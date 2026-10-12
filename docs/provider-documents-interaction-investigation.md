# Documents interaction investigation

1. **Concrete causes identified.** The current callbacks and modal subscription were traced rather than replaced. Missing metadata produced a generic operation error below the form, without field errors or scrolling it into view. Repository construction/read in submit happened outside the catch boundary, so a provider-resolution failure escaped instead of displaying an error. The same failure during initial load left loading flags set. During modal completion, a blind pop could dismiss a covering route; skipping pop for a covered sheet instead left an empty sheet. A covering-dialog regression reproduced that lifecycle failure and the final implementation removes only the editor's own route. These are concrete client failure paths; they are not proof of the cause of every reported live/native black-screen event.

2. **Why actions looked inactive.** A submit blocked by file/name/date validation could put a generic message outside the keyboard viewport. Dependency-resolution failure could terminate the action before its safe failure state. An unresolved native picker future legitimately leaves Selecting file active; the code now records safe stage markers to distinguish that from callback/validation/registration problems. No arbitrary timeout or retry delay was added.

3. **Busy recovery.** Existing successful/cancelled/failed picker tests did not establish a normally stuck busy flag. Picker now uses try/finally; submit repository resolution is inside its try/finally. Returned cancellation, exceptions, upload failure, registration failure and dependency failure release busy and phase. Pending selection blocks repeated invocation. Disposed refs are not written; new controller instances start idle. An unreturned native future remains active rather than permitting overlapping native activities.

4. **Modal lifecycle.** Main page and editor watch the same family instance. The page keeps it subscribed; autoDispose did not reproduce lost state. Opening captures the existing container and service ID before awaiting the modal. Single-presentation and single-close guards remain. Completion waits for refresh and pops the current sheet, or removes its exact active route when covered, leaving other dialogs and the Documents page intact. No repeated modal-open loop or self-triggering rebuild loop was found.

5. **Picker configuration.** The cached file_picker 13.1.0/Android implementation was inspected. `FileType.custom` with pdf/jpg/jpeg/png/webp is supported; Android converts extensions through MimeTypeMap and launches ACTION_OPEN_DOCUMENT for custom selection. RESULT_CANCELED returns null. The adapter awaits the native future, then reads file size and streams content later. No unsupported MIME combination or confirmed MissingPluginException was found. Native configuration/manifests and dependencies are unchanged. Explicit focus release before picker/submit provides intentional keyboard handoff; a pre-fix focused-field regression also passed, so focus was not established as the root cause.

6. **Submit validation.** Busy/no-draft guards previously returned silently. They now explain the block. Missing file, blank document name, invalid issued date and invalid required expiry each receive precise messages; name/issued/expiry errors appear inline. The modal renders the summary in error color and scrolls it into view on controller notification. Document number remains free text: the old client did not require nonempty numbers, so no new rule was invented. Dates retain YYYY-MM-DD calendar checks without future-date or ordering restrictions. Expiry visibility still follows the strictly parsed requirement.hasExpiry boolean. The live National Identity Card response was not supplied, so its actual flag cannot be inferred from a screenshot; debug edit markers report the flag without identifiers.

7. **Code changes and diagnostics.** Controller adds authoritative draft field errors, visible guard errors, protected repository resolution, load recovery, picker finally recovery and debug-only stage labels. Presentation adds inline errors, error visibility, explicit unfocus, captured modal inputs and exact-route closing. Safe `[ProviderDocuments]` events cover edit/hasExpiry, pick start/native request/native return-or-cancel/size lookup/idle, validation, upload, registration and refresh. Events never include tokens, numbers, file contents, filenames, keys, URLs or headers. Release builds do not print these diagnostics. Backend APIs, serialized fields, upload key retry and shared matching are unchanged.

8. **Regression coverage.** Ten new tests: visible missing-file errors; inline issued/expiry errors; focused pending-picker handoff; exception recovery; one pending picker launch and file result; keyboard-constrained error visibility; repository-resolution submit failure; no-draft submit explanation; initial loading failure/retry; and covered-sheet completion preserving another dialog. Existing 51 backend Documents tests are unchanged. Existing modal/retry/cancellation/delete/expiry/light-dark tests remain. The fake picker now supports a pending result, cancellation, success and exception.

9. **Tests.** 650 workspace tests pass: Provider 446, Customer 1, Design System 19, Network 46, Session 8, Auth 127, Common 3. Automated backend operations use fakes/in-memory transport.

10. **Analysis.** All seven members passed with no issues. Provider checks were repeated after final modal/diagnostic changes.

11. **Formatting.** All seven lib/test trees pass formatting: 153 Dart files, zero changes.

12. **APK.** `flutter build apk --debug --no-pub` produces `apps/provider_app/build/app/outputs/flutter-apk/app-debug.apk`. Final build passed; APK kernel includes DocumentEditorSheet and native-stage diagnostics. Root `dart pub get` passed.

13. **Exact intentional files changed (seven).** Ignored build/cache artifacts are excluded.

Updated:
- `apps/provider_app/lib/features/services/documents/documents_controller.dart`
- `apps/provider_app/lib/features/services/documents/documents_screen.dart`
- `apps/provider_app/test/document_editor_sheet_test.dart`
- `apps/provider_app/test/support/fake_documents_repository.dart`
- `docs/provider-documents-upload-ux.md`

New:
- `apps/provider_app/test/documents_interaction_recovery_test.dart`
- `docs/provider-documents-interaction-investigation.md`

14. **Emulator limitation.** SurfaceSyncGroup/Choreographer/viewport/IME messages alone do not establish a Dart crash or picker failure. Black-screen behavior was not reproduced in offline widget tests, and no live authenticated emulator session was mutated. It remains unconfirmed whether a live incident is rendering-only or a native activity/result issue. The final APK's debug stage markers identify where a future live interaction stops; do not treat this report as verification that emulator graphics problems are fixed.

No live backend mutations, commit, push or PR. Service-first routing, assignments, options, experience, auth/session and document request contracts are preserved.
