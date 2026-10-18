# Provider service locations and Google Maps

The Step 2 subservice editor follows Figma frame `216:2902`. Experience and
additional fields use the selected option's onboarding schema. No service names,
answers, supported modes, locations, or radius values are populated with samples
in application code. Design fixtures exist only in tests.

## Configure the Maps key

Replace the sample `BTHERE_GOOGLE_MAPS_API_KEY` in `config/provider.local.json`
with your Google Maps key. This file is ignored by Git. The committed
`config/provider.example.json` provides the same configuration format.

From `apps/provider_app`, run:

```powershell
flutter run --dart-define-from-file=../../config/provider.local.json
```

The same flag works with `flutter build apk`. Android decodes Flutter build
defines into `com.google.android.geo.API_KEY`; iOS reads the encoded build defines
from Info.plist and passes the Maps key to `GMSServices.provideAPIKey`. Enable
Maps SDK for Android and/or Maps SDK for iOS for the intended target. Use the
appropriate app restrictions for the native key. Platform setup follows
[Google's Flutter setup guide](https://developers.google.com/maps/flutter-package/config).

The sample key is a placeholder. Live map tiles need a valid configured key.
Android and iOS are supported; the provider app does not currently target web.

After changing the JSON key, fully stop and rebuild the app with the command
above. Hot reload and hot restart do not rebuild the native Android/iOS Maps
configuration. The local VS Code launch profile `Provider (local config)` includes
this file automatically; choose an Android or iOS target. A plain `flutter run`
does not automatically read this JSON file.

If the map opens but tiles are blank, inspect Android logcat for
`Google Android Maps SDK: Authorization failure`. Confirm Maps SDK for Android
is enabled and billing is active in the key's Google Cloud project. Android
application restrictions must allow package `com.bthere.provider` and the
certificate fingerprint for the installed build. Debug and release signing
certificates can differ. The debug fingerprint can be read locally with:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE/.android/debug.keystore" -storepass android
```

See [Google's Maps SDK setup guide](https://developers.google.com/maps/documentation/android-sdk/get-api-key).
Never paste the Maps key into issue reports or logs.

## Location behavior and API contract

Select Location opens a searchable Google map. The provider can search an address,
tap the map, drag the pin, and set a positive radius. The map displays a coverage
circle and adjusts zoom to the radius. Address search and reverse lookup use the
[geocoding plugin's native platform service](https://pub.dev/packages/geocoding),
separately from the Maps SDK. They do not send the provider's access token to
Google. If address lookup fails, the selected pin remains available with an optional
display name. Coordinates and country/province/district fields stay internal;
users never have to enter or view them. Search remains usable when map rendering
is unavailable.

For a new location the picker requests foreground device-location permission and
uses the current position as its initial pin, resolving its address automatically.
It does not replace an existing saved pin. Use my current location can recenter
the picker explicitly. Denied access, disabled GPS, and timeouts leave search and
pin selection available; permanently denied access offers Open Settings. A late
GPS response cannot replace a newer search or manual pin selection. No background
location permission or continuous tracking is used. This follows the
[geolocator setup and permission flow](https://pub.dev/packages/geolocator).

The picker and coverage overview use the registration theme, white panels, teal
controls, and fixed bottom confirmation buttons. Travel distance offers quick
choices and custom entry only when the provider visits customers. View in Map
shows saved locations, coverage circles, a selectable address list, and Show all
locations. Viewing coverage does not request device location or change saved data.

The inline + action adds the selected location to the draft list. Pending selections
must be added before saving the subservice. Existing locations can be edited or
removed. View in Map shows saved area markers and coverage circles.

On Step 2 Continue, the existing registration flow selects options first, then
uses authenticated PUT
`/providers/me/services/{assignmentId}/options/{optionId}/delivery-modes/{deliveryMode}/service-areas`
with a direct array. Coordinates come from the selected pin; provider-to-customer
areas require a positive radius. Customer-to-provider locations send `radiusKm: null`.
Online services skip locations. Existing location reads keep using the matching
assignment, option, and supported mode.

An existing main-service assignment does not mean every locally selected option
has been registered. Saved-location reads run only for options returned by the
registered-options API. A newly selected option starts with its local location
draft and does not issue a premature service-areas GET (which the server rejects
with HTTP 400). Step 2 Continue saves the option selection before location PUTs.
Failed reads for genuinely registered options still block replacement to protect
their saved locations.

Weekly availability remains assignment-scoped. Weekday edits preserve existing
per-day start/end times; explicit time-setting changes apply the chosen times.
The info action opens advanced availability settings and unavailable dates.

## Verification

Widget tests inject a map surface and geocoder to verify search, pin selection,
stale-reply handling, radius conversion, and coordinate payloads without live Maps
requests. A separate editor test verifies weekday changes preserve other days'
times. Visual fixtures cover the updated subservice form. A placeholder key cannot
verify live map authorization, billing, or actual address-service availability.
