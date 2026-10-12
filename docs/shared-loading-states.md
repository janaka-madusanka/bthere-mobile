# Shared loading states

`BThereLoadingState` is exported by `bthere_design_system`. Use it for page and
section loading with a caller-supplied `label`, optional supporting `message`,
and optional `placeholder`. Set `compact: true` for fields and inline sections.
Its loading announcement is a single live-region semantic node; decorative
indicators and placeholders do not produce duplicate announcements.

`BThereSkeleton` supplies neutral, non-interactive placeholder blocks. The
Services screen composes eight placeholder tiles with its existing responsive
grid, followed by real backend content when requests finish. Placeholder tiles
are decorative and never introduce fake service names or tap targets.

The Provider app uses shared states for startup, account checks, service catalog,
service progress, service detail/status transitions, setup, requirements,
service options, market selection and document reads. Existing small
`BThereLoadingIndicator` instances remain appropriate for buttons and refresh
actions; real document upload progress retains its progress bar. No request,
error, retry, submission, session or routing behavior changed.

Verification: 731 tests across all seven workspace members passed (517 Provider,
23 design system, 1 Customer, 46 network, 12 session, 129 auth, 3 common).
Workspace analysis found no issues. Formatting checked 191 Dart files with no
changes. Provider debug APK build passed. Actual-widget loading preview passed
and was visually inspected at `apps/provider_app/build/provider-shell-previews/services-loading.png`.

No dependency additions, live backend mutations, commits, pushes or PRs.
