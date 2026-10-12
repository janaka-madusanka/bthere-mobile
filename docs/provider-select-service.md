> Current navigation is service-first. The routes and sequencing below are historical; their reusable repositories/models remain preserved. See [Provider service-first architecture](provider-service-first.md) for the current Services → sub-services/experience → assignment/options → selected-service setup flow.

# Provider Select Service

/onboarding/service is a real Provider-owned onboarding screen. The six completion
nextStep mappings, shared authentication, simplified profile and market flow remain
unchanged. The implementation is in features/onboarding/services:

presentation -> Riverpod catalog/selection controllers -> repository -> remote data
source -> existing ApiClient. Both endpoints set requiresAuth true and rely on the
existing session access-token bridge; no widget/API code manually attaches tokens.

## Service catalog

GET /provider-types expects a bare array. Immutable ProviderServiceType retains
id, name, description, iconUrl and status. IDs must be unique positive integers;
names/status must be nonblank. Missing/null/blank description and iconUrl are
accepted, while invalid non-string optional values fail safely. Only ACTIVE types
are selectable; production has no invented or fallback catalog entries.

The auto-disposed Riverpod catalog controller loads only for an authenticated
session and supports explicit reload/Retry without polling. Loading, malformed or
network responses and an empty active list are safe UI states. Continue remains
disabled until selection and valid experience exist.

Cards show backend names, optional descriptions and a clear single-selection
state. Switching cards changes the selected ID while retaining entered experience.
Usable absolute HTTP(S) icon URLs without embedded credentials use Flutter's image
widget; null, blank, invalid URLs and image failures use a generic local work icon.
There is no new image dependency, image upload or marketplace management UI.

## Assignment request and response

POST /providers/me/service-types sends exactly:

```json
{"providerTypeId": 3, "experienceYears": 4.5}
```

The immutable ProviderServiceInput validates a positive ID and finite nonnegative
experience. Numeric entry supports zero, integer and decimal years; blank, negative,
NaN/infinite and invalid text are rejected. There is no invented maximum or age rule.
Experience serializes as a JSON number. Whether the backend sets a stricter minimum
or maximum remains unconfirmed; zero is accepted by the client per supplied direction.

The handwritten immutable ProviderServiceAssignment retains all documented fields:
assignmentId, providerTypeId, providerTypeName, experienceYears, status,
providerStatus, adminStatus, verificationStatus, emergencyOverride,
emergencyOverrideReason, emergencyOverrideExpiresAt, requiredDocumentTypeIds and
missingDocumentTypeIds. Assignment/type/document IDs must be positive integers;
experience must be finite and nonnegative, flags must be booleans, required text
must be nonblank and document arrays must exist. Nullable emergency fields are
supported; non-null expiry uses an ISO-8601 date string parsed to UTC. Document
lists are immutable. A returned providerTypeId that differs from the request fails
safely. Status strings are retained without inventing backend enums or policy.

## Controller state and routing

The selection controller prevents invalid or duplicate requests, exposes safe
loading/failure state and retains the returned assignment before calling the
existing completion controller's reload method. Assignment remains in memory across
routing for later onboarding APIs. Session-state changes clear it, and results from
an earlier session cannot overwrite a new session. No assignment ID is written to
secure storage; backend completion/service APIs remain the recovery authority after
restart. Existing shared network 401 policy is preserved without token deletion.

POST failures preserve the selected card and experience for retry. During submission,
fields, cards and Continue are disabled and busy back navigation is blocked.
Unexpected exceptions and network errors return safe AppFailure messages without
raw HTTP data, credentials or traces.

After successful POST, the router waits on completion then follows the actual
nextStep. COMPLETE_SERVICE_REQUIREMENTS is an expected outcome, never a hard-coded
destination. Completion failure remains on the existing Retry gateway; it does not
repeat POST. If completion returns SELECT_SERVICE again, the screen offers Recheck
setup instead of accidentally posting the same assignment again.

The B there page retains themed branding, rounded controls, bounded width, SafeArea,
scrolling, keyboard safety and large-text light/dark support. Service requirements,
options, languages, skills, documents, certificates, education, availability,
locations, dynamic fields and approval are outside this implementation.

## Tests and contract notes

Tests use fake repositories, a fake HTTP adapter and a failing image client; there
are no automated live backend calls or submissions. Coverage includes catalog and
assignment parsing, positive IDs, optional fields, active filtering, exact endpoints,
authenticated token bridge, numeric request body, malformed/network failures,
validation, duplicate prevention, retries, session isolation, retained assignments,
loading/empty states, switching selection, experience, completion-driven routing,
image fallback and responsive light/dark layouts. Existing gateway and profile
fixtures now provide a fake service catalog when their destination is SELECT_SERVICE.

No live response was verified in this task. The implementation follows the supplied
bare-array catalog and assignment response, with ISO-8601 assumed for a non-null
emergency expiry. Zero experience and no maximum remain client rules until the
backend clarifies its bounds. No idempotency/recovery endpoint is invented.


Provider Service Requirements now has an authenticated schema loader, completion-derived assignment recovery, applicable-section overview and guarded future-form routes. See [Provider Service Requirements](provider-service-requirements.md) for behavior and contract gaps. Actual requirement forms/submissions remain deferred.
