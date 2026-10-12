# Provider profile save investigation

The live failure has not been reproduced by an automated submission. No backend
mutation was performed. The root cause and live HTTP status remain unconfirmed.

## Current request

`ProviderProfileScreen` constructs `ProviderProfileInput` and the controller
validates required names, calendar date and the selected active market before
calling `ProviderProfileRepositoryImpl.updateProfile`.

The repository calls `ProviderProfileRemoteDataSource.updateProfile`, which calls
`ApiClient.put<Object?>('/providers/me/profile', requiresAuth: true)`.
The configured API base URL supplies the `/api/v1` prefix. The transport obtains
the current access token through its token provider. No credentials are logged.

`serializeProviderProfile` always includes these ten JSON keys:

- `firstName`: trimmed text
- `lastName`: trimmed text
- `nicNumber`: null
- `passportNumber`: null
- `dateOfBirth`: calendar components formatted as YYYY-MM-DD
- `gender`: exact selected enum wire value MALE or FEMALE
- `profilePhoto`: null
- `bio`: trimmed text, or null when blank
- `availabilityStatus`: exact selected availability enum wire value
- `marketId`: selected market's numeric ID, not its display name

No request fields or serialization rules were changed for this investigation.

## Response and error handling

Dio uses its default successful-status validation (200 through 299) and JSON
response transformation. Redirect following is disabled. The remote source
ignores the success body and treats an accepted HTTP status as acknowledgment.

`ApiClient._request` catches `DioException` and calls `normalizeDioException`.
`DioExceptionType.badResponse` becomes `NetworkExceptionKind.badResponse`, whose
fallback is **The server could not complete the request.**

For a JSON object, normalization reads only top-level `message` and `code`, and
only accepts its existing generic allowlists. It does not read `title`, `detail`
or field errors. Unknown or differently structured bodies retain the fallback.
The displayed fallback does not establish a specific HTTP status or root cause.

The profile repository replaces recognized validation failures with
**Please check your profile details and try again.** Otherwise it passes
`error.toAppFailure()` to the controller, which preserves the message and code
for presentation. Unexpected non-network exceptions have separate fallbacks.

## Debug diagnostics

Only the profile remote source installs the new optional PUT error inspection
callback, and only under `kDebugMode`. It runs before existing normalization;
diagnostic callback failures cannot replace the original network failure.
Release and profile builds do not install the callback or print these logs.
Successful debug saves also emit the status and field names.

The JSON log contains only `method`, `path`, `statusCode`, recognized top-level
`title` / `detail` / `message`, and the fixed allowlisted profile field names
present in the serialized map (including keys whose values are null).

Arbitrary backend text can echo PII or credentials. Known generic error phrases
are printed verbatim; other string values are replaced with
`[withheld: unrecognized backend text]`. Non-object bodies and non-string error
fields are omitted. Headers, tokens, request values, full response bodies,
field-validation objects, exception strings and document data are never printed.
This deliberately limits diagnosis when the server returns only unfamiliar text.

Restart the app in debug mode with the usual API configuration and manually
submit once to capture this log. No API contract or user-visible failure mapping
has changed, and no specific backend cause is claimed.

## Verification

- Workspace `dart analyze`: no issues.
- Focused Provider profile, gender, selector and diagnostics tests: 49 passed.
- All network package tests: 46 passed.
- Formatting check for the touched Dart sources: zero changes.
- Three additional regression tests cover field-name-only/redacted output,
  missing/non-object response bodies, and preservation of normalization even
  when a diagnostic sink throws.
- No commit, push or PR.
