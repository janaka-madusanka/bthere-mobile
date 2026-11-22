# Accepted request payment recovery

Implemented against the supplied Customer API reference's **Accepted booking
payment actions** update. The reference labels backend deployment unverified;
this change does not claim that the hosted API has been upgraded.

## Customer behavior

- Provider acceptance leads to the existing accepted-provider presentation with
  an explicit payment action. A definite failure keeps the same request, accepted
  provider and job. Retry never cancels the request or starts provider matching.
- `GET /customers/me/booking-requests/{id}/payment-window` supplies action flags
  and the actual UTC `confirmationExpiresAt`. There is no hardcoded 15-minute UI
  window. The updated backend starts a one-time retry window on the first verified
  card decline/cancellation or insufficient-wallet failure: acceptance defaults to
  120 seconds, then the first failure updates the deadline to failure time plus
  15 minutes, capped by service start. Further failures do not reset it. The UI
  always reads this deadline; it never adds time locally. `paymentRetryStartedAt`
  also restores the failure presentation when Wallet still reports NOT_STARTED.
  Provider extensions refresh within
  five seconds while visible, and immediately on resume.
- Final 30 seconds use the amber countdown warning. At zero, payment is disabled;
  authorized lifecycle reads determine whether the request is EXPIRED/CANCELLED.
- Pending/reconciliation/uncertain payments cannot pay or cancel. The client
  polls, never treats a browser redirect as proof, and never retries a write
  automatically. A durable account/environment-scoped uncertainty marker blocks
  another payment after a process restart. A stale FAILED snapshot from before
  an uncertain retry cannot unlock a second checkout.
- Home Recent and job details display compact payment request cards. Booking tab
  shows only its normal booking list; open a booking first to access payment.
  Opening payment always rereads its owned request and action window. Cards distinguish
  required/failed/pending/deadline-ended states and retain the same request ID.
- Confirmed results remain visible until the customer chooses booking details or
  Home. The refreshed booking history remains authoritative for job details.

## Recovery and methods

Creation saves request ID and chosen payment method in secure storage alongside
the existing environment/account scope. Own `booking-events?after=...` recovers
references on other devices or after missed push. References are saved before the
event cursor; events never supply authoritative prices or payment state. The
existing View has no guaranteed payment-method field, so the client restores the
saved method or joins the authorized job history by jobId. It does not guess it.
Account changes clear in-memory data and invalidate pending reads. Terminal
requests are not repeatedly fetched unless new events reference them.

Wallet uses existing `confirm-wallet`. Card settings select MOCK or PayHere on the
server: MOCK explicitly selects an owned saved card and posts only `{methodId}` to
`confirm-mock-card`. Hosted checkout posts required profile/contact/card-brand
fields to `confirm` and validates the signed HTTPS destination and amount before
opening the existing WebView. The customer never supplies amount or success proof.

The accepted-request API now supports
`POST /customers/me/booking-requests/{id}/payment-method` with
`{"paymentMethod":"CARD"}` or `{"paymentMethod":"WALLET"}`. The failure screen
opens an in-place picker, disables the current method, and refreshes the updated
request and action window after the switch. No cancel, new request, matching or
payment is triggered by selection. Backend enforces service-enabled methods,
unpaid acceptance, checkout and expiry restrictions; rejections remain visible.
The selected method is stored under the original account/API scope. An uncertain
switch blocks payment (also after restart) until an authoritative request View
supplies its method. Method changes and confirmations are never auto-retried.
Mock Card selection/Add Card stays in the failure screen and the selected card is
shown before explicit Retry payment. Hosted PayHere retains its secure checkout
flow; saved mock cards are not presented as reusable gateway tokens. Customer
cannot extend the provider's payment deadline.

If the new action endpoint is missing, invalid or disagrees with the request
snapshot, payment actions remain unavailable with a visible retry-status action.
Deployment of `/payment-window` and the matching backend policy/data migration
must be verified separately. Live merchant charging and real-device integration
were not exercised by the implementation tests.

## Verification

Controller tests cover same-ID Wallet retries, mock/hosted card contracts, action
flags, expiry, extensions, pending/reconciliation, missing endpoint, persistence,
account/environment isolation, logout during reads, stale failure after uncertain
retry and concurrent taps during polling. UI tests cover Home/Booking/details
navigation, explicit confirmation/details navigation, countdown warning and
extension, accepted card contact/errors and background polling without disabling
the payment button. Old cancel-and-rematch failure expectations were replaced by
the accepted-request contract.

## Failure presentation correction (2026-11-07)

Definite Wallet balance errors (retryable HTTP 409 with NOT_STARTED) and other
payment-action rejections open the existing branded Payment Failed screen,
including its failure artwork and payment detail card. The failure screen now
supports a same-request variant with the backend deadline, final-30-second amber
warning, Retry payment and Home. It does not show the obsolete cancel/rematch
copy or unsupported method-type switch action. Read/status errors alone do not
claim that a payment failed; pending/uncertain results keep their read-only UI.
The failure presentation survives background polling and the request/provider
are retained when retrying. A 320px/2x-text regression covers scrolling and retry.
The separate payment banner above the Booking tab list was removed; Home Recent
recovery and the action inside the selected booking's details are retained.

## Delayed card success refresh (2026-11-11)
Hosted payment completion detected by request polling or app resume refreshes booking history, wallet and request recovery, as well as rendering confirmation. Repeated unchanged terminal reads do not repeatedly publish the transition. A pre-payment local details snapshot yields to funded history so returning to an already opened booking shows the current paid status. Automated regression uses owned fake API reads and performs no financial POST.

## Details recovery latency (2026-11-11)
Details use a job-targeted read independently of the full event/recovery scan. Local job/request references are account/API scoped hints, always verified against the owned request View. Existing installations fall back to newest saved request references; no booking/request ID equivalence is assumed. Bulk results publish progressively, and payment-window metadata cannot erase View identity fields. Awaiting details show status-loading feedback before resolving a deadline. Unchanged funded requests can refresh a still-unpaid cached job list until it catches up.
Debug Customer runs emit sanitized 'Booking payment:' lifecycle lines for request reads, window, method switch and confirmation endpoints. Card selection/confirmation UI alone is not evidence of PAID; use the owned request status and actual confirmation response. User's live TEST CARD result remains under investigation; no charge was repeated automatically.
