import importlib.util
import io
from datetime import datetime, timedelta, timezone
from pathlib import Path
import unittest
from unittest.mock import Mock
from unittest.mock import patch
import urllib.error
import tempfile
import ssl

spec = importlib.util.spec_from_file_location('provider_helper', Path(__file__).parents[1] / 'accept-provider-request.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def offer(request=22, identity=50, status='PENDING', expired=False):
    return {'requestId': request, 'offerId': identity, 'status': status,
            'expiresAt': (datetime.now(timezone.utc) + timedelta(seconds=-20 if expired else 60)).isoformat()}


class AcceptanceTests(unittest.TestCase):
    def test_tls_eof_during_offer_read_retries_with_verification_unchanged(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.opener = Mock()
        response = Mock()
        response.__enter__ = Mock(return_value=io.BytesIO(b'[]'))
        response.__exit__ = Mock(return_value=False)
        client.opener.open.side_effect = [urllib.error.URLError(ssl.SSLEOFError(8, 'private')), response]
        with patch.object(helper.time, 'sleep'), patch('builtins.print'):
            self.assertEqual(client.offers(), [])
        self.assertEqual(client.opener.open.call_count, 2)

    def test_tls_eof_reads_are_bounded_and_do_not_expose_raw_error(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.opener = Mock()
        client.opener.open.side_effect = ssl.SSLEOFError(8, 'private')
        with patch.object(helper.time, 'sleep'), patch('builtins.print'):
            with self.assertRaises(helper.HelperError) as caught:
                client.offers()
        self.assertIn('TLS connection closed unexpectedly', str(caught.exception))
        self.assertNotIn('private', str(caught.exception))
        self.assertEqual(client.opener.open.call_count, 3)

    def test_certificate_verification_failure_never_retries(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.opener = Mock()
        client.opener.open.side_effect = urllib.error.URLError(ssl.SSLCertVerificationError(1, 'private'))
        with patch.object(helper.time, 'sleep') as sleep:
            with self.assertRaises(helper.HelperError) as caught:
                client.offers()
        self.assertIn('certificate verification failed', str(caught.exception))
        self.assertNotIn('private', str(caught.exception))
        client.opener.open.assert_called_once()
        sleep.assert_not_called()

    def test_tls_eof_during_acceptance_is_uncertain_and_never_retried(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.opener = Mock()
        client.opener.open.side_effect = ssl.SSLEOFError(8, 'private')
        with patch.object(helper.time, 'sleep') as sleep:
            with self.assertRaises(helper.HelperError) as caught:
                client.accept(offer())
        self.assertIn('uncertain', str(caught.exception))
        client.opener.open.assert_called_once()
        sleep.assert_not_called()

    def run_interactive(self, auto):
        client = Mock()
        client.base_url = 'https://example.invalid/api/v1'
        client.offers.side_effect = [[offer(request=23), offer()], [offer()]]
        client.accept.return_value = {'requestId': 22, 'status': 'AWAITING_CUSTOMER_CONFIRMATION'}
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'test.json'
            config.write_text('{"BTHERE_API_BASE_URL":"https://example.invalid/api/v1"}', encoding='utf-8')
            args = ['--config', str(config), '--request-id', '22', '--wait-seconds', '0']
            if auto:
                args.append('--accept-on-arrival')
            answers = ['synthetic@example.invalid'] if auto else ['synthetic@example.invalid', '']
            with patch.object(helper, 'ProviderClient', return_value=client), patch.object(helper.sys.stdin, 'isatty', return_value=True), patch.object(helper.getpass, 'getpass', return_value='synthetic-password'), patch('builtins.input', side_effect=answers) as prompt, patch('builtins.print'):
                helper.main(args)
        return client, prompt

    def test_accept_on_arrival_skips_second_prompt_and_accepts_only_selected_request(self):
        client, prompt = self.run_interactive(True)
        self.assertEqual(prompt.call_count, 1)
        self.assertEqual(client.offers.call_count, 2)
        client.accept.assert_called_once()
        self.assertEqual(client.accept.call_args.args[0]['requestId'], 22)

    def test_default_mode_still_allows_cancel_without_acceptance(self):
        client, prompt = self.run_interactive(False)
        self.assertEqual(prompt.call_count, 2)
        client.accept.assert_not_called()
    def test_offer_read_recovers_from_temporary_connection_failure(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.opener = Mock()
        response = Mock()
        response.__enter__ = Mock(return_value=io.BytesIO(b'[]'))
        response.__exit__ = Mock(return_value=False)
        client.opener.open.side_effect = [TimeoutError(), response]
        with patch.object(helper.time, 'sleep'), patch('builtins.print'):
            self.assertEqual(client.offers(), [])
        self.assertEqual(client.opener.open.call_count, 2)

    def test_read_timeout_and_invalid_json_are_distinguished_and_bounded(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.opener = Mock()
        client.opener.open.side_effect = TimeoutError('secret')
        with patch.object(helper.time, 'sleep'), patch('builtins.print'):
            with self.assertRaises(helper.HelperError) as caught:
                client.offers()
        self.assertIn('timed out', str(caught.exception))
        self.assertNotIn('secret', str(caught.exception))
        self.assertEqual(client.opener.open.call_count, 3)
        client._request_once = Mock(side_effect=helper.TemporaryReadError('API returned invalid JSON for GET /providers/me/booking-offers.'))
        with patch.object(helper.time, 'sleep'), patch('builtins.print'):
            with self.assertRaises(helper.HelperError) as caught:
                client.offers()
        self.assertIn('invalid JSON', str(caught.exception))
        self.assertEqual(client._request_once.call_count, 3)
    def test_only_live_matching_request_is_selected(self):
        match = offer()
        self.assertIs(helper.pending_offer([offer(request=23), offer(expired=True), offer(status='DECLINED'), match], 22), match)
        self.assertIsNone(helper.pending_offer([offer(request=23), offer(expired=True)], 22))

    def test_bad_or_ambiguous_offer_is_not_selected(self):
        self.assertIsNone(helper.pending_offer([{'requestId': 22, 'status': 'PENDING', 'offerId': 50, 'expiresAt': 'bad'}], 22))
        with self.assertRaises(helper.HelperError):
            helper.pending_offer([offer(), offer(identity=51)], 22)

    def test_customer_role_cannot_accept(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.request = Mock(return_value={'user': {'roles': ['CUSTOMER']}, 'accessToken': 'synthetic'})
        with self.assertRaises(helper.HelperError):
            client.login('synthetic@example.invalid', 'synthetic-password')
        self.assertIsNone(client.token)

    def test_provider_login_retains_only_access_token(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.request = Mock(return_value={'user': {'roles': ['SERVICE_PROVIDER']}, 'accessToken': 'synthetic'})
        client.login('synthetic@example.invalid', 'synthetic-password')
        self.assertEqual(client.token, 'synthetic')

    def test_expired_or_replaced_offer_cannot_be_accepted(self):
        for rows in [[], [offer(expired=True)], [offer(identity=51)]]:
            client = Mock()
            client.offers.return_value = rows
            with self.assertRaises(helper.HelperError):
                helper.accept_selected(client, 22, 50)
            client.accept.assert_not_called()

    def test_accept_is_revalidated_and_sent_once(self):
        current = offer()
        client = Mock()
        client.offers.return_value = [current]
        client.accept.return_value = {'requestId': 22, 'status': 'AWAITING_CUSTOMER_CONFIRMATION'}
        result = helper.accept_selected(client, 22, 50)
        client.offers.assert_called_once()
        client.accept.assert_called_once_with(current)
        self.assertEqual(result['requestId'], 22)

    def test_accept_post_uses_provider_offer_route_without_body(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.request = Mock(return_value={'requestId': 22, 'status': 'AWAITING_CUSTOMER_CONFIRMATION'})
        client.accept(offer())
        client.request.assert_called_once_with('POST', '/providers/me/booking-offers/50/accept')

    def test_uncertain_acceptance_is_not_retried_or_raw_error_exposed(self):
        for error in [TimeoutError('private data'), urllib.error.HTTPError('https://example.invalid', 503, 'private data', {}, io.BytesIO(b'sensitive'))]:
            client = helper.ProviderClient('https://example.invalid/api/v1')
            client.opener = Mock()
            client.opener.open.side_effect = error
            with self.assertRaises(helper.HelperError) as caught:
                client.accept(offer())
            self.assertIn('uncertain', str(caught.exception))
            self.assertNotIn('private data', str(caught.exception))
            client.opener.open.assert_called_once()

    def test_remote_plain_http_and_redirects_are_rejected(self):
        with self.assertRaises(helper.HelperError):
            helper.ProviderClient('http://example.invalid/api/v1')
        helper.ProviderClient('http://127.0.0.1:8080/api/v1')
        self.assertIsNone(helper.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://other.invalid'))


if __name__ == '__main__':
    unittest.main()
