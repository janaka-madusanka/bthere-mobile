# Accept a test booking request using a provider account

This local terminal helper performs a real provider acceptance against the same
API configuration as Customer. It does not restore the offline preview or fake
Customer payment state. Only pending, unexpired offers received by this provider
can be accepted. Service approval, availability, coverage and matching still apply.

From the repository root in your own PowerShell terminal:

For the fastest test flow, use accept-on-arrival mode. It accepts only the exact
Request ID you enter, without waiting for a second confirmation while the short
provider offer expires:

```powershell
.\scripts\accept-provider-request.ps1 -AcceptOnArrival
```

Log in first, then send a new request in Customer and enter its Request ID at the
waiting prompt. The helper still checks the offer's ownership, status and expiry
again immediately before its single acceptance POST. It cannot revive an expired
offer or force the server to assign the request to this provider.

For a manual confirmation prompt instead:

```powershell
.\scripts\accept-provider-request.ps1
```

1. Enter your provider email/username and password locally. Password input is hidden.
2. Create a fresh request in the Customer app, then enter its numeric Request ID.
3. The helper waits up to five minutes for that request's offer to reach the provider.
4. Read the matching Request ID/Offer ID. Type the Request ID number again to accept it, or press Enter without typing to cancel. The older `ACCEPT <requestId>` format also works.
5. Return to Customer. Its existing status polling shows provider acceptance;
   continue into customer payment confirmation. This helper does not pay or reserve funds.

An already expired, cancelled or unmatched request needs a fresh send from Customer.
If another provider receives the offer first, wait for dispatch or use an eligible
direct-request provider. The helper does not force assignment or override expiry.

To supply the request number up front:

```powershell
.\scripts\accept-provider-request.ps1 -RequestId 22
```

Replace 22 with the current request. Optional `-WaitSeconds` is 0–900;
`-ConfigFile` selects a different local config. Default: `config/customer.local.json`.
Python 3 (`python`, or the `py` launcher) is required; no additional packages are used. Credentials and tokens
are kept in process memory only. Do not put passwords in commands, chat or files.

Acceptance is revalidated just before POST and is never automatically retried.
If the result is uncertain, inspect Customer/Provider status before another attempt.
Tests run locally without backend requests:

```powershell
python -B -m unittest discover -s scripts/tests -p test_accept_provider_request.py
```
Read reliability: temporary network/timeouts, invalid JSON and selected server errors during GET reads are retried up to three times with a short pause. Diagnostics identify the failing method/path and category without exposing credentials or response bodies. Sign-in/accept POSTs are not automatically retried. The PowerShell wrapper shows the helper error without an extra exception stack.

An intermittent TLS EOF (the connection closes unexpectedly while reading) also
retries GET reads up to three times. This was reproduced against the API without
credentials: two verified HTTPS connections succeeded and one returned
`UNEXPECTED_EOF_WHILE_READING`. It does not by itself indicate an invalid
certificate. Certificate verification errors fail immediately; certificate checks
remain enabled. TLS failures during acceptance still report an uncertain result
and never retry the acceptance POST automatically.
