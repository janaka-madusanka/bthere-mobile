# Provider home

Source: [Bthere Figma](https://www.figma.com/design/IQjgwcnUnxHd34avAUVhyQ/Bthere?node-id=0-1), frames `110:93` (new) and `180:2125` (registered). Both were read with the Figma plugin, including screenshots, then compared with rendered Flutter references.

## Screen selection

Authenticated `GET /providers/me/service-types`, through the existing `providerAssignmentsProvider`, determines the variant:

- A successful empty assignment list displays the new-provider screen.
- Any registered service displays the registered dashboard, including pending, incomplete, rejected, approved and inactive services.
- A failed or loading registration lookup never displays the first-service invitation.

Completion data does not determine whether a provider has registered. `GET /providers/me/completion` still supplies verification and setup detail for badges, using `productServiceStatus`. Existing authentication and profile prerequisite routing remains intact. Returning from a service status screen and existing service mutations invalidate assignments; pull-to-refresh reloads assignments, completion, catalog, account metadata and sub services.

## Presentation

`provider_home_screen.dart` orchestrates data and selects the variant. `provider_home_widgets.dart` contains the header, first-service invitation, registered greeting and metrics, service rows, category grids, community card, resource cards and Home navigation.

The layout preserves the 430-point Figma coordinate grid, proportionally scales to the device width and scrolls vertically. Header and navigation use teal gradients. Source icons retain their intended inner size and circular backgrounds. New and registered screens use their separate category order, card heights and text sizes. Inter and Lato are bundled locally with their OFL licenses; no package dependency was added.

For system text scaling above 130%, `provider_home_accessible.dart` uses intrinsic rows and scrolling instead of fixed-height design cards. Home navigation grows with its labels. The standard-size design geometry is unchanged by this fallback.

At 110%–130% text size, the Figma layout now reserves additional vertical space in the welcome area, registration prompt, greeting, metric cards, category cards, headings, community panel and resources. Category labels may wrap to two lines. This fixes the reproduced card overflows without changing normal-size geometry. Home text colors are applied to the local theme as well as the page text style so Material cards retain the intended navy.

The reported Android `HomeGreeting` overflow also occurred at the default text scale because platform font/emoji metrics exceeded its 42-point header. The greeting header and section now use minimum heights with intrinsic content sizing. Forced strut height was removed from the name to avoid clipping fallback glyphs. Metric cards use intrinsic equal-height rows and minimum heights; the community panel also grows to its content rather than imposing a hard height.

Original Figma SVGs are in `assets/home`. The registration arrow's SVG export rendered incorrectly; the original icon instance `I110:136;24:587` was exported as a transparent PNG through the Figma Plugin API. The three service photograph slots use the original Figma image with the source cropping geometry, mapped only to Caregiving, Meal Preparation and Pet Care. Other registered services use a generic service symbol. No full-screen screenshot is used as a screen implementation.

Native system status/navigation areas remain OS-owned. The shared navigation bar matches the Figma order: Home, Opportunities, Services, Messages, Profile. All five main tabs use the same teal gradient, source icons, label styles, sizing and safe areas. The white pill and teal icon follow the selected branch; inactive icons remain light teal. Opportunities maps to the existing Requests branch; branch indices and routing remain unchanged. Nested service/edit screens keep their existing full-screen navigation behavior.

## Dynamic data and interactions

- Assignment model: `ProviderServiceAssignment` supplies service IDs, names and account/service states.
- Completion model: `ProviderServiceCompletion` supplies verification and requirement state.
- Existing `ProviderOptionsRepository.loadSelections(assignmentId)` supplies actual sub-service names and counts for each registered row; up to three chips plus a remaining-count chip are shown.
- `GET /provider-types` resolves backend IDs for category links. Category taxonomy, ordering and artwork follow Figma; categories absent from the backend open the Services catalog, without fabricating IDs.
- Greeting uses secure session account metadata and the existing clock provider. Name, date, assignments and sub services are never sample production values.
- Register/Manage Services open Services; categories open matching details; registered rows open status/setup; header actions open Requests and Profile. Resource cards open an availability sheet.

## Remaining backend gaps

The supplied API PDF describes Super Admin APIs. `/admin/dashboard/statistics` is unsuitable for provider accounts. No documented provider activity/community metrics endpoint or resource-content endpoint exists in the supplied material. Both metric sections preserve the Figma card geometry and show em dashes with unavailable tooltips instead of fabricated counts. Resource content remains unavailable. Live backend integration was not exercised during this UI revision.

## Validation

`provider_home_test.dart` covers both variants at 320 and 430 logical pixels, assignment failure/retry, stale or missing completion rows, and pending/rejected/approved registrations. Two golden reference images use bundled fonts, synthetic test-only services, and native-area insets. Photographs are explicitly precached before capture. These references document rendered output; they are not an automated pixel-difference comparison against Figma. Device rendering and live authenticated APIs remain untested.

Rendered references: `apps/provider_app/test/goldens/provider_home_new.png` and `provider_home_registered.png`.

Validation commands: `flutter analyze --no-pub` and `flutter test --no-pub test/provider_home_test.dart test/provider_shell_test.dart --reporter expanded`. The combined suite contains 30 tests, including a greeting with Sinhala and emoji fallback glyphs plus loaded sub services, both variants at 110% and 130% text sizes, normal-size golden comparisons, registration routing, shell navigation and large-text/safe-area checks. Golden baselines were inspected after the Figma refinements.

Results: all 30 tests passed; Flutter analysis reported no issues. The four font-size regressions initially failed on both variants and passed after the height fixes. Updated normal-size rendered references were inspected.

Shared navigation revision: the home, shell, services-grid and account suites passed 60 tests. An additional regression checks each of the five destinations, stable navigation-bar dimensions, selected semantics and existing branch routes. Flutter analysis reported no issues. Authentication and full-screen detail routes continue to hide the main-tab bar as before.
