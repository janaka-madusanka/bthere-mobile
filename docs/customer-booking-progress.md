# Booking completion work: step 2 — service progress

The user approved the START-code card and requested the next individual step.
Booking Details now shows a compact Service progress card and expandable timeline
for CONFIRMED → IN_PROGRESS → AWAITING_COMPLETION_CONFIRMATION → COMPLETED.
These are actual server job states. Time passing never starts, completes or
cancels a booking. This initial progress step added no lifecycle write. The
subsequent customer completion-confirmation step is now implemented as described
in `customer-booking-completion.md`.

While the details route is current and the app foreground, active jobs poll the
customer-owned GET `/customers/me/bookings` every five seconds. Overlapping reads
are skipped; background/covered routes pause reads; resume refreshes immediately.
Completed/cancelled/expired jobs stop progress polling. Missing jobs/read errors
retain the last confirmed status with explicit feedback and a retry action.
Reads do not set a page-wide busy state or reset the scroll/timeline expansion.

On a status/payment change, the verified booking snapshot updates the header and
START-code widget immediately, then refreshes history for other views. Cached
history refreshes/errors do not temporarily replace the newer verified snapshot.
Account changes discard it. START-code expiry still has its own small UI timer;
its widget no longer sends duplicate status polls.

## Manual review

1. Hot restart (`R`) and open a paid confirmed Hospital Care booking's details.
   Service progress should show “Ready for your service”; expand the timeline.
2. With a booking inside the START-code window, let the provider start it using
   the code. Within the next foreground status read, the header should become
   In progress, the card should show “Service in progress”, and the START-code
   section should disappear.
3. When the provider requests completion, expect “Awaiting your confirmation”.
   The next implemented step now offers explicit customer completion confirmation;
   see its separate manual checklist before using it on a live booking.
4. Background/resume and scroll the screen. There should be no repeated full-page
   loading, scroll resets or automatic navigation.

The automated tests simulate these server transitions and verify read-only
behavior, error recovery, account isolation and paused polling. No live service
was started/completed or paid by the assistant.
