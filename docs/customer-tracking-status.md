# Customer journey status — step 7

Live map and notification code is now implemented in
[the remaining customer integration](customer-live-tracking-and-notifications.md).
The user's latest instruction postpones manual testing until this combined work
is ready, overriding earlier per-step manual-review pauses.

This is the first tracking step: a read-only status card in owned Booking details,
below service progress. Live GPS map/ETA/vehicle display, provider GPS production
and push are separate subsequent steps.

- For confirmed/in-progress PROVIDER_TO_CUSTOMER jobs, probe authenticated
  GET `/customers/me/bookings/{jobId}/tracking`. Historical job responses do not
  retain option context's liveTrackingSupported, so the owned endpoint itself
  decides support; no service IDs or tracking capability are hardcoded.
- NOT_SUPPORTED hides the card and stops automatic reads. The UI does not offer
  a map for unsupported options or fabricate a provider journey.
- Render server WAITING_FOR_CONFIRMATION / NOT_STARTED / EN_ROUTE / ARRIVED /
  IN_TRIP / ENDED as payment pending / Scheduled / Provider on the way / Provider
  has arrived / Trip in progress / Tracking ended. Full-trip arrival stays live;
  other arrival modes and ENDED stop polling. IN_TRIP requires FULL_TRIP.
- Use positive server pollIntervalSeconds, one read at a time, one-shot timer
  after each completed read. No local clock advances statuses. Unchanged reads
  do not notify/redraw the card. Existing service progress polling is separate.
- Pause requests when background or covered by another route. Resume refreshes
  immediately on app foreground; route uncover is checked at the next interval.
  No timer survives disposal. In-flight responses can be retained as last known
  status while background, but no further background polling is scheduled.
- Failed reads retain last status and add error feedback/explicit read retry.
  A 404 stops automatic reads until explicit retry. Initial endpoint failure
  does not create a retry loop or erase other booking details.
- Team bookings explicitly explain the overall endpoint status represents the
  furthest provider stage; it must not imply every team member has arrived.
- Logout/identity change discards late results and clears status. This feature
  does not start journeys, mark arrival, start/complete services or make payments.

Eight new tests cover status transitions, read-only requests, unchanged refresh,
server interval, failure recovery, missing/unowned data, overlapping reads,
logout, unsupported/terminal statuses, background pause and 320px/2x layout.

## Manual review

Hot restart and open an owned confirmed booking. An enabled tracking option
should show Scheduled until backend reports EN_ROUTE, then On the way / Arrived.
Background the app and return: status should refresh without a full-page loading
flash. Unsupported options should have no tracking card. If endpoint is not yet
deployed, other details remain usable and Check tracking status retries manually.

The supplied customer API document labels tracking implemented locally, not
deployed. Live state transitions require deployed backend and Provider journey
actions; no real journey mutations are performed by tests.
