# Customer email authentication — milestone 2

Customer-only auth lives under `apps/customer_app/lib/features/auth`. It uses
the shared ApiClient, secure SessionStorage and Design System without changing
Provider authentication, shared packages or the workspace lockfile.

## Contracts and screens

- Register: POST `/auth/register`, exactly email/password/accountType CUSTOMER.
  Email is trimmed/lowercased; password is preserved. Password length is 10–72
  Unicode code points. Registration is 201 account metadata, not a login.
- Verify: POST `/auth/email/verify`, exactly email/otp; six digits including
  leading zeros. No accountType on this endpoint.
- Resend: POST `/auth/email/resend`, exactly email; 202 response. A default
  60-second cooldown applies, overridden conservatively by 429 body/header
  deadlines, including HTTP-date Retry-After. Generic responses do not prove
  that an account exists. There is no invented registration OTP expiry timer.
  Returning unverified users can enter their email on sign-in and choose
  Verify an existing email to resume through this same generic resend contract.
- Login: POST `/auth/login`, exactly trimmed identifier and unchanged password;
  no username/accountType key. Identifier accepts email or username.
- Login/verification/refresh validate Bearer tokens, positive server expiresIn,
  active CUSTOMER role and nullable email before persisting one secure record.
- Startup restores credentials, refreshes expired access tokens and validates
  GET `/users/me`. Empty storage routes to sign-in without HTTP calls. Storage,
  offline and server errors remain a retryable startup error.
- Current logout: public POST `/auth/logout` with refreshToken. All-session
  logout: protected POST `/auth/logout-all` without body and with confirmation.
  Both require successful 204 before local clearing; failed revocation remains
  an explicit error. Existing short-lived access tokens on other devices may
  remain valid until expiry after logout-all.

Login and verification only enter the authenticated handoff after secure
persistence and current-user validation. That temporary screen has sign-out
actions; it does not pretend that Customer profile onboarding is implemented.
Profile GET/PUT and its documented 404 completion gate are milestone 3.

## Refresh and transport

Auth uses public requests with no bearer header. Protected reads use
ApiClient.requiresAuth and the existing Customer token bridge; the network
layer strips caller-supplied Authorization headers by design. The service
accepts HTTP error responses for local fixed-message mapping so it can inspect
Retry-After without changing shared network error contracts. Raw backend bodies,
credentials and personal values are never logged or exposed as errors.

`CustomerAuthService.get` is the Customer authenticated safe-read boundary:
refresh expired credentials, retry one 401 after serialized token rotation,
reuse a newer session when another request already refreshed it, clear on
refresh rejection or a repeated read 401. It does not replay writes. Future
Customer repositories must use this boundary for authenticated reads, rather
than expecting the raw shared ApiClient to refresh automatically.

Both tokens are saved together. Persistence is serialized so a late write cannot
restore credentials after logout. Generation checks reject late refresh results.
Refresh server/offline failure retains credentials for retry; rejected refresh
clears them. UI operations block duplicate submissions and disable fields while
busy. Error copy is fixed and no debug credential logging is installed.

## Verification

Tests use only an in-memory HTTP adapter and session store, including complete
register/verify/sign-out UI, exact public bodies, bearer handling, nullable email,
wrong roles, malformed responses, persistence failures, 429 cooldown,
single-flight refresh, concurrent read retries, startup errors, late refresh
after logout and narrow/large-text validation. No live backend mutations.

Phone OTP and Google Sign-In remain later milestones. No fake social sign-in,
password-reset endpoints or guessed Customer profile responses are added.

Final verification: all 31 Customer tests passed; Customer analysis found no
issues; formatting checked nine Dart files with no changes; configured Customer
debug APK build passed. Workspace analysis retains the existing Provider
withOpacity deprecation notice. Provider/shared code and lockfile were unchanged;
the previously reported Provider regression failures from milestone 1 were not
rerun or claimed resolved in this milestone. No live account mutations, commits,
pushes or PRs. Native interactive sign-in and deployed endpoint availability
remain manual verification steps.

## Provider-style auth presentation

Customer now uses the same authentication theme, decorative mint background,
155:77 care-promise logo, Nunito font, segmented mode tabs, above-field labels,
mail/lock icons, password visibility controls and reserved-slot primary action
as Provider. Marketing copy is Customer-specific. Original SVG assets and font
were copied unchanged into Customer's own asset bundle, including the font
license. The SVG renderer preserves original proportions and colors, expanding
the existing embedded-image pattern exactly as the Provider renderer does.
There are no cross-app imports or Provider source changes.

Google/Apple and legal/footer controls are disabled, consistent with Provider;
no social login, reset endpoint or legal URL was invented. Customer verification
recovery and 10–72-character registration validation remain operational. The UI
restyle does not change auth service/controller request or persistence behavior.

Verification: 31 Customer tests passed, Customer analysis clean, formatting clean,
configured debug APK built, real-font/real-asset preview test passed; registration preview visually inspected,
and 320px large-text registration checked without
overflow. Previews are under `apps/customer_app/build/auth-previews/`.
Workspace analysis still reports the existing Provider withOpacity deprecation.
A full relaunch is needed to load newly registered fonts/assets and dependencies.

## Login viewport fit

Sign-in uses a compact original-aspect logo, reduced spacing and field padding,
48px minimum action sizing and side-by-side disabled Google/Apple controls.
Redundant sign-in marketing text and the duplicate registration link are removed;
Create account remains available in the segmented tabs. Registration and OTP keep
their full layouts. No scale-down, clipping or text-scaling cap is used.

The scroll view naturally has zero scroll extent at standard text sizes on
360×800, 390×844 and 430×932 phones, including 24px top/bottom safe areas. It
still permits overflow scrolling with the keyboard, larger accessibility text,
validation errors or smaller screens so actions stay reachable. All 35 Customer
tests passed, Customer analysis and formatting are clean, and the real-asset
preview test passed.

Follow-up: login now displays the exact requested slogan, "Be there when care is
matter", below the original logo. Google and Apple are full-width stacked rows
again. Verify email and the disabled Forgot password action share a secondary
row to retain zero-scroll fit on the same three standard phone sizes. Social
actions stay disabled with explanatory tooltips; no authentication integration
changed. The visible compact social disclaimer was removed to avoid redundant
copy. Tests assert the exact slogan, equal-width vertical social rows and zero
scroll extent, alongside keyboard/large-text recovery and the existing auth flow.

The login slogan is now 24px bold with 16px above/24px below, and taller screens
add up to 40px of top breathing room to use spare vertical space. Viewport tests
load the shipped Nunito font rather than the test-only Ahem fallback so text
wrapping measurements match the app. All 35 Customer tests, the actual-widget
preview, Customer analysis, formatting and configured debug APK build passed.
