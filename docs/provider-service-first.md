# Provider service-first architecture

The Documents extension is implemented in [Provider Documents](provider-documents.md), including its current verification and exact file manifest. The test counts and manifest below describe the original service-first refactor.

## Final flow and authenticated landing

Email registration now enters `/onboarding/profile` after email verification and secure persistence. Login and restored sessions check `GET /providers/me/completion`: incomplete profile/market flags or COMPLETE_PROFILE/SELECT_MARKET require Provider Details. Account-check failures stay on a recoverable startup screen. See [email registration onboarding](provider-email-registration-onboarding.md).

Once profile and market prerequisites are complete, the flow remains Services → main-service detail → applicable sub-services and main-service experience → assignment → saved sub-services → service setup → status/review. Later service completion refreshes remain status data and cannot initiate a global wizard redirect. `/onboarding/profile` is the account prerequisite form; other retired onboarding links migrate to Services after that gate. The router keeps one instance across session changes.

## Feature architecture and preserved infrastructure

New service UX lives in `apps/provider_app/lib/features/services`, separate from reusable Provider onboarding data/domain implementations. Presentation → Riverpod controller/providers → existing/new repository methods → remote data sources → existing ApiClient. Auth/password identifier serialization, registration/OTP, dormant Google, secure persistence, token expiry, HTTP authentication, Result/AppFailure normalization and design-system primitives are preserved. No assignment/option IDs or draft forms are added to secure storage.

The existing service catalog/assignment, schema, options, completion, profile and market repositories/models are retained. Completion nextStep parsing remains intact. Retired wizard orchestration has no app-router entry. The reused profile form now also handles account prerequisites at `/onboarding/profile`; service-specific profile editing remains under the selected service. Their reusable model/repository/controller tests remain; obsolete wizard-navigation/component expectations are replaced by service-first tests.

## Catalog and detail

Authenticated GET `/provider-types` supplies active main-service cards with name, description and safe optional icon. GET `/providers/me/service-types` supplies existing assignments. Completion supplies backend requirement and verification state. Cards support independent Available, Setup required, Pending approval, Approved, Rejected and Inactive states. Assigned cards use service-specific schema/selection state when available so disabled/optional sections do not force a pending service back into setup. Unavailable progress remains visible as Status unavailable / a safe Retry rather than inventing approval or redirecting to profile.

Opening `/services/{serviceTypeId}` performs reads only: catalog, schema and assignments, plus current options for existing assignments. New services have no arbitrary preselection. Existing services restore persisted option IDs and numeric experience. Schema option IDs are never deduplicated by display name. Duplicate names display humanized codes (underscore/hyphen words converted to title case). Identical name/code variants remain separate, display Variant plus their real option ID, and surface a clearer-label contract concern.

Sub-services use schema optionsRequired/minimumOptionSelections/maximumOptionSelections. Missing maxima remain unbounded. Missing required minima fail safely without invented limits. Zero minima and optional empty sets retain supplied backend semantics. Experience accepts finite nonnegative numbers, including zero and decimals; blank, invalid, negative, NaN and infinity are rejected without inventing a maximum. Experience belongs only to the main-service assignment. Existing experience is read-only because no assignment-experience update API was provided.

## Continue and partial success

Continue validates IDs, counts and experience before mutation, and locks duplicate submission/edit/back actions. A fresh GET `/providers/me/service-types` checks assignment existence immediately before a new POST. An existing assignment is reused; failed lookup never falls back to blind creation.

New assignment POST `/providers/me/service-types` sends exactly:

```json
{"providerTypeId":3,"experienceYears":4.5}
```

The returned assignmentId is retained in controller state before the second mutation. PUT `/providers/me/services/{assignmentId}/options` sends exactly:

```json
{"optionIds":[12,13]}
```

Only real sorted integer option IDs are sent. Assignment creation followed by failed options saving preserves identity, selections and experience, exposes safe Retry and never repeats POST for that retained assignment. Restart/revisit recovers identity through the authoritative assignment list. A failed/ambiguous POST response is rechecked through GET before retrying creation. Server-side uniqueness/idempotency is still needed for genuinely concurrent clients; the mobile app cannot make two separate backend writes atomic.

After both mutations succeed, completion, assignment and schema state is invalidated and UI enters `/services/{serviceTypeId}/setup`. That page resolves fresh backend assignment/completion/schema/selections. Local code never fabricates completion. Options persisted with PENDING verification remain successful persistence. Location applicability/completion may change after options saving.

## Service setup, profile/market and selected fields

Setup requires a real authoritative assignment and valid persisted sub-service IDs. Direct setup or requirement links without required selections offer Choose your sub-services. Basic Details is guarded by the same authoritative context and is never a login prerequisite screen.

Setup excludes the old Service Options card. Available sections use existing schema/flags: documents/skills when metadata exists, enabled availability/service areas, non-DISABLED certificates/education, and Additional information when common or selected-option fields exist. Locations remain hidden before selection. Common fields always belong to the main service; option fields are filtered strictly by selected option IDs. Unselected option fields cannot appear in UI, progress or pending-state evaluation. Additional information currently lists applicable field labels/requiredness as a future-form placeholder.

Metadata preserves TEXT, TEXTAREA, NUMBER, BOOLEAN, DATE, TIME, PHONE, EMAIL, SELECT, MULTI_SELECT, IMAGE_UPLOAD, DOCUMENT_UPLOAD and FILE_UPLOAD without implementing their inputs/submissions. Documents has a real service-scoped submission screen; other requirement forms remain branded placeholders. Languages has no confirmed applicability/completion contract and remains deferred.

Backend profileCompleted/marketSelected determine whether Basic details/Market information appears inside service setup. The existing profile form retains active market selection, names, DOB, gender, availability and bio; no NIC/passport controls are introduced. Successful profile submission reloads completion and returns to that service setup instead of a global wizard step. Markets are selected through this preserved profile API, because no independent market-update endpoint was supplied.

Documents are service-specific sections. Existing documentsCompleted backend flags remain the authority for shared approved/unexpired documents satisfying multiple services. No global document step or service-specific document storage is added. The Documents screen uses the documented Provider-level document and upload APIs; see its implementation report.

## Product status, pending and approval

Known INACTIVE provider/admin/effective status takes precedence; explicit rejection comes from backend verification/status; explicit APPROVED verification authorizes Approved. Pending approval requires authoritative PENDING verification plus completed applicable provider setup, valid selections and backend profile/market completeness. Optional certificate/education and hidden sections do not independently block pending; required selected dynamic fields use customRequirementsCompleted. No local boolean can create Approved.

Pending/approved/inactive services show `/services/{serviceTypeId}/status`. Pending copy says the information is submitted and waiting for review, without missing-setup cards. Approved services are not sent back into editable onboarding, including through direct detail links; they may view setup information with `?view=1`. Rejected status shows an optional backend rejectionReason at service level. Only already supported profile/options edits are available; no invented rejection resubmission/update endpoint is provided.

## Routes

- `/services`
- `/services/{serviceTypeId}`
- `/services/{serviceTypeId}/setup`
- `/services/{serviceTypeId}/setup/{documents,skills,availability,locations,additional,certificates,education}`
- `/services/{serviceTypeId}/setup/profile`
- `/services/{serviceTypeId}/status`

Sub-services are in Service Detail, with no separate options route. Route IDs are validated/recovered from backend state, and no secrets or draft forms are passed.

## Backend blockers and contract concerns

No live backend mutation was performed, so no deployed BACKEND BLOCKER is claimed or fabricated. If POST `/providers/me/service-types` rejects service-first creation because profile/market is incomplete, the app stays on the selected service, preserves input, displays the normalized safe error and creates no fake profile/market data. Resolving such a rejection requires the backend to permit assignment creation before these prerequisites or defer their enforcement to service setup. Exact live status/detail requires an explicitly performed integration test; automated tests simulate the failure without claiming a deployed result.

Assignment GET is parsed as a list of the existing assignment response models, including experience/status/document metadata. Incompatible envelopes or missing mandatory fields fail safely pending a confirmed contract. Optional rejectionReason is read only when actually supplied. Updating existing main-service experience needs a supported backend endpoint. Options absent from schema cause an explicit inconsistency and blocked saving, never silent retention/deletion.

Duplicate name + humanized-code combinations need backend labels meaningful enough to distinguish real variants. The UI preserves IDs and supplies variant labels but does not invent business meanings. Per-option delivery metadata was not provided; locations rely on refreshed backend serviceAreasEnabled/serviceAreasCompleted, not assumptions about option names/codes.

Inner skill metadata and the schema document entries remain opaque to the setup overview. The dedicated Documents requirement endpoint supplies typed per-document requiredness, expiry and approval metadata. Applicable false flags conservatively show attention; optional/required per-item blocking cannot be definitively refined without typed metadata or an authoritative per-assignment provider-setup-complete flag. Field options/conditions and upload contracts remain preserved JSON and deferred. Language applicability/completion and affected-requirement rejection details remain unspecified.

## Tests and verification

Service-first tests cover all six backend nextSteps yielding Services, authenticated restoration and existing login/OTP regression landings, unauthenticated guards, completion failure without wizard redirection, read-only card opening, exact authenticated assignment GET, positive IDs/duplicate-assignment rejection, existing assignment/sub-service/experience recovery, fresh preflight recovery, numeric experience validation, sub-service minima/maxima, duplicate labels, POST success + PUT failure retry/restart, duplicate-submit blocking, backend-prerequisite failure without fake data, selected-field filtering, profile/market placement and guards, schema/retry/empty handling, multiple independent statuses, pending/approved/rejected/inactive UX and responsive light/dark layouts. Repository-level auth/catalog/assignment/options/schema/profile/market tests remain. No automated test uses real backend transport.


## Exact files changed

New files:

- apps/provider_app/lib/features/services/domain/provider_service_status.dart
- apps/provider_app/lib/features/services/domain/sub_service_rules.dart
- apps/provider_app/lib/features/services/application/service_providers.dart
- apps/provider_app/lib/features/services/application/service_detail_controller.dart
- apps/provider_app/lib/features/services/application/service_setup_controller.dart
- apps/provider_app/lib/features/services/presentation/service_catalog_screen.dart
- apps/provider_app/lib/features/services/presentation/service_detail_screen.dart
- apps/provider_app/lib/features/services/presentation/service_setup_screen.dart
- apps/provider_app/lib/features/services/presentation/service_basic_details_screen.dart
- apps/provider_app/test/service_first_test.dart
- apps/provider_app/test/support/fake_configured_service.dart
- docs/provider-service-first.md

Existing files updated:

- apps/provider_app/lib/app/router/app_router.dart
- apps/provider_app/lib/app/router/app_routes.dart
- apps/provider_app/lib/features/onboarding/profile/application/provider_profile_controller.dart
- apps/provider_app/lib/features/onboarding/profile/presentation/provider_profile_screen.dart
- apps/provider_app/lib/features/onboarding/services/domain/provider_service_repository.dart
- apps/provider_app/lib/features/onboarding/services/domain/provider_service_assignment.dart
- apps/provider_app/lib/features/onboarding/services/data/provider_service_remote_data_source.dart
- apps/provider_app/lib/features/onboarding/services/data/provider_service_repository_impl.dart
- apps/provider_app/lib/features/onboarding/services/data/provider_service_response.dart
- apps/provider_app/test/support/fake_service_repository.dart
- apps/provider_app/test/email_auth_screen_test.dart
- apps/provider_app/test/google_auth_test.dart
- apps/provider_app/test/login_test.dart
- apps/provider_app/test/onboarding_test.dart
- apps/provider_app/test/provider_market_test.dart
- apps/provider_app/test/provider_options_test.dart
- apps/provider_app/test/provider_profile_test.dart
- apps/provider_app/test/provider_requirements_test.dart
- apps/provider_app/test/provider_service_test.dart
- apps/provider_app/test/widget_test.dart
- apps/provider_app/README.md
- docs/mobile-architecture.md
- docs/foundation-technology-stack.md
- docs/provider-select-service.md
- docs/provider-service-options.md
- docs/provider-service-requirements.md
- docs/provider-complete-profile.md


Final verification: root `dart pub get` succeeded. Formatting check covered all seven members (145 Dart files, zero changes required). All seven members passed analysis; final Provider analysis also passed after profile-navigation refinements. All 576 workspace tests passed: Provider 372, Customer 1, Design System 19, Network 46, Session 8, Auth 127, Common 3. This includes 72 new service-first tests replacing 52 obsolete flow/component navigation expectations. The final Provider suite includes retained profile-success duplicate-submit protection and return/cancel navigation to the selected service setup. Provider `flutter build apk --debug --no-pub` succeeded at `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`; its kernel contains all four new service screens. No automated live backend calls/mutations, commit, push or PR were performed.
