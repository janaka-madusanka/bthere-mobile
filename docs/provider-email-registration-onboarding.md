# Provider email registration onboarding

Implemented 2026-10-11. This report supersedes older authenticated-landing descriptions. Automated tests use local responses; no live account was created, no backend record was deleted, and no commit, push, or PR was made.

## Reused implementation

The existing Login/Create account tabs, email registration and verification screens/controllers, shared `bthere_auth` DTOs/repository/role checks, `bthere_network` transport and token bridge, `bthere_session` secure storage/expiry, Design System, Provider profile form/repository/serializer, market loader, and completion API are reused. Service catalog/detail/setup/Documents behavior remains service-first after account prerequisites. Google remains dormant.

## Routes and state transitions

`/auth` → Create account → `/auth/register/email` → successful 201 → `/auth/verify-email` with transient email-only route context → successful verification and awaited secure persistence → `/onboarding/profile` → acknowledged profile PUT → `/services`.

Registration creates an account, never an authenticated session. Email and passwords are trimmed differently: email is trimmed; password is unchanged. Password/confirmation controllers are cleared on successful registration and disposed when leaving. Confirmation is client-only. Verification retains neither password nor OTP in route/storage state. There is no active resend action.

Fresh verification explicitly requires Provider Details without relying on an undocumented profile-read/missing response. The router verifies local session restoration before allowing the authenticated form. Authenticated users cannot return to registration or OTP. Profile save uses `go` and the completed account gate: Services cannot pop back into the completed form, and direct `/onboarding/profile` links redirect to Services. The stable router survives session transitions.

## Exact API contracts

The externally supplied `BTHERE_API_BASE_URL` includes `/api/v1`; relative paths below add no second prefix.

| Method/path | Authentication | Payload |
| --- | --- | --- |
| POST `/auth/register` | false | Exactly `email`, `password`, `accountType: SERVICE_PROVIDER` |
| POST `/auth/email/verify` | false | Exactly `email`, `otp` |
| POST `/auth/login` | false | Exactly `identifier`, `password` (existing contract) |
| GET `/providers/me/completion` | true | No request body; existing response parser |
| GET `/markets` | true | No request body; existing active-market parser |
| PUT `/providers/me/profile` | true | Exactly the ten fields below |

```json
{"email":"<trimmed email>","password":"<unchanged password>","accountType":"SERVICE_PROVIDER"}
```

```json
{"email":"<registered email>","otp":"<trimmed entered code>"}
```

```json
{
  "firstName": "<trimmed first name>",
  "lastName": "<trimmed last name>",
  "nicNumber": null,
  "passportNumber": null,
  "dateOfBirth": "YYYY-MM-DD",
  "gender": "MALE",
  "profilePhoto": null,
  "bio": null,
  "availabilityStatus": "AVAILABLE",
  "marketId": 42
}
```

The example market ID 42 represents a selection returned by the API, not a hard-coded default. Existing optional Bio is retained: trimmed nonblank text is sent, otherwise null. No NIC, passport, or photo controls are added. The subsequently confirmed MALE and FEMALE gender options are offered with exact uppercase wire values. DOB uses the existing calendar-only picker, calendar-component YYYY-MM-DD serializer, and future-date guard, with no invented minimum age. Initial registration hides Availability and initializes AVAILABLE; existing service Basic details retains its editing controls.

Markets display API market names and submit their actual positive IDs. Only ACTIVE markets can be submitted. There is no hard-coded country or market ID. Loading, error/Retry markets, empty result, and invalid/removed selection prevent a profile request while preserving editable inputs.

## Secure session

Both verification and Login use the same shared auth persistence path. It checks SERVICE_PROVIDER, validates the response, computes UTC expiry from expiresIn, and awaits the secure write before returning success. One existing secure record contains accessToken, refreshToken, tokenType, expiresAt, and now optional typed account `user` metadata. The new metadata copies the validated AuthUser fields; Session does not depend on Auth. Legacy records without user metadata remain readable. Corrupt user metadata cannot restore a partial session. Failed writes preserve the prior complete record according to existing storage behavior.

No password or OTP is stored or logged. Session/account objects do not stringify sensitive values. Existing expiry and authentication error handling are preserved. The audited client has no automatic token-refresh request, rotation coordinator, or Remember Me switch; refreshToken persistence exists, but refresh/rotation behavior cannot be claimed as implemented. No undocumented endpoint or parallel session format was added.

## Authenticated entry gate

As clarified by the user, routing uses **GET `/providers/me/completion`**, not GET profile:

- `profileCompleted == false`, `marketSelected == false`, `nextStep == COMPLETE_PROFILE`, or `nextStep == SELECT_MARKET` → Provider Details.
- Both account flags complete and a later documented step → Services, including SELECT_SERVICE, COMPLETE_SERVICE_REQUIREMENTS, AWAIT_ADMIN_APPROVAL, and COMPLETED.
- Pending lookup → startup spinner.
- Failed, unauthorized, malformed, unsupported, offline, or timed-out lookup → visible existing safe failure plus Retry account setup. These are never treated as a missing profile. No session is deleted on account-check failure.

The gate shares the existing completion controller's entry response and reads it once per authenticated entry. Later service completion refreshes do not replace a service route with global onboarding. An acknowledged authenticated profile PUT with the selected market satisfies the current-entry gate; completion is refreshed as before. A new app process or new authenticated entry checks backend completion again. Local state cannot approve a service.

## Errors and busy behavior

Registration keeps existing inline required/email/password 10–72 code-point/confirmation validation, conflict/network/server feedback and retry. Verification keeps required numeric-keyboard OTP, safe invalid/expired-code/network/server failures and retry. No unsupported six-digit length rule is imposed. Registration and verification guard both pending and already-successful submissions; profile guards pending/saved submissions and validates loaded ACTIVE market membership. Primary actions and navigation are locked during active submissions. Failures restore controls and retain safe editable inputs. Profile rejection never enters Services. Lookup retry coalesces repeated requests.

## Tests and workspace verification

New app integration tests use the **real auth, profile, market, completion and network repositories** with an in-memory HTTP adapter and session-storage test double. They cover:

- Complete registration/verification/profile/save/restart sequence, exact request keys, no registration session, fixed Provider account type, no confirmation payload, public/auth request metadata and bearer headers, unchanged passwords, secure token/user/expiry mapping, actual market ID 42 and null optional fields.
- Verified-but-unfinished restart, complete/incomplete account flags and every documented nextStep, auth/service deep-link guards, completed-form back safety, and service-only incomplete flags.
- Completion loading, 401/404/500/offline/timeout/malformed errors, retry and double retry; market failure/empty retry; profile required fields, rejection/value preservation, double submit and successful retry; identifier login entering incomplete onboarding.

Four new shared Session tests cover metadata round-trip/immutability, legacy records, malformed records, and secure-write failure preservation. Existing shared Auth tests now assert identical stored user metadata for all common authenticated operations. Existing registration/email validation, wrong-role/persistence/expiry, market/DOB/payload, service-first, Documents and dormant Google tests remain regression coverage. Existing verification-success route expectations now require Provider Details. Service-first/Documents/profile/market test bodies and assertions are preserved; only their fixtures declare the already-completed account prerequisite through `CompletedEntryGate`. Separate real-gate integration tests validate that prerequisite itself. No existing Session regression assertions were changed.

Final verification:

| Member | Passing tests | Analysis |
| --- | ---: | --- |
| customer_app | 1 | Clean |
| provider_app | 468 | Clean |
| bthere_design_system | 19 | Clean |
| bthere_network | 46 | Clean |
| bthere_session | 12 | Clean |
| bthere_auth | 127 | Clean |
| bthere_common | 3 | Clean |
| **Total** | **676** | **All seven clean** |

26 tests added (22 Provider integration tests and 4 Session storage tests); the previous workspace total was 650. Root `dart pub get` succeeded without changing resolved package versions. All seven suites and member analyses exited 0; the additional whole-root analysis was also clean. Formatting check covered 158 Dart lib/test files and reported 0 changes. `flutter build apk --debug --no-pub` succeeded and generated `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`. The APK was built without a live API URL define; the existing configuration-required startup behavior applies until a real URL is supplied.

Verification logs are under the Windows temporary directory as `bthere-registration-tests-{member}.log`, `bthere-registration-analysis-{member}.log`, and `bthere-registration-apk.log`.

## Backend contract gaps

The authoritative document lists GET `/providers/me/profile` but provides no complete/incomplete/missing response examples. No GET profile parser or 404/missing inference was invented; it is not needed for the explicitly documented completion gate. Email registration is expected to deliver the OTP; email delivery itself must be verified live. No documented email resend endpoint exists, so no resend request is implemented. The confirmed gender contract now supports MALE and FEMALE; GET profile schema/restoration remains unresolved. The existing client lacks refresh/rotation and Remember Me behavior, as noted above.

## Manual live test

Build/run with your actual API URL including `/api/v1`, for example `flutter run --dart-define=BTHERE_API_BASE_URL=<actual-base-url>` from apps/provider_app. The automated debug build does not embed a guessed live URL; without the define the app shows the existing configuration-required state.

1. Open Provider with the correct backend configuration.
2. Select Create account from Login.
3. Enter a fresh test email, a 10–72-character password, and matching confirmation.
4. Submit and confirm an OTP email arrives; confirm Verify Email shows the trimmed email.
5. Enter the received OTP.
6. Verify email; confirm the busy indicator and authenticated transition only after persistence.
7. Confirm Provider Details appears before Services and registration cannot be reopened.
8. Confirm markets load from the live backend and select a real active market.
9. Fill first/last name, pick a non-future DOB, and select a documented gender; optional Bio may stay blank.
10. Save profile once; confirm AVAILABLE and the selected API market ID in a safe backend inspection without exposing credentials.
11. Confirm Services and the existing main-service/sub-service/setup/Documents flow; Back must not reopen the completed account form.
12. Kill the app process without clearing app data, then reopen.
13. Confirm completion lookup and restored session enter Services directly when profile and market are complete.

Separate incomplete-profile restart: use a second fresh test account, complete email verification, then kill the app at Provider Details **before saving**. Reopen without clearing secure storage. Confirm the documented incomplete completion flags route back to Provider Details and markets load; no second registration, new OTP request, or backend deletion is needed. Save afterward to finish that account. Also test invalid/expired OTP, duplicate email, temporary connectivity loss and Retry; do not assume email delivery or backend contracts were live-validated by the automated tests.

## Exact source/document manifest

New:

- `apps/provider_app/lib/features/onboarding/application/provider_entry_gate.dart`
- `apps/provider_app/test/email_registration_onboarding_test.dart`
- `apps/provider_app/test/support/completed_entry_gate.dart`
- `packages/bthere_session/lib/src/models/session_user.dart`
- `packages/bthere_session/test/session_user_storage_test.dart`
- `docs/provider-email-registration-onboarding.md`

Updated:

- `apps/provider_app/pubspec.yaml` (test-only direct Dio dependency; existing resolved transport version)
- `apps/provider_app/lib/app/router/app_router.dart`
- `apps/provider_app/lib/features/auth/application/email_registration_controller.dart`
- `apps/provider_app/lib/features/auth/application/email_verification_controller.dart`
- `apps/provider_app/lib/features/onboarding/profile/application/provider_profile_controller.dart`
- `apps/provider_app/lib/features/onboarding/profile/presentation/provider_profile_screen.dart`
- `apps/provider_app/lib/features/startup/presentation/startup_screen.dart`
- `apps/provider_app/test/email_auth_screen_test.dart`
- `apps/provider_app/test/provider_documents_test.dart` (fixture only)
- `apps/provider_app/test/provider_market_test.dart` (fixtures only)
- `apps/provider_app/test/provider_profile_test.dart` (fixtures only)
- `apps/provider_app/test/service_first_test.dart` (fixture only)
- `packages/bthere_session/lib/bthere_session.dart`
- `packages/bthere_session/lib/src/models/auth_session.dart`
- `packages/bthere_session/lib/src/storage/secure_session_storage.dart`
- `packages/bthere_auth/lib/src/data/repositories/provider_auth_repository_impl.dart`
- `packages/bthere_auth/test/bthere_auth_test.dart`
- `docs/provider-password-sign-in.md`
- `docs/provider-service-first.md`

Generated build/tool artifacts are separate from this source manifest. Provider APK: `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`.
