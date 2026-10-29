# Customer build configuration

Customer environment values are supplied by a JSON file using Flutter's
`--dart-define-from-file`. Existing `String.fromEnvironment` readers consume these
values at compile time; no runtime file download or dotenv dependency is needed.

## Local setup

`config/customer.local.json` is the local working configuration and is ignored by
Git. For a fresh checkout, copy `config/customer.example.json` to that path and
edit its values. Do not put private server credentials in a mobile configuration:
values can be extracted from the built application.

| Setting | Purpose |
| --- | --- |
| `BTHERE_API_BASE_URL` | Backend URL including `/api/v1`; release requires HTTPS |
| `BTHERE_GOOGLE_MAPS_API_KEY` | Mobile SDK key for Google Maps and native Google Places search |

All Customer map views now use Google Maps on Android/iOS: booking location/time,
Service Details, service/destination pin selection and provider result markers.
OpenStreetMap tiles and Photon search are removed. Search uses native Google
Places autocomplete, then fetches coordinates only for the selected suggestion.
Market country restrictions are retained. No direct mobile REST request or
separate server key is used.

Enable Maps SDK for Android in your Google Cloud project and restrict the Android
key to `com.bthere.customer` plus the appropriate debug/release signing SHA-1.
For iOS, use a separately iOS-restricted key with Maps SDK for iOS enabled and
the Customer bundle ID. Supply that key in the same JSON field for iOS builds.
Google Cloud billing must be enabled. The Google logo/legal attribution are
provided by the native SDK; the booking panel resizes the map's visible area.
Web/desktop Maps setup is not included in this mobile integration.

## Run from repository root

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-customer.ps1
```

Optional: `-DeviceId '<device-id>'` or `-ConfigFile 'config/customer.staging.local.json'`.
Explicit relative configuration paths resolve from the caller's working directory;
the default path resolves from the script's location.

## Direct Flutter run and release builds

From `apps/customer_app`:

```powershell
flutter run --dart-define-from-file=../../config/customer.local.json
flutter build apk --release --dart-define-from-file=../../config/customer.local.json
flutter build appbundle --release --dart-define-from-file=../../config/customer.local.json
```

Use a separate ignored `customer.production.local.json` file for production and
pass that filename to the same commands. CI can create this JSON file from its
environment settings before building; do not commit deployment credentials.
Configure production signing before distributing Android release artifacts.
For iOS, build on macOS with the same define-file argument and appropriate signing.

Changes require stopping and restarting `flutter run`, or rebuilding a release;
hot reload does not replace compile-time configuration. Changing the backend host
later does not update already-installed builds. Native Customer builds are
distributed as mobile apps; the backend is hosted separately.


## Google Places search

Enable **Places API (New)** in the Google Cloud project, and allow it in the
mobile key's API restrictions alongside Maps SDK for Android. Existing package
name and signing SHA-1 restrictions remain. An app restart is required after
adding the native plugin. Successful map rendering does not prove Places access.

Search runs on submit. Suggestions stay in memory until selection or query change;
only selection fetches place ID, address and coordinates. Details use the search
session token. No Google prediction/detail cache or query logging is implemented.
The existing booking draft retains the user-selected address/coordinates.

The UI shows the SDK-bundled Google attribution plus returned place credits.
Failed queries/details remain retryable; map and current-location selection stay
available. Late results cannot override a new query or manually selected pin.

The compatible plugin pair is pinned to flutter_google_places_sdk 0.4.2 and
flutter_google_places_sdk_android 0.2.1 (Android Places SDK 3.5). Android 0.2.2
has upstream compile errors with Places 5.x; do not upgrade that pair without
rechecking native builds. The iOS plugin uses Places SDK 8.x. iOS uses
the plugin's legacy native autocomplete implementation; verify API enablement and
SDK compatibility when building on macOS. This Windows workstation cannot verify
the iOS build. Web/desktop Places integrations are not enabled in the adapter.
