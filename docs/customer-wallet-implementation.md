# Customer Wallet implementation reference

Source: [full Customer API reference](customer-api-reference-2026-10-25.md),
provided by the user. Keep the full reference verbatim. Its latest dated sections
supersede older conflicting examples. The reference says current booking-request
updates are implemented locally, not deployed; verify the actual configured API
when testing. Do not assume merchant/device integration has been verified.

## UI direction

Await the user's Wallet reference image before implementing its middle content.
Ignore the reference image's header/footer. Reuse CustomerTopBar and the existing
compact CustomerBottomNavigation with Wallet selected. Apply the existing shared
header/footer to future main destination pages; booking/map-specific controls
must retain their necessary workflow controls.

## Wallet contract

- Authenticated CUSTOMER; owner derives from the access token, never send userId.
- LKR only, even when an active market uses another currency. No conversion.
- GET /me/payment-settings: capability flags for generic wallet operations.
- GET /me/wallets/LKR: authoritative available/reserved/pending/status/fundingMode.
  A 404 means not opened. PUT /me/wallets/LKR (no body) explicitly opens it.
- GET /me/wallets: list owned wallets.
- GET /me/wallets/LKR/transactions?page=0&size=20: Spring Page, newest entry first.
  Read actual pagination metadata. Group entries by operationId so ledger bucket
  movements do not appear as multiple charges. Historical operation metadata can
  be null. Do not infer missing wallet from an empty history.
- GET /me/wallets/LKR/reconciliation: if balanced=false, block actions and present
  a support state. Do not attempt repair.
- Only available is spendable; reserved and pending are separate. Label MOCK and
  PAYHERE_SANDBOX clearly as test funds; UNFUNDED/PAYHERE/null are distinct states.
- Decimal-safe money handling, positive amount with at most two decimals and max
  99999999999999.99. Do not silently round invalid user input or author balances.

## Generic methods and money actions

These are MOCK-only in this contract, not live card/bank integrations.

- GET /me/payment-methods lists returned IDs, labels and states.
- POST /me/payment-methods/setup?type=CARD or BANK_ACCOUNT (no body) creates/reuses
  synthetic VERIFIED_MOCK methods. Never collect real PAN/CVV/bank credentials.
  No default/edit/delete or real hosted method-linking API is documented.
- POST /me/wallets/LKR/topups: amount, optional methodId; Idempotency-Key required.
- POST /me/wallets/LKR/withdrawals: amount, required owned test bank methodId;
  Idempotency-Key required. Available is reserved immediately, not paid to a bank.
- GET /me/payment-intents/{id}: recover actual status after timeout/retry.
- POST /me/mock-payments/{id}/events: explicit mock testing only. Never call it
  automatically to manufacture a successful payment. PENDING is not success.
- Persist the same key and input for a logical retry; top-up/withdrawal share a
  key namespace. Refresh balances from the backend after confirmed outcomes.
- Capability-gate actions; do not offer unsupported live payouts or funding.

## Scheduled booking request distinction

Enabled requests support CARD or WALLET under the selected option policy.
POST /customers/me/booking-requests creates the request with an idempotency key;
creation/ringing does not reserve wallet money. Provider acceptance precedes
explicit POST /customers/me/booking-requests/{id}/confirm-wallet (no body). The
server reserves the fare once and returns CONFIRMED/RESERVED. Structured 409
code=INSUFFICIENT_WALLET_FUNDS carries the shortfall. Do not match detail text.
paymentFundingMode is the funds' source, not the selected paymentMethod.
Legacy /customers/me/bookings/{jobId}/wallet-payment is a separate flow. Generic
payment capability flags do not describe hosted scheduled-request CARD checkout.

## Implemented initial screen

### Add Card dialog

The supplied Add New Card reference is implemented behind capability-gated Add
test card. Cardholder name, formatted PAN, expiry and masked/revealable CVV have
inline validation. Local checks: Unicode names, Visa/Mastercard length/prefix
(including Mastercard 2-series), Luhn, valid MM/YY through expiry month end, and
3-digit CVV for these supported brands. These checks do not verify issuer/card
ownership, funds or authorization, and do not establish PCI compliance.

Current contract only creates a synthetic backend method. The form explicitly
says Test mode and accepts only 4242 4242 4242 4242, a valid expiry and a test CVV.
Inputs never enter repository/controller arguments, request bodies, storage or
logs. Controllers clear on close, before submission and on backgrounding. The
existing setup request has no body and the method label comes from the refreshed
server response; entered brand/name/expiry are not purportedly saved. No unsupported
Save card checkbox or unverified encryption claim is shown. Close/double-submit
are blocked during the request; uncertain results require a wallet refresh.

Real linking is blocked by the absent backend/gateway setup contract, not solved
by local validation. [PayHere preapproval](https://support.payhere.lk/api-%26-mobile-sdk/preapproval-api)
collects credentials on hosted gateway pages. [PCI SSC CVV guidance](https://www.pcisecuritystandards.org/faqs/1319/)
prohibits retaining verification codes after authorization, even encrypted.

Backend work needed for live linking: an authenticated hosted setup-session API;
trusted HTTPS launch/return handling and owner-scoped status recovery; verified
server callback/tokenization; safe method metadata (ID, brand, last4, expiry,
status), explicit consent and supported brand/capability metadata. The backend
must never return PAN/CVV. A browser redirect alone must not mark linking verified.
This is required work, not an endpoint already present in the supplied contract.

Checks cover invalid/expired/current-month dates, Mastercard BIN boundaries,
checksum/length, Unicode names, CVV length, non-test number rejection, formatting,
reopening without prior inputs, keyboard/large text and no-body setup integration.
Dialog preview: build/wallet-previews/add-test-card.png.

Wallet now routes to /wallet with shared CustomerTopBar and compact selected
Wallet navigation. The supplied screenshot's middle content guides the balance
card and dashed payment-method/history empty states. Balance privacy toggle,
pull-to-refresh, error/retry, explicit missing-wallet opening and paginated
operation-grouped history are implemented. No money mutation happens on entry.
Auth changes clear data; stale requests cannot restore another session's funds.

Reserved and Pending replace the screenshot's Total spent: no authoritative
spend-summary endpoint exists, so a paginated ledger is not summed into a lifetime
total. LKR is fixed by the contract, not inferred from the market currency.

Manage/Add new payment method show server methods and explain mock-only linking;
explicit Add test card/bank account actions require capability flags and an active,
reconciled wallet. No PAN/CVV/account fields or unsupported edit/delete controls.
Add money currently explains that live top-ups are not available; it does not
create payment intents or simulate a success. A full test top-up flow and future
live funding design are separate from this initial screen.

Validation: 228 Customer tests pass, including exact decimal formatting, 404/open,
503/retry, reconciliation, explicit mock setup, history deduplication/pagination,
logout with an outstanding read and narrow 2x-text layout. Rendered preview:
apps/customer_app/build/wallet-previews/initial-wallet.png using
tool/wallet_preview_test.dart. Actual deployed backend/device testing remains.

### Add Money sheet (2026-10-28)

Implemented quick/custom amounts and explicit saved-card selection matching the
provided reference. Uses documented mock topup API; real card charging remains
unavailable. Backend topups capability gates the CTA. Existing Add Card dialog
is reused. Pending input and idempotency key persist in encrypted storage scoped
to account/API environment before any write. Retry reuses the original intent;
no credit is shown for PENDING. Complete test payment is explicit, refreshes
intent first, then simulates SUCCESS and reloads server wallet balances. No
manual balance calculations. Wallet regression suite: 13 passed; analysis clean.
