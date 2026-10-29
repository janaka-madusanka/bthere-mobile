# Customer foundation — milestone 1

Customer now has an app-local bootstrap, configuration, go_router routes and
Riverpod composition. It reuses Design System, Network and Session; no Provider
feature imports or shared-package changes are introduced.

Run from `apps/customer_app`:

```powershell
flutter run --dart-define-from-file=../../config/customer.local.json
```

The URL must include `/api/v1`. Credentials, query strings, fragments and
whitespace are rejected. Release configuration requires HTTPS; debug accepts
HTTP for local development. Missing/invalid configuration renders a dedicated
startup error. Configured startup shows a temporary Customer foundation screen.
Neither startup path reads storage or makes HTTP calls.

The lazy API client uses the existing transport and closes with its provider.
Secure session storage is wired through the existing platform adapter. The
app-local access-token bridge supplies a token only for an unexpired session
whose user roles contain CUSTOMER. Missing metadata supplies no token; storage
failures propagate. This is not authentication restoration or backend validation.
Auth/session restoration, serialized refresh, users/me validation and profile
entry routing belong to milestone 2/3. No protected Customer feature is exposed.

Android uses the Customer display label and INTERNET permission. Existing native
application identities are retained. No live API mutations, commits or pushes.

## Verification

- Workspace `dart pub get`: passed; root lockfile unchanged.
- Customer tests: 11 passed, covering startup with/without configuration and
  zero startup API/storage calls, URL validation, role/expiry/missing metadata,
  storage failure propagation and narrow large-text layout.
- Shared package tests: design system 23, network 48, session 13, auth 157,
  common 3; all 244 passed.
- Provider regression suite: 657 passed, 28 failed, including pumpAndSettle
  timeouts and golden mismatches. Provider source and shared packages were not
  changed. These failures remain unresolved; no golden baselines were updated.
- Customer analysis: no issues. Workspace analysis: one existing Provider
  deprecated withOpacity notice in service_catalog_visuals.dart:39.
- Customer formatting: five files checked, no changes.
- Customer debug APK: built successfully at
  `apps/customer_app/build/app/outputs/flutter-apk/app-debug.apk`.
- Native device launch and iOS build have not been verified.

Next milestone: email authentication, customer role validation, secure session
lifecycle/refresh and current-user validation. No authentication UI is connected
in this foundation milestone.
