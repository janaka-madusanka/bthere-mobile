# Provider wallet

Contract: *Complete Provider Registration and Service Approval API Flow (2)*,
pages 35–43, wallet implementation dated 17 October 2026. The document says
local implementation exists; deployment has not been verified.

All endpoints below use the existing authenticated API client and its configured
`/api/v1` base. Ownership comes from the access token.

| Method and path | App use |
| --- | --- |
| `GET /me/payment-settings` | Capabilities on entry, resume and refresh |
| `GET /me/wallet-capabilities` | Direct capabilities in Wallet details |
| `GET /me/wallets` | All supported wallets in Wallet details |
| `GET /me/wallets/LKR` | Authoritative available, reserved and pending balances |
| `PUT /me/wallets/LKR` | Open a wallet only after balance GET returns 404 |
| `GET /me/payment-methods` | Saved cards and bank accounts |
| `POST /me/payment-methods/setup?type=CARD` | Synthetic test card setup, no body |
| `POST /me/payment-methods/setup?type=BANK_ACCOUNT` | Synthetic test bank setup, no body |
| `POST /me/wallets/LKR/topups` | Amount, actual method ID and persistent idempotency key |
| `POST /me/wallets/LKR/withdrawals` | Available funds only, selected bank method and persistent key |
| `GET /me/payment-intents/{intentId}` | Recover a pending or interrupted request |
| `POST /me/mock-payments/{intentId}/events` | Explicit “Simulate success/failure” test controls |
| `GET /me/wallets/LKR/transactions?page=0&size=20` | Recent operations and paginated full history |
| `GET /me/wallets/LKR/reconciliation` | Block payments if balance verification fails |

Wallet details reads the list-wallet and direct capability endpoints alongside reconciliation. Payment status supports retained device payment IDs and manual owner-scoped intent lookup. No administrator, gateway selection,
or customer booking payment APIs are called.

## Payment handling

- Monetary values use integer hundredths (`BigInt`). Incoming monetary JSON
  tokens are preserved before JSON number decoding; outgoing amounts are raw
  decimal JSON tokens. Maximum amount and two-decimal precision follow the PDF.
- A secure, account-scoped request journal records purpose, amount, selected
  method and retry key **before** creation. A timeout leaves that request pending;
  retry reuses the same key, including after restarting the page/app. Returned
  intent IDs are retained for status checks. No automatic success event is sent.
- Only a server `SUCCEEDED` response reports completion. The app reloads balances
  after a result; pending/reserved buckets are never added to available funds.
- A reconciliation failure, inactive wallet, incompatible funding mode, or disabled
  capability blocks the relevant actions. A 503 triggers a settings reload.
- Wallet entry timestamps have no timezone offset. Their supplied wall time is
  displayed without inventing a timezone conversion. Entries sharing an
  operation ID are grouped without summing internal bucket transfers into charges.

## Design and backend limitations

Figma file `IQjgwcnUnxHd34avAUVhyQ`, page `0:1`: wallet reference `416:2081`
and balance-banner reference `416:2045`. These nodes are flattened raster images,
not editable wallet components or separate illustration assets. The screen is
rebuilt as native interactive Flutter widgets; the wallet illustration uses native
icons, so the artwork is an approximation. No screenshot is shipped as the UI.
The existing Bthere header and five-tab navigation are reused.

The current API offers mock payments only; PayHere and real bank payouts are
unimplemented. Test funds/methods and explicit simulation controls are labelled.
Default-method flags, method edit/delete, mobile-money methods, client names,
service names and transaction purposes are absent from these response shapes.
The app shows actual method labels, capability-appropriate actions, and ledger
operation/bucket details rather than fabricating those design fields.

## Wallet loading correction (19 October 2026)

The live balance endpoint returned successfully, but decimal scale/exponent forms were rejected by the client amount parser. Incoming values now normalize to exact integer hundredths, including trailing zeroes and scientific notation; nonzero sub-cent values are rejected without rounding. Numeric JSON tokens retain their text before decoding, including exponent tokens. Loading/error panels fill the available page width, errors distinguish access and service failures, and Retry reloads the wallet.

Verified on the connected Samsung phone: balance, payment methods, transactions and reconciliation all returned HTTP 200 and the wallet rendered. The server currently disables top-ups and withdrawals. Fifteen wallet tests passed, including exact decimal precision and full-width error/retry recovery; Dart analysis was clean. No payment mutations were performed during device verification.

## Completed wallet API controls (19 October 2026)

All wallet routes in the supplied current implementation document are integrated. The main screen retains the reference layout and always exposes Add New Payment Method. Its sheet renders Add test card and Add test bank account according to their respective linking flags and offers Refresh availability when setup is disabled. Linking does not require a balanced/funded wallet. Unsupported edit/delete/default and mobile-money actions are not fabricated.

Payment status accepts an intent ID and shows IDs saved for the authenticated owner on this device. Creation and lookup retain up to 50 IDs in secure storage, separate from the unresolved-request journal, so successful payments remain inspectable after restart. Known unresolved intents use the existing recovery flow. Explicit test controls support SUCCESS, FAILURE and PENDING. A successful MOCK top-up offers a confirmed REFUND after a fresh intent read; pending payments, withdrawal refunds, disabled capabilities, incompatible funding modes and failed reconciliation block this action. The backend remains authoritative for sufficient funds and event transitions. Refunds refresh wallet balances; they do not send a real card refund.

Wallet details reads wallets, direct capabilities and reconciliation. The backend configuration remains unchanged: the deployed linking/funding flags must be enabled before method setup and payments become available. No payment mutations are required to verify the read-only UI on the device.

Validation for the completed controls: all 24 wallet tests passed, including the reference screenshot, authenticated transport paths and payloads, both setup types, disabled-to-enabled capability refresh, retained payment IDs across controller recreation, refund cancellation/confirmation, and responsive layouts. Analyzer reported no issues and the debug APK built successfully. The phone disconnected before installation, so live verification of the new read-only details endpoints is pending.

## Pre-top-up balance banner

The banner entry button remains clickable when server funding flags are disabled. It opens the top-up sheet with a service-status explanation and Refresh availability. Payment submission still enforces capabilities, reconciliation, wallet status and unresolved-request guards. All 26 wallet tests passed after this navigation correction; analyzer was clean.

Wallets with fundingMode UNFUNDED show the compact teal balance banner with the visibility toggle, native wallet/coins illustration and an inline white Top Up Wallet button. The button opens the existing top-up sheet and follows payment capabilities, reconciliation and pending-operation guards. Funded wallets retain the detailed available/pending/reserved card. The server balance is displayed directly; reference amounts are not hardcoded. Twenty-five wallet tests passed and analyzer was clean after this presentation update.


## Wallet flow completion (20 October 2026)

The payment sheet now supports the documented optional card on top-ups. Select
"Continue without a saved card" to send a null methodId, or use Add card directly
in the sheet; setup selects the returned method ID. Withdrawals still require a
saved BANK_ACCOUNT returned by setup. Bank-detail collection remains deferred;
setup sends only the type query and never submits account or card credentials.

Refresh and app resume re-read a known unresolved intent, refresh server balances,
and clear the retry journal only once the intent is terminal. Payment result
controls also support top-ups without a saved card. Creation retains the same
persistent idempotency key across uncertain retries.

The configured API base is https://jobhub.pentarixlabs.com/api/v1. The screenshot
shows linking and funding unavailable. The deployed backend must enable the
corresponding payment-settings flags before the customer/provider app can perform
setup or funding. The mobile app has no administrator credentials or gateway
selector and does not override disabled server capabilities. Deploying the API
implementation and enabling its payment configuration are backend prerequisites.
