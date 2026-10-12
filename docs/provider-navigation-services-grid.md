# Five-tab Provider navigation and Services grid

The authenticated shell now contains exactly **Home, Services, Requests,
Messages and Profile**. This supersedes the earlier two-tab Services list UI.
Authentication, session restoration, account prerequisites and service business
logic are unchanged. Completed authenticated entry still lands on Home.

## Shell and routes

The existing go_router `StatefulShellRoute.indexedStack` retains each visited
branch and its scroll state. `ProviderTab` centralizes the ordered paths, labels,
outline/selected icons and temporary-page descriptions. The shell builds its
destinations from this configuration, and the router uses the same configuration
for temporary branches and permitted top-level paths.

| Tab | Route | Behavior |
| --- | --- | --- |
| Home | `/home` | Existing temporary Home, unchanged |
| Services | `/services` | Backend-driven service grid |
| Requests | `/requests` | “Your service requests will appear here.” |
| Messages | `/messages` | “Your conversations will appear here.” |
| Profile | `/profile` | “Manage your provider profile and account settings here.” |

`AppRoutes.account` names the Profile tab path, avoiding a collision with the
existing `AppRoutes.profile` Provider Details route (`/onboarding/profile`).
The completion-based gate still sends incomplete authenticated accounts to
Provider Details, and unauthenticated accounts to Auth. No profile GET semantics
or account-editing functionality were introduced.

Temporary tabs use one reusable branded screen with a title, supporting text and
decorative empty-state icon. They perform no repository reads and contain no
fake counts, messages, requests, account data or unsupported actions.

The Material NavigationBar uses teal selected icons/labels and a soft pill,
muted inactive items, and native selected-tab semantics/tooltips. Its height is
72dp plus safe-area padding, with comfortable touch targets. Labels are 11sp
below 360px and 12sp otherwise; navigation-only scaling is bounded at 1.2 to fit
all five labels. Page text retains full system scaling.

Android back from any non-Home top-level tab returns to Home. Existing nested
Service Detail/Setup/Status/Basic Details/Documents/requirement pages still use
the root navigator above the shell, with no visible bottom navigation. Back
returns naturally to Services without a duplicate catalog or shell. All existing
service URLs and explicit nested back actions are preserved.

## Services presentation

Services reuses the existing `BrandedFormPage` with optional compact-header,
header-action and pull-to-refresh support. Its logo is 88px wide with the original
aspect ratio; title and compact refresh action share a row. The subtitle is
“Choose a main service to set up or manage.” Other branded pages keep their
existing default layout. The aqua decoration remains behind content with
IgnorePointer and excluded semantics.

`ServiceCatalogGrid` uses a shrink-wrapped, non-scrolling GridView inside the
page's single outer scroll view. The bottom navigation remains fixed. Normal
phone layouts use four equal-width columns with 8dp gaps, matching the supplied
service-menu reference. Narrow content widths use three or two columns; enlarged
text uses two or one column for readability. Row height
reserves two scaled name lines and two scaled status lines; it is approximately
166dp at the standard text size and grows with text scaling.

The existing `ServiceCatalogCard` now renders a grid tile: backend icon or the
same generic briefcase fallback, centered name limited to two lines with ellipsis,
compact status badge, and a centered icon above the name. The entire tile is one semantic button whose
full label includes service name and status. Long descriptions are omitted from
tiles; description data and its existing Service Detail presentation remain
unchanged. Backend service ordering, IDs and icons are preserved.

`ServiceStatusStyle` centralizes all status badge and attention tile styling:

| Existing status | Presentation |
| --- | --- |
| Available / Approved | Mint badge |
| Setup required | Warm badge, surface and border |
| Pending approval | Amber badge |
| Rejected | Error badge |
| Inactive / unavailable status | Muted badge |

The existing `productServiceStatus` calculation and setup-controller overrides
are unchanged. Styling is status-driven, with no service-name special cases.

## Refresh and state handling

The old bottom “Refresh services” CTA is removed. A 48dp outlined icon action
beside the Services title exposes the Refresh services tooltip and a subtle
busy indicator. Pull-to-refresh invokes the same callback, including for short
or empty lists through AlwaysScrollableScrollPhysics.

Both triggers reuse precisely the existing catalog reload, assignments
invalidation and completion reload. The local busy guard blocks duplicate or
concurrent triggers until all three reads finish. No additional endpoint,
repository behavior or assignment mutation was added.

Initial loading uses the existing indicator. Refresh continues the existing
provider loading-state behavior. Read failures retain generic error/retry
presentation and never expose transport internals. An empty catalog displays
“No services are available right now.” with the compact header refresh available.
Progress-unavailable retry handling is retained.

## Tests and verification

Ten new regression cases cover all three temporary tabs and their selection/
announcements, zero backend reads, unauthenticated and incomplete-profile deep
links, four-column layouts at 360/430px, description-free tiles, long-name
ellipsis/full semantic labels, pull-to-refresh/concurrent header blocking, and
enlarged-text single-column layout. Existing shell tests now check five
destinations, compact refresh geometry, status treatments, and 25-service
scroll-offset retention across Messages at small/large heights with safe areas.
Existing service-first tests use the updated empty-state copy.

| Workspace member | Passing tests | Analysis |
| --- | ---: | --- |
| customer_app | 1 | Clean |
| provider_app | 517 | Clean |
| bthere_design_system | 21 | Clean |
| bthere_network | 46 | Clean |
| bthere_session | 12 | Clean |
| bthere_auth | 129 | Clean |
| bthere_common | 3 | Clean |
| **Total** | **729** | **All seven clean** |

- Root `dart pub get` succeeded; no dependency changes.
- Final root analysis also reports no issues.
- Formatting check: 188 Dart files, zero changes.
- Normal-entrypoint `flutter build apk --debug --no-pub` passed.
- APK: `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`.
- Additional actual-widget preview test passed; excluded from the 729 total.

## Visual review and extension points

Actual widget renders were manually inspected for the three-service grid at
430x1100, 320x568 scrolling through the final tile, five readable tab labels,
compact refresh, status badges, ellipsis, and all three temporary screens. Images
are under `apps/provider_app/build/provider-shell-previews/`, including
`services-grid-large.png`, `services-grid-small-last-row.png`, and the three
`*-placeholder.png` files. Fixture data and SDK preview fonts exist only in
test/tooling; no production data or font assets were fabricated.

Native emulator visual verification remains incomplete: the preceding milestone
encountered black Flutter surfaces, and this task's visual review used actual
widget renders. That emulator issue remains unresolved; no native renderer
configuration was changed. The normal APK build passed.

Future Requests/Messages/Profile functionality should replace each temporary
branch's screen and add its own feature providers/routes. Shell metadata and
stateful branch behavior can stay intact. No Requests API, messaging, profile
editing, bookings, notifications, locations, availability, earnings or analytics
were implemented.

## Exact files changed

Production:

- `apps/provider_app/lib/app/router/app_routes.dart`
- `apps/provider_app/lib/app/router/app_router.dart`
- `apps/provider_app/lib/app/presentation/provider_shell.dart`
- `apps/provider_app/lib/app/presentation/provider_tabs.dart` (new)
- `apps/provider_app/lib/app/presentation/provider_placeholder_screen.dart` (new)
- `apps/provider_app/lib/core/presentation/branded_form_page.dart`
- `apps/provider_app/lib/features/services/presentation/service_catalog_screen.dart`
- `apps/provider_app/lib/features/services/presentation/service_catalog_card.dart`
- `apps/provider_app/lib/features/services/presentation/service_catalog_grid.dart` (new)
- `apps/provider_app/lib/features/services/presentation/service_status_style.dart` (new)

Tests, tooling and documentation:

- `apps/provider_app/test/provider_shell_test.dart`
- `apps/provider_app/test/provider_services_grid_test.dart` (new)
- `apps/provider_app/test/service_first_test.dart`
- `apps/provider_app/tool/provider_shell_preview_test.dart`
- `docs/provider-navigation-services-grid.md` (new)

No auth/session/onboarding/service repositories, backend contracts, Documents
implementation or dependency manifests changed. No automated live backend
mutations, commit, push or PR were performed.

Reference-image follow-up: service tiles now use four columns at normal phone
widths, centered icons and names, and compact status badges. Narrow layouts and
larger text use three, two or one column. B there colors, catalog data, status
rules and navigation are preserved.

Follow-up verification: all 517 Provider tests passed; workspace analysis found
no issues; formatting checked 188 files with no changes; the Provider debug APK
built successfully. The actual-widget preview test also passed.


Reference fidelity revision (2026-10-12): the Services page now uses a plain
white surface, a compact horizontal B there branding header, 16 px side margins,
8 px tile gaps, 12 px tile corner radii and the reference tile proportions
(158:202). Labels are regular-weight 12 px, centered below 32 px icons, with up
to three lines. Network icons retain their colors and aspect ratio; unavailable
icons use a neutral outline fallback. Catalog status pills and status-colored
tile surfaces have been removed from the visible grid to match the reference.
Status calculation, tap destinations, detail/status screens and accessible tile
labels remain unchanged. This supersedes the earlier visible-badge description.
No banking banner, banking services or unsupported chat actions were added.

Final revision verification: 517 Provider tests passed, analysis reported no issues, formatting checked 188 files with no changes, actual-widget previews passed, and the debug APK built successfully.
