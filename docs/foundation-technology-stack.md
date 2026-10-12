# Foundation technology stack plan

This is the approved planned stack. Common Result/AppFailure primitives, secure
session persistence, REST transport, and confirmed Provider authentication are
implemented. Session alone declares
`flutter_secure_storage` (^11.2.0); Network alone declares Dio (^5.11.1).
Provider bootstrap now composes these packages with flutter_riverpod 3.4.3 and
go_router 18.0.2 and consumes the shared Design System. Other technologies remain planned.

## Classification and ownership

| Package/app | Classification | Planned responsibility and dependencies |
| --- | --- | --- |
| `bthere_common` | Pure Dart | Common value types and generic application errors/result types where appropriate. No Flutter, UI, storage implementation, or higher-level dependencies. |
| `bthere_network` | Pure Dart | Dio, transport-level errors, interceptors, request/response infrastructure. No Riverpod unless a compelling later reason is established. |
| `bthere_session` | Flutter-capable | `flutter_secure_storage`, session abstraction, and token persistence. |
| `bthere_auth` | Flutter-capable through Session | Shared auth repository/domain logic and auth API DTOs/models. Depends on Common, Network, and Session. No auth screens or Provider onboarding. |
| `bthere_design_system` | Flutter | Theme/widgets, visual tokens, and Nunito/font integration. No networking/auth/session dependencies. Verified local Nunito assets remain pending. |
| `customer_app` | Flutter app | Riverpod, `go_router`, Customer state/features, and application composition. |
| `provider_app` | Flutter app | Riverpod, `go_router`, Provider state/features, and application composition. |

Current workspace edges remain Session → Common, Network → Common, and
Auth → Common/Network/Session. Apps will add shared dependencies only as needed.
Common exports Result/Success/Failure and AppFailure; Network implements typed
REST transport. Neither declares Flutter SDK dependencies.
Auth stays Flutter-capable to keep its future secure-storage dependency chain
practical, while remaining free of UI.

## Planned stack

| Concern | Planned technology and ownership |
| --- | --- |
| State management/dependency wiring | Riverpod in each app. |
| Routing | `go_router` in each app. |
| REST transport | Dio in Network. |
| Immutable/JSON models | Freezed and `json_serializable` in whichever package or app feature owns the models. Select compatible annotations and generator tooling together later. |
| Sensitive session storage | `flutter_secure_storage` in Session. |
| Small non-sensitive preferences | `shared_preferences` in app-local settings/persistence; share only genuinely reusable infrastructure. |
| Structured cache | Drift + SQLite; database ownership remains to be decided by cached domain. |
| Testing | `flutter_test` for Flutter apps/packages, `package:test` for pure Dart packages. Mocking/fakes only where useful. |

Do not put one global database blindly in Common. Drift ownership will depend
on which cached domains are genuinely shared and which are app-specific.
App-specific schemas belong with their app; a shared cache package requires
demonstrated reusable needs. No database, tables, SQLite runtime, or generator
setup is created now.

## State management rule

Riverpod is NOT the architecture. It supplies dependency injection, state
exposure, asynchronous UI state, and application composition. Business/data flow
remains:

```text
Presentation → ViewModel/Controller → Repository → Remote/Local Data Source
```

Do not put raw Dio calls directly inside Riverpod UI providers. Controllers use
repositories; data sources own transport/persistence details.

## Persistence rules

| Category | Intended contents |
| --- | --- |
| Secure storage | Access token, refresh token, sensitive session metadata. |
| Preferences | Theme mode, locale, small non-sensitive user preferences. |
| Structured cache | Markets, service types, onboarding schema, safe profile/service summaries where useful. |

The backend remains authoritative for Provider verification, active service
assignment state, jobs/bookings, payments, earnings, approval state, and
operational marketplace state. Account state and availability configuration also
remain backend-owned. Local persistence must not become independent business truth.

Never persist passwords, OTP codes, full third-party secrets, temporary signed
URLs, or unnecessary precise location history by default. Required access/refresh
tokens belong only in designated secure session storage, not preferences,
caches, logs, or persisted raw API responses.

## Initial data strategy

READ: cache-first where appropriate, followed by remote refresh. Show appropriate
freshness expectations and reconcile with backend state. Current active jobs/
bookings must be revalidated after restart/reconnect, not inferred from a locally
remembered screen.

WRITE: online-first. If a write fails, do not pretend it succeeded. Preserve user
input/state where appropriate and show retry/error. No offline mutation queues
or conflict resolution will be implemented in the v1 foundation.

## Before foundation installation

Verify compatible package versions, runtime/generator combinations, plugin
platform requirements, and concrete font/cache ownership during the next setup.
No future foundation versions are pinned by this plan. No
Freezed, `json_serializable`, `build_runner`,
`shared_preferences`, Drift, or SQLite dependencies are installed here.

## Implemented secure session foundation

AuthSession stores only accessToken, refreshToken, tokenType, and UTC expiresAt.
Expiry is evaluated against a caller-supplied time, with expiry at the boundary.
Expired credentials can be read; callers decide whether/how to restore them.
SessionStorage exposes read/write/clear. SecureSessionStorage persists the four
fields as one complete JSON value under a private namespaced key, avoiding
multi-key partial credential sets. Missing, malformed, or incomplete records
return null without destructive cleanup. Driver access/write/clear failures
propagate; a failed write does not indicate persistence succeeded. Calls on one
key are individual operations, not a multi-operation transaction; application
composition must coordinate competing credential replacement/clear operations.

FlutterSecureKeyValueStore wraps the plugin; serialization depends only on the
small SecureKeyValueStore interface. Tests use an in-memory fake without platform
channels. Construct dependencies in app composition, with Flutter bindings
initialized before invoking the plugin. No singleton or redundant manager exists.

Secure storage is authoritative only for persisted credentials, never business
state. No passwords or OTPs are persisted. Callers must never log tokens, serialized
credentials, or unsanitized plugin failures. Session does not perform HTTP refresh,
login, logout requests, role decisions, or navigation. Clear deletes only the
owned credential record, never unrelated secure data.

Provider now consumes Session. Its Flutter Android minimum API 24 already meets
the plugin's API 23 minimum; Provider Android backup is disabled as documented by
flutter_secure_storage 11.2.0. Customer remains unwired. The Darwin implementation
documents Keychain Sharing entitlements; iOS plugin integration/provisioning is
not verified in this Android bootstrap task. iOS builds cannot be validated on
this Windows machine.

## Implemented REST foundation

Dio 5.11.1 lives only in pure Dart Network. NetworkConfig receives the final
HTTP(S) base URL from composition; it reads no environment variables. Configurable
connect/receive/send timeouts default to 20 seconds. ApiClient constructs its
own Dio with Accept: application/json and typed Response<T> for GET, POST, PUT,
PATCH, and DELETE. It accepts queries, JSON bodies, Options, cancellation, and
caller-created FormData; it performs no endpoint DTO conversion or file reads.

Requests default to public (`requiresAuth: false`). Authenticated requests ask
AccessTokenProvider for the current token and attach Bearer only when a nonblank
token is available. Public requests skip the provider. Transport owns Authorization
and removes caller-supplied/stale values; other custom headers/metadata are
supported. AccessTokenProvider is an inversion-of-control boundary exposing no
refresh token. Network depends on Common, never Session/Auth/Flutter; composition
supplies the Session-backed provider in Provider now. No singleton is created.

Paths must be relative to the configured API base. Absolute/cross-origin paths
are rejected and automatic redirects are disabled to prevent credential forwarding
or implicit replay. Composition owns lifetime and calls close when finished.

DioException is normalized at ApiClient into NetworkException: connection
(including certificate errors), timeout, cancelled, badResponse, or unknown.
HTTP status is retained. Raw requests, bodies, plugin messages, and causes are
not retained. Top-level backend message/code keys are accepted only when they
match known safe generic allowlists. Missing, malformed, nested, or unrecognized
metadata falls back to a generic message/no backend code. This deliberately
conservative extraction can evolve after a global backend error contract is agreed.

Data sources may throw NetworkException; repositories catch it, call
toAppFailure(), and return Failure<T>/Result<T> to presentation. Mapping retains
safe message/code and omits transport details and causes. ApiClient does not
return Result. DioException does not escape its request boundary. Successful Dio
Response objects still include request metadata/payloads; never log them blindly.

There is no automatic refresh, refresh retry, session clearing on 401, automatic
mutation/request retry, or sensitive HTTP logger. A 401 is an ordinary HTTP
failure. Deterministic tests use a custom adapter, never the internet.

## Implemented Provider authentication

The current source of truth is the confirmed Provider contracts supplied
with the implementation requests, including Google authentication. No separate Provider API document was found
in the repository. The application must inject a base URL ending in `/api/v1`;
Auth uses the existing client's relative-path behavior without a hostname.

| Operation | Public POST path | Result and persistence |
| --- | --- | --- |
| registerProviderWithEmail | `/auth/register` | Expects 201 and returns RegistrationAccount; no session write. |
| verifyProviderEmail | `/auth/email/verify` | Parses credentials/user, validates Provider role, persists session, returns AuthUser. |
| requestProviderPhoneOtp | `/auth/otp/request` | Expects 202 and returns OtpRequestInfo; no session write. |
| verifyProviderPhoneOtp | `/auth/otp/verify` | Same verification/persistence flow; backend may create the account. No extra account-creation call. |
| authenticateProviderWithGoogle | `/auth/google` | Google ID-token exchange; reuses token parsing, Provider role verification, UTC expiry and awaited session persistence. |
| loginProvider | `/auth/login` | Public identifier/password login; reuses Provider role verification and awaited secure session persistence. |

All requests explicitly use requiresAuth: false and send no Authorization.
Provider serialization injects SERVICE_PROVIDER for registration and phone OTP
operations; email verification sends only email and OTP. Callers cannot supply
an arbitrary account type. All models are handwritten immutable values because
this small set does not justify generators/dependencies. Roles are copied into
an unmodifiable list. Token DTOs/parsing helpers remain internal.

ProviderAuthRepository/ProviderAuthRepositoryImpl expose typed request values
and Result<RegistrationAccount>, Result<AuthUser>, or Result<OtpRequestInfo>.
AuthUser has no credential/profile/onboarding fields. Optional email/phone and
verification fields tolerate missing/null values for authenticated accounts;
registration requires its documented email and verification flags. Unexpected
types, missing required metadata, or incomplete credentials fail safely.
Account status is preserved from the backend, with no invented status policy.

Verification requires roles to contain SERVICE_PROVIDER before storage is touched.
The injected clock (DateTime.now in production) is converted to UTC and expiresIn
seconds are added in Auth, not Session. Positive integer expiry is required;
overflow/unrepresentable timestamps are rejected. Tokens only reach SessionStorage.
Success is returned only after awaiting write. Passwords and OTPs are transient
request values, never stored. No model logs credentials or prints them in toString.

Transport errors use NetworkException.toAppFailure(). Invalid responses use
AUTH_INVALID_RESPONSE; local input failures use AUTH_INVALID_REQUEST; wrong roles
use AUTH_WRONG_ACCOUNT_TYPE; storage errors use SESSION_PERSIST_FAILED.
Unexpected failures use AUTH_OPERATION_FAILED. Failures expose no raw exception
cause or secret values. Failed operations do not clear or replace existing
sessions except through an attempted verification write; there is no automatic
logout or recovery policy. Composition must coordinate concurrent auth attempts.

Local validation checks nonblank email/phone and password length 10–72 Unicode
code points, preserving submitted values. OTP format, eligibility, resend cooldown,
and maximum attempts remain backend-owned. Password Unicode length semantics,
phone-created account nullable fields, and verification HTTP statuses should be
confirmed against the full backend contract before UI integration. Current
verification calls accept the transport's successful 2xx responses with valid
payloads; only documented 201/202 statuses are enforced for registration/request.

Deferred pending a confirmed current contract:
email/phone OTP resend where applicable, refresh, logout, logout-all, other
auth methods, forgot password, and password reset. There is no refresh replay,
refresh rotation, or backend logout. Provider now composes a Session-backed token provider and the Auth repository,
and supports email registration/verification forms on explicit submission. No live backend was called;
tests use an in-memory transport and session fake. Customer remains unchanged.

## Provider application bootstrap

Provider uses handwritten Riverpod providers for composition, with no generator
or service locator. The dependency graph is AppConfig → NetworkConfig;
SessionStorage + clock → AccessTokenProvider; NetworkConfig + AccessTokenProvider
→ ApiClient; ApiClient + SessionStorage + clock → ProviderAuthRepositoryImpl.
SessionStorage is SecureSessionStorage(FlutterSecureKeyValueStore()). Concrete
plugin access stays in composition, and ApiClient is closed when its scope ends.
Design System is a direct Provider dependency for shared theme/widgets; Common is now direct for Result/AppFailure presentation handling.

AppConfig reads BTHERE_API_BASE_URL from --dart-define with no fallback hostname.
Supply the final API base, including `/api/v1`, externally. Absolute HTTP(S)
URLs are required without embedded credentials, query, or fragment. HTTP is allowed
in debug development; profile/release require HTTPS. Missing/invalid config
renders a clear configuration failure on startup without constructing storage or
HTTP dependencies. No .env, flavors, or committed secrets are introduced.

```sh
flutter run -d emulator-5554 --dart-define=BTHERE_API_BASE_URL=<development-api-base-url>
```

Startup reads persisted credentials once locally. Checking displays a neutral
startup screen; no session or expired access token routes to `/auth`; valid local
credentials route to `/home`. The auth entry begins the email flow; home remains a placeholder.
Storage read failures display a safe restoration failure instead of a spinner
or unauthenticated-success assumption. A stable go_router instance listens for
Riverpod state changes and redirects only when the target path differs.

Startup does not validate backend account state, Provider role, or token revocation
and makes no backend/auth/refresh requests. Local validity means non-expired
persisted credentials only. The app-level token adapter rereads storage for each
request and never supplies expired access tokens or refresh tokens. Expired
persisted sessions are deliberately retained for a later confirmed refresh flow;
no startup path writes/clears credentials. Refresh remains deferred.

Unit/widget tests override storage and time without platform channels or internet.
No development base URL is committed or configured in the repository; any emulator
smoke using example.invalid is only a non-network test argument, not the actual
development backend or a production fallback. iOS native integration remains a
separate verification step; no iOS build is attempted here.

## Shared Design System foundation

Design System owns the approved palette, Nunito typography API, 8px spacing
rhythm, 16px control radius, 24px surface radius, Material 3 light/dark themes,
and generic button, form field, loading, and state widgets. It depends only on
Flutter. Apps/features consume shared tokens and semantic theme roles instead
of duplicating colors. Provider uses both themes with ThemeMode.system and
shared primitives in startup, email auth screens, and the home placeholder; Customer is unchanged.

Nunito assets are absent and verified local integration is pending; Flutter
uses platform fallback without runtime font fetching. The approved palette is
preserved with accessible foreground variants for small text and errors.
See [Design System usage and token reference](../packages/bthere_design_system/README.md).
Design System contains no auth logic, logo, or theme preference persistence.

## Provider email authentication UI

Provider implements `/auth` (default email/password Sign in), `/auth/register/email` (email,
password, confirmation), and `/auth/verify-email` (one verification-code field).
Presentation trims email, checks basic email shape, validates passwords at
10–72 Unicode code points to match Auth, and requires an exact confirmation.
OTP validation requires only nonblank input; no length, cooldown, attempt,
or resend policy is invented. Shared controls preserve system themes, text
scaling, accessible labels, and scrollable keyboard layouts.

Separate auto-disposed Riverpod controllers call the existing Auth repository,
block duplicate submissions, and expose safe domain results/failures without
raw exceptions or failure causes. Registration creates no session and passes
only a transient email context via route extra, with no query parameters.
Verification relies on AuthRepository to await secure session persistence,
then invalidates appSessionStateProvider. The stable router reevaluates local
credentials and routes to home only after restoration reports authentication.

Password/OTP are transient widget/request values, never logged or persisted
by the app. Confirmation never reaches the repository. Visibility remains
local; password correction/suggestions stay disabled even when revealed.
Registration autofill disposal cancels automatic platform-save completion.
Passwords are cleared on registration success and controllers disposed on exit.
Missing verification context recovers to registration; an app restart during
pending verification returns to auth entry without restoring email/password/OTP.
Failures allow retry and preserve relevant input. Busy forms disable fields,
actions, and back navigation. Home remains unchanged; phone UI,
resend, forgot password, refresh, and onboarding remain deferred.

Tests use only fake repositories/storage, never internet endpoints. Emulator
smoke checks entry, registration, keyboard, and themes without submitting.
Live registration/verification is a separate manual validation step.

Provider email auth presentation now uses centered text branding, strong navy/
teal hero hierarchy, clipped low-opacity edge shapes, above-field labels with
mail/lock icons, a lightweight 48px back control, and shared arrow CTAs.
Auth content has a 440px maximum width, token-based responsive margins, and
scrollable keyboard/large-text layouts. Decorations ignore input and semantics,
and soften further in dark mode. Routes, controllers, validation, repository
calls, and session refresh behavior are unchanged. That visual redesign added no social/login, phone,
resend, name field, or terms requirement is introduced.

## Provider Google authentication

Google OAuth is deferred because backend OAuth configuration is unavailable.
Its isolated identity adapter, controller, repository operation, dependency and
tests are retained dormant for future enablement. The active auth UI neither
watches nor constructs Google providers; SDK initialization is lazy and is never
requested by the active flow. `BTHERE_GOOGLE_SERVER_CLIENT_ID` remains optional;
only `BTHERE_API_BASE_URL` is required for normal startup.

Current authentication offers email/password Sign in and Create account tabs.
Registration retains email/password registration followed by email OTP
verification and authenticated routing to `/home`. Registration creates no
session; verification awaits Auth-owned persistence before refreshing local
session state. Provider onboarding remains future work after the existing home
placeholder. Google OAuth, Apple auth and phone OTP UI are
deferred. See [Dormant Google implementation and future setup](provider-google-sign-in.md).

## Provider password Sign in

`/auth` now defaults to Sign in using the current shared background, branding,
rounded icon-leading fields and CTA. A route-based Sign in / Create account
switcher also appears on registration. Login requires only a nonblank identifier
and nonempty password, trims the identifier and sends it as `identifier`; it does
not apply registration's 10–72-character rule. Login uses the existing Auth-owned
token parsing, Provider role validation, expiry and awaited secure persistence,
then refreshes local session state for routing to `/home`. The new auto-disposed
controller blocks duplicates and exposes safe domain state only. Google remains
hidden. See [Provider Sign in and manual validation](provider-password-sign-in.md).


## Provider onboarding completion gateway (current routing)

The earlier home-on-authentication descriptions above describe the foundation stages.
Current authenticated routing first checks GET /providers/me/completion with
requiresAuth true, using the existing session token bridge. Backend nextStep is the
routing authority; only COMPLETED reaches home. Complete Profile and Select Service now have real
forms; the three remaining steps have branded placeholders. Loading/error/unsupported responses remain on the gateway with Retry.
Models, repository, remote data source and refreshable Riverpod controller belong
solely to the Provider app. Auth persistence, role validation, expiry and dormant
Google behavior are unchanged. See [gateway documentation](../apps/provider_app/README.md).


Provider Complete Profile is implemented inside onboarding/profile. It performs
authenticated GET /markets and PUT with the selected marketId, fixes profilePhoto
to null, and reloads
completion after success. See [profile contract](provider-complete-profile.md).


Provider Select Service uses authenticated GET /provider-types and POST
/providers/me/service-types, retains the parsed assignment in onboarding state,
and reloads completion. See [service selection](provider-select-service.md).


Provider Service Requirements now has an authenticated schema loader, completion-derived assignment recovery, applicable-section overview and guarded future-form routes. See [Provider Service Requirements](provider-service-requirements.md) for behavior and contract gaps. Actual requirement forms/submissions remain deferred.


Service Options is now a real schema-driven selection flow with authenticated GET/PUT, authoritative completion/schema refresh and safe retries. See [Provider Service Options](provider-service-options.md). Other requirement forms remain deferred.


## Provider service-first navigation

The earlier completion-driven global wizard is retired. Authenticated login/restoration lands on `/services`; backend provider types are main services and schema options are sub-services. Assignment GET recovery, validated main-service experience and options PUT precede selected-service setup. Completion remains progress/approval data. See [the current architecture](provider-service-first.md). Auth/session/network/design-system foundations and reusable onboarding repositories/models remain preserved.
