# Documents upload UX correction

For the subsequent end-to-end audit, failure recovery and current verification, see [Documents interaction investigation](provider-documents-interaction-investigation.md). Counts below describe the initial modal correction.

1. **Root cause.** Upload/Replace called `controller.edit(requirement)` correctly, but the draft form was appended after all document cards. On a long screen the draft was below the viewport and the button appeared to do nothing.

2. **Interaction.** Upload/Replace first creates the selected requirement's draft with the existing controller, then immediately presents a modal editor. A presentation guard blocks repeated taps and prevents another requirement from replacing the open draft. The main Documents page no longer contains an inline draft form.

3. **Bottom sheet.** Reusable `DocumentEditorSheet` uses `showModalBottomSheet`, `isScrollControlled: true`, `useSafeArea: true`, a SafeArea, scrollable content and padding from `MediaQuery.viewInsetsOf(context).bottom`. It has no fixed height and follows the current theme/text scale. It shows the requirement name, allowed formats/100 MB limit, Choose file, selected filename, the reused DocumentMetadataForm, conditional expiry field, phases/progress, safe errors, submit/retry and Cancel. Outside-tap and drag dismissal are disabled; Cancel and idle system back dismiss safely. Busy state blocks back and editor actions.

4. **Controller reuse.** The sheet watches the same service-keyed DocumentsController through the existing ProviderContainer. `state.draft` is the sole draft. The editor calls `edit`, `pick`, `submit` and `cancel` without business logic copies. Controller, models, repositories, API paths/payloads, matching, expiry/review rules and completion logic are unchanged. Existing replacement metadata is preserved.

5. **Picker.** Choose file calls the existing controller.pick. Successful selection renders its filename in the sheet. Native selection cancellation stays in the editor, produces no error and preserves entered metadata. Native manifests, dependency versions and picker plugin configuration were not changed. Root `dart pub get` passed with an unchanged pubspec.lock.

6. **Success/failure/back.** Upload and registration failures keep the editor open with metadata and safe errors. On successful registration the sheet waits while the existing controller reloads documents and completion/setup, then closes when the controller finishes and clears its draft. The updated underlying card uses refreshed backend review data. Refresh failure retains the controller's existing page-level saved-but-refresh-failed error and retry behavior. Cancel or idle system back calls controller.cancel and clears unsaved draft state. System back marks the sheet closed before notifying the controller to prevent a second navigation pop. Busy operations cannot be destroyed by back, barrier taps, drag or duplicate submit.

7. **Partial-registration retry.** An upload key already retained by the controller changes the sheet action to Retry registration. The same key is reused without another upload. No temporary key storage or new transaction logic was introduced.

8. **Tests.** Added 13 modal widget regressions: immediate visible entry from the first card of a long list; replacement metadata/expiry; picker invocation/filename; picker cancellation; Cancel/reopen; system back; repeated taps/requirement consistency; upload failure; registration retry and refreshed status; busy action/back/barrier protection; waiting for refresh before closure; and narrow keyboard-safe large-text light/dark layouts. Two existing Documents widget tests now enter through Upload document rather than directly creating an invisible draft. The shared fake picker records calls. All original 51 Documents tests, including authenticated transport/serialization/deletion/controller coverage, remain and pass; targeted old/new Documents tests total 64.

9. **Workspace tests.** 640 passed: Provider 436, Customer 1, Design System 19, Network 46, Session 8, Auth 127, Common 3. Automated requests use fakes/in-memory transport; no live backend mutations were performed.

10. **Analysis.** All seven workspace members passed with no issues. Provider was rechecked after removing an unused new-test import.

11. **Formatting.** All seven members' lib/test trees passed `dart format --output=none --set-exit-if-changed`: 152 Dart files, zero changes.

12. **APK.** Provider debug APK verification uses `flutter build apk --debug --no-pub`; output is `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`. Build passed. APK Dart kernel was checked and includes DocumentEditorSheet. Device file selection was not invoked during this correction.

13. **Exact intentional changes: six files.** Generated build/cache artifacts are excluded.

Updated:
- `apps/provider_app/lib/features/services/documents/documents_screen.dart`
- `apps/provider_app/test/provider_documents_test.dart`
- `apps/provider_app/test/support/fake_documents_repository.dart`
- `docs/provider-documents.md`

New:
- `apps/provider_app/test/document_editor_sheet_test.dart`
- `docs/provider-documents-upload-ux.md`

Service-first navigation, main/sub-service selection, experience, assignment creation and all document backend behavior are preserved. No commit, push or PR was created. Scope stops at the Documents editor UX correction.
