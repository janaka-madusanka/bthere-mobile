# Repository structure

The root coordinates a Dart Pub Workspace. The two apps remain independent
Flutter applications. Common result/failure primitives and secure session
persistence, REST transport, and confirmed Provider authentication are implemented.
Provider now has dependency composition, local session restoration, and minimal
routing plus email registration/verification UI. The shared Design System is implemented; Customer remains a scaffold.
Shared dependency boundaries are configured: session and network depend on
common; auth depends on common, network, and session. Apps currently have no
shared-package dependencies except Provider's Auth/Network/Session/Design System/Common composition.
See [mobile architecture](mobile-architecture.md)
for allowed directions and future organization.

| Directory | Responsibility |
| --- | --- |
| `apps/customer_app` | Customer application and Customer-specific features. |
| `apps/provider_app` | Service Provider application and Provider-specific features. |
| `packages/bthere_design_system` | Shared visual tokens, light/dark themes, and generic controls. |
| `packages/bthere_network` | Future shared REST/network infrastructure. |
| `packages/bthere_session` | Future secure authenticated-session infrastructure. |
| `packages/bthere_auth` | Future authentication domain shared where appropriate. |
| `packages/bthere_common` | Only genuinely shared small models/utilities. |
| `docs` | Repository documentation. |

Do not place Provider-only or Customer-only business logic in shared packages.
These boundaries cover current implementations and intended future responsibilities.
