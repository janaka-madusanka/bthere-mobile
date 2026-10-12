# Provider password Sign in

The default `/auth` route now shows Sign in. The Sign in / Create account
segmented control switches between `/auth` and the existing
`/auth/register/email` form. Registration's validation and email OTP verification
remain unchanged. Tabs replace route state; passwords are never transferred
between forms or placed in navigation.

`ProviderAuthRepository.loginProvider(identifier: ..., password: ...)` posts
`/auth/login` with `requiresAuth: false` and exactly:

```json
{"identifier": "<trimmed Provider email or username>", "password": "<unchanged password>"}
```

The external API base URL includes `/api/v1`. The backend accepts email through
`identifier`; the deployed backend rejects the previous `username` request key
with an identifier-required validation error. No email, role/type or registration
metadata is added to this request.
UI requires an identifier and a password, with email keyboard and username/email
autofill. Login applies no registration length/complexity requirement and never
trims the password. Visibility is local, with correction/suggestions disabled
even when revealed. Password autofill is used, and automatic save completion is
canceled on disposal. Text controllers are disposed on exit and password is
cleared on successful completion while the form remains mounted.

Login reuses the existing internal authentication response parser and trusted
Auth flow: require `SERVICE_PROVIDER`, calculate UTC expiry from `expiresIn`,
construct the B there session, await `SessionStorage.write`, return safe AuthUser.
Wrong roles and malformed responses never persist. A secure-write failure returns
Failure; backend success alone is insufficient. The Riverpod login controller
does not call ApiClient or write storage. It blocks duplicates, handles disposal,
strips failure causes and refreshes local session state on success. The existing
router checks the documented completion API after secure session restoration.
Incomplete profile/market prerequisites enter `/onboarding/profile`; completed
prerequisites enter `/services`. Later service setup keeps its service-first routing.
See [email registration onboarding](provider-email-registration-onboarding.md).
Tokens and password are never stored in presentation state, logs or navigation.

Failures keep the form and input available for correction/retry. Busy submissions
disable fields, visibility, tabs, CTA and back. Shared tokens/background/branding
are used in both modes; scroll, SafeArea, maximum width and system themes remain.
Google is retained dormant and hidden. No Apple, forgot-password or phone UI is
added. Only `BTHERE_API_BASE_URL` is required; Google configuration is optional.

## Manual live-contract validation

Automated tests use fake repositories/storage or an in-memory transport and do
not call a live backend. Validate login manually first using a Provider account
created from the Admin Dashboard, with `SERVICE_PROVIDER` in its returned roles.
Confirm the supplied username/email, password and common token-response shape
against the current backend. The app preserves backend status rather than
inventing status/verification rules. Invalid credentials, role rejection and
secure-storage errors remain safe failures. `/home` remains a placeholder behind
the [onboarding completion gateway](../apps/provider_app/README.md). Registration/OTP remains available while the backend
developer fixes that flow; it has not been removed or changed into login.

Verification passed: root dependency resolution, formatting, clean analysis of
all seven members, Provider debug APK build, and 317 workspace tests (Provider
113, Auth 127, Customer 1, Common 3, Network 46, Session 8, Design System 19).
This adds 47 login tests to the previous 270-test baseline. Automated coverage
includes fixed public identifier/password serialization, credential validation,
Provider roles, response/expiry safety, awaited persistence/failure, tabs,
visibility/autofill, loading/duplicates, retry, session reread/routing, disposal,
and narrow light/dark layouts with enlarged text and keyboard insets.
