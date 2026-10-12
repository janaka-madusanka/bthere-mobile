> Current navigation is service-first. The routes and sequencing below are historical; their reusable repositories/models remain preserved. See [Provider service-first architecture](provider-service-first.md) for the current Services → sub-services/experience → assignment/options → selected-service setup flow.

# Provider Service Requirements overview

The Provider app now replaces `/onboarding/service-requirements` with a branded, scrollable backend-driven overview. Service Options now has a real selection/submission flow; the other requirement forms remain deferred.

## Architecture and API

Presentation → Riverpod `ProviderRequirementsController` → `ProviderSchemaRepository` → `ProviderSchemaRemoteDataSource` → existing `ApiClient`.

Schema requests use authenticated `GET /provider-types/{serviceTypeId}/onboarding-schema` with the existing session token bridge. No requirement submission endpoint is called.

Immutable domain models include `ProviderOnboardingSchema`, `ProviderServiceSetup`, `ProviderRequirementField`, `ProviderSchemaOption`, `ProviderDocumentRequirement`, `ProviderSkillRequirement`, `ProviderLevelRequirement`, and `ProviderRequirementLevel`. Lists and JSON metadata are copied and deeply frozen. IDs, ownership, mandatory booleans, JSON shapes, bounds and finite file sizes are checked. Certificate and education levels accept only DISABLED, OPTIONAL and REQUIRED; unknown levels produce a safe unsupported-metadata failure.

## Identity, lifetime and refresh

`GET /providers/me/completion` remains the authority for assignmentId, serviceTypeId, serviceName, completion flags and overall completionPercentage. The overview never reads the temporary service-selection assignment or stores assignment IDs in secure storage. The existing completion future is shared and cached while its session is valid; restoration starts a new completion load. Existing session invalidation, mutation-triggered invalidation and explicit refresh prevent reuse after known state changes. There is no invented time-based freshness policy or polling.

Candidates have at least one false completion flag, sorted by assignmentId. One candidate opens directly; multiple candidates get a selector. No effectiveStatus/verificationStatus filtering is invented because assignment status eligibility rules were not supplied. Schema applicability controls which sections are actually displayed. No candidates yields a safe empty state with Retry, never a local home redirect.

Refresh invalidates both completion and the selected schema. In-flight calls are shared. Refreshed completion can change the selected assignment or route through the unchanged six-step completion gateway.

## Applicability and progress

- Options: optionsRequired or nonempty selectable options; optionsCompleted.
- Documents: nonempty document requirement metadata; documentsCompleted. No mandatory label is inferred.
- Skills: nonempty skill requirement metadata; skillsCompleted. No mandatory label is inferred.
- Certificates/education: hidden when DISABLED; OPTIONAL/REQUIRED labels retain the backend level and respective completion flag.
- Availability: availabilityEnabled; availabilityCompleted.
- Locations: serviceAreasEnabled; serviceAreasCompleted.
- Additional information: common fields or option fields; customRequirementsCompleted.

Progress is completed applicable sections / applicable sections. Optional sections are included in this descriptive count, without any client-side blocking decision. Disabled/hidden sections are excluded. Overall account setup shows the backend percentage separately; no service percentage is fabricated.

## Placeholder routes

`/onboarding/service-requirements/options` opens the real Service Options screen. The same prefix followed by `documents`, `skills`, `certificates`, `education`, `availability`, `locations`, or `additional` opens a branded future-form placeholder. Query parameters carry only `assignmentId` and `serviceTypeId`, recovered from completion. Deep links resolve another authoritative assignment before loading its schema; nonexistent IDs, mismatches and inapplicable sections show Section unavailable. Authentication and the COMPLETE_SERVICE_REQUIREMENTS completion step guard all child routes. No tokens, passwords, form values or session objects are passed.

## Error handling and backend gaps

Schema transport errors use existing network normalization; malformed/unsupported responses and unexpected errors return safe AppFailure values. Loading, empty and failure states have no local completion inference or home fallback. Retry reloads completion and schema.

The supplied backend contract does not define inner document/skill objects. These are retained as opaque immutable JSON objects; their requiredness is deliberately not guessed. A full element contract is needed to interpret per-item enabled/level/required metadata and filter individual items, beyond the overview's array-presence signal. Field options/condition JSON is preserved without implementing undocumented form semantics. Field type/scope/status vocabularies must be confirmed before dynamic form rendering.

Languages is omitted from the overview and routes because the supplied schema has no language applicability signal. Completion also lacks languagesCompleted. An endpoint's existence alone does not establish applicability or completion. Future language setup needs an explicit applicability contract; it must remain excluded from progress until an authoritative completion flag exists.

## Verification and changed files

New feature files (relative to repository root):

- apps/provider_app/lib/features/onboarding/requirements/domain/provider_onboarding_schema.dart
- apps/provider_app/lib/features/onboarding/requirements/domain/provider_schema_repository.dart
- apps/provider_app/lib/features/onboarding/requirements/domain/provider_requirement_section.dart
- apps/provider_app/lib/features/onboarding/requirements/data/provider_schema_response.dart
- apps/provider_app/lib/features/onboarding/requirements/data/provider_schema_remote_data_source.dart
- apps/provider_app/lib/features/onboarding/requirements/data/provider_schema_repository_impl.dart
- apps/provider_app/lib/features/onboarding/requirements/application/provider_requirements_controller.dart
- apps/provider_app/lib/features/onboarding/requirements/presentation/provider_requirements_screen.dart
- apps/provider_app/test/provider_requirements_test.dart
- apps/provider_app/test/support/fake_schema_repository.dart
- docs/provider-service-requirements.md

Existing files updated:

- apps/provider_app/lib/app/providers/app_providers.dart
- apps/provider_app/lib/app/router/app_router.dart
- apps/provider_app/lib/app/router/app_routes.dart
- apps/provider_app/test/onboarding_test.dart
- apps/provider_app/test/provider_service_test.dart
- apps/provider_app/README.md
- docs/provider-select-service.md
- docs/foundation-technology-stack.md

Tests use fake repositories and mocked HTTP transport, never live backend calls. Coverage includes parsing/nulls/unknown levels, immutable metadata, IDs/bounds, authenticated endpoint, network failures, completion reuse/refresh, simulated restart, multiple assignments, applicability/progress, responsive light/dark UI, retry, guarded routes and invalid deep links. Full workspace checks include existing login, profile, market, service-selection and completion regressions.

Final verification: root `dart pub get` succeeded; all seven members analyzed without issues. All 520 tests passed (Provider 316, Customer 1, Design System 19, Network 46, Session 8, Auth 127, Common 3), including 38 new requirements tests. Provider `flutter build apk --debug --no-pub` succeeded at `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`. No live backend mutation, commit, push or PR was performed.


Service Options is now a real schema-driven selection flow with authenticated GET/PUT, authoritative completion/schema refresh and safe retries. See [Provider Service Options](provider-service-options.md). Other requirement forms remain deferred.
