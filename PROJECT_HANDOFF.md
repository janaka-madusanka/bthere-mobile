## Current override: offline preview removed (2026-11-03)

User explicitly requested removing preview code and scripts after the integration
audit. The offline gallery/sample backend, alternate entry point, run script,
four preview-only test files, three dependent screenshot tools and old preview
guide are removed. Historical preview instructions below are superseded.
Normal Customer UI and production tests remain. Use scripts/run-customer.ps1
with existing local configuration. This source cleanup does not install or
switch the app on a device or change the backend configuration.

# BThere mobile project handoff

Updated: 2026-10-27 (Asia/Colombo).

Provider selection redesign: results now use BookingProviderResultsCanvas with
the map behind floating Back/service dropdown controls and a draggable white
provider panel. Compact cards show actual photos (fallback person), rating/review
counts, distance and backend language chips; no invented skills or live-status
indicators. Select/Selected highlights the card; sticky Continue retains existing
distinct-provider/team validation and opens the unchanged review flow. Back,
change-details, option switching, pagination, empty/errors and ONLINE mode remain.
Results map is read-only for booking location; recenter preserves the selected
search area and tapping provider markers selects that candidate. Resolved admin
marker icons retain priority; otherwise results can use circular provider-photo
pins. Other map screens retain their existing marker behavior.
Full Customer suite passed (247 tests before the final avatar-specific test),
followed by map/selection regression checks; analysis clean. Preview:
build/booking-previews/provider-results.png via tool/provider_results_preview_test.dart
(synthetic provider details, native map replaced by test canvas).

Add Card dialog explanatory paragraphs above fields and above submit removed per
user request; a compact Test mode label remains. Card number field detects Visa
(4) and Mastercard (51–55 / 2221–2720) prefixes while typing and shows the matching
SVG logo; unrecognized prefixes clear the logo. Detection is not validation and
does not relax Luhn/expiry/CVV or synthetic-card-only submission. Payment SVGs are
in assets/icons/payment; Visa path sourced from Simple Icons and viewBox trimmed
to remove whitespace, Mastercard uses the red/orange overlap mark. 18 card/wallet
tests pass, analysis clean, both brand previews visually reviewed.

Wallet now offers cards only. Add new payment method opens Add New Card directly,
without the old card/bank selection sheet. Manage lists CARD methods only and
offers Add card; existing backend bank records are retained but hidden in this
Customer UI. Dialog remains explicitly test-only. It can be previewed when card
linking is disabled, but submit is disabled with the backend availability reason;
controller capability/eligibility checks are rechecked before setup.

Location search now autocompletes after 350 ms without typing (2–200 chars),
keeping keyboard focus. Manual search remains available and cancels the debounce.
Query changes, map/GPS selection and disposal invalidate stale predictions and
details. IME composition waits until committed before auto search; selected place
details are still fetched only on explicit selection. Google attribution remains.

Booking maps now start over Sri Lanka (7.8731, 80.7718, zoom 6.5) before GPS or a
manual selection; the camera fallback does not select a booking location. Camera
zoom accounts for visible map height, and native camera bounds include the search
circle plus returned provider pins. Resize/results updates debounce camera moves.
Coincident provider pins (including overlap with customer pin) are deterministically
spiderfied with connectors to authoritative backend coordinates and an explicit
shared-location InfoWindow. Distinct coordinates and custom icons are retained;
no coordinates are invented for candidates with missing mapPoint. Expanded pins
stay inside the search circle when their shared centre is inside. Backend data,
filtering, booking positions and provider IDs remain unchanged. 44 map/GPS/booking
widget tests pass; analysis clean. Phone disconnected during live marker audit,
so changes still need a real-device visual check after restart.

Home no longer shows the Service area/market selector beside the greeting, per
the latest request. Greeting and name are a simple left-aligned column. Existing
market selection/persistence remains accessible through Profile > Change service
area, with its routing/persistence checks updated accordingly.

Add New Card reference dialog is implemented as explicitly test-only: local name,
Visa/Mastercard+Luhn, expiry and 3-digit CVV validation, formatted inputs, masked
CVV, responsive scrolling and double-submit protection. Only synthetic 4242 is
accepted until real hosted linking exists. PAN/name/expiry/CVV never go to backend,
storage or logs; inputs clear before request/close/background. The actual existing
setup call remains no-body and refreshed server metadata remains authoritative.
No unsupported Save card checkbox/encryption promise. See the Add Card section in
docs/customer-wallet-implementation.md for the required live gateway contract.
Validation: 235 Customer tests pass; analysis clean. Rendered dialog checked with
the existing Wallet background and shared chrome.

Customer Wallet initial screen is implemented at /wallet and linked from the
footer, matching the supplied middle-content reference and reusing shared chrome.
See docs/customer-wallet-implementation.md for exact implemented behaviors and
remaining funding flows. Balance/methods/history/reconciliation are backend-backed;
Total spent is replaced with Reserved/Pending because no spend summary exists.
Live Add money remains unavailable; no fake credit or mock success is generated.
Explicit test-method setup is capability gated. 228 Customer tests pass.

User provided the full API reference, saved verbatim
to docs/customer-api-reference-2026-10-25.md. Wallet endpoints, mock/live payment
boundaries and implementation notes are in docs/customer-wallet-implementation.md.
User will supply a Wallet image: implement only its middle content; reuse our
existing header and footer, regardless of the image's header/footer design.
Home's header is now the reusable app/widgets/customer_top_bar.dart component.
Wallet screen/routing is now implemented; funding-flow design is the next step.

Home top bar matches the supplied reference with home_logo.svg (white wordmark),
home_header_background.png and translucent circular notification/profile controls.
The background SVG embeds a bitmap; original SVG is retained alongside extracted
PNG. Header overscan clips the bitmap's baked checkerboard outer frame. Native
status-bar insets are handled by SafeArea; light system icons use AnnotatedRegion.
No simulated status time or unread badge is drawn. Notification button explains
the feature is coming soon; profile navigation and saved profile photos remain.
Home preview and 320px/2x-text layout pass; Customer analysis is clean.

Get a Service home card uses the user's image 48.svg artwork. Original retained
as assets/illustrations/get_a_service.svg. The SVG is a wrapper around an embedded
1907x825 PNG; its original PNG bytes were extracted unchanged to get_a_service.png
and only that PNG is bundled/rendered as the full card background, aligned right.
Large text reduces artwork opacity for readable copy. Preview verified at 430px
and 320px with 2x text; analysis clean. Reproduce with tool/home_preview_test.dart.

Navigation icons now use the user's 10 Figma SVG exports, copied unchanged into
apps/customer_app/assets/icons/navigation/ with tab.svg / tab_selected.svg names.
The folder is registered in pubspec; SvgPicture renders each state with original
white outline / teal filled colors in a 24px box, retaining the compact footer.
Navigation tests, SVG preview render and Customer analysis pass. Newly added
assets require a full restart if the running Flutter process cannot load them.

Customer bottom navigation now follows the supplied teal design with a white
selected pill and Home / Opportunities / Services / Messages / Wallet labels.
The shared CustomerBottomNavigation is used on Home and Services with the
appropriate selected state. Home/Services route normally; the three unfinished
destinations show a coming-soon snackbar rather than opening unrelated screens.
Existing recent bookings remain on Home and My bookings is also accessible from
Account. Profile remains accessible through the Home avatar. System bottom
insets are respected; enlarged text scrolls horizontally without truncation.
Validation: 220 Customer tests pass and analysis is clean. Reference preview:
apps/customer_app/build/navigation-previews/bottom-navigation.png, reproducible
with tool/navigation_preview_test.dart and FLUTTER_SDK pointing to the SDK root.

Service-specific reusable requirements: a known ineligible customer sees an
"Additional details needed" badge with View details. Continue opens the existing
schema-driven additional-information form before filter validation or provider
search. Live searches are suppressed until eligibility is satisfied. Text,
choices and file uploads keep the existing typed submission API. Pending,
rejected, expired and approved statuses remain backend controlled. Refresh now
reloads both requirement rows and eligibility without resetting the booking
draft. After approval the action returns to location/time selection. Eligibility
failures during live preview also refresh the requirement schema and access.

Empty availability after Continue is a neutral teal notice, separate from errors:
"No matching providers just yet" (or a team-size explanation), with guidance to
change time, search area or filters. Editing clears the notice. Actual request
and validation failures retain their error handling.

Live filter preview: while selecting location, radius, time, languages, skills or
configured provider filters, availability refreshes after 500 ms without edits.
The map count and backend markers update before Continue; preview requests never
advance the screen or block editing. Obsolete responses are ignored. Errors show
a retry action instead of claiming zero providers. Continue still rechecks the
backend before opening booking questions.

Latest flow: Location/time Continue refreshes context and POSTs the real provider
search with selected time, location/radius, languages, skills and configured
filters before opening Service Details. AVAILABLE opens booking questions;
NO_AVAILABLE_PROVIDERS stays on filters with a clear empty/insufficient-team
message. API/eligibility failures are not presented as zero providers. If the API
requires customer eligibility first, only the requirements UI is exposed until
access is resolved and availability can be checked.

The form map displays returned mapPoint coordinates and backend-resolved
mapMarker.icon.url artwork. The count deduplicates provider IDs; a + indicates
more result pages, with a Show more available providers control to add their pins.
Provider-location result totals are not mislabeled as distinct provider totals.
Availability stays visible while editing booking answers, but mismatched time,
location, radius or filters hide the old snapshot. Long forms leave map space
for the count badge. Final provider search/selection and server booking checks
remain in place; a preview does not reserve a provider.
Verification: all 212 Customer tests passed (concurrency 2), final native-map
regressions passed, analysis clean, and the synthetic availability-count preview
was visually reviewed. Actual deployed provider availability was not queried.

Service option selector: both form headers now open an anchored dropdown of
backend options for the current service category, rather than triggering Back.
Selecting another option replaces the booking route directly and reloads its
context/requirements/eligibility. Common location/address/time/radius and valid
preferences transfer only within the same account/market; option-specific answers
and provider results reset. Service Details stays selected when the transferred
preferences satisfy the new option; otherwise location/time asks for missing
choices. The left Back button retains its original navigation behavior.
Verification: all 205 Customer tests passed at concurrency 2; analysis clean.
The initial parallel full-suite run had one profile-image timeout; that test
passed in isolation and the subsequent complete run passed.

Booking schema refresh fix: Continue into Service Details now fetches fresh
booking context (including the physical pricing point) before showing questions.
New Admin fields returned for this service/option therefore appear without
reopening the booking. Unchanged answer IDs/versions/types and valid preferences
are preserved; obsolete answers/options are pruned and changed preferences are
revalidated. A failed refresh stays on the current step with retry feedback.
62 booking controller/widget regressions pass; Customer analysis clean. The
reported live field name/association has not yet been supplied, so whether that
specific field is returned by the deployed API remains unverified.

Location display refinement: location cards show only the first address segment
on one line with ellipsis, while the complete address remains in the booking
draft/payload. The current-location button is anchored at the lower-right edge
of the visible map, just above the draggable form, rather than mid-map.
Short labels now skip number-only segments, Plus Codes and unnamed roads, strip
leading house numbers and prefer the first named street/area. Unicode place
names are retained. The original full address is still untouched for booking.

Latest request: hide required asterisks in booking field labels while retaining
backend-required validation. A fresh physical location step automatically requests
foreground GPS and centers/selects its result. Native reverse geocoding now fills
the address for GPS/manual pins; stale results cannot replace a newer selection.
Existing selected pins are preserved on return; permission/GPS or address lookup
failure retains map/Places search fallback. Customer now depends on geocoding
5.x, already present in the workspace for Provider. Restart the app for native
plugin registration. GPS/address plus booking widget regressions: 29 passed.

Latest Service Details refinements: Patient-name help descriptions are hidden;
other backend descriptions remain. Schedule summary says Duration. Responsibilities
section is removed. Service address is read-only here; select it in the prior
location step, which now catches a missing address before continuing. Required
asterisks still reflect only backend `required: true`; optional fields omit them.

Reference compactness refinement: Service Details uses 8px card padding/gutters,
6px card spacing, 12px field labels and a shorter date/time summary (full date is
retained for accessibility). Short text/number/date/time fields can share a row;
phone/email and long labels use full width. Booking-question icon wells render
only when the backend supplies an icon URL, reclaiming input width otherwise.
Additional notes remain backend-defined only. Existing validation/sticky footer
and responsive large-text fallback are preserved.
Service Details can collapse to 25% height, allowing short forms to fit content
without the previous 35% minimum adding unused space above Continue. Location/time
retains its 35% minimum.

Latest request: removed the app-defined Additional notes box from Service Details.
Questions/instructions should come from backend booking fields; configured
TEXTAREA fields still render normally. Location/schedule summaries and navigation
remain. Older notes below about an optional notes box describe previous UI.

Newest milestone: Service Details now follows the completed location/time UI:
content-height expanded default, drag-to-collapse, sticky Continue, compact card
spacing/theme tokens, choice tiles for small configured choice sets, and inline
required-field highlights. Typed values (including false and zero), conditional
fields, the optional 4000-character note and existing booking APIs are preserved.
All 197 Customer tests pass and analysis is clean. This supersedes older notes
about a separate 46% initial Service Details height and scrolling Continue.

Latest UI update: Location/time now opens at its measured content-height maximum
by default. The customer can drag it down to reveal more map, then expand it again.
Continue stays pinned; large content remains scrollable. Service Details retains
its separate initial height. This supersedes the historical half-height default.
Location/time footer spacing is compact: 8px scroll bottom padding plus 8px
footer top padding; no unconditional trailing schedule/form spacers. Content
height measurement uses the same padding so reducing the gap also shrinks the sheet.
Location/time Continue now requires a selection for every displayed configured
provider filter, fallback language choices and any displayed skills. This is a
customer-requested UI rule, not a new backend required flag. Empty selections keep
the customer on this step with field messages. Existing future-time/location rules
remain, and explicit Boolean false / numeric zero are accepted. Booking controller
and widget suites: 58 tests passed; Customer analysis clean.
Validation presentation now highlights each invalid group with a red outline,
subtle tint and nearby hint, rather than a top-of-sheet error list. Correcting
one group revalidates the form and clears only resolved errors. Location/schedule
and skill controls also use inline hints; Service Details keeps its existing
error handling. Booking regressions remain 58 passing; analysis clean.

## Resume here

Continue in this workspace: `D:\Projects\bthere-mobile`.
This handoff was checked against the current source, Git status, milestone docs,
and the old **BThere App** conversation, read without editing its history.
Old conversation ID: `01a121c3-eff9-7e90-b11d-d4dba2299561`.

The latest request was: remove the **Spoken languages** heading, keep the language
buttons, and let the location/time panel expand only as far as its content needs.
The old turn stopped after partially editing and formatting the panel. It did not
finish verification. This continuation completes the configured language-filter
heading removal and verifies the existing content-height panel implementation.

## Working tree and boundaries

- Flutter/Dart Pub monorepo: `apps/customer_app`, `apps/provider_app`, shared
  packages under `packages/`. Flutter is installed at
  `C:\Users\hjana\develop\flutter`; use its Dart SDK.
- The Customer implementation, assets, tests, tools, and many milestone documents
  are currently **untracked**, alongside tracked modifications to app bootstrap,
  dependencies, native configuration, README, ignores and the root lockfile.
  They are existing project work: do not clean, reset, overwrite, or discard them.
- No commit or push was performed in this continuation. No Provider or shared
  design-system changes were needed for the latest UI request.
- Keep API field IDs, options, typed values, validation and payloads backend-driven.
  Do not invent production configuration, fake provider availability or APIs.
- The README's statement that Customer is a scaffold is outdated. Prefer actual
  Customer source and the newer milestone documents below.

## Delivered project work

Source and tests exist for these Customer capabilities; these are implementation
milestones, not a claim that every live backend/device integration was exercised:

- App-local configuration, Riverpod composition, navigation, email/phone auth,
  verification, session lifecycle and authenticated profile entry.
- Profile completion/editing and profile-photo upload.
- Per-account/environment persisted market selection, Home/service discovery,
  service options and configured booking context.
- Booking requirements, eligibility, typed/conditional service questions, location
  and address search, current-location startup, scheduling, provider search and
  explicit selection, review, quote and supported booking/payment stages.
- Backend-resolved map markers and configured pricing choices. Server pricing
  remains authoritative; quotes do not reserve availability.
- Customer-local Public Sans assets/theme, teal palette and compact form styles.
- Location/time form starts around half height, drags upward, keeps Continue
  outside the scrolling content, and uses a compact floating service badge.
- Gender/language selection tiles, side-by-side Location/Radius cards and a
  dedicated radius picker. Single start-time slider uses 15-minute steps; the
  default is the next future quarter-hour in the market timezone, with duration
  deriving the end time. Missing-field validation remains actionable.

## Latest request: implementation and verification

- `booking_details_canvas.dart` already contained the interrupted turn's
  post-layout body/footer measurement. It caps the location/time sheet at content
  height, bounded between 35% and 94% of available height, and clamps initial
  height/snap positions. Larger content remains scrollable. Service Details keeps
  its existing separate panel behavior.
- `customer_booking_screen.dart` already omitted the legacy language heading.
- `booking_provider_filters.dart` now also omits the heading for configured
  language filters. Backend choices and toggle/deselect behavior remain intact.
- Added a booking widget regression using configured Spoken languages choices:
  heading absent, selection/deselection works, maximum expansion fits short
  content, and the fully expanded panel has no excess scroll extent.
- Targeted new regression passed. The pre-change 19 booking widget tests passed.
- Full Customer suite: **189 tests passed**. Customer analysis: **no issues**
  after completing the interrupted panel code's missing-braces lint fix.
- This continuation did not build an APK or exercise a live device/backend.

## Remaining work / practical next steps

1. On the running Customer app, hot reload and visually check the location/time
   panel with the real backend fields, including short/long content and large text.
2. Review backend integration gaps in `docs/customer-booking.md` and the provider
   search plan before implementing another workflow. Automatic dispatch, provider
   acceptance, live presence and wallet settlement must not be inferred from the
   implemented explicit-selection flow.
3. Native-device behavior and iOS need their own validation. Older foundation docs
   record Provider test failures; they were not rechecked or fixed here.
4. Review/stage existing project changes deliberately before any future commit;
   Git's tracked diff alone does not show the large untracked Customer feature set.

## Useful references and commands

Read `docs/customer-booking.md`, `docs/customer-provider-search-booking-plan.md`,
`docs/customer-design-system.md`, `docs/customer-email-auth.md`,
`docs/customer-phone-auth.md`, `docs/customer-profile.md`, and
`docs/customer-market-home.md`. Earlier milestone documents can describe states
that later milestones supersede.

From `apps/customer_app`:

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter run --dart-define-from-file=../../config/customer.local.json
```

The older chat reported 188 passing Customer tests, clean analysis and a successful
debug APK before the latest request. Treat those as historical results.

Customer configuration now uses `config/customer.local.json` (ignored) with a
tracked `config/customer.example.json` template. API URL and the Google Maps/Places SDK key are included; see `docs/customer-configuration.md` and
`scripts/run-customer.ps1`. Customer Google Maps and native Google Places search are now implemented.

## Troubleshooting history outside app code

The old chat stalled with connection resets/DNS failures; short health checks did
not establish its full cause. Its history was approximately 193 MB and recent
input about 234k tokens, below the reported context limit. Do not assume size alone
proves the cause. This new conversation avoids replaying that full history.

An earlier troubleshooting turn repaired the `.git` directory owner/user ACL and
confirmed sandbox commands worked. It also changed Wi-Fi IPv4 DNS from the router
to `1.1.1.1` / `1.0.0.1`; the VPN was not changed. A proposed ChatGPT-specific DNS
rule was rejected and was not installed. The user subsequently requested no
VPN/network changes. Do not continue network troubleshooting as part of UI work.
ACL/DNS backups and repair outputs are in `%TEMP%\bthere-codex-repair`.


## Google Maps migration ? 2026-10-26

All Customer map surfaces now share the Google Maps location picker. Android
Gradle decodes the JSON Dart defines into manifest key metadata; iOS startup reads
the same define via Info.plist. Customer flutter_map/latlong2 dependencies and OSM
tile settings were removed. The user-supplied local key was preserved and never
copied to the example file. Native Google Maps requires a full app restart.

GPS/search camera updates, radius circles, provider marker identities, resolved
raster/SVG artwork and disabled-state behavior are retained. The map viewport
resizes with the booking panel to leave native attribution visible. Address search
remains Photon; Google Places migration is separate. Customer tests: existing 189
passed plus 3 new Maps checks passed with a synthetic key; analysis clean.
Android debug APK build passed, and the merged Android manifest key was verified
against the ignored local JSON without printing it. Native map rendering/key
authorization still needs a device check; iOS has not been built on Windows.


## Google Places search ? 2026-10-26

Supersedes the earlier Photon search notes. Search now uses native SDK
predictions plus selected-place details; all Google calls use the existing JSON
Maps key. Photon source/config/attribution are removed. Query submission retains
country restrictions; no details request is made for unselected suggestions.
Google attribution and returned place credits are displayed. No search-result
cache is persisted. Stale details and repeated errors have regression coverage.
All 193 Customer tests pass with a synthetic key; analysis clean. The Cloud
project/key must allow Places API (New). iOS native plugin/API compatibility
still needs a macOS check. Android debug APK build passed with the local JSON.
The plugin pair is pinned to flutter_google_places_sdk 0.4.2 and Android 0.2.1
because Android 0.2.2 has upstream compile errors. Actual Places authorization and
search results still require a live device check after enabling the Cloud API.

## Latest booking flow correction - 2026-10-27

Completed the interrupted Open/Direct request navigation work. Open requests go
from filters and availability directly to booking details. Direct requests show
the provider map/list first, then booking details after selection. Answer edits
preserve selection; matching-filter edits invalidate it. No providers blocks
progress. Request-policy-enabled creation uses the scheduled requests endpoint;
Open payloads omit provider IDs. Creation is a request receipt, not payment or
provider confirmation. Backend policy must enable Open requests. Regression
coverage includes both routes, answer validation and idempotency reuse.

## Booking review presentation - 2026-10-27

Review now groups service, schedule and compact location into a summary card
with Edit returning to booking details. Dynamic backend answers and selected
providers remain in a separate details card. Payment methods have icons and a
selected-state border; server estimated total is emphasized. No fabricated
prices or provider acceptance. Booking widget regression tests: 33 passed.

## Wallet saved-card presentation - 2026-10-28

Wallet with saved cards now shows Wallet / Manage your money, outlined payment
method rows, a dedicated logo area, method details action, and persistent Add
new payment method action. Brand SVG is shown only for explicit supported brand
metadata; generic mock methods remain honestly labelled. History has circular
icons and positive available-balance movements highlighted green. Shared header
and navigation retained. No invented expiry, default selection, balance or total
spent. Wallet regression tests: 10 passed; Flutter analysis clean.

## Add Money implementation - 2026-10-28

Reference-based scrollable Add Money sheet now replaces the informational panel.
Quick amounts 1000/2000/5000/10000, exact-decimal custom amount validation,
explicit saved mock CARD selection, nested existing Add Card UI, dynamic amount
CTA and backend capability gating. No fabricated brands or mobile-pay support.

Mock integration: POST /me/wallets/LKR/topups with amount, methodId and a random
Idempotency-Key. Encrypted environment/account-scoped pending payload is written
before POST; reopening/retrying retains the same input and key. PENDING does not
credit or show success. Explicit Complete test payment reads the intent then
posts mock SUCCESS only if still PENDING. Terminal results refresh authoritative
wallet data; test funds remain labelled. Auth changes invalidate panel actions.
Live card top-ups are not implemented by this generic MOCK-only API. Backend
must enable topups capability and configure the mock gateway to exercise it.
Wallet tests 13 passed, including pending/success separation, recovery on reopen,
amount precision and narrow viewport; analysis clean.

## Wallet Manage and full history - 2026-10-28

Manage opens a reactive compact bottom sheet with all saved CARD methods, close,
empty/error/loading states, and the existing Add Card dialog. Card rows inside
Manage do not recursively reopen Manage. No unsupported delete/default actions.
View all now opens a separate history screen with shared header/navigation,
Back to Wallet, pull-to-refresh, paginated Show more payments, retry/error/empty
states and grouped ledger movements. Wallet home remains a three-operation
preview. Amount visibility follows the wallet's privacy setting.

## Booking payment chooser / saved-card fix - 2026-10-28

Create booking now opens a dedicated payment-method sheet before confirmation.
The previous unset-method branch incorrectly opened Add Card without checking
saved instruments. The new sheet offers only backend-enabled CARD/WALLET/CASH;
legacy CARD checks the authenticated saved-card list and opens Add Card only
when no usable card exists. Existing cards bypass setup. Scheduled hosted request
payments remain separate after acceptance. No eZ Cash integration or fabricated
price; a missing quote is explicitly marked server-confirmed amount pending.
Payment selection does not create or pay a booking. Existing confirmation stays.
Booking regression suite 84 passed; separate no-card fallback regression passed;
Flutter analysis clean. Tests cover unset method + existing card, no duplicate
setup calls, missing-card fallback and full legacy booking navigation.

## Hot reload navigation reset fix - 2026-10-28

CustomerBootstrap recreated CustomerConfig.fromEnvironment() inside build on
reassemble. Its new override identity invalidated dependent providers, including
router/auth/discovery, returning navigation to the startup/home route. Bootstrap
now retains the configuration once in State; config/environment changes still
require restart. An injectable loader supports isolated hot-reload regression.
Tests use real Flutter reassemble, pumping its required end-of-frame: config and
router identity, current route, and actual booking review/controller/provider
selection/draft survive. Root StatelessWidget -> StatefulWidget requires one
Hot Restart to install this structural change; subsequent UI edits use hot reload.

## Reference-based booking review - 2026-10-28

Supersedes the separate payment chooser milestone. Review now uses the existing
map/draggable canvas with read-only selected location and recenter. Summary
contains backend service/field icons, compact location, chosen providers,
conditional answers (short answers paired), and schedule/duration tiles. Edit
returns to booking details with the draft preserved. Estimated total is formatted
as LKR currency only from server quote; missing quotes show explanatory text.
Enabled CARD/WALLET/CASH choices are inline with brand acceptance logos. No
unsupported eZ Cash or fabricated amount/availability. Primary sticky Confirm
booking (or Send request) validates the inline choice, checks saved mock cards
before Add Card, then asks confirmation; it does not claim payment success.
Preview price disappears once a current quote exists; changing pricing or method
invalidates it. Review map taps cannot change the draft. Widget + hot reload
regressions: 39 passed, including narrow large-text review and saved-card paths.
Synthetic visual preview: build/booking-previews/review-map.png (test map, not
live map tiles). Flutter analysis clean.

## Booking details Estimated cost - 2026-10-28

Added a compact Estimated cost card below schedule/duration on the details form.
Direct requests debounce a read-only backend quote after required dynamic fields,
configured pricing choices, valid schedule and provider selection are ready.
Inputs include actual start/end and typed answers. Changes clear stale amounts;
late responses are rejected by generation. No global busy flag or booking write.
Errors have a local retry and never show zero as a failed estimate. Quote-only
payment fallback uses an allowed method without changing the user's checkout
choice. Pricing dimensions can be selected in details using exact context IDs.
Open requests show cost-after-acceptance explanation; no fake provider IDs or
client-computed rates. Regression suite: 89 booking tests passed, covering
interval payload, stale response rejection and Open request fallback.

## Pre-acceptance Open request estimate API - 2026-10-28

Supersedes the previous Open cost-after-acceptance limitation. Integrated the
backend developer's new POST /customers/me/bookings/estimate read-only contract:
{marketId, booking:{serviceTypeId, optionId, deliveryMode, startDatetime,
expectedEndDatetime, meetingPoint, pricingSelections}}. Open estimates exclude
provider IDs, booking answers and payment method and are fetched before required
name/contact answers are complete. Details and review both use the new endpoint;
Direct /bookings/quote stays unchanged. Debounce, stale-response rejection,
positive response validation and local retry retained. 400 shows input guidance;
404 means estimate unavailable (cannot distinguish missing deployment from a
missing configured rate by status alone). Never create booking/reservation/payment.
The supplied provider-to-customer shape is supported. Customer-to-provider Open
estimate is deliberately unavailable until its provider-independent location
contract is supplied; no speculative location field is sent. The backend doc path
on Rashen's computer is not present here. Hosted deployment was not verified.
Booking regressions: 90 passed, including provider/answer/payment-free payload
and 404 recovery. This update uses only the developer's pasted API contract.

## Visible details estimate footer - 2026-10-28

Moved Estimated cost into the fixed booking-details footer immediately above
Continue, so the amount stays visible while booking answers scroll. Pricing
choices remain in the scrollable form via BookingPricingChoices; the estimate
API/debounce/retry behavior is unchanged. Actual backend totals only, no reference
sample amount. Booking widget suite: 41 passed; Flutter analysis clean.

## Review footer correction - 2026-10-29

Read-only inspection of the connected phone identified that the user was on
review, while the earlier horizontal footer change applied only to details.
Review now also uses cost-left / confirm-right compact footer with pale teal
background. Removed the large empty-payment notice and omit the choices heading
when no methods exist; confirm still blocks unsupported payment and explains why
in a snackbar. No payment capability bypass. Existing device estimate was real
Rs. 21,000.00; this was a screen-target mismatch, not confirmed reload failure.
Temporary device screenshot removed after inspection. 41 widget tests pass;
analysis clean.

## Review reset after blocked checkout - 2026-10-29

The resumed lifecycle handler called full load() in review/results; load resets
the stage to filters and clears search/provider selection. Replaced this with
refreshCheckoutOptions(): safely refresh policy/capabilities, preserve draft,
selection, answers and stage, reject stale responses. Creation still validates
server availability. Removed the generic unsupported-gateways paragraph; no
payment support was invented or bypassed. A saved card does not enable checkout
when the selected service/policy/capabilities have no supported intersection.
New regression simulates blocked Open checkout followed by inactive/resumed and
asserts review, interval, note/search result remain with no booking-context reload.
Booking controller tests: 49 passed; widget suite: 42 passed; analysis clean.

## Compact review payment controls - 2026-10-29

Reduced review payment row density/padding, heading/title/subtitle sizes, brand
logos and trailing icons. Request/confirm button uses a local 44px-min theme;
shared buttons elsewhere are unchanged. Compact estimate amount reduced to16px,
and pre-footer spacing reduced. Cost-left/action-right layout retained.
Booking widget tests: 42 passed; analysis clean.

## Confirm and Pay / saved-card selector / wallet confirmation - 2026-10-29

Review primary action is now Confirm and Pay. CARD opens a reference-based saved
card dialog with explicit selection, Add New Card and Use Selected Card. Lists
actual server-returned VERIFIED_MOCK CARD methods; brand only when supplied,
no invented expiry/default flag. Existing Add Card is reused and list reloaded.
Saved mock method selection is UI-only: existing booking request/card-session
contracts do not accept a saved methodId. It is not live tokenized card charging.
Hosted PayHere checkout still requires its distinct post-acceptance billing/brand
flow; this change does not implement that hosted form.

Legacy WALLET creation now attempts its existing reservation endpoint after
successful booking creation. Scheduled requests do not charge during MATCHING.
After refresh reports AWAITING_CUSTOMER_CONFIRMATION, a Confirm and Pay with
Wallet action reads authoritative status and calls POST
/customers/me/booking-requests/{id}/confirm-wallet with no body. Identity guards,
server payment state, insufficient-balance retry on same request, and already
confirmed duplicate prevention retained. It never calls legacy wallet-payment
for a booking-request job. Pending is never shown as paid. No automatic writes
when provider acceptance is merely refreshed.

Tests: booking controller 52 passed, booking widgets 42 passed, wallet 16 passed
including multi-card selection, no-card add flow, no reservation before
acceptance, duplicate confirmation and insufficient-funds retry. Analysis clean.

## Payment result screens and supplied assets - 2026-10-29

Added standalone reference-style Payment Successful / Payment Failed screens
with pale teal painted background, circles/waves, outcome copy and actions.
Failure uses the user's image 51 (1).svg; its embedded PNG was extracted exactly
for reliable Flutter raster rendering, with original SVG preserved in
assets/illustrations/payment. The other supplied image 51.svg is only a 140-byte
empty rectangle (no paths or embedded image). Success currently has an explicit
check-circle fallback; the proper success bee SVG must be reattached to finish
that illustration. No generated substitute mascot was invented.

Result routing uses verified controller state. Scheduled success requires a
confirmed/in-progress/completed request with PAID/RESERVED/SETTLED payment.
Wallet reservation copy explicitly describes reservation rather than final
settlement. Mock card success is labelled test-only. Matching/PENDING and
network/5xx/unsupported responses never become success or failure screens.
Known server-declared failed outcomes and insufficient-balance responses use
failure UI. Try Again retains the same booking/request; change method requires
an explicit confirmation and confirmed unpaid-request cancellation before
returning to review. Legacy method changes remain unavailable without an API.
View booking dismisses success to its existing receipt; Home navigates normally.

97 booking tests passed; additional uncertain-payment regression passed in the
payment subset (7 passed). Visual preview tests 2 passed. Preview PNGs live in
build/booking-previews/payment-success.png and payment-failed.png. Native device
flow not executed; no real payment or cancellation was sent during development.
New assets are registered in pubspec; a hot restart may be needed to load them.

## Payment confirmation, finding and acceptance UIs - 2026-10-29

New supplied assets inspected and renamed, originals retained and embedded PNGs
extracted losslessly: payment_success, finding_provider, provider_accepted.
The earlier empty success asset is now replaced with the real success bee.
Review Continue now opens a dedicated map-based Payment confirmation screen;
only Confirm and Pay submits. The saved-card selection is shown before that
screen. Existing backend order and enabled methods are preserved.

Created MATCHING requests show the animated finding screen. Safe GET polling
runs every five foreground seconds, stops with disposal/background, and routes
to accepted UI on AWAITING_CUSTOMER_CONFIRMATION. Real candidate metadata is used
when the accepted providerId matches; no invented photos/ratings/badges. The
accepted countdown uses actual confirmationExpiresAt; no fake 30-second timer or
auto-charge/auto-approval is implemented. Cancel requires explicit confirmation
and server-confirmed unpaid request cancellation. Request details/payment remain
accessible. Success still requires actual paid/reserved confirmed backend state.

User clarified intended future flow is hold before matching, finalize after
acceptance. Current API does not implement pre-match holds; user informed that
backend contract is required. Concrete request saved in
 docs/customer-pre-match-hold-backend-request.md. No invented endpoint or live
money operation was used. Existing flow remains match -> accept -> confirm pay.

Booking regressions: 99 passed plus the corrected polling test passed separately
(100 total cases). Four standalone mascot preview cases passed across runs.
Analysis clean. New booking asset folder requires asset-bundle refresh/restart.


### Booking form keyboard layout

Keyboard visibility is passed from above the resizing Scaffold into BookingDetailsCanvas. While editing, the sheet expands below a compact service header, hides map controls/availability badge, pins a Done keyboard-dismiss toolbar, and reveals the focused EditableText through the form scroll position. On very short viewports, the footer joins the scroll content. Keyed form/scroll subtrees preserve focus and answers when the toolbar/footer layout changes. Closing the keyboard restores the prior sheet extent. Input fields have explicit scroll padding. No booking or provider API rules changed.

Validation: two keyboard layout tests at 430x932 and 430x568, each with a 360px keyboard, passed; 49 booking widget/map regressions also passed. Tests verify field visibility, tappable Done, retained answers/location and restored sheet position.

Keyboard layout refinement: at the user's request, the editing sheet now fills 100% of the viewport above the keyboard, with safe-area protection and a square top edge. The map is fully covered and retains its pre-keyboard dimensions underneath. Dismissing the keyboard restores the prior sheet extent and map/form view. Both keyboard regression cases pass with full-screen extent assertions; changed-file analysis is clean.

Review payment visibility refinement: review sheets may now use the map/badge area when needed to display all available methods. Sheet extent updates are applied after new layout constraints arrive, fixing expansion that was clamped by the old maximum. Native map resize listeners schedule rebuilds safely outside build. User drag/scroll choices remain respected. Payment footer spacing includes clearance for the final method row. Regression coverage verifies two-method open requests on 360x780 and three-method direct requests on 393x852 without scrolling. All 53 booking/keyboard/ripple widget regressions passed.

Matching/cancellation flow: removed View request details from matching/accepted progress UI; backend polling automatically switches matching to provider accepted. Existing Continue to payment remains on accepted UI. Added BookingCancelRequestDialog in the shared white/teal/coral style. Confirmation pauses background polling underneath it. Only server-confirmed unpaid cancellation returns to the payment confirmation screen, retaining draft answers, location, schedule, filters and payment selection. Failed cancellation stays with the current request. Pending creation storage is cleared before retry checkout so a later submission uses a fresh idempotency key. Default cancelCreatedRequest behavior still retains the cancelled receipt for other callers. Validation: 105 booking controller/widget tests passed; final matching/modal cases also passed after the polling guard.

### Provider service loading compatibility (2026-11-02)

Emulator diagnostics identified SCHEMA_INVALID_RESPONSE / Mismatched field when opening registered services. Hosted onboarding schema returns matching legacy optionId and current optionIds together; linked options also retain requirement fields owned by the source service. Updated provider_schema_response.dart to accept consistent legacy/current membership and linked option ownership, preserving the original field serviceTypeId. Common field service ownership, schema IDs, option membership and duplicate validation remain enforced. Removed temporary debug diagnostics after investigation. Added three regression tests; all 35 provider requirements tests pass and changed-file Flutter analysis is clean. Overview suite has two golden image mismatches (37 other tests passed); reference images were not updated. Corrected debug APK installed on emulator-5554 without clearing login data.

### Provider incoming request integration (2026-11-02)

Merged origin/dev-vishwa through d1d658c into feature/customer-app as 95a3bf8. Incoming offer polling, Opportunities, Accept/Decline, native Android looping alert, booking details and payment-window flows are now connected through BookingOfferHost in ProviderShell. Foreground/resume polling runs every five seconds; Firebase background/locked-screen delivery remains unimplemented. Keep provider app foregrounded when testing. Native Android changes require stopping and rerunning the provider app, not hot reload alone.

Kept the real CustomerBootstrap and customer pubspec during merge, avoiding the incoming demo main and duplicate YAML/font keys. Restored all existing customer UI edits and untracked work from safety stash; content hashes matched the backup. The safety stash remains retained. Upstream linked-schema handling supersedes the local parser fix and includes equivalent regression coverage. Fixed imported brace lints and updated the customer theme test's shared Provider font expectation from Nunito to PublicSans; customer typography itself is unchanged.

Validation: 63 provider booking/schema tests passed; customer integration run had 115 passing cases plus one outdated shared-font assertion, then both theme tests passed after correcting that expectation. Shared design-system tests: 23 passed. Provider and customer analysis clean. Provider Android debug APK built successfully. No apps launched or installed during this integration; user requested to run them from their own terminals. Live offer delivery still needs a fresh eligible customer request with provider app foregrounded. No push performed.

### Offline booking UI preview gallery (2026-11-02)

Added debug-only lib/main_booking_preview.dart and scripts/run-booking-preview.ps1 (-DeviceId, optional -Scene accepted). Normal production main.dart is untouched. The gallery uses sample data without auth bootstrap, API repositories, persistent storage or Google Maps. It runs under the existing Customer app ID and preserves account storage. Stop preview and rerun run-customer.ps1 with configured defines to return to live testing.

Nine selectable states: finding, accepted, paymentDue, paymentPending, success, failure, confirmed, expired and cancelled. Freeze countdown defaults on; live ticking is opt in and never auto-navigates even at zero. Controls include animation pause, long names, busy buttons, text scaling 1.0-1.6, 30-second and expired deadlines. Current selection survives hot reload. Provider app is unnecessary for preview work.

Extracted BookingRequestProgressView (presentation/animation only) from the existing progress controller wrapper; actual polling and countdown behavior stay in BookingRequestProgressScreen. Extracted BookingRequestReceipt from CustomerBookingScreen with the same real callbacks and styles. Gallery uses these actual widgets, existing payment result screen and cancellation dialog, so UI edits apply to real checkout too. Preview actions only navigate sample states; no real booking/payment.

Validation: 4 new preview widget tests plus 47 existing booking widget tests passed (51 total). Tests cover frozen time across rebuild, opt-in clock expiry without navigation, local payment navigation, all scenes on compact phones, long names/1.6x text and disposal. Full Customer Flutter analysis clean; PowerShell launcher parses with zero errors; standalone Android debug preview APK built successfully. No apps installed/launched; user runs commands. Full instructions and Mermaid state map: docs/customer-booking-ui-preview.md.

Provider accepted UI refinement: extracted presentation-only BookingProviderAccepted used by the real progress view and offline gallery. Compact heading/illustration, constrained 420px card, 58px avatar with fallback, wrapped name/rating with gold star, actual service label, pale countdown panel with tabular figures and expired styling, 48px full-width Continue to payment button with busy indicator. No acceptance/payment/deadline logic changed; no invented verification badges or provider metadata. Compact and 1.6x text countdown overflow found and fixed. Existing 47 booking widget cases passed; all four preview tests pass after wrapping fix; two matching/accepted render cases pass. Changed-file analysis clean. Visual render inspected at build/booking-previews/provider-accepted.png. Hot reload with preview Scene accepted to review.

Payment confirmation UI refinement: BookingRequestReceipt now presents friendly state headings, formatted server amount, selected-method card using the existing wallet SVG, state-specific guidance, a 48px Confirm and Pay action and secondary refresh/home actions. Raw enum codes removed from displayed copy. Wallet confirmation remains gated by the existing AWAITING_CUSTOMER_CONFIRMATION + WALLET condition; busy disables actions; PAYMENT_PENDING has no repeat-pay button. Confirmed RESERVED copy explicitly describes reserved funds. No API/controller/payment behavior changed. Preview assertions now verify formatted amount and no pay action while pending, with ensureVisible for short test viewports. All 47 real booking widget regressions passed; four preview cases pass after adapting short-viewport scrolling. Visual render inspected at build/booking-previews/payment-confirmation.png; render case passed; changed-file analysis clean.

Payment confirmation/pending reference artwork (2026-11-02): imported user SVGs as payment_amount_banner.svg, secure_payment_card.svg and secure_payment_mascot.svg under assets/illustrations/payment, preserving originals and extracting their embedded PNG bytes without pixel edits. Shared booking_payment_visuals.dart supplies rounded teal-header payment page, security mascot heading, amount artwork and selected-method/status cards. Real scheduled-request receipt path and debug gallery use the same page; existing API callbacks, status/result precedence and error display retained. New BookingPaymentConfirmation follows the supplied reference; pending uses matching artwork/style and only Check payment status, never a repeat-pay action. Confirmed/expired/cancelled states retain their existing receipt presentation. 51 preview/real booking UI regressions pass; two full-artwork visual renders pass and were inspected after explicit image precaching. Full Customer analysis clean. New assets require restarting/re-running the preview bundle. No apps launched or installed.

Payment failure UI: replaced the old duplicated success/failure conditional layout with a separate presentation-only failure view. Existing failed mascot, pale coral reason notice, consistent navy typography and 48px retry/46px change-method actions on the flow backdrop. No enclosing action card. Missing method-change capability still disables its action and explains availability; busy disables all actions. Existing keys/callbacks, backend reason and test-mode labeling retained. 51 preview and booking UI tests pass, success/failure render tests pass and changed-file analysis is clean.

Provider search previews: added providers (Provider list) and providerDetails to the offline gallery. Extracted the existing BookingProviderResultsView presentation from its real controller adapter; existing sheet, cards, map viewport, selection/count and continuation logic retained. Offline preview injects a labeled sample map and five sample candidates, with no auth/map SDK/API. Optional card onDetails callback is used only by preview; live card taps still select as before. No standalone provider profile screen exists in current app: details preview explicitly wraps existing BookingProviderCard and labels this limitation. Sample selection survives details/back; Continue only shows a local notice about the real booking-details destination. Five preview tests pass, including all 11 scenes and select/details/back/continue behavior; 47 real booking UI regressions also passed. Full Customer analysis clean. User can hot reload and choose Provider list / Provider details from Preview menu.

Provider list reference refinement: compact rounded navy-name cards, 54px photo/fallback avatars, gold rating stars with separate review counts, lilac language chips, consistent Select/Selected and Continue actions. Actual candidate metadata only; no invented online indicators or specialties. Results map now prefers provider profile photos when preferProviderPhotos is enabled; original custom icon remains fallback if photo is missing/fails, and non-photo map screens retain their custom icons. Coordinates, range/search, coincident-pin connectors, provider IDs and selection logic unchanged. Eight map tests pass including simultaneous custom/photo data and failed-photo fallback; combined map/preview/live-booking run: 60 pass. Provider list visual render passed and inspected; changed-file analysis clean. Offline preview has generic avatars until real profile photos are supplied; live map reads actual candidate.profilePhoto.

Provider details popup: implemented BookingProviderDetailsDialog to match reference with rounded white modal, photo fallback/name/rating, optional experience/location/about, skill and language chips, optional previous-work review cards, top close icon and pinned Close button. Candidate card taps in the live direct-request list now open this popup; Select still performs selection. No new API endpoint was invented: live dialog shows candidate search fields only; optional typed ProviderProfileDetails/ProviderWorkReview data is supplied by the debug preview with explicit sample biography/skills/reviews. Missing extended sections and verification badges are not fabricated; review counts remain labeled ratings rather than jobs. Provider details gallery entry opens the same modal over the sample list. Updated booking tests to View/Close then Select, retaining full direct-request continuation. 54 modal/gallery/booking tests passed; standalone full-profile visual render passed and inspected; full Customer analysis clean. Docs updated with backend profile dependency.

Booking confirmed reference UI: imported image 63.svg as assets/illustrations/booking/booking_confirmed_mascot.svg and extracted its unchanged embedded PNG for runtime. Added BookingConfirmedView using shared rounded payment page, mascot heading, booking amount with calendar/check icon artwork, selected payment method, precise RESERVED-versus-confirmed payment copy, refresh and Home actions. Only shown for backend CONFIRMED plus RESERVED/PAID/SETTLED; no payment action or fabricated auto-approval. Shared heading accepts artwork overrides and amount card accepts optional trailing artwork. 52 gallery/live booking UI tests pass, confirmed visual render passed and inspected, changed-file analysis clean. Re-run preview with -Scene confirmed after asset-bundle refresh.

Request expired reference UI: imported image 64.svg as request_expired_mascot.svg plus unchanged extracted PNG under assets/illustrations/booking. Added BookingRequestExpired selected only from server EXPIRED status. Reuses shared teal/rounded payment page, custom mascot heading, request amount with native coin-stack artwork, selected method and peach expiry notice. Only refresh/Home actions; no payment/resubmission or local expiry timer added. Amount labeled Request amount since expired requests are not payable. 52 gallery/booking widget cases pass; gallery additionally asserts expiry notice/refresh and absence of wallet pay action. Expired artwork render passed and inspected; changed-file analysis clean. New assets require preview rerun with -Scene expired.

Request cancelled reference UI: imported image 65.svg as request_cancelled_mascot.svg and extracted unchanged embedded PNG. Renamed/generalized expired presentation to booking_request_closed.dart / BookingRequestClosed, sharing amount coin artwork, selected method, refresh and Home between server EXPIRED and CANCELLED states while varying mascot, title and notice. No cancellation mutation or return-to-checkout draft flow changed. Cancelled requests have no Pay action. 52 gallery/booking regressions pass; additional cancelled-state assertions verify message and refresh-only recovery. Cancelled visual render passed/inspected and changed-file analysis clean. Re-run preview -Scene cancelled after asset refresh.

Shared amount artwork replacement: user-supplied Secure Payment Card Shield 1 (2).svg is byte-identical to the existing secure_payment_card.svg (hash checked). Reused secure_payment_card.png rather than duplicating files. Confirm payment now uses the gradient plus separate card/shield asset; confirmed/cancelled/expired use the same asset in place of native calendar/coin artwork. Removed unused native artwork helpers. Shared card keeps art visible on normal compact phone widths and hides it only for very narrow/large-text layouts to avoid obscuring amount text. Five gallery tests and confirmed visual render pass; changed-file analysis clean.


### 2026-11-02 � Opportunities and booking details

- Implemented the customer Opportunities navigation destination with authenticated booking history, status filters, empty/loading/retry states, pull-to-refresh, and booking detail links. Existing My bookings/recent bookings links remain supported.
- Added shared booking detail presentation: schedule, location, submitted answers, assigned providers, payment method/status, and backend amount. Uses existing booking history API; no invented single-booking or provider-profile endpoint.
- Verified payment success displays for 3 seconds then opens the matching job details. Manual actions cancel the one-shot timer; background lifecycle pauses it. Payment failures/pending states never auto-redirect or initiate payments.
- Kept current-session provider display context and booking field labels scoped to authentication; historical provider profile enrichment still needs backend support after session restart.
- Added offline Opportunities/Booking details preview scenes. Gallery success remains frozen for UI inspection.
- Added timer/filter/details tests and updated real booking navigation regression tests. Existing unrelated work preserved.
- Validation: Flutter analysis clean; 53 booking/Opportunities/navigation tests and 5 offline preview tests passed. Automatic post-payment navigation is covered through the real booking widget flow.


### 2026-11-03 ? Full interactive booking preview

- Added `-Scene flow` / gallery Start full booking flow to mount the real CustomerApp navigation/controllers/screens with a terminal in-memory HTTP adapter. Native map/Places/GPS and secure stores are overridden with offline samples; unknown endpoints fail locally and there is no real HTTP fallback.
- Hospital Care is the open-request option; Home Care is direct-request with real provider selection/details before the form. Both flow through real review, wallet payment, success auto-navigation, booking details and Opportunities.
- Added provider acceptance/expiry, next payment success/failure/pending, pending completion, no-provider and optional requirement scenarios; sample saved-card setup, wallet top-up/history are in memory. Existing cancellation/back/edit rules are reused.
- Preserved the frozen single-screen gallery. Post-acceptance live card checkout is still not wired; an explicitly labelled offline Simulate card success action previews subsequent screens without changing production payment logic.
- Full preview overrides are stable across hot reload. Normal main.dart imports none of these debug modules.
- Validation: Flutter analysis clean; 10 full-flow/scenario/gallery tests passed, including open and direct requests through actual payment buttons, success auto-navigation, and Opportunities history.

### 2026-11-03 — Screen browser alongside full flow
- Added Screens toolbar action and Screen list control to open the existing frozen gallery over the interactive preview. Resume full flow returns to the retained session. Added navigation regression coverage; six gallery tests passed.

- Screen browser fix: ignore BTHERE_PREVIEW_SCENE when browsingFlow is true. Previously -Scene flow recursively opened another full-flow app instead of the list. Regression test now runs with the actual flow dart-define and passes.


### 2026-11-03 ? Complete booking screen inventory

- Corrected the incomplete browser: added 20 real-widget presets alongside 13 existing frozen scenes (33 total), with screen search and open/direct forms/reviews explicitly distinguished.
- Presets automatically prepare isolated offline sessions/drafts and open location/date/duration/card/cancellation dialogs directly. Original interactive flow is retained under the browser.
- Extracted unchanged checkout presentation into booking_checkout_contents.dart for reuse. Exposed existing date/custom-duration picker actions without changing validation or live flow.
- Added per-shortcut coverage for all 20 new entries and a search-to-direct-review browser regression test. Flutter analysis is clean.
- Final validation: all 79 screen-shortcut, gallery, interactive-flow and live booking widget tests passed; Flutter analysis reports no issues.

### Authentication screen browser additions (2026-11-03)

Added seven real authentication shortcuts: email/password login, registration, mobile login, email/phone OTP, and email/phone verification success. Inventory is now 40 (27 live shortcuts + 13 frozen scenes). Each auth shortcut uses an isolated signed-out memory session; normal production login defaults remain unchanged. The terminal offline adapter handles registration, resend, OTP verification and sign-in without network/SMS/email. Six-digit sample OTP: 123456. Validation: 60 auth/gallery/shortcut tests passed, followed by all 27 shortcut tests including email and phone OTP submission-to-success navigation.

### Market preference retention (2026-11-03)

Production already saves confirmed market IDs by account and API environment in
secure storage, validates them against current active markets and restores Home.
No production booking/payment changes were needed. The full offline journey now
shares its memory market preferences across journey instances in the same preview
process, including logout/login. Hot restart or app restart still clears preview
memory; production secure preferences survive restart. Screen shortcuts retain
isolated preferences, including the first-time Market selection shortcut.
Regression coverage includes repeated login, journey recreation, unavailable IDs,
account/environment isolation and shortcut isolation.
Validation: all 60 production market/discovery and preview market/full-flow/shortcut tests passed; Flutter analysis clean.
`nHome UI refinement: removed the large tinted Explore Services tile backgrounds while retaining circular service icons and tap targets. Recent Services now uses compact service-icon/name/date rows with separate booking/payment badges, subtle borders and a matching empty state. Existing details routing and booking/payment logic retained. Home/discovery/opportunities checks: 22 passed; populated and empty Home screenshots reviewed, 320px/2x-text preview passed; Flutter analysis clean. Preview tool: tool/home_preview_test.dart.
Service category accordion UI refined: white rounded category surfaces with teal expanded outline, animated chevron, backend category descriptions and divided option area. Options now show larger icons, backend descriptions and View details affordance; details sheet description typography refined. Existing access labels, retries, routes and booking logic retained. 49 discovery/shortcut/full-flow tests plus responsive service preview pass; analysis clean. Screenshot: build/home-previews/service-options.png; tool/service_options_preview_test.dart (FLUTTER_SDK define).
Footer navigation: renamed Opportunities label to Booking and added calendar/check SVG icons for inactive (white outline) and selected (teal filled) states. Existing destination route retained. Footer navigation regression checks and Flutter analysis run.
Service cards compacted per mobile feedback: reduced category padding/icon/title sizes, removed Choose your service and View details rows, option icons 34px with 10px padding, single-line description (full text in details sheet), smaller gaps/radii. Two-option category now uses substantially less height. 18 discovery/responsive preview tests passed; Flutter analysis clean.
Cancelled request UI: hides the leading radio indicator on the read-only payment method row; cancellation notice now uses app selection teal with a subtle teal border and darker readable text. Existing expired/payment screens retain their styling; cancellation behavior unchanged.
Cancelled request actions: replaced Refresh request status with Back to booking form, kept Back to Home. New controller action only accepts confirmed CANCELLED requests, clears persisted submission identity before reopening Service Details and preserves draft answers/location/time/payment choice. Gallery button opens real offline form. Expired refresh remains. Controller/full-flow regressions passed (64) and gallery regressions passed (7), including new form navigation and draft-preservation checks.
Confirm payment screen: removed leading payment-method radio indicator and removed manual Refresh request status button plus unused confirmation callback. Confirm and Pay and Back to Home remain; other request-state refresh actions unchanged.
Payment pending now reads request status automatically every 5 seconds while visible/foreground and not busy. Pauses in background, checks immediately on resume, skips covered routes and cancels timer on disposal/result transition. Existing controller drives success/failure presentation; no payment POSTs added. Manual Check payment status remains available. Frozen gallery disables polling; interactive preview uses real polling. Tests cover automatic success/failure, busy/background/resume/disposal and frozen gallery.
Payment pending UI simplified: removed Check payment status and Back to Home buttons and leading payment-method radio icon. Automatic status polling remains; unused pending onHome callback removed. Preview asserts removed controls; automatic success/failure and lifecycle polling regressions retained.
Cancellation dialog restyled with centered teal calendar icon/title, concise reassurance panel, full-width Keep request primary action and red text Cancel request secondary action. Existing true/false confirmation behavior retained. Added tool/cancel_dialog_preview_test.dart for screenshot and 320px/2x-text dismissal check; preview passed.
Confirmed booking receipt: removed leading radio and Refresh request status. Added View booking details primary action plus Back to Home. Live action uses the authoritative positive jobId and existing details routing/extras; if no valid booking ID exists only Home is offered. Frozen confirmed preview opens bookingDetails scene. Existing confirmation/payment criteria unchanged.
Expired receipt: removed payment-method radio and manual refresh, added Back to booking form using existing draft-preserving identity cleanup (now permits EXPIRED as well as CANCELLED). Expiry helper copy updated. User also requested ring again action; clarification pending whether this means sending a new provider request or phone call, so no new retry/call action is wired yet.
Clarification received: ring again means send a new provider request. Expired receipt now has Send request again primary action, outlined Back to booking form and Back to Home. Resend only accepts EXPIRED scheduled requests, clears old identity via existing return-to-form action, reuses service-detail validation and submit path, preserves draft and uses a fresh idempotency key. Existing active/uncertain request protections remain. Frozen preview simulates transition to Finding; live flow resets progress display before resend. Controller regression verifies identical payload/fresh identity and blocks resending MATCHING requests.
Booking details redesigned to match Customer UI: shared teal-header BookingDetailsPage chrome in live app and frozen preview, pale teal service/status summary, compact icon-led section headings and detail rows, consistent provider card, highlighted booking amount and View all bookings label. Backend fields/status/payment/provider fallbacks and refresh/details navigation retained. Preview tool tool/booking_details_preview_test.dart renders upper/payment sections and verifies 320px/2x-text navigation. Opportunity/gallery tests and final full-flow/visual checks passed; analysis clean.
Booking footer destination refreshed: visible title Bookings replaces Opportunities; compact rounded white cards show service name, separate booking ID, schedule, booking/payment badges and authoritative amount. Updated teal filter-chip styling and pale page background; filters, pull-to-refresh, empty/error behavior and details routes preserved. Internal route/enum kept stable. Gallery label now Bookings. 18 navigation/history/gallery/full-flow tests plus 320px/2x-text filtered-card preview pass; Flutter analysis clean. Tool: tool/booking_tab_preview_test.dart; screenshot build/home-previews/booking-tab.png.
Booking list readability refinement: pale teal card fill and stronger teal borders, larger/darker service titles, booking IDs, dates and amounts; status badges now use 12px semibold darker text (also improves Home recent badges). Five history/filter/320px 2x-text preview checks passed; analysis clean.
Customer UI integration audit completed: recent improvements are used by normal main.dart routes and shared widgets; no missing production wiring found. Full Customer suite 345/345 passed, design system 24/24 passed, analysis clean, normal main.dart debug bundle compiled and updated branding/Booking icons/artwork confirmed bundled. Fixed one stale test assertion for split service name/booking ID labels. No installed-device/live-backend run performed. Audit: docs/customer-ui-integration-check.md.
Preview removal validation: all 307 remaining/new Customer tests passed; Flutter analysis clean; normal main.dart debug asset bundle built successfully. Added four production receipt action tests to retain important UI coverage. Existing production market/pending/resend/navigation tests remain.
Map wave repeating behavior implemented: BookingLocationPicker enables repeat on editable maps; 2.8s wave plus 1.4s idle gap, with background/covered route/TickerMode/gesture pauses, reduced-motion suppression and timer disposal. Shared component keeps optional one-shot mode. Tests cover repeat timing, idle ticker stopped, gesture/lifecycle/route pause and resume, native map stability and disposal.
Missing filter-map markers diagnosed on emulator: selected Nov 4 01:30 while device time was Nov 3 23:45; backend policy requires minimum 120 minutes notice. Continue showed the authoritative validation error, so no provider search/markers were expected. Improved live availability badge to explain invalid search inputs immediately rather than silently show no count/pins; unchanged search validation and marker data. New regression covers blocked too-soon start and availability recovery after correction. Controller/native marker tests: 70 passed. No booking/payment was submitted during device diagnosis.
Preferred time validation now appears immediately beside the slider: red border/tint plus live-region inline message for past times, invalid dates or insufficient server-configured notice. Shared startTimeError logic is used by search and form validation, including minimumNoticeMinutes; corrected times clear the hint without Continue. Removed duplicate outer start-time error wrapper. Added widget regression for too-soon/past selections and correction.
Booking calendar popup restyled locally with white untinted surface, 24px rounded dialog, pale-teal header, clear date typography, rounded teal selected day/today outline and Apply date action. Uses market-local current date, preserves existing first/last date limits and date-input/year navigation. Cancel and 320px/2x-text date selection tested; original time/duration retained. Screenshot utility: tool/calendar_style_preview_test.dart; normal booking calendar regression passed; analysis clean.
Calendar compactness refinement (2026-11-04): replaced fixed-height native date-dialog shell with BookingCalendarDialog using the native compact CalendarDatePicker plus input-date mode and content-sized scrollable layout. Cancel/OK now share full available width equally with >=52px height; removed oversized empty dialog area. Month/year navigation, typed-date validation, existing date limits, market-local today and time/duration preservation retained. Added six-week-month grid/input regressions and updated widget expectations.
Service-option dropdown restyled (2026-11-04): white untinted popup, softer shadow and anchor gap, compact icon-led rows, pale teal selected row and right-aligned teal check. Clearer 13px typography and rounded row surfaces; long names wrap, menu remains height-limited/scrollable. Existing reload/options switching and draft transfer retained. Both location/time and Service Details dropdown routing regressions passed; analysis clean.
Manual booking-map selection (2026-11-04): existing customer-location marker drag support retained and made discoverable via pin info hint; native map long-press also selects a location. Wave pauses during marker drag; release uses existing onChanged/reverse-geocoding path, updating booking point, radius circle and provider-search fingerprint. Provider markers and read-only maps remain immovable. Added drag regression covering point/circle/address/wave and provider immutability. Fourteen native-map/ripple tests passed; analysis clean.
Unaccepted request recovery fixed (2026-11-04): documented UNMATCHED status previously fell through to generic receipt. It now shows No provider accepted with Send request again, Change filters and Back to Home. UNMATCHED joins closed-draft cleanup/retry guards; filters action retains booking answers, schedule, location, method/preferences/pricing choices and rechecks availability. New retry identity/payload and filter draft retention tests pass; normal booking-screen test confirms all three actions and restored filters. Prior expired/cancelled behavior retained.
Cancellation navigation corrected (2026-11-04): live request-progress cancellation no longer passes returnToCheckout:true. Server-confirmed CANCELLED request remains in created stage and renders the existing Request cancelled receipt; Back to booking form and Back to Home are available. Draft answers/payment choice are retained, and form action clears old creation identity via existing controller. Updated integration regression exercises Keep request, one cancel POST, cancelled receipt and return to form with preserved data.
Provider acceptance helper added (2026-11-04): scripts/accept-provider-request.ps1 invokes stdlib-only Python helper against existing customer.local.json API environment. Credentials are prompted locally with hidden password and never persisted; requires SERVICE_PROVIDER role. Polls only this provider offers for the specified request, enforces PENDING/unexpired state, revalidates after exact ACCEPT <requestId> confirmation and sends one normal provider accept POST. Rejects redirects; uncertain acceptance is never auto-retried. No customer payment is performed. Nine offline helper tests passed; PS wrapper syntax checked. Interactive terminal opened for user credential entry; no provider acceptance performed by the assistant without those credentials/confirmation. Guide: docs/provider-acceptance-helper.md.
Finding-provider Request ID visibility fixed (2026-11-04): live progress screen now passes the authoritative requestId to its view and displays selectable Request #ID below Provider for you. This allows entering the correct current request into the provider acceptance helper. Previously this particular screen did not show the ID. Added assertion to normal matching/cancellation integration regression; analysis clean.
Provider helper reliability refinement (2026-11-04): separated timeout/network/TLS/DNS/invalid-JSON diagnostics and added bounded retries for read-only GET failures. Acceptance POST remains single-attempt and uncertain results are explicit. Removed redundant wrapper throw stack. Eleven helper tests passed including temporary read recovery and bounded failure. User Request 28 failed while reading offers, before acceptance; actual underlying connection/response category was hidden by old generic message.
Provider accepted button flicker fixed (2026-11-04): five-second progress polling now calls refreshCreatedRequest(background:true) without setting global busy. Dedicated in-flight read guard prevents overlapping reads; snapshot/epoch/busy checks prevent stale polling results from overwriting cancellation/payment state or new action errors. Manual refresh and actual writes keep normal loading behavior. Sixty-eight controller/pending tests plus slow-poll accepted-screen integration test passed; Continue remains enabled/spinner-free during held read; analysis clean.
One-step accepted-wallet confirmation (2026-11-04): provider accepted card now shows authoritative wallet amount/method and Confirm and Pay. Explicit click invokes existing confirmRequestWallet directly and refreshes wallet, skipping the extra wallet-confirmation page. Existing success/pending/failure UI remains controller-driven; acceptance never auto-charges. Expired wallet action disabled; CARD or missing amount retains existing continuation. Tests cover slow polling with direct payment exactly once, no intermediate page, card continuation and expiry guard, plus controller/pending regressions.

Direct payment-method recovery (2026-11-04): removed extra Change payment method confirmation dialog from payment failure. Use Different Payment Method now opens a white/teal method chooser; Card opens the existing saved-card dialog, Wallet goes directly to checkout. Original unpaid request is cancelled only after replacement selection is complete; dismissing chooser/card list keeps it unchanged. Adding a card during recovery does not mutate the active booking method/stage. Existing backend cancel-and-new-request contract and draft retained; checkout requires explicit submission/payment. New widget regressions cover chooser/card dismissal, selected saved card, preserved answers, and failed-card-to-wallet checkout without automatic payment. All 121 booking controller/widget/pending-polling regressions passed; Flutter analysis clean.

Wallet reselection correction (2026-11-04): current Wallet row in payment recovery chooser is now selectable. Reselecting the same wallet dismisses failure presentation and returns to accepted-provider Confirm and Pay on the existing request, without cancellation or automatic payment. Different-method recovery remains unchanged. Added regression verifies selectable wallet, enabled explicit payment button, original request retention and no extra confirm/cancel POST. Flutter analysis clean.

Inline replacement-method retry (2026-11-04, latest user preference supersedes wallet reselection above): Use Different Payment Method disables the original request method for both Card and Wallet. Card opens the existing saved-card list with Add New Card in place; selecting a replacement now keeps the payment failure screen visible and displays its method/card label. Selection alone neither cancels nor charges. Try Again cancels the unpaid request through the existing guarded controller, applies the replacement to the retained draft and submits a fresh request directly into provider finding, skipping the original checkout page. Cancellation failure keeps the old request; uncertain submission keeps the existing reconciliation behavior. Tests cover disabled methods, chooser/card dismissal, in-place Add Card access, selected-card display, draft retention and direct matching on retry. All 122 booking widget/controller/pending regressions passed; Flutter analysis clean.

Card setup navigation isolation (2026-11-04): user still saw checkout after recovery selection on their running app. Removed booking method/review mutations entirely from _bookingCard, including its applySelection switch: setup now only links and refreshes saved cards; selection callers own journey transitions. Strengthened recovery regression from opening/closing Add Card to a successful mock-card setup, selection, hot reload, retained failed-payment screen/selected-card display and explicit Try Again into matching. Added fixture support for successful setup. All 54 booking widget tests passed, including normal checkout; Flutter analysis clean. Running emulator needs latest code via Flutter reload/restart; no live emulator update was performed in this turn.

Accepted Card payment connected (2026-11-04): countdown now shows Card amount/method and Confirm and Pay, directly invoking documented POST /booking-requests/{id}/confirm and hosted PayHere checkout rather than the extra confirmation page. Added guarded confirmRequestCard controller/repository path using real profile billing details and email/phone; missing contact is collected only when necessary, unknown brand prompts Visa/Mastercard. Rechecks identity/deadline, prevents overlapping confirmation, validates signed checkout destination and matching amount/currency, form-POSTs all server fields. New official webview_flutter dependency opens HTTPS checkout, polls owned request while foreground, refreshes on resume/return, and never treats redirects as success. Uncertain responses enter pending recovery without automatic write retry. Card retry uses this same flow; fallback receipt also has a working Card action. Auth tokens and card credentials are never sent to the app confirmation API or logged. Existing mock saved-card records select brand, not live reusable card tokens. All 139 booking/payment regressions passed; final 12 checkout tests passed; analysis clean; Android debug build passed. Live PayHere payment and iOS device flow not exercised. New native plugin requires stop/run, not just hot restart. Details: docs/customer-card-checkout.md.

Contact continuation diagnostics (2026-11-04): user reports phone entry/Continue returns to accepted screen with no visible result. Live emulator read-only inspection showed Request 41 already EXPIRED, so original backend rejection could not be recovered; public OpenAPI returned 401. Confirmed UI issue: successful 5-second status reads cleared action errors and the accepted error text was below the card. Background polls now retain action errors; accepted card renders a live-region notice immediately above Confirm and Pay; null checkout and presenter exceptions show visible feedback. Pending automatic reads remain background/silent and can reconcile an uncertain card write. Added privacy-safe phase/status/type diagnostics without billing/card fields. New widget cases exercise the actual missing-phone dialog followed by hosted checkout, and HTTP 400 rejection persisting through subsequent status polls. All 136 booking/controller/checkout/pending regressions passed; Flutter analysis clean. Original live checkout failure cause remains unconfirmed until a fresh attempt yields its now-visible error. Building/installing latest APK on emulator with adb install -r to retain data; no booking or payment submitted by assistant.
Contact diagnostics deployment: Android debug build passed; adb install -r succeeded on emulator-5554 and MainActivity launched. Existing app data retained. A fresh user/provider test is needed for the real confirmation API error.

Failure-screen replacement-card presentation (2026-11-04): replaced the plain concatenated method/card text box with shared PaymentSelectedMethod used by other payment screens. Separate Selected payment method heading, teal icon tile, clear method title, masked last-four subtitle and small retry explanation outside the card. Added optional subtitle to the shared widget without changing existing callers; selected metadata now passed as method/card-label separately. Card summary displays only validated/extracted last four and test-card label. Inline card/wallet selection and Try Again flow unchanged. Both affected recovery integration tests pass; Flutter analysis clean; diff whitespace check clean. This UI-only change has not been installed on the live emulator, to avoid interrupting its current request.

Visa branding colour (2026-11-04): Wallet payment-method list and Add Money saved-card row now tint the Visa SVG blue (#1434CB), matching Add Card and saved-card dialog branding. Mastercard retains its original multi-colour SVG. Presentation-only change; no payment logic altered.

Provider helper intermittent TLS EOF (2026-11-04): user Request 44 stopped on offers GET with generic TLS/certificate message. Three unauthenticated verified HTTPS probes reproduced two expected 401 responses and one SSLEOFError/UNEXPECTED_EOF_WHILE_READING, identifying an intermittent TLS transport interruption rather than proving a certificate-validation problem. Helper now retries transient TLS EOF/clean-close GET failures within existing three-read limit and distinguishes true certificate validation failures (fail fast). Verification remains enabled; login and acceptance writes remain single-attempt, and uncertain accept results are never auto-retried. Added EOF recovery/bounded read/certificate failure/accept uncertainty tests; all 17 helper tests pass. No login, request creation or acceptance was performed during diagnosis.

Confirmation stays visible (2026-11-04): removed the live booking journey's success onAutoContinue callback. Confirmed/payment-success screens now remain visible until View booking/details or Home is explicitly tapped. Existing manual navigation retained. Updated integration regression waits ten seconds, verifies no automatic details route and then taps the details action to open the correct booking. Regression passes; Flutter analysis clean.

Booking tab visual refresh (2026-11-04): white compact cards with soft teal borders, smaller service icon/title/ID block, status badge at top right, separate readable schedule, muted payment status and right-aligned amount/chevron. Removed large competing status/payment pills and heavy card tint; cancelled status neutral, completed soft green, active teal. Correct wallet SVG/card/cash payment icons. Horizontal filter chips use solid teal selection and scroll at narrow widths. Narrow/large-text cards stack status and amount safely. No backend/filter-grouping/navigation/payment logic changes. Existing four booking-tab/details/result regressions plus standalone rendering/filter/320px large-text check passed; Flutter analysis clean. Screenshot inspected: apps/customer_app/build/home-previews/booking-tab.png. UI code updated; no live emulator reinstall during this turn.

Booking tab refinement and delivery (2026-11-04): user repeated old screenshot; prior UI code was never installed. Revised cards further with month/day calendar tile, tighter title/ID/schedule block, top-right status, quiet payment footer/right amount, actual total and filtered counts. Existing filter/status semantics preserved. Rendered 393x852 sample plus 320px/2x text; five UI/navigation checks passed, analysis clean. Android debug build passed, installed via adb install -r retaining app data, and MainActivity launched. Device startup then reported Unable to restore your session; tapped its Retry once to attempt signed-in read-only viewing. Live Booking tab verification depends on session restoration; no credentials, booking or payment actions were performed. Rendered artifact: apps/customer_app/build/home-previews/booking-tab.png.
Delivery verification: session Retry succeeded; opened Booking tab through its real footer and visually inspected live account bookings on the installed APK. New calendar date tiles, solid teal filter, quiet statuses and aligned payment/amount rows are present. Left emulator on Booking tab. Live screenshot: apps/customer_app/build/home-previews/booking-installed.png.

Booking Details reference styling (2026-11-04): refined page to supplied screenshot style with a light-teal gradient header/static wave artwork, compact service/title/status badges, softer cancelled status, white rounded sections with clear icon headings and fine separators, larger readable detail values, and tinted provider tile. Removed repeated heavy dividers; maintained all authoritative schedule/location/provider/answer/payment data, unknown-profile fallback, links and actions. Uses shared branded wallet SVG and card/cash-specific icons. Standalone style export plus 320px/2x text and existing four detail/navigation regressions passed; Flutter analysis clean; Android debug build passed. Artifact: apps/customer_app/build/home-previews/booking-details.png. Installing latest APK on emulator with app data retained; no booking/payment mutations.
Booking Details delivery verified: adb install -r succeeded; opened real Booking 16 from the Booking tab and visually inspected the refreshed details page with its existing account data. Left emulator on Booking Details. Actual-device screenshot: apps/customer_app/build/home-previews/booking-details-installed.png.

Booking Details bottom-sheet clarification (2026-11-04): user explicitly clarified reference requires rounded white bottom sheet, not only a full-page restyle. CustomerBookingDetailsScreen now opens a draggable 80%-height sheet automatically after loading the owned booking, over a compact summary background. White rounded top, handle, fixed close X, scrollable live details, resize up to 95%, close/reopen action. Existing details content and provider dialogs reused; View all bookings first closes the modal, then navigates. Sheet content watches account-scoped history and hides data if signed-in identity changes. Pull refresh/retry retained inside sheet. Integration regression verifies manual success/details navigation, automatic sheet, close/reopen, 320px/2x text scrolling and View all bookings. All 60 booking UI/details regressions pass; analysis clean; Android debug build passed. Latest APK being installed with data retained; no booking/payment writes.
Bottom-sheet delivery verified: install -r succeeded, opened real Booking 16 from footer Booking list, and visually confirmed auto-opening white rounded draggable sheet with drag handle/close X over dimmed summary. Emulator left on the requested sheet. Actual screenshot: apps/customer_app/build/home-previews/booking-details-sheet.png.

Latest Booking Details navigation preference (2026-11-04, supersedes bottom-sheet request above): user now explicitly wants Booking tab card click to open the Details page directly. Removed modal launcher, background summary/reopen action and summary-only branch. Retained refreshed full-page header/sections/provider/payment UI, account-scoped data, refresh and normal back/all-bookings navigation. Android debug build passed and latest APK installed with data retained. Integration test covers no auto navigation from success, explicit details action, large-text full-page scrolling, all-bookings return and tapping a Booking tab card with no BottomSheet. Flutter analysis clean.

Booking Details reference fidelity correction (2026-11-04): screenshot comparison confirmed terminal runs the current code; discrepancy was the visual design, not a stale build. User says supplied reference differs from the previous simplified design. Kept latest explicit direct-page navigation, and matched the reference's stronger teal section borders, inner booking-information panel, fine row dividers, 38px teal icon tiles, larger section/value typography, rounded red cancelled and amber pending-payment pills with card icon. Existing data/payment/navigation logic retained. Five style/details/navigation checks passed including 320px/2x text; final style recheck passed, analysis clean. Building/installing latest corrected style to emulator with data retained. Rendered artifact: apps/customer_app/build/home-previews/booking-details.png.
Reference fidelity delivery verified: Android debug build passed; install -r succeeded; opened real Booking 16 and inspected the installed full page. Red cancelled/amber payment pills, larger icon tiles/fonts and reference-style nested teal booking-information border are present. Direct page navigation retained, emulator left on Details. Actual screenshot: apps/customer_app/build/home-previews/booking-details-reference-installed.png.

Booking tab colour pass (2026-11-04): user requests more colour matching Details. Added subtle pale-teal gradient card surfaces and stronger teal borders/calendar tiles, teal confirmed/green completed/rose closed status pills, payment-state text/icon colours (amber pending, rose failed, green funded) and white amount highlight with teal typography. Kept compact responsive layout, actual statuses, filters and direct-details navigation unchanged. Rendered/inspected standalone screenshot; all five related UI/navigation/layout checks pass, analysis clean. Building/installing latest APK on emulator with account data preserved. Artifact: apps/customer_app/build/home-previews/booking-tab.png.
Booking tab colour delivery: Android debug build passed; adb install -r succeeded on emulator-5554 and customer app relaunched, retaining account data.

Services tab reference refresh (2026-11-04): white page body, clearer category heading and soft-teal search with clear action, rounded teal-outlined category cards with larger title/icons, pale-teal expanded surface and a single compact white option panel separated by fine dividers. Hospital/Home/Ride fallback icons distinguish options while server icons/data remain authoritative. Category descriptions show two lines (unrestricted at large text); search keyboard dismisses when choosing a category/option. Existing eligibility/reasons/loading/retry, lazy option loading, search and booking route unchanged. Added standalone render/search/clear/narrow-large-text/modal check; all 18 discovery/layout regressions passed and Flutter analysis clean. Rendered artifact: apps/customer_app/build/home-previews/services-tab.png. Building/installing latest APK with account data preserved.
Services UI delivery: Android debug build passed, adb install -r succeeded on emulator-5554 and the customer app relaunched with existing account data retained.

Customer typography consistency (2026-11-05): migrated custom presentation text styles across Home, market/catalog, booking form/review/provider screens, request receipts, payment results, Wallet and payment dialogs to app-local CustomerTypography roles. Screen 24/700, section 18/600, card/button 14/600, body 14/400, compact 12/500 (12/600 emphasis), micro 10/500. Countdown remains a deliberate 38/700 tabular display role. Removed unsupported w800 usage, adaptive footer font shrinking and duplicate Public Sans registrations; auth action line heights and verification-success body now follow theme. Removed obsolete estimate amount-size override. Provider theme unchanged. Customer suite 339 passed; three standalone Services/Booking/detail rendering checks passed including narrow/large text; payment typography regression covers 320px at 1x/2x. Customer/shared Flutter analysis clean and diff whitespace check passed. Rendered Services and Booking Details inspected. No live emulator install or payment/backend write performed. Changes remain uncommitted in the original workspace.

Offline Customer UI browser (2026-11-05): added debug-only lib/main_ui_preview.dart, isolated ProviderContainer/in-memory HTTP+session+market+top-up storage and sample location/map overrides. Searchable gallery has 47 shortcuts for typography changes and post-provider-acceptance states/dialogs. Real app widgets/controllers reused; matching acceptance toolbar and explicit offline hosted-card outcome simulator exercise local confirmation/recovery. No production entry-point wiring, live API or real payment writes. Run scripts/run-customer-ui-preview.ps1 -DeviceId emulator-5554; optional -Scene accepted-wallet/failure-card/flow. Tests: all 47 scenes render at mobile size, local Wallet confirms, Card simulator confirms and failed Card switches to Wallet/retries in place (50 tests pass). Customer/shared analysis clean, PowerShell script parse and diff whitespace checks clean. Debug preview APK build passed. Emulator was disconnected, so no install/launch performed. Uses existing Customer app ID; switching binaries requires stop/run; real secure account storage is untouched. Usage/limits in docs/customer-ui-preview.md. Existing uncommitted typography work preserved.
Preview final regression: added offline hosted-card decline coverage; decline remains eligible for in-place alternative-method selection. All 51 preview tests pass.

Preview scope correction (2026-11-07): user wants typography-changed UI only. Gallery reduced from 47 to 32 distinct changed layouts; removed full journey, Profile, OTP, billing and duplicate Card/Wallet/busy/error variants from list. Shared payment/status typography remains represented once. Documentation updated.

Customer offline preview removed (2026-11-07): user requested removal after typography review. Deleted the alternate entry point, four debug gallery/backend/sample files, preview-only test, runner script and usage document. Production typography fixes, normal entry point, normal runner and production regression tests retained. Earlier preview handoff entries are historical and superseded by this removal.

Accepted request payment recovery (2026-11-07): implemented supplied full API doc's newer payment-window contract. New account/API-scoped secure request/method/event-cursor registry recovers through own booking-events; Home Recent, Booking tab and job details show actionable payment request cards. Accepted request routes into a dedicated read/refetch/action controller, retains provider/job/request on failure and retries the same Wallet/Card confirmation before backend deadline. Server canPay/canCancel flags rechecked, final-30s warning retained, provider extensions update via silent foreground reads/resume; pending/reconciliation/uncertain writes block pay/cancel. Unknown write marker survives restart and stale pre-retry FAILED state cannot unlock another charge. Hosted signed checkout/WebView reused with required contacts and price validation; MOCK uses explicit saved methodId via confirm-mock-card. No accepted method-type switching endpoint is documented, so old cancel-and-rematch replacement UI is bypassed for accepted requests. Existing accepted-provider visual retained and confirmation requires explicit details/Home navigation. Full Customer suite 355 passed; after final retry/concurrency refinements 79 focused UI/controller tests passed, including 14 new payment controller tests and 4 Home/Booking/detail/extension UI tests. Customer/shared analysis clean, Android debug build passed, whitespace clean. No live payment, booking, device install or backend deployment verification performed. New payment-window endpoint must be deployed; unavailable/malformed endpoints safely disable payment with retry-status UI. Docs: docs/customer-payment-recovery.md. All pre-existing uncommitted typography/30-second warning changes preserved.

Provider helper saved login (2026-11-07): added opt-in -SaveCredentials to PowerShell runner (Python --save-credentials), auto-reuse on subsequent runs, and -ForgetCredentials deletion without accepting. Successful SERVICE_PROVIDER login required before save. Internal PowerShell PSCredential CLIXML uses current-user Windows DPAPI for password, API-scoped SHA256 filenames under LOCALAPPDATA/BThere/ProviderAcceptance; username/API scope remain metadata. Credentials cross child boundary only in private pipes, never argv/env/logs. No plaintext fallback, existing exact-request accept-on-arrival/revalidation and TLS/write retry rules unchanged. 23 Python tests pass including real Windows DPAPI synthetic save/read/forget, API isolation and Unicode password; no real credentials saved or API login/acceptance performed. Docs: docs/provider-acceptance-credentials.md.

Provider helper post-login 401 recovery (2026-11-07): user saved login successfully but offers read rejected while waiting for Request 54. Output proves initial login passed; exact backend rejection cause unverified. Moved request-ID input before login and added one in-memory refresh-token rotation only for authenticated GET 401, followed by reread; repeated rejection stops. Login/refresh/accept POST remain single-attempt, role revalidated after refresh and error messages now include safe method/path. Saved credentials remain valid independently of session expiry. All 27 helper tests pass including renew-on-read, repeated-401 bound, no acceptance retry and role isolation. No real credential read, API login or offer acceptance performed.

Provider helper waiting investigation (2026-11-07): user reports later requests stay waiting, current request61. Authorized saved-provider login and read-only offers/events/profile/service-types/payment-window checks performed; no accept/cancel/payment writes. API returned empty offer feed, zero own events, request61 provider payment-window404; provider profile ACTIVE/AVAILABLE (verification NOT_SUBMITTED), assignment32 ACTIVE. Thus no live offer for61 was available to this provider during observation; exact non-matching/expiry/capacity cause cannot be established from provider-only API. Asked user for Customer61 status and booked date/time; answer pending. Added wait_for_offer heartbeat every15s distinguishes missing target vs returned-but-not-live offer; timeout explains backend assignment requirement. ExactID and expired-offer safeguards unchanged; all30 helper tests pass. No automated acceptance or booking mutation performed.

Payment failure UI and Booking tab correction (2026-11-07): user screenshots show insufficient Wallet balance remaining inline in accepted-provider card and unwanted payment banner outside booking list. Definite payment-action failures now set a separate failure reason (including Wallet409/NOT_STARTED) and route into existing branded BookingPaymentResultScreen failure art/layout. Added backward-compatible same-request failure mode with selected payment card, server countdown, 30-second warning and Retry payment; hides old rematch copy/method-switch UI. Same provider/job/request preserved, no automatic write retry. Pending/uncertain remain read-only; status read errors alone do not claim payment failure. Removed standalone CustomerPaymentRequests banner from Booking tab; payment action remains inside selected booking details and Home Recent remains unchanged. Updated accepted rejection/pending and details-navigation regressions; new mobile 320px/2x-text insufficiency->failure->same-ID-success test verifies deadline and no cancel/rematch. All358 Customer tests pass, Customer/shared analysis clean, whitespace check clean. No device install, booking/payment writes or backend mutations during this turn. User should hot restart Customer (R) to manually verify latest UI. See docs/customer-payment-recovery.md.

Payment retry contract update (2026-11-08): frontend now consumes optional paymentRetryStartedAt from payment-window, validates its timestamp and restores the failure UI for Wallet NOT_STARTED after navigation/restart. Backend-supplied confirmationExpiresAt remains the only countdown source: initial120s and one-time failure+15min capped at service start are server rules, never client timers/extensions. Refresh after rejected payment already reloads the changed deadline. Repeated failures preserve server deadline; pending/reconciliation guards unchanged. Updated recovery documentation supersedes old single-window rule. All360 Customer tests passed, additional6 payment UI tests passed, Flutter analysis clean and diff whitespace clean. No backend migration/deploy, real payment or device install performed; backend persistence/deployment remains separately required. Existing uncommitted work preserved.

Booking details payment retry (2026-11-09): recovery tiles recognize paymentRetryStartedAt as a failure even for Wallet NOT_STARTED, show Retry payment and backend time remaining. Added foreground-only one-second presentation timer, retaining five-second API polls and disposal. Expanded details navigation regression verifies no outer Booking banner, failure/time inside owned job details, and successful explicit same-ID Wallet retry. All21 focused controller/widget tests pass; Flutter analysis clean. Card/Wallet switching remains pending backend endpoint: supplied contract requires cancel/rematch, so no fabricated switch or automatic cancellation added. Asked user for updated endpoint/doc. All other changes preserved.

Accepted request method switching (2026-11-09): integrated user-supplied POST /customers/me/booking-requests/{id}/payment-method with paymentMethod CARD/WALLET and updated View response. Failure UI now offers in-place alternative method picker with current method disabled, no cancellation/rematching or automatic confirmation. Mock Card opens existing saved-card/Add Card dialog, displays selected card and reuses its methodId on explicit Retry. Hosted PayHere keeps existing secure checkout flow. Controller refreshes server flags/deadline before switching; pending/funded/closed/expired blocked, backend service-method restrictions displayed, updated method stored in account/API scope. Durable method-change uncertainty marker prevents charging with guessed old method after unknown switch or restart until authoritative View resolves it. Same provider/job/request retained. All364 Customer tests pass, Flutter analysis clean, whitespace clean. No live API/payment/device install or backend deployment verification performed. Docs/customer-payment-recovery.md updated; supersedes previous no-switch-endpoint limitation.

Unmatched resend payment flash (2026-11-09): resendExpiredRequest internally restores draft then enters review before submit, briefly rendering checkout while awaiting API. Added guarded resendingRequest presentation flag with finally cleanup and duplicate resend guard. Live screen renders finding view throughout this transition, retaining existing method/draft and original submission behavior; no payment confirmation performed. Slow-response widget regression verifies no checkout flash and matching screen after success. All121 booking controller/widget tests pass, Flutter analysis clean and diff whitespace clean. Existing changes preserved; no live request/payment/device mutation.

Payment failure polling stability (2026-11-09): background refresh previously replaced View and cleared action window before awaiting payment-window; Wallet NOT_STARTED View may omit retry metadata, allowing the one-second timer to temporarily select accepted-provider UI and lose scroll. Preserve authoritative retry-start metadata and last window while the next read is in flight; completed/error reads still update/invalidate actions and payments continue to wait for fresh reads. Slow-poll widget regression verifies same failure element, scroll offset and enabled Retry, with retry timestamp supplied only by window. All25 payment controller/widget tests pass, Flutter analysis clean, diff whitespace clean. No live payment/device operations. Existing uncommitted changes preserved.

Retry payment method sheet styling (2026-11-09): replaced plain accepted-request method ListTiles with BookingPaymentMethodSheet: white rounded scrollable sheet, left-aligned title/close action, concise same-provider copy, compact bordered method cards, teal current-method background/check/subtitle without faded text, and existing wallet_selected.svg branding. Current method remains disabled, alternative routes and explicit retry unchanged. Existing7 payment UI tests pass; Flutter analysis and diff whitespace clean. No live payment/device operations.

Compact payment picker reference (2026-11-09): latest user reference supersedes larger icon-card chooser. Retry method sheet now uses the checkout's compact RadioListTile pattern: CARD first, WALLET second, left radio, small title/subtitle, right Mastercard/blue Visa or branded wallet SVG. Removed bulky leading icon blocks, chevrons, explanatory paragraph/footer; retained white rounded sheet/title/close, current method disabled and same-request selection logic. Existing7 payment UI tests pass with radio selector expectations; Flutter analysis and diff whitespace clean. No live API/device changes.

Selected retry method summary styling (2026-11-09): failure screen selected-method summary now opts into compact PaymentSelectedMethod presentation matching checkout/chooser density: mint selected row, small confirmation check, compact title/masked card subtitle and trailing Mastercard/blue Visa or branded wallet SVG. Removes oversized leading icon tile from this summary. Existing other receipt presentations retain defaults; selection/payment behavior unchanged. All13 payment UI/receipt tests pass; Flutter analysis and whitespace clean. No device/live payment actions.

Booking details missing retry recovery (2026-11-09): user screenshot shows outer recovery error despite AWAITING_PAYMENT job. Identified local ref/cursor read/write exceptions could abort all server recovery. Recovery now independently tolerates local storage errors, retains session IDs, replays events from0 when refs unreadable/corrupt, and never advances cursor unless references persist. Own API View/window remains authoritative; no guessed request IDs/deadlines or payment writes. Details passes booking requestId when provided as direct recovery hint. Existing details countdown/action navigation retained. All27 focused recovery/controller/UI tests pass including unavailable storage and corrupt refs with advanced cursor; Flutter analysis clean before final small replay guard and whitespace clean. Actual device storage failure cause not confirmed; no live API/device operations. Previous uncommitted changes preserved.

Filter-to-pricing selection defaults (2026-11-09): Ride screenshot shows Vehicle type selected for matching but blank pricing dropdown. _resetSearch now seeds pricingSelections for pricingFieldIds with exactly one valid String provider-filter choice, matched strictly by backend fieldId/value, no service/label hardcoding. Rechecking context and changing filters resets stale pricing then reapplies valid singleton; multi-choice remains explicitly unselected. Added controller regression exercises CAR auto-fill/estimate payload, VAN replacement and multi-choice clearing. All66 booking controller tests pass; full Customer run passed367 other cases with only the new fixture failing for omitted matching preferences, then corrected fixture and reran controller suite successfully. Flutter analysis clean; whitespace clean. No live API/device changes; all prior uncommitted work preserved.

Ride-specific details and directions (2026-11-09): ROUTE_BASED services now show editable pickup/destination trip summary, compact dynamic pricing/vehicle choices, retained schema questions/schedule and pinned fare/Continue footer. Initial draggable sheet caps at60percent to keep map visible. BookingLocationPicker accepts destination, distinct destination marker, Google Routes overview geometry with white outline/teal road polyline, endpoint/full-geometry camera fitting, loading/unavailable map status; no invented straight road. Endpoint-keyed autoDispose provider closes HTTP client and ignores superseded endpoint results, no availability/timer geometry re-fetch. Optional BTHERE_GOOGLE_ROUTES_API_KEY falls back to existing Maps key; configured key checked via single read-only Routes HTTP200, no booking/payment mutation. All371 Customer tests pass, Flutter analysis clean; includes3 new Ride layout/map/decoder regressions. Native emulator visual verification not performed. Docs/customer-ride-ui.md describes config/limitations. Existing uncommitted changes preserved.

Map-focused staged Ride booking (2026-11-09): latest HelaGo references applied as interaction inspiration using BThere styling. ROUTE_BASED now groups presentation into route pickup/destination -> vehicle/pickup time/preferences -> schema-driven passenger details; existing backend booking stages, validation and payment flow retained. Route location advance validates both points/addresses; Back traverses local route steps and preserves draft. Horizontal compact pricing-filter vehicle cards, collapsed editable route recap on passenger screen, existing pinned fare/footer. Route sheet initial cap36percent and later/review48percent (draggable expansion/keyboard handling retained), no review auto-expansion for Ride. Existing map road highlight/destination markers remain. All371 Customer tests pass, Flutter analysis and whitespace clean. Updated Ride regression verifies field isolation, sheet size caps and Back preserving vehicle/answers/destination. No live booking/payment/device operations; native emulator visual inspection not performed. Docs/customer-ride-ui.md updated; prior uncommitted changes preserved.

Ride pickup extra pins (2026-11-10): user screenshot shows red and cyan pins near pickup. Code renders pickup cyan plus provider candidates using default red fallback when no custom artwork. Choose-your-route phase now passes no provider candidates to map, retaining pickup/destination/road geometry. Later vehicle/passenger steps keep candidate markers and stored availability unchanged. Ride regression verifies provider pins present later, hidden on route-edit Back despite available candidates, endpoints retained. All3 Ride tests pass; Flutter analysis clean if final log reports no issues. No live device/API/payment mutations; existing changes preserved.

Ride endpoint visibility on map resize (2026-11-10): route camera now refits full road geometry/pickup/destination after visible map height/top inset or MediaQuery viewport changes, debounced180ms after dragging settles. Added top inset to CustomerMapState/GoogleMap, clamped for small visible maps, keeping trip endpoints below service selector/availability badge; normal non-route camera behavior unchanged. Fit padding32 leaves both endpoints inside available area. Idle polls do not recenter or refetch route. New fake native-camera regression verifies multiple quick resizes produce one full-bounds fit, includes curved route extent, overlay inset applied and only one geometry request. All18 Ride/map regressions pass; Flutter analysis and whitespace clean. Docs/customer-ride-ui.md updated; no live device/API/booking/payment mutations; existing uncommitted work preserved.

Ride stop card distinction (2026-11-10): replaced combined mint trip block with two separate compact white bordered cards. Pickup teal/ring icon, destination warm orange/flag icon matching map distinction, faint downward connector, larger readable compact labels, clear address hierarchy/chevron and location-specific empty prompts. Both full rows remain tappable; 64px minimum grows with text and two-line addresses. Existing trip-summary key and location callbacks retained, no business/data changes. All4 Ride tests pass; Flutter analysis and whitespace clean. No live device/API changes; previous changes preserved.

Post-payment booking work step1 only (2026-11-10): user explicitly requests implement/test/manual-review one feature at a time; do not start service progress/completion/tracking/push until manual START-code review is done. Added CustomerBookingStartController + CustomerBookingStartCode in live Booking Details below hero: funded CONFIRMED CARD/PAID or WALLET/RESERVED jobs offer Show start code. Reads owned history before customer verification-codes GET, strict START/4-digit String/UTC-expiry validation, preserves leading zeros, no secret persistence/logging/clipboard. Backend enforces service window; 404/409/malformed/error feedback, no invented code or locked flag. Hide/background/logout and late response revision guard remove code; foreground five-second revealed-code status reads hide on provider start and invalidate job history. No provider start/completion/payment write. Fixed existing details badge overflow with Flexible for narrow large text. All388 Customer tests pass including16 new START code controller/widget cases (expiry, invalid legacy length/numeric/characters, error states, duplicate taps, ownership/logout/late-hide, actual Booking tab routing, background and 320px/2x text). Flutter analysis and whitespace clean. Docs/customer-booking-start-code.md has manual checklist. No live booking/code/provider/payment/device actions performed; user must hot restart and test confirmed booking within server window (starts30min before scheduled time). All pre-existing work preserved; no commits/push.

Post-payment step2 service progress (2026-11-10): user manually saw START-code card and authorized next individual step. Added read-only CustomerBookingProgressController/card with confirmed -> in-progress -> awaiting completion confirmation -> completed timeline. Own job history polls5s only for active foreground/current details route, skips overlapping reads, refreshes on resume, stops terminal; errors retain last status with retry and no global loading/scroll reset. Details screen now keeps verified per-account/job snapshots for immediate header/START-code updates while history revalidates; cached refresh errors retain existing content. Start-code widget no longer duplicates history polling, still handles reveal/expiry/background privacy. All394 Customer tests pass; Flutter analysis and whitespace clean. New6 progress tests cover server-only transitions, no writes, terminal stop, unchanged-read no notify, missing-job recovery, overlap/logout, real details updates/code hiding and background/covered polling. Docs/customer-booking-progress.md manual checklist; step1 doc updated. No live service start/completion/payment/device actions. STOP for user manual review now; customer confirm-completion action, tracking and push are subsequent steps, not implemented in this turn. All existing uncommitted changes preserved.

Post-payment step3 customer completion (2026-11-10): user authorized continuing remaining customer features while waiting for minimum-notice manual test. Implemented only next completion-confirmation step. Booking Details offers explicit confirmation only for owned AWAITING_COMPLETION_CONFIRMATION funded jobs; scrollable white dialog explains existing-funds settlement and no additional payment. Not yet sends no POST. Confirm rereads own job, guards duplicate actions, posts confirm-completion once with no body, reconciles unknown outcomes via GET only and does not roll acknowledged COMPLETED back on stale history. Payment summary remains server-authoritative; history/wallet refresh on completion. Identity/lifecycle read guards retained. All405 Customer tests pass including11 new completion controller/widget tests; Flutter analysis clean and git diff --check clean. Docs/customer-booking-completion.md manual checklist, progress doc updated. No live settlement/provider/device actions. STOP for manual review; tracking/push remain subsequent work. All existing uncommitted changes preserved; no commit/push.

Post-payment step4 provider feedback (2026-11-10): user authorized remaining work under the existing one-feature/manual-review cadence. Implemented only completed-booking Rate your provider in real Booking Details immediately below progress. GET owned booking ratings supplies names/provider IDs/canRate/saved feedback; explicit 1-5 stars and optional1000-character comment, no default rating or automatic write. POST includes providerId for team correctness; repeated taps blocked, acknowledged feedback retained across stale same-screen reads, unknown/duplicate outcomes reconcile GET-only with submission blocked if reconciliation fails. Account identity guards discard late results. Saved stars/comment remain visible; no edit/delete UI. Repository validates own job/rating provider response and star/comment inputs. All410 Customer regression tests pass, focused5 rating tests pass after final reconciliation cleanup, Flutter analysis clean and whitespace clean. Docs/customer-booking-ratings.md manual checklist. No live ratings/booking/payment/device actions, no commit/push, all earlier uncommitted changes preserved. STOP for manual feedback. Public reviews/option-specific search rating summaries, tracking and push remain subsequent steps. Supplied ratings doc labels backend locally implemented/not deployed; no live deployment claim.

Post-payment step5 option-specific search ratings (2026-11-10): user requests remaining documented features step-by-step while waiting for newer API docs. Implemented this individual display step only. Candidate optional optionAverageRating/optionTotalRatings validated and exposed as searchRating/searchRatingCount; presence of either option field prevents borrowing overall feedback for an unrated option. Search cards receive selected service name and label For [service]; null/zero count displays Not yet rated. Older responses with neither option field display existing overall score/count explicitly labelled Overall rating. Overall fields remain unchanged for existing accepted/profile/tracking consumers. No new API calls/ranking/filtering/selection/payment changes. Five new tests validate distinct scope values, explicit unrated data, legacy fields, malformed payloads and narrow large typography. All415 Customer tests pass; Flutter analysis clean and git diff --check clean. Docs/customer-booking-ratings.md updated with manual checklist. No live device/API/payment/rating writes, no commit/push, earlier uncommitted changes preserved. STOP for user manual review; provider public reviews/distribution, live tracking and push remain next separate steps.

Post-payment step6 provider summary/reviews (2026-11-10): user authorized next individual feature. Real search-provider details and remembered Booking Details provider dialogs now include CustomerProviderReviews. Read-only GET provider ratings yields overall and named per-option summaries; selected option starts active, chips switch All services/option. Server score/count/distribution, optional review comment, shortened customer name and supplied date component displayed; no timezone conversion guess. Reviews GET page0 size10 with optional optionId, explicit Load more, ID dedup, same-page retry retaining prior content. Scope revision ignores late responses; duplicate reads guarded; logout/dispose discards data. Summary/review failures independent with retries, profile remains usable; no polling or writes. Optional feedback slot preserves plain profile consumers/tests. New typed parsers/repository routes plus6 controller/parser and3 dialog tests; all424 Customer tests pass, Flutter analysis clean, git diff --check clean. Docs/customer-provider-reviews.md manual checklist; ratings doc updated. No real API/device/rating/booking/payment mutation; all prior uncommitted changes preserved and no commit/push. STOP for manual review; tracking/push remain subsequent. API doc still says backend ratings locally implemented/not deployed, no deployment verification performed.

Post-payment step7 tracking status (2026-11-10): user authorized next tracking step under one-feature/manual-review cadence. Implemented read-only CustomerTrackingStatus card below progress for confirmed/in-progress PROVIDER_TO_CUSTOMER owned jobs; authenticated tracking GET is authoritative support check because historical jobs lack retained liveTrackingSupported context. Strict known status/matching job/positive poll interval validation. Scheduled, On the way, Arrived, In trip, Ended and pending-confirmation messages; team label explicitly explains most-advanced-stage aggregation. NOT_SUPPORTED hides/stops reads, ENDED and non-FULL_TRIP ARRIVED stop polling. One-shot backend interval scheduling, overlap guard, unchanged-response no redraw, foreground/current-route network reads only, app resume refresh, disposal/logout guards. Errors retain last status with explicit retry;404 stops auto reads. No journey actions/payment/booking writes. All432 Customer tests pass including8 new controller/parser/real Booking Details tests; Flutter analysis clean and whitespace clean. Docs/customer-tracking-status.md manual checklist. No real device/API/journey mutations, no commit/push; existing uncommitted changes preserved. STOP for manual review; next is live map/GPS/ETA/vehicle UI, then push. Supplied tracking doc still marks backend not deployed; no live deployment claim.

Remaining customer tracking/notifications implementation (2026-11-10): user explicitly changed cadence to finish remaining customer code now and manual-test last; this overrides earlier per-step STOP/manual-review instructions. Extended owned tracking response with typed providers/target/UTC locations/stale threshold/public metadata and signature-based updates. Live Booking Details map on en-route/full-trip states uses backend artwork/headings, stable provider IDs and orange target, fits all real points, stops camera following on user touch and offers Show all locations. Coordinate-only camera updates, no fake road line/default provider positions, no customer GPS permission. Provider profiles/vehicle metadata/public reviews from owned response; approximate direct-distance ETA suppressed on stale/missing/read-failed data; retained pins and scheduled staleness expiry. Existing lifecycle/route/identity polling guards preserved. Added Firebase official plugins (core5.1.0/messaging17.0.1) via injectable gateway, optional native config, Android notification permission/conditional Google Services4.5.0 plugin, iOS remote-notification mode. Home bell notification settings, explicit permission prompt, token registration/rotation, API+account-scoped stored device ID/binding, old binding token revocation, pre-logout authenticated DELETE with token revocation fallback; added authenticated DELETE transport support. Foreground generic banner, verified request-based payment/details deep links, initial/background tap, event dedup including foreground/tap race, account/epoch checks and app-resume booking-events recovery. Firebase17 legacy registration-token APIs intentionally isolated/suppressed because supplied backend requires FCM token rather than FID. No token/payload logs or automatic payment/journey mutations. All445 Customer tests pass (13 new map/notification tests atop432), Flutter analysis clean, final Android debug APK built successfully and iOS plist XML parsed; no iOS native build on Windows. Docs/customer-live-tracking-and-notifications.md includes config instructions/sources and final manual matrix; status doc updated. No customer Firebase config files supplied/found, so actual push remains unconfigured, gracefully disabled, and live delivery is NOT verified. Provider app still needs GPS/journey actions/full provider-write contract for real movement (customer code only in this task). Backend deployment not verified. No live device/API/payment/rating/journey mutations, no commit/push, existing uncommitted work preserved. Final validation logs: build/customer-live-full-final.log, customer-live-analysis.log, customer-live-apk-final.log. Manual test now pending at user convenience, not as a gate to further already-authorized customer coding.

Latest customer API additions complete (2026-11-10): user authorized completing all specified new customer features before requesting remaining backend details; manual device testing remains last. Implemented option minimumNoticeMinutes/instantBooking metadata and validation, explicit Book now vs Schedule later, fresh outgoing market-local instant timestamps across search/estimate/quote/create, preserved time-based duration and route payload shape. Normalized only instant schedule comparison identities to retain quotes/availability as time advances; actual transport/idempotency snapshots preserve real complete payloads. Scheduled defaults/calendar/quick dates/slider honor notice with5-minute rounding and future zero-notice Schedule later default. Legacy metadata-missing policy behavior preserved. Option drafts retain bookNow, fallback to valid schedule for unsupported new option. Added owned paid cancellation preview/reason/note/expectedRefundAmount POST/saved receipt with strict decimal minor-unit checks, no client refund arithmetic, no POST on dismiss, duplicate guards, 409 requires explicit fresh review, uncertain writes GET-only reconciliation and blocked actions until owned read, identity loss guards and provider-cancel/start races. Refund receipt updates header/history/wallet/removes START/tracking, readable REFUNDED/PARTIALLY_REFUNDED/CANCELLATION_SETTLED labels. Provider compensation displays actual customerPaidAmount only, pending recovery note and explicit receipt refresh; Wallet PROVIDER_PENALTY label added. Target navigationUrl uses explicit external Google Maps launch only after HTTPS/host/path/destination-target validation; missing/unsafe links hidden, launcher errors handled. All462 Customer tests pass,17 new focused tests pass, Flutter analysis clean, Android debug APK built successfully, whitespace clean. Logs build/new-contract-full-final.log, new-contract-final-focused.log, new-contract-analysis.log, new-contract-apk.log. Docs/customer-instant-cancellation-navigation.md implementation/manual checklist; docs/backend-customer-follow-up.md contains ready-to-send Sinhala backend message. Remaining external items: deployment/migrations/option policies, instant-start vs retry deadline cap examples, Firebase client files/APNs/sender config, Provider app journey/GPS write contract, assigned providers for tracking-disabled/history jobs, compensation events/refund ledger type, optional active request recovery/dispute/lock contracts. Do not guess any deadlines/refund policies/provider write endpoints. No live bookings/cancellations/refunds/payments/ratings/device mutations, no commit/push; all pre-existing uncommitted changes preserved.

Post-interruption completeness audit (2026-11-10): user requested a fresh verification after connection/login interruptions. Audited on-disk feature modules/app wiring, current git changes, no unresolved conflict markers and preserved all uncommitted work. Found/reproduced2 notification recovery issues with pre-fix failing tests: failed network logout left signingOut=true for retained session, and secure-storage binding-read failure could be bypassed by registration retry. Fixed retained-session re-registration, bindingReady gate/retry and identity recheck before storing device ID/attaching listeners. Added missing-session auth reconciliation for registration/owned-push lookup (CustomerAuthFailure401 -> auth.restore) to clear stale cached login. Added3 regressions. Auth/notification subset39 pass; fresh full Customer465 tests pass, Flutter analysis clean, Android debug APK rebuilt successfully; whitespace clean. Logs build/recheck-notifications-before.log (expected2 failures), recheck-auth-tests.log, recheck-full-tests.log, recheck-analysis.log, recheck-apk.log. Docs/customer-implementation-recheck.md audit matrix/evidence and live-tracking doc recovery notes updated. Existing Book now/notice/cancellation/refund/compensation/navigation and earlier customer features are wired and compiled; no missing implementation files from the interrupted session found. No live customer/provider/payment/device actions, no iOS native build, no commit/push. Remaining live deployment/Firebase/Provider GPS/API clarification/manual tests unchanged and tracked in docs/backend-customer-follow-up.md.

Booking details payment-card stability (2026-11-11): user reports retry tile intermittently disappears during manual testing. Retained request-recovery subscription at details-screen level across history child replacement, and explicitly preserve previous history data during dependency reload and refresh. Added delayed history GET fixture/regression asserting countdown/action remain visible and recovery identity survives refresh. Payment UI suite 8 passed, Flutter analysis clean, diff whitespace clean. No live payment writes or device restart performed; user hot restart/manual verification remains required. Exact live disappearance cause not observed in logs.

Delayed card payment success refresh (2026-11-11): reproduced stale AWAITING_PAYMENT history after server request became CONFIRMED/PAID via background polling (payment-success-before.log). Payment screen now publishes funded/closed transitions observed by polling/resume to history, wallet and recovery once per terminal status/payment tuple; explicit navigation retained, no extra payment writes. Funded history also replaces a pre-payment AWAITING_PAYMENT local details snapshot. Regression covers cached history plus return to previously opened details after asynchronous card success and verifies no confirm POST. Payment/controller/progress/completion suites 33 passed; Flutter analysis clean; diff whitespace clean. Logs build/payment-success-after.log and payment-success-analysis.log. Provider app unchanged; live manual verification requires Customer hot restart.

Payment recovery latency and unresolved live card result (2026-11-11): user still sees Request84/Job32 awaiting payment and delayed recovery tile. Earlier cache-only correction did not establish live payment success. Recovery now has independent targeted job lookup: account/API-scoped persisted job-to-request hint, owned View/job identity verification, newest-known fallback, no wait for bulk event/history scan, progressive newest-first bulk publication. Window metadata is whitelisted so null jobId cannot erase owned View linkage. Awaiting details display checking status while resolving; funded history is reloaded until caught up and stops payment polling on funded details. Added three regressions: blocked event feed, blocked old request, null window job link; all470 Customer tests pass, analysis clean, whitespace clean. Safe debug-only Booking payment lifecycle logs contain method/path/http/state/payment/methodType/gateway only, no bodies/secrets/card IDs. Phone and emulator connected; read-only adb logs had no new diagnostic lines yet. User says selected TEST CARD then saw an in-app confirmation window, cannot remember whether confirmed-success or confirm-and-pay; live successful financial confirmation is NOT verified. Asked user capital R Customer, open existing Booking32 details only, no extra payment, then inspect sanitized logs. No actual API payment mutation or credentials inspection performed.

Closed unpaid payment labels (2026-11-11): user screenshots show cancelled expired-window booking still labelled Pending payment. Frontend-only presentation now uses Not paid for PENDING/NOT_STARTED when job CANCELLED/EXPIRED/REJECTED across recent/list, details badge and payment summary; neutral badge/list ink replaces payment-due warning. Active pending, failed, paid/reserved/settled and refund statuses retained; backend values and financial actions untouched. Added actual list-to-details cancelled-unpaid UI regression; payment+cancellation widget suites12 passed, Flutter analysis clean. User hot restart needed; no backend change required.

Post-confirmation details retry flash (2026-11-11): reproduced user's View booking details transient retry screen with cached empty history and delayed fresh history response after Wallet confirmation. Details now treat absent target in previous data as loading while history.isLoading, preserving real missing/error retry once read completes. Navigation unchanged; no financial calls added. Added slow-history success-to-details regression (before failed at unwanted Retry booking details, after passes); payment/cancellation UI suites13 passed, Flutter analysis clean, whitespace clean. Logs build/details-retry-flash-before.log, details-retry-flash-after.log, details-retry-flash-analysis.log. No device hot restart performed; user capital R needed for manual review.

Provider START audit (2026-11-16): user entered customer code on Job36 with no visible transition. Existing implementation has funded CONFIRMED gate, four-digit string/leading-zero preservation, owned POST /providers/me/bookings/{id}/start, successful/status parsing, reload to IN_PROGRESS and Request completion action. Found silent submission loss: controller.refresh uses _working without busy UI; _mutate returned false if START collided with foreground polling. Mutations now await only an active safe refresh, show busy while waiting, preserve epoch/session and duplicate-write guards. START rechecks current owned booking canStart before POST and checks epoch after that read. Details now show explicit success/error SnackBar after START result. Two new controller regressions cover held polling+duplicate taps+0472 and cancelled eligibility preflight. Five booking suites25 passed, Provider Flutter analysis clean, whitespace clean. Recent emulator read-only log excerpt contained Job36 GET200 but no retained START response; exact live attempt not independently established. No real START/API write or code capture performed. Provider capital R then manual Job36 retest pending; do not ask user to share code.

Customer single-language filtering (2026-11-16): user requires one language at a time. Fallback Sinhala/English/Tamil chips now replace prior language; backend-defined language filter choices also replace prior choice while preserving array-shaped API contract. Returning drafts restore at most one language in both representations. Gender behavior and unrelated multi-select skills/filters unchanged. Booking widget suite56 passed; explicit English-to-Sinhala UI regression passed after final changes. Logs build/language-selection-tests.log, language-selection-regression.log, language-selection-analysis.log. Existing uncommitted changes preserved; user Customer capital R then manual check.

Single-language live build verification (2026-11-16): user screenshot still showed Sinhala/Tamil/English selected simultaneously. Current source already clears prior selection in fallback and backend filter paths. Extended existing backend MULTI_SELECT field UI test through ENGLISH->TAMIL->SINHALA->ENGLISH; each step asserts a singleton array; focused test passes. Built and installed/launched fresh Customer debug APK on emulator-5554 from this exact workspace using --no-resident and customer.local config; build38.1s, running Customer PID4587, files synced. Account/app storage retained (no uninstall). This removes ambiguity about old running binaries; user's manual language retest pending. Log build/customer-language-emulator-run.log and backend-language-exclusive-test.log. No booking or financial writes made.

Customer booking entry latency (2026-11-16): user reports slow/laggy Caregiver map/filter entry. Audited controller load and map bootstrap; GPS lookup is asynchronous and does not gate form mount, but capabilities was serialized after context/requirements/eligibility/policy. Payment capability read now starts alongside those four independent reads, eliminating that extra sequential network round trip. Existing payment-unavailable fallback, all required checks and account/epoch guards preserved; no readiness cached or backend rules skipped. Added held-context regression asserting settings already started. Booking controller/UI suites123 passed, analysis clean, whitespace clean. Fresh optimized Customer debug APK built and launched on emulator-5554 (PID5089), account data retained, log build/customer-entry-performance-emulator.log. No measured live latency/frame benchmark yet; user manual comparison pending. Logs booking-entry-performance-tests.log and booking-entry-performance-analysis.log. No booking/payment writes performed.

Customer native map/GPS startup (2026-11-16): after parallel API improvement user still reports initial map freeze followed by late GPS camera move. Local google_maps_flutter_android2.21.0 README explicitly documents first-map SDK main-thread jank and warmup. Added direct dependencies on already-resolved Android/platform-interface versions (offline pub get, no version upgrades). main schedules guarded Android Maps warmup after first Flutter frame, no permission/location read; warmup failure does not block app. Booking load exposes account/epoch-guarded onContextReady hook; screen prepares one fresh device GPS future once physical mode known while remaining API calls are pending. Canvas/picker reuse that future instead of starting a second lookup after map mount; permission failures are consumed safely and picker retains existing errors. No GPS preparation for ONLINE, existing/draft pin kept, late GPS cannot replace manual pin; no stale last-known coordinate committed. Added two prepared-GPS/manual-race tests; booking/ride/map suites129 pass. Fresh native debug build installed/launched emulator5554 PID5839 with account storage retained; final analysis log build/map-startup-analysis.log. No live frame-time benchmark or user retest yet. Backend changes not required for these SDK/GPS waits. Logs build/map-startup-tests.log, customer-map-startup-emulator.log.

Booking tab reference redesign (2026-11-16): updated CustomerOpportunitiesBody and BookingSummaryTile to user's reference: navy Bookings heading/live total, rounded icon filters, compact borderless white/mist cards with mint month/day badge, service+bookingID, right-aligned colour/icon status and teal amount. Removed duplicate list count, visible schedule/payment row/divider/chevron from tab cards; full schedule/payment state retained in details and screen-reader summary (including Not paid for cancelled unpaid). Recent Home tiles unchanged. Public Sans CustomerTypography roles retained, large-text/narrow layout stacks safely; actual amounts/status/filter semantics/navigation unchanged. Added320px scale1/2 long-name/large-amount navigation tests and updated cancelled-unpaid accessible-list test. Three relevant suites19 passed, Flutter analysis clean, whitespace clean. Rendered cards inspected on emulator; tightened filter padding and right alignment afterward, reran19 tests, installed/launched final APK emulator5554 PID6994. No financial writes, booking changes or account deletion. Screenshot artifact build/booking-tab-reference-update.png is the intermediate alignment version; latest layout installed, user manual review pending. Logs booking-tab-refresh-tests.log, booking-tab-refresh-analysis.log, customer-booking-tab-emulator.log.

Booking details reference implementation (2026-11-17): user supplied white summary/progress/provider/schedule/location/payment + teal START + patient fields + cancellation + bottom-nav reference. Rebuilt details view using existing Public Sans roles and actual owned booking/catalog fields. Progress embeds a responsive three-step visual while preserving explicit awaiting-completion action, polling, errors and completion confirmation; standalone timeline retained outside embedded mode. START banner teal with adaptive inline action, same reveal/privacy/window logic; cancellation rose card still opens refund review before any explicit write. Patient answers preserve schema labels, strip CG_ fallback prefix, group actual ward/bed and highlight actual notes; no fake fields. Service catalog imagery and name resolve when reopening history. Payment uses actual enum/amount; never substitutes reference Partially paid for Paid/Reserved/Refunded. Added Booking bottom navigation on details, same route/back behavior. Current supplied API lacks authorized provider phone/call permission and reliable general assigned-provider profile read; booking View example lacks saved full street address (only meetingPointName+coordinates). These gaps and data mapping in docs/customer-booking-details-reference.md. Full477 Customer tests passed; after compact visual polish13 focused tests passed; analysis/whitespace clean. Debug APK built/installed/launched emulator5554 finalPID11546; existingBooking34 opened read-only for visual review, no reveal/start/payment/cancel writes. Screenshot build/booking-details-reference-update.png predates final compact provider/mode spacing and corrected Unicode date separator. Logs details-reference-full-tests.log, details-reference-final-ui-tests.log, details-reference-analysis.log and customer-details-reference-emulator.log. User manual UI review pending. All prior uncommitted Customer/Provider work preserved.

Booking details four-state progress correction (2026-11-17): user wants original four statuses preserved in new reference layout. Restored distinct visible steps Booking confirmed -> Service started -> Provider requested completion -> Booking completed; current index maps directly to the four canonical statuses instead of collapsing awaiting-completion into in-progress. Connectors align to four equal-width centres. Narrow widths/large text use a vertical four-row layout with normal compact typography. Existing completion/START/privacy controls unchanged. Progress regression asserts all four labels and distinct completion-request label across state changes; progress/START/completion suites7 passed; analysis/whitespace clean. docs/customer-booking-details-reference.md updated. APK build passed, emulator deployment log build/customer-four-step-emulator.log; manual user review pending.

Compact booking details cards (2026-11-17): user says service-status and cancellation cards are oversized versus reference. Tightened embedded four-state progress heading/spacing plus summary gaps. Also compacted teal START banner (short caption, Show code pill,12px padding, removed leftover bottom spacer). Eligible cancellation now has40px icon, title/caption and side-aligned compact white/red outlined pill at normal widths; narrow/large-text stacks. Receipt layout and all prepare/confirm/uncertainty/error/compensation behavior retained. Card heights verified in UI tests with real Public Sans font (test Ahem geometry caused misleading inflated heights before font loading); START/progress/completion/cancellation suites9 passed, analysis clean, whitespace clean. New debug APK built and installed emulator5554; log build/customer-compact-details-emulator.log. docs/customer-booking-details-reference.md updated; user review pending. No codes revealed, bookings cancelled or financial writes performed by assistant.

Inline START-code reference (2026-11-17): user supplied revealed four-digit banner with copy icon. After explicit Show code, banner now shows title + four separate white digit boxes + copy action inline at normal sizes; narrow/large text stacks responsively. Small hide control retained. Removed old tall revealed column/caption/full-width action. User copy tap rechecks controller.code/alive and writes exact string (leading zeros retained), guards concurrent taps, shows generic success/error feedback, never logs code. No auto-copy, persistent code storage, or clipboard reads/clears; background/expiry/state guards still remove code and copy control. Updated prior no-clipboard doc rule to reflect explicitly user-requested copy action. UI regression mocks system clipboard, asserts no pre-tap copy, exact0472 copy, compact height, large text fit and background hiding. START/progress/completion suites7 passed; analysis clean, whitespace clean. New APK built/installed/launched emulator5554 PID14529; no real device code revealed/copied and no booking/payment writes by assistant. Logs inline-start-code-tests.log, inline-start-code-analysis.log, customer-inline-code-emulator.log. User manual review pending.

## Completion rating bottom sheet - 2026-11-17
- Customer booking details opens Rate the Service once when the open booking transitions to COMPLETED. Historical completed bookings can open it by tapping an unrated provider.
- Rounded white sheet, app typography, five yellow selectable stars, optional note, explicit Submit Review. Backend 1000-character comment limit retained; no default rating, no automatic POST.
- Existing once-per-provider POST and GET-only uncertain-write reconciliation retained. Team reviews remain separate. Narrow/large-text scrolling and account/logout cleanup covered.
- Files: customer_booking_rating.dart, customer_booking_details_screen.dart, customer_booking_rating_test.dart; docs/customer-booking-ratings.md updated.
- Validation: 9 focused rating/completion tests pass; complete customer suite 479 tests pass; Flutter analysis clean. No live review was submitted by the assistant.

## Assigned provider details endpoint - 2026-11-17
- User reports deployed GET /customers/me/bookings/{jobId}/providers. Integrated a separate stateful provider card into Booking Details: name/photo/rating/review flag and active team members in backend order.
- Phone/dialler visible only with contact.callAllowed=true AND current booking CONFIRMED/IN_PROGRESS. History retains profiles without contact. Read errors offer Retry provider details without blocking booking UI. Status/resume reload; account/epoch guards drop late responses.
- Repository expects {jobId,providers:[...]} and validates owned job/list/provider IDs/contact map. Backend summary supplied, full CUSTOMER_BOOKING_PROVIDERS_API.md not attached; live payload shape still needs manual confirmation. Supports phoneNumber nested under contact or provider, no invented profile/contact data.
- Analysis clean. Final providers/rating/opportunities widget suites 15 tests pass, including team display, completed-state contact suppression and 320px/2x text. Broad run had 480 pass and one standalone layout test failure from initial consumer placement; fixed via injected assignedProviders widget and all affected suites rerun passing. No actual phone call/payment/review sent.
- docs/customer-booking-providers.md added. Existing uncommitted work retained.

Provider card reference styling (2026-11-17): replaced tinted titled list with white rounded bordered card, circular 56px provider portrait, Provider/team-member caption, name and authorized phone, teal rounded call action at right. App typography, API loading/error/team support and contact-state guards retained. Provider widget tests2 pass including 320px/2x text. No real calls made.

Compact booking summary reference (2026-11-17): compacted date/location tiles and provider spacing. Payment panel now horizontal icon/divider, label+actual amount, real status badge at right; narrow/large-text fallback stacks badge. Payment method retained in semantics; backend values and actions unchanged. Details/provider tests8 pass; analysis checked separately. No fictitious Partially paid status introduced.
Final compact provider row uses 46px portrait and Provider/name/phone only to match reference; rating/review metadata remain available from the API and existing review UI. Final details/provider tests8 pass.

Add a Review reminder (2026-11-17): completed single-provider unrated booking now has mint gradient Add a Review banner with star tile, placed below service progress above assigned provider. Dismissing rating sheet retains banner; tapping reopens explicit star/note review sheet. Saved reviews replace reminder; unreadable/unknown states retain check-status controls; team bookings keep provider-specific review list. No default rating or automatic POST. Focused rating/completion tests9 pass including close/reopen without POST. Existing changes preserved.
Booking details duplicate loaders (2026-11-17): independent ratings/providers GETs previously rendered two linear bars. Hide initial review section until rating eligibility returns; provider uses a compact portrait/loading caption placeholder without an animated bar. Existing data/retry/unknown-write safeguards retained; focused provider/rating tests9 pass. No API flow changes.
Booking details skeletons (2026-11-17): replaced provider loading caption and hidden initial review area with shared static mint skeletons matching portrait/name/phone and review banner shapes. No shimmer timer/dependency or linear progress bars; accessible loading semantics. Existing data/error/eligibility logic unchanged. Emulator was disconnected on preceding run; no device launch attempted for this patch.
Full Booking Details skeleton (2026-11-17): initial history loading, missing-history refresh for newly confirmed booking and null history now use full scrollable static skeleton for summary/progress/provider/schedule/location/payment/start/patient cards. Existing cached data stays visible on refresh. App header/navigation remain usable; errors retain explicit retry. Slow-history navigation regression updated; request-payment/opportunities suites17 pass.

Assigned provider details sheet (2026-11-17): tapping assigned provider row opens rounded white bottom sheet with photo/name/role badge, rating/review count, reviewed flag and Close. Authorized current-status phone/call preserved. Sheet watches account and booking history so logout hides identity data and completed/current closed state suppresses phone. Existing parent dialler guard rechecks alive/status/loading. No fake experience, verified/background-check, About or skills added: supplied endpoint summary has none. Existing search-provider dialog unchanged. Provider widget tests2 pass, including open/close, no completed phone, rating display and 320px/2x text. Flutter analysis clean.

Cancellation bottom sheet reference (2026-11-17): replaced paid cancellation AlertDialog with rounded scrollable white bottom sheet, red calendar icon/title, local plain-text reason dropdown (Plans changed/Booked by mistake/Service no longer needed/Other), custom Other reason, optional note and responsive Keep booking/Cancel Booking buttons. Actual backend refund/retained amount/fee/policy remain visible before explicit confirm; unchanged c.prepare/c.confirm, expectedRefundAmount checks, uncertain-write safeguards and no automatic POST. Note max1000 and custom reason max100 API limits retained. Cancellation controller/widget suites10 pass; Flutter analysis clean. User hot restart via active Flutter terminal; no live cancellation performed.

Cancelled booking reference (2026-11-17): details summary now has red cancelled status connector/notice and muted provider/schedule/location/payment region. Cancelled START card explicitly unavailable and never mounts code loader. Actual refund/payment labels and cancellation receipt/compensation section retained; no fake Partially paid status or sample timestamp. Cancellation timestamp displayed only if returned booking.cancelledAt exists. Booking/cancellation/payment widget suites19 pass; analysis clean. No live cancellation performed.
Cancellation receipt readability (2026-11-17): refund amount now separate prominent mint wallet panel, amount paid/fee/policy/reason/note in labeled divided rows, informational wallet destination callout. Narrow/large text stacks label/value. Compensation uses credited customerPaidAmount unchanged. Cancellation UI/controller tests10 pass; Flutter analysis clean; financial API actions unchanged.

## Customer Profile overview and actions - 2026-11-17
- User supplied full CUSTOMER_PROFILE_OVERVIEW_API.md and confirms overview, paginated requests and contact OTP endpoints deployed; stale local-only notes are historical. Contract copied to docs with that note.
- /account now renders Profile: actual name/photo, edit through existing /profile, server counts, per-currency real spending, debug-only separated test spending, verification flags, documents with status/review/expiry/rejection, pending/history links and preserved market/signout/all-session actions. No fabricated financial/verification fields. Full replacement profile editor retained.
- New contact sheet implements signed-in email/phone send/verify, six-digit leading-zero OTP, optional current password, server resend/expiry, 400 stays signed-in, 429 delay, no automatic POST replay and read-only reconciliation/blocking for uncertain verification. No live OTP sent by assistant.
- Documents read scoped requirement definitions before controls; private evidence upload/view-url and explicit submission by requirementId reused. Validation includes type/size/count/expiry; unknown write blocks blind repeat. No live upload/submission by assistant. Existing private upload pipeline retained for evidence.
- Pending requests paginate/deduplicate and keep unknown states active, with read-only request status; historical/legacy bookings retained through existing booking lists. Unselected profile footer Home works. Selected Booking footer in details returns to list (former View all removal had exposed a dead tab).
- Validation: final full Customer suite488 passes. Final visual changes (white centered title, No real payments empty label) followed by profile suites7 pass and Flutter analysis clean. Initial legacy account test assumptions updated to real overview/scroll and last PUT (overview adds reads).
- Installed on emulator-5554; read-only live profile overview loaded actual account/contact/count data successfully. Screenshot build/profile-overview-live.png is before final header visual correction. Tests do not establish actual SMS/email delivery or document review.
- docs/customer-profile-overview.md describes actions/manual checks. Existing cumulative uncommitted changes preserved; no commits/pushes.

Profile reference colour/layout refinement (2026-11-17): teal gradient/circle header with centered white Profile title, rounded white content body, borderless compact identity header with mint Client account/Edit action, three mint/purple/amber stat cards at ordinary mobile width, navy headings, icon bubbles, compact verification rows, document review/action columns, and coloured pending/history status pills (blue assigned, amber awaiting, green completed, pink cancelled). Narrow/enlarged text stacks safely; View all uses flexible icon button after detecting/fixing a 2px large-font overflow. Real API data, per-currency spending and all edit/OTP/document/navigation actions retained. UI/profile/navigation tests28 pass; Flutter analysis clean. No actual contact/document writes performed.
Profile visual review follow-up: live reference palette screenshot build/profile-reference-colours.png verified gradient/rounded body, mint/purple/amber cards, contacts/badges and complete footer. Final stats refinement changes vertical card contents to compact horizontal icon+value/label with 88px minimum; profile/navigation tests28 pass. Snapshot predates that last compact card adjustment. No API/business changes.

## Service-specific document gating and Profile discovery - 2026-11-18
- Generic metadata-driven Service documents screen before filters/provider search when pre-request eligibility is false and a required/blocking upload is MISSING/PENDING/REJECTED/EXPIRED. No Home Care IDs or certificate fields hardcoded. Other non-upload requirement flow and post-created payment/business flow retained.
- Initial booking load retains independently fetched requirements/eligibility if booking-context is denied. Once backend approval makes eligibility true, refresh returns to booking, reloading context if previously denied.
- Shared ServiceDocumentRequirements presentation and Profile Add service documents picker load active-market services/options and scoped requirements, covering never-submitted service-specific uploads omitted by overview. Existing private upload/view and explicit requirementId submission reused. Successful external saves clear only that requirement's stale draft before refresh.
- PENDING document forms are read-only (view allowed; remove/upload/expiry/submit disabled). Rejected/expired can resubmit; optional expiry stays optional. Close/submit reloads authoritative requirements/eligibility and Profile reloads overview on return. Empty Profile copy now No documents submitted yet.
- New tests cover missing gate/no search or write, explicit rejected resubmission, pending read-only, approval return, Profile first-submission scope discovery, enlarged text and context403 with all blocked statuses. Full Customer suite492 passes; Flutter analysis clean; whitespace clean.
- Built/installed/run on emulator-5554 and read-only live Home Care navigation verified. Existing account has a REJECTED backend test certificate; live gate displays returned reason and configured 1-2 files/10MB/PDF,JPG,PNG,WEBP. No live upload, submission, admin review or booking write by assistant. Screenshot build/home-care-document-gate.png; run log build/customer-service-documents-emulator.log.
- docs/customer-service-documents.md added. All prior cumulative uncommitted changes preserved; no commit/push.
Profile bottom actions cleanup (2026-11-18): user requested only Change service area and Sign out. Removed My bookings and Sign out all sessions UI from Profile; underlying booking navigation and auth all-session API remain unchanged. Retained actions now rounded icon/chevron rows: pale mint service area and subtle blush signout, app typography and busy guard. Existing account/navigation test updated to use Booking footer and assert removed shortcuts absent. User active Flutter terminal hot restart required.

Profile photo access investigation (2026-11-18): user screenshot shows image-load failure. Read-only sanitized emulator log confirms repeated HTTP403 from server image requests, not upload validation. Current image display uses returned URL without API authorization headers as public-photo contract requires. Frontend now gives concise 403-specific unavailable/retry/choose-another copy; retains photo URL, explicit cache-evict retry, no local fallback masking server failure. Photo/profile tests22 pass; analysis clean. Actual photo delivery remains blocked pending backend/CDN/storage URL access fix; do not report fully fixed. No storage permissions changed, no new photo upload or profile PUT performed. Ask backend to make returned profile-photo URL serve HTTP200 valid image via intended image delivery, including existing stored URLs; do not send API tokens to image host.

Service document UI refinement (2026-11-18): themed teal/white app bars for booking gate and Profile document picker; compact mint intro with icon/title; white document cards with status pills, separate blush rejection notice, file-limit info panel and mint upload action. Upload sheet now has document icon/title, file-requirements panel, file-count heading, bordered document rows with view/remove, rounded add action, separated calendar expiry field and full-width teal submit. Existing metadata limits/private view/upload, optional expiry, explicit submit and pending read-only state preserved. Targeted service-document/profile suites11 pass; Flutter analysis clean; diff whitespace clean. Extended 320px/2x coverage through upload and pending read-only sheets, then resets viewport for existing booking-form navigation. That separate existing booking_schedule_picker.dart:511 row overflows with mock font at 320px/2x and is outside this styling patch; noted for a future schedule accessibility pass. No live document writes performed. User active Flutter terminal R needed to see changes.

## 2026-11-18 - Public service icon session cache
- User reported service icons loading again after returning Home. Discovery already retains catalog metadata; CatalogIcon now uses shared public SVG/raster byte cache across route remounts.
- Added customer_catalog_media_cache.dart and catalog_media_image.dart; 64 entries/20 MB LRU, 5 MB asset cap, in-flight deduplication, cache headers/conditional validation, stale image retained while refreshing, bounded failure cooldown. No API auth on media requests. No profile/private document pipeline changes and no disk persistence.
- Added seven cache/remount tests. Full Customer suite: 499 passed. Flutter analysis: no issues. See docs/customer-service-icon-cache.md. No device install performed for this patch; hot restart current customer run to manually check Home -> service -> Home.

## 2026-11-18 - Customer booking text chat
- Implemented supplied Booking Chat API in Customer app (customer prefix, not pasted provider inbox prefix). Messages footer now opens inbox and shows totalUnread; booking details opens job chat. Team participant/sender names retained.
- New features/messages repository/controller/screens: latest/after/before pagination, deduplication, four-second foreground/current-route polling, viewport-only read receipts, Seen, server canSend/sendUntil, plain server-masked text and unavailable content placeholder. No images/calls/voice, no chat disk storage/body logging. 404 returns to inbox; 409 reloads availability; auth failures reconcile session.
- Explicit send uses random 48-character valid clientMessageId. Uncertain send keeps same payload/id for manual retry; GET polling reconciles accepted clientMessageId. No optimistic unmasked bubble or automatic POST retry. 400 draft retained, 429 temporarily disables send. Account change clears text/inbox and ignores late responses.
- Existing push host validates owned request/job before routing CHAT_MESSAGE_FROM_PROVIDER to chat, uses generic no-content snackbar, refreshes inbox. Booking event recovery and app resume also refresh unread data. Existing push configuration still required for actual push delivery; Provider app UI unchanged.
- Validation: complete Customer suite508 passed; final focused chat/navigation/push suites23 passed (see build/customer-chat-tests.log), Flutter analysis clean. New tests use fake adapter only, including lifecycle, 320px/2x readonly layout, retry identity, masking, read receipts, pagination, rate limit, signout and push routing. No live messages sent/receipts marked by assistant, no device install for this patch. Existing cumulative changes preserved.
- docs/customer-booking-chat.md documents contract/manual checks. Supplied attachment says backend not deployed yet; asked user asynchronously whether live; no confirmation received during implementation. Do not claim live end-to-end chat or provider chat UI verified. Customer active Flutter terminal hot restart R to load changes.

## 2026-11-19 - Booking Details reference flow and isolated UI Lab
- Prior reference upgrade uses the actual Booking Details page: gradient/circle header, state pill/countdown, provider call/chat, compact schedule/location/payment, collapsed patient answers, four-stage expandable timeline, START window, review reminder/saved feedback, cancellation receipt and embedded payment recovery. Compact live maps reuse Google Routes for a single fresh provider; stale routes are removed and refresh is bounded. Native visit to Booking #36 ultimately returned HTTP200 for provider/ratings and showed the real provider and saved five-star review. Initial temporary read failures recovered; do not claim a confirmed backend failure. No live writes or chat read receipts performed.
- Important correction: full BookingResponse has flat latitude/longitude. bookingLocationPoint previously read only nested projections, so the prior missing-map fallback did not establish missing backend data. Now reads/validates flat pairs as well, including valid zero coordinates; incomplete/out-of-range pairs still fall back. Regression tests added. Backend chat deployment is confirmed by user; stale not-deployed note in previous handoff is superseded.
- User approved step-by-step review using real widgets with fake data, explicitly avoiding cloned UI. New debug-only entry main_booking_ui_lab.dart + debug/booking_ui_lab*.dart + scripts/run-booking-ui-lab.ps1. Default Ready (4h23m), Ready / 23m code scenario, plus later-state fixtures. Amber toolbar: scenarios, 1/1.3/2x text, 320px content width, reset. Shared production CustomerBookingDetailsScreen/controllers/repositories are mounted, not copied.
- Lab has memory-only auth/recovery stores, fake adapter restricted to booking-ui-lab.invalid, unknown paths local501, Dart HTTP connections blocked in the entry, no Firebase/push host, no device GPS/Google Maps/Routes, and an explicitly labelled offline sample map boundary. Provider call launcher is now injectable (production default unchanged); lab intercepts it. Sample actions never hit real APIs. Payment checkout is an explicit later-review boundary, not a fake live payment flow. Provider/service photos currently use actual fallback widgets in the lab.
- Android lab installs separately as com.bthere.customer.bookinglab / Booking UI Lab via explicit Dart flag. Normal main.dart does not import the lab; normal package/label remain com.bthere.customer / B there Customer. Firebase config skipped only for lab; activity class stays explicit com.bthere.customer.MainActivity. Do not pass real config files/keys to the lab script.
- Validation: lab-specific tests14 passed; full Customer suite527 passed; Flutter analysis clean; launch script syntax/whitespace checked. Native debug lab built, installed and launched on emulator-5554. adb pm verifies both normal and lab packages coexist. Ready screen visually verified: sample provider, call/chat buttons, 4h23m, offline map and actual schedule/location tiles. Screenshots build/booking-ui-lab-ready.png and build/booking-ui-lab-scenes.png; build/booking-ui-lab-emulator.log.
- docs/customer-booking-ui-lab.md covers launch/isolation/first Ready review. User's next step is manual Ready review before further styling/next lifecycle state. Use .\scripts\run-booking-ui-lab.ps1 -DeviceId emulator-5554 (optional -Scene ready-code). Our tool launch was --no-resident, so no active tool terminal for hot reload; rerun script for resident development.
- Cumulative uncommitted changes preserved; no commits/pushes or actual booking/payment/document/contact/chat writes.

Ready header review pass 1 (2026-11-19): user selected Header (service image, booking ID, Ready/countdown) as the first UI part. Extracted shared BookingDetailsIdentity: compact mint image circle, app-standard Public Sans title, subdued booking-ID chip and responsive placement. BookingStatusSummary now has state-appropriate icons, mint Ready/check badge, clock icon, muted Starts in prefix and bold remaining time, plus a divider when they fit; measured text widths stack safely on narrow/enlarged text. No status/payment/time-window logic changed. Shared production widget is used directly by the UI lab; other cards unchanged. Added narrow/large-text long-name/header bounds coverage. Focused header/lab/booking/completion suites27 pass; Flutter analysis clean; whitespace clean. Updated separate Booking UI Lab on emulator-5554 and visually verified Ready header (build/booking-header-ready.png). User next step: manually review this header and request refinements before proceeding to provider/map cards. Native tool launch remains --no-resident; script can be rerun for resident hot reload. Existing changes preserved; no live API actions or commits/pushes.

### 2026-11-19 - Booking header: selected service option, no icon
- Removed the service image from the shared Booking Details identity header, as requested.
- Header resolves the exact selected option (e.g. Hospital Care), never substitutes the Caregiver category. Uses response snapshot / remembered option / matching catalog option with owner-scoped lookup.
- Offline UI lab uses Hospital Care and is installed on emulator-5554; visually verified build/booking-option-header-ready.png.
- Focused tests: 27 passed. Flutter analysis: no issues. git diff --check passed. Existing uncommitted changes preserved.

### 2026-11-19 - Provider card review step
- Moved the Ready/active Booking Details provider card below the map, per user request. Completed ordering and unpaid behavior preserved.
- Provider label/name/phone now use weight 700 (previously 600), retaining app typography sizes and authorized contact behavior.
- Full-page skeleton matches map-before-provider and icon-free header. Lab test asserts provider appears below map.
- Focused UI lab/provider tests: 16 passed; analysis clean; diff whitespace check clean. Offline emulator lab rebuild requested for manual review.

### 2026-11-19 - Compact schedule/location cards
- Updated shared BookingScheduleLocation to reference-style horizontal icon/text tiles, mint circle icons, pale backgrounds, smaller labels and bold navy values.
- Equal-height side-by-side tiles at normal widths; narrow/enlarged text stacks without truncating schedule/address. Existing end time and duration data retained.
- Focused reference/lab tests: 19 passed; analysis clean; whitespace check clean. Offline emulator lab rebuilt for review.

### 2026-11-19 - Schedule display follow-up
- Per user reference, schedule card now displays only the start date/time plus existing duration in hours (or hours/minutes). End date/time is no longer rendered in this card; underlying booking dates and duration calculation unchanged.
- Validation: focused reference/lab tests 19 passed, analysis clean. Updated offline UI lab APK installed on emulator-5554.

### 2026-11-19 - Short schedule label
- User requested removing year and duration from the schedule UI. Card now shows localized month/day plus start time only; removed duration calculation from the view. Backend date/time values unchanged.
- Validation: 19 focused tests passed, analysis clean. Updated offline lab build installed and launched on emulator-5554.

### 2026-11-19 - Payment summary card review
- Replaced generic Material wallet/card glyph with the exact footer navigation wallet.svg asset, tinted teal, for the Payment summary.
- Increased amount emphasis to section size / weight 700 and tightened padding. Text measurement determines whether status badge fits alongside amount; large values/text stack without truncation. Real payment label/state logic retained.
- Focused reference/lab tests: 19 passed. Offline emulator lab build requested for user review.
- Analysis clean; diff whitespace check passed. Offline lab APK installed on emulator-5554.

### 2026-11-19 - Payment row reference correction
- User requires amount and status in one row. Removed divider/stacked badge behavior; compact 36px footer wallet icon, 20px bold amount, status on right. Scale-down protects full amount/status from horizontal overflow.
- Focused reference/lab tests: 19 passed. Normal state labels and money unchanged.
- Analysis clean; whitespace check passed. Updated offline lab APK installed on emulator-5554.

### 2026-11-19 - Payment badge background colours
- Status badge now has distinct fills: reserved/pending amber (reference), paid green, refunded blue, failed red, other/closed neutral grey. Backend status text unchanged; single-row amount/badge layout retained.
- Validation: 19 focused tests passed, analysis clean, whitespace check clean. Updated lab APK installed on emulator-5554.
- 2026-11-19 follow-up: payment status badge text increased from weight 600 to 700 per user request; colours and labels unchanged.

### 2026-11-19 - Remove service timeline option
- Removed View service timeline expansion from CustomerBookingProgress at user request. Status polling, noncompact progress steps and explicit completion action retained.
- Updated existing progress widget expectations; focused progress/completion/lab tests: 18 passed.

### 2026-11-19 - Patient details card review
- Refined expandable Patient details card: pale white gradient, mint people icon, bold navy title, explicit muted arrow colours, clipped rounded corners and compact spacing.
- Expanded answers use bold values with subtle row separators; dynamic fields, ward/bed tiles, notes and responsive stacking preserved. No patient fields invented.
- Validation: 19 focused reference/lab tests passed; analysis clean; diff whitespace check clean. Offline lab update installed on emulator-5554.

### 2026-11-19 - Patient dropdown data reference
- Aligned regular patient labels and bold values in compact rows with thin dividers (stack only on narrow/large text). Ward and bed retain side-by-side pale tiles with label above value. Notes now explicitly vertical, separated mint panel with label above full text.
- All content remains dynamic from booking answers; no backend changes or fake data added. Focused reference/lab tests: 19 passed.
- Analysis clean; whitespace check clean; updated offline lab APK installed on emulator-5554 for review.

### 2026-11-19 - Patient note alignment correction
- Additional information panel now fills the same available width as Ward/Bed tiles. Dividers appear only between regular rows; removed the final divider under Hospital name before tiles.

### 2026-11-19 - Quiet cancellation action
- Replaced eligible-booking cancellation promo card with a centered small muted-red Cancel booking TextButton after patient details. No background, border or icon; retains 48px tap target.
- Existing review/refund sheet, eligibility, working/uncertain guards, errors and cancellation receipt unchanged.
- Cancellation controller/widget and offline lab tests: 24 passed. Analysis clean; diff whitespace check clean.

### 2026-11-19 - Cancellation review sheet styling
- Reason dropdown now has white rounded menu, selected checkmark, labelled pale field with list icon and teal expand arrow.
- Refund preview uses bordered mint information panel, clear heading and bold refund amount, spaced policy/fee/retained data and separated wallet refund explanation. Backend preview values and cancellation validation unchanged.
- Keep booking is now solid teal primary action; Cancel Booking is pale red with muted-red text. Existing 48px targets and responsive button layout retained.
- Verification: cancellation widget/lab tests 16 passed, analysis clean, whitespace check clean. Updated offline lab APK installed on emulator-5554.

### 2026-11-19 - Replace default cancellation reason menu
- Replaced native grey DropdownButtonFormField popup with themed white rounded reason selection sheet. Full-width pale option rows, selected mint row and check icon; scrollable/SafeArea for large text.
- FormField retains required reason validation and Other text path; selection updates only on chosen value, dismiss preserves existing reason. Cancellation itself still requires original confirmation.
- Cancellation widget/lab tests: 16 passed; analysis clean.

### 2026-11-19 - Hide footer on booking details
- Removed bottom navigation from shared BookingDetailsPage, including loading/error and all booking states. Existing Back/pop and bookings fallback remain; SafeArea keeps gesture inset clear.
- Lab asserts footer absent. Offline lab launch targets ready-code for the next review step; start-code UI unchanged in this revision.
- Validation: 19 focused tests passed; analysis clean; whitespace check clean. Updated lab APK installed on emulator-5554.

### 2026-11-19 - Service Start Code card review
- Updated hidden/revealed card with teal multi-stop gradient, mint/white Show code pill, translucent grid icon panel and divider. Title bold; digits larger/bold with tabular figures in white boxes, preserving leading zero.
- Compact normal-width layout remains within existing 100px contract; narrow/large text stacks. Hide/copy actions and lifecycle/expiry/account guards unchanged.
- Initial taller variant failed compact-height check; corrected and all 30 start-code controller/widget/lab tests now pass. No real codes or live writes used.
- Final analysis clean; corrected lab build installed. Hidden start-code card visually verified in build/start-card.png; sample reveal inspected separately. No live API actions.

### 2026-11-19 - Revealed start-code reference row
- Compact revealed card now uses single-line Service Start Code title, divider, four smaller white digit boxes and copy action on the right, matching user reference. Removed standalone eye icon; title opens a Hide code popup option.
- Narrow/large text uses stacked fallback. Code remains string with leading zero; lifecycle/expiry guards unchanged.
- Start-code controller/widget/lab tests: 30 passed. Analysis checked separately.
- Final analysis clean; whitespace check clean; updated offline lab APK installed on emulator-5554.

### 2026-11-19 - Dedicated Hide code action
- Removed hidden title popup. Revealed code card now shows a visible white Hide code text/eye button below its title, alongside existing digit boxes and copy action. Button directly hides code; original reveal and lifecycle guards retained.
- Added direct hide/re-show checks to existing widget test. All 30 start-code/widget/lab tests passed. Initial validation was interrupted by approval-service usage limit; resumed successfully on user continuation.
- Final analysis clean; whitespace check clean. Updated offline lab APK installed on emulator-5554. Interactive PTY launch unavailable (Access denied), so used standard nonresident launch.

### 2026-11-19 - Compact Add a Review banner
- Matched reference with compact mint gradient banner, navy bold title, compact subtitle, subtle code-painted wave and white star tile with decorative sparks. Uses native code artwork, no new image/network assets.
- Existing eligibility, review sheet and submit flow unchanged. Rating/lab tests: 21 passed.
- Final analysis clean, whitespace check clean; updated offline Completed scene APK installed on emulator-5554.

### 2026-11-19 - Rating popup reference
- Refined Rate the Service sheet with pale background, spacious stars row, bordered note field with 250-character counter, and full-width bold teal Submit Review button with 12px corners.
- Removed extra provider-name line for single-provider bookings (kept for teams). Close action, eligibility, uncertain-result handling, actual selected rating and submit flow retained; stars never preselected.
- Rating/lab tests: 21 passed; analysis clean. Offline Completed scene update requested.
- Whitespace check clean. Updated offline Completed scene APK installed on emulator-5554.
- 2026-11-19: Rating sheet and note field updated to soft white/lavender #F7F5FC per reference. No interaction changes.

### 2026-11-19 - Saved review reference row
- Replaced stacked rating summary with pale compact row: review bubble icon, five amber stars, divider and actual saved comment. Empty comment omits divider/text; large text/narrow view stacks safely.
- Numeric score retained as accessibility label, decorative stars excluded from duplicate semantics. Existing team review handling unchanged.
- Updated rating tests for semantic score widgets. Rating/lab tests: 21 passed.
- Final analysis clean; whitespace check clean. Updated offline Reviewed scene APK installed on emulator-5554.

### 2026-11-19 - Payment failed Booking Details reference
- Failed-payment header aligns the red failure badge beside option/title and booking ID at normal widths (stacks for large text). Unpaid failure state also follows authoritative recovery paymentRetryStartedAt, including wallet shortfall with NOT_STARTED; paid views do not subscribe to recovery here.
- Details retry banner now uses footer wallet SVG, failure indicator, teal gradient, bold Retry Payment heading, deadline text and white pill action alongside content. Narrow/large text stacks; pending/expired states retain View status and accurate messaging.
- Schedule/location/patient UI remains as approved; payment status remains actual API value, not reference's sample Partially paid.
- Focused reference/payment recovery/lab tests: 30 passed. Initial display assertion exposed missing retry-timestamp header state; corrected. Existing retry route and payment execution unchanged.
- Final analysis clean; whitespace check clean. Offline payment-failed scene visually verified on emulator-5554: build/booking-failed-reference.png. No real payment actions executed.

### 2026-11-20 - Compact Retry Payment card reference
- Tightened retry banner typography/icon/button spacing to match reference; uses full failure sentence and white pill action, native-painted subtle background curves.
- Moved backend-derived remaining time to a small line below banner so the card stays compact; countdown/urgent warning and pending/expired action guards preserved.
- Payment recovery/lab tests: 25 passed. Final red failure-icon tint only changed after checks.
- Analysis clean; whitespace check clean. Updated payment-failed lab visually verified: build/retry-compact.png. No live payment actions.

### 2026-11-20 - Failure indicator colour follow-up
- Retry wallet indicator now uses explicit red circle with white border and white exclamation mark (previous icon cutout inherited teal).
- Payment Failed header/payment summary badges now share warm pale coral #FFE2DC fill and dark red #C5362B text/icon. Other booking status colours unchanged.
- 2026-11-20: Payment Failed header and payment-summary text/icon now use #F04452, exactly matching retry-card red indicator; backgrounds unchanged.

### 2026-11-20 - Actual service elapsed timer
- User confirmed backend timestamp deployment. Booking Details now displays actual elapsed HH:MM:SS below header during IN_PROGRESS, and fixed Service duration after actualFinishedAt. completionConfirmedAt never extends duration.
- Accepts UTC/offset actualStartedAt/actualFinishedAt only; never uses scheduled dates. Missing, offsetless, reversed or future timestamps do not show a guessed timer. Historical completed bookings without finish data omit timer.
- Local foreground ticking only, no per-second HTTP. Pause/resume recalculates from timestamps. Existing 5-second progress refresh now notifies on actual start/finish/completion timestamp corrections even if status unchanged.
- Lab has sample actual timestamps for in-progress/completion/completed. Tests cover UTC conversion, ticks, freeze, delayed customer confirmation, missing/future data, large text, lifecycle resume and same-status timestamp updates: 25 relevant tests passed. Analysis clean.
- Clock uses existing customerClockProvider (device clock in production); no server-time offset field/contract supplied in pasted backend summary. SERVICE_TIMER_API.md referenced by backend was not supplied. No unsupported clock-correction behavior invented.
- Final analysis clean after three braces-style fixes; timer visually verified on emulator in build/service-timer.png. Existing tests 25 passed before brace-only changes. No real service start/finish/completion actions executed.

### 2026-11-20 - Booking UI accessibility and normal app integration completed
- Added 27-state/action accessibility checks: all 11 booking scenes at 320x568 and 568x320 with 2x text, expanded patient data, provider/rating/cancellation/START/chat sheets, nested reason picker and keyboard insets.
- Fixed cancelled/expired progress row horizontal overflow by constraining cancellation step. Error screen is now a scrollable bounded retry card, so short/large-font views do not overflow. Full-page skeleton matches the unified reviewed layout and announces loading semantics.
- Fixed embedded booking chat at large fonts/small viewports: compact one-line name header, hides unnecessary avatar/subtitle when constrained and removes duplicate participant-name strip. Message send/read/privacy behavior unchanged.
- Updated a stale normal-app integration test to assert the details footer is absent; normal booking route remains testable directly.
- Verified normal main.dart/CustomerBootstrap imports no UI Lab. Booking list and confirmation navigate to the shared production CustomerBookingDetailsScreen; all reviewed UI is already production code, not cloned lab widgets.
- Final full customer suite: 562 tests passed. Accessibility matrix: 27 passed. Flutter analysis clean. Normal main.dart debug APK built successfully using existing config, no lab defines. aapt2 confirms package com.bthere.customer, label B there Customer.
- Existing app data and cumulative uncommitted changes preserved. UI lab remains optional separate app. No real booking/payment/START/completion/cancel/chat writes executed during checks. Manual live customer/provider E2E remains the final account-level verification.
- Known pending item: device-clock synchronization for service timer awaits SERVICE_TIMER_API.md contract; no invented server-time fields.

### 2026-11-21 - Cancelled booking details polish
- Removed duplicate Ready-to-Cancelled progress line; retained authoritative cancelled badge and bold cancellation notice/date when available.
- Cancellation receipt now has compact status icon/title and clearer bold refund amount with the same footer wallet SVG. Existing paid/fee/policy/reason/note/compensation fields preserved.
- Receipt loading is a labelled compact indicator only when no receipt exists; background refresh no longer inserts a linear loading bar over existing refund details.
- Analysis clean, whitespace check clean. 43 cancellation-widget/accessibility/lab tests passed. Controller test file could not launch: Windows Application Control blocked flutter_tester.exe for that process; no policy/security changes or bypass attempted. Overall command reported failure for that blocked file only.
- Last device check had no emulator connected; no new APK install or visual claim made for this revision. Changes are shared production widgets used by normal app and lab.

### 2026-11-21 - Cancelled cards match approved pattern
- Aligned cancellation receipt with shared white rounded card, faint border/shadow, navy bold headings/row values and mint gradient refund summary. Notice has pale red circular close icon; wallet explanation uses pale blue/mint panel.
- Real refund/fee/reason/policy/compensation logic unchanged. Analysis clean; whitespace check clean. No new device installation or real cancellation actions performed.
- 2026-11-21: Removed the duplicate This booking was cancelled notice card as requested. Header Cancelled badge and full refund/cancellation receipt remain. Updated widget expectations.

### 2026-11-21 - Booking chat reference styling
- Updated shared chat with pale white/blue sheet, bold navy participant title, mint call action, mint outgoing/white incoming rounded-tail bubbles, faint received-message shadow, compact timestamps and real read-receipt check icon.
- Added local calendar-day separators (Today/Yesterday/date), using existing app clock and sentAt. Groups only adjacent chronological messages; message identity/viewport keys remain on actual bubbles for existing read-receipt logic.
- Rounded pale composer and teal outlined-send action. No unsupported attachment, online-presence indicator or dummy menu added. Existing message sending, retries, masking, privacy and pagination preserved.
- Customer chat widget + accessibility + lab tests: 44 passed. Flutter analysis clean; whitespace check clean. No live messages/read receipts sent by assistant. Main app and lab share widgets; emulator build not installed for this revision (last device check was disconnected).

### 2026-11-21 - Remove Messages footer destination
- Footer now shows Home, Booking, Services and Wallet with four equal-width destinations. Removed footer unread-badge subscription/rendering; retained inbox route and enum for existing inbox screen compatibility.
- Booking Details provider chat remains available. Chat tests use explicit inbox route rather than removed footer entry; navigation test asserts Messages absent.

### 2026-11-21 - Booking chat sheet auto-dismiss fix
- Found embedded chat auto-pop on initial unavailable/404 error. Embedded sheet now stays open with API error and Retry; standalone inbox fallback unchanged. Removed contradictory empty-conversation hint while initial load is in error.
- Added regression: unavailable initial response keeps sheet visible/composer absent, Retry success restores composer, explicit Close dismisses, no message POST. Chat/accessibility tests: 31 passed; final analysis clean.
- No live API response captured, so exact server reason still unverified. No emulator rebuild/install this turn. Existing account/privacy guards unchanged.


### 2026-11-21 - Chat v1 integration for both apps
- User authorized implementing available deployed chat contract while backend G1-G3 are requested separately. No 30-minute gate, inferred presence, unsupported attachments or local 24-hour extension.
- Customer: drain hasNewer pages, team sender labels only for shared chats, exact 409 detail mapping, 403 does not logout, HTTP Date + monotonic clock for chat deadlines/rate cooldown, stable explicit uncertain-send retry even after send window closes.
- Provider: replaced Messages placeholder with authenticated API inbox/shared sheet, booking-details chat action, totalUnread footer badge, four-second foreground thread polling and 30-second inbox/badge polling, displayed-only read receipts, history/read-only/error states. Shared auth signal refreshes separate inbox scopes after read/send. Original account checked before/after I/O; POST never automatically replayed after auth refresh.
- Tests: Customer full suite 563 passed before four extra chat regressions; latest focused chat/accessibility suite 41 passed. Provider latest chat/widget/320-430px suite 12 passed. Both analyses clean. Both debug APK builds succeeded. No emulator install or live chat send/read performed.
- Provider broad suite was also run: 785 passed, 42 failed at that point (includes two old placeholder expectations subsequently adapted and now passing). Remaining startup timing and golden/snapshot failures were not resolved or baselined by this task; do not claim full Provider suite green. Logs build/provider-chat-full-tests.log and build/provider-startup-alone.log; latest passing focus build/provider-chat-focus.log.
- Docs: docs/customer-booking-chat.md, docs/provider-booking-chat.md. Pending backend: explicit availability fields, machine error codes and immutable ended-chat deadline; actual push delivery still unreliable per backend doc. Manual E2E on the same confirmed booking remains required.


### 2026-11-22 - Start-code and chat entry availability
- Start-code card fails closed when scheduled instant is unknown; it appears only from scheduled start minus 30 minutes for eligible paid/confirmed bookings. Existing local timer reveals the card at the boundary without per-second API traffic.
- Booking provider section checks chat canSend/sendUntil via a safe GET (no read receipt), hides message buttons until available, and schedules local hiding at the deadline. Rechecks on status/job changes and foreground resume. Embedded chat reports availability changes back to the underlying booking section, hiding its entry after unavailable/read-only response. Other provider details/call action remain independent.
- Validation: 55 focused start-code/provider/chat/accessibility/lab tests passed, analysis clean. New boundaries: 31 minutes hidden, exactly 30 shown, unknown time hidden, canSend false and expired deadline hide entry; availability callback recovers on successful retry.
- No live messages/receipts or APK install in this revision. Running flutter session needs hot restart (R).


### 2026-11-22 - Customer chat half-height sheet
- Booking chat popup now caps content at 50% screen height, with keyboard/drag-handle clearance. It does not expand fullscreen while typing.
- Reduced compact header/composer spacing to fit 320px/2x text with keyboard; preserves message scrolling and actual read-receipt viewport.
- Chat widget/accessibility tests: 31 passed, including explicit half-height assertion and keyboard send-button visibility. Provider chat UI unchanged.


### 2026-11-22 - Customer message ticks
- Server-acknowledged own messages show one grey tick (Sent). Own IDs at/below othersLastReadMessageId show two blue ticks (Seen), including restored history. No tick on unsent drafts.
- Delivered state is absent from current backend contract, so no false delivered indicator is shown. Explained backend support needed for separate grey double-tick delivery state.
- Customer chat widget tests: 5 passed including explicit icon/colour/state check; analysis clean.

### 2026-11-22 - Consolidated development PR preparation
- Recreated the seven PR #6 commits on origin/development in .worktrees/customer-development-pr (feature/customer-development-review), then added the complete source snapshot in focused Customer, Provider chat and tooling commits. Original main worktree changes remain intact.
- Excluded tracked historical temporary PDF tools and generated test failure images from the new history. No local configuration, credentials or build output included; proposed source scan found no private keys/tokens.
- Fresh review-branch checks: Customer 573 passed; Provider 790 passed/40 failed; isolated development comparison 779 passed/the exact same 40 failures (no new failure names). Baseline needed a valid Customer manifest for dependency resolution because development contains duplicate YAML keys. Shared design system 24 passed; helper 30 passed; both app analyses clean.
- See docs/customer-development-integration-validation.md for scope, limitations and Provider failure names. The new PR supersedes #6 and targets development; do not merge automatically.
