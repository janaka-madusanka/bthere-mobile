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
