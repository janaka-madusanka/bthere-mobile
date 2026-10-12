# B there Provider app

Supply `BTHERE_API_BASE_URL` with a Dart define. Google sign-in remains dormant. Authentication, secure session persistence, token expiry and network error policies are unchanged.

## Service-first experience

Login/OTP or valid session restoration → `/services` → open a main service → choose the services you provide → enter main-service experience → create/recover assignment → save sub-services → `/services/{serviceTypeId}/setup` → service status/review.

Main services are active backend provider types. Sub-services retain backend option IDs, codes, names and fields. Opening a card performs read requests only. Assignment creation occurs only on Continue, after validation and a fresh assignment-list check. A successful POST followed by a failed PUT retains the assignment ID for retries; revisiting/restoring recovers it through the assignment API.

Completion remains backend progress and approval data. The router no longer listens to completion or mechanically follows nextStep. Old `/onboarding` and `/home` links migrate to Services. Completion loading/failure cannot redirect a signed-in user into a global wizard.

Routes:

- `/services`
- `/services/{serviceTypeId}`
- `/services/{serviceTypeId}/setup`
- `/services/{serviceTypeId}/status`
- `/services/{serviceTypeId}/setup/{documents,skills,availability,locations,additional,certificates,education}`
- `/services/{serviceTypeId}/setup/profile` for the preserved Basic Details/Market form

Setup shows applicable sections after persisted sub-service selection, filters dynamic fields to common fields and selected option fields, and excludes the former Service Options requirement card. Profile/market do not precede service selection. Documents now supports authenticated shared-document upload, registration, review states and safe replacement/deletion; remaining requirement submission forms are deferred; Basic Details retains its existing authenticated GET markets/PUT profile implementation, without NIC/passport controls.

Pending/approved/inactive services show status; approved services can view read-only setup information. Optional and disabled requirement sections do not independently block pending approval. Approval itself always requires backend verification, never a local completed count.

See [the service-first architecture, contracts, tests and exact changes](../../docs/provider-service-first.md). Earlier onboarding/requirements/options documents describe reusable implementation and historical routes, not the current navigation flow.

Documents implementation, backend contract, verification and exact changes: [Provider Documents](../../docs/provider-documents.md).
