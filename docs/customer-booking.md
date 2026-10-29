# Customer provider search and booking

Provider selection UI (2026-10-27): results use a map-led screen with floating
Back/service picker and draggable provider list, compact profile/rating/language
cards, explicit Select/Selected and sticky Continue. Full-width form-style results
have been replaced; matching/selection/review APIs are unchanged. Providers are
counted distinctly; paged results retain +/Load more. No invented specialty tags,
photos, ratings or online presence. Native markers select candidates, with custom
backend marker icons preferred over circular public-photo fallback. Recenter
does not change the booking location or trigger a new search. ONLINE uses the same
selection panel with a non-map background. Narrow 2x-text layout is covered.

Map visibility update (2026-10-27): initial camera uses Sri Lanka until a point is
selected. Actual GPS still wins. Visible map dimensions determine radius zoom;
camera updates fit the full radius and available pins. Coincident pins are
spiderfied only for rendering, with thin connectors back to their real mapPoint
and a shared-location label. Original candidates/booking coordinates are never
rewritten. Providers at distinct coordinates stay exact. Missing/ONLINE mapPoint
does not receive a synthetic location; the backend must supply public/approximate
coordinates for a physical provider pin. Pagination retains existing load-more.

Service access requirements (2026-10-26): known ineligible services offer View
details from the map badge, and Continue routes to Additional information before
validating filters or searching. The backend requirements schema supplies inputs
and uploads; submission does not imply approval. Review refresh fetches both rows
and eligibility while preserving the draft. Approved users return to location
and time selection; pending/rejected/expired states keep booking gated. Preview
eligibility errors refresh the requirement data instead of presenting zero
providers. Nonblocking optional requirements remain available in Service details.

Live availability preview (2026-10-26): filter, radius, location and schedule
edits trigger the real provider search after a 500 ms debounce. Count and map
markers update on the filters screen without Continue or disabling input. A
request revision and input fingerprint reject stale responses. Loading and
retryable failures have distinct badge states; Continue still validates and
rechecks availability before opening booking fields. Counts deduplicate loaded
provider IDs and retain the existing +/load-more behavior for paged results.
Validation: 216 Customer tests passed, including debounce, obsolete responses,
retry and an on-screen count update before Continue.

Implemented against the supplied Customer frontend API reference on 2026-10-22.
The FigJam assessment and backend gaps are recorded in
[customer-provider-search-booking-plan.md](customer-provider-search-booking-plan.md).
No live authenticated booking or payment was created during development.

## Entry and data

Home and Services retain their backend category/sub-service accordion. A
sub-service's Continue button opens `/booking/:service/:option` within the current
authenticated account and selected market. Authentication/profile/market gates
remain in place. Bookings opens `/bookings`; Home shows the newest three server
booking records, with separate loading, empty and retry states.

The form reads `GET /customers/me/booking-context` with market/service/option IDs,
`GET /customers/me/requirements`, `GET /customers/me/eligibility` and
`GET /me/payment-settings`. Only documented BOOKING_FIELD definitions become
booking answers. Common and option fields are deduplicated by field ID;
conflicting/unsupported schemas fail visibly. Typed SELECT/MULTI_SELECT values,
BOOLEAN false and NUMBER zero retain their JSON types. EQUALS/NOT_EQUALS conditions
clear hidden answers. Changed field ID/type/version discards obsolete drafts.

Reusable requirements are separate from per-booking answers. Dirty submissions
use `PUT /customers/me/requirement-submissions` with the documented submissions
wrapper, then reread server requirements and eligibility. Uploading/saving never
implies approval; PENDING, REJECTED and expiry remain backend states. Private
PDF/JPEG/PNG/WebP evidence uses multipart `POST /uploads/documents`, configured
limits and a hard 100 MB ceiling. Only returned object keys are submitted.
Document viewing obtains a fresh `/uploads/view-url`; signed URLs are not stored
or logged. No access tokens, personal values or uploaded bytes are logged.

## Schedule, location and selection

Market IANA timezone drives schedule validation. Search uses explicit-offset
timestamps; booking creation uses the documented market-local timestamps.
Nonexistent/ambiguous local times, DST-crossing intervals, past starts and
time-based durations over 31 elapsed days are rejected.

Time-based provider-to-customer bookings collect an address/map pin;
customer-to-provider bookings search around the chosen area and retain the
selected providerLocationId; online bookings omit physical coordinates.
Route-based bookings collect pickup/destination addresses and coordinates.
Language and configured skill filters remain independent of form answers.

`POST /customers/me/provider-search` supports paging, real empty/error states,
approximate/public/online location labels, ratings only when returned, and
distinct-provider team selection. Search result map points are not live tracking.
Changing details or returning from the background while reviewing results clears
stale search selection. Account/market changes discard private drafts and late
responses. Native file/location pickers do not reset the details form on resume.

`POST /customers/me/bookings` sends explicit providerId or providerIds, the selected
delivery mode, correct schedule/location shape, fieldId/value answers, optional
note and allowed payment method. It sends no client price or marketId. Creation
requires confirmation, prevents double taps and never automatically replays a
write. Timeout/5xx/malformed success leaves an uncertain outcome and directs the
customer to history before another attempt. Known availability/eligibility errors
require a fresh search. Booking amount/currency/status come only from the server.

## Payments and history

Cash remains PENDING; the app does not assert payment or final provider acceptance.
Wallet invokes the documented booking wallet-payment operation and displays the
refreshed booking status, including RESERVED rather than claiming settlement.
Card creates an idempotent card-payment-session with a stable per-booking key.
The supplied backend currently implements mock card checkout only: controls are
explicitly labelled test mode and require confirmation before mock events. No raw
card details are collected and no production gateway is implied. Capability
failures disable unavailable methods; settings are rechecked before payment.
History is read from `GET /customers/me/bookings`; record details use that returned
object, without inventing a single-booking GET endpoint.

## Maps

### Availability before Service Details

Continue from filters refreshes booking context and calls the documented provider
search with `locationStep` inputs. Per-booking answers are not included in this
search request. Only an AVAILABLE response opens booking questions. An empty or
insufficient-team response keeps the customer on filters and suggests changing
time/location/radius. Transport/schema errors remain retryable errors.

Map pins use the backend's mapPoint and resolved mapMarker.icon.url (PNG/SVG
artwork with a standard marker fallback). They represent public provider locations
or approximate service areas, not live GPS tracking. Counts deduplicate provider
IDs rather than treating multiple locations as multiple people. A + suffix means
more pages; the badge's Show more control loads those pins and updates the count.
The map viewport leaves room for this badge above the sheet.

The availability snapshot is invalidated by changed search inputs, and retained
while filling service answers. The final form submission still searches again
before explicit provider selection; server booking creation rechecks availability.
If eligibility blocks the early API query, customer requirements can be completed
without exposing unverified booking questions; access must be resolved before
checking availability again.

The app-defined Additional notes input has been removed from Service Details.
Questions, including any notes/instructions question, now come from configured
backend booking fields. Configured TEXTAREA questions remain supported.

Service Details now uses the same content-height expanded default, collapsible
panel and sticky Continue as location/time. Cards share Customer colors/spacing;
small Boolean/select/multi-select sets use matching choice tiles while preserving
typed backend values. Required address/questions highlight inline on Continue and
clear individually as corrected. Conditional visibility, reusable requirements,
the optional 4000-character note and search/booking payloads remain intact.
This supersedes the older 46% Service Details starting height below.

Customer product rule: Continue from location/time requires a value for each
displayed provider filter, fallback language choices and displayed skills. Empty
or invalid selections remain on that step with actionable errors; nothing is
searched or booked. Boolean false and numeric zero remain valid selections.
This changes frontend completion rules, not the API payload or backend metadata.

Location/time opens fully expanded to its content-height cap by default; drag
down to expose more map. Continue stays pinned and oversized content scrolls.
Service Details keeps its separate initial panel height. This supersedes the
half-height location/time default recorded in earlier milestones below.

All physical Customer map views use `google_maps_flutter` on Android/iOS. The
`BTHERE_GOOGLE_MAPS_API_KEY` value comes from `config/customer.local.json` and is
injected into Android manifest metadata and iOS Google Maps initialization.
See [Customer configuration](customer-configuration.md) for SDK enablement and
package/signing-key restrictions. OSM tile configuration is no longer used.

Foreground location permission is requested when opening a physical map without
an existing pin, or when tapping Use current location. Denied/unavailable GPS
retains search and manual map selection. Search now uses native Google Places
autocomplete and selected-place details. Provider markers retain backend-resolved PNG/SVG artwork with
standard Google markers as fallback. Radius circles, tap/drag selection, camera
updates and late-GPS protections remain. The native Google logo/legal attribution
is retained, and the map viewport resizes above the draggable booking panel.
Tests substitute only the native view while exercising the same journey state.
iOS runtime verification requires macOS; web/desktop Maps setup is not included.

New native plugins require stopping the old Flutter run and launching again:

```powershell
cd D:\Projects\bthere-mobile\apps\customer_app
flutter run --dart-define-from-file=../../config/customer.local.json
```

## Remaining backend/product work

- Gender matching uses only the actual admin-enabled providerFilters metadata;
  no gender field IDs or values are hardcoded. Gender-specific team quantities,
  invite/dispatch workflow and automatic matching remain unavailable.
  OPEN_REQUEST still requires explicit provider IDs.
- Live ETA/tracking, customer messaging, automatic acceptance/cancellation and a
  documented cancellation API remain unavailable.
- Pre-booking price/fee quote, production card checkout, eZ Cash and provider-side
  mock-mode discovery are not supplied by this contract. Server price is known
  only after creation, which consumes provider capacity.
- Full wallet funding/linking/withdrawal management is outside this milestone.
- Address autocomplete/geocoding and GPS-to-market resolution are not implemented.
  The map picker works with manually entered addresses and GPS/pins.

## Verification

Contract/controller tests cover exact request shapes, schema conditions/types,
timezone conversion, distinct team selection, paging, requirements, private uploads,
authorization refresh without write replay, duplicate/uncertain creation and payment
states. Widget tests traverse sub-service through booking/history, exercise dynamic
fields and eligibility, verify narrow large-text layouts and denied-GPS manual entry.
Live deployment behavior still needs authenticated manual testing.

Verified on 2026-10-22:

- Customer suite: 150 passed, including 33 booking tests.
- Shared packages: 244 passed (23 design system, 48 network, 13 session,
  157 auth, 3 common).
- Customer and all five shared-package analyses: no issues. Provider analysis
  retains its existing `withOpacity` deprecation in `service_catalog_visuals.dart:39`;
  Provider source was not changed by this milestone.
- Customer formatting: 48 files checked, zero changes; `git diff --check` passed.
- Synthetic visual preview: details/results/review/created captured in ignored
  `apps/customer_app/build/booking-previews/`; map network downloads disabled.
- Customer debug APK built with the deployed API base URL at
  `apps/customer_app/build/app/outputs/flutter-apk/app-debug.apk`.

Provider tests were not rerun in this Customer milestone; these counts are not a
claim that the entire seven-member workspace test suite is green.

## UI review follow-up

Date/time controls open native Flutter date/time pickers from the entire field and
display readable market-local dates with the year; wire timestamps are unchanged.
Stage transitions and new errors scroll to the top so results and validation stay
visible after a long form. Review Back returns to results while preserving selected
providers; results Back returns to the existing details draft. Busy requests still
block navigation. Short booking stages fill the available page background.
Recent history uses the shared compact loading component; history shows readable
schedule dates and route pickup times. Authentication/profile/Home and booking
previews were reviewed using synthetic fixtures, with map downloads disabled.
Regression coverage includes error visibility, date-picker cancellation, preserved
provider selection and the existing narrow large-text layout checks.

## Map-first details redesign — 2026-10-24

Customer details now use an interactive map background, floating service badge,
GPS control and draggable rounded details sheet. Attribution remains visible above
the sheet. Location/radius controls, market-local quick dates, preferred-time slider
and duration presets update the same draft used by existing search/booking DTOs.
Manual coordinates are validated together before changing the map pin. Calendar
controls retain an always-floating label so empty hints cannot overlap.
Online delivery hides physical map input; route delivery retains destination fields
and omits time-based duration presets. No immediate/dispatch promise, location name
or nearby-provider count is invented from the reference image.

BOOKING_FIELD definitions/conditions and reusable requirements remain separate.
Context providerFilters now render configured SELECT/MULTI_SELECT, NUMBER RANGE
and BOOLEAN EQUALS preferences, including gender only if actually published by the
backend. Choice labels map to stable string arrays; ranges preserve numeric zero
and booleans preserve false. Clear controls remove filtering; context reload and
account/market changes clear preferences. Search alone sends providerFilters;
booking answers, requirement submissions and pricingSelections do not receive them.
Unknown schemas, invalid choices/ranges and excessive selections fail visibly.

Verification for this redesign: all 158 Customer tests passed; Customer analysis
clean; 50 files passed formatting; debug APK and synthetic visual preview passed.
Provider source was not changed. No live search/booking/payment was submitted.

## Corrected two-screen flow — 2026-10-24

This replaces the combined map/details form from the redesign above:

1. Location and time: map pin/GPS, radius slider with radius-aware map zoom,
   start/end date-time controls, quick date/time/duration controls and configured
   provider preferences. Continue validates location/schedule only and opens the
   next screen without sending a provider search or demanding booking answers.
2. Service details: backend BOOKING_FIELD questions/conditions, reusable
   requirements/review, necessary human-readable addresses and optional note.
   Find providers performs full validation and the existing provider search.

Customers never enter latitude/longitude and never choose technical delivery-mode
enum values. The location button opens an interactive map with GPS and an optional
address/landmark entry; only the actual selected pin supplies API coordinates.
The existing option configuration selects PROVIDER_TO_CUSTOMER when allowed,
otherwise its first supported mode. Online and fixed-location API shapes remain
separate. Route bookings collect pickup/destination pins and omit duration/end time.
No geocoding, invented address lookup or location inferred from typed text is used.

Back from service details preserves answers and returns to location/time; editing
an answer stays on service details. Both date and time dialogs are tested through
confirmation, not just opening. Numeric time entry supports both start and end.
The map camera fits the selected radius so its coverage circle remains visible.
All 162 Customer tests, Customer analysis, formatting and debug APK verification
passed. Provider application code is unchanged.

## Calendar/range scheduling and place search — 2026-10-24

The first screen no longer contains duplicate start/end date-time fields.
The calendar button beside “When do you need help?” stays visible independently
of the quick-date strip. A selected calendar date outside the next four days is
shown explicitly. Both handles of the preferred-time range change the same
market-local start/end values used by the existing API; duration choices update
the end handle. Overnight and multi-day durations use an elapsed multi-day scale,
and custom duration accepts minutes expressed in hours, up to 31 days. Route
services keep a pickup-only slider and never invent an end time. Existing backend
future/DST/maximum-duration validation remains authoritative.

“Where do you need the service?” opens a searchable map. Search a city/area/place,
choose a returned result, and the service pin/camera moves to that coordinate;
this is independent of the device's current GPS position. GPS and map taps remain
available. A typed search alone does not move the pin or confirm a location.
The customer confirms the actual selected pin before returning to the booking.

Place search uses a separate, unauthenticated HTTP client against the Photon API:
`https://photon.komoot.io/api/`. Only the entered query and selected market's valid
country code are sent; Customer account tokens, session/profile data and GPS
coordinates are not sent to the search endpoint. Requests are explicit on submit,
serialized at most once per second, and duplicate results use a bounded 10-minute
in-memory cache. Loading, no-results, safe failures and stale-response protection
are distinct. Search queries/results are not logged or persisted.

The default public Photon demo allows reasonable project usage but offers no
availability guarantee; production can use a hosted/self-managed compatible
endpoint through `--dart-define=BTHERE_PLACE_SEARCH_URL=https://your-host/api/`.
No paid Google Maps key is required. See the official
[Photon service terms](https://github.com/komoot/photon#demo-server) and
[API contract](https://github.com/komoot/photon/blob/master/docs/api-v1.md).
Map/Photon attribution remains visible. The existing map tile endpoint is unchanged.

Verification: all 172 Customer tests passed, Customer analysis clean, 55 files
passed formatting, debug APK and synthetic previews passed. One public
`Kurunegala` search returned real district/city results; no account/booking/payment
mutation was used for this check. Automated tests verify exact GeoJSON coordinate
order, country scoping, absence of auth headers, caching/rate spacing, error/empty
states, stale responses, camera movement, custom dates and duration/range syncing.

### Compact preferences and location search

Location, radius and calendar/time range appear first. All optional configured
provider filters (including spoken language/gender) now live in a single collapsed
Provider preferences card below the schedule. Its summary reflects selected values;
expanding/collapsing preserves controls and selections. Legacy language/skill controls
share that section rather than competing with the primary location/schedule actions.

The location picker keeps search/results and the interactive map, with Use this
location pinned below. The extra guidance paragraph and Address or landmark input
are removed. A selected search result still supplies its returned address together
with the actual pin; a manually chosen pin can leave address blank for the existing
Service Details address field. Search/booking API serialization is unchanged.
Required map/search attribution remains as a small source credit.

Verified: all 172 Customer tests, analysis, formatting and debug APK passed.

### Initial current location and compact date/duration rows

A new physical map now attempts foreground GPS once after the first frame and
centers/selects the returned current position. Existing service pins bypass this
initial lookup. A later search/map selection or a disabled/disposed picker prevents
late GPS data from overriding the customer's service location. Permission denial
and unavailable GPS retain search/map selection; online booking does not request GPS.

Quick-date cards use smaller label/padding styling. Duration has its own heading,
with all options on the following single horizontally scrollable row, preserving
large-text/narrow-screen access without wrapping options onto multiple rows.
Verified: all 176 Customer tests, analysis, formatting and debug APK passed,
including four startup-GPS regression tests. Provider app code is unchanged.

### Reference-style Service Details panel

The separate Service Details stage now shares the map background and draggable
rounded panel used by location/time. Changing stages resets the panel height and
scroll position, while Back retains the booking draft. Its service badge uses the
selected option name/icon. No illustrative provider count is displayed.

Service questions still come exclusively from bookingSchema common/option fields,
including required flags, typed values and conditional visibility. Backend field
icons are optional; map-marker icons are not substituted. Short consecutive fields
can share a row on sufficiently wide screens, with single-column layout for narrow
screens or large text. Ward and bed appear separately only if configured separately;
the app does not split a combined backend question or invent field IDs.

Service-location, dynamic-question and optional-note cards use the reference visual
style. Date and duration summaries use the actual prior selection. The standard
customerNote limit remains the documented 4000 characters, not the pictured sample
200. Required address entry and reusable requirements/review states are preserved.
Continue retains the existing validated provider-search handoff; this milestone
does not implement automatic OPEN_REQUEST dispatch, acceptance or new booking APIs.

Verified: all 178 Customer tests, clean analysis, 57-file formatting, debug APK and
synthetic reference-layout preview. Provider application source is unchanged.

### Service Details visual refinement — 2026-10-25

Preserved the existing map, booking stages and backend-driven questions. Removed the redundant Service Details heading, compacted card icons and inputs, and placed the documented 4000-character note counter in the card header. The selected address is displayed as a compact row: tap its text to edit the address or use its chevron to choose a map location. The schedule summary remains tappable to return to scheduling without an extra text button. Extended the existing widget regression to verify address editing and the note limit. No API payload changes or Provider app changes.


### Phone reference layout — 2026-10-26

Service Details now opens with 54% map / 46% form proportions. Compact short fields pair at 300 logical pixels of available width with large-text fallback retained. Square icon wells, field hints, compact note input and full duration labels match the supplied form composition. Recenter is positioned above the sheet. Questions/icons remain backend-driven; no hospital-only fields or sample provider counts are fabricated. Customer note retains its documented 4000-character limit. Regression exercises a 393-pixel phone viewport.


### Resolved markers and conditional pricing — 2026-10-26

Customer booking context now parses pricingFieldIds and matches configured providerFilters. Final single-choice pricing selections are separate from search filter arrays and booking answers. A fresh search refreshes context using the selected physical point's pricingLatitude/pricingLongitude together, allowing area-specific pricing discovery. ONLINE omits them. Review presents only configured pricing choices and a Preview price action. Quote uses the complete validated booking request and shows the server amount/currency plus available rate parameters. Creation reuses the request fields and remains server-priced; quote does not reserve availability or lock prices. Edits invalidate cached quote display.

Map candidates render their backend-resolved mapMarker.icon.url with a safe generic fallback; photos remain provider-card media. The client does not resolve vehicle/gender marker rules. No Provider/Admin or live configuration changes. Provider wallet credit after completion remains backend settlement work; no automatic settlement is claimed.

Verified: all 183 Customer tests (five new regressions), clean Customer analysis, formatting, and Customer debug APK build. Live deployment behavior was not exercised.


### Compact location/time half-sheet — 2026-10-26

This supersedes the earlier two-handle time-range treatment. The location form opens at half height, can be dragged upward, and keeps full-width Continue outside the scrolling content. The floating selected-service card is smaller. Configured gender choices use matching compact selection tiles, with no invented filter IDs/values; language choices use the same tile component. Location and Radius are side-by-side cards; Radius opens a dedicated range picker and updates the real map circle.

Preferred time now has one thumb with 15-minute steps and a neutral, unfilled track. The closest future quarter-hour in the market timezone is persisted as the initial current-time default because the API requires a strictly future start. Changing start preserves duration; duration presets/custom hours derive end time, including overnight/multi-day cases. ROUTE_BASED remains pickup-only. Dates retain calendar access.

Missing location/start/duration now produce actionable field messages and keep the user on the form without sending a search. Existing future-time, interval and backend validation remain in place. Three new regressions cover current-quarter defaults, missing-field handling and half-sheet dragging/sticky Continue; prior range assertions now cover the requested single-thumb behavior. All 188 Customer tests pass; analysis is clean. Provider and shared design-system files are unchanged.



### Google Places search ? 2026-10-26

Supersedes the historical Photon search milestone above. Customer searches now
use the native Google Places SDK with the existing JSON Maps key. Predictions
are country-restricted when the market supplies a two-letter country code.
Only the selected suggestion triggers a place-details request for coordinates
and address, reusing the autocomplete session. Google attribution replaces the
Photon footer; returned place credits remain visible. No REST key is exposed in
URLs, and no Google prediction/detail cache is persisted. Query/selection errors
are retryable and stale details cannot override a newer query or manual pin.

All 193 Customer tests passed with a synthetic key; Customer analysis is clean.
Cloud Places API access and actual device results require a live smoke test.
See customer-configuration.md for setup and iOS limitations.

### Request flow correction - 2026-10-27

The backend option providerSelectionMode controls navigation. OPEN_REQUEST:
filters -> available-provider check -> booking details -> review. DIRECT_REQUEST:
filters -> available providers map/list -> provider selection -> booking details
-> review. Unavailable searches stay on filters. Booking answers preserve the
selected provider; changing matching filters clears stale results and selection.
Back from Direct booking details returns to providers.

Open requests never send invented provider IDs. Enabled scheduled-request policy
uses /customers/me/booking-requests with an encrypted, persisted idempotency key.
Legacy Direct booking remains available when policy is disabled. Request receipt
and status refresh do not imply provider acceptance or successful payment;
subsequent acceptance/payment confirmation is a separate integration step.
