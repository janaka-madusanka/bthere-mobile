# Provider service registration

The registration flow follows Figma frames `129:1082`, `216:2628`, `216:2902`,
`236:1508`, `119:1888`, and `129:1235` in the Bthere design. Screens use bundled
Figma SVGs and local fonts, a five-step progress indicator, scrollable forms,
editable review rows, and the operating system's status/navigation bars.

## Flow and API contract

The current contract is **Complete Provider Registration and Service Approval API Flow (1).pdf**, updated 15 October 2026.
The earlier Super Admin PDF is configuration reference, never provider mutation
authority. All API paths below are relative to the configured `/api/v1` base URL.

- `/services/register` selects one or more main services. Existing
  `/services/{serviceTypeId}/register` links preselect that service. Multiple main
  services are registered sequentially using individual POSTs; the destructive
  replacement PUT for all assignments is deliberately unnecessary.
- Service details load both the onboarding schema and the public
  `/provider-types/{serviceTypeId}/options` catalog before selection, plus the
  existing assignment/options.
  New assignments use POST `/providers/me/service-types`. Sub-services use
  PUT `/providers/me/services/{assignmentId}/options` with `optionIds`.
- Languages use GET/PUT `languages`, with ENGLISH, SINHALA, and TAMIL only.
  Step 2 compares fresh saved languages before replacing them. Unchanged sets
  are not resent. An uncertain failed write is accepted only after GET confirms
  the exact requested set. See [the backend language-save handoff](backend-language-save-failure.md).
  Saved languages preselect the Step 2 picker after asynchronous loading. Empty
  defaults and clean old drafts cannot override the saved list. Explicit pending
  language edits remain local until a successful Step 2 save; the language sheet
  also supports shorter screens with scrolling.
  Skills use GET/PUT `skills` with catalog `skillIds`.
- Weekly availability uses GET/PUT `availability`, shared across the assignment.
  Existing per-day times survive edits to unrelated option information.
  Unavailable dates use GET/POST `unavailable-dates` and DELETE by its returned ID.
- Physical locations use GET/PUT
  `options/{optionId}/delivery-modes/{deliveryMode}/service-areas`. PUT sends a
  direct array. Coordinates are mandatory; provider visits require a positive
  radius, customer visits send a null radius, and online services omit areas.
  Saved locations can be loaded for a selected delivery mode. Google Maps now
  supports address search, pin selection, and radius previews; see
  [Maps setup](provider-google-maps.md). Address/coordinate entry remains available.
- Shared document requirements, upload, registration, replacement, and deletion
  reuse the existing document repository/controller. Uploads accept PDF,
  JPG/JPEG, PNG, and WebP up to the documented **100 MB** limit, rather than the
  older 5 MB design copy. Uploaded keys, never `s3://` URLs, are submitted.
  Recent image uploads have bounded, session-scoped in-memory previews. Existing
  private files use GET `/uploads/view-url?key=...`; its signed URL is used only
  for viewing and expires after ten minutes. Requirements with `optionId` apply
  only when that option is selected, while common requirements use `optionId: null`.
- Certificates and education upload supporting files first, then POST their
  documented metadata. Existing records show server review state. No unsupported
  update/delete operations are offered. A retry checks the uploaded key against
  existing records before creating another record.
- Dynamic common fields always appear; option fields appear only for selected
  options. Text, textarea, number, boolean, date/time, phone/email, select,
  multiselect, and file controls retain JSON types. Requiredness, file count,
  size, and type constraints are applied. EQUALS/NOT_EQUALS conditions support
  field IDs or codes. Unrecognized condition/option structures fail visibly;
  they are never silently submitted as satisfied. `optionIds` fields shared by
  several options are displayed and submitted once. `reuseScope` is retained;
  inherited approved answers returned with `reused: true` remain inherited until
  the provider changes them. File answers always use `{"files":[{"key":"..."}]}`.
- Structured service `icon`, `coverImage`, `gallery`, and `responsibilities`
  are parsed from provider-type responses and displayed when supplied. Legacy
  `iconUrl` and bundled Figma artwork remain safe fallbacks.
- Step 2 Continue persists requirement replacements; document and qualification
  editors persist their records in step 3. **Submit for Review** re-reads saved
  requirements and documents, validates required uploads, and refreshes
  `/providers/me/completion` and `/providers/me/service-types`. There is no
  invented submit-application endpoint. Pending approval is permitted after
  successful data submission; required location/availability setup must be
  confirmed by completion. Approved/effective-active status remains server owned.
  The final review does not replay PUTs for saved languages, skills, availability,
  areas, or field answers. A failed refresh leaves review open for a safe retry.

Form drafts use encrypted storage, isolated by account and service. Idempotent
replacement requests retain draft data on failure. The assignment creation
preflight recovers an existing assignment before retrying, preventing duplicates.

## Existing pages checked and updated

Email registration, verification/login, markets, profile PUT, schema, assignment,
option, completion, and document request shapes match the new document. Profile
and Basic Details now load GET `/providers/me/profile`, prefill saved values, and
preserve optional NIC/passport/photo values on edits. Account details can open
that editor. Sign-out calls POST `/auth/logout` with the refresh token before
local clearing; local sign-out remains available if the server is unreachable.
Expired sessions use `/auth/refresh`, persist both rotated tokens, and share
concurrent refresh requests. A late refresh cannot resurrect a signed-out account.

Existing setup links for skills, availability, locations, additional information,
certificates, education, and documents now open the functional registration forms.

## Verification

Contract tests use synthetic HTTP transport; UI tests render all six screens and
exercise retries, navigation through completion, and 320px layouts at normal and
enlarged text sizes. No live provider registration or production-data mutation
is performed by the tests. Live end-to-end behavior still depends on the server's
configured service schema, delivery modes, and review state.

## Registration corrections (16 October 2026)

Rechecked the supplied API PDF and all six registration Figma frames. Public
option descriptions and supported delivery modes now survive schema loading and
reach the option editor. The editor limits delivery choices to the configured
modes; draft validation also rejects unsupported modes before sending requests.
Older responses without delivery-mode metadata retain the existing choices.

The option editor places Experience first, then Service Location & Area, Weekly
Availability, and Additional Information, matching the supplied screen sequence.
Weekday toggles stay visible for every-day availability. Additional scheduling
controls remain available under Availability settings. Dynamic field values and
field IDs are preserved across these presentation changes.

### Step 2 UI update

The Service Details overview now uses compact API-driven skill rows, a selected
option count, descriptions and icons from the public options response, and
independent progress for experience, skills, locations, and dynamic information.
A saved editor flag cannot mark unanswered sections complete. Skills remain
assignment-scoped as specified by the API; the UI does not fabricate per-option
skill totals. New selections retain skill IDs, including duplicate display names;
legacy drafts using names remain readable. Saved locations load using the
assignment, selected option, and supported delivery mode before showing progress.
Change returns to registration service selection. Common schema fields and the
required numeric assignment experience remain available when applicable; no
sample services, skills, answers, or selection counts are inserted in production.


## Dynamic option configuration (20 October 2026)

The supplied Complete Service Configuration APIs ? V1 document is configuration
reference only; no admin endpoints are called by registration. Existing provider
schema and public-option responses retain `locationEnabled`, `defaultCapacity`,
and `bookingMode`. Option location controls, validation, saving, summaries, and
profile editing respect both the service and option location flags. Older
responses without the option flag retain existing behavior.

Fixed customer-visit locations support a positive integer capacity override,
prefilled from the option default for new locations. Coverage areas retain a
positive radius and null capacity; fixed locations retain a null radius. Capacity
is optional so the server can apply its configured default. Admin scheduling,
fulfillment, and pricing settings remain server configuration, not provider inputs.

Common conditional fields can read option answers, and option editors receive
the full selected field context. Select answers reject removed/invalid choices;
valid emails and calendar dates pass the corrected validators.


### Provider location UI correction

Delivery mode is service configuration, not a provider registration input. The
provider app has no delivery-mode selector or prompts to choose one. A single
configured mode is applied automatically, including overriding stale local
choices. Saved location context is retained for existing services. Missing or unsupported configuration is reported explicitly; multiple configured
modes are supported as independent location groups, without asking the provider
to select a delivery mode. The app does not invent missing configuration. The mode remains internal because section 12 of Complete
Provider Registration and Service Approval API Flow (2).pdf requires it in the
location API path. Online services require no physical locations.


### Service-independent rendering

Catalog, detail, registration, review, setup, and subservice profile screens use
service/option IDs and configuration. No caregiver, hospital, elderly, or other
service-name checks select artwork or form behavior. Supplied icons (including
SVG) and responsibilities render from API data; absent artwork uses neutral
icons, and absent responsibilities produce no empty panel.

Custom provider fields follow `displayOrder`, `scope`, `status`, conditions, and
selected option IDs. Labels containing ?experience? do not change field grouping
or validation. Assignment experience remains part of the existing provider API
contract. Public subservice `displayOrder` determines ordering. Disabled or
unconfigured skills, qualifications, locations, and descriptions do not appear
as missing review requirements. Deselected option drafts do not override active
answers. Purely online/location-disabled options do not create physical-location
setup rows. Tests cover caregiver, parking, charging, rides, and arbitrary names
with identical metadata, plus custom-field ordering and deselected drafts.


### Multiple location groups

The earlier single-mode resolver incorrectly treated a valid multi-mode option
as unavailable and restored only its first saved location group. Registration
now renders independent coverage and premises sections directly from all
configured modes. ONLINE needs no area. Multiple groups retain separate drafts,
load/retry state, radius/capacity rules, validation, and provider API writes.
`locationsByMode` stores local groups; the provider API still receives direct area
arrays at its existing documented per-option/per-mode paths. Legacy single-mode
drafts remain readable. Local edits merge by group so they cannot erase another
saved location group. Failed location reads must be retried successfully before
replacement. No service-name rules, admin calls, or provider mode selector are
introduced.

The live catalog is authenticated (unauthenticated reads return 401). The PDFs
confirm the API contract but cannot identify the deployed option values. If an
option has no supported mode in either the schema or public-option response,
its redacted responses are needed to distinguish missing backend metadata from
an unhandled response shape; the app never guesses a radius or location type.
