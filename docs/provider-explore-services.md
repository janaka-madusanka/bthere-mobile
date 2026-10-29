# Explore Services

Implemented from Figma frames `119:877` and `177:1505` using the Figma plugin's design context and screenshots. Services now shares the existing teal header and fixed five-tab navigation, with a rounded white content surface, search, featured carousel and four-column pastel category grid. Enlarged text reduces the grid's columns; the page scrolls independently of navigation.

Providers without assignments see the design's Hot Services selection, resolved against actual catalog names and IDs. Providers with assignments see My Registered Services, including pending and rejected registrations. Assignments absent from the current catalog retain their backend names and IDs. Search matches names and descriptions; filters offer all, registered and not registered services. Search/filter changes perform no network calls or mutations. Carousel cards and category tiles keep the existing calculated detail/status destinations and service setup flows.

Catalog, assignment and completion loading, failure/retry and empty states are preserved. Pull-to-refresh and the compact All Services refresh action reload all three existing reads with a concurrent-request guard. API icon URLs remain available for categories without matching Figma artwork.

## API document

Reviewed the supplied 23-page `https___jobhub.pdf` (Complete Super Admin API List). It documents `GET /provider-types`, `GET /provider-types/{serviceTypeId}/setup`, service descriptions and `iconUrl`. It does not document provider assignment or completion APIs, featured-service rankings, or service photograph URLs. Existing authenticated provider assignment/completion repositories remain unchanged. No admin endpoints are called by this UI.

Hot Services ordering and the Caregiving Most Popular badge are editorial copy from Figma, not live popularity metrics. No unavailable service entries or fabricated IDs are inserted into the catalog. Photographs are the original Figma artwork in the corresponding Caregiving, Meal Preparation and Household Support slots, with a separate registered Caregiving image. Other services use their category symbol. Original assets are bundled locally; no temporary Figma URLs remain in production code. The registered meal/household photograph export was byte-identical to the new-provider export and shares that asset.

## Verification

Widget tests cover both variants, backend-ID selection, search/filter behavior without new reads, empty searches, refresh concurrency, retained navigation/scroll state, API registration/status flows and narrow layouts at normal, 1.3 and 2.5 text scaling. Rendered references use bundled fonts and synthetic test-only API data. The preview retains all API categories, so its extra Household Support category can require scrolling compared with Figma's twelve-category example.

Final provider regression run: 566 tests passed, two untouched Home/login tests failed (`login_test.dart` expects two session reads instead of three; `widget_test.dart` expects the retired Welcome back copy). Both fail on Home before Services opens. All Services and service-flow checks passed, including the new Caregiver alias, carousel pagination and catalog-missing assignment cases. Flutter analysis reported no issues. Rendered normal-size references were inspected against both Figma screenshots, with original asset dimensions and local non-empty files checked. The normal-entrypoint debug APK built successfully at `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`; all 18 Services assets are present and non-empty in the APK. PowerShell reported a nonzero wrapper exit from Java native-access warnings despite Gradle completing successfully and Flutter reporting the built APK.

Existing shared header/navigation rendering remains unchanged. Device rendering and live authenticated backend calls were not exercised.
