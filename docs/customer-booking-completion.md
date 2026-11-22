# Booking completion work: step 3 — explicit customer confirmation

The user requested continuing the next individual feature while waiting for the
backend's scheduled-booking minimum notice window. This step connects
`POST /customers/me/bookings/{jobId}/confirm-completion`, with no body or code.
No provider lifecycle endpoint, payment checkout or new wallet debit is called.

## Behavior

- Confirm service completion appears only for an owned job in
  AWAITING_COMPLETION_CONFIRMATION with funded CARD/PAID or WALLET/RESERVED state.
- A white confirmation dialog explains that the service must actually be
  finished, reserved funds/provider earnings will be settled, and no additional
  payment is made. Not yet/dismissal sends no mutation.
- After explicit confirmation, wait for an existing status read, then reread the
  owned job before sending a single POST. A state changed by another device
  cannot be confirmed from stale UI. Concurrent taps cannot duplicate the POST.
- A valid successful COMPLETED transition updates details in place, refreshes
  history and invalidates the customer's wallet data. No automatic navigation.
- Read the job after success for the real payment/settlement state. A briefly
  stale history response cannot roll a verified completion back; keep reading
  the payment summary until the server returns SETTLED. Never calculate money.
- Rejections keep the awaiting state and show the backend reason. Unknown
  network/5xx/malformed outcomes reconcile via GET only, never an automatic POST
  retry. A fresh owned awaiting state permits another explicit confirmation;
  completed state disables further confirmations. Backend atomic/idempotent
  settlement remains authoritative.
- Identity changes discard late responses. Tests perform no live settlement.

## Manual checklist

1. Hot restart (`R`). Start the service through Provider app using a valid
   customer START code, then use Provider Request completion.
2. Customer Booking Details should become Awaiting your confirmation and show
   Confirm service completion.
3. Open the dialog and choose Not yet: state and balances must remain unchanged.
4. Reopen and confirm only for the finished test service. Expect Service
   completed, completed header/history and server-updated payment summary.
5. Confirm button must disappear; leaving/reopening must retain the completed
   state. Wallet uses SETTLED on the job; CARD request receipt may retain PAID
   while the job shows SETTLED. Do not confuse request/job payment states.

Tracking, background push and backend-dependent provider details/refunds/disputes
remain separate subsequent features. Manual device testing of this step is still
required; automated tests use stubbed backend responses.
