# Customer market selection and Home catalog

Contract: supplied Customer API reference sections 16–17 and access/media schema.
No live-account mutations, guessed market IDs or production fixture services.

## Entry and market selection

Existing authenticated profile GET and verification-success gates remain.
New profile save or a completed-profile authenticated entry goes to /market.
Continue commits the selected market and opens /home. Profile/account routes
remain available for editing and sign-out. Confirmed selection is stored securely
on this device per account ID and API environment. Startup validates the saved ID
against the current ACTIVE /markets list, restores it, loads its services and goes
directly to Home. Market-loading uses a startup loader instead of flashing the
selection screen. New accounts without a saved choice, removed/inactive market
IDs or malformed stored IDs require selection. Unknown storage/network failures
remain retryable errors. Home can change the choice; Continue awaits persistence
before committing the active market or navigating. Failed saves remain on the
selector with an error and retry. Selection controls are disabled during saving.

Logout/account changes clear in-memory discovery state, while the device-local
preference remains isolated under its original account/environment key. Late
read/write/service responses cannot activate a market for a signed-out or different
account. Only the ID is persisted; current names/currency/timezone come from the
backend, and no undocumented market-selection PUT is invented. Reinstallation,
cleared secure storage or another device requires selection again.

Authenticated GET /api/v1/markets has no body/query. Only ACTIVE results are
offered. One market selects itself with no dropdown interaction; Continue is
explicit. Multiple markets expose a dropdown. A unique exact match of the saved
profile country to market name/countryCode is a labeled suggestion. An ambiguous
or absent match requires manual selection, with Continue disabled until chosen.
Device locale is never treated as location. No GPS permissions are requested.

There is no customer PUT market-selection API. The app retains the returned
market ID/object; it does not modify SessionUser.marketId or profile fields.
Home can reopen the selector. A new selection clears stale services on Continue;
late responses cannot overwrite another market or restore state after logout.

## Home and expandable service catalog

The Home layout follows the supplied teal-header/footer reference: profile
shortcut, saved-city/market selector, a tappable Find the right help banner,
pastel Explore Services tiles, and five navigation items. The original supplied
brand asset retains its colors and aspect ratio. The bee illustration is a
code-rendered decorative vector, not an extracted asset from the reference.

Authenticated GET /api/v1/customers/me/services?marketId=<selected returned id>
returns the raw array. Home shows up to eight real services; View all, the hero,
and Services navigation open /services with the full catalog. A Home service tile
opens /services?service=<returned service.id> and expands that category. Catalog
search filters returned service names/descriptions. One category opens at a time;
tapping it again collapses it. Back returns to Home. Both screens support refresh.

Opening a category lazily requests authenticated GET
/api/v1/customers/me/services/<service.id>/options?marketId=<selected market.id>.
Options are the documented raw OptionCard array. Parse optionId, serviceTypeId,
name, optional description/media, displayOrder and the option's own access object.
Only ACTIVE options render, ordered by displayOrder then ID. Invalid parents,
duplicate IDs and malformed/wrapped responses are errors. Option eligibility is
independent of the parent service badge; restricted options remain visible.

Loaded options are cached for the current catalog. Duplicate concurrent fetches
are avoided. Refresh, market switch, logout or account change clears this state;
late responses cannot repopulate another market/account. Loading, error/retry and
empty sub-service states are distinct. A sub-service opens its description and
eligibility reasons. Continue opens the backend-driven booking journey documented
in [customer-booking.md](customer-booking.md); discovery itself does not create bookings.

Category icons prefer actual backend icons, without recoloring/distortion;
missing/broken media gets a presentation icon. Badges distinguish ELIGIBLE,
CHECK_OPTION, NEEDS_DETAILS, PENDING_REVIEW, REJECTED, RESTRICTED and unknown states.
No fake catalog categories, customer names, locations, bookings, prices or paid
statuses from the reference are inserted into production. The profile avatar
loads only its returned server URL, with a neutral failure placeholder.

## Available data and remaining work

Markets provide ID/name/country/currency/timezone. The saved profile city appears
in the location shortcut only when the selected market matches its saved country;
otherwise the selected market name appears. GPS-to-market selection still lacks
a documented resolver/boundary contract. The selector remains manual with the
existing unique saved-country suggestion.

Notifications and Messages have no implemented customer UI/data flow here.
Bookings opens server booking history; Recent Services shows its first three
returned records or a real empty/error state. Messages and recurring services
remain unavailable. No invented sample history is displayed. Booking context,
requirements, provider search and supported booking payments are implemented;
full wallet management remains a later milestone. A deployed services HTTP 500 or
media URL HTTP 403 remains a real backend/media failure rather than fake content.

## Validation

Discovery tests cover authenticated paths/query, independent option eligibility,
ordering, malformed responses, invalid parent/duplicate IDs, retry, collapse and
cache reuse, selected-category navigation, full-list entry, market-switch/logout
races, and narrow large-text layouts, alongside existing market/auth/profile tests.

Run the synthetic-data visual preview from apps/customer_app:

```powershell
flutter test tool/auth_preview_test.dart --dart-define=FLUTTER_SDK=C:/Users/hjana/develop/flutter
```

It exports build/auth-previews/customer-home.png and
build/auth-previews/customer-services-expanded.png with the shipped Nunito font
and original branding. Preview fixtures are not production service data.

### Verification for this UI milestone

- Customer: 109 tests passed, including 12 new option/catalog tests.
- Shared packages: all 244 tests passed (23 design system, 48 network,
  13 session, 157 auth, 3 common).
- Provider: 657 passed and 28 failed, including loader expectations,
  pumpAndSettle timeouts and golden comparisons. No Provider/shared application
  source was modified for this Customer milestone. Golden failure images were
  retained under ignored build/home-ui-verification/provider-goldens.
- Analysis: Customer and all five shared members clean. Provider reports the
  existing withOpacity deprecation in service_catalog_visuals.dart:39.
- Formatting: all 34 Customer Dart source/test/tool files unchanged by check;
  git diff --check clean.
- Customer configured debug APK built successfully. Synthetic UI previews passed.

These results do not claim that the entire workspace is green or that deployed
API/media availability has been fixed. No commit, push or PR was performed.

### Market persistence follow-up

Eight new persistence tests cover account/environment isolation, invalid stored
IDs, active-market restoration, inactive-market rejection, storage read/write
failures, logout during saving, and a full widget restart/change/restart journey.
All 117 Customer tests pass. Customer analysis and formatting are clean.
