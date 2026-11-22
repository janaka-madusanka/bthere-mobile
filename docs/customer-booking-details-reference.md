# Booking Details reference upgrade (19 November 2026)

The existing booking/payment APIs and write guards are retained. This is a presentation upgrade across ready, active, awaiting completion confirmation, completed, reviewed, cancelled and unpaid/retry states.

## Layout and actions

- Teal gradient header with soft circles and rounded pale body; one white booking card, Public Sans/app typography, selected service option name, booking ID and state pill (no service icon).
- Ready countdown uses an explicit timestamp offset or a known booking market timezone. Missing timezone is not replaced with the device timezone. Reaching the scheduled start never starts the service automatically.
- Provider row keeps real name/photo and authorized phone/call; adds a booking chat button opening a rounded keyboard-aware sheet. No invented online indicator or unsupported attachment button. Team members share the booking chat.
- Service map uses valid booking coordinates or the tracking API target. Active live tracking keeps backend polling/privacy/staleness rules. A single fresh travelling provider can show blue road geometry through the existing Google Routes integration. Route refresh requires meaningful movement and is limited to once per minute (target changes refresh immediately). Stale data removes the route; unavailable routes keep real pins, not a made-up straight line. Team maps keep individual pins without guessing a primary route. Fare and ETA remain server-owned.
- Compact schedule/location tiles and actual payment amount/status; no hardcoded Partially paid label. Same-day schedules omit duplicated dates. Duration is scheduled time, not elapsed provider work.
- START banner is hidden more than 30 minutes before a trustworthy start instant; when timing context is unknown, the existing explicit Show code action still relies on the backend verification window. Code reveal/hide/copy, expiry, account and payment restrictions are unchanged.
- Four backend service stages remain supported. The optional timeline dropdown was removed after review; awaiting customer completion keeps its explicit confirmation button visible. No automatic completion/payment.
- Patient/dynamic booking answers are collapsed by default. Cancellation still previews the actual refund before the explicit reason/confirmation flow; cancelled refund/compensation details are retained.
- Completed unrated bookings show Add a Review; saved single-provider feedback moves to a compact stars/comment panel below patient details. Unknown rating writes retain existing GET-only reconciliation.
- Unpaid details embed a teal payment-recovery banner with the authoritative deadline and existing retry/status route. Provider matching, payment confirmation and cancellation behavior are unchanged.
- Full-page skeleton now matches the new header/map/tiles structure. Existing data remains visible on background refresh.

## Data limits / live review

- The initial Booking #36 preview showed the location fallback. A later contract review found that BookingResponse uses flat latitude/longitude, while the helper handled only nested projections. That frontend mapping is now corrected and regression-tested; the fallback did not establish that backend coordinates were absent. No new map API is required for the documented fields. Truly null/invalid coordinates still show an honest fallback; a trustworthy market/timezone is required for a wall-time countdown, and device GPS is never substituted.
- The first live visit hit temporary provider/rating read failures. The final run returned HTTP200 for both Booking #36 endpoints and rendered the assigned provider successfully. HTTP status-only debug diagnostics cover these two owned-booking GET paths; no response bodies, private photo URLs, tokens or chat text are logged.
- Chat presence/online state is not in the current API. Call visibility continues to follow server contact.callAllowed plus booking lifecycle restrictions.
- Routes require the app's existing Google Routes/Maps key configuration and Google Routes service availability; no new backend route endpoint was introduced.

## Verification

Tests cover real location pins/routes and stale-route removal, timezone conversion/countdown, collapsed answers, narrow/enlarged text, chat sheet keyboard handling, and existing payment, START, four-stage progress, completion, cancellation and rating flows. Automated tests use fake services and make no real booking/payment/chat/document writes.


## Accepted UI and normal-app integration (20 November 2026)

- Normal `main.dart` → `CustomerBootstrap` → `/bookings/:jobId` uses the same production `CustomerBookingDetailsScreen` reviewed in the separate UI Lab. Booking list and payment confirmation both route here. The normal entry point imports no lab fixtures or sample API overrides.
- Details hides footer navigation and retains the Back action and safe system inset. Header shows the selected service option without a service image. Provider card follows the map; schedule shows month/day and start time only. Payment keeps the normal-size amount/status row; patient details are collapsible and cancellation is a quiet text action.
- Actual service timer uses server actualStartedAt/actualFinishedAt; customer completion-confirmation time does not extend service duration. Existing device-clock limitation remains until the referenced server clock-synchronization contract is provided.
- Full-page loading skeleton matches the unified details card. Error view is a scrollable, bounded white retry card. Previously loaded data is retained during background reads.
- Fixed cancelled/expired stepper overflow at 320px/2x text. Booking chat uses a compact header when space is limited and does not repeat the participant header in an embedded sheet.
- Accessibility matrix covers all 11 sample states at 320×568 and 568×320 with 2x text, plus provider/review/cancellation/START/chat actions and keyboard insets. All sample interactions remain offline.

Run the normal app for real account testing:

```powershell
.\scripts\run-customer.ps1 -DeviceId emulator-5554
```

UI Lab is an optional separate debug app; it is not the normal app entry point. A native debug build validates integration; real provider/payment end-to-end actions still require manual account testing.
