# Customer card confirmation

The accepted-provider countdown now presents **Confirm and Pay** for both Wallet
and Card, with the authoritative request amount and payment method. Card bypasses
the old extra payment confirmation page.

Card confirmation uses the existing contract in
[the API reference](customer-api-reference-2026-10-25.md):

1. Read the owned request again and check its identity, method and deadline.
2. Use the customer's real profile billing address and account contact details.
   Ask for missing email/phone only for this checkout; do not fabricate or persist
   them. Ask Visa/Mastercard only if the selected card's brand is unavailable.
3. POST `/customers/me/booking-requests/{id}/confirm` with billing information and
   `cardMethod`. Card number/CVV never enter this API payload.
4. Validate the server's HTTPS PayHere action URL, signed fields, amount and
   currency. Form-POST **all** returned fields unchanged to that exact action URL
   in the hosted WebView. Do not construct a signature or put fields in a URL.
5. Poll the owned request while checkout is in the foreground and when returning
   to the app. Return/cancel redirects close checkout and trigger a status read;
   neither redirect proves payment success. Only server-confirmed PAID/RESERVED/
   SETTLED lifecycle state permits success UI.

The existing saved cards are explicitly mock setup records, not reusable live
gateway tokens. Hosted checkout collects the actual gateway payment credentials.
An uncertain confirmation result goes to status recovery without automatic
payment retries. Closing an unfinished checkout does not fabricate cancellation
or permit a second charge while status is PAYMENT_PENDING.

The official `webview_flutter` plugin is used. Android supplies the form POST
content type itself; the explicit form header is also provided for WKWebView.
See [Flutter WebView documentation](https://pub.dev/packages/webview_flutter).
No JavaScript channel exposes app authentication tokens or card fields. Normal
HTTPS/SSL checks remain enabled. Tests inject only the checkout presenter so
normal widgets exercise real controller/repository logic without a live charge.

The new native plugin requires stopping and running Flutter again; hot reload
or hot restart alone cannot register a newly added native plugin. Android build
validation does not exercise a live PayHere payment or verify iOS on-device.
