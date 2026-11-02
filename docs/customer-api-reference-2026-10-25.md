Customer App — full frontend API reference
Wallet payments for scheduled booking requests — 25 October 2026
Implemented locally; not deployed. This extends the existing single-provider request lifecycle to CARD or WALLET for both supported TIME_BASED and ROUTE_BASED services. It does not add team dispatch, new funding/top-up adapters, cancellation refunds or bank payouts. No additional schema migration is needed beyond the existing booking-request, platform-fee and card-settlement schemas.
Configuration and creation
The option must allow WALLET and use ADMIN pricing, with an enabled booking-request policy. Code encryption must be configured. A WALLET-only policy/request does not require PayHere checkout configuration. CARD requests continue to require PayHere; if an option allows both, an unavailable card adapter does not block WALLET requests. The same minimum notice, capacity, coverage, eligibility and required field checks apply. DIRECT_REQUEST includes booking.providerId; OPEN_REQUEST omits it.
CUSTOMER authorization and Content-Type: application/json:
POST /api/v1/customers/me/booking-requests
Header: Idempotency-Key: <unique-logical-request-key>
Example TIME_BASED ONLINE request (illustrative future dates/IDs; required fields must come from the returned booking schema):
{
  "marketId": 1,
  "booking": {
    "serviceTypeId": 3,
    "optionId": 12,
    "deliveryMode": "ONLINE",
    "startDatetime": "2030-01-07T08:00:00",
    "expectedEndDatetime": "2030-01-07T09:00:00",
    "paymentMethod": "WALLET",
    "answers": [],
    "pricingSelections": []
  },
  "radiusKm": 20,
  "languages": ["ENGLISH"],
  "requiredSkillIds": [],
  "providerFilters": []
}
For ROUTE_BASED use the existing requestedPickupTime/pickup/destination fields instead of time interval fields, and set paymentMethod:WALLET. No money is reserved at creation or during provider ringing. Provider acceptance creates an AWAITING_PAYMENT job and an AWAITING_CUSTOMER_CONFIRMATION request. The customer must explicitly confirm before confirmationExpiresAt; available balance can change before then. The selected method is retained through quote and acceptance.
Request View adds paymentMethod (CARD or WALLET) to its existing fields, including paymentStatus, paymentFundingMode and settlement metadata. The payment method is fixed for the request. To change it before funding, cancel the still-unfunded request and create a fresh request with a new idempotency key.
Confirm using wallet
POST /api/v1/customers/me/booking-requests/{requestId}/confirm-wallet
CUSTOMER token. No body, no card brand and no billing-contact fields.
The server locks the owned request/job and payer wallet, checks the deadline, reconciles the wallet and reserves expectedAmount from AVAILABLE into RESERVED. The booking becomes CONFIRMED, paymentStatus becomes RESERVED, a customer START code is generated and BOOKING_CONFIRMED events are queued. This is one transaction; a failure generating the code or events rolls the financial reservation back. No card gateway is called. Repeated/concurrent confirmation cannot reserve twice.
HTTP 200 View example:
{
  "requestId": 501,
  "status": "CONFIRMED",
  "selectionMode": "OPEN_REQUEST",
  "offerId": 601,
  "providerId": 15,
  "offerExpiresAt": "2030-01-07T00:01:00Z",
  "confirmationExpiresAt": "2030-01-07T00:03:00Z",
  "jobId": 70,
  "paymentStatus": "RESERVED",
  "expectedAmount": 1000.00,
  "currencyCode": "LKR",
  "platformFeePercentage": 15.00,
  "platformFee": 150.00,
  "providerEarnings": 850.00,
  "settlementStatus": null,
  "settlementOperationId": null,
  "paymentFundingMode": "PAYHERE",
  "paymentMethod": "WALLET"
}
paymentFundingMode describes the wallet money's original source, not the chosen booking payment method. PAYHERE means existing live card-sourced wallet funds; it does not mean this wallet confirmation charges a card.
Example customer balances with LKR 1,500 available before confirmation:
Before: available 1,500; reserved 0
After confirmation: available 500; reserved 1,000
After completion settlement: available 500; reserved 0
Read balances with GET /api/v1/me/wallets/LKR and history with GET /api/v1/me/wallets/LKR/transactions?page=0&size=20.
Insufficient balance
HTTP 409, application/problem+json example:
{
  "type": "about:blank",
  "title": "Insufficient wallet balance",
  "status": 409,
  "detail": "Insufficient available wallet balance",
  "instance": "/api/v1/customers/me/booking-requests/501/confirm-wallet",
  "code": "INSUFFICIENT_WALLET_FUNDS",
  "currencyCode": "LKR",
  "requiredAmount": 1000.00,
  "availableAmount": 200.00,
  "shortfall": 800.00
}
The booking remains AWAITING_CUSTOMER_CONFIRMATION, no money is reserved and no start code is issued. Keep the same deadline; no automatic extension is made. The app can display the shortfall and retry the same confirmation if sufficient eligible funds become available before the deadline. If it expires, normal expiry cancels the unpaid job and releases service capacity. This update does not implement live wallet top-ups: do not present the generic mock top-up API as a live funding route. A request without an existing wallet sees available zero and a shortfall.
Start and completion
Existing endpoints are unchanged:
GET /api/v1/customers/me/bookings/{jobId}/verification-codes POST /api/v1/providers/me/bookings/{jobId}/start with {"code":"123456"} POST /api/v1/providers/me/bookings/{jobId}/complete with no body POST /api/v1/customers/me/bookings/{jobId}/confirm-completion with no body
WALLET/RESERVED is valid for starting and requesting completion, just as CARD/PAID is valid for card bookings. There is no end code. Customer completion confirmation atomically consumes the customer's RESERVED gross amount, credits the provider's AVAILABLE net earnings, records the saved fee and completes the booking. Both request and job paymentStatus become SETTLED; request settlementStatus is POSTED with settlementOperationId. Card request paymentStatus still remains PAID as its gateway receipt while its job becomes SETTLED.
Example: gross 1,000; saved fee 15% = 150; provider receives 850. The operation type is WALLET_BOOKING_SETTLE, amount is gross, providerEarnings is net, and paymentReference is WALLET_RESERVATION:<reservation-operation-id>. No PayHere payment notice is created for wallet payment. Every settlement is balanced and idempotent, including concurrent retries. A failure rolls back completion and all financial postings, preserving the reservation. No fee recalculation from current admin settings or actual duration/distance occurs.
The provider app still shows only providerEarnings/currencyCode on incoming and booking screens, then refreshes wallet/history after BOOKING_COMPLETED. Provider accept/start/complete routes remain SERVICE_PROVIDER-only; providers cannot reserve a customer's wallet or confirm completion for them.
Funding separation and older endpoints
Live request-wallet payments require a reconciled wallet tagged PAYHERE. A wallet tagged MOCK is allowed only while the generic server gateway is in MOCK mode; provider earnings and fee postings remain synthetic (MOCK_PLATFORM_FEE). Unknown, legacy or unclassified nonempty balances require reconciliation; their source is not guessed. PAYHERE_SANDBOX funds cannot pay for wallet bookings. Live/mock funds cannot mix in a nonempty provider wallet. Frozen/inactive/unreconciled wallets block posting. These rules prevent converting test credits into live provider earnings.
The existing POST /customers/me/bookings/{jobId}/wallet-payment route and admin wallet-booking release/settlement/approval routes reject jobs linked to the new request lifecycle. Use confirm-wallet and customer confirm-completion instead. Legacy wallet-funded bookings without a booking request retain their original finance-approved pending-earnings settlement behavior.
The CARD confirm endpoint rejects WALLET requests. confirm-wallet rejects CARD requests. Verified gateway callbacks cannot fund wallet jobs. Confirmation retries after success return the existing View without re-reserving or resetting codes. The paid/reserved request cannot use the pre-payment cancellation endpoint; paid cancellation/refund policies remain separate future work.
Superadmin monitoring
Existing GET /api/v1/admin/booking-monitor endpoints expose WALLET jobs, RESERVED / SETTLED payment states, BOOKING_RESERVE and WALLET_BOOKING_SETTLE operations and linked ledger entries. Examples:
GET /api/v1/admin/booking-monitor/bookings?paymentMethod=WALLET&paymentStatus=RESERVED GET /api/v1/admin/booking-monitor/transactions?jobId=70&type=WALLET_BOOKING_SETTLE GET /api/v1/admin/booking-monitor/transactions/{operationId}/entries
Errors: 400 invalid create method/fields/configuration; 401/403 authentication/role; 404 ownership/missing request; 409 insufficient funds, wrong selected method, missing acceptance, expired confirmation, unsupported funding or wallet/settlement conflict. For the structured shortfall use code=INSUFFICIENT_WALLET_FUNDS rather than matching the detail text. No new hold-and-capture or bank-payout API is added.

Scheduled booking requests, card checkout and completion — 25 October 2026
Implemented locally; not deployed or verified against a live PayHere merchant account/mobile device. This section supersedes older statements that offers, booking-request idempotency, hosted PayHere checkout or card-funded provider wallet settlement are unavailable. Existing catalog, eligibility, dynamic fields, shared-option registrations and independent map-marker rules still apply. Examples use illustrative IDs and future dates; replace them with actual configuration.
Which booking flow to use
Read GET /api/v1/customers/me/booking-requests/policy?optionId=12 with CUSTOMER authorization. Use this flow only when enabled; legacy POST /bookings then returns 409. Supported requests are scheduled, ADMIN-priced, single-provider, LKR and either CARD (Visa/Mastercard credit/debit) or WALLET. The option must allow the selected method. CARD requires PayHere; WALLET-only does not. Team dispatch and immediate Ride Now matching remain unsupported.
{
  "enabled": true,
  "minimumNoticeMinutes": 120,
  "offerTimeoutSeconds": 60,
  "confirmationTimeoutSeconds": 120,
  "matchingTimeoutSeconds": 600,
  "maximumRadiusKm": 50
}
The policy values above are examples, not fixed limits. Read them from the server. Search/matching checks the selected option's approvals, configured fields/capabilities, market, delivery, schedule, service coverage and remaining capacity. Search is a snapshot; acceptance revalidates and reserves capacity. OPEN_REQUEST offers sequentially to distinct eligible providers ordered by existing search distance, from at most the first 100 candidate rows. DIRECT_REQUEST contacts only booking.providerId; no automatic switch to open matching. Radius is constrained by policy and service coverage, not road ETA or live online distance. Even a scheduled trip must pass the configured coverage, notice and radius checks.
Create a request
POST /api/v1/customers/me/booking-requests → HTTP 201 View. Headers: Authorization: Bearer <customer-token>; Content-Type: application/json; Idempotency-Key: <unique-key-for-this-logical-request> (nonblank, at most 100 characters). First load booking-context/access/requirements and collect configured required answers and pricing selections. The outer marketId and inner booking are distinct from the older quote body. No amount, commission, rate or distance override is accepted.
{
  "marketId": 1,
  "booking": {
    "serviceTypeId": 3,
    "optionId": 12,
    "deliveryMode": "PROVIDER_TO_CUSTOMER",
    "requestedPickupTime": "2030-01-07T08:00:00",
    "pickup": {
      "address": "Pickup address",
      "latitude": 6.9271,
      "longitude": 79.8612
    },
    "destination": {
      "address": "Destination address",
      "latitude": 6.9371,
      "longitude": 79.8712
    },
    "paymentMethod": "CARD",
    "answers": [],
    "pricingSelections": [
      {
        "fieldId": 45,
        "choiceValue": "CAR"
      }
    ]
  },
  "radiusKm": 20,
  "languages": [
    "ENGLISH"
  ],
  "requiredSkillIds": [],
  "providerFilters": [
    {
      "fieldId": 45,
      "value": [
        "CAR"
      ]
    }
  ]
}
For DIRECT_REQUEST add booking.providerId:15; OPEN_REQUEST omits providerId. Do not send providerIds. answers:[] is valid only when no configured required booking fields exist. TIME_BASED uses market-local startDatetime/expectedEndDatetime instead of route fields. PROVIDER_TO_CUSTOMER time bookings need meetingPoint; CUSTOMER_TO_PROVIDER supplies top-level searchLocation and can constrain booking.providerLocationId; ONLINE omits physical coordinates. Read the existing booking schema for exact configured field/value shapes.
A matching View example follows. Amounts may be null if no eligible priced candidate exists. Repeating the same key and body returns the same request; changing the body under the same key returns 409. Another matching/unpaid request for the same customer/option returns 409. Confirmed bookings do not block a new request. No match returns a stored UNMATCHED request without collecting payment.
{
  "requestId": 501,
  "status": "MATCHING",
  "selectionMode": "OPEN_REQUEST",
  "offerId": 601,
  "providerId": 15,
  "offerExpiresAt": "2030-01-07T00:01:00Z",
  "confirmationExpiresAt": null,
  "jobId": null,
  "paymentStatus": "NOT_STARTED",
  "expectedAmount": 1000,
  "currencyCode": "LKR",
  "platformFeePercentage": 15,
  "platformFee": 150,
  "providerEarnings": 850,
  "settlementStatus": null,
  "settlementOperationId": null,
  "paymentFundingMode": null
}
GET /api/v1/customers/me/booking-requests/501 → HTTP 200 current View; no body. View contains requestId, status, selectionMode, offerId, providerId, offerExpiresAt, confirmationExpiresAt, jobId, paymentStatus, expectedAmount, currencyCode, platformFeePercentage, platformFee, providerEarnings, settlementStatus, settlementOperationId and paymentFundingMode. Nullable fields reflect lifecycle. Show the customer their total expectedAmount/currencyCode; commission is deducted from that fare, never added as an extra charge.
Provider acceptance, customer confirmation and PayHere
After PROVIDER_ACCEPTED, View.status is AWAITING_CUSTOMER_CONFIRMATION with jobId and confirmationExpiresAt. The job is AWAITING_PAYMENT, not a confirmed service. Confirm before the UTC deadline: POST /api/v1/customers/me/booking-requests/501/confirm → HTTP 200 Checkout.
{
  "cardMethod": "VISA",
  "firstName": "Customer",
  "lastName": "Name",
  "email": "customer@example.com",
  "phone": "0771234567",
  "address": "Billing address",
  "city": "Colombo",
  "country": "Sri Lanka"
}
cardMethod accepts VISA or MASTER for credit/debit cards. Match first, then collect payment: there is no card balance check, preauthorization or deduction before matching. Card number/CVV go only to PayHere hosted checkout. Do not send card credentials to this backend.
{
  "actionUrl": "https://sandbox.payhere.lk/pay/checkout",
  "fields": {
    "merchant_id": "<server-returned>",
    "order_id": "<server-returned>",
    "amount": "1000.00",
    "currency": "LKR",
    "items": "Booking 501",
    "notify_url": "<server-returned>",
    "return_url": "<server-returned>",
    "cancel_url": "<server-returned>",
    "first_name": "Customer",
    "last_name": "Name",
    "email": "customer@example.com",
    "phone": "0771234567",
    "address": "Billing address",
    "city": "Colombo",
    "country": "Sri Lanka",
    "payment_method": "VISA",
    "hash": "<server-returned-signature>"
  },
  "status": "PAYMENT_PENDING"
}
Submit every returned fields entry by form POST to the exact returned actionUrl. Values/signatures above are placeholders, not a payload to construct locally. Retrying confirm returns the same checkout; changing card brand after checkout starts returns 409. Browser return/cancel redirects are not payment proof. Poll the request or recover through booking-events until the server verifies the callback. Only a verified successful callback confirms service. Repeated gateway callbacks do not repeat transitions or settlement.
The gateway-only POST /api/v1/payments/payhere/booking-notify is not an app action. The server verifies signature, merchant, order, amount, currency and card method. Missing callback after 15 minutes enters PAYMENT_RECONCILIATION and retains capacity; do not create another payment to guess the outcome. Late/extra payments can enter PAYMENT_REVIEW/REFUND_REVIEW for merchant operations.
Start code and completion confirmation
Lifecycle: MATCHING → AWAITING_CUSTOMER_CONFIRMATION → PAYMENT_PENDING → CONFIRMED → IN_PROGRESS → AWAITING_COMPLETION_CONFIRMATION → COMPLETED. Other outcomes include UNMATCHED, cancellation/expiry and payment review. Keep request.status, request.paymentStatus, job.status and job.paymentStatus separate; a provider accepting is not payment success.
GET /api/v1/customers/me/bookings/70/verification-codes → HTTP 200 own START code, no body. Available only for a CONFIRMED paid booking, from 30 minutes before scheduled start until 24 hours after expected end. The code is encrypted at rest and is never in provider responses/push payloads.
{
  "purpose": "START",
  "code": "123456",
  "expiresAt": "2030-01-08T02:32:00Z"
}
Give the START code to the assigned provider when service actually begins. The provider submits it to the start endpoint. Five incorrect attempts lock the code; support reset is an audited admin action. No end/completion code exists.
After the provider requests completion, display a confirmation action for AWAITING_COMPLETION_CONFIRMATION. POST /api/v1/customers/me/bookings/70/confirm-completion → HTTP 200; no body and no code.
{
  "successful": true,
  "status": "COMPLETED"
}
Customer completion atomically completes service and credits saved provider net earnings once. CARD request paymentStatus stays PAID; WALLET request paymentStatus becomes SETTLED after consuming its RESERVED fare. Job paymentStatus becomes SETTLED in either case. View has settlementStatus POSTED, settlementOperationId, paymentFundingMode and paymentMethod. Failed posting rolls completion back. No extra charge or actual-duration/distance fare recalculation occurs. Without customer confirmation the service remains awaiting confirmation; no automatic completion/dispute workflow is added.
Cancellation, notifications and app recovery
POST /api/v1/customers/me/booking-requests/501/cancel → HTTP 200 View; no body. Allowed before checkout begins. It is not a paid-booking refund API. Customer cancellation during/after payment, automatic cancellation refund policies, provider cancellation after acceptance and live bank payouts remain future work. Paid cancellations/duplicate charges require merchant/support handling.
POST /api/v1/me/booking-devices → HTTP 200 {deviceId}; both customer and provider apps use their own authenticated token. Example request:
{
  "token": "<FCM-registration-token>",
  "platform": "ANDROID",
  "deviceName": "Phone"
}
platform accepts ANDROID or IOS. DELETE /api/v1/me/booking-devices/{deviceId} unregisters an owned device, with no body; refresh registrations on token changes and logout. At most ten active devices per user. GET /api/v1/customers/me/booking-events?after=0 → HTTP 200 own events (up to 100). Save last eventId and poll after it to recover from missed push notifications. Push data has eventId, requestId, type and optional offerId/expiresAt; fetch authorized details instead of expecting booking fields or money in the notification.
Customer events include PROVIDER_ACCEPTED, BOOKING_CONFIRMED, BOOKING_STARTED, COMPLETION_REQUESTED, BOOKING_COMPLETED and terminal/review updates. Deduplicate by eventId. Event records contain eventId, userId, requestId, offerId, eventType, createdAt, expiresAt, deliveryStatus, deliveryAttempts and nextDeliveryAt. Push depends on configured Firebase/APNs and app notification permissions; local implementation is not evidence of live delivery.
Errors and rollout
400: invalid fields/selections/time/currency/payment method. 401/403: authentication/role/access restrictions. 404: missing/other user's request or booking. 409: disabled policy, conflicting active request, reused key with changed body, expired offer/deadline, changed quoted fare or commission, invalid lifecycle, or settlement wallet inconsistency. 503: unavailable checkout configuration. Use HTTP status and returned error body; do not match exact error strings. All dates/IDs/amounts here are illustrative.
Deployment requires the booking-request, platform-fee and card-settlement schema migrations, enabled option booking policy, CARD allowed, ADMIN pricing, PayHere gateway selection and merchant URLs/credentials, a persistent booking-code encryption key, and Firebase credentials for live push. Hosted checkout is a separate integration from the older mock wallet/card/top-up endpoints and their capability flags. Sandbox earnings never become live money. Full-screen ringing belongs to the provider app; this backend provides offers/events, not a telephone call.

Vehicle-only map markers and independent pricing — 25 October 2026
Confirmed against the local backend and regression tests. This clarification uses existing APIs; it introduces no endpoint, response property or database migration. It does not verify a new production deployment. IDs and asset URLs below are illustrative; use the selected option’s actual schema.
Search for the selected service, option and capabilities
The customer chooses a main service and option, then filters capabilities: Caregiver → Hospital Caregiver, or Riding → Ride → Vehicle CAR. POST /api/v1/customers/me/provider-search returns candidates qualified and available for that selected option, market, time, coverage and filters. A person offering both caregiving and rides appears only when the selected option’s checks pass. Shared options reuse their approved source registration across linked services.
Load GET /api/v1/customers/me/booking-context?marketId={marketId}&serviceTypeId={serviceTypeId}&optionId={optionId} before search. Read selection.option, bookingSchema, providerFilters and timezone. Context prepares the booking screen; it creates no booking and returns no fare.
One vehicle marker across gender variants
For an option with Vehicle and Gender fields, pricing may use Vehicle + Gender while map marker rules use Vehicle alone. CAR + MALE and CAR + FEMALE then use the same car icon. BIKE uses its bike icon. Do not create a separate marker for every pricing combination or a separate gender pin.
An active CAR-only rule matches when the vehicle filter selects CAR, whether the gender filter is absent, MALE, FEMALE, or [MALE,FEMALE]. Only fields in the rule’s conditions need one selected choice each. Multiple vehicle values such as [CAR,BIKE] do not identify one vehicle marker; the usual fallback applies unless another matching rule exists. Marker resolution uses the customer’s selected filters, not each provider’s current vehicle or photo.
Search request fragment (include all required market, service, option, delivery, time and location/route fields as documented below):
{"providerFilters":[{"fieldId":45,"value":["CAR"]},{"fieldId":47,"value":["FEMALE"]}]}
For an active rule 7 containing only vehicle CAR, each candidate’s mapMarker is shaped as follows:
{"source":"COMBINATION","icon":{"key":"markers/car.png","url":"https://cdn.example.com/markers/car.png","altText":"Car","displayOrder":0},"fieldId":null,"choiceValue":null,"ruleId":7,"conditions":[{"fieldId":45,"choiceValue":"CAR"}]}
Render candidate.mapMarker.icon.url as the map asset, keeping profilePhoto for cards. Even a one-condition rule uses source COMBINATION for compatibility. The most specific matching rule wins; equal specificity conflicts return 409. Fallback is selected choice marker → shared option marker → canonical main-service marker → default pin. DEFAULT has icon null. ONLINE has no physical mapPoint; physical pins are existing coverage/location points, not live GPS.
Fetch the server price separately
POST /api/v1/customers/me/bookings/quote
Search returns availability and candidates, with no fare. After choosing provider(s), send the complete booking request to quote, including required booking answers, payment method, scheduling/location details and pricingSelections. Quote returns rateId, currencyCode, expectedAmount, startDatetime, expectedEndDatetime, estimatedDistanceKm, pricingSelections and pricingSnapshot. It creates no booking or reservation; booking creation revalidates availability and recalculates price.
If both Vehicle and Gender are configured pricing dimensions, the quote/booking fragment is:
{"pricingSelections":[{"fieldId":45,"choiceValue":"CAR"},{"fieldId":47,"choiceValue":"FEMALE"}]}
Keep providerFilters [{fieldId,value}], pricingSelections [{fieldId,choiceValue}] and booking answers [{fieldId,value}] separate. Send exactly the applicable pricing fields, one stable choice per field. Extra filter fields must not automatically become pricing selections. Current context/search has no dedicated pricing-dimensions catalog; use an agreed configuration mapping instead of guessing required price fields.
Pricing uses configured admin rates for the market, shared option, applicable geographic area, choices and duration/distance. Route geographic pricing uses destination coordinates; provider coverage search uses pickup coordinates. Every selected provider must support the pricing choices. pricingOwner PROVIDER does not enable individual provider quotes in this implementation. Admin marker changes do not change prices, and price conditions do not require duplicate marker rules.
Existing shared options migrate automatically — 23 October 2026
The new local migration automatically merges legacy duplicate configuration instead of asking for conflict selection. Existing option IDs/links stay. Choice sets and applicable field associations are combined; current schemas return the winning shared field IDs and condition references are remapped. Historical booking answers, fares and pricing snapshots remain untouched. Original configuration/approval records are archived.
Customer request bodies do not change. Reload booking-context/providerFilters after deployment; do not retain old duplicate field IDs in a hardcoded client mapping. Field historical serviceTypeId need not equal the selected main service or configurationServiceTypeId; use actual option-scoped definitions. Missing/incompatible provider proof stays pending; rejected proof is not auto-approved. Production application of this update is still pending.
Fully shared option entry — customer workflow update — 23 October 2026
Implemented locally; NOT yet deployed, and production migration has NOT been applied. This supersedes earlier service-local field/rate/marker descriptions. The six service-pattern request/response examples below retain their body shapes. Old deployed-configuration snapshots describe 22 October only.
Ride → CARE_RIDE and Caregiver → CARE_RIDE now use the same option configuration. ServiceOptionResponse adds configurationServiceTypeId (the stable original configuration namespace). Keep the selected navigation serviceTypeId + shared optionId in requests; do not replace navigation IDs with guessed configuration IDs. Both contexts expose the same provider requirement/booking field IDs, choices, icons, pricing conditions and marker rules.
For enabled policies: profile → market/service/option → context/eligibility/required fields → schedule/location/filters/pricing selections → search/optional quote → create idempotent request → provider acceptance → customer confirms via CARD hosted checkout or WALLET reservation → confirmed service → START code → provider requests completion → customer confirms → completed and provider wallet credited. Disabled-policy options retain the older legacy flow. Active market offerings and option links remain required.
Search reuses the option's provider registrations across linked services. An approved provider does not need another main-service registration to appear through the second link. The selected source assignment supplies availability, service areas, languages, skills and approved attributes. Legacy duplicate provider IDs are deduplicated so one person cannot satisfy multiple team slots. No unrelated option/provider approval is borrowed.
Quote/booking resolves the same source registration, booking fields and canonical market/option rate through either entry path. Provider capacity already counts overlapping reservations by shared option ID. Creating through one path therefore affects availability through the other. The saved booking retains the requested navigation serviceTypeId and its applied price snapshot. Same field ID/market/time/location/selections means the same configured fare; different inputs/markets or intervening availability/rate edits can still change results.
{
  "optionId": 120,
  "serviceTypeId": 7,
  "configurationServiceTypeId": 6,
  "mapMarkerFieldId": 145
}
This is a response projection with illustrative IDs: service 7 is the chosen link, service 6 is the shared namespace, and option 120/field 145 are reused. It is not a verified deployed record. Keep providerFilters [{fieldId,value}] separate from booking answers [{fieldId,value}] and pricingSelections [{fieldId,choiceValue}]. Option-level reusable customer requirements/eligibility follow the same option ID; the original configuration's service policy is used consistently once an option is selected.
Main-service catalog gates remain separate before an option is selected. No service-specific option override is supported. Current-vehicle switching, live GPS/road ETA, automatic open-request dispatch, per-unit pricing and booking-create idempotency are not added by this change. Quote still creates no booking or capacity/price reservation, and create revalidates. Existing payment/mock restrictions remain.
Six configuration-driven customer API patterns — complete examples — 22 October 2026
These six patterns cover the currently implemented service models. Every configuration is a relevant option-settings projection, not a complete admin write body; use the full Super Admin request examples when saving configuration. All IDs, providers, prices, attributes, timestamps and successful responses here are illustrative, not live customer results. In particular example gender field 501 and vehicle field 502 must be replaced with the selected option's actual context fields; deployed gender field 6 belongs only to service 9. Do not paste these examples into production unchanged.
For every pattern: first load market-aware service/options and booking-context, resolve eligibility, then POST /api/v1/customers/me/provider-search. POST /api/v1/customers/me/bookings/quote with the illustrated booking body returns 200. After customer confirmation, POST /api/v1/customers/me/bookings with that same body returns 201. Use CUSTOMER Authorization and JSON content type. No client amount/rate/distance override is accepted. All examples assume approved available providers, active market/offering/links/rates, cash enabled, no additional required booking fields, and exact schedule/coverage matches. Required dynamic answers must be added from bookingSchema in real calls.
A. Caregiver / cleaning — provider travels to customer
Customer provides the interval and meeting point. The service can charge hourly/daily/fixed; this example uses two hourly blocks. Search pins represent approximate provider coverage centres, not a travelling provider's live position.
Relevant Super Admin option configuration:
{
  "schedulingModel": "TIME_BASED",
  "locationEnabled": true,
  "deliveryModes": [
    "PROVIDER_TO_CUSTOMER"
  ],
  "fulfillmentModel": "ONE_TO_ONE",
  "requiredProviderCount": 1,
  "defaultCapacity": 1,
  "bookingMode": "ONE_AT_A_TIME",
  "providerSelectionMode": "DIRECT_REQUEST",
  "pricingOwner": "ADMIN",
  "allowedPaymentMethods": [
    "CASH"
  ]
}
POST /api/v1/customers/me/provider-search — full request:
{
  "marketId": 1,
  "serviceTypeId": 20,
  "optionId": 200,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "location": {
    "latitude": 6.93,
    "longitude": 79.86
  },
  "radiusKm": 30,
  "languages": [],
  "requiredSkillIds": [],
  "page": 0,
  "pageSize": 20,
  "providerFilters": []
}
200 full provider-search response:
{
  "checkedAt": "2030-01-01T00:00:00Z",
  "marketId": 1,
  "timezone": "Asia/Colombo",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "providerSelectionMode": "DIRECT_REQUEST",
  "requiredProviderCount": 1,
  "status": "AVAILABLE",
  "totalCandidates": 1,
  "page": 0,
  "pageSize": 20,
  "hasNext": false,
  "candidates": [
    {
      "providerId": 300,
      "assignmentId": 310,
      "optionId": 200,
      "providerLocationId": null,
      "displayName": "Example Provider A",
      "profilePhoto": null,
      "averageRating": 4.8,
      "totalRatings": 25,
      "locationLabel": "APPROXIMATE_SERVICE_AREA",
      "mapPoint": {
        "latitude": 6.93,
        "longitude": 79.86
      },
      "distanceKm": 0,
      "remainingCapacity": 1,
      "languages": [
        "ENGLISH",
        "SINHALA"
      ],
      "providerAttributes": {},
      "mapMarker": {
        "source": "DEFAULT",
        "icon": null,
        "fieldId": null,
        "choiceValue": null,
        "ruleId": null,
        "conditions": []
      }
    }
  ]
}
Full request body for POST /api/v1/customers/me/bookings/quote and, after confirmation, POST /api/v1/customers/me/bookings:
{
  "serviceTypeId": 20,
  "optionId": 200,
  "providerId": 300,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "meetingPoint": {
    "name": "Customer home",
    "addressLine1": "Example address",
    "city": "Colombo",
    "country": "Sri Lanka",
    "latitude": 6.93,
    "longitude": 79.86
  },
  "answers": [],
  "paymentMethod": "CASH",
  "pricingSelections": []
}
200 full quote response:
{
  "rateId": 600,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "estimatedDistanceKm": null,
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": []
  }
}
201 full booking response (assuming unchanged rate/capacity and the same validated inputs):
{
  "jobId": 700,
  "serviceTypeId": 20,
  "optionId": 200,
  "providerId": 300,
  "providerIds": [
    300
  ],
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "schedulingModel": "TIME_BASED",
  "fulfillmentModel": "ONE_TO_ONE",
  "capacityUsed": 1,
  "providerLocationId": null,
  "meetingPointName": "Customer home",
  "latitude": 6.93,
  "longitude": 79.86,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "destinationLatitude": null,
  "destinationLongitude": null,
  "destinationAddress": null,
  "estimatedDistanceKm": null,
  "estimatedDurationMinutes": null,
  "rateId": 600,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "paymentMethod": "CASH",
  "paymentStatus": "PENDING",
  "status": "PENDING",
  "answers": {},
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": []
  }
}
B. Ride — pickup and destination
Search uses offset-bearing startAt with pickup/destination, omitting location and endAt. Quote/booking uses market-local requestedPickupTime and route points with addresses, omitting time-based fields. Example straight-line distance is 1.11 km, average speed 40 km/h, estimated duration 2 minutes, base 200 + 100/km with minimum 400 → amount 400. Geographic rate overrides use destination coordinates. No road routing or live vehicle tracking.
Relevant Super Admin option configuration:
{
  "schedulingModel": "ROUTE_BASED",
  "locationEnabled": true,
  "deliveryModes": [
    "PROVIDER_TO_CUSTOMER"
  ],
  "fulfillmentModel": "ONE_TO_ONE",
  "requiredProviderCount": 1,
  "defaultCapacity": 1,
  "bookingMode": "ONE_AT_A_TIME",
  "providerSelectionMode": "DIRECT_REQUEST",
  "pricingOwner": "ADMIN",
  "allowedPaymentMethods": [
    "CASH"
  ],
  "routeAverageSpeedKmh": 40
}
POST /api/v1/customers/me/provider-search — full request:
{
  "marketId": 1,
  "serviceTypeId": 20,
  "optionId": 201,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startAt": "2030-01-07T08:00:00+05:30",
  "radiusKm": 30,
  "languages": [],
  "requiredSkillIds": [],
  "page": 0,
  "pageSize": 20,
  "providerFilters": [],
  "pickup": {
    "latitude": 6.9,
    "longitude": 79.8
  },
  "destination": {
    "latitude": 6.91,
    "longitude": 79.8
  }
}
200 full provider-search response:
{
  "checkedAt": "2030-01-01T00:00:00Z",
  "marketId": 1,
  "timezone": "Asia/Colombo",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T08:02:00+05:30",
  "providerSelectionMode": "DIRECT_REQUEST",
  "requiredProviderCount": 1,
  "status": "AVAILABLE",
  "totalCandidates": 1,
  "page": 0,
  "pageSize": 20,
  "hasNext": false,
  "candidates": [
    {
      "providerId": 300,
      "assignmentId": 312,
      "optionId": 201,
      "providerLocationId": null,
      "displayName": "Example Provider A",
      "profilePhoto": null,
      "averageRating": 4.8,
      "totalRatings": 25,
      "locationLabel": "APPROXIMATE_SERVICE_AREA",
      "mapPoint": {
        "latitude": 6.9,
        "longitude": 79.8
      },
      "distanceKm": 0,
      "remainingCapacity": 1,
      "languages": [
        "ENGLISH",
        "SINHALA"
      ],
      "providerAttributes": {},
      "mapMarker": {
        "source": "DEFAULT",
        "icon": null,
        "fieldId": null,
        "choiceValue": null,
        "ruleId": null,
        "conditions": []
      }
    }
  ]
}
Full request body for POST /api/v1/customers/me/bookings/quote and, after confirmation, POST /api/v1/customers/me/bookings:
{
  "serviceTypeId": 20,
  "optionId": 201,
  "providerId": 300,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "answers": [],
  "paymentMethod": "CASH",
  "pricingSelections": [],
  "requestedPickupTime": "2030-01-07T08:00:00",
  "pickup": {
    "address": "Example pickup",
    "latitude": 6.9,
    "longitude": 79.8
  },
  "destination": {
    "address": "Example destination",
    "latitude": 6.91,
    "longitude": 79.8
  }
}
200 full quote response:
{
  "rateId": 601,
  "currencyCode": "LKR",
  "expectedAmount": 400,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T08:02:00",
  "estimatedDistanceKm": 1.11,
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "ROUTE_BASED",
    "durationMinutes": null,
    "rate": null,
    "baseFare": 200,
    "pricePerKm": 100,
    "minimumFare": 400,
    "conditions": []
  }
}
201 full booking response (assuming unchanged rate/capacity and the same validated inputs):
{
  "jobId": 701,
  "serviceTypeId": 20,
  "optionId": 201,
  "providerId": 300,
  "providerIds": [
    300
  ],
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "schedulingModel": "ROUTE_BASED",
  "fulfillmentModel": "ONE_TO_ONE",
  "capacityUsed": 1,
  "providerLocationId": null,
  "meetingPointName": "Pickup",
  "latitude": 6.9,
  "longitude": 79.8,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T08:02:00",
  "destinationLatitude": 6.91,
  "destinationLongitude": 79.8,
  "destinationAddress": "Example destination",
  "estimatedDistanceKm": 1.11,
  "estimatedDurationMinutes": 2,
  "rateId": 601,
  "currencyCode": "LKR",
  "expectedAmount": 400,
  "paymentMethod": "CASH",
  "paymentStatus": "PENDING",
  "status": "PENDING",
  "answers": {},
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "ROUTE_BASED",
    "durationMinutes": null,
    "rate": null,
    "baseFare": 200,
    "pricePerKm": 100,
    "minimumFare": 400,
    "conditions": []
  }
}
C. Customer visits provider — fixed location
Search location is the customer's search centre. Select a candidate's providerLocationId (illustrative 400); send that ID to quote/booking, not meetingPoint. The location must belong to that provider assignment, option, mode and market. Candidate coordinates are the public service location.
Relevant Super Admin option configuration:
{
  "schedulingModel": "TIME_BASED",
  "locationEnabled": true,
  "deliveryModes": [
    "CUSTOMER_TO_PROVIDER"
  ],
  "fulfillmentModel": "ONE_TO_ONE",
  "requiredProviderCount": 1,
  "defaultCapacity": 1,
  "bookingMode": "ONE_AT_A_TIME",
  "providerSelectionMode": "DIRECT_REQUEST",
  "pricingOwner": "ADMIN",
  "allowedPaymentMethods": [
    "CASH"
  ]
}
POST /api/v1/customers/me/provider-search — full request:
{
  "marketId": 1,
  "serviceTypeId": 20,
  "optionId": 202,
  "deliveryMode": "CUSTOMER_TO_PROVIDER",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "location": {
    "latitude": 6.93,
    "longitude": 79.86
  },
  "radiusKm": 30,
  "languages": [],
  "requiredSkillIds": [],
  "page": 0,
  "pageSize": 20,
  "providerFilters": []
}
200 full provider-search response:
{
  "checkedAt": "2030-01-01T00:00:00Z",
  "marketId": 1,
  "timezone": "Asia/Colombo",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "providerSelectionMode": "DIRECT_REQUEST",
  "requiredProviderCount": 1,
  "status": "AVAILABLE",
  "totalCandidates": 1,
  "page": 0,
  "pageSize": 20,
  "hasNext": false,
  "candidates": [
    {
      "providerId": 300,
      "assignmentId": 314,
      "optionId": 202,
      "providerLocationId": 400,
      "displayName": "Example Provider A",
      "profilePhoto": null,
      "averageRating": 4.8,
      "totalRatings": 25,
      "locationLabel": "PUBLIC_SERVICE_LOCATION",
      "mapPoint": {
        "latitude": 6.93,
        "longitude": 79.86
      },
      "distanceKm": 0,
      "remainingCapacity": 1,
      "languages": [
        "ENGLISH",
        "SINHALA"
      ],
      "providerAttributes": {},
      "mapMarker": {
        "source": "DEFAULT",
        "icon": null,
        "fieldId": null,
        "choiceValue": null,
        "ruleId": null,
        "conditions": []
      }
    }
  ]
}
Full request body for POST /api/v1/customers/me/bookings/quote and, after confirmation, POST /api/v1/customers/me/bookings:
{
  "serviceTypeId": 20,
  "optionId": 202,
  "providerId": 300,
  "deliveryMode": "CUSTOMER_TO_PROVIDER",
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "answers": [],
  "paymentMethod": "CASH",
  "pricingSelections": [],
  "providerLocationId": 400
}
200 full quote response:
{
  "rateId": 602,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "estimatedDistanceKm": null,
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": []
  }
}
201 full booking response (assuming unchanged rate/capacity and the same validated inputs):
{
  "jobId": 702,
  "serviceTypeId": 20,
  "optionId": 202,
  "providerId": 300,
  "providerIds": [
    300
  ],
  "deliveryMode": "CUSTOMER_TO_PROVIDER",
  "schedulingModel": "TIME_BASED",
  "fulfillmentModel": "ONE_TO_ONE",
  "capacityUsed": 1,
  "providerLocationId": 400,
  "meetingPointName": "Example provider venue",
  "latitude": 6.93,
  "longitude": 79.86,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "destinationLatitude": null,
  "destinationLongitude": null,
  "destinationAddress": null,
  "estimatedDistanceKm": null,
  "estimatedDurationMinutes": null,
  "rateId": 602,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "paymentMethod": "CASH",
  "paymentStatus": "PENDING",
  "status": "PENDING",
  "answers": {},
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": []
  }
}
D. Online service — no physical location
Search omits location, pickup and destination; quote/booking omits meetingPoint and providerLocationId. Candidate mapPoint, distanceKm and providerLocationId are null. This models scheduling and booking only; no video-call/session URL API is implied. Example default mapMarker has no physical pin.
Relevant Super Admin option configuration:
{
  "schedulingModel": "TIME_BASED",
  "locationEnabled": false,
  "deliveryModes": [
    "ONLINE"
  ],
  "fulfillmentModel": "ONE_TO_ONE",
  "requiredProviderCount": 1,
  "defaultCapacity": 1,
  "bookingMode": "ONE_AT_A_TIME",
  "providerSelectionMode": "DIRECT_REQUEST",
  "pricingOwner": "ADMIN",
  "allowedPaymentMethods": [
    "CASH"
  ]
}
POST /api/v1/customers/me/provider-search — full request:
{
  "marketId": 1,
  "serviceTypeId": 20,
  "optionId": 203,
  "deliveryMode": "ONLINE",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "languages": [],
  "requiredSkillIds": [],
  "page": 0,
  "pageSize": 20,
  "providerFilters": []
}
200 full provider-search response:
{
  "checkedAt": "2030-01-01T00:00:00Z",
  "marketId": 1,
  "timezone": "Asia/Colombo",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "providerSelectionMode": "DIRECT_REQUEST",
  "requiredProviderCount": 1,
  "status": "AVAILABLE",
  "totalCandidates": 1,
  "page": 0,
  "pageSize": 20,
  "hasNext": false,
  "candidates": [
    {
      "providerId": 300,
      "assignmentId": 316,
      "optionId": 203,
      "providerLocationId": null,
      "displayName": "Example Provider A",
      "profilePhoto": null,
      "averageRating": 4.8,
      "totalRatings": 25,
      "locationLabel": "ONLINE",
      "mapPoint": null,
      "distanceKm": null,
      "remainingCapacity": 1,
      "languages": [
        "ENGLISH",
        "SINHALA"
      ],
      "providerAttributes": {},
      "mapMarker": {
        "source": "DEFAULT",
        "icon": null,
        "fieldId": null,
        "choiceValue": null,
        "ruleId": null,
        "conditions": []
      }
    }
  ]
}
Full request body for POST /api/v1/customers/me/bookings/quote and, after confirmation, POST /api/v1/customers/me/bookings:
{
  "serviceTypeId": 20,
  "optionId": 203,
  "providerId": 300,
  "deliveryMode": "ONLINE",
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "answers": [],
  "paymentMethod": "CASH",
  "pricingSelections": []
}
200 full quote response:
{
  "rateId": 603,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "estimatedDistanceKm": null,
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": []
  }
}
201 full booking response (assuming unchanged rate/capacity and the same validated inputs):
{
  "jobId": 703,
  "serviceTypeId": 20,
  "optionId": 203,
  "providerId": 300,
  "providerIds": [
    300
  ],
  "deliveryMode": "ONLINE",
  "schedulingModel": "TIME_BASED",
  "fulfillmentModel": "ONE_TO_ONE",
  "capacityUsed": 1,
  "providerLocationId": null,
  "meetingPointName": null,
  "latitude": null,
  "longitude": null,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "destinationLatitude": null,
  "destinationLongitude": null,
  "destinationAddress": null,
  "estimatedDistanceKm": null,
  "estimatedDurationMinutes": null,
  "rateId": 603,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "paymentMethod": "CASH",
  "paymentStatus": "PENDING",
  "status": "PENDING",
  "answers": {},
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": []
  }
}
E. Team service — two providers for one customer
Configure requiredProviderCount 2. Search returns individual candidates, not a grouped team; select exactly two distinct qualified available providers and send providerIds [300,301]. Both must cover the meeting point and interval. This quote is one option rate (2,000), not an automatic 2,000 × 2 per-person multiplication. Fixed-location teams are not demonstrated because one venue ID cannot generally belong to multiple provider assignments.
Relevant Super Admin option configuration:
{
  "schedulingModel": "TIME_BASED",
  "locationEnabled": true,
  "deliveryModes": [
    "PROVIDER_TO_CUSTOMER"
  ],
  "fulfillmentModel": "ONE_CUSTOMER_MANY_PROVIDERS",
  "requiredProviderCount": 2,
  "defaultCapacity": 1,
  "bookingMode": "ONE_AT_A_TIME",
  "providerSelectionMode": "DIRECT_REQUEST",
  "pricingOwner": "ADMIN",
  "allowedPaymentMethods": [
    "CASH"
  ]
}
POST /api/v1/customers/me/provider-search — full request:
{
  "marketId": 1,
  "serviceTypeId": 20,
  "optionId": 204,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "location": {
    "latitude": 6.93,
    "longitude": 79.86
  },
  "radiusKm": 30,
  "languages": [],
  "requiredSkillIds": [],
  "page": 0,
  "pageSize": 20,
  "providerFilters": []
}
200 full provider-search response:
{
  "checkedAt": "2030-01-01T00:00:00Z",
  "marketId": 1,
  "timezone": "Asia/Colombo",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "providerSelectionMode": "DIRECT_REQUEST",
  "requiredProviderCount": 2,
  "status": "AVAILABLE",
  "totalCandidates": 2,
  "page": 0,
  "pageSize": 20,
  "hasNext": false,
  "candidates": [
    {
      "providerId": 300,
      "assignmentId": 318,
      "optionId": 204,
      "providerLocationId": null,
      "displayName": "Example Provider A",
      "profilePhoto": null,
      "averageRating": 4.8,
      "totalRatings": 25,
      "locationLabel": "APPROXIMATE_SERVICE_AREA",
      "mapPoint": {
        "latitude": 6.93,
        "longitude": 79.86
      },
      "distanceKm": 0,
      "remainingCapacity": 1,
      "languages": [
        "ENGLISH",
        "SINHALA"
      ],
      "providerAttributes": {},
      "mapMarker": {
        "source": "DEFAULT",
        "icon": null,
        "fieldId": null,
        "choiceValue": null,
        "ruleId": null,
        "conditions": []
      }
    },
    {
      "providerId": 301,
      "assignmentId": 319,
      "optionId": 204,
      "providerLocationId": null,
      "displayName": "Example Provider B",
      "profilePhoto": null,
      "averageRating": 4.8,
      "totalRatings": 25,
      "locationLabel": "APPROXIMATE_SERVICE_AREA",
      "mapPoint": {
        "latitude": 6.93,
        "longitude": 79.86
      },
      "distanceKm": 0,
      "remainingCapacity": 1,
      "languages": [
        "ENGLISH",
        "SINHALA"
      ],
      "providerAttributes": {},
      "mapMarker": {
        "source": "DEFAULT",
        "icon": null,
        "fieldId": null,
        "choiceValue": null,
        "ruleId": null,
        "conditions": []
      }
    }
  ]
}
Full request body for POST /api/v1/customers/me/bookings/quote and, after confirmation, POST /api/v1/customers/me/bookings:
{
  "serviceTypeId": 20,
  "optionId": 204,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "meetingPoint": {
    "name": "Customer home",
    "addressLine1": "Example address",
    "city": "Colombo",
    "country": "Sri Lanka",
    "latitude": 6.93,
    "longitude": 79.86
  },
  "answers": [],
  "paymentMethod": "CASH",
  "pricingSelections": [],
  "providerIds": [
    300,
    301
  ]
}
200 full quote response:
{
  "rateId": 604,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "estimatedDistanceKm": null,
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": []
  }
}
201 full booking response (assuming unchanged rate/capacity and the same validated inputs):
{
  "jobId": 704,
  "serviceTypeId": 20,
  "optionId": 204,
  "providerId": 300,
  "providerIds": [
    300,
    301
  ],
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "schedulingModel": "TIME_BASED",
  "fulfillmentModel": "ONE_CUSTOMER_MANY_PROVIDERS",
  "capacityUsed": 1,
  "providerLocationId": null,
  "meetingPointName": "Customer home",
  "latitude": 6.93,
  "longitude": 79.86,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "destinationLatitude": null,
  "destinationLongitude": null,
  "destinationAddress": null,
  "estimatedDistanceKm": null,
  "estimatedDurationMinutes": null,
  "rateId": 604,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "paymentMethod": "CASH",
  "paymentStatus": "PENDING",
  "status": "PENDING",
  "answers": {},
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": []
  }
}
F. Car/Bike and gender — configured provider filters
Example option exposes SELECT gender field 501 and MULTI_SELECT vehicle field 502. Definitions are shown before search. gender value MALE is a scalar attribute; vehicle attributes are an array. Filters use arrays in both cases. The example also assumes an active rate conditioned on both choices; therefore quote/booking must separately send pricingSelections. Without such pricing conditions, gender/vehicle filters alone do not affect fares. Car capability does not identify the provider's currently active vehicle.
Relevant Super Admin option configuration:
{
  "schedulingModel": "TIME_BASED",
  "locationEnabled": true,
  "deliveryModes": [
    "PROVIDER_TO_CUSTOMER"
  ],
  "fulfillmentModel": "ONE_TO_ONE",
  "requiredProviderCount": 1,
  "defaultCapacity": 1,
  "bookingMode": "ONE_AT_A_TIME",
  "providerSelectionMode": "DIRECT_REQUEST",
  "pricingOwner": "ADMIN",
  "allowedPaymentMethods": [
    "CASH"
  ]
}
Illustrative booking-context providerFilters projection:
{
  "providerFilters": [
    {
      "fieldId": 501,
      "code": "PROVIDER_GENDER",
      "label": "Provider gender",
      "fieldType": "SELECT",
      "options": [
        "MALE",
        "FEMALE",
        "OTHER"
      ],
      "filterOperator": "IN",
      "icon": null
    },
    {
      "fieldId": 502,
      "code": "VEHICLE_TYPE",
      "label": "Vehicle type",
      "fieldType": "MULTI_SELECT",
      "options": [
        "CAR",
        "BIKE",
        "VAN",
        "TUK_TUK"
      ],
      "filterOperator": "IN",
      "icon": null
    }
  ]
}
POST /api/v1/customers/me/provider-search — full request:
{
  "marketId": 1,
  "serviceTypeId": 20,
  "optionId": 205,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "location": {
    "latitude": 6.93,
    "longitude": 79.86
  },
  "radiusKm": 30,
  "languages": [],
  "requiredSkillIds": [],
  "page": 0,
  "pageSize": 20,
  "providerFilters": [
    {
      "fieldId": 501,
      "value": [
        "MALE"
      ]
    },
    {
      "fieldId": 502,
      "value": [
        "CAR"
      ]
    }
  ]
}
200 full provider-search response:
{
  "checkedAt": "2030-01-01T00:00:00Z",
  "marketId": 1,
  "timezone": "Asia/Colombo",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "providerSelectionMode": "DIRECT_REQUEST",
  "requiredProviderCount": 1,
  "status": "AVAILABLE",
  "totalCandidates": 1,
  "page": 0,
  "pageSize": 20,
  "hasNext": false,
  "candidates": [
    {
      "providerId": 300,
      "assignmentId": 320,
      "optionId": 205,
      "providerLocationId": null,
      "displayName": "Example Provider A",
      "profilePhoto": null,
      "averageRating": 4.8,
      "totalRatings": 25,
      "locationLabel": "APPROXIMATE_SERVICE_AREA",
      "mapPoint": {
        "latitude": 6.93,
        "longitude": 79.86
      },
      "distanceKm": 0,
      "remainingCapacity": 1,
      "languages": [
        "ENGLISH",
        "SINHALA"
      ],
      "providerAttributes": {
        "501": "MALE",
        "502": [
          "CAR",
          "BIKE"
        ]
      },
      "mapMarker": {
        "source": "DEFAULT",
        "icon": null,
        "fieldId": null,
        "choiceValue": null,
        "ruleId": null,
        "conditions": []
      }
    }
  ]
}
Full request body for POST /api/v1/customers/me/bookings/quote and, after confirmation, POST /api/v1/customers/me/bookings:
{
  "serviceTypeId": 20,
  "optionId": 205,
  "providerId": 300,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "meetingPoint": {
    "name": "Customer home",
    "addressLine1": "Example address",
    "city": "Colombo",
    "country": "Sri Lanka",
    "latitude": 6.93,
    "longitude": 79.86
  },
  "answers": [],
  "paymentMethod": "CASH",
  "pricingSelections": [
    {
      "fieldId": 501,
      "choiceValue": "MALE"
    },
    {
      "fieldId": 502,
      "choiceValue": "CAR"
    }
  ]
}
200 full quote response:
{
  "rateId": 605,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "estimatedDistanceKm": null,
  "pricingSelections": [
    {
      "fieldId": 501,
      "choiceValue": "MALE"
    },
    {
      "fieldId": 502,
      "choiceValue": "CAR"
    }
  ],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": [
      {
        "fieldId": 501,
        "choiceValue": "MALE"
      },
      {
        "fieldId": 502,
        "choiceValue": "CAR"
      }
    ]
  }
}
201 full booking response (assuming unchanged rate/capacity and the same validated inputs):
{
  "jobId": 705,
  "serviceTypeId": 20,
  "optionId": 205,
  "providerId": 300,
  "providerIds": [
    300
  ],
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "schedulingModel": "TIME_BASED",
  "fulfillmentModel": "ONE_TO_ONE",
  "capacityUsed": 1,
  "providerLocationId": null,
  "meetingPointName": "Customer home",
  "latitude": 6.93,
  "longitude": 79.86,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "destinationLatitude": null,
  "destinationLongitude": null,
  "destinationAddress": null,
  "estimatedDistanceKm": null,
  "estimatedDurationMinutes": null,
  "rateId": 605,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "paymentMethod": "CASH",
  "paymentStatus": "PENDING",
  "status": "PENDING",
  "answers": {},
  "pricingSelections": [
    {
      "fieldId": 501,
      "choiceValue": "MALE"
    },
    {
      "fieldId": 502,
      "choiceValue": "CAR"
    }
  ],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": [
      {
        "fieldId": 501,
        "choiceValue": "MALE"
      },
      {
        "fieldId": 502,
        "choiceValue": "CAR"
      }
    ]
  }
}
Errors shared by all six patterns
These patterns share the documented ProblemDetail contract: 400 invalid body/field/filter/time/location/provider count/answers/selections or changed capacity; 403 authentication-role/eligibility restrictions as applicable; 404 missing active option/offering or matching price; 409 ambiguous conditional price/marker configuration. Missing/invalid authentication is handled by security, not as an eligibility failure. Search can return HTTP 200 with NO_AVAILABLE_PROVIDERS; when a team has fewer distinct candidates than required, candidates is empty even if totalCandidates is nonzero. Quote success reserves no time or amount and booking creation recalculates. Empty optional arrays do not bypass required schema answers or pricing choices.
Customer workflow aligned with Super Admin service configuration — 22 October 2026
Follow this sequence using IDs and settings returned by the selected market, service and option. The Super Admin tab now documents the full configuration order, request/response examples, shared-option update behavior and live readiness gaps. This workflow supersedes the older screen sequence where quote was omitted.
Customer screen and API sequence
Restore the CUSTOMER session and GET /api/v1/customers/me/profile; complete it with PUT if missing. Read GET /api/v1/markets and select an active market.
GET /api/v1/customers/me/services?marketId=<marketId>. Each item is {service, access}. Only active services with active market offerings are listed. Listing does not guarantee a provider, linked option or price.
GET /api/v1/customers/me/services/{serviceTypeId}/options?marketId=<marketId>. Each item is {option, access}. Only active memberships are returned. Preserve the serviceTypeId + optionId pair, even when the optionId is shared under other services. Never use the admin global catalog as the customer option list.
GET /api/v1/customers/me/booking-context?marketId=<marketId>&serviceTypeId=<serviceTypeId>&optionId=<optionId>. Use selection.option for delivery/scheduling/fulfillment/payment behavior, bookingSchema for per-booking questions, providerFilters for candidate filters and timezone for local booking times. Render icon separately from mapMarkerIcon. liveTrackingSupported is currently false.
Resolve customer access using the returned access/eligibility contract. GET /api/v1/customers/me/requirements?serviceTypeId=<serviceTypeId>&optionId=<optionId>, upload evidence if required, PUT /api/v1/customers/me/requirement-submissions, then GET /api/v1/customers/me/eligibility with the same scope. A submitted answer is not an approval; wait for the required review state before gated search/booking.
Choose a configured delivery mode and future schedule. TIME_BASED needs startAt and endAt in search; physical searches need location and ONLINE must omit it. ROUTE_BASED uses startAt + pickup + destination, with no endAt/location; the backend estimates end time. Choose the search filter values from context.providerFilters, including configured gender if available.
POST /api/v1/customers/me/provider-search. Read candidates, providerAttributes, mapMarker, remainingCapacity and pagination from the response. totalCandidates is filtered candidate-row count, not male/female aggregate counts. Select one provider or the exact requiredProviderCount distinct providers for team options. Do not infer active/current vehicle availability from an approved multi-select capability.
Collect applicable bookingSchema answers as [{fieldId,value}], including backend-configured ward/bed/conditional questions. Prepare independent pricingSelections as [{fieldId,choiceValue}] for every applicable pricing dimension; providerFilters and booking answers do not automatically become pricingSelections. The current context/search response has no dedicated pricing-dimensions/rate catalog, so a generic client cannot reliably infer exact required selections from providerFilters alone. An agreed configuration mapping or additional backend discovery contract is required for fully dynamic variant pricing. Do not guess field IDs or assume every search filter affects price.
POST /api/v1/customers/me/bookings/quote with the complete booking request, selected provider(s), enabled payment method and required answers/selections. Display currencyCode and expectedAmount from the server. Use the full request/response/error examples in the next section. The quote creates no job, locks no capacity, reserves no wallet funds and has no quoteId/expiry/price lock.
After customer confirmation, POST /api/v1/customers/me/bookings using the same final choices. The server rechecks availability and recalculates the price; handle changed availability/amount and show the actual BookingResponse. Current creation is not protected by booking idempotency: do not blindly retry a timed-out create.
Follow payment capabilities and the option's allowedPaymentMethods. WALLET booking creation reserves the amount; POST /api/v1/customers/me/bookings/{jobId}/wallet-payment is the existing reservation endpoint if needed. CARD uses POST .../{jobId}/card-payment-session with Idempotency-Key and the documented mock checkout flow. Configured payment labels do not mean production integration. Creation status PENDING is not payment success.
GET /api/v1/customers/me/bookings returns the authoritative own-booking list; a dedicated customer GET /bookings/{jobId} is still absent. For enabled booking requests, GET /booking-requests/{requestId} and /booking-events provide lifecycle recovery, with idempotent creation, sequential open offers, acceptance, pre-checkout cancellation and payment callbacks documented at the top of this tab. Live tracking and messaging remain unimplemented.
Configuration issues to resolve before customer acceptance testing
Live snapshot: 22 October 2026, approximately 09:33 Sri Lanka time. Shared catalog has 8 options; IDs 2, 3, 4 and 8 have no service links. Only Caregiver service 1 currently has linked options (1, 5, 6, 7). Its options 6/7 have no option-specific rates; rates for unlinked options are not usable through the current linked-option flow. Service 9 (test2) has actual gender field 6 with MALE/FEMALE/OTHER, but has no linked option or market offering. Caregiver and Man Power have no published gender field. Do not reuse test2 field 6 under another service.
Actual combination configuration now exists under Caregiver service 1 / option 1: pricing field IDs 7 and 8, active conditional rates 8 (VAN + ELECTRIC) and 9 (CAR + PETROL), and one configured combination marker rule. These are live configuration observations, not successful customer quote/search results. Older examples using service 6 as Caregiver, option 120, fields 145/147 or rate 710 are illustrative only; live service 6 is Pet Care.
Search and quote routes were verified through deployed validation responses. A successful CUSTOMER-role search/quote/create was not tested, and database migration history has not been confirmed. Per-unit/tree-count pricing and quantity-based duration remain proposed features. Geographic route rates currently use destination coordinates, while provider coverage search uses pickup coordinates.
Verified deployment and client examples — 22 October 2026
This section supersedes deployment assumptions in the dated examples below. Verified against https://jobhub.pentarixlabs.com at approximately 09:28 Sri Lanka time on 22 October 2026. Configuration was read using SUPER_ADMIN; no service configuration or bookings were changed.
Deployment confirmation and remaining verification
POST /api/v1/customers/me/provider-search and POST /api/v1/customers/me/bookings/quote are deployed: authenticated empty-body probes returned HTTP 400 with their expected DTO validation errors. GET on the quote URL returned 405 (use POST). These checks prove routing and request validation, not successful customer matching, correct production prices or payment processing. A successful CUSTOMER-role search and quote has not been verified: no customer login is configured in the workspace. Admin credentials must not be used by the customer app. Production OpenAPI at /v3/api-docs returned 404.
Actual configured gender field
The deployed admin custom-field list contains fieldId 6, code TEST_PROFILE_GENDER, under serviceTypeId 9 (test2). It is ACTIVE, SELECT, scope PROVIDER_REQUIREMENT, reuseScope ASSIGNMENT, valueSource PROVIDER_PROFILE, profileField gender, customerVisible true, searchable true, filterOperator IN, requiresApproval false, with no condition and no option restriction. Exact case-sensitive choice values: MALE, FEMALE, OTHER. The live definitions also include display labels/icons; consume those from the schema rather than hardcoding them.
{
  "fieldId": 6,
  "serviceTypeId": 9,
  "code": "TEST_PROFILE_GENDER",
  "fieldType": "SELECT",
  "options": [
    {
      "value": "MALE",
      "label": "Male"
    },
    {
      "value": "FEMALE",
      "label": "Female"
    },
    {
      "value": "OTHER",
      "label": "Other"
    }
  ],
  "valueSource": "PROVIDER_PROFILE",
  "profileField": "gender",
  "status": "ACTIVE",
  "customerVisible": true,
  "searchable": true,
  "filterOperator": "IN"
}
This is a real deployed field, but not a global gender field. No gender field was found for service 1 (Caregiver), service 5 (Man Power), or the other listed services. GET /api/v1/admin/provider-types/9/options returned no linked options, so there is currently no service-9 option to use for an end-to-end gender search. Admin configuration is still needed for the intended customer-facing services/options. Do not send fieldId 6 to another service or assume that a database field alone makes a customer flow ready.
Discover providerFilters, then search
GET /api/v1/customers/me/booking-context?marketId=<marketId>&serviceTypeId=<serviceTypeId>&optionId=<optionId> returns providerFilters with fieldId, code, label, fieldType, options, filterOperator and icon. Only send filters advertised by the context for the selected service/option. Re-fetch when the selection changes. The schema response below is an illustrative projection after service 9 has a valid active option; it was not returned by a live customer request.
{
  "providerFilters": [
    {
      "fieldId": 6,
      "code": "TEST_PROFILE_GENDER",
      "label": "Gender",
      "fieldType": "SELECT",
      "options": [
        {
          "value": "MALE",
          "label": "Male"
        },
        {
          "value": "FEMALE",
          "label": "Female"
        },
        {
          "value": "OTHER",
          "label": "Other"
        }
      ],
      "filterOperator": "IN",
      "icon": null
    }
  ]
}
POST /api/v1/customers/me/provider-search — complete illustrative TIME_BASED request. serviceTypeId 9 and gender fieldId 6 are real; marketId 1, optionId 900001, providerId 900002 and rateId 900003 used in the following examples are illustrative, not verified deployed records. Option 900001 is assumed to be an active TIME_BASED / PROVIDER_TO_CUSTOMER / ONE_TO_ONE option with cash enabled and no additional required booking answers. Replace all illustrative IDs and future timestamps with current configuration and customer input. This is not a production smoke-test payload.
{
  "marketId": 1,
  "serviceTypeId": 9,
  "optionId": 900001,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startAt": "2030-01-07T09:00:00+05:30",
  "endAt": "2030-01-07T11:00:00+05:30",
  "location": {
    "latitude": 6.9271,
    "longitude": 79.8612
  },
  "radiusKm": 10,
  "languages": [],
  "requiredSkillIds": [],
  "page": 0,
  "pageSize": 20,
  "providerFilters": [
    {
      "fieldId": 6,
      "value": [
        "MALE"
      ]
    }
  ]
}
To allow either gender, send {"fieldId":6,"value":["MALE","FEMALE"]}. To apply no gender restriction, omit that filter. A SELECT filter still takes an array; a candidate SELECT attribute is a scalar string. Values within one filter use OR; different fields use AND. Unknown/unavailable fields, unsupported choices, empty or duplicate choices, duplicate field IDs, or more than 50 filters return 400. A missing/invalid provider gender excludes that provider when filtering by gender.
Read providerAttributes and filtered counts
Illustrative response fragment only; the normal Results wrapper and other candidate fields remain unchanged:
{
  "status": "AVAILABLE",
  "totalCandidates": 1,
  "page": 0,
  "pageSize": 20,
  "hasNext": false,
  "candidates": [
    {
      "providerId": 900002,
      "assignmentId": 900005,
      "optionId": 900001,
      "providerAttributes": {
        "6": "MALE"
      }
    }
  ]
}
providerAttributes is a JSON object keyed by the string form of fieldId: read candidate.providerAttributes["6"], not candidate.gender. Render the configured choice label for the returned value. Attributes contain applicable public supported fields: approved manual values or valid self-declared profile-backed PROVIDED values. Profile-backed gender is not a verified/background-check badge. totalCandidates is the count after all search filters and before pagination; it counts candidate rows, which can include provider/location combinations. Separate male/female aggregate counts and customer-selected male/female team quantities are not implemented.
Booking quote — TIME_BASED request and full response
POST /api/v1/customers/me/bookings/quote; Authorization: Bearer <customer-access-token>; Content-Type: application/json. The same CreateBookingRequest body is used by POST /api/v1/customers/me/bookings. Provider selection, service eligibility, required answers, enabled payment method, coverage, availability and applicable pricing selections must all be valid. A search filter is not a booking answer or a pricing selection: do not copy providerFilters into this request.
{
  "serviceTypeId": 9,
  "optionId": 900001,
  "providerId": 900002,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startDatetime": "2030-01-07T09:00:00",
  "expectedEndDatetime": "2030-01-07T11:00:00",
  "meetingPoint": {
    "name": "Customer home",
    "addressLine1": "Example address",
    "city": "Colombo",
    "country": "Sri Lanka",
    "latitude": 6.9271,
    "longitude": 79.8612
  },
  "customerNote": "Please call on arrival.",
  "answers": [],
  "paymentMethod": "CASH",
  "pricingSelections": []
}
Illustrative HTTP 200 response assumes a matching LKR 1,000 hourly rate with durationMinutes 60 and no pricing conditions:
{
  "rateId": 900003,
  "currencyCode": "LKR",
  "expectedAmount": 2000,
  "startDatetime": "2030-01-07T09:00:00",
  "expectedEndDatetime": "2030-01-07T11:00:00",
  "estimatedDistanceKm": null,
  "pricingSelections": [],
  "pricingSnapshot": {
    "billingType": "HOURLY",
    "durationMinutes": 60,
    "rate": 1000,
    "baseFare": null,
    "pricePerKm": null,
    "minimumFare": null,
    "conditions": []
  }
}
Search timestamps are offset-bearing startAt/endAt. Booking/quote timestamps are market-local startDatetime/expectedEndDatetime without an offset. TIME_BASED requires startDatetime < expectedEndDatetime and rejects route fields. Choose a future interval no longer than 31 days; timezone-transition intervals are rejected. For a team option use providerIds with the configured exact required count. Each selected provider must qualify and offer every selected pricing choice.
Route quotes and price selection
The full ROUTE_BASED request/response example remains in the 21 October section below. For route quotes use requestedPickupTime plus pickup and destination (each with address, latitude and longitude); omit startDatetime, expectedEndDatetime, meetingPoint and providerLocationId. The backend derives the end time using straight-line distance and configured average speed (default 40 km/h). It rounds estimatedDistanceKm to two decimals and calculates max(minimumFare, baseFare + estimatedDistanceKm × pricePerKm). No road routing or traffic ETA is integrated.
Geographic pricing correction: current CustomerBookingService uses DESTINATION coordinates for ROUTE_BASED rate-area matching, not pickup coordinates. Time-based rates use the resolved booking location. Area configuration is centre plus radius, not a pickup-zone/destination-zone matrix. Applicable conditional prices prioritize the greatest condition count, then the smallest area radius. Any desired pickup-based behavior requires a backend change.
If applicable rates have conditions, send pricingSelections as [{fieldId, choiceValue}], selecting exactly one value for every distinct applicable pricing field (maximum 10). These are independent from providerFilters and booking answers. The server rejects missing, extra, duplicate or unsupported selections and providers that do not offer the selections. A gender search filter does not automatically change the price; gender must separately be an applicable pricing condition if pricing is meant to vary by it.
Quote returns no jobId, quoteId, expiresAt, fee breakdown or per-person allocation. It creates no booking, takes no provider locks and reserves neither availability nor wallet funds. No price-lock/quote-expiry mechanism exists. Booking creation rechecks availability/eligibility and recalculates pricing, so the final amount may change. Current pricing supports FIXED, HOURLY, DAILY and ROUTE_BASED; the discussed PER_UNIT/tree-count pricing and automatic duration per unit are proposals, not implemented endpoints.
Quote error examples and client handling
Live-observed HTTP 400 for POST /api/v1/customers/me/bookings/quote with {} (probe used an admin login and validates only the request layer, not CUSTOMER-role success):
{
  "type": "about:blank",
  "title": "Validation failed",
  "status": 400,
  "detail": "The request contains invalid fields",
  "instance": "/api/v1/customers/me/bookings/quote",
  "errors": {
    "serviceTypeId": "must not be null",
    "deliveryMode": "must not be blank",
    "optionId": "must not be null"
  }
}
Source-derived examples below are illustrative, not live customer responses. Missing provider/profile, invalid times/mode/location/payment/answers, unavailable providers, changed capacity and invalid pricing selections generally return 400. Eligibility failures return 403 with an eligibility object. Missing active option/market or matching rate returns 404. Equally specific conditional rates return 409. Authentication failures and role restrictions must be handled separately from eligibility. Render the returned problem detail and field errors; do not treat all 403 responses as missing customer requirements.
{
  "type": "about:blank",
  "title": "Invalid request value",
  "status": 400,
  "detail": "Provider capacity changed; search again",
  "instance": "/api/v1/customers/me/bookings/quote"
}
{
  "type": "about:blank",
  "title": "Resource not found",
  "status": 404,
  "detail": "No active price is configured for the selected choices, market and service option",
  "instance": "/api/v1/customers/me/bookings/quote"
}
{
  "type": "about:blank",
  "title": "Resource conflict",
  "status": 409,
  "detail": "Multiple equally specific prices match the selected choices",
  "instance": "/api/v1/customers/me/bookings/quote"
}
On availability/capacity failure, repeat provider search and ask the customer to confirm the new selection. On pricing configuration errors, do not invent a fare. A successful quote is not a booking or payment confirmation. Booking-create idempotency and automatic open-request matching are not added by this documentation update.
Customer API update — shared options, combination markers and price quotes — 21 October 2026
The 21 October examples below are illustrative; see the 22 October section above for live deployment checks and actual configured IDs. All IDs, URLs, timestamps and results in this update are illustrative. This update uses main service 6 (Caregiver), option 120 (Ride), field 145 (Vehicle type), field 147 (Fuel type), provider 15, assignment 140, market 1, offering 70, price 710 and marker rule 80. Do not combine these illustrative IDs with the older nursing examples.
All customer-specific requests require Authorization: Bearer <customer-access-token>. Use Content-Type: application/json for JSON requests. Customers read configuration and select choices; only SUPER_ADMIN manages prices and marker rules.
Endpoint quick reference

Method / success
Endpoint
GET / 200
/api/v1/customers/me/services/6/options?marketId=1
GET / 200
/api/v1/customers/me/booking-context?marketId=1&serviceTypeId=6&optionId=120
POST / 200
/api/v1/customers/me/provider-search
POST / 200
/api/v1/customers/me/bookings/quote
POST / 201
/api/v1/customers/me/bookings
GET / 200
/api/v1/customers/me/bookings


Read linked options and keep choice identifiers stable
A main service's option list includes linked options. The same optionId can appear under several main services; the returned serviceTypeId, displayOrder/status and dynamicFields refer to the requested link. Inactive links are excluded without removing the option from other active services.
New metadata: ProviderTypeResponse and ServiceSetupResponse have nullable mapMarkerIcon. ServiceOptionResponse has nullable mapMarkerIcon and mapMarkerFieldId. Choice objects may contain both icon and mapMarkerIcon. Use icon for lists/selection controls; map marker assets are independent.
Read providerFilters from booking-context. Continue rendering BOOKING_FIELD definitions as booking answers and customer requirements as requirementId submissions. These three channels are separate.
Search Car + Electric and render the resolved map marker
POST /api/v1/customers/me/provider-search
{
  "marketId": 1,
  "serviceTypeId": 6,
  "optionId": 120,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startAt": "2030-01-07T08:00:00+05:30",
  "pickup": {
    "latitude": 6.9271,
    "longitude": 79.8612
  },
  "destination": {
    "latitude": 7,
    "longitude": 79.9
  },
  "providerFilters": [
    {
      "fieldId": 145,
      "value": [
        "CAR"
      ]
    },
    {
      "fieldId": 147,
      "value": [
        "ELECTRIC"
      ]
    }
  ],
  "page": 0,
  "pageSize": 20
}
Search uses arrays for SELECT/MULTI_SELECT filters. A single value selects a particular variant. More than one value in a field is an OR filter and does not identify one exact variant for that field's marker condition.
Response candidate excerpt:
{
  "providerId": 15,
  "assignmentId": 140,
  "optionId": 120,
  "providerLocationId": null,
  "displayName": "Example Provider",
  "profilePhoto": null,
  "locationLabel": "APPROXIMATE_SERVICE_AREA",
  "mapPoint": {
    "latitude": 6.93,
    "longitude": 79.86
  },
  "providerAttributes": {
    "145": [
      "CAR",
      "VAN"
    ],
    "147": "ELECTRIC"
  },
  "mapMarker": {
    "source": "COMBINATION",
    "icon": {
      "key": "markers/electric-car.png",
      "url": "https://cdn.example.com/markers/electric-car.png",
      "altText": "Electric car",
      "displayOrder": 0
    },
    "fieldId": null,
    "choiceValue": null,
    "ruleId": 80,
    "conditions": [
      {
        "fieldId": 145,
        "choiceValue": "CAR"
      },
      {
        "fieldId": 147,
        "choiceValue": "ELECTRIC"
      }
    ]
  }
}
Render candidate.mapMarker.icon.url on the map; keep profilePhoto for provider cards. The active matching combination with the most conditions wins. If none matches, use the selected choice marker from mapMarkerFieldId, then option marker, main-service marker, then the built-in default pin. Equally specific matching rules fail with 409 rather than choosing an arbitrary icon.
mapMarker.source is COMBINATION, CHOICE, OPTION, SERVICE or DEFAULT. Combination markers include ruleId and conditions; their singular fieldId/choiceValue are null. Other sources have ruleId: null and conditions: []. DEFAULT has icon: null. ONLINE candidates still have mapPoint: null; travelling pins remain approximate coverage centres, not live vehicle positions.
Quote and book using final pricing selections
Search filters are not automatically retained for booking. Send final single choices only for applicable pricing dimensions in pricingSelections; do not copy every search filter. BOOKING_FIELD answers and reusable customer requirements remain separate.
Send the following complete route request to either endpoint:
POST /api/v1/customers/me/bookings/quote  → 200 BookingQuoteResponse
POST /api/v1/customers/me/bookings        → 201 BookingResponse
{
  "serviceTypeId": 6,
  "optionId": 120,
  "providerId": 15,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "requestedPickupTime": "2030-01-07T08:00:00",
  "pickup": {
    "address": "10 Main Street, Colombo",
    "latitude": 6.9271,
    "longitude": 79.8612
  },
  "destination": {
    "address": "Destination address",
    "latitude": 7,
    "longitude": 79.9
  },
  "paymentMethod": "CASH",
  "answers": [],
  "pricingSelections": [
    {
      "fieldId": 145,
      "choiceValue": "CAR"
    },
    {
      "fieldId": 147,
      "choiceValue": "ELECTRIC"
    }
  ]
}
This example assumes an approved, available provider covering the pickup, a valid market, no additional required BOOKING_FIELD answers, and an active Car + Electric price of baseFare 250, pricePerKm 100, minimumFare 500. Actual selections, addresses, IDs and future times must come from current configuration/customer input.
Illustrative full quote response for those inputs and routeAverageSpeedKmh: 40:
{
  "rateId": 710,
  "currencyCode": "LKR",
  "expectedAmount": 1167,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T08:14:00",
  "estimatedDistanceKm": 9.17,
  "pricingSelections": [
    {
      "fieldId": 145,
      "choiceValue": "CAR"
    },
    {
      "fieldId": 147,
      "choiceValue": "ELECTRIC"
    }
  ],
  "pricingSnapshot": {
    "billingType": "ROUTE_BASED",
    "durationMinutes": null,
    "rate": null,
    "baseFare": 250,
    "pricePerKm": 100,
    "minimumFare": 500,
    "conditions": [
      {
        "fieldId": 145,
        "choiceValue": "CAR"
      },
      {
        "fieldId": 147,
        "choiceValue": "ELECTRIC"
      }
    ]
  }
}
Distance is the existing straight-line estimate rounded to 2 decimals, not a road-routing promise. Route fare is max(minimumFare, baseFare + estimatedDistanceKm × pricePerKm). Quote performs the same eligibility/provider/schedule/location/payment/answer checks without creating a job, taking provider locks or reserving capacity/wallet funds. It is a preview, not a fare or availability reservation.
Booking creation revalidates, locks/checks provider capacity and recalculates the price. The full BookingResponse and booking-list entries now include pricingSelections and pricingSnapshot alongside rateId and expectedAmount. Saved choices, rate parameters and fare do not change when an admin later edits the rate; old bookings may have null snapshots.
Booking response excerpt:
{
  "jobId": 1001,
  "serviceTypeId": 6,
  "optionId": 120,
  "providerId": 15,
  "rateId": 710,
  "currencyCode": "LKR",
  "expectedAmount": 1167,
  "status": "PENDING",
  "paymentMethod": "CASH",
  "paymentStatus": "PENDING",
  "pricingSelections": [
    {
      "fieldId": 145,
      "choiceValue": "CAR"
    },
    {
      "fieldId": 147,
      "choiceValue": "ELECTRIC"
    }
  ],
  "pricingSnapshot": {
    "billingType": "ROUTE_BASED",
    "durationMinutes": null,
    "rate": null,
    "baseFare": 250,
    "pricePerKm": 100,
    "minimumFare": 500,
    "conditions": [
      {
        "fieldId": 145,
        "choiceValue": "CAR"
      },
      {
        "fieldId": 147,
        "choiceValue": "ELECTRIC"
      }
    ]
  }
}
Pricing selection and error rules
pricingSelections accepts at most 10 distinct field IDs, one stable string choice per field. Provider MULTI_SELECT capability does not make a booking vehicle selection an array.
Select every distinct pricing field used by active, effective, geographically applicable rates; extra fields are rejected. Omitting selections cannot bypass a conditional price by falling back to a cheaper unconditional rate.
All price conditions must match. Prefer the greatest condition count, then the smallest applicable geographical radius. Equally specific conditional prices return 409; legacy unconditional rates retain latest-effective-from precedence.
Every selected provider must offer every pricing choice using approved manual answers or the existing allowlisted profile-backed PROVIDED values. Team bookings check every member.
400: missing/extra/duplicate/invalid pricing choices or unsupported provider combination. 404: no matching price or invalid scope. 409: ambiguous price/marker rules or existing concurrency conflicts. Customer eligibility errors remain 403 with eligibility details.
Do not send client price, distance or rate overrides. Provider search still returns no fare. Use /bookings/quote, then create the booking using the final choices.
Legacy bookings without applicable conditional rates may omit pricingSelections. Payment execution remains governed by the existing Wallet/Card capability contracts; a quote or PENDING booking is not payment success.
Customer tab update: provider filters and field/choice icons (2026-10-20)

Implemented locally; deployment is not verified. These additions supplement the
numbered reference. Customers consume admin-configured metadata; the customer app
does not expose admin configuration or icon-upload controls.

Discover filters for the selected option

GET /api/v1/customers/me/booking-context?marketId=1&serviceTypeId=3&optionId=12

Success 200: existing context plus providerFilters. Response fragment:

{
  "matchingFilters":["languages","requiredSkillIds","providerFilters"],
  "providerFilters":[
    {
      "fieldId":25,"code":"VEHICLE_TYPE","label":"Vehicle type",
      "fieldType":"SELECT","filterOperator":"IN",
      "icon":{"key":"service-icons/vehicle.png","url":"https://your-bucket.example/service-icons/vehicle.png"},
      "options":[
        {"value":"CAR","label":"Car","icon":{"key":"service-icons/car.png","url":"https://your-bucket.example/service-icons/car.png"}},
        {"value":"VAN","label":"Van","icon":null},
        "BIKE"
      ]
    },
    {"fieldId":26,"code":"EXPERIENCE","label":"Experience years","fieldType":"NUMBER","options":null,"filterOperator":"RANGE","icon":null},
    {"fieldId":27,"code":"OWN_VEHICLE","label":"Own vehicle","fieldType":"BOOLEAN","options":null,"filterOperator":"EQUALS","icon":null}
  ]
}

Only active applicable fields explicitly enabled by admin appear. SELECT/MULTI_SELECT
render choices, NUMBER renders inclusive min/max inputs, BOOLEAN renders Yes/No.
Empty providerFilters means no dynamic filters. Re-fetch on service/option change
and clear obsolete selections. Support string choices and {value,label,icon} objects;
fallback to value for missing label, text-only for missing icon. Field and choice icons
are independently optional.

Search using stable values

POST /api/v1/customers/me/provider-search

{
  "marketId":1,"serviceTypeId":3,"optionId":12,"deliveryMode":"ONLINE",
  "startAt":"2030-01-07T08:00:00+05:30","endAt":"2030-01-07T10:00:00+05:30",
  "languages":["ENGLISH"],"requiredSkillIds":[],
  "providerFilters":[
    {"fieldId":25,"value":["CAR","VAN"]},
    {"fieldId":26,"minimum":3},
    {"fieldId":27,"value":true}
  ],
  "page":0,"pageSize":20
}

Use actual IDs, future times and an enabled delivery mode. ONLINE omits location;
physical searches require it. Submit values only, never labels/icons/choice objects.
Filters AND-combine with each other and languages/skills. IN accepts any requested
choice (any overlap for MULTI_SELECT). RANGE permits either or both bounds. EQUALS
takes a boolean. Omit providerFilters or send [] to clear dynamic filtering.

Success 200: existing Results wrapper/pagination; candidates additionally include
providerAttributes keyed by field ID, e.g. {"25":"CAR","26":5,"27":true}.
Only approved manual answers or valid linked profile values from customer-visible fields are included. Reuse is
resolved by backend. Display-only fields may appear but cannot be queried. No-review
fields are auto-approved; do not label all attributes independently verified.
Private uploads and pending/rejected/invalid answers are excluded. Filtering occurs
before pagination and does not reserve capacity or create a booking.

400: unavailable/private/inactive/other-option field, invalid choice/type/range,
duplicate IDs/choices, over 50 filters or over 100 choices per filter.
403: customer eligibility failed. Do not retry invalid filters unchanged.

Booking fields remain separate

Profile-backed provider filters: admin can publish gender from provider profile and
age derived from provider DOB. These are live self-declared PROVIDED values; they
can match filters without a duplicate provider submission. Do not label them verified.
Raw DOB, NIC/passport and other private profile details cannot be published through
this mapping. Customer profile/patient fields are not auto-filled from provider data.

bookingSchema BOOKING_FIELD definitions also carry optional field and choice icons.
Render common plus selected-option fields, respecting required/conditions. Final booking
answers remain {fieldId,value}: SELECT sends "CAR", MULTI_SELECT sends ["CAR","VAN"].
Do not submit provider requirement filter IDs inside BOOKING_FIELD answers. For combination pricing, send the final selected stable values separately as pricingSelections; search filters are not carried forward automatically.
Reusable customer NIC/DOB requirements retain their own requirementId,
definition wrapper and submission APIs; provider document date modes do not govern them.

Full contracts: provider filters
and choice icons.


Contract checked against the local Java controllers, DTOs, and services on 2026-10-20. New APIs are implemented locally; deployment has not been verified. This reference covers customer registration through discovery, plus the existing final booking handoff. IDs, URLs, tokens, times and results in examples are illustrative, not live data. Use actual configured IDs and future times.

1. Connection, authentication and conventions

Base URL: https://jobhub.pentarixlabs.com

All paths below include /api/v1. JSON writes use Content-Type: application/json. Protected calls use Authorization: Bearer <access-token>. Customer-specific routes require role CUSTOMER. Registration/login/OTP/refresh/logout-current are public credential endpoints; logout-all, users/me, markets and uploads require bearer authentication. Never send an admin token from the customer application.

GET endpoints have no request body. An empty JSON array is a valid empty list response. Lists returned by catalog/options/markets/requirements/bookings are raw arrays, not {data: ...} wrappers. Search is a results object with its own pagination. Missing data can be null; do not replace null with guessed IDs or URLs. JSON property names and enum values are case-sensitive unless stated otherwise. Treat IDs as opaque Java Long values; use a lossless JSON strategy if IDs exceed JavaScript safe integers. Monetary values/coordinates are JSON numbers; use decimal-safe arithmetic for displayed prices.

Search uses offset-aware ISO timestamps. Booking uses market-local timestamps without an offset. Date fields use YYYY-MM-DD. Local time fields use HH:mm:ss (HH:mm is also parseable). Instant fields, including upload URL expiry and checkedAt, use an offset such as Z. Do not hardcode timezone/currency from the phone locale; read the selected market.

2. Endpoint inventory and screen sequence

Email registration — POST /api/v1/auth/register — 201 RegisterResponse
Email verification — POST /api/v1/auth/email/verify — 200 LoginResponse
Resend verification — POST /api/v1/auth/email/resend — 202 OtpRequestResponse
Password login — POST /api/v1/auth/login — 200 LoginResponse
Phone OTP request — POST /api/v1/auth/otp/request — 202 OtpRequestResponse
Phone OTP verification — POST /api/v1/auth/otp/verify — 200 LoginResponse
Google login — POST /api/v1/auth/google — 200 LoginResponse
Refresh session — POST /api/v1/auth/refresh — 200 LoginResponse
Logout current session — POST /api/v1/auth/logout — 204, no body
Logout all sessions — POST /api/v1/auth/logout-all — 204, no body
Restore current user — GET /api/v1/users/me — 200 CurrentUserResponse
Read/save customer profile — GET / PUT /api/v1/customers/me/profile — 200 CustomerProfileResponse
Choose market — GET /api/v1/markets — 200 MarketResponse[]
Browse services — GET /api/v1/customers/me/services?marketId=1 — 200 ServiceCard[]
Choose service option — GET /api/v1/customers/me/services/3/options?marketId=1 — 200 OptionCard[]
Load settings/form — GET /api/v1/customers/me/booking-context?marketId=1&serviceTypeId=3&optionId=12 — 200 Context
Load customer requirements — GET /api/v1/customers/me/requirements?serviceTypeId=3&optionId=12 — 200 FormItem[]
Private evidence upload — POST /api/v1/uploads/documents — 200 FileUploadResponse
Public profile image upload — POST /api/v1/uploads/images — 201 FileUploadResponse
View private evidence — GET /api/v1/uploads/view-url?key=<encoded-key> — 200 PresignedUrlResponse
Save reusable customer answers — PUT /api/v1/customers/me/requirement-submissions — 200 Submission[]
Recheck eligibility — GET /api/v1/customers/me/eligibility?serviceTypeId=3&optionId=12 — 200 Eligibility
Search available providers — POST /api/v1/customers/me/provider-search — 200 Results
Preview booking price — POST /api/v1/customers/me/bookings/quote — 200 BookingQuoteResponse
Final booking handoff — POST /api/v1/customers/me/bookings — 201 BookingResponse
Own booking history — GET /api/v1/customers/me/bookings — 200 BookingResponse[]

Register/login → GET profile (404 means complete it) → choose market/location → services → linked options → context/access check → complete requirements/review if needed → select delivery/time/providerFilters → provider search → select provider(s) → booking answers and pricingSelections → server quote → customer confirmation → final booking → checkout if applicable → own booking history. Keep selected service/option in navigation when opening requirements, so the customer can return to the same flow.

3. Email registration

POST /api/v1/auth/register

Request body:

{
  "email": "customer@example.com",
  "password": "StrongPassword123!",
  "accountType": "CUSTOMER"
}

Success: 201 Created.

{
  "id": 25,
  "username": "customer01",
  "email": "customer@example.com",
  "phoneNumber": null,
  "status": "PENDING",
  "emailVerified": false,
  "phoneVerified": false,
  "roles": [
    "CUSTOMER"
  ]
}

Required: email (valid, max 254), password (10–72 characters), accountType. The public accountType enum also supports SERVICE_PROVIDER, but this app sends CUSTOMER. Username is generated; do not send username, role, profile or address here. Registration sends email OTP and does not return tokens. Email is normalized to lowercase. Errors: 400 invalid input; 409 duplicate account; 429 OTP cooldown; delivery/configuration failure can return 500.

4. Verify email

POST /api/v1/auth/email/verify

Request body:

{
  "email": "customer@example.com",
  "otp": "123456"
}

Success: 200 OK.

{
  "accessToken": "<access-token>",
  "refreshToken": "<refresh-token>",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": 25,
    "username": "customer01",
    "email": "customer@example.com",
    "status": "ACTIVE",
    "marketId": null,
    "roles": [
      "CUSTOMER"
    ]
  }
}

Both fields required. OTP is a six-digit string (preserve leading zeroes). Default OTP expiry is 300 seconds and maximum failed attempts is 5; server configuration may differ. Success activates the account and authenticates it. Errors: 400 invalid format; 401 invalid/expired/used OTP or attempt limit.

5. Resend email OTP

POST /api/v1/auth/email/resend

Request body:

{
  "email": "customer@example.com"
}

Success: 202 Accepted.

{
  "message": "If the email is awaiting verification, a code has been sent",
  "expiresIn": 300
}

email is required and must be valid. Response is intentionally generic, not proof that an account exists. Use retryAfterSeconds / Retry-After on 429; default resend cooldown is 60 seconds.

6. Password login

POST /api/v1/auth/login

Request body:

{
  "identifier": "customer@example.com",
  "password": "StrongPassword123!"
}

Success: 200 OK.

{
  "accessToken": "<access-token>",
  "refreshToken": "<refresh-token>",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": 25,
    "username": "customer01",
    "email": "customer@example.com",
    "status": "ACTIVE",
    "marketId": null,
    "roles": [
      "CUSTOMER"
    ]
  }
}

identifier and password must be nonblank. identifier accepts email or generated username. Do not send accountType to this endpoint. Email-registered users must verify before password login. Wrong credentials/inactive account returns 401. Confirm returned roles includes CUSTOMER before entering the customer interface.

7. Phone registration/login — request OTP

POST /api/v1/auth/otp/request

Request body:

{
  "phoneNumber": "+94771234567",
  "accountType": "CUSTOMER"
}

Success: 202 Accepted.

{
  "message": "If the phone number is eligible, an OTP has been sent",
  "expiresIn": 300
}

Both properties required. phoneNumber must match E.164: ^\+[1-9][0-9]{7,14}$. No purpose/type field. Response is generic. Text.lk must be configured. A new number becomes an account on successful verification; an existing matching account signs in. Handle 400/429 without revealing whether a number exists.

8. Phone registration/login — verify OTP

POST /api/v1/auth/otp/verify

Request body:

{
  "phoneNumber": "+94771234567",
  "otp": "123456",
  "accountType": "CUSTOMER"
}

Success: 200 OK.

{
  "accessToken": "<access-token>",
  "refreshToken": "<refresh-token>",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": 25,
    "username": "customer01",
    "email": "customer@example.com",
    "status": "ACTIVE",
    "marketId": null,
    "roles": [
      "CUSTOMER"
    ]
  }
}

All three properties required; phone is E.164, OTP exactly six digits. LoginResponse.user.email may be null for phone-only accounts; username is generated. Do not require an email on the next screen just because the illustrative login sample has one. Errors: 400 invalid input; 401 invalid/expired OTP or account mismatch.

9. Google authentication

POST /api/v1/auth/google

Request body:

{
  "idToken": "<google-id-token>",
  "accountType": "CUSTOMER"
}

Success: 200 OK.

{
  "accessToken": "<access-token>",
  "refreshToken": "<refresh-token>",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": 25,
    "username": "customer01",
    "email": "customer@example.com",
    "status": "ACTIVE",
    "marketId": null,
    "roles": [
      "CUSTOMER"
    ]
  }
}

Both fields required. Obtain a Google ID token, not a Google access token. Google client configuration must match the backend. Existing linked accounts retain their stored role; inspect returned roles. Errors: 400 missing data; 401 invalid token/inactive or unsupported account. This document does not imply that a production Google client is configured.

10. Refresh authentication

POST /api/v1/auth/refresh

Request body:

{
  "refreshToken": "<current-refresh-token>"
}

Success: 200 OK.

{
  "accessToken": "<access-token>",
  "refreshToken": "<refresh-token>",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": 25,
    "username": "customer01",
    "email": "customer@example.com",
    "status": "ACTIVE",
    "marketId": null,
    "roles": [
      "CUSTOMER"
    ]
  }
}

refreshToken is required/nonblank. Replace BOTH stored tokens atomically on success: refresh tokens rotate. Serialize refresh operations so concurrent 401s do not replay the same refresh token. On refresh 401, clear the session and return to login. Retry only safe reads automatically; do not blindly retry a non-idempotent booking.

11. Logout current session

POST /api/v1/auth/logout

Request body:

{
  "refreshToken": "<current-refresh-token>"
}

Success: 204 No Content.

No response body.

No JSON response body; do not attempt JSON parsing. Revoke the refresh session and clear local credentials.

12. Logout every session

POST /api/v1/auth/logout-all

Request body:

None.

Success: 204 No Content.

No response body.

Requires bearer authentication. Revokes all refresh sessions. Existing short-lived access tokens can remain usable until their expiry.

13. Current authenticated user

GET /api/v1/users/me

Request body:

None.

Success: 200 OK.

{
  "id": 25,
  "username": "customer01",
  "email": "customer@example.com",
  "status": "ACTIVE",
  "marketId": null,
  "roles": [
    "CUSTOMER"
  ]
}

Exact CurrentUserResponse fields: id (integer), username (string), email (string|null), status (string), marketId (integer|null), roles (string[]). For CUSTOMER marketId is null: it is not the selected discovery market. Store selected marketId in app state and send it on discovery requests. LoginResponse always has accessToken, refreshToken, tokenType, expiresIn (seconds), user. expiresIn is server-provided; 900 is the default, not a client constant.

14. Create/replace customer profile

PUT /api/v1/customers/me/profile

Request body:

{
  "firstName": "Jane",
  "lastName": "Doe",
  "profilePhoto": null,
  "addressLine1": "10 Main Street",
  "addressLine2": null,
  "city": "Colombo",
  "district": "Colombo",
  "province": "Western",
  "postalCode": "00100",
  "country": "Sri Lanka"
}

Success: 200 OK.

{
  "customerId": 7,
  "userId": 25,
  "firstName": "Jane",
  "lastName": "Doe",
  "profilePhoto": null,
  "addressLine1": "10 Main Street",
  "addressLine2": null,
  "city": "Colombo",
  "district": "Colombo",
  "province": "Western",
  "postalCode": "00100",
  "country": "Sri Lanka",
  "status": "ACTIVE",
  "profileCompleted": true
}

Full replacement/upsert for these fields. Required nonblank: firstName (max100), lastName (max100), addressLine1 (max255), city (max100), country (max100). Optional nullable: profilePhoto (max2048), addressLine2 (max255), district/province (max100 each), postalCode (max20). Omitting optional values clears them through the existing replacement behavior. Do not send userId, customerId, status or profileCompleted. DOB, gender and NIC are configured reusable requirements, not profile DTO properties. Authentication must be CUSTOMER.

15. Read customer profile

GET /api/v1/customers/me/profile

Request body:

None.

Success: 200 OK.

{
  "customerId": 7,
  "userId": 25,
  "firstName": "Jane",
  "lastName": "Doe",
  "profilePhoto": null,
  "addressLine1": "10 Main Street",
  "addressLine2": null,
  "city": "Colombo",
  "district": "Colombo",
  "province": "Western",
  "postalCode": "00100",
  "country": "Sri Lanka",
  "status": "ACTIVE",
  "profileCompleted": true
}

404 means no saved profile: route to profile completion. The current implementation returns profileCompleted:true for a persisted profile, not a dynamic document-eligibility percentage. customerId (entity ID) and userId (authentication ID) are different; private file keys use userId.

16. Active markets

GET /api/v1/markets

Request body:

None.

Success: 200 OK.

[
  {
    "id": 1,
    "name": "Sri Lanka",
    "countryCode": "LK",
    "currencyCode": "LKR",
    "timezone": "Asia/Colombo",
    "locale": "en-LK",
    "phoneCode": "+94",
    "status": "ACTIVE",
    "createdAt": "2026-01-01T10:00:00",
    "updatedAt": "2026-01-01T10:00:00"
  }
]

No query/body required; authenticated read. id is selected marketId. countryCode is the configured country code; currencyCode is currency (not currency); phoneCode is the dial prefix (not phoneCountryCode). timezone is an IANA zone used for schedules. createdAt/updatedAt are local datetime strings. Choose a returned active market and retain its ID in app state; there is no customer PUT market-selection endpoint. Location permission/GPS is handled by the mobile platform; the backend takes coordinates in search, not a device permission flag.

17. Browse services for market

GET /api/v1/customers/me/services?marketId=1

Request body:

None.

Success: 200 OK.

[
  {
    "service": {
      "id": 3,
      "name": "Nursing",
      "description": "Home nursing services",
      "iconUrl": "https://cdn.example.com/nursing.png",
      "status": "ACTIVE",
      "icon": {
        "key": "service-icons/nursing.png",
        "url": "https://cdn.example.com/nursing.png",
        "altText": "Nursing service",
        "displayOrder": 0
      },
      "coverImage": null,
      "gallery": [],
      "responsibilities": [
        {
          "responsibleParty": "CUSTOMER",
          "title": "Provide access",
          "description": "Ensure access to the agreed service location.",
          "required": true,
          "displayOrder": 1
        }
      ]
    },
    "access": {
      "status": "ELIGIBLE",
      "action": "CONTINUE",
      "eligibility": {
        "eligible": true,
        "reasons": []
      }
    }
  }
]

Required query: marketId (integer). Requires saved customer profile and active market. Returns active services with active market offerings only; empty results is []. Restricted services are returned with access badges, not hidden. Service fields shown above are the complete ProviderTypeResponse shape: id, name, description, iconUrl, status, icon, coverImage, gallery, responsibilities. Optional media/description can be null; collections can be empty. This endpoint returns a raw unpaginated array.

18. Choose option for service

GET /api/v1/customers/me/services/3/options?marketId=1

Request body:

None.

Success: 200 OK.

[
  {
    "option": {
      "optionId": 12,
      "serviceTypeId": 3,
      "code": "HOME_CARE",
      "name": "Home Care",
      "description": "Care at the customer location",
      "displayOrder": 1,
      "status": "ACTIVE",
      "schedulingModel": "TIME_BASED",
      "routeAverageSpeedKmh": null,
      "locationEnabled": true,
      "deliveryModes": [
        "PROVIDER_TO_CUSTOMER"
      ],
      "fulfillmentModel": "ONE_TO_ONE",
      "defaultCapacity": 1,
      "requiredProviderCount": 1,
      "bookingMode": "ONE_AT_A_TIME",
      "providerSelectionMode": "DIRECT_REQUEST",
      "pricingOwner": "ADMIN",
      "allowedPaymentMethods": [
        "CASH",
        "CARD"
      ],
      "deliveryModeConfigurations": [
        {
          "code": "PROVIDER_TO_CUSTOMER",
          "providerLocationType": "COVERAGE_AREA",
          "providerLocationRequired": true,
          "radiusRequired": true,
          "customerLocationInput": "MEETING_POINT"
        }
      ],
      "icon": {
        "key": "service-icons/nursing.png",
        "url": "https://cdn.example.com/nursing.png",
        "altText": "Nursing service",
        "displayOrder": 0
      },
      "coverImage": null,
      "gallery": [],
      "responsibilities": [
        {
          "responsibleParty": "CUSTOMER",
          "title": "Provide access",
          "description": "Ensure access to the agreed service location.",
          "required": true,
          "displayOrder": 1
        }
      ],
      "dynamicFields": [
        {
          "fieldId": 20,
          "serviceTypeId": 3,
          "optionId": 12,
          "optionIds": [
            12
          ],
          "scope": "BOOKING_FIELD",
          "reuseScope": "ASSIGNMENT",
          "code": "CARE_NOTES",
          "label": "Care instructions",
          "description": "Tell the provider what care is needed",
          "fieldType": "TEXTAREA",
          "required": false,
          "requiresApproval": false,
          "minimumFiles": null,
          "maximumFiles": null,
          "maximumFileSizeMb": null,
          "allowedFileTypes": [],
          "options": null,
          "condition": null,
          "displayOrder": 1,
          "version": 1,
          "status": "ACTIVE"
        }
      ]
    },
    "access": {
      "status": "ELIGIBLE",
      "action": "CONTINUE",
      "eligibility": {
        "eligible": true,
        "reasons": []
      }
    }
  }
]

Path serviceTypeId and query marketId required. Returns active options for this service/market, raw array. Each option has its exact eligibility, not just the service badge. Do not use providerTypeId as a different service ID: service.id is the serviceTypeId for this flow. Options are admin configured; render returned modes/limits rather than hardcoding Nursing behavior. Every option response property is shown in the example.

19. Full booking context and form

GET /api/v1/customers/me/booking-context?marketId=1&serviceTypeId=3&optionId=12

Request body:

None.

Success: 200 OK.

{
  "marketId": 1,
  "timezone": "Asia/Colombo",
  "selection": {
    "option": {
      "optionId": 12,
      "serviceTypeId": 3,
      "code": "HOME_CARE",
      "name": "Home Care",
      "description": "Care at the customer location",
      "displayOrder": 1,
      "status": "ACTIVE",
      "schedulingModel": "TIME_BASED",
      "routeAverageSpeedKmh": null,
      "locationEnabled": true,
      "deliveryModes": [
        "PROVIDER_TO_CUSTOMER"
      ],
      "fulfillmentModel": "ONE_TO_ONE",
      "defaultCapacity": 1,
      "requiredProviderCount": 1,
      "bookingMode": "ONE_AT_A_TIME",
      "providerSelectionMode": "DIRECT_REQUEST",
      "pricingOwner": "ADMIN",
      "allowedPaymentMethods": [
        "CASH",
        "CARD"
      ],
      "deliveryModeConfigurations": [
        {
          "code": "PROVIDER_TO_CUSTOMER",
          "providerLocationType": "COVERAGE_AREA",
          "providerLocationRequired": true,
          "radiusRequired": true,
          "customerLocationInput": "MEETING_POINT"
        }
      ],
      "icon": {
        "key": "service-icons/nursing.png",
        "url": "https://cdn.example.com/nursing.png",
        "altText": "Nursing service",
        "displayOrder": 0
      },
      "coverImage": null,
      "gallery": [],
      "responsibilities": [
        {
          "responsibleParty": "CUSTOMER",
          "title": "Provide access",
          "description": "Ensure access to the agreed service location.",
          "required": true,
          "displayOrder": 1
        }
      ],
      "dynamicFields": [
        {
          "fieldId": 20,
          "serviceTypeId": 3,
          "optionId": 12,
          "optionIds": [
            12
          ],
          "scope": "BOOKING_FIELD",
          "reuseScope": "ASSIGNMENT",
          "code": "CARE_NOTES",
          "label": "Care instructions",
          "description": "Tell the provider what care is needed",
          "fieldType": "TEXTAREA",
          "required": false,
          "requiresApproval": false,
          "minimumFiles": null,
          "maximumFiles": null,
          "maximumFileSizeMb": null,
          "allowedFileTypes": [],
          "options": null,
          "condition": null,
          "displayOrder": 1,
          "version": 1,
          "status": "ACTIVE"
        }
      ]
    },
    "access": {
      "status": "ELIGIBLE",
      "action": "CONTINUE",
      "eligibility": {
        "eligible": true,
        "reasons": []
      }
    }
  },
  "bookingSchema": {
    "serviceTypeId": 3,
    "serviceName": "Nursing",
    "serviceSetup": {
      "serviceTypeId": 3,
      "name": "Nursing",
      "description": "Home nursing services",
      "iconUrl": "https://cdn.example.com/nursing.png",
      "status": "ACTIVE",
      "availabilityEnabled": true,
      "serviceAreasEnabled": true,
      "optionsRequired": true,
      "minimumOptionSelections": 1,
      "maximumOptionSelections": 5,
      "documents": [],
      "skills": [
        {
          "skillId": 10,
          "name": "Patient care",
          "required": false,
          "requiresApproval": false
        }
      ],
      "certificates": {
        "level": "OPTIONAL",
        "requiresApproval": true
      },
      "education": {
        "level": "DISABLED",
        "requiresApproval": false
      },
      "icon": {
        "key": "service-icons/nursing.png",
        "url": "https://cdn.example.com/nursing.png",
        "altText": "Nursing service",
        "displayOrder": 0
      },
      "coverImage": null,
      "gallery": [],
      "responsibilities": [
        {
          "responsibleParty": "CUSTOMER",
          "title": "Provide access",
          "description": "Ensure access to the agreed service location.",
          "required": true,
          "displayOrder": 1
        }
      ]
    },
    "commonFields": [],
    "options": [
      {
        "optionId": 12,
        "code": "HOME_CARE",
        "name": "Home Care",
        "fields": [
          {
            "fieldId": 20,
            "serviceTypeId": 3,
            "optionId": 12,
            "optionIds": [
              12
            ],
            "scope": "BOOKING_FIELD",
            "reuseScope": "ASSIGNMENT",
            "code": "CARE_NOTES",
            "label": "Care instructions",
            "description": "Tell the provider what care is needed",
            "fieldType": "TEXTAREA",
            "required": false,
            "requiresApproval": false,
            "minimumFiles": null,
            "maximumFiles": null,
            "maximumFileSizeMb": null,
            "allowedFileTypes": [],
            "options": null,
            "condition": null,
            "displayOrder": 1,
            "version": 1,
            "status": "ACTIVE"
          }
        ]
      }
    ]
  },
  "matchingFilters": [
    "languages",
    "requiredSkillIds",
    "providerFilters"
  ],
  "liveTrackingSupported": false,
  "providerFilters": []
}

All three integer query parameters are required. The endpoint remains readable when selection.access is blocked, so the app can explain the service and offer requirements. It does not bypass search eligibility. selection is the complete OptionCard. bookingSchema.options is filtered to the selected option. commonFields always applies; selected option fields apply in addition; deduplicate shared fieldId values. serviceSetup documents/skills/certificate/education sections describe provider setup and may supply configured skill IDs; do not ask the customer to complete provider qualification sections. matchingFilters is [languages, requiredSkillIds, providerFilters]. Context providerFilters supplies the admin-enabled filter schema, including optional field and choice icons; see the 20 October update above. liveTrackingSupported is currently false.

20. Customer reusable requirements form

GET /api/v1/customers/me/requirements?serviceTypeId=3&optionId=12

Request body:

None.

Success: 200 OK.

[
  {
    "requirement": {
      "requirementId": 1,
      "version": 1,
      "status": "ACTIVE",
      "definition": {
        "code": "NIC",
        "label": "National identity card",
        "description": "Upload front and back images",
        "fieldType": "IMAGE_UPLOAD",
        "required": true,
        "verificationMode": "DOCUMENT_REVIEW",
        "blocksBooking": false,
        "targets": [
          {
            "scope": "GLOBAL",
            "serviceTypeId": null,
            "optionId": null
          }
        ],
        "evidenceCodes": [],
        "choices": [],
        "minimumFiles": 2,
        "maximumFiles": 2,
        "maximumFileSizeMb": 10,
        "allowedFileTypes": [
          "JPG",
          "PNG",
          "WEBP"
        ],
        "displayOrder": 1
      }
    },
    "submission": null
  },
  {
    "requirement": {
      "requirementId": 2,
      "version": 1,
      "status": "ACTIVE",
      "definition": {
        "code": "DATE_OF_BIRTH",
        "label": "Date of birth",
        "description": "Must match your NIC",
        "fieldType": "DATE",
        "required": true,
        "verificationMode": "DOCUMENT_REVIEW",
        "blocksBooking": false,
        "targets": [
          {
            "scope": "SERVICE",
            "serviceTypeId": 3,
            "optionId": null
          }
        ],
        "evidenceCodes": [
          "NIC"
        ],
        "choices": [],
        "minimumFiles": null,
        "maximumFiles": null,
        "maximumFileSizeMb": null,
        "allowedFileTypes": [],
        "displayOrder": 2
      }
    },
    "submission": null
  }
]

serviceTypeId and optionId are optional, but optionId requires serviceTypeId. No context returns global requirements; service context adds service rules; option context adds its rules. Related evidence and DOB definitions can be included even when their own targets are broader/different, because they support applicable rules. A FormItem always has requirement and submission; unanswered submission is null. requirementId is for requirement-submissions; fieldId is for BOOKING_FIELD answers. They are NOT interchangeable. Read full customer requirement definition/answer schemas below.

21. Private customer document upload

POST /api/v1/uploads/documents

Request format: multipart/form-data. One binary file part named file; no JSON request body.

Success: 200 OK.

{
  "key": "customers/25/documents/550e8400-e29b-41d4-a716-446655440000.jpg",
  "url": "s3://private-bucket/customers/25/documents/550e8400-e29b-41d4-a716-446655440000.jpg",
  "contentType": "image/jpeg",
  "size": 245120
}

Actual request is multipart/form-data with one part named file containing file bytes, not the illustrative string "multipart" above. Supported MIME types: application/pdf, image/jpeg, image/png, image/webp. Maximum100MB, and field limits can be stricter. Let the HTTP library generate the multipart boundary; do not send JSON or set a boundaryless multipart header. Use returned key in files[].key; s3:// URL is not a browser view URL. Never infer bucket/prefix/UUID. CUSTOMER upload keys use authenticated userId. The backend checks ownership, object existence, actual S3 metadata, field count/type/size rules on submission. Already uploaded files are not rolled back if a later form save fails.

22. Public profile photo upload

POST /api/v1/uploads/images

Request format: multipart/form-data. One binary file part named file; no JSON request body.

Success: 201 Created.

{
  "key": "providers/25/images/550e8400-e29b-41d4-a716-446655440000.jpg",
  "url": "https://cdn.example.com/providers/25/images/550e8400-e29b-41d4-a716-446655440000.jpg",
  "contentType": "image/jpeg",
  "size": 245120
}

Actual request is multipart/form-data with part file, not a JSON string. Maximum10MB; JPG/PNG/WebP for customers. Current generic image uploader uses a providers/{userId}/images prefix even for CUSTOMER; this existing prefix does not mean the customer is a provider. Use its returned public url as profilePhoto. Never upload NIC/evidence using this public endpoint. SVG is not accepted for customer photos; service-asset SVG support is Super Admin only.

23. View private file

GET /api/v1/uploads/view-url?key=customers%2F25%2Fdocuments%2F550e8400-e29b-41d4-a716-446655440000.jpg

Request body:

None.

Success: 200 OK.

{
  "key": "customers/25/documents/550e8400-e29b-41d4-a716-446655440000.jpg",
  "url": "https://private-bucket.example.com/object?temporary-signature=example",
  "expiresAt": "2030-01-01T00:10:00Z"
}

Required query key is the returned object key, URL-encoded once. Only owning customer/authorized admin can view the private file. Signed url lasts10minutes; use expiresAt to refresh when needed. Do not store signed urls as permanent submission values, expose them in logs, or use their host as a fixed configuration.

24. Save all supplied reusable answers

PUT /api/v1/customers/me/requirement-submissions

Request body:

{
  "submissions": [
    {
      "requirementId": 1,
      "value": {
        "files": [
          {
            "key": "customers/25/documents/nic-front.jpg"
          },
          {
            "key": "customers/25/documents/nic-back.jpg"
          }
        ]
      },
      "expiresOn": null
    },
    {
      "requirementId": 2,
      "value": "2000-05-10",
      "expiresOn": null
    }
  ]
}

Success: 200 OK.

[
  {
    "submissionId": 101,
    "customerId": 7,
    "requirementId": 1,
    "code": "NIC",
    "value": {
      "files": [
        {
          "key": "customers/25/documents/nic-front.jpg"
        },
        {
          "key": "customers/25/documents/nic-back.jpg"
        }
      ]
    },
    "status": "PENDING",
    "storedStatus": "PENDING",
    "expiresOn": null,
    "reviewedBy": null,
    "reviewedAt": null,
    "rejectionReason": null,
    "answerVersion": 1,
    "definitionVersion": 1
  },
  {
    "submissionId": 102,
    "customerId": 7,
    "requirementId": 2,
    "code": "DATE_OF_BIRTH",
    "value": "2000-05-10",
    "status": "PENDING",
    "storedStatus": "PENDING",
    "expiresOn": null,
    "reviewedBy": null,
    "reviewedAt": null,
    "rejectionReason": null,
    "answerVersion": 1,
    "definitionVersion": 1
  }
]

submissions array is required, maximum100 entries; [] is permitted. Each entry requires nonnull requirementId and value; expiresOn is optional/null or YYYY-MM-DD and cannot be in the past when supplied. Duplicate requirement IDs are invalid. All supplied answers save in one transaction; omitted answers are preserved. NONE fields become PROVIDED; reviewed fields become PENDING. Resubmitting increments answerVersion and resets review metadata. Replacing/rejecting supporting evidence returns linked approved details to pending review. A saved answer is not automatically approval or booking eligibility. Customer does not submit customerId, userId, status, reviewer or version flags. Use the server-returned effective status.

25. Check customer access

GET /api/v1/customers/me/eligibility?serviceTypeId=3&optionId=12

Request body:

None.

Success: 200 OK.

{
  "eligible": false,
  "reasons": [
    {
      "code": "DATE_OF_BIRTH_UNVERIFIED",
      "requirementCode": "DATE_OF_BIRTH",
      "message": "Provide a current approved date of birth"
    }
  ]
}

Query context rules match GET requirements. An ineligible result still returns200 for this endpoint; search/booking enforcement returns403 instead. eligible is computed from required blocking fields, review/expiry/current definition state and all applicable global/service/option rules. All age rules apply, so stricter option age limits win. Age uses current date in Asia/Colombo. Keep display reasons separate from availability: an eligible customer can still have zero available providers.

26. Time-based provider search

POST /api/v1/customers/me/provider-search

Request body:

{
  "marketId": 1,
  "serviceTypeId": 3,
  "optionId": 12,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "location": {
    "latitude": 6.9271,
    "longitude": 79.8612
  },
  "radiusKm": 30,
  "languages": [
    "ENGLISH"
  ],
  "requiredSkillIds": [
    10
  ],
  "page": 0,
  "pageSize": 20
}

Success: 200 OK.

{
  "checkedAt": "2030-01-01T00:00:00Z",
  "marketId": 1,
  "timezone": "Asia/Colombo",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T10:00:00+05:30",
  "providerSelectionMode": "DIRECT_REQUEST",
  "requiredProviderCount": 1,
  "status": "AVAILABLE",
  "totalCandidates": 1,
  "page": 0,
  "pageSize": 20,
  "hasNext": false,
  "candidates": [
    {
      "providerId": 15,
      "assignmentId": 14,
      "optionId": 12,
      "providerLocationId": null,
      "displayName": "Jane Doe",
      "profilePhoto": null,
      "averageRating": 4.8,
      "totalRatings": 25,
      "locationLabel": "APPROXIMATE_SERVICE_AREA",
      "mapPoint": {
        "latitude": 6.93,
        "longitude": 79.86
      },
      "distanceKm": 0.5,
      "remainingCapacity": 1,
      "languages": [
        "ENGLISH",
        "SINHALA"
      ]
    }
  ]
}

All top-level required fields: marketId, serviceTypeId, optionId, deliveryMode, startAt. For TIME_BASED, endAt is additionally required. Physical modes require location; ONLINE must omit/null it. TIME_BASED must omit/null pickup and destination. Matching filters are optional and AND-combined: provider must speak every requested language and have every requested approved skill. Required skill IDs must be configured for this service. Optional providerFilters AND-combine with them; IN allows any requested choice and RANGE is inclusive. Only admin-enabled provider fields can be queried. Do not send BOOKING_FIELD answers to this endpoint: it has no answers/matchingAnswers property.

27. Route-based provider search

POST /api/v1/customers/me/provider-search

Request body:

{
  "marketId": 1,
  "serviceTypeId": 4,
  "optionId": 20,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startAt": "2030-01-07T08:00:00+05:30",
  "pickup": {
    "latitude": 6.9271,
    "longitude": 79.8612
  },
  "destination": {
    "latitude": 7,
    "longitude": 79.9
  },
  "radiusKm": 30,
  "languages": [],
  "requiredSkillIds": [],
  "page": 0,
  "pageSize": 20
}

Success: 200 OK.

{
  "checkedAt": "2030-01-01T00:00:00Z",
  "marketId": 1,
  "timezone": "Asia/Colombo",
  "startAt": "2030-01-07T08:00:00+05:30",
  "endAt": "2030-01-07T08:30:00+05:30",
  "providerSelectionMode": "DIRECT_REQUEST",
  "requiredProviderCount": 1,
  "status": "NO_AVAILABLE_PROVIDERS",
  "totalCandidates": 0,
  "page": 0,
  "pageSize": 20,
  "hasNext": false,
  "candidates": []
}

The response above demonstrates the complete Results shape; actual endAt is derived and candidates/status must come from the real search (do not synthesize them). ROUTE_BASED requires pickup and destination and omits/nulls location and endAt. startAt is pickup time. End time is estimated using straight-line distance and configured average speed (default40km/h), rounded up to at least1minute. This is not a road ETA. Route options support PROVIDER_TO_CUSTOMER and ONE_TO_ONE in current admin validation.

28. Complete enum and value catalog

Use only values allowed by the selected option/definition. Arrays containing enums are unordered sets for UI purposes; do not assume the first value is the default.

Authentication, access and requirement states

accountType — CUSTOMER, SERVICE_PROVIDER. Customer app always sends CUSTOMER on register/OTP/Google.
roles — String array. This app requires CUSTOMER. Other known backend roles include SERVICE_PROVIDER, SUPER_ADMIN, PREMIUM_ADMIN, ADMIN, SUPPORT_ADMIN, FINANCE_ADMIN, VERIFICATION_ADMIN; customer screens must not grant access based on a local role edit.
account/profile status — Registration writes PENDING; successful customer authentication/profile writes ACTIVE. Inactive account handling is server controlled. This is a persisted string, not a closed DTO enum; do not treat an unknown status as active.
catalog/definition status — ACTIVE, INACTIVE. Customer catalog returns active resources only.
access.status — ELIGIBLE, CHECK_OPTION, NEEDS_DETAILS, PENDING_REVIEW, REJECTED, RESTRICTED.
access.action — CONTINUE, SELECT_OPTION, COMPLETE_REQUIREMENTS, WAIT_FOR_REVIEW, VIEW_REQUIREMENTS.
Eligibility reason.code — MISSING, PENDING, REJECTED, EXPIRED, DATE_OF_BIRTH_UNVERIFIED, INVALID_DATE_OF_BIRTH, MINIMUM_AGE. Unknown future codes should show the server message and offer refresh.
Submission effective status — MISSING, PROVIDED, PENDING, APPROVED, REJECTED, EXPIRED. A never-submitted FormItem has submission:null, not an invented submissionId.
Submission storedStatus — PROVIDED, PENDING, APPROVED, REJECTED. Can differ from effective status due to expiry, definition changes or evidence changes.
Requirement target.scope — GLOBAL (no service/option IDs), SERVICE (serviceTypeId only), OPTION (serviceTypeId+optionId). A definition can have multiple service/option targets. GLOBAL cannot be mixed with other targets.
Requirement verificationMode — NONE → PROVIDED; ADMIN_REVIEW → PENDING; DOCUMENT_REVIEW → PENDING and needs review of uploaded or linked evidence.
Requirement fieldType / booking fieldType — TEXT, TEXTAREA, NUMBER, BOOLEAN, DATE, TIME, PHONE, EMAIL, SELECT, MULTI_SELECT, IMAGE_UPLOAD, DOCUMENT_UPLOAD, FILE_UPLOAD.
Booking field scope — BOOKING_FIELD for customer per-booking questions. PROVIDER_REQUIREMENT can occur in generic option.dynamicFields; do not render it as a customer requirement. Prefer bookingSchema for customer forms.
Booking field reuseScope — ASSIGNMENT, SERVICE, PROVIDER exist in generic dynamic definitions. BOOKING_FIELD must use ASSIGNMENT; reuse is not customer eligibility reuse.
Requirement level (provider serviceSetup only) — DISABLED, OPTIONAL, REQUIRED. Customer app does not submit provider education/certificates.
File type configuration — PDF, JPG, PNG, WEBP for private customer requirements. IMAGE_UPLOAD cannot accept PDF.
Condition operator for BOOKING_FIELD — EQUALS (default), NOT_EQUALS. Missing parent answer means condition does not apply. Other operators are not implemented.
Languages — SINHALA, ENGLISH, TAMIL. Case-sensitive search values. Null list entries invalid.
Responsibility responsibleParty — PROVIDER, CUSTOMER, PLATFORM. Display the selected service/option responsibilities; no customer checkbox/acknowledgment property is currently accepted by booking DTO.

Service option and discovery enums

schedulingModel — TIME_BASED, ROUTE_BASED. No ASAP enum or live dispatch promise.
deliveryMode / deliveryModes — PROVIDER_TO_CUSTOMER, CUSTOMER_TO_PROVIDER, ONLINE. Send one mode from returned deliveryModes.
fulfillmentModel — ONE_TO_ONE; MANY_CUSTOMERS_ONE_PROVIDER; ONE_CUSTOMER_MANY_PROVIDERS.
bookingMode — ONE_AT_A_TIME; MANY_AT_A_TIME. MANY_AT_A_TIME alone does not imply unlimited simultaneous capacity.
providerSelectionMode — DIRECT_REQUEST or OPEN_REQUEST. Enabled scheduled booking-request policies support direct targeting or sequential open offers; direct includes booking.providerId and open omits it. Legacy booking creation for options without an enabled policy still requires the configured provider selection. Team dispatch is not supported by the new request flow.
pricingOwner — ADMIN; PROVIDER. Current booking prices from admin rates; provider-owned quote workflow is not implemented.
allowedPaymentMethods / paymentMethod — CASH, CARD, BANK_TRANSFER, WALLET, EZ_CASH, KOKO. Render only the selected option's allowed subset. For CARD, also require payment-settings.capabilities.cardCheckout; WALLET uses the wallet reservation route below. Other configured labels do not imply working gateway integrations. Final booking normalizes case/spaces; use uppercase canonical values.
deliveryModeConfigurations.providerLocationType — COVERAGE_AREA, FIXED_POINT, NONE.
deliveryModeConfigurations.customerLocationInput — MEETING_POINT, PROVIDER_LOCATION_SELECTION, NONE. ROUTE_BASED additionally needs pickup/destination, even though generic delivery configuration says MEETING_POINT.
Results.status — AVAILABLE, NO_AVAILABLE_PROVIDERS.
Candidate.locationLabel — PUBLIC_SERVICE_LOCATION, APPROXIMATE_SERVICE_AREA, ONLINE.
matchingFilters — languages, requiredSkillIds, providerFilters. Dynamic filtering uses admin-enabled provider requirements; arbitrary booking answers are not provider filters.
liveTrackingSupported — Boolean; currently false. No live GPS/heartbeat stream is implemented by these endpoints.
Booking status/paymentStatus — Creation writes status:PENDING and paymentStatus:PENDING. Status fields are strings. Overlap rules exclude CANCELLED, COMPLETED, REJECTED, EXPIRED. These overlap values are not a claim that customer lifecycle transition endpoints exist.

29. Field-by-field response and request schemas

Examples above show every property of service, option, context, search, profile and auth responses. The tables below specify nested structures and nullable/default behavior needed to implement a typed client.

Access and Eligibility

Access.status / action — Strings from the catalog above. UI summary only; do not store as approval authority.
Access.eligibility — Eligibility object, always present.
Eligibility.eligible — Boolean; true only when all applicable enforced rules pass.
Eligibility.reasons — Reason[]; [] when eligible.
Reason.code / requirementCode / message — String / string / string. requirementCode identifies the reusable detail such as NIC or DATE_OF_BIRTH; do not parse IDs out of human messages.
CHECK_OPTION — Service-level eligible can be true while access.status is CHECK_OPTION. Always read the selected option.
PENDING_REVIEW — Current badge is used when every reason is exactly PENDING. DOB pending review can instead produce DATE_OF_BIRTH_UNVERIFIED and NEEDS_DETAILS; inspect GET requirements submission statuses before asking the customer to re-upload.

Media and responsibility objects

icon / coverImage / mapMarkerIcon — Nullable ServiceMediaPayload objects. icon is for cards and lists; mapMarkerIcon is a separate map asset. Card images are never automatically substituted for markers.
gallery — ServiceMediaPayload[]; may be [].
ServiceMediaPayload.key — String object key, max1024 in admin contract; opaque to customer UI.
ServiceMediaPayload.url — String image URL, max2048 in admin contract; use this for display.
ServiceMediaPayload.altText — String — null, max300.
ServiceMediaPayload.displayOrder — Integer — null. Display ordering, not media identity.
responsibilities — ServiceResponsibilityPayload[]; may be [].
responsibleParty / title / description — Enum string / string max150 / string — null max1000.
required / displayOrder — Boolean / nonnegative integer — null. Required responsibility is configuration; no separate acceptance write endpoint exists.

ServiceSetupResponse (nested inside bookingSchema)

serviceTypeId, name, description, iconUrl, status — Integer; string; nullable string; nullable string; status string.
availabilityEnabled / serviceAreasEnabled / optionsRequired — Booleans. Provider setup configuration exposed for rendering context.
minimumOptionSelections / maximumOptionSelections — Integer — null; provider service-selection limits, not number of providers needed by a customer booking.
documents — DocumentRequirement[]: {documentTypeId:integer, documentTypeName:string, optionId:integer — null, required:boolean, requiresApproval:boolean}. These are PROVIDER documents.
skills — SkillRequirement[]: {skillId:integer, name:string, required:boolean, requiresApproval:boolean}. Use IDs as optional requiredSkillIds preferences; server requires approved selected provider skills.
certificates / education — SectionRequirement: {level:DISABLED — OPTIONAL — REQUIRED, requiresApproval:boolean}. Provider configuration only.
icon / coverImage / gallery / responsibilities — Media and responsibility structures above. mapMarkerIcon is an additional nullable ServiceMediaPayload for the main-service map marker.

ServiceOptionResponse

optionId / serviceTypeId — Integer IDs for the option and the requested main-service link. An option can belong to multiple main services using the same optionId; serviceTypeId is the requested service, not an exclusive owner.
code / name / description — String / string / nullable string. code is stable configured identifier, not an ID.
displayOrder / status — Display order and status of this service-option link; ACTIVE in customer reads. Inactive links are excluded without disabling the same option under other services.
schedulingModel / routeAverageSpeedKmh — Enum / positive integer — null; null speed defaults40 for route estimation.
locationEnabled / deliveryModes — Boolean / enum string[]. Physical search returns no candidates if locationEnabled is false.
fulfillmentModel / defaultCapacity / requiredProviderCount — Enum / integer (default1) / integer (default1). Team booking requires that many DISTINCT providers.
bookingMode / providerSelectionMode / pricingOwner — Enums as listed above.
allowedPaymentMethods — Payment method string[]. Do not offer absent methods. Enabled booking-request CARD checkout requires its policy and server PayHere configuration; older generic payment-settings capability flags do not describe that separate hosted checkout. See the current booking-request section above. A configured CARD label alone does not guarantee checkout is operational.
deliveryModeConfigurations — Array of {code:string, providerLocationType:string, providerLocationRequired:boolean, radiusRequired:boolean, customerLocationInput:string}.
icon / coverImage / gallery / responsibilities — Complete media/responsibility shapes above. mapMarkerIcon is a separate nullable ServiceMediaPayload; mapMarkerFieldId is a nullable field ID on the shared option for the single-choice marker fallback; linked services use the same setting.
dynamicFields — ServiceCustomFieldResponse[]. May include provider and booking scopes; prefer filtered bookingSchema for customer questions.

ServiceDynamicSchemaResponse and ServiceCustomFieldResponse

bookingSchema.serviceTypeId / serviceName / serviceSetup — Integer / string / complete ServiceSetupResponse.
bookingSchema.commonFields — ServiceCustomFieldResponse[] applying to whole service.
bookingSchema.options — OptionSchema[]: {optionId:integer, code:string, name:string, fields:ServiceCustomFieldResponse[]}. Context filters to selected option.
fieldId / serviceTypeId — Integer; integer. fieldId goes in booking answers.
optionId / optionIds — Legacy integer — null / integer[]. Empty optionIds means common; current arrays support multiple options.
scope / reuseScope — Strings described in enum catalog; customer booking schema has scope BOOKING_FIELD.
code / label / description — String stable code; string display label; string — null help text.
fieldType / required / requiresApproval — Type enum; boolean; boolean. BOOKING_FIELD does not use the reusable customer admin approval workflow.
minimumFiles / maximumFiles / maximumFileSizeMb — Integer — null. Booking count default minimum1 if required else0; maximum enforced only when configured. Private upload hard maximum100MB remains.
allowedFileTypes — String[]; [] means no extra configured restriction beyond supported private formats.
options — JSON or null. SELECT/MULTI_SELECT choices may be strings or objects with value, optional label and optional icon and mapMarkerIcon media. Use icon for choice controls and mapMarkerIcon only for map rendering. Render icons/labels; submit only stable value strings. Missing label falls back to value, missing icon to text-only.
condition — JSON — null. Supported shape: {fieldCode:string, operator:EQUALS — NOT_EQUALS, value:any JSON}. Compare JSON values using their types.
displayOrder / version / status — Integer — null; integer schema revision; ACTIVE/INACTIVE (customer booking-schema read includes active definitions). Keep fieldId/code/version for rendering/cache invalidation; final booking only accepts fieldId/value.
icon — Optional {key,url,altText,displayOrder} field media, independently from each choice icon. valueSource/profileField identify provider profile bindings; BOOKING_FIELD remains MANUAL and does not bind provider data.

Customer requirement definition and submission

FormItem.requirement / submission — Requirement object; Submission — null.
Requirement.requirementId / version / status / definition — Integer / integer / status string / Definition.
Definition.code / label / description — Stable uppercase code [A-Z][A-Z0-9_]{0,99}; string max200; nullable help text max1000.
Definition.fieldType / required / verificationMode / blocksBooking — Enums/booleans. required controls form completion; blocksBooking controls booking enforcement and requires required:true. A service rule may require a globally collected field even if blocksBooking:false.
Definition.targets — Target[]: {scope:GLOBAL — SERVICE — OPTION, serviceTypeId:integer — null, optionId:integer — null}. One answer/approval can serve all listed targets.
Definition.evidenceCodes — String[] referencing configured reviewed upload requirements. Approve evidence first, then the dependent detail.
Definition.choices — String[] used by SELECT/MULTI_SELECT; these are NOT booking field options objects.
Definition.minimumFiles / maximumFiles / maximumFileSizeMb — Integer — null. Null defaults:1,1,100 respectively. Configured min/max files1–20 and size1–100MB.
Definition.allowedFileTypes / displayOrder — String[]; nonnegative integer. IMAGE_UPLOAD cannot include PDF.
Submission.submissionId / customerId / requirementId / code — Integer IDs and code string. customerId is entity ID, not authenticated userId.
Submission.value — Typed JSON matching the definition; no status/approval inside value is trusted.
Submission.status / storedStatus — Effective and stored states described above. Display effective status.
Submission.expiresOn — YYYY-MM-DD — null, submitted metadata subject to review; not a date extracted automatically from NIC.
Submission.reviewedBy / reviewedAt / rejectionReason — Reviewer integer — null; local datetime string — null (current review writes UTC clock without offset); string — null.
Submission.answerVersion / definitionVersion — Integers. A definition update makes old answers effectively MISSING; resubmission restarts review.
Customer PUT entry — {requirementId:integer, value:nonnull JSON, expiresOn:date — null}; no customerId/status/reviewer flags. At most100 entries; omitted answers unchanged.

Provider-search request

marketId / serviceTypeId / optionId — Required nonnull integer IDs; all must form an active market/service/option combination.
deliveryMode — Required nonblank string; must be one of option.deliveryModes.
startAt — Required ISO OffsetDateTime; must be in the future relative to server Instant.now.
endAt — Required for TIME_BASED; must be after startAt. Omit/null for ROUTE_BASED; server derives it.
location — Point — null. Required physical TIME_BASED search centre/customer address; forbidden ONLINE and ROUTE_BASED.
pickup / destination — Point — null. Both required ROUTE_BASED, both forbidden TIME_BASED.
Point.latitude / longitude — Required numeric coordinates; latitude -90..90, longitude -180..180.
radiusKm — Number — null; default50; 0.1..500. Distance to centre for fixed locations; travelling provider must also cover pickup/customer point with its own radius.
languages — String[] — null; null/[] means no language filter; values from enum; every selected language must be spoken.
requiredSkillIds — Integer[] — null; null/[] means no skill preference; each must belong to service; every requested skill must be approved for candidate.
providerFilters — Optional array (max50) of {fieldId,value,minimum,maximum}. Choice value is an array of allowed strings (max100), boolean value is true/false, number uses inclusive bound(s). Fields must be offered by context.providerFilters; duplicate/unavailable/invalid filters return400.
page / pageSize — Integer — null; defaults0/20; page>=0; size1..100. Page numbers are offset-based, not cursors.
Interval rules — Future interval, maximum31 elapsed days. Converted to market timezone. Nonexistent/ambiguous local times and intervals crossing DST transitions rejected due to existing local-time booking storage.
Unsupported request properties — No matchingAnswers, booking answers, providerId, eligibility override, paymentMethod, GPS permission flag or client availability assertion belongs in provider-search.

Results and Candidate

checkedAt / marketId / timezone — Instant timestamp; selected market integer; IANA zone string.
startAt / endAt — Offset timestamps for normalized requested interval; route end is estimated.
providerSelectionMode / requiredProviderCount — Enum string and integer; team needs that many distinct providers.
status — AVAILABLE or NO_AVAILABLE_PROVIDERS. For insufficient team size, candidates is[] even if individual candidates exist.
totalCandidates / page / pageSize / hasNext — Integers and boolean. Counts provider-location results (not necessarily distinct people). Can be positive for insufficient team size; hasNext is computed on candidate results.
candidates — Candidate[]; results ordered by distance then provider ID then location ID.
Candidate.providerId / assignmentId / optionId — Integer provider entity ID / provider-service assignment ID / option ID. Final booking providerId uses Candidate.providerId, NOT assignmentId or userId.
Candidate.providerLocationId — Integer — null; fixed public location ID for CUSTOMER_TO_PROVIDER only.
displayName / profilePhoto — String display name; nullable public photo URL. No NIC/contact data.
averageRating / totalRatings — Numeric — null and integer — null; do not invent ratings for null/unrated providers.
locationLabel / mapPoint / distanceKm — Enum; Point — null; number — null (km). ONLINE returns null coordinates/distance. Travelling pins are rounded approximate coverage centres and distance is calculated from that public point. Fixed pins are public business locations.
remainingCapacity / languages — Positive integer spare units during entire interval; string[]. It is a search snapshot, not a reservation or guarantee.
providerAttributes — Object keyed by fieldId; customer-visible approved manual answers or valid profile-backed PROVIDED gender/age values. Never infer independent verification from self-declared attributes.
Pagination UI — Retain request context, increment page until hasNext:false, deduplicate provider/location keys. On time/location/filter change reset page0 and discard stale results. Re-fetch after app resume or booking failure.

30. Dynamic field value examples and rendering rules

Reusable customer requirements and per-booking fields are distinct. Never substitute requirementId for fieldId. Use booleans/numbers as JSON booleans/numbers, not strings. false and0 are valid answers, not missing values.

{
  "TEXT": "Example",
  "TEXTAREA": "Longer instructions",
  "NUMBER": 4.5,
  "BOOLEAN": false,
  "DATE": "2000-05-10",
  "TIME": "08:30:00",
  "PHONE": "+94771234567",
  "EMAIL": "customer@example.com",
  "SELECT": "HOME",
  "MULTI_SELECT": [
    "A",
    "B"
  ],
  "IMAGE_UPLOAD": {
    "files": [
      {
        "key": "customers/25/documents/photo.jpg"
      }
    ]
  },
  "DOCUMENT_UPLOAD": {
    "files": [
      {
        "key": "customers/25/documents/nic.pdf"
      }
    ]
  },
  "FILE_UPLOAD": {
    "files": [
      {
        "key": "customers/25/documents/support.pdf"
      }
    ]
  }
}

For customer requirement TEXT/TEXTAREA/DATE/TIME/PHONE/EMAIL/SELECT, nonblank text is required when submitting, max4000characters. DATE/TIME must parse as ISO local values. PHONE accepts an optional + and 7–30 characters consisting of digits/spaces/parentheses/hyphens (different from auth E.164). EMAIL must match the basic address pattern. MULTI_SELECT must be nonempty and have unique configured string values. Upload value must be an object containing files[], each item object with key. Counts/types/sizes and unique keys are checked; ownership is customer-private.

For BOOKING_FIELD, the existing backend validates required fields, condition applicability, JSON type, choices and upload rules at final booking. DATE/TIME/PHONE/EMAIL booking answers currently receive text-type validation rather than the stronger reusable customer validation; the client should still render/validate the correct input. Required fields only apply when their condition applies. Parent fieldCode must refer to another available booking definition. Implement only EQUALS/NOT_EQUALS; compare typed JSON. When parent changes, clear hidden children. Do not invent new operators or map arbitrary booking fields to provider skills.

Example booking condition and choices:

{
  "options": [
    {
      "value": "HOME",
      "label": "Home"
    },
    {
      "value": "HOSPITAL",
      "label": "Hospital"
    }
  ],
  "condition": {
    "fieldCode": "CARE_LOCATION",
    "operator": "EQUALS",
    "value": "HOSPITAL"
  }
}

31. Exact availability and map behavior

The backend filters active provider accounts, service assignments and provider/admin option statuses/approval, market, supported delivery, weekly schedule coverage, unavailable dates, active service areas and remaining capacity. Provider UNAVAILABLE excludes candidates. OFFLINE alone does not exclude a future scheduled appointment; this is not an immediate-dispatch online-presence system.

ONE_AT_A_TIME blocks overlapping work across options of the same main service and advertises at most1slot. An existing exclusive option also blocks a new nonexclusive option in that service. For a shared option, an overlapping booking of the same optionId under another main service also reserves that provider. Other unrelated service/option combinations retain their existing behavior. MANY_AT_A_TIME + MANY_CUSTOMERS_ONE_PROVIDER uses option defaultCapacity or fixed location capacity override, subtracting peak simultaneous occupied units. MANY_AT_A_TIME + ONE_TO_ONE still blocks overlapping work for the same option. Team models need the configured distinct count; search gives individuals, not a grouped/reserved team or a guarantee of a shared venue.

Intervals are [start,end): one booking ending10:00 does not conflict with one starting10:00. Weekly slots must cover the whole interval; adjacent slots merge, gaps do not. Unavailable dates override weekly hours. If availability configuration is disabled, those schedule/date checks are skipped. Active areas must match market and delivery mode. PROVIDER_TO_CUSTOMER requires actual coverage and search radius; CUSTOMER_TO_PROVIDER returns fixed public locations in radius; ONLINE returns no physical pins.

Cancelled/completed/rejected/expired jobs do not consume capacity. Pending jobs currently do, until their status changes. Final booking locks providers in stable order and rechecks current capacity; search has no hold. Do not show a busy/full provider as available based on cached list items. Do not explain hidden providers with another customer's private booking data.

Approximate service-area pins are not live positions. Scheduled booking requests now support matching/acceptance, capacity reservation on acceptance, idempotent retries and PayHere-funded wallet settlement after customer confirmation. liveTrackingSupported:false still means no moving GPS/heartbeat/road ETA or immediate Ride Now dispatch. Provider quote collection remains unimplemented.

32. Existing final booking handoff — full request and response

POST /api/v1/customers/me/bookings
Authorization: Bearer <customer-access-token>
Content-Type: application/json

TIME_BASED / PROVIDER_TO_CUSTOMER request:

{
  "serviceTypeId": 3,
  "optionId": 12,
  "providerId": 15,
  "providerIds": null,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "requestedPickupTime": null,
  "pickup": null,
  "destination": null,
  "providerLocationId": null,
  "meetingPoint": {
    "name": "Customer home",
    "addressLine1": "10 Main Street",
    "addressLine2": null,
    "city": "Colombo",
    "district": "Colombo",
    "province": "Western",
    "postalCode": "00100",
    "country": "Sri Lanka",
    "latitude": 6.9271,
    "longitude": 79.8612,
    "instructions": "Use the front entrance"
  },
  "customerNote": "Please call on arrival",
  "answers": [
    {
      "fieldId": 20,
      "value": "Routine care instructions"
    }
  ],
  "paymentMethod": "CASH"
}

Success: 201 Created. BookingResponse core-field example; the 21 October update above documents the additional pricingSelections and pricingSnapshot properties.

{
  "jobId": 1001,
  "serviceTypeId": 3,
  "optionId": 12,
  "providerId": 15,
  "providerIds": [
    15
  ],
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "schedulingModel": "TIME_BASED",
  "fulfillmentModel": "ONE_TO_ONE",
  "capacityUsed": 1,
  "providerLocationId": null,
  "meetingPointName": "Customer home",
  "latitude": 6.9271,
  "longitude": 79.8612,
  "startDatetime": "2030-01-07T08:00:00",
  "expectedEndDatetime": "2030-01-07T10:00:00",
  "destinationLatitude": null,
  "destinationLongitude": null,
  "destinationAddress": null,
  "estimatedDistanceKm": null,
  "estimatedDurationMinutes": null,
  "rateId": 40,
  "currencyCode": "LKR",
  "expectedAmount": 2400,
  "paymentMethod": "CASH",
  "paymentStatus": "PENDING",
  "status": "PENDING",
  "answers": {
    "CARE_NOTES": "Routine care instructions"
  }
}

Required: serviceTypeId, optionId, deliveryMode, valid provider selection, correct time/location shape. For a single provider send providerId; alternatively use providerIds. Team requests must contain exactly requiredProviderCount distinct providers; the backend unions providerId/providerIds and rejects null IDs. For fixed venue teams, member locations must be compatible with the one booking venue; search is not a grouped team selection API.

TIME_BASED requires startDatetime before expectedEndDatetime, with no route fields. These are market-local LocalDateTime strings WITHOUT offset; convert search timestamps using market timezone, not phone timezone. Future-time and maximum31day checks are performed in the market zone. PROVIDER_TO_CUSTOMER needs meetingPoint and no providerLocationId. CUSTOMER_TO_PROVIDER needs the selected candidate.providerLocationId and no meetingPoint. ONLINE needs neither. Do not reuse a providerLocationId from a different provider/option/market.

ROUTE_BASED booking request (actual times, address strings and IDs must come from customer input/configuration):

{
  "serviceTypeId": 4,
  "optionId": 20,
  "providerId": 15,
  "deliveryMode": "PROVIDER_TO_CUSTOMER",
  "requestedPickupTime": "2030-01-07T08:00:00",
  "pickup": {
    "address": "10 Main Street, Colombo",
    "latitude": 6.9271,
    "longitude": 79.8612
  },
  "destination": {
    "address": "Destination address",
    "latitude": 7,
    "longitude": 79.9
  },
  "customerNote": null,
  "answers": [],
  "paymentMethod": "CASH"
}

ROUTE_BASED forbids startDatetime, expectedEndDatetime, meetingPoint and providerLocationId; the backend derives the time interval/distance using the current straight-line estimate. RoutePoint.address is required nonblank max500; coordinates required within latitude/longitude bounds. Selection and capacity are checked again for every selected provider.

MeetingPoint fields: name required max150; addressLine1 required max255; addressLine2 optional max255; city/district/province/country optional max100 each; postalCode optional max30; latitude/longitude required within bounds; instructions optional max1000. customerNote optional max4000.

answers is optional/null or [{fieldId:integer,value:nonnull JSON}]. Submit common + selected-option BOOKING_FIELD answers only. The response answers is an object keyed by field code, not the request array or customer requirement code. Follow the field type/condition/choice/file rules above. Missing required active booking fields, invalid IDs/choices/types or private file ownership fail400.

Legacy quote/create paymentMethod defaults to CASH only when allowed; admin pricing remains authoritative. Enabled booking requests instead accept CARD or WALLET and retain that selection. CARD uses hosted PayHere confirmation; WALLET uses confirm-wallet with no body. Search has no fare; quote creates no reservation. Provider acceptance reserves service capacity; customer confirmation then funds service. PENDING is not confirmation.

BookingResponse field dictionary: jobId/serviceTypeId/optionId/providerId are integer IDs; providerIds is integer[]; deliveryMode/schedulingModel/fulfillmentModel are the enums above; capacityUsed is integer (currently1); providerLocationId nullable integer; meetingPointName nullable string; latitude/longitude nullable numbers; startDatetime/expectedEndDatetime market-local strings; destinationLatitude/destinationLongitude/destinationAddress nullable number/number/string; estimatedDistanceKm nullable number; estimatedDurationMinutes nullable integer; rateId integer; currencyCode string; expectedAmount decimal number; paymentMethod string; paymentStatus/status string; answers object with code→typed JSON. pricingSelections is an array of {fieldId,choiceValue}; pricingSnapshot records billingType, durationMinutes, rate, baseFare, pricePerKm, minimumFare and matched conditions. Older bookings may have null selection/snapshot fields. No price/tax/route values may be asserted by the client to override server calculation.

GET /api/v1/customers/me/bookings has no body/query and returns 200 BookingResponse[] newest first for the authenticated customer, currently unpaginated. A customer single-booking GET is still absent. Enabled booking-request offers, pre-checkout cancellation, acceptance capacity holds, verified PayHere callbacks and customer completion confirmation are now implemented through the distinct endpoints at the top of this tab.

33. Error contracts and frontend handling

Business/DTO validation errors use application/problem+json. Security-filter401/403, malformed JSON/parameter binding, servlet upload failures and unexpected exceptions may use Spring/container error bodies instead. Inspect HTTP status/content type before decoding; do not assume every error contains errors or eligibility.

Validation400 example:

{
  "type": "about:blank",
  "title": "Validation failed",
  "status": 400,
  "detail": "The request contains invalid fields",
  "instance": "/api/v1/customers/me/provider-search",
  "errors": {
    "location.latitude": "must be greater than or equal to -90"
  }
}

Invalid business value400 example:

{
  "type": "about:blank",
  "title": "Invalid request value",
  "status": 400,
  "detail": "Choose a future interval of at most 31 days",
  "instance": "/api/v1/customers/me/provider-search"
}

Customer eligibility403 example (search/booking only):

{
  "type": "about:blank",
  "title": "Customer eligibility requirements not satisfied",
  "status": 403,
  "detail": "Customer requirements must be completed before booking",
  "instance": "/api/v1/customers/me/provider-search",
  "eligibility": {
    "eligible": false,
    "reasons": [
      {
        "code": "MISSING",
        "requirementCode": "NIC",
        "message": "National identity card: MISSING"
      }
    ]
  }
}

Missing profile404 example:

{
  "type": "about:blank",
  "title": "Resource not found",
  "status": 404,
  "detail": "Customer profile has not been completed",
  "instance": "/api/v1/customers/me/profile"
}

OTP cooldown429 example:

{
  "type": "about:blank",
  "title": "Too many requests",
  "status": 429,
  "detail": "Please wait before requesting another OTP",
  "retryAfterSeconds": 43
}

On429, read Retry-After header and/or retryAfterSeconds; disable resend until allowed. On401, refresh once using serialized token rotation, then sign out if refresh fails. On403 with eligibility, show requirements/reasons and preserve selected service/option. On403 without eligibility, check role/access; do not keep retrying. On404 profile, open profile; on404 service/option/market, refresh catalog and clear invalid selection. On400 show errors keyed to field paths or business detail; if availability changed, search again. On409 reread changed state before retrying. On5xx show a retryable server failure without exposing tokens/private evidence. A network timeout after a booking POST has uncertain outcome; check own booking history before manual retry because no booking idempotency key is implemented.

Application status vocabulary and HTTP errors are different: NO_AVAILABLE_PROVIDERS is200 with empty candidates; ineligible GET eligibility is200 with eligible:false; attempted provider-search when ineligible is403. Final booking currently reports changed capacity as400 Invalid request value, not a dedicated409 availability enum. Do not implement a nonexistent conflict-code parser.

File failures can be400 business errors or413 for multipart size. Current global multipart exception detail says Image must not exceed10MB even for a document request; this generic message is an implementation inconsistency. Enforce documented per-endpoint/field limits in the app and handle413 by HTTP status instead of treating that text as document configuration.

34. Frontend state, caching and acceptance checklist

Keep auth tokens secure; never log them. user.marketId is null for customers. Keep selected market, service, option, delivery mode, time/location and search page in app state.
After login, load profile. After selecting a market, load market services. After selecting service, load options. Read selected option/context before building the form. Restricted services remain visible.
Separate reusable requirements from booking-specific questions. Display per-item submission.status and rejectionReason; approved evidence can be reused. Replacing evidence restarts linked verification. No customer button can set APPROVED.
Store a return destination during requirements/review. There is no eligibility push stream; recheck on returning to the app, after a submission, or on explicit refresh. Wait for real admin approval; do not locally advance eligibility after upload.
Use commonFields + selected option.fields from bookingSchema; render returned definitions. Clear conditional children when their parent changes. Do not ask customers to fill provider setup requirements from serviceSetup.
Request actual device location permission in the app; offer manual location input if denied. For ONLINE, no coordinate is necessary. Geocoding/map rendering is frontend infrastructure, not a backend route in this contract.
Before searching, collect valid future time context, physical location or route points, and supported language/skill preferences. Reset search pages when any context changes; discard stale in-flight responses using a request key.
Only display returned available candidates for the exact context. Fixed business locations can be map pins with their location IDs; travelling providers use approximate centres. No live position/ETA claim. Show no-results with change-time/location actions.
Retain provider entity IDs, not assignment/user IDs, for final booking. For teams, need distinct compatible people; multiple location pins for one provider do not form a team.
Render only allowed payment methods. Search contains no price quote and makes no reservation. Final booking repeats eligibility, schedule, coverage, provider approval and capacity checks.
Treat response strings as extensible where DTOs use persisted strings. Handle unknown enums conservatively with a refresh/fallback instead of silently permitting booking.
Test empty catalogs/options, missing profile, pending/rejected/expired evidence, age restriction, null photo/rating, invalid route/time combinations, out-of-radius/no capacity, multi-location duplicates, pagination reset, stale availability, token refresh failure, upload413 and uncertain booking timeout.

35. Implementation boundaries and source of truth

Current APIs support catalog/access/requirements, scheduled option-specific search/filtering/quotes, legacy booking/wallet reservation, and opt-in scheduled DIRECT_REQUEST/OPEN_REQUEST offers with idempotent creation, acceptance capacity holds, PayHere hosted card checkout, start code, customer completion confirmation and automatic provider wallet credit. Live GPS/road ETA, immediate Ride Now matching, provider quotes, team dispatch, automatic paid-cancellation refunds and bank payouts remain future work. Production deployment/live merchant/mobile tests are separate; bounded search is not a large-scale spatial/road-routing engine.

Source of truth for this reference: AuthController and auth DTOs; CustomerProfileController/Service and profile DTOs; MarketController/MarketResponse; CustomerDiscoveryController/Service and CustomerDiscoveryApi; CustomerRequirementsController/Service and CustomerRequirementsApi; FileUploadController and S3 private/image services; ServiceOptionResponse, ServiceDynamicSchemaResponse, ServiceCustomFieldResponse, ServiceSetupResponse; CustomerBookingController/Service, CreateBookingRequest and BookingResponse; GlobalExceptionHandler and security configuration. This document changes documentation only, not runtime APIs. Dates and deployment configuration must be verified separately before release.

Wallet and payment API — current implementation (17 October 2026)
This older generic wallet/payment-method/top-up/withdrawal section describes MOCK-only operations. Those generic routes do not process real card/bank transactions. A separate enabled scheduled booking-request flow now provides PayHere hosted checkout, verified callbacks and automatic provider wallet credit after customer completion confirmation; use its endpoints documented at the top of this tab. Deployment is separate.
Authentication, ownership and UI rules
All /api/v1/me routes below require Authorization: Bearer <accessToken> with CUSTOMER or SERVICE_PROVIDER role. The server derives the owner from the token; do not send userId, provider selection, wallet balance or success flags. JSON bodies use Content-Type: application/json. Successful calls below return HTTP 200 with the shown raw response shape. IDs are integer identifiers, amounts are JSON decimal numbers, and nullable fields are shown explicitly. Use decimal-safe handling for money in the app.
The app has no gateway selector. Generic payment-settings capabilities still govern mock top-up/payment-method/withdrawal features. They do not describe the separate enabled request checkout. For booking requests, the option must allow the selected CARD or WALLET method; CARD needs configured hosted PayHere checkout and WALLET needs sufficient eligible funds. Never treat allowed labels, synthetic funds or a settings save as proof of a completed payment.
Read payment capabilities
GET /api/v1/me/payment-settings
No body or query parameters.
Response:
{
  "capabilities": {
    "walletLedger": true,
    "bookingReservations": true,
    "cardCheckout": true,
    "topups": true,
    "withdrawals": true,
    "cardLinking": true,
    "bankLinking": true
  }
}
The response above describes generic MOCK capabilities. In DISABLED and the generic PAYHERE SPI, walletLedger/bookingReservations remain true and five gateway capabilities false. Those flags do not gate or describe the separately configured booking-request PayHere hosted checkout; use its policy and endpoints. Synthetic MOCK and PAYHERE_SANDBOX funds must never be presented as real money.
Add and list payment methods
POST /api/v1/me/payment-methods/setup?type=CARD
No body.
Response:
{
  "methodId": 5,
  "type": "CARD",
  "displayLabel": "TEST CARD •••• 4242",
  "status": "VERIFIED_MOCK"
}
POST /api/v1/me/payment-methods/setup?type=BANK_ACCOUNT
No body.
Response:
{
  "methodId": 6,
  "type": "BANK_ACCOUNT",
  "displayLabel": "TEST BANK •••• 0001",
  "status": "VERIFIED_MOCK"
}
GET /api/v1/me/payment-methods
No body or query parameters.
Response:
[
  {
    "methodId": 5,
    "type": "CARD",
    "displayLabel": "TEST CARD •••• 4242",
    "status": "VERIFIED_MOCK"
  },
  {
    "methodId": 6,
    "type": "BANK_ACCOUNT",
    "displayLabel": "TEST BANK •••• 0001",
    "status": "VERIFIED_MOCK"
  }
]
type is required and accepts exactly CARD or BANK_ACCOUNT. Setup currently creates/reuses one synthetic method per authenticated owner/type/gateway. List returns Method[] or []. Method fields: methodId integer; type enum above; displayLabel string to display; status string, currently VERIFIED_MOCK. Use the actual returned methodId; sample IDs are illustrative. Methods are scoped to the owner and selected gateway. Setup has no card-number, expiry, CVV or bank-account body: never collect/send real credentials to these mock routes. Real hosted/tokenized setup, card-brand selection, default method, edit and delete APIs are not implemented.
Open, read and list wallets
PUT /api/v1/me/wallets/LKR
No body. Opens or returns the existing wallet.
Response:
{
  "walletId": 10,
  "currencyCode": "LKR",
  "available": 0,
  "reserved": 0,
  "pending": 0,
  "status": "ACTIVE",
  "fundingMode": "UNFUNDED"
}
GET /api/v1/me/wallets/LKR
No body. Response: the same complete Balance shape.
GET /api/v1/me/wallets
No body or query parameters. Response:
[
  {
    "walletId": 10,
    "currencyCode": "LKR",
    "available": 0,
    "reserved": 0,
    "pending": 0,
    "status": "ACTIVE",
    "fundingMode": "UNFUNDED"
  }
]
Balance fields: walletId, currencyCode, available, reserved, pending, status, fundingMode. Sources include UNFUNDED, MOCK, PAYHERE, PAYHERE_SANDBOX or historical null. New CARD/WALLET request completion credits provider available net earnings; legacy finance-approved wallet settlement credits pending. Reserved/pending are not spendable and sandbox/mock money is not live. GET before a wallet exists is 404; no currency conversion exists.
First release: only LKR is supported for customer/provider wallets and payment initiation. Other currency paths or payment amounts in unsupported currencies return HTTP 400, even if another currency is configured in an active market. LKR amounts must be positive, no more than 99999999999999.99 and exact to at most two decimal places; overprecision is rejected. Wallet lists return only LKR. Legacy foreign-currency rows are preserved without conversion. The user-plus-currency schema remains for future expansion. Opening an LKR wallet still requires LKR in an active market.
Card top-up — complete mock flow
App flow: open wallet → read capabilities → add/select a test Card → enter amount → create top-up → complete the test result → refresh intent and wallet. A saved card is optional for the current mock top-up API; if supplied it must be the owner's VERIFIED_MOCK CARD. For a card-based UI, pass its returned methodId.
POST /api/v1/me/wallets/LKR/topups
Idempotency-Key: topup-test-001
Request:
{
  "amount": 1000,
  "methodId": 5
}
Response:
{
  "intentId": 21,
  "purpose": "TOPUP",
  "currencyCode": "LKR",
  "amount": 1000,
  "jobId": null,
  "methodId": 5,
  "status": "PENDING"
}
Request fields: amount required decimal; methodId optional nullable integer (omit or null to test without a saved card). No wallet credit occurs while the intent is PENDING. Idempotency-Key is required, nonblank, at most 100 characters. Persist one key for the same logical request across timeout/retry. The same owner/gateway/key with matching purpose, currency, normalized amount and method returns the original intent. Changed input with a reused key returns 409. Top-up and withdrawal share the client-key namespace; use distinct keys.
POST /api/v1/me/mock-payments/21/events
Request:
{
  "outcome": "SUCCESS"
}
Response:
{
  "intentId": 21,
  "purpose": "TOPUP",
  "currencyCode": "LKR",
  "amount": 1000,
  "jobId": null,
  "methodId": 5,
  "status": "SUCCEEDED"
}
GET /api/v1/me/wallets/LKR
Response after that success, assuming a previously empty wallet:
{
  "walletId": 10,
  "currencyCode": "LKR",
  "available": 1000,
  "reserved": 0,
  "pending": 0,
  "status": "ACTIVE",
  "fundingMode": "MOCK"
}
The mock event call uses the same authenticated owner. It is an explicit testing step, not a real card callback or a production payment-success signal. Replaying SUCCESS does not credit twice. A simulated FAILURE credits nothing. Only after SUCCEEDED should the test UI show top-up success. Read current wallet balance after result handling; do not calculate authoritative balances in the app.
Withdraw to a test bank account
POST /api/v1/me/wallets/LKR/withdrawals
Idempotency-Key: withdrawal-test-001
Request:
{
  "amount": 100,
  "methodId": 6
}
Response:
{
  "intentId": 22,
  "purpose": "WITHDRAWAL",
  "currencyCode": "LKR",
  "amount": 100,
  "jobId": null,
  "methodId": 6,
  "status": "PENDING"
}
amount follows the same money rules. methodId must reference the owner's VERIFIED_MOCK BANK_ACCOUNT; missing methodId is rejected. Only available funds can be withdrawn; pending earnings cannot. Creation reserves funds immediately: from an available 1000 balance, available becomes 900 and reserved 100. POST /api/v1/me/mock-payments/22/events with {"outcome":"SUCCESS"} returns the complete Intent with SUCCEEDED, consumes reserved 100 and leaves available 900. FAILURE returns FAILED and releases reserved 100 back to available 1000. PENDING leaves the hold unchanged. No actual bank receives money. Successful withdrawal refund is not supported by this event API.
Read intents, outcomes and refunds
GET /api/v1/me/payment-intents/21
No body. Response is the complete Intent for that owner's currently selected gateway.
POST /api/v1/me/mock-payments/21/events
Request:
{
  "outcome": "REFUND"
}
Response after an eligible successful top-up:
{
  "intentId": 21,
  "purpose": "TOPUP",
  "currencyCode": "LKR",
  "amount": 1000,
  "jobId": null,
  "methodId": 5,
  "status": "REFUNDED"
}
Intent fields: intentId integer; purpose TOPUP, WITHDRAWAL or CARD; currencyCode string; amount decimal; jobId nullable integer (non-null for CARD); methodId nullable integer; status PENDING, SUCCEEDED, FAILED or REFUNDED. Event body has required outcome enum SUCCESS, FAILURE, PENDING or REFUND. PENDING → SUCCESS or FAILURE is allowed; repeating the existing outcome is a no-op. SUCCEEDED → REFUND is allowed for TOPUP and CARD only. Other terminal changes return 409. A top-up refund removes the amount from available exactly once; insufficient available funds returns 409 without a partial refund. Event route is unavailable outside MOCK and is not a processor webhook. No list-all-intents route is implemented; retain intentId for reads/retries.
Wallet transaction history and reconciliation
GET /api/v1/me/wallets/LKR/transactions?page=0&size=20
No body. page defaults to 0 and must be >=0. size defaults to 20 and must be 1–100.
Returns Spring Page<Entry>, newest entry ID first. Read content plus number/size/totalElements/totalPages/first/last/numberOfElements/empty; other Spring paging metadata may also be serialized. Empty history has content:[]; do not assume that no rows means a missing wallet. Example entry from content:
{
  "entryId": 31,
  "operationId": 41,
  "currencyCode": "LKR",
  "bucket": "AVAILABLE",
  "delta": 1000,
  "balanceBefore": 0,
  "balanceAfter": 1000,
  "createdAt": "2026-10-17T12:00:00"
}
Entry fields: entryId, operationId, currencyCode, bucket, delta, balanceBefore, balanceAfter, createdAt. Added operation metadata: type, jobId, grossAmount, platformFeePercentage, platformFee, providerEarnings, fundingMode and paymentReference. Historical metadata may be null. Entries are owned-wallet scoped; group by operationId to avoid counting multiple postings as multiple charges.
GET /api/v1/me/wallets/LKR/reconciliation
No body or query parameters.
Example response:
{
  "walletId": 10,
  "balanced": true,
  "available": 900,
  "reserved": 0,
  "pending": 0
}
Reconciliation compares stored balances against ledger totals under locking. walletId is integer; balanced boolean; available/reserved/pending are ledger totals. If balanced is false, block further actions in the UI and report the issue; do not try to repair balances through an app request.
Errors, retries and safeguards
400: malformed/invalid body, amount, currency, type, outcome, pagination or idempotency key. 401/403: missing authentication or wrong role. 404: missing wallet, booking, intent or method, including another owner's resources and wrong gateway/type method. 409: insufficient funds, inactive owner/wallet, reconciliation problem, mixed mock funds, reused key with changed input, illegal payment state or changed booking price/currency. 503: disabled or unconfigured gateway. Never mark a payment successful after a timeout; retry creation with the same key or read the retained intent.
Example HTTP 409 ProblemDetail response (instance is request-specific):
{
  "type": "about:blank",
  "title": "Resource conflict",
  "status": 409,
  "detail": "Insufficient available balance",
  "instance": "/api/v1/me/wallets/LKR/withdrawals"
}
PaymentUnavailable uses HTTP 503 ProblemDetail with type/title/status/detail and request-specific instance. Validation errors can include an errors object keyed by invalid body field. Display detail appropriately and preserve the user's amount/method selection for a safe retry. Server transactions, owner locks, ledger reconciliation, natural effect keys and request fingerprints guard against double application. Mock and non-mock money cannot be mixed. MOCK balances cannot move after switching away from MOCK and cannot be converted to real funds. Use a separate test database.
Administrator configuration — reference only
SUPER_ADMIN only:
GET /api/v1/admin/settings/payments
PUT /api/v1/admin/settings/payments
Request:
{
  "provider": "MOCK"
}
Response:
{
  "provider": "MOCK",
  "configured": true,
  "testMode": true
}
The admin provider selector accepts DISABLED, MOCK or PAYHERE and is not an app control. Generic instruments/intents retain their existing MOCK-only configured/testMode behavior and gateway scoping. Scheduled booking-request PayHere hosted checkout is a separate configured integration with merchant URLs/credentials, enabled policy and verified callbacks. Real bank payouts and saved hosted payment-method linking remain unimplemented.
Customer booking checkout: Wallet or Card
Choose only the selected option's allowedPaymentMethods and intersect external methods with payment capabilities. Listing CARD in service configuration alone does not enable real card processing. Create the booking through the existing booking API with paymentMethod WALLET or CARD, then call the matching payment route. A created PENDING booking is not payment success. The server locks the owned booking and uses its currency/expectedAmount; never send a client price override.
POST /api/v1/customers/me/bookings/100/wallet-payment
No body or Idempotency-Key required; reservation is naturally keyed by booking.
Example response:
{
  "operationId": 42,
  "type": "BOOKING_RESERVE",
  "jobId": 100,
  "currencyCode": "LKR",
  "amount": 500,
  "status": "POSTED"
}
CUSTOMER only. Booking must use WALLET and be in PENDING, ACCEPTED or CONFIRMED with paymentStatus PENDING. Reserves expectedAmount from available to reserved and marks booking paymentStatus RESERVED; this is a hold, not final provider payout. A prior reservation is returned without a second debit. Operation fields: operationId integer; type string (here BOOKING_RESERVE); jobId integer; currencyCode string; amount decimal; status string (here POSTED). Not enough available balance returns 409; offer Top up then retry the same booking. Booking ownership and state checks remain server-side.
POST /api/v1/customers/me/bookings/101/card-payment-session
Idempotency-Key: card-booking-101
No body.
Example response:
{
  "intentId": 23,
  "purpose": "CARD",
  "currencyCode": "LKR",
  "amount": 500,
  "jobId": 101,
  "methodId": null,
  "status": "PENDING"
}
CUSTOMER only. The booking must use CARD, be owned by this customer, and initially be payable (job status PENDING/ACCEPTED/CONFIRMED and paymentStatus PENDING). The Idempotency-Key is required/nonblank/max 100 characters; one intent is retained per booking even when different retry keys are submitted. This mock session does not accept methodId/card data or return a hosted checkout URL. It does not debit the wallet. A failed/refunded terminal intent is not automatically replaced; use a new test booking for a fresh mock attempt.
POST /api/v1/me/mock-payments/23/events
Request:
{
  "outcome": "SUCCESS"
}
Response:
{
  "intentId": 23,
  "purpose": "CARD",
  "currencyCode": "LKR",
  "amount": 500,
  "jobId": 101,
  "methodId": null,
  "status": "SUCCEEDED"
}
The older mock card-session simulation keeps its previous behavior. The new CARD and WALLET booking-request flow automatically credits saved provider net earnings on customer completion with job paymentStatus SETTLED. Only legacy WALLET jobs without a request retain separate finance-approved pending settlement. PAID alone is not provider settlement. Automatic paid-cancellation refunds and bank payouts remain unimplemented.

