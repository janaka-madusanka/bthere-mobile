# Saved provider login for the acceptance helper

First run (or to replace the saved account/password):

```powershell
.\scripts\accept-provider-request.ps1 -SaveCredentials -AcceptOnArrival
```

Enter the provider identifier and hidden password locally. Credentials are saved
only after a successful SERVICE_PROVIDER login. Next time:

```powershell
.\scripts\accept-provider-request.ps1 -AcceptOnArrival
```

Only enter the Customer Request ID. The real offer for exactly that ID is still
revalidated before acceptance. Saving credentials does not broaden acceptance,
disable TLS verification or enable automatic POST retries.

Delete the saved account for the configured API:

```powershell
.\scripts\accept-provider-request.ps1 -ForgetCredentials
```

Windows stores the file in `%LOCALAPPDATA%\BThere\ProviderAcceptance`, outside
the repository. The password uses Windows DPAPI through PSCredential CLIXML;
it can be decrypted by the same Windows user on that computer. The username and
API scope are metadata. Different API base URLs use separate files. The password
is not placed in shell history, process arguments, environment variables or logs;
the child helper exchanges it through private stdin/stdout pipes. Do not run the
internal credential script's Read mode directly in a shared terminal.

No credential is saved merely by changing this implementation. A person with
access to your unlocked Windows account can use the saved login. If credentials
expire/change, run `-SaveCredentials` again. There is no plaintext fallback if
decryption fails. Non-Windows direct Python usage retains interactive login.

Session recovery: the helper asks for the Request ID before logging in, so time spent locating the ID does not age the access token. An authenticated offer GET rejected with HTTP 401 can rotate the in-memory refresh token once and reread. Repeated rejection stops. Login, refresh and acceptance POSTs are never automatically retried, and refresh credentials/tokens are never written to disk. API method/path is included in authentication errors without server bodies or tokens.

Waiting diagnostics: every 15 seconds the helper reports whether the specified request exists in this provider's offer feed, or is returned without a live unexpired offer. An empty feed is not acceptance failure: no accept POST has been sent. The helper cannot assign a provider or override backend capacity/eligibility/expiry. After one accepted booking, overlapping scheduled tests may have no offer for that provider while its capacity remains held; inspect the real request/payment state before choosing another test slot.
