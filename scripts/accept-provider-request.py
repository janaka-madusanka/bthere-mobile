"""Accept one real booking offer with provider credentials entered locally."""
import argparse
from datetime import datetime, timezone
import getpass
import json
from pathlib import Path
import sys
import socket
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
import warnings


class HelperError(Exception):
    pass


class TemporaryReadError(HelperError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class ProviderClient:
    def __init__(self, base_url):
        if not isinstance(base_url, str):
            raise HelperError('Invalid API URL in the configuration.')
        parsed = urllib.parse.urlsplit(base_url)
        local = parsed.hostname in {'localhost', '127.0.0.1', '::1'}
        if (parsed.scheme != 'https' and not (local and parsed.scheme == 'http')) or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise HelperError('Use an HTTPS API URL (HTTP is allowed only on localhost).')
        self.base_url = base_url.rstrip('/')
        self.token = None
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, method, path, data=None):
        attempts = 3 if method == 'GET' else 1
        for attempt in range(attempts):
            try:
                return self._request_once(method, path, data)
            except TemporaryReadError as error:
                if attempt + 1 == attempts:
                    raise HelperError(str(error)) from None
                print(f'{error} Retrying read ({attempt + 2}/{attempts})...')
                time.sleep(1)

    def _request_once(self, method, path, data=None):
        headers = {'Accept': 'application/json'}
        if self.token:
            headers['Authorization'] = f'Bearer {self.token}'
        body = None
        if data is not None:
            body = json.dumps(data).encode('utf-8')
            headers['Content-Type'] = 'application/json'
        request = urllib.request.Request(self.base_url + path, data=body, headers=headers, method=method)
        try:
            with self.opener.open(request, timeout=20) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if method == 'POST' and path.endswith('/accept') and error.code >= 500:
                raise HelperError('Acceptance result is uncertain. Check app status before retrying. No automatic retry was sent.') from None
            if method == 'GET' and error.code in {500, 502, 503, 504}:
                raise TemporaryReadError(f'Provider API temporarily unavailable (HTTP {error.code}).') from None
            messages = {401: 'Sign-in expired or credentials are incorrect.', 403: 'This provider account is not permitted to perform this action.', 409: 'The offer is no longer available or the request state changed.'}
            raise HelperError(messages.get(error.code, f'API returned HTTP {error.code}.')) from None
        except (OSError, urllib.error.URLError, ValueError) as error:
            if method == 'POST' and path.endswith('/accept'):
                raise HelperError('Acceptance result is uncertain. Check Customer/Provider status before trying again. No automatic retry was sent.') from None
            reason = error.reason if isinstance(error, urllib.error.URLError) else error
            transient_tls = isinstance(reason, (ssl.SSLEOFError, ssl.SSLZeroReturnError)) or (
                isinstance(reason, ssl.SSLError) and getattr(reason, 'reason', None) == 'UNEXPECTED_EOF_WHILE_READING'
            )
            if isinstance(error, ValueError):
                message = f'API returned invalid JSON for {method} {path}.'
            elif isinstance(reason, (TimeoutError, socket.timeout)):
                message = f'API connection timed out during {method} {path}.'
            elif isinstance(reason, ssl.SSLCertVerificationError):
                message = f'TLS certificate verification failed during {method} {path}. Check the system clock and server certificate chain.'
            elif transient_tls:
                message = f'TLS connection closed unexpectedly during {method} {path}.'
            elif isinstance(reason, ssl.SSLError):
                message = f'TLS/certificate connection failed during {method} {path}.'
            elif isinstance(reason, socket.gaierror):
                message = f'API hostname could not be resolved during {method} {path}.'
            else:
                message = f'Network connection failed during {method} {path}.'
            if method == 'GET' and (not isinstance(reason, ssl.SSLError) or transient_tls):
                raise TemporaryReadError(message) from None
            raise HelperError(message) from None

    def login(self, identifier, password):
        result = self.request('POST', '/auth/login', {'identifier': identifier, 'password': password})
        user = result.get('user') if isinstance(result, dict) else None
        if not isinstance(user, dict) or not isinstance(user.get('roles'), list) or 'SERVICE_PROVIDER' not in user['roles']:
            raise HelperError('Sign in with a SERVICE_PROVIDER account.')
        token = result.get('accessToken')
        if not isinstance(token, str) or not token.strip():
            raise HelperError('Invalid sign-in response.')
        self.token = token

    def offers(self):
        result = self.request('GET', '/providers/me/booking-offers')
        if not isinstance(result, list):
            raise HelperError('Invalid offer list returned by the server.')
        return result

    def accept(self, offer):
        result = self.request('POST', f"/providers/me/booking-offers/{offer['offerId']}/accept")
        if not isinstance(result, dict) or result.get('requestId') != offer['requestId']:
            raise HelperError('Acceptance response could not be verified. Check app status before retrying.')
        return result


def pending_offer(rows, request_id, now=None):
    now = now or datetime.now(timezone.utc)
    matches = []
    for row in rows:
        if not isinstance(row, dict) or row.get('requestId') != request_id or row.get('status') != 'PENDING':
            continue
        if type(row.get('offerId')) is not int or row['offerId'] <= 0:
            continue
        try:
            deadline = datetime.fromisoformat(row['expiresAt'].replace('Z', '+00:00'))
        except (KeyError, ValueError, AttributeError, TypeError):
            continue
        if deadline.tzinfo is not None and deadline > now:
            matches.append(row)
    if len(matches) > 1:
        raise HelperError('Multiple live offers match this request. Inspect the Provider app before accepting.')
    return matches[0] if matches else None


def accept_selected(client, request_id, offer_id):
    # Re-read after the operator confirms: never accept a stale/different offer.
    current = pending_offer(client.offers(), request_id)
    if current is None or current['offerId'] != offer_id:
        raise HelperError('The selected offer expired or changed. No acceptance was sent.')
    return client.accept(current)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=Path(__file__).resolve().parents[1] / 'config/customer.local.json')
    parser.add_argument('--request-id', type=int)
    parser.add_argument('--wait-seconds', type=int, default=300)
    parser.add_argument('--accept-on-arrival', action='store_true', help='Accept the specified request immediately when its live offer arrives; no second confirmation prompt.')
    args = parser.parse_args(argv)
    if not sys.stdin.isatty():
        raise HelperError('Run this helper in your own interactive terminal.')
    try:
        config = json.loads(args.config.read_text(encoding='utf-8-sig'))
        client = ProviderClient(config['BTHERE_API_BASE_URL'])
    except (OSError, ValueError, KeyError, TypeError):
        raise HelperError('Unable to read BTHERE_API_BASE_URL from the local config.') from None
    if not 0 <= args.wait_seconds <= 900:
        raise HelperError('Wait time must be between 0 and 900 seconds.')
    print(f'API: {client.base_url}')
    print('This accepts a real offer for this provider account. Credentials are not saved.')
    if args.accept_on_arrival:
        print('Accept-on-arrival enabled: ONLY the Request ID you enter will be accepted automatically.')
    identifier = input('Provider email / username: ').strip()
    with warnings.catch_warnings():
        warnings.simplefilter('error', getpass.GetPassWarning)
        try:
            password = getpass.getpass('Provider password (hidden): ')
        except getpass.GetPassWarning:
            raise HelperError('Hidden password input is unavailable. Use a normal PowerShell terminal.') from None
    if not identifier or not password:
        raise HelperError('Enter both provider identifier and password.')
    try:
        client.login(identifier, password)
    finally:
        password = None
    try:
        request_id = args.request_id or int(input('Customer Request ID (number only): ').strip())
        if request_id <= 0:
            raise ValueError()
    except ValueError:
        raise HelperError('Enter a positive Customer Request ID.') from None
    print(f'Waiting for Request #{request_id} to ring this provider. Ctrl+C stops.')
    deadline = time.monotonic() + args.wait_seconds
    while True:
        offer = pending_offer(client.offers(), request_id)
        if offer:
            break
        if time.monotonic() >= deadline:
            raise HelperError('No live offer for this request reached this provider. Check service approval, availability, coverage and request expiry. No acceptance was sent.')
        time.sleep(min(3, max(0, deadline - time.monotonic())))
    print(f"Request #{request_id} | Offer #{offer['offerId']} | Service {offer.get('serviceTypeId', '?')} / Option {offer.get('optionId', '?')}")
    print(f"Offer expires: {offer['expiresAt']}")
    if not args.accept_on_arrival:
        confirmation = input(f'Type {request_id} to ACCEPT this offer, or press Enter to cancel: ').strip()
        if confirmation not in {str(request_id), f'ACCEPT {request_id}'}:
            print('Stopped. No acceptance was sent.')
            return
    else:
        print(f'Accepting Request #{request_id} now...')
    result = accept_selected(client, request_id, offer['offerId'])
    print(f"Request #{request_id}: acceptance response received. Status: {result.get('status', 'not supplied')}")
    print('Return to the Customer app. It should show provider acceptance; continue to customer payment confirmation.')
    client.token = None


if __name__ == '__main__':
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        print('\nStopped. Check app status if acceptance had already started.')
        sys.exit(1)
    except HelperError as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
