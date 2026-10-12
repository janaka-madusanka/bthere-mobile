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
