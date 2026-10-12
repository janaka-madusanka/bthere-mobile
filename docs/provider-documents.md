# Provider Documents implementation report

The editor presentation is now a modal bottom sheet. See [Documents upload UX correction](provider-documents-upload-ux.md) for the current interaction, checks and exact change manifest. The counts and manifest below describe the original Documents implementation.

1. **Requirements architecture.** `/services/:serviceTypeId/setup/documents` replaces only the Documents placeholder. The existing setup controller guards initial entry with an existing assignment and saved valid sub-services. Presentation uses a service-keyed Riverpod controller, injectable picker and Documents repository. The repository uses the shared ApiClient and safe Result/AppFailure handling. Requirements load from authenticated GET `/provider-types/{serviceTypeId}/document-requirements`; IDs and all required/optional, expiry and approval booleans come from this endpoint. The title uses the main-service name, e.g. Caregiver Documents. Empty requirements have an explicit state.

2. **Existing documents.** Authenticated GET `/providers/me/documents` parses a bare array of the Provider Document shape confirmed in this conversation. It retains documentId, documentTypeId, documentTypeName, documentName, documentNumber, documentKey, issuedDate, expiryDate, verificationStatus, rejectionReason and createdAt. Null optional review fields are accepted; no speculative fields or envelope aliases are introduced. Malformed data yields a safe retry state.

3. **Shared matching.** Documents match by documentTypeId, never assignment ID. An approved, unexpired match is preferred and shown as satisfying this service. Approved matches offer no upload or delete action. Required/Optional and Approval required labels come from the backend; optional cards do not gate navigation or require local submission.

4. **Picker and upload.** `file_picker` 13.1.0 uses the native single-file picker with PDF/JPG/JPEG/PNG/WebP extension filtering. Selection size is checked before upload, with a conservative 100 MB = 100,000,000-byte limit. Empty, oversized and unsupported files are rejected. Files stream into authenticated multipart POST `/uploads/documents`; the multipart field is exactly `file`. Selection, upload progress, registration and refresh have distinct states. No application permission changes are introduced. Android's plugin manifest uses a GET_CONTENT query without broad storage permissions. Provider Flutter plugin registration was regenerated after root `dart pub get` and verified for Android and iOS.

5. **Upload response/key.** The upload parser requires key, url, contentType and positive size. Registration uses `key` exclusively; URL is never used as documentKey or displayed as an action. Shared ApiClient gained an upload method that retains its existing auth/path/error policies and forwards send progress.

6. **Metadata form.** Document name defaults to the requirement's name. Replacement pre-fills known submitted name/number/issued/expiry metadata. Document number remains free text without format, length or identity-number rules. Issued date uses YYYY-MM-DD calendar validation, without age/future-date/ordering rules. Expiry is shown and supplied only for hasExpiry=true; otherwise the JSON value is null. Entered metadata survives file/registration errors.

7. **Registration.** Authenticated POST `/providers/me/documents` sends exactly documentTypeId, documentName, documentNumber, documentKey, issuedDate and expiryDate. HTTP 201 is accepted; an undocumented response body is not required for success. Busy and post-success draft clearing prevent duplicate submission. Successful registration stays on Documents.

8. **Review UX.** PENDING renders Pending approval, APPROVED renders Approved, and REJECTED renders Rejected with an available rejectionReason. Pending does not force another upload. Unknown review statuses remain Status unavailable. A documented expiryDate earlier than the current calendar day renders Expired; the expiry day itself remains valid. Date-only comparison does not turn today's date into yesterday due to device timezone offsets.

9. **Replacement/deletion.** Replacement uses the same Provider-level POST and warns that shared verification resets to pending and may affect other services. No delete-before-replacement request is sent. Pending/rejected documents offer confirmed DELETE `/providers/me/documents/{documentId}`. Approved deletion is blocked in the UI, controller and repository, including expired approved documents.

10. **Partial failures.** The upload result lives only in the draft's in-memory state. A failed registration retains its upload key and metadata. Retry performs registration alone with the same key. Choosing a valid replacement file clears the previous upload result; cancellation or invalid selection preserves it. Temporary keys are never written to secure storage. Leaving/cancelling discards the draft.

11. **Authoritative refresh/navigation.** Registration and deletion reload shared documents, reload Provider completion and invalidate selected-service setup. Current screen/controller remain mounted across parent refresh. Refresh failure reports that the mutation was saved and offers refresh retry, without re-registering the cleared draft. Backend documentsCompleted remains authoritative; no local completion flags, selected options or experience are changed. Back and system back return to `/services/{serviceTypeId}/setup`, and mutation progress blocks duplicate actions/back navigation. No global Documents onboarding route is added.

12. **Tests.** 51 offline tests cover requirement parsing and exact authenticated paths; confirmed Provider document fields/shared matching/approval/expiry; file formats/size/streamed multipart/progress/upload key; exact registration keys and 201; both expiry cases; duplicate guards; upload/registration failures and retained-key retry; deletion paths/approved guards/confirmation/cancellation; refresh failure; visible metadata retention; loading/error/retry/empty/review labels; narrow light/dark layouts; and real service routing/parent completion refresh with preserved sub-services. The former service-first placeholder test now uses a shared document fake and expects the real Documents empty state. Automated tests use injected repositories or an in-memory HTTP adapter, with no live backend calls.

13. **Workspace test results.** 627 tests passed: Provider 423 (including 51 Documents tests), Customer 1, Design System 19, Network 46, Session 8, Auth 127, Common 3.

14. **Analysis.** All seven workspace members passed analysis with no issues. Provider analysis was repeated after the regression test update.

15. **Formatting.** All seven members' lib/test trees passed `dart format --output=none --set-exit-if-changed` (151 Dart files, zero changes).

16. **APK.** Provider debug APK built successfully with `flutter build apk --debug --no-pub` after native picker registration was regenerated. Artifact: `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`. APK contents were checked for both the native FilePickerPlugin class and DocumentsScreen in the Dart kernel. No live upload/registration/deletion or emulator backend mutation was performed. This Windows verification does not build iOS.

17. **Exact intentional file manifest (14 files).** Generated ignored plugin metadata/registrants and build/cache artifacts are excluded from this source/documentation list.

New:
- `apps/provider_app/lib/features/services/documents/document_models.dart`
- `apps/provider_app/lib/features/services/documents/documents_repository.dart`
- `apps/provider_app/lib/features/services/documents/documents_controller.dart`
- `apps/provider_app/lib/features/services/documents/documents_screen.dart`
- `apps/provider_app/test/provider_documents_test.dart`
- `apps/provider_app/test/support/fake_documents_repository.dart`
- `docs/provider-documents.md`

Updated:
- `apps/provider_app/lib/app/router/app_router.dart`
- `apps/provider_app/pubspec.yaml`
- `apps/provider_app/test/service_first_test.dart`
- `apps/provider_app/README.md`
- `packages/bthere_network/lib/src/client/api_client.dart`
- `pubspec.lock`
- `docs/provider-service-first.md`

18. **Contract concerns/limits.** The missing existing-document response shape was supplied and is now implemented. Requirements/document lists are bare arrays. There is no documented uploaded-file cleanup endpoint: cancelling after a successful upload or abandoning failed registration can leave an unregistered server object, whose cleanup remains a backend concern. Temporary draft recovery after app restart is intentionally absent. The documented 100 MB limit does not specify decimal/binary units; this implementation chooses the conservative decimal boundary. No idempotency contract was supplied, so a lost registration response can require retry; duplicate user taps are blocked, and documented same-type replacement behavior is used. Local optional-document labels never supersede backend completion. Native picker invocation/upload against a real device/backend remains manual verification; automated requests are isolated. Auth, secure persistence, expiry handling, registration/OTP, dormant Google, service-first assignment/options and experience behavior retain their existing regression coverage.

No commit, push or PR was created. Work stops at Documents implementation.
