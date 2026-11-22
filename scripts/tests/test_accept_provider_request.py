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
import os
import json
import subprocess
import uuid

spec = importlib.util.spec_from_file_location('provider_helper', Path(__file__).parents[1] / 'accept-provider-request.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def offer(request=22, identity=50, status='PENDING', expired=False):
    return {'requestId': request, 'offerId': identity, 'status': status,
            'expiresAt': (datetime.now(timezone.utc) + timedelta(seconds=-20 if expired else 60)).isoformat()}


class AcceptanceTests(unittest.TestCase):
    def test_wait_reports_missing_offer_and_never_accepts_another_request(self):
        client = Mock()
        client.offers.return_value = [offer(request=62)]
        with patch.object(helper.time, 'monotonic', side_effect=[0, 0]), patch('builtins.print') as output:
            with self.assertRaises(helper.HelperError):
                helper.wait_for_offer(client, 61, 0)
        self.assertIn('no offer in this provider feed', output.call_args.args[0])
        client.accept.assert_not_called()

    def test_wait_polls_until_exact_request_arrives(self):
        client = Mock()
        desired = offer(request=61)
        client.offers.side_effect = [[], [desired]]
        with patch.object(helper.time, 'monotonic', side_effect=[0, 0]), patch.object(helper.time, 'sleep'), patch('builtins.print'):
            self.assertIs(helper.wait_for_offer(client, 61, 30), desired)
        client.accept.assert_not_called()

    def test_wait_distinguishes_expired_offer_from_missing_offer(self):
        client = Mock()
        client.offers.return_value = [offer(request=61, expired=True)]
        with patch.object(helper.time, 'monotonic', side_effect=[0, 0]), patch('builtins.print') as output:
            with self.assertRaises(helper.HelperError):
                helper.wait_for_offer(client, 61, 0)
        self.assertIn('no live unexpired offer', output.call_args.args[0])
        client.accept.assert_not_called()

    def test_401_offer_read_renews_once_then_rereads_without_accepting(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.token, client.refresh_token = 'old-access', 'old-refresh'
        session = {'user': {'roles': ['SERVICE_PROVIDER']}, 'accessToken': 'new-access', 'refreshToken': 'new-refresh'}
        client._request_once = Mock(side_effect=[helper.ExpiredReadSession(), session, []])
        self.assertEqual(client.offers(), [])
        self.assertEqual(client.token, 'new-access')
        self.assertEqual(client.refresh_token, 'new-refresh')
        self.assertEqual([(call.args[0], call.args[1]) for call in client._request_once.call_args_list], [
            ('GET', '/providers/me/booking-offers'), ('POST', '/auth/refresh'), ('GET', '/providers/me/booking-offers')])

    def test_repeated_401_read_stops_after_one_refresh(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.token, client.refresh_token = 'old-access', 'old-refresh'
        session = {'user': {'roles': ['SERVICE_PROVIDER']}, 'accessToken': 'new-access', 'refreshToken': 'new-refresh'}
        client._request_once = Mock(side_effect=[helper.ExpiredReadSession(), session, helper.ExpiredReadSession()])
        with self.assertRaises(helper.HelperError):
            client.offers()
        self.assertEqual(client._request_once.call_count, 3)

    def test_accept_401_is_not_refreshed_or_retried(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.token, client.refresh_token = 'old-access', 'old-refresh'
        client.opener = Mock()
        client.opener.open.side_effect = urllib.error.HTTPError('https://example.invalid', 401, 'Unauthorized', {}, None)
        with self.assertRaises(helper.HelperError):
            client.accept(offer())
        self.assertEqual(client.opener.open.call_count, 1)
        self.assertEqual(client.refresh_token, 'old-refresh')

    def test_refresh_cannot_change_to_customer_role(self):
        client = helper.ProviderClient('https://example.invalid/api/v1')
        client.token, client.refresh_token = 'old-access', 'old-refresh'
        client._request_once = Mock(return_value={'user': {'roles': ['CUSTOMER']}, 'accessToken': 'wrong-role'})
        with self.assertRaises(helper.HelperError):
            client.refresh_session()
        self.assertIsNone(client.token)

    def test_saved_login_reuses_credentials_without_prompting(self):
        client = Mock(base_url='https://example.invalid/api/v1')
        with patch.object(helper, 'credential_store', return_value={'identifier': 'sample', 'password': 'synthetic-secret'}) as store, patch('builtins.input') as prompt, patch('builtins.print'):
            helper.login_provider(client)
        prompt.assert_not_called()
        client.login.assert_called_once_with('sample', 'synthetic-secret')
        store.assert_called_once_with('Read', client.base_url)

    def test_credentials_saved_only_after_successful_provider_login(self):
        client = Mock(base_url='https://example.invalid/api/v1')
        for accepted in [True, False]:
            client.login.side_effect = None if accepted else helper.HelperError('Incorrect credentials')
            with patch.object(helper, 'credential_store') as store, patch('builtins.input', return_value='sample'), patch.object(helper.getpass, 'getpass', return_value='synthetic-secret'), patch('builtins.print'):
                if accepted:
                    helper.login_provider(client, save=True)
                    store.assert_called_once_with('Save', client.base_url, {'identifier': 'sample', 'password': 'synthetic-secret'})
                else:
                    with self.assertRaises(helper.HelperError):
                        helper.login_provider(client, save=True)
                    store.assert_not_called()

    def test_no_saved_credential_keeps_interactive_hidden_login(self):
        client = Mock(base_url='https://example.invalid/api/v1')
        with patch.object(helper, 'credential_store', return_value=None), patch('builtins.input', return_value='sample'), patch.object(helper.getpass, 'getpass', return_value='synthetic-secret'):
            helper.login_provider(client)
        client.login.assert_called_once_with('sample', 'synthetic-secret')

    def test_credential_secret_uses_private_stdin_not_process_arguments(self):
        with patch.object(helper.os, 'name', 'nt'), patch.object(helper.subprocess, 'run', return_value=Mock(returncode=0, stdout='')) as run:
            helper.credential_store('Save', 'https://example.invalid/api/v1', {'identifier': 'sample', 'password': 'synthetic-secret'})
        args, kwargs = run.call_args
        self.assertNotIn('synthetic-secret', str(args))
        self.assertEqual(json.loads(kwargs['input'])['password'], 'synthetic-secret')
        self.assertNotIn('env', kwargs)

    def test_credential_errors_do_not_expose_child_output(self):
        with patch.object(helper.os, 'name', 'nt'), patch.object(helper.subprocess, 'run', return_value=Mock(returncode=1, stdout='synthetic-secret', stderr='synthetic-secret')):
            with self.assertRaises(helper.HelperError) as error:
                helper.credential_store('Read', 'https://example.invalid/api/v1')
        self.assertNotIn('synthetic-secret', str(error.exception))

    @unittest.skipUnless(os.name == 'nt', 'Windows DPAPI integration')
    def test_windows_store_roundtrip_is_encrypted_and_api_scoped(self):
        root = Path(__file__).resolve().parents[2] / 'build'
        root.mkdir(exist_ok=True)
        directory = root / ('credential-test-' + uuid.uuid4().hex)
        self.assertEqual(directory.resolve().parent, root.resolve())
        script = Path(__file__).parents[1] / 'provider-helper-credentials.ps1'
        executable = Path(os.environ.get('SystemRoot', r'C:\Windows')) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
        def operation(mode, scope='https://example.invalid/api/v1', data=None):
            result = subprocess.run([str(executable), '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', str(script), '-Mode', mode, '-ApiScope', scope, '-StoreDirectory', str(directory)], input=json.dumps(data) if data else '', capture_output=True, text=True, encoding='utf-8', timeout=30)
            self.assertEqual(result.returncode, 0, 'Encrypted credential operation failed')
            return json.loads(result.stdout) if mode == 'Read' else None
        credential = {'identifier': 'synthetic@example.invalid', 'password': 'synthetic-secret-සිංහල'}
        try:
            operation('Save', data=credential)
            self.assertEqual(operation('Read'), credential)
            self.assertIsNone(operation('Read', scope='https://other.invalid/api/v1'))
            content = next(directory.glob('*.xml')).read_text(encoding='utf-8-sig')
            self.assertNotIn(credential['password'], content)
            self.assertNotIn('synthetic-secret', content)
            operation('Forget')
            self.assertIsNone(operation('Read'))
        finally:
            if directory.exists():
                for file in directory.iterdir():
                    self.assertEqual(file.resolve().parent, directory.resolve())
                    file.unlink()
                directory.rmdir()

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
