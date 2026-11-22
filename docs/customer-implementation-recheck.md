# Customer implementation recheck — 10 November 2026

Requested after connection/login interruptions in the development session.
Checked the current on-disk implementation and app integration, not only old
completion messages or saved test summaries. Existing uncommitted work preserved.

| Area | Audit outcome |
| --- | --- |
| Instant booking / notice | Option metadata parsed, market-local current-time payloads, preserved duration, notice-aware scheduled UI, option drafts and quote/availability comparisons connected. |
| Paid cancellation | Real Booking Details action, owned fresh preview, reason validation, exact shown expectedRefundAmount, conflict re-review, read-only uncertain-outcome recovery and receipt connected. |
| Refund / compensation | Saved cancellation and actual credited compensation shown; history labels and wallet invalidation wired. No client refund arithmetic. |
| START / service progress / completion | Real details components and explicit completion action remain connected; identity/state guards and existing tests retained. |
| Ratings / reviews | Completed-booking rating submission, search option ratings and public summary/review panels connected. |
| Tracking / navigation | Owned tracking status, live provider/target map, stale ETA handling, safe explicit directions launch and lifecycle polling connected. |
| Notifications / auth | Root host, Home settings, ownership-checked navigation, device binding and logout hooks connected; recovery issues below fixed. |
| Workspace integrity | No unresolved conflict markers in Customer lib/tests. Whitespace check passed. Added source files are present on disk and compile into the APK. |

## Issues found and corrected

1. A network failure after notification unregister but before successful logout
   left signingOut active while the account remained signed in. The retained
   session now re-arms notification registration after the failed logout.
2. After a secure-store binding read failure, a subsequent registration retry
   could bypass the unresolved account/API binding. Registration now requires
   successful binding preparation; explicit enable/retry recovers the binding.
   Async initialization also rechecks session identity before storing device ID
   or attaching listeners.
3. A missing/invalid session encountered by notification registration or owned
   push resolution now reconciles auth state instead of leaving cached login
   state active. No notification payload is used as authoritative booking data.

Two new failure tests were run before the fixes and failed as expected. After
fixing them and adding the missing-session regression, the auth/notification
subset passed 39 tests. These tests use fake API/gateway/storage data.

## Fresh verification

- Full Customer suite: **465 passed** (`build/recheck-full-tests.log`).
- Flutter analysis: **No issues found** (`build/recheck-analysis.log`).
- Current Android debug APK: **built successfully** (`build/recheck-apk.log`).
- `git diff --check`: passed. Existing CRLF notices are not check failures.

No real customer booking, cancellation, payment, compensation, rating, device
registration or provider journey was mutated during this audit. Tests and build
verify implementation and integration; they do not prove deployed API behavior,
live merchant settlement, Firebase/APNs delivery or real provider GPS movement.
Those still need the configuration/contracts in backend-customer-follow-up.md
and final manual device tests. No iOS native build was performed on Windows.
