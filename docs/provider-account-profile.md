# Provider Profile tab

The API gaps in this historical report are resolved by the supplied complete provider contract. The account page now reads the provider profile, opens its editor, and calls server logout. See [Service registration](provider-service-registration.md) for the current behavior.

The authenticated `/profile` tab now renders a real account page instead of a
placeholder. `/onboarding/profile` remains the existing creation/onboarding form.
Authentication and completion-based onboarding gates are unchanged.

The page reads username, email, account ID, status and roles from the existing
secure session metadata. Legacy sessions without account metadata show an honest
unavailable state. Local storage errors remain errors, with safe copy and retry.
No credentials, raw storage errors or tokens are shown or logged.

Setup percentage, profile/market/service flags and next-step copy come only from
the documented `/providers/me/completion` repository. Refresh reuses that
repository and rereads local account metadata. Errors expose fixed safe copy and
retry; they never become an invented incomplete/missing profile.

Manage services opens the existing Services tab. Sign out requires an in-app
confirmation, waits for secure storage clearing, then invalidates the session so
the existing router returns to authentication. Duplicate clears are blocked.
Storage failure keeps the session and presents safe retry guidance. Pending sign
out survives leaving the Profile tab. This is local credential removal; no
undocumented server logout endpoint is called.

## Backend contract gap

The user reconfirmed that GET `/providers/me/profile` has no authoritative
response example/schema or missing-profile semantics. No GET request or parser
was added. Saved first/last names, gender, market name, date of birth, bio and
profile photo are not displayed or guessed. Personal provider details are shown
as unavailable. An existing-profile editor requires that backend contract before
it can safely restore values and submit changes. Existing onboarding PUT behavior
is preserved.

## Changed files

- `lib/features/account/application/provider_account_controller.dart`
- `lib/features/account/presentation/provider_account_screen.dart`
- `lib/app/router/app_router.dart`
- `lib/app/presentation/provider_tabs.dart`
- `test/provider_account_test.dart`
- `tool/provider_shell_preview_test.dart`

Paths above are relative to `apps/provider_app`; this report is in `docs`.

## Verification

Ten new tests cover confirmed fields, legacy metadata, account read failure/retry,
completion loading/error/retry, Services navigation, logout cancellation/success,
pending/duplicate/failed secure clearing, leaving the tab during logout, both
authenticated gates, and narrow-screen large-text layout. Profile is no longer
included in the placeholder-tab parameterized tests.

All seven workspace members passed: Provider 526, Customer 1, design system 23,
network 46, session 12, auth 129 and common 3: **740 tests**. Workspace analysis
found no issues; formatting checked 194 Dart files with no changes. Provider debug
APK build passed. Actual-widget Profile previews were rendered and inspected;
preview account data is synthetic and no live backend mutations were performed.

No dependency additions, commits, pushes or PRs.

## Reported runtime null-check failure

The supplied runtime trace identifies `ProviderPlaceholderScreen.build` and its
`tab.description!` expression. `ProviderTab.profile.description` is null because
Profile now has a real account page, so a Profile placeholder instantiated by
that runtime route crashed. The current Profile URL stays `/profile` and its
account-screen route remains unchanged.

The placeholder now passes its nullable description to `BrandedFormPage`.
That shared page accepts an optional subtitle and omits missing or blank copy
and its spacing. No fabricated fallback subtitle is used. Requests and Messages
retain their existing descriptions. The router explicitly limits placeholder
branches to Requests and Messages, rather than inferring route selection from
whether presentation copy exists. Home, Services and all five tab URLs remain
unchanged.

Direct placeholder regression tests cover Profile without its optional
subtitle, Requests and Messages. Additional Profile coverage tests real scoped
providers and production bootstrap, and missing/blank email on Android and iOS.
Profile identity/error rendering also uses promoted nullable locals. Account
metadata and completion contracts remain unchanged; no GET profile parser,
missing-profile semantics or backend mutations were added.

The exploratory browser test did not progress beyond loading and was stopped;
its result is not counted as a passing check.

Final fix verification: 537 Provider tests and all six other workspace members
passed (751 total). Opening Profile through the bottom navigation without
optional account data also passed. Analysis found no issues; formatting checked
194 files with no changes; Provider debug APK build passed. A full app restart
loads the current router configuration instead of any retained earlier route
objects. No commits, pushes or PRs were created.
