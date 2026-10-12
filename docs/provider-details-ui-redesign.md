# Provider Details UI modernization

1. **UI changes:** initial-onboarding Provider Details now uses the same bright branded presentation as Sign in/Create account: pale aqua edge shapes, compact proportional supplied logo, visible B there Provider label, centered bold title, muted supporting copy, aligned above-control labels, outlined fields and teal full-width Save profile. The initial header is shorter than the auth marketing hero. The service setup keeps its existing shell, title, availability control and return behavior; its reused profile controls receive the same presentation improvements.
2. **Reusable widgets:** added app-local `BrandedFormPage`; extracted `BThereBrandedBackground`, `BTherePrimaryButton` and `BThereInlineError` into the design system from the existing auth presentation. Added `BThereFieldGroup` for above-control labels on date, selectors and market states. Moved the unchanged supplied-artwork renderer to app-local `core/presentation/brand_image.dart` as `BThereBrandImage`, `BThereBrandAsset` and `BThereBrandAssetLoader`. Compatibility aliases keep existing auth callers/tests on that same renderer.
3. **Auth reuse:** uses the existing `BThereTheme.authentication()` bright palette, typography, spacing, input borders, CTA styling and original logo renderer. AuthBackground's marketing variant delegates to the extracted background; AuthPrimaryButton and decorated AuthFailureMessage delegate to the shared primary button/error primitives. Auth rendering, routing and business logic are unchanged. Provider Details has no auth controller, repository or route dependency.
4. **Design system:** only the four small presentation primitives and their exports were added. No new colors, fonts, dependencies, backend concepts or broad theme changes. Existing tokens remain the source of colors, spacing, borders and radii. Source SVGs are byte-identical to the supplied originals; no recoloring, distortion, cropping or new asset declarations.
5. **Responsive strategy:** SafeArea, LayoutBuilder, SingleChildScrollView, keyboard drag dismissal, 16/24/40 responsive horizontal padding and a 440 maximum content width. No fixed screen-height layout. Native background decoration remains behind controls, clipped, IgnorePointer and excluded from semantics. The footer/primary action is ordinary scroll content, reachable with the keyboard open. Provider Details intentionally uses the same local bright presentation under system dark mode as the redesigned auth screens.
6. **Fields/selectors:** first/last names retain controllers, autofill, required validation and Next actions, with person icons/placeholders. DOB remains read-only and wholly tappable with calendar icon; the original calendar-only picker, clock-derived today limit, minimum date, selected value and backend date serialization remain. Its dialog gets the same bright theme. Gender/Market keep enum values/numeric IDs and live data, with friendly labels, matching muted placeholders, leading icons, chevrons and above-control labels. Their taps unfocus the keyboard. Bio remains optional, multiline (3–5 lines), with notes icon, placeholder and newline action. No identity/photo fields added.
7. **Loading/errors:** markets load in an outlined inline state with labelled spinner; names remain editable. Existing error/retry and empty states remain, using the shared compact live-region error presentation. Submission failures appear above the CTA and preserve entered data. Save uses reserved progress slots so button dimensions remain stable and duplicate taps stay disabled. Existing save enablement is preserved: busy/readiness/selected active market govern the button, and existing required-field validation blocks invalid submission when pressed. Required fields were not turned into a new pre-submit enablement policy.
8. **API unchanged:** `GET /api/v1/markets` and `PUT /api/v1/providers/me/profile` behavior, auth requirements, repositories, controllers and payload serialization are unchanged. Required values remain firstName, lastName, dateOfBirth, gender, availabilityStatus and marketId. Initial onboarding still sends AVAILABLE. Names/bio are trimmed exactly as before; optional NIC/passport/photo/bio behavior remains. No new requests or backend fields, no manual date string entry and no raw Dio/backend errors exposed.
9. **Routing unchanged:** Email registration → Email verification → Provider Details + Market → Services remains. The same onSaved callback and entry-gate behavior run after successful save. Existing service-first setup return callbacks are preserved. No router, session, refresh, service or Documents business code changed.
10. **Tests:** added five Provider Details regressions: shared brand/style/disabled initial save; pending market loading retaining editable inputs and resolving to API choices; pending-save size stability, duplicate prevention, exact optional payload and visible failure with retained names; and narrow 320x480 surfaces with keyboard inset 200 and text scale 2.5 in both OS themes. Extended only the local onboarding HTTP adapter with a pending-market completer. Existing profile/domain/date-limit/enum/market-retry/payload/onboarding/service-first/Documents/auth tests remain green. Optional actual-widget visual preview tools pass separately.
11. **Workspace count:** 693 passed: Provider 481; Customer 1; Design System 21; Network 46; Session 12; Auth 129; Common 3. Preview-tool tests are excluded from this count.
12. **Analysis:** all seven members pass, and final root `dart analyze` reports no issues.
13. **Formatting:** `dart format --output=none --set-exit-if-changed apps packages` passes with zero changes. Root `dart pub get` passed; no dependency or manifest edits needed.
14. **APK:** final `flutter build apk --debug --no-pub` succeeds. Output: `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`. No live backend data was mutated; repositories in UI previews/tests are replaced with local fixtures.
15. **Exact source/documentation files changed:**

- `apps/provider_app/lib/core/presentation/brand_image.dart` (new; unchanged renderer moved here)
- `apps/provider_app/lib/core/presentation/branded_form_page.dart` (new)
- `apps/provider_app/lib/features/onboarding/profile/presentation/provider_profile_screen.dart`
- `apps/provider_app/lib/features/auth/widgets/auth_background.dart`
- `apps/provider_app/lib/features/auth/widgets/auth_brand_image.dart` (compatibility aliases)
- `apps/provider_app/lib/features/auth/widgets/auth_page.dart`
- `apps/provider_app/lib/features/auth/widgets/auth_primary_button.dart`
- `packages/bthere_design_system/lib/bthere_design_system.dart`
- `packages/bthere_design_system/lib/src/widgets/bthere_branded_background.dart` (new)
- `packages/bthere_design_system/lib/src/widgets/bthere_field_group.dart` (new)
- `packages/bthere_design_system/lib/src/widgets/bthere_inline_error.dart` (new)
- `packages/bthere_design_system/lib/src/widgets/bthere_primary_button.dart` (new)
- `apps/provider_app/test/email_registration_onboarding_test.dart`
- `apps/provider_app/test/provider_details_redesign_test.dart` (new)
- `apps/provider_app/tool/provider_details_preview_test.dart` (new)
- `docs/provider-details-ui-redesign.md` (new)

## Visual QA

Rendered real Provider Details and both auth screens at 430x1100 and compared background, margin, field height, icon scale, border/radius, typography hierarchy and primary button. Details reuses the same styles and compact header rather than the auth marketing hero. Preview: `apps/provider_app/build/provider-details-previews/provider-details.png`. Normal Save profile height is 56; field spacing is 16 with 24 separating title/form and form/action. Native decoration and platform font fallback match the existing auth implementation. No Nunito font files are supplied, so exact platform typography remains subject to the same existing fallback.

Regenerate from `apps/provider_app`:

```powershell
flutter test --no-pub --dart-define=FLUTTER_SDK=<path-to-your-flutter-sdk> tool/provider_details_preview_test.dart tool/auth_ui_preview_test.dart
```

The optional preview renderer loads local SDK fonts only for test rendering; it does not add production fonts or dependencies. Screenshots and APK are generated build artifacts, not source changes.

No commit, push or PR created.
