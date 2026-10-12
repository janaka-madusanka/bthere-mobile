# Confirmed Provider gender values

The backend-confirmed authoritative enum is exactly:

| UI label | Dart value | API wire value |
| --- | --- | --- |
| Male | ProviderGender.male | MALE |
| Female | ProviderGender.female | FEMALE |

`ProviderGender.female` was added alongside Male. The existing bottom sheet already builds its rows from `ProviderGender.values`, so it now displays both without changing the selector component. Selected labels, highlights, checkmarks, reopening, cancellation, keyboard behavior and accessibility remain intact. No other enum values were introduced.

## Serialization and parsing

The existing profile serializer remains unchanged and sends the selected `gender.wireValue` to PUT `/api/v1/providers/me/profile`, exactly `MALE` or `FEMALE`. Names, date, availability, marketId and optional fields retain their existing payload behavior.

Added `ProviderGender.tryParse(Object?)` for the confirmed field values. It accepts exact `MALE`/`FEMALE`; null, unknown, lowercase, display labels and non-string values return null rather than inventing a default gender. This is an enum decoder, not a GET profile response parser.

The user confirmed that GET `/providers/me/profile` has no documented response example, missing-profile semantics, profileCompleted response contract or incomplete-profile object definition. Provider Details remains a creation/onboarding form. No GET request, automatic prefill/restoration, read-profile object model or new routing logic was added. Authenticated routing continues using the existing documented completion endpoint. Backend GET-based restoration remains a contract gap until those details are confirmed; its tests are deferred accordingly.

## Tests and verification

Three new unit tests check both exact enum parsing/serialization with every other payload field unchanged, plus unsupported/malformed values. Updated the original Male-only enum assertion to require exactly MALE and FEMALE. The existing parameterized selector regression now executes for Female too: both rows are present, each selection stores the corresponding Dart enum, selected semantics/checkmark restore after reopening, the sheet closes and the real local HTTP adapter receives the exact wire value. All existing profile submission, market, registration, service-first and Documents tests remain green.

- `dart pub get`: passed; no dependency or manifest changes.
- Workspace tests: **703 passed** — Provider 491, Customer 1, Design System 21, Network 46, Session 12, Auth 129, Common 3.
- All seven members analyzed successfully; final root analysis reports no issues.
- Formatting check: `dart format --output=none --set-exit-if-changed apps packages` passed with zero changes.
- Provider debug APK: `flutter build apk --debug --no-pub` passed; artifact `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`.
- Optional actual-widget preview tool passes separately and shows both options. No live backend data mutated.

## Exact files changed

- `apps/provider_app/lib/features/onboarding/profile/domain/provider_profile_input.dart`
- `apps/provider_app/test/provider_profile_test.dart`
- `apps/provider_app/test/provider_gender_test.dart` (new)
- `docs/provider-complete-profile.md`
- `docs/provider-details-selectors.md`
- `docs/provider-email-registration-onboarding.md`
- `docs/provider-gender-values.md` (new)

The profile presentation, serializer, repositories, controllers, routes and shared selector implementation remain unchanged. Existing preview tooling is reused; generated images/APK are build artifacts.

No commit, push or PR created.
