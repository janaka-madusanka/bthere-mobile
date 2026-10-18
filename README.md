# B there Mobile

A Flutter monorepo containing the B there Customer and Service Provider mobile
applications and shared mobile packages.

## Structure

```text
apps/
  customer_app/
  provider_app/
packages/
  bthere_design_system/
  bthere_network/
  bthere_session/
  bthere_auth/
  bthere_common/
docs/
```

Customer and Provider are separate Android/iOS applications. Customer-specific
and Provider-specific business features stay inside their respective apps.
Genuinely shared infrastructure belongs in `packages/`. Common result/failure
primitives, secure session persistence, REST transport, confirmed Provider
authentication, Provider bootstrap/email registration UI, and the shared Design
System are implemented. Customer remains a scaffold. Provider uses Riverpod/
go_router and reads BTHERE_API_BASE_URL from --dart-define; see the foundation
document for launch configuration.
Their responsibilities are documented in
[repository structure](docs/repository-structure.md).
See [mobile architecture](docs/mobile-architecture.md) for dependency boundaries,
future feature organization, and backend/local data ownership rules.
See the [foundation technology plan](docs/foundation-technology-stack.md) for
planned dependency ownership and currently implemented foundation components.

## Workspace commands

The repository uses Dart Pub Workspaces with one root lockfile and shared
dependency resolution. Run commands from the workspace root where supported:

```sh
dart pub get
dart pub workspace list
flutter analyze --no-pub apps/customer_app
flutter analyze --no-pub apps/provider_app
flutter analyze --no-pub packages
```

Use the Flutter installation's Dart SDK (currently Flutter 3.47.6 / Dart 3.13.5).
Keep the root `pubspec.lock` in version control. Commands targeting an app,
such as `flutter run`, should run from that app's directory; workspace dependency
resolution remains shared.

## Running Provider against a local backend on Android

Start the backend first, then run `adb devices -l` to get the device ID.
From the repository root in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-provider-local.ps1 -DeviceId '<device-id>' -Port 8080
```

This checks that the local server is listening, forwards the phone's port to
the PC with ADB reverse, and launches with `http://127.0.0.1:8080/api/v1`.
Keep the ADB connection active; rerun the script after reconnecting the device.
`10.0.2.2` only addresses the host PC from an Android emulator, not a physical phone.
For a remote backend, launch from `apps/provider_app` with
`flutter run --dart-define=BTHERE_API_BASE_URL=https://<your-api-host>/api/v1`.
Changing this define requires restarting Flutter, not hot reload.
Debug builds print HTTP method, endpoint, status, and failure type in the Flutter
terminal without request bodies, headers, or query strings.
