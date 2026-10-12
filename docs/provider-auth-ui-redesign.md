# Provider authentication UI redesign

1. **Screens:** `AuthEntryScreen` (Sign in) and `EmailRegistrationScreen` (Create account). Both use the bright marketing layout. Email verification retains its existing presentation and navigation.
2. **Reusable components:** `AuthPage` owns safe scrolling, shared hero, mode switch, social area, account switch and footer. Updated `AuthBrandHeader`, `AuthBackground`, `AuthFlowSwitcher` and compact opt-in `AuthFailureMessage`; added `AuthPrimaryButton`, `AuthSocialButtons`, `AuthAgreementRow`, `AuthExistingAccountLink`, `AuthFooterLinks`. Existing design-system fields/buttons and original asset renderer are reused.
3. **Assets:** `apps/provider_app/assets/branding/bthere_logo_care_promise.svg`, `google_logo.svg`, `apple_logo.svg`. All three already declared in the app manifest. Their source contents, proportional sizing, original colors and original rendering compatibility adapter are unchanged. No dependency or manifest changes in this refactor.
4. **Tokens:** added accessible `primaryAction` (#087F89), large-text `primaryEmphasis` (#008F95), and segmented radius 32. Added opt-in `BThereTheme.authentication()` with a light palette, bold two-line headline, thin field/social outlines, flat teal CTA and checkbox styling. Global light/dark themes and other feature presentations remain unchanged.
5. **Responsive behavior:** SafeArea, LayoutBuilder, scrollable content, responsive 16/24/40 horizontal padding, maximum content width 440, natural field/error heights, wrapping divider/consent/footer and keyboard drag dismissal. Footer uses available space on tall screens and follows content when scrolling is needed. Decorative native shapes are clipped, excluded from semantics and ignore taps. Primary buttons reserve matching progress slots to keep dimensions stable.
6. **Sign in:** unchanged `/auth/login`, `requiresAuth: false`, exact identifier/password payload, identifier trimming, unchanged password, SERVICE_PROVIDER validation, secure persistence, expiry restoration and completion-based entry routing. The visible Email address label and existing username support are preserved.
7. **Registration:** unchanged `/auth/register`, trimmed email, unchanged password, SERVICE_PROVIDER accountType. Confirm password and consent are never serialized. Existing 10–72 validation and mismatch validation remain. Registration creates no session; verification then Provider Details/market then Services remains intact. Frontend checkbox is local UI state and does not introduce a new submission requirement.
8. **Errors:** sign-in/registration opt into a compact wrapping accessible inline error container; OTP retains its previous error presentation. Registration HTTP 409 now returns `AUTH_EMAIL_ALREADY_REGISTERED` with “This email is already registered. Sign in instead.” Other operations retain their conflict behavior. Invalid-response copy becomes “The server could not complete the request. Please try again.” Classification, role/session validation and safe network normalization otherwise remain unchanged; no raw response/JWT/stack trace appears in widgets.
9. **Social:** supplied Google/Apple marks appear in disabled outlined buttons, with unavailable tooltip/caption and null callbacks. No OAuth initialization, Firebase setup, Apple package, fabricated success or Google reactivation.
10. **Forgot password:** visible, right-aligned, disabled and explains unavailability through a tooltip. No documented route/backend flow exists; no endpoint added.
11. **Legal:** consent checkbox has accessible semantics; emphasized legal text and disabled Privacy/Terms footer match the structure. No existing destinations were found, so none are invented. Already-have-an-account Sign in uses the existing replacement route.
12. **Tests:** updated email UI, login, widget and dormant-Google expectations; existing DTO/session/OTP/onboarding/service-first/Documents regressions remain. Added 5 UI regressions for local consent/disabled controls and loading dimensions at normal/2.5x text scale. Added registration-specific 409 and login-conflict isolation tests, plus auth-theme and accessible contrast tests. Existing independent password toggles, logo rendering, validation, busy prevention and keyboard/narrow-screen checks pass.
13. **Workspace tests:** 688 passed: Provider 476; Customer 1; Design System 21; Network 46; Session 12; Auth 129; Common 3. The optional visual preview tool is separate from this count.
14. **Analysis:** all seven members pass; root analysis also reports no issues.
15. **Formatting:** workspace check clean (`dart format --output=none --set-exit-if-changed apps packages`).
16. **APK:** `flutter build apk --debug --no-pub` passed; output `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`. No live backend mutations or account creation performed.
17. **Exact source/documentation files changed by this refactor:**

- `apps/provider_app/lib/features/auth/presentation/auth_entry_screen.dart`
- `apps/provider_app/lib/features/auth/presentation/email_registration_screen.dart`
- `apps/provider_app/lib/features/auth/widgets/auth_background.dart`
- `apps/provider_app/lib/features/auth/widgets/auth_brand_header.dart`
- `apps/provider_app/lib/features/auth/widgets/auth_flow_switcher.dart`
- `apps/provider_app/lib/features/auth/widgets/auth_page.dart`
- `apps/provider_app/lib/features/auth/widgets/auth_primary_button.dart` (new)
- `apps/provider_app/lib/features/auth/widgets/auth_support_controls.dart` (new)
- `apps/provider_app/test/email_auth_screen_test.dart`
- `apps/provider_app/test/login_test.dart`
- `apps/provider_app/test/widget_test.dart`
- `apps/provider_app/test/google_auth_test.dart`
- `apps/provider_app/test/auth_redesign_test.dart` (new)
- `apps/provider_app/tool/auth_ui_preview_test.dart` (new)
- `apps/provider_app/assets/branding/README.md`
- `packages/bthere_design_system/lib/src/theme/bthere_colors.dart`
- `packages/bthere_design_system/lib/src/theme/bthere_radius.dart`
- `packages/bthere_design_system/lib/src/theme/bthere_theme.dart`
- `packages/bthere_design_system/test/bthere_design_system_test.dart`
- `packages/bthere_auth/lib/src/data/repositories/provider_auth_repository_impl.dart`
- `packages/bthere_auth/test/bthere_auth_test.dart`
- `docs/provider-auth-ui-redesign.md` (new)

18. **Reference differences:** implementation follows supplied screenshots rather than editable Figma measurements. Native decorative ellipses/leaves approximate edge artwork; no screenshot background is used. No dashed ornamental path is reproduced. Nunito is declared by the existing typography but no font files are bundled, so the production font falls back by platform. Accessible CTA/text shades, normal safe areas, system status bar, scrolling at smaller sizes and backend-correct 10–72 helper deliberately differ from the static mockups. Supplied logo says Care when it matters rather than recreating a tagline. Social-unavailability caption is added to explain disabled actions. Registration may need scrolling to reach its footer; text scaling stays supported rather than forced into one fixed frame.

## Visual review

Optional renderer from `apps/provider_app`:

```powershell
flutter test --no-pub --dart-define=FLUTTER_SDK=<path-to-your-flutter-sdk> tool/auth_ui_preview_test.dart
```

It renders real widgets with fake repositories into `build/auth-ui-previews/sign-in.png` and `create-account.png` at 430x1100. SDK Roboto is loaded only inside this preview tool under the typography family to avoid Flutter test Ahem; it does not bundle, download or change production fonts. UI tests forbid network and Google identity creation. Generated previews and APK are build artifacts, not additional source changes.

No commit, push or PR was created.
