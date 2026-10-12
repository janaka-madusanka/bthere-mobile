# Provider Google authentication — deferred

Google OAuth is temporarily deferred because backend OAuth configuration is
unavailable. The isolated implementation, dependency, official asset and tests
are retained for future use, but no Google action, social divider, disabled
button, coming-soon message or configuration error is exposed in Provider UI.
The current active UI defaults to email/password Sign in and offers Create account
for email/password registration → email OTP verification → authenticated session
→ `/onboarding` → backend-selected destination. Login reuses Auth-owned persistence. Registration creates no session; OTP
verification awaits existing Auth session persistence before local refresh and
routing. Google OAuth, Apple auth and phone OTP UI are deferred.
The completion gateway is implemented; full onboarding forms remain deferred.

## Ownership and lifecycle

`google_sign_in` 7.2.0 is a dependency only of `apps/provider_app`; no Firebase
packages are used. App composition owns a non-auto-disposed
`GoogleIdentityProvider` implemented by `GoogleSignInIdentityProvider`.
It uses `GoogleSignIn.instance`, lazily initializes once on the first user
action with the configured Web server client ID, and caches that initialization
future (including failure). Route/controller recreation does not reinitialize
the SDK. Configuration is immutable for the app lifetime; restart after changes.
Startup does not launch a chooser, request scopes or perform silent Google auth.
The entry screen does not read the Google controller or identity provider, so
neither is constructed by the active email flow. Native plugin registration
sets up channels only; it does not initialize Google OAuth or select an account.
`BTHERE_GOOGLE_SERVER_CLIENT_ID` is optional and unnecessary for normal startup;
only `BTHERE_API_BASE_URL` is currently required.

The auto-disposed Google controller blocks duplicate taps through chooser and
backend exchange when explicitly exercised by tests or future integration. Null
identity results mean user cancellation: idle, no error, no backend call and no
session. Structured plugin cancellation is handled separately from failures.
Configuration, missing-token and identity failures use fixed safe messages;
plugin descriptions, details and stack traces never reach presentation.

The app passes only the transient ID-token string to the platform-independent
`ProviderAuthRepository.authenticateProviderWithGoogle`. Auth posts
`/auth/google` with `requiresAuth: false` and body:

```json
{"idToken": "<transient Google ID token>", "type": "SERVICE_PROVIDER"}
```

The configured API base URL includes `/api/v1`. Google access tokens are not
used as B there credentials. Shared Auth reuses its internal token response
parser and trusted persistence flow: require `SERVICE_PROVIDER`, validate token
metadata, calculate UTC `expiresAt` from `expiresIn`, await `SessionStorage.write`
and return safe `AuthUser`. Wrong roles, malformed responses, network failures
and storage failures return safe `Failure`. A failed secure write never reports
successful authentication. The controller invalidates local app session state
only on repository success; the router enters the completion gateway after the
persisted session is reread successfully. Only nextStep COMPLETED reaches `/home`. The B there session is authoritative.
The app does not log or persist the Google ID token or expose any raw tokens in
Riverpod presentation state.

## Android setup required outside this repository

1. Configure the Google Cloud OAuth consent screen (branding, audience and
   applicable test users/publication) in the project used by the backend.
2. Create an Android OAuth client for package `com.bthere.provider` with the
   actual SHA-1 signing certificate fingerprint for each build distributed.
   Debug, production release and Google Play app-signing certificates may differ.
   Obtain actual fingerprints from Gradle `signingReport` or the relevant signing
   certificate/Play Console; never guess. Current release scaffolding uses the
   debug signing configuration and must be configured separately for production.
3. Obtain the Web OAuth client ID the B there backend accepts as its ID-token
   audience. The backend must accept that exact audience. Pass it as
   `BTHERE_GOOGLE_SERVER_CLIENT_ID`; this is not the Android client ID.
4. Restart/build the app with external values:

```powershell
flutter run -d emulator-5554 `
  --dart-define=BTHERE_API_BASE_URL=<API base URL ending in /api/v1> `
  --dart-define=BTHERE_GOOGLE_SERVER_CLIENT_ID=<backend Web OAuth client ID>
```

No `google-services.json`, Firebase initialization or Google Services Gradle
plugin is needed for this direct Google Cloud setup with explicit serverClientId.
No OAuth ID, SHA fingerprint or private configuration file has been fabricated.
The dormant adapter returns a controlled failure if invoked without its server
client configuration; current UI never invokes it or displays that error.
The Android SDK can also report cancellation for some OAuth
misconfigurations after account selection; if it happens repeatedly, check the
package, certificate and server client ID rather than interpreting it as backend
rejection.

## iOS setup pending Mac verification

Register an iOS OAuth client for bundle ID `com.bthere.provider` in the relevant
Google Cloud project. On a Mac, configure the actual iOS client ID as
`GIDClientID` in `ios/Runner/Info.plist` and the matching reversed client ID in
`CFBundleURLTypes` / `CFBundleURLSchemes`. The adapter obtains its serverClientId
from the same external Web-client define. Do not put the Android client ID in
the iOS client field. Real identifiers and URL schemes are not available here,
so no fake plist entries were added. Configure, build and test the real chooser,
callback and token audience on a Mac/iOS device. iOS is not verified on Windows.

## Verification

Tests use a fake Google identity provider and repositories/storage or an
in-memory transport. They never open an account chooser or call a live backend.
Coverage includes loading/duplicates, cancellation/retry, missing token/config,
safe errors, disposal, fixed public payload, malformed responses, wrong roles,
expiry, secure-write failure/waiting, session reread and authenticated routing.
The existing email validation, visibility, busy, persistence and layout tests
remain in place. Real Google login remains unverified until actual OAuth and
backend audience configuration are supplied.

Google deferral baseline verification: root `dart pub get`, clean analysis of all seven
workspace members, 270 passing workspace tests (Provider 95, Customer 1,
Common 3, Network 46, Session 8, Auth 98, Design System 19), formatting and
Provider `flutter build apk --debug`. Google controller/repository coverage is
retained through explicit fake-only tests, and the unused button is tested in
isolation. The active UI tests assert password Sign in/registration and no Google provider
construction. Emulator verification uses only the API base URL, without a Google
client ID; entry and email registration remain usable without exposing Google.
No account chooser, live login or backend form submission is performed.

Provider Android disables Kotlin incremental compilation because the selected
plugin's Kotlin 2.3 compiler fails to relativize Windows paths when the Pub cache
and repository are on different drives. Full compilation preserves app behavior
at the cost of incremental build speed. A transient Maven TLS download problem
was resolved using the official artifact and verifying its published checksum;
no alternate repository or weakened TLS settings are committed.

Official references:
- [google_sign_in 7.2.0 API and usage](https://pub.dev/packages/google_sign_in/versions/7.2.0)
- [Android integration](https://pub.dev/packages/google_sign_in_android/versions/7.2.17)
- [iOS integration](https://pub.dev/packages/google_sign_in_ios/versions/6.3.6)
- [Google branding and official assets](https://developers.google.com/identity/branding-guidelines)
