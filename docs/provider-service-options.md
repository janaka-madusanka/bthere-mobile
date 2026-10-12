> Current navigation is service-first. The routes and sequencing below are historical; their reusable repositories/models remain preserved. See [Provider service-first architecture](provider-service-first.md) for the current Services → sub-services/experience → assignment/options → selected-service setup flow.

# Provider Service Options

Service Options is implemented at `/onboarding/service-requirements/options`. Other requirement screens remain placeholders. No dynamic option fields or other requirement submissions are implemented.

## Architecture and context

Presentation → auto-disposed Riverpod family controller → ProviderOptionsRepository → ProviderOptionsRemoteDataSource → existing ApiClient. Provider-scoped composition supplies the repository; widgets never access the client or tokens.

The route carries only assignmentId and serviceTypeId. Both must match an authoritative assignment in completion-backed requirements state. A restored/deep-linked second assignment is resolved through the overview controller before loading selections. Names and available option IDs come from completion/schema, never from temporary service creation state. Missing/mismatched/inapplicable context fails safely before option API access.

## API and response model

Authenticated GET `/providers/me/services/{assignmentId}/options` loads the selected-option array. Immutable ProviderSelectedOption retains providerOptionId, optionId, code, name, providerStatus, adminStatus, verificationStatus, nullable reviewedBy, reviewedAt and reviewNote. IDs must be positive integers; duplicate selection/provider-option IDs, wrong JSON shapes, missing mandatory fields and malformed review metadata fail safely. Lists are unmodifiable. Review timestamps are parsed into UTC DateTime; reviewedBy is a nullable positive integer.

Authenticated PUT uses the same path and exactly this payload:

```json
{"optionIds":[12,13]}
```

Only sorted integer option IDs are sent. Empty arrays are valid when schema rules permit clearing. No names, codes, completion flags or other fields are sent. No save-response body contract was provided, so successful HTTP responses (including 204) establish persistence success without inventing response fields or requiring approval. PENDING verification does not cause a failed save.

## Rules and UI

Available option cards come from the existing schema.options. Existing selections preselect matching IDs. Users can select/unselect one or multiple cards. Backend minimumOptionSelections and maximumOptionSelections drive guidance and validation; a missing maximum remains unbounded. A required selection with an absent minimum produces a safe rules-unavailable state and Retry rather than inventing a minimum. A supplied zero minimum is retained exactly. A nonnull minimum is respected even if optionsRequired is false.

Cards display option names and checkbox state; codes and review internals are hidden. Selected options with fields show Additional details required. Those fields do not block option saving and remain deferred to Additional Information.

Loading disables editing. Empty schemas offer Retry and disable Save. If an existing saved option ID is absent from current schema, only matching IDs are shown selected, an explicit inconsistency message appears, and saving is blocked. The screen never silently PUTs away or preserves unknown IDs.

Save validates membership and counts, locks editing/back actions during submission, and prevents duplicate requests. PUT failure retains the current selection and exposes a safe readable message with the Save retry action. Unexpected exceptions and network errors cannot expose raw transport details. Retry for load/schema/inconsistency errors refreshes requirements then selections. Generation/mounted checks prevent late save responses from changing replaced/disposed controller state.

## Refresh and routing

After successful persistence, the screen returns to the requirements overview and the existing refresh coordinator reloads completion and schema. There are no local completion updates. In particular, serviceAreasCompleted may become false after selecting a physical option; the overview renders the refreshed flag.

The persistent overview coordinator captures its scoped container before invalidation so refresh can finish while the options screen is disposed or the overview notifier rebuilds. The saved service schema is still fetched if completion chooses another assignment or advances to approval/completed and there is no candidate for its normal overview load. Refresh failure does not convert an already persisted save into a PUT failure: the completion gateway or overview exposes Retry. The unchanged nextStep router remains authoritative if completion advances beyond the requirements step.

## Contract concerns

The response is treated as a JSON array, as for existing list APIs. The supplied request describes response fields without a complete typed payload; nonnull reviewedBy is treated as a positive numeric reviewer ID. A different reviewer representation or response envelope requires a confirmed backend contract. Optional review fields can be absent/null. PUT response content is intentionally ignored because no response model was documented.

Missing required minimum, saved IDs absent from schema, malformed rules/IDs and unsupported schema metadata are surfaced safely. Missing maxima are never invented. Dynamic fields, document/skill metadata, languages applicability and language completion retain the previously documented gaps/deferred scope.

## Tests and changed files

New tests cover authenticated exact GET/PUT paths, integer-only payload, 204 success, parsing/nulls/review metadata, malformed and duplicate IDs, empty selections, network errors, restoration-derived context, preselection, min/max/required/null rules, option field notes, duplicate-save blocking, failure preservation, save success, completion/schema refresh, changes to locations completion, schema/load retry, inconsistency, empty/loading states, lifecycle safety and large-text light/dark layout. Existing overview tests now expect the real options screen; other placeholders and guarded IDs retain their coverage. Automated tests use mock repositories/transports only.

New files:

- apps/provider_app/lib/features/onboarding/requirements/options/domain/provider_selected_option.dart
- apps/provider_app/lib/features/onboarding/requirements/options/domain/provider_options_repository.dart
- apps/provider_app/lib/features/onboarding/requirements/options/data/provider_options_response.dart
- apps/provider_app/lib/features/onboarding/requirements/options/data/provider_options_remote_data_source.dart
- apps/provider_app/lib/features/onboarding/requirements/options/data/provider_options_repository_impl.dart
- apps/provider_app/lib/features/onboarding/requirements/options/application/provider_options_controller.dart
- apps/provider_app/lib/features/onboarding/requirements/options/presentation/provider_options_screen.dart
- apps/provider_app/test/provider_options_test.dart
- apps/provider_app/test/support/fake_options_repository.dart
- docs/provider-service-options.md

Existing files changed:

- apps/provider_app/lib/app/providers/app_providers.dart
- apps/provider_app/lib/app/router/app_router.dart
- apps/provider_app/lib/features/onboarding/requirements/application/provider_requirements_controller.dart
- apps/provider_app/test/provider_requirements_test.dart
- apps/provider_app/README.md
- docs/provider-service-requirements.md
- docs/foundation-technology-stack.md


Final verification: root `dart pub get` succeeded. All seven workspace members passed analysis. All 556 workspace tests passed: Provider 352, Customer 1, Design System 19, Network 46, Session 8, Auth 127, Common 3. This includes 36 new Service Options tests. Provider `flutter build apk --debug --no-pub` succeeded at `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`; the APK kernel contains the real options screen/controller. No automated live backend calls/mutations, commit, push or PR were performed.
