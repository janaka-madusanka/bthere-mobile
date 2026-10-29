# Backend contract needed: pre-match payment hold

Requested flow: payment selection -> temporary hold -> provider matching ->
provider accepted -> 30-second customer cancellation window -> payment finalization
and confirmed booking. This differs from the currently supplied contract, which
matches and accepts before wallet reserve/PayHere checkout.

Please confirm support and provide concrete endpoints/payloads/responses for:

- Wallet reservation before matching, and card gateway authorization/preauth
  (confirm whether the configured gateway supports authorize/capture separately).
- Owner-scoped hold/payment identifiers, request linkage, currency/amount,
  hold status, expiration and authoritative status recovery.
- Idempotency across retries, timeout recovery and concurrent requests, so no
  duplicate hold or capture can happen.
- Provider-acceptance finalization: server-authoritative autoApproveAt/cancelUntil
  timestamps if the 30-second policy is supported; amount changes must not be
  silently captured beyond the authorized amount.
- Release/void of wallet/card holds when matching fails, the user cancels,
  the provider rejects, the authorization expires or payment cannot finalize.
- Cancellation during the grace period and its terminal response/hold state.
- Verified payment callbacks/events and polling states; distinguish HELD from
  CAPTURED/PAID, with wallet reservation versus final settlement defined.
- Accepted provider public profile fields (name/photo/rating and actual verified
  badges). The current request View supplies providerId only, so the app can
  otherwise show only candidate metadata already returned by the backend.

The frontend must not simulate hold success, invent a 30-second auto-approval,
accept a browser redirect as payment proof, or create another payment to recover
an unknown outcome. UI screens/assets are implemented against current server
states; new financial ordering awaits this contract and deployed support.
