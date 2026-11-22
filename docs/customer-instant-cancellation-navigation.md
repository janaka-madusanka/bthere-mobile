# Latest customer contract integration — 10 November 2026

Based on the customer API reference headed Compensation when a provider cancels,
followed by Booking notice, Book now and cancellation refunds. The latest dated
additions supersede contradictory older paragraphs in the same cumulative doc.
This completes the new customer-side behaviors that are specified there. Manual
device/API testing remains pending; do not claim backend deployment or live money
movement based on the stubbed tests.

## Notice and Book now

- Parse optional option.minimumNoticeMinutes / instantBooking. Explicit option
  notice takes priority over the older booking-request policy notice. Legacy
  responses without new option fields retain existing policy-based behavior.
- Enabled instant options initially offer Book now, with Schedule later as an
  explicit alternative. No service IDs or global notice overrides are hardcoded.
- Instant search/estimate/quote/create bodies sample current market-local time.
  Time-based end preserves the chosen duration; route bodies send pickup time
  and omit time-based interval fields. Waiting in the form does not send an old
  pickup time. No client adjustment of backend acceptance/start/deadline occurs.
- Stable comparison identities normalize only instant schedule timestamps so
  unchanged preferences/quotes do not disappear merely because time advances.
  Transport and idempotency snapshots retain the real complete outgoing body;
  uncertain booking writes retain the existing explicit recovery/no-auto-retry
  behavior. Quotes remain previews; the backend determines final availability
  and price, including time-sensitive pricing.
- Scheduled defaults use now + configured notice, rounded up to five minutes.
  With zero notice, Schedule later defaults to the next future slot. Calendar,
  quick dates and slider honor that lower bound and five-minute resolution when
  new option metadata is present. Existing validation blocks stale selections.
- Option-switch drafts retain the instant/scheduled choice. Switching to an
  option that does not allow instant booking moves an instant draft to a valid
  scheduled start while preserving duration/common answers.
- Existing server confirmationExpiresAt/payment-window flags remain the only
  payment countdown authority, including Book now. The document's instant-start
  vs service-start retry cap needs backend clarification, not a client guess.

## Paid cancellation and refunds

Owned Booking details offers Review cancellation only for funded CONFIRMED
jobs (CARD/PAID or WALLET/RESERVED). Started/in-progress/unpaid jobs cannot use
this action. Existing unpaid request cancellation stays on its existing route.

1. Reread own history to prevent a stale screen cancelling a started job.
2. GET /customers/me/bookings/{jobId}/cancellation-preview.
3. Show the server refund, retained amount when supplied, fee, policy tier and
   explicit wallet refund destination, including for card payments.
4. Require reason (1–100 characters), optional note (up to 1000), then an explicit
   Confirm cancellation. Keep booking / dismiss sends no cancellation POST.
5. POST /customers/me/bookings/{jobId}/cancel with reason, note/null and the exact
   numeric refundAmount from the shown preview as expectedRefundAmount.

No refund arithmetic or refund percentage calculation is performed in the app.
Amounts are validated with existing exact minor-unit helpers. Duplicate taps
are blocked. A 409 clears the preview and requires a fresh explicit review and
confirmation; it never silently accepts a smaller refund or retries a POST.

An unknown write reconciles using GET .../cancellation only. Failed reconciliation
keeps further writes blocked. A 404 plus a fresh owned CONFIRMED job permits a
new explicit preview/action; the backend's documented idempotent cancellation
remains responsible for exactly-once financial settlement. Confirmed saved
cancellation updates the header, removes START/tracking/actions, and refreshes
history/wallet. Auth changes discard late responses.

## Saved cancellations and compensation

- Paid cancelled history loads GET .../cancellation and shows the saved wallet
  refund, fee, policy/reason/note. REFUNDED, PARTIALLY_REFUNDED and
  CANCELLATION_SETTLED have readable history/detail payment labels.
- Provider cancellation encountered during preview preparation recovers the
  saved receipt without writing another cancellation.
- Compensation displays penalty.customerPaidAmount only. A lower paid amount
  than customerShareAmount shows a pending-recovery explanation, not a promised
  credit. Check compensation rereads the receipt without making a payment.
- Wallet history labels PROVIDER_PENALTY as Provider cancellation compensation.
  Monetary deltas/balances continue to come from the wallet ledger. Provider
  suspension data is not presented as an invented customer action.

## Directions

During supported live-map states, a valid target.navigationUrl offers Open
directions in Google Maps. The user must tap; there is no automatic external
navigation. Allow only HTTPS, known Google Maps hosts, a directions path/API and
a destination matching the owned target coordinates. Missing/malformed/off-host
links are hidden. External-app errors have retryable UI feedback. Tracking ETA
remains the documented direct-distance estimate; this button does not change
pricing or claim the app has road ETA.

## Verification and manual checks

Seventeen added tests cover notice precedence/default rounding, fresh instant
times after delay, time-based duration, quote retention/create payload, route
payload shape, mode switching, read-only preview/dismiss, required reason,
duplicate cancellation, changed-refund conflict, service-start/provider-cancel
races, unknown settlement reconciliation, failed reconciliation, identity loss,
actual credited compensation, large text and external-link validation/failure.
All tests use fake backend responses and fake URL launchers. No real refund,
compensation, cancellation, rating or booking is created by these tests.

Manual: use deployed instant-enabled Ride and scheduled Hospital Care options;
check current-time vs notice-constrained scheduling, both payment methods, cancel
preview/keep/reason/confirm, fee tiers/zero/full/partial refunds, refreshed wallet,
provider cancellation/partial compensation and safe navigation. Card refunds must
be explained as wallet credits. New endpoints/migrations and correct option
configuration must be present in the selected backend environment.

See [backend follow-up](backend-customer-follow-up.md) for the concrete remaining
configuration/contracts/questions. Firebase/APNs and provider GPS producer are
still required for real push/moving-provider device tests.
