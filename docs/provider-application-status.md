# Provider application status

`/services/:serviceTypeId/status` displays the under-review or rejected application layout. Home service cards, registered catalog services, and setup redirects use this route for pending or rejected applications. Successful registration shows the step 5 All Set screen, with its status determined by refreshed completion. A rejected submission opens its correction status page. Approved and inactive services retain their existing status views.

The page reads completion, assignment, onboarding requirements, documents, and registration records through the existing repositories. Required rows, labels, verification states, and rejection reasons come from those responses. The illustrated screens do not seed sample documents or approval states. Failed reads show a retry action.

Rejected document rows open the existing document editor. Other correction rows open their corresponding setup section. Update and Resubmit opens the first item requiring correction; the existing registration flow saves changes and reloads server completion. The documented API recalculates application verification automatically, so there is no invented submit/resubmit endpoint.

A replacement is labelled Document re-uploaded only when the backend returns PENDING and its uploaded key matches locally recorded successful replacement history. That history is stored separately from registration drafts, scoped to the signed-in account and service. It does not override server approval or rejection.

Pull to refresh, returning from an edit, and resuming the app reload status. Go to Home returns to the provider home screen.

The registered sub-service rows on the service overview also open Application
Status when their own verification status is PENDING or REJECTED. The badge and
the rest of the row share that action. A rejected registered option selects the
rejected application view even while aggregate assignment/completion data remains
PENDING. Opening status performs reads only; it does not restart registration.
Pending registered sub-services also keep the application in the review view
when aggregate assignment/completion data is already APPROVED.

Design assets are bundled in `apps/provider_app/assets/application_status/`. Focused checks: `flutter test --no-pub test/application_status_test.dart` covers server-derived review items, unknown states, upload history, both catalog routes, document editing, retry, golden images, and narrow-screen large text.
