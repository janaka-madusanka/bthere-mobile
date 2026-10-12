# Provider Details modal selectors

1. **Why only Male was shown:** the previous popup generated options from `ProviderGender.values`, and the enum at that time contained only `male('MALE', 'Male')`. This was an intentionally limited client contract, not a dropdown filtering bug. Earlier profile documentation explicitly recorded the full backend gender enum as unresolved.
2. **Confirmed gender update:** the backend subsequently confirmed the complete authoritative enum as `MALE` and `FEMALE`. Both are now offered through the same enum-driven sheet, with Male/Female display labels and exact uppercase serialization. The former gender-enum gap is resolved; GET profile restoration remains undocumented. See [confirmed gender support](provider-gender-values.md). Verification counts below record the earlier selector refactor.
3. **Gender:** replaced the tiny popup with a rounded modal sheet titled Select gender, a drag handle, comfortable option rows, selected checkmark/highlight and selected screen-reader state. Tapping an option updates the existing `_gender` and closes the sheet; reopening marks the selected value. Cancelling keeps the value. The outlined field retains its person icon, above label, muted placeholder and down chevron.
4. **Market:** uses the same `BThereSelectorField<T>` design-system primitive, with Select market title and location icon. Options are built exclusively from the existing active-market repository result: names are displayed and numeric IDs stored. Loading/error/retry/empty behavior is unchanged. Long lists scroll; the title and rows share the scroll area so large text cannot crowd options out of the viewport. Open sheets snapshot their rows; a choice removed from the current options during refresh is ignored.
5. **Backend serialization:** unchanged `PUT /api/v1/providers/me/profile` payload, existing `.wireValue` serializer, enum/domain model, availability default, trimming, date formatting and optional fields. Male still sends `MALE`, never `Male`. Market selection still sends numeric marketId, not a name. `GET /api/v1/markets` loading/retry behavior, profile controller, secure sessions and onboarding/service-first routing remain unchanged. No live backend mutation or API enum speculation was performed.
6. **Tests:** six new UI regressions cover supported gender labels, MALE serialization, reopening selected gender and semantics/checkmark/minimum touch size; API-sourced market names/reopening and exact ID 98 submission; keyboard dismissal before/after sheet selection; cancelled selection; removed market choice during an open sheet; and 30-option scrolling on 320x480 with 2.5x text. Existing profile/market assertions now inspect the new FormField type, preserving validation, busy callbacks, market refresh and submission checks. All existing auth/onboarding/service-first/Documents regressions remain green. Optional actual-widget previews pass separately.
7. **Workspace count:** 699 passed: Provider 487; Customer 1; Design System 21; Network 46; Session 12; Auth 129; Common 3. Preview tests are excluded from this count.
8. **Analysis:** all seven workspace members pass; final root analysis reports no issues. `dart pub get` succeeds with existing dependencies; no dependency/manifests changed.
9. **Formatting:** `dart format --output=none --set-exit-if-changed apps packages` passes with zero changes.
10. **APK:** `flutter build apk --debug --no-pub` passes. Artifact: `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`.
11. **Exact source/documentation files changed:**

- `packages/bthere_design_system/lib/bthere_design_system.dart`
- `packages/bthere_design_system/lib/src/widgets/bthere_selector_field.dart` (new)
- `apps/provider_app/lib/features/onboarding/profile/presentation/provider_profile_screen.dart`
- `apps/provider_app/test/provider_profile_test.dart`
- `apps/provider_app/test/provider_market_test.dart`
- `apps/provider_app/test/provider_selector_test.dart` (new)
- `apps/provider_app/tool/provider_details_preview_test.dart`
- `docs/provider-details-selectors.md` (new)

## Interaction and accessibility

The shared selector uses the existing theme, label-group, border, spacing and radius tokens. Its entire outlined control responds to taps; it has a button role, labelled value, enabled state and accessible validation hint/live region. It has its own focus node and opens no text editor. Before and after the modal, it dismisses text input; returning focus to the selector prevents the preceding name input reopening the keyboard. Busy fields have disabled/null callbacks and repeated taps cannot open duplicate sheets. Selected rows expose selected semantics and a checkmark in addition to the subtle teal fill. Row touch height is at least 56 at normal scale and grows with wrapped text. Bottom sheets have safe areas and a 70%-viewport maximum, shrink to content for short lists, and allow normal scrolling for long lists and enlarged text.

## Visual QA

Reviewed real-widget renders of Gender and Market, including selected states, against the existing bright Provider Details presentation. Sheets retain the same navy text, teal accents, white surface and rounded corners. Generated artifacts under `apps/provider_app/build/provider-details-previews/`:

- `gender-sheet.png`
- `gender-selected-sheet.png`
- `market-sheet.png`
- `market-selected-sheet.png`

Regenerate from `apps/provider_app`:

```powershell
flutter test --no-pub --dart-define=FLUTTER_SDK=<path-to-your-flutter-sdk> tool/provider_details_preview_test.dart
```

The preview uses local synthetic fixtures and SDK fonts only for test rendering. It changes no production assets/fonts or backend data. Existing brand SVGs and auth UI remain unchanged.

No commit, push or PR created.
