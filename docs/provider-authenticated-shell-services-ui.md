# Provider authenticated shell and Services UI

## Routing audit and architecture

Before this change, `app_router.dart` redirected completed authenticated sessions
from startup/auth to `/services`. The profile onboarding `onSaved` callback also
navigated there, and `/home` was a retired-link redirect to Services. Login only
invalidates restored session state; verification requests Provider Details through
`ProviderEntryGate.requireDetails()` after session persistence. Neither needs a
new navigation mechanism.

The existing completion-based account gate is unchanged. Missing profile/market
flags or their documented `nextStep` values still require Provider Details;
completion failures still display startup retry rather than assuming a missing
profile. No GET profile semantics, token storage or refresh behavior changed.

`StatefulShellRoute.indexedStack` now provides two lazy branches:

| Route | Behavior |
| --- | --- |
| `/home` | Default completed authenticated entry, including login and relaunch |
| `/services` | Existing backend-driven service catalog |
| `/onboarding/profile` | Unfinished account prerequisites, outside the shell |
| `/services/:serviceTypeId` | Existing service detail, above shell |
| `/services/:serviceTypeId/setup` | Existing setup, above shell |
| `/services/:serviceTypeId/status` | Existing status, above shell |
| `/services/:serviceTypeId/setup/profile` | Existing service-specific basic details |
| `/services/:serviceTypeId/setup/documents` | Existing Documents flow |
| Other existing setup requirement URLs | Preserved without renaming |

Acknowledged profile-save navigation now targets Home. Explicit service links
remain service links, and retired wizard links still migrate to Services. The
completed route guard permits those migration routes to execute their existing
redirects. Unauthenticated sessions cannot enter either shell branch.

Services is the parent route of the existing nested URLs. Those pages use the root
navigator key, so their own screens cover the shell and its bottom bar. Back from
detail returns to the retained Services branch. At top-level Services, Android
back selects Home; at Home it follows the normal root exit behavior. Existing
setup/Documents explicit back actions are unchanged.

The shell owns a single 64dp Material NavigationBar plus native bottom safe-area
padding, with exactly Home and Services. Selected icons/text use teal and stronger
emphasis; inactive items use muted blue-gray. Router branches retain widget state
and Services scroll offset without manual caching or persistent navigation state.

## Home and Services presentation

Home uses the existing bright `BrandedFormPage`, original proportional SVG logo,
and aqua background decoration. It shows Welcome back, a short introduction and
a Home dashboard information card. It adds no backend calls, metrics, requests,
avatars or activity data. Authenticated entry still performs the existing
completion check before opening Home.

Services uses the same compact branded header and scrollable responsive content.
`ServiceCatalogCard` provides a rounded bordered card, proportional network icon
or the existing generic briefcase fallback, service name/description, status badge
and chevron. The whole card retains its original route selection. Backend order,
IDs, names, descriptions and icon sources are preserved.

`ServiceStatusBadge` centralizes presentation for Available/Approved (mint),
Setup required (warm attention tint), Pending approval (amber), Rejected (error),
Inactive/unknown (muted). No service names receive special treatment. Existing
`productServiceStatus` and setup-controller overrides remain unchanged.

Refresh still invokes precisely the existing catalog reload, assignments
invalidation and completion reload. A local busy guard prevents duplicate taps
and remains active until those reads finish. The full-width teal button retains
its label, leading slot and dimensions during refresh. No endpoints or repository
behavior were added or changed. Loading, error/retry, unavailable-progress and
empty states retain their existing handling; Refresh remains reachable through
scrolling even for long lists.

Reusable additions live in the Provider app: ProviderShell, ProviderHomeScreen,
ServiceCatalogCard and ServiceStatusBadge. Existing shared brand/layout/design
tokens and buttons are reused without design-system edits.

## Tests and verification

Thirteen new shell/presentation tests cover initial Home selection, exactly two
tabs, lazy Services reads, state retention, dynamic names/descriptions, Available
and Setup required treatments, detail taps/back, no visible nested bottom bar,
top-level Android back, three-read refresh and duplicate prevention with stable
button size, loading, error/retry/empty, and 25-service scrolling/offset retention
at 320px width with enlarged text and safe areas. All seven badge states are
checked at enlarged text size. Existing auth/bootstrap/verification/profile
selector tests now expect Home after account prerequisites; service regression
fixtures explicitly open Services when testing catalog behavior.

| Member | Passing tests | Analysis |
| --- | ---: | --- |
| customer_app | 1 | Clean |
| provider_app | 507 | Clean |
| bthere_design_system | 21 | Clean |
| bthere_network | 46 | Clean |
| bthere_session | 12 | Clean |
| bthere_auth | 129 | Clean |
| bthere_common | 3 | Clean |
| **Total** | **719** | **All seven clean** |

- Root `dart pub get` succeeded; no dependency changes.
- Root analysis also reports no issues.
- Formatting check: 183 app/package Dart files, zero changes.
- Normal-entrypoint `flutter build apk --debug --no-pub` passed.
- APK: `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`.
- Additional widget preview tool test passed (excluded from the 719 tests).

## Visual QA and limitations

The debug-only `tool/provider_shell_preview.dart` runs the real router/screens on
emulator-5554 with synthetic in-memory repositories. It blocks live transport and
does not access secure storage. Fixture service names/data exist only in the
preview/test tooling, not the production Home or Services implementations.

The emulator launched and exposed the expected Home/tabs in its Android
accessibility hierarchy, but screen captures showed a black Flutter surface.
Retries with Impeller disabled and compatible software rendering did not produce
usable screenshots. Full visual emulator QA therefore remains incomplete; its
cause is unconfirmed and no production renderer/native configuration was changed.
The preview was stopped and the normal-entrypoint debug APK reinstalled without
launching it or submitting any live requests.

Actual widget renders were inspected at 430px wide/1100px high and 320x568,
including the scrolled Refresh CTA. Automated responsive tests additionally cover
320x915, doubled text scaling and 24px Android safe-area padding. Widget preview
images are under `apps/provider_app/build/provider-shell-previews/`; the preview
tool uses SDK fonts for inspection, without changing production font assets.

The next Requests/Messages/Profile extension point is additional
StatefulShellBranch entries with matching NavigationDestination entries in the
same router/shell. No future tabs, APIs or placeholder pages were implemented.

## Exact files changed for this milestone

Production (modified unless marked new):

- `apps/provider_app/lib/app/router/app_routes.dart`
- `apps/provider_app/lib/app/router/app_router.dart`
- `apps/provider_app/lib/app/presentation/provider_shell.dart` (new)
- `apps/provider_app/lib/features/home/presentation/provider_home_screen.dart` (new)
- `apps/provider_app/lib/features/services/presentation/service_catalog_screen.dart`
- `apps/provider_app/lib/features/services/presentation/service_catalog_card.dart` (new)

Tests and preview tooling:

- `apps/provider_app/test/provider_shell_test.dart` (new)
- `apps/provider_app/test/login_test.dart`
- `apps/provider_app/test/email_registration_onboarding_test.dart`
- `apps/provider_app/test/service_first_test.dart`
- `apps/provider_app/test/google_auth_test.dart`
- `apps/provider_app/test/email_auth_screen_test.dart`
- `apps/provider_app/test/provider_selector_test.dart`
- `apps/provider_app/test/widget_test.dart`
- `apps/provider_app/tool/provider_shell_preview.dart` (new)
- `apps/provider_app/tool/provider_shell_preview_test.dart` (new)
- `docs/provider-authenticated-shell-services-ui.md` (new)

No authentication/business repositories, Documents sources, backend contracts,
secure persistence or dependency manifests changed. No automated live backend
mutations, commit, push or PR were performed.
