> Current navigation is service-first. The routes and sequencing below are historical; their reusable repositories/models remain preserved. See [Provider service-first architecture](provider-service-first.md) for the current Services → sub-services/experience → assignment/options → selected-service setup flow.

# Provider Complete Profile

`/onboarding/profile` is now a real first-time onboarding form. Its route and the
six backend nextStep mappings remain unchanged. Profile submission lives in `features/onboarding/profile`; market loading lives
in `features/onboarding/markets`. Both belong to the Provider app, separately from shared Auth:

presentation -> Riverpod profile controller -> profile repository -> remote data
source -> existing authenticated ApiClient/session token bridge.

## Request contract

PUT /providers/me/profile, requiresAuth true:

```json
{
  "firstName": "Jane",
  "lastName": "Doe",
  "nicNumber": null,
  "passportNumber": null,
  "dateOfBirth": "1990-02-03",
  "gender": "MALE",
  "profilePhoto": null,
  "bio": null,
  "availabilityStatus": "AVAILABLE",
  "marketId": 1
}
```

ProviderProfileInput is handwritten and immutable. Serialization contains exactly
these ten keys. Normal text is trimmed; empty optional bio becomes null.
NIC and passport are not editable inputs; both request keys always serialize as null. A nonempty bio is trimmed text with internal line breaks preserved.
The immutable model requires a positive marketId from the selected active market.
profilePhoto remains fixed to null. No upload code or image_picker dependency is added.

Success is acknowledged by successful HTTP status; no profile-update response
shape was supplied, so there is no invented response DTO. HTTP errors use the
existing NetworkException -> AppFailure infrastructure. Known validation failures
receive fixed readable guidance. The shared network layer deliberately removes
untrusted field text; raw errors, response headers and traces are never shown.
401 preserves the existing request-failure policy without deleting credentials.

## Form and validation

First name, last name, date of birth, gender, market and availability are required.
Names must be nonblank. NIC and passport controls, input-model properties and
identity validation have been removed. Identity/document collection belongs to
future service-specific verification requirements; no new document screen or upload
is implemented. Bio is optional and multiline with no undocumented counter/max length.
BThereTextField now supports minLines/maxLines with the existing single-line
default preserved.

Date of birth uses a calendar-only picker, with no editable text entry and no
future dates. The localized display includes the year. Serialization uses the
selected calendar components as YYYY-MM-DD, without converting time zones.
The calendar range starts at year 1; there is no minimum-age restriction.
Controller validation checks names, market eligibility and date safety too.

Availability choices are Available (AVAILABLE), Unavailable (UNAVAILABLE) and
Offline (OFFLINE). This first-time form defaults to Available because no existing
value has been supplied. Future edit/prefill flows should retain returned values.

The backend has confirmed the authoritative gender enum: MALE and FEMALE.
ProviderGender maps them to Male and Female while preserving exact uppercase
wire values. Both options are offered, with no default selection or additional
guessed values. See [confirmed gender support](provider-gender-values.md).

GET /providers/me/profile was considered but is not called: this is first-time
completion and neither a read-response shape nor new-provider not-found behavior
is specified. The form opens without blocking on a profile GET, and request failures
retain all locally entered values. This is not an existing-profile edit screen
and does not persist drafts across app restarts.

## Submission and completion

The auto-disposed Riverpod controller coordinates validation, blocks duplicates,
and exposes safe loading/failure state. Fields, selectors and Continue are
disabled while saving. Text controllers are disposed with the screen. Busy back
navigation is blocked; failures retain text, date and selections for retry.

After successful PUT, the controller calls the existing completion notifier's
reload method. The router enters the loading gateway and applies the new backend
nextStep. There is no hard-coded profile-to-market or profile-to-service navigation. Completion failures
stay on the existing safe gateway with Retry. Late profile results after controller
disposal cannot trigger refresh or affect another session.

The form reuses B there themes and controls: navy/teal, rounded inputs, centered
brand, a single Continue CTA, bounded width, SafeArea, scrolling and keyboard
insets. Light/dark and narrow large-text layouts are tested.

## Verification and backend concerns

Fake-only tests cover the exact authenticated PUT/token bridge, all ten request
keys, optional nulls, date padding/calendar semantics, availability enums, safe
HTTP/transport errors, acknowledged empty success responses, controller validation,
loading/duplicates/retry/disposal, form controls, date selection/cancellation,
state preservation and completion-driven routing to several destinations.
No automated live profile submissions are performed.

The current save implementation ignores the PUT success body; the GET profile
response schema and missing-profile behavior remain unconfirmed. The updated supplied live contract requires marketId in the profile
PUT; the earlier direction to omit it is superseded. The API returns a bare markets
array. All documented market text fields are required, IDs must be positive integers,
and duplicate IDs fail safely. ACTIVE is the only selectable status. No additional
market-status enum, paging wrapper or locally invented markets are assumed. Authentication, Provider role checks, session persistence/expiry,
registration/OTP and dormant Google implementation are unchanged.


## Market loading and selection

On profile entry the auto-disposed Riverpod market controller fetches authenticated
GET /markets via repository -> remote data source -> existing ApiClient. It uses
requiresAuth true and the existing token bridge, without manual token attachment.
The immutable ProviderMarket holds id, name, countryCode, currencyCode, timezone,
locale, phoneCode and status; timestamps are not needed by this UI. Parsing returns
an immutable list of only ACTIVE markets.

The Market selector appears between Gender and Availability. Labels come from the
backend; internal selection is an integer ID. No first-market selection is automatic,
even for one market. Long names fit the control with ellipsis and retain their full
semantic text. Markets can be reloaded without resetting profile inputs.

Loading shows a local indicator. Other form inputs remain usable while loading,
failed or empty. A safe error offers Retry markets, preserving names, date, gender,
availability and optional text. Empty data shows No markets are currently available.
Continue is disabled until an active market is selected. Profile controller checks
also reject loading, failed, empty, inactive or unlisted IDs before issuing PUT.
Refresh preserves a selection that remains active; a removed selection requires
another choice.

After profile success, the existing completion reload and six routing mappings
remain unchanged. SELECT_SERVICE is only an expected backend outcome, never a
hard-coded destination. SELECT_MARKET still maps to /onboarding/market, which remains
a placeholder for existing-profile edge cases.

Fake-only market tests cover all fields, positive/duplicate IDs, malformed/empty
responses, active filtering, authenticated GET/token bridge, HTTP/transport failures,
reload/duplicate prevention, guarded profile submission, multiple/single explicit
selection, exact selected IDs and profile preservation across retries. Existing
profile tests now include required marketId and select a fake API market explicitly.
Gateway tests retain the SELECT_MARKET destination and backend-driven success routes.


The simplified profile screen contains First name, Last name, Date of birth,
Gender, Market, Availability status, optional Bio and Continue, with no identity
controls or spare gaps. Tests assert absent NIC/passport fields, retained Bio and
Market, compatible null request keys, validation, retry preservation and the existing
completion-driven success flow. Authentication, market loading/selection, routing,
gender/availability and design system behavior are unchanged.
