# Provider service locations and Google Maps

The Step 2 subservice editor follows Figma frame `216:2902`. Experience and
additional fields use the selected option's onboarding schema. No service names, answers, supported modes, or locations are populated with samples
in application code. New provider-to-customer areas start with an editable 5 km
radius; existing saved radii are preserved. Design fixtures exist only in tests.

## Configure the Maps key

Replace the sample `BTHERE_GOOGLE_MAPS_API_KEY` in `config/provider.local.json`
with your Google Maps key. Change only the JSON value; do not replace strings
in `MainActivity.kt` or `AppConfig`. In particular, an availability check must not
compare against and reject your actual key. This file is ignored by Git. The committed
`config/provider.example.json` provides the same configuration format.

For a connected Android phone, launch from the workspace root with:

```powershell
.\scripts\run-provider.ps1 -DeviceId <device-id>
```

This launcher requires the local config and a Google-format Maps key; it never
silently launches without them. It uses the API URL in that file and does not
require a locally running backend. `run-provider-local.ps1` is the separate
launcher for a backend running on your computer.

Alternatively, from `apps/provider_app`, run:

```powershell
flutter run --dart-define-from-file=../../config/provider.local.json
```

The same flag works with `flutter build apk`. Android decodes Flutter build
defines into `com.google.android.geo.API_KEY`; iOS reads the encoded build defines
from Info.plist and passes the Maps key to `GMSServices.provideAPIKey`. Enable
Maps SDK for Android and/or Maps SDK for iOS for the intended target. Use the
appropriate app restrictions for the native key. Platform setup follows
[Google's Flutter setup guide](https://developers.google.com/maps/flutter-package/config).

The committed sample key is `YOUR_GOOGLE_MAPS_API_KEY`, a nonfunctional placeholder.
It is treated as unconfigured rather than opening an unauthorized native map.
Keep your existing sandbox key in the ignored local JSON.
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

The map starts over Sri Lanka and constrains its camera target to the Sri Lanka
envelope (5.8–9.9 N, 79.5–82.0 E), with a minimum zoom of 7. Search appends
Sri Lanka to unscoped queries, filters coordinates to that envelope, removes
duplicate results, and rejects addresses whose resolved country code is not LK.
Device locations and manual pins outside the envelope cannot be selected.
The envelope includes surrounding water; it is not a coastline polygon, and
when native reverse lookup is unavailable the envelope is the fallback check.
Search continues to use native geocoding and does not require a Places API key.

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
controls, and fixed bottom confirmation buttons. The compact map supports pan/pinch, tapping and pin dragging inside the scrolling
page. Travel radius offers 5/10/15/25/50 km choices, a slider in half-kilometre
steps, and exact custom decimal entry only when the provider visits customers.
The coverage circle and map zoom follow the selected radius. Custom values above
50 km expand the slider range; the slider is not a backend radius limit. View in Map
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

## Missing native key diagnosis

A Dart config change alone does not update the Android manifest in an already
installed APK. A build made without the local-config flag can have a working
API base URL but an empty `com.google.android.geo.API_KEY` entry. Rebuild and
install using the launcher above. Do not copy a real key into AndroidManifest.xml
or the committed example config. Keep both the Dart defines and native manifest
in the same build so that the picker and the Maps SDK use the same configuration.

## Blank tiles with Google authorization failure

If the Google logo/zoom controls render but tiles remain blank, check native
logs for `Google Android Maps SDK: Authorization failure`. This is distinct from
the app's missing-key fallback. Replacing Flutter UI or the geocoder does not
resolve a Google authorization rejection.

In the Google Cloud project that owns the key:

1. Enable **Maps SDK for Android** (`maps-android-backend.googleapis.com`).
   Enabling only Maps JavaScript API or Geocoding API is insufficient.
2. Under APIs & Services ? Credentials, open the key used by the local config.
3. If application restrictions are enabled, select Android apps and add the
   installed app's exact package name (`com.bthere.provider`) and signing SHA-1.
4. If API restrictions are enabled, allow Maps SDK for Android.
5. Confirm billing is active on that same project.
6. Save changes, allow time for propagation, then close and reopen the app.
   A native rebuild is required only if the key itself changed.

The installed debug build investigated on 18 October 2026 reported this SHA-1:
`61:7D:72:00:37:3A:04:5C:FE:A5:40:5B:4D:54:4E:29:F5:85:50:F7`.
This fingerprint is machine/build specific; obtain it again for another signing
key or a release build. Google logs report the package/fingerprint pair expected
for the current installation. Never copy the API key line into diagnostics.

[Official Android SDK setup](https://developers.google.com/maps/documentation/android-sdk/start)

## Android debug-launch fallback

Android debug builds now read `BTHERE_GOOGLE_MAPS_API_KEY` from the ignored
`config/provider.local.json` if no Maps key build define was supplied. An explicit
Maps define takes precedence. Release builds continue to require explicit defines.
The app queries a native method channel for whether the installed manifest has a
key, so a debug build with native configuration does not show the missing-key
fallback merely because the Dart key define was omitted. The channel returns only
a boolean and never returns or logs the API key. This does not bypass Google's
SDK enablement, application restrictions, API restrictions, or billing checks.
