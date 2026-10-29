# B there — Customer and Provider user stories

Prepared: **20 October 2026**, Asia/Colombo. Scope: the current mobile monorepo,
the supplied Customer API reference, and current Provider code/contracts recorded
in the repository. English story wording is intended for product, development
and QA backlog use. This is a source review, not a new runtime acceptance test.

## Backlog summary

| Area | Stories |
| --- | ---: |
| Customer | 54 |
| Provider | 59 |
| Shared | 10 |
| Future proposal | 5 |
| **Total** | **128** |

| Current status | Stories |
| --- | ---: |
| Implemented | 55 |
| Partial | 14 |
| Ready | 33 |
| Blocked | 21 |
| Proposed | 5 |

The companion [CSV backlog](bthere-user-stories.csv) contains the same story IDs,
priorities, criteria and dependencies for filtering and planning.

## How to use this backlog

Every story includes an ID, role, user benefit, current status, priority,
acceptance criteria and dependencies. Shared acceptance rules below apply to
every relevant story in addition to its specific criteria.

| Status | Meaning |
| --- | --- |
| Implemented | Working code path exists. Does not certify deployed backend, device coverage or production readiness. |
| Partial | Some implementation exists, but the complete user outcome is unfinished, dormant or affected by a known integration issue. |
| Ready | Not implemented in the app; a documented backend contract supports the described frontend work. |
| Blocked | A required contract, configuration, product decision or external integration is missing/unconfirmed. No guessed endpoints are authorized. |
| Proposed | Future product story, not an existing API promise or committed feature. |

**P0:** core authentication, onboarding and a safe first booking. **P1:** complete
operational experience and supported payments. **P2:** optional identity methods,
enhancements and future experiences. These are suggested priorities, not dates or
effort estimates. Dependencies refer to story IDs; `Contract` means backend or
product confirmation, not an implementation-ready route.

## Shared acceptance rules

- Loading, empty, unavailable, validation, offline and server-error states are
  distinct. Retry preserves valid input; unknown errors never imply success.
- Validate documented values and limits. Never invent IDs, approvals, balances,
  service availability, market selection endpoints or missing-profile semantics.
- Recheck authentication/ownership server-side. Tokens stay in secure storage;
  diagnostics exclude credentials, OTPs, personal values and signed file URLs.
- Preserve correct keyboard access, labels, readable text scaling, safe areas
  and reachable actions. Reduced motion must not prevent task completion.
- Block duplicate submissions and ignore stale results after account, selection
  or route changes. Do not automatically replay non-idempotent writes.
- Admin approval, payment outcome, booking status and eligibility come from the
  backend. A successful upload or local UI change does not establish approval.
- Use real returned media/data. A placeholder is not a fabricated service/photo,
  metric, rating, notification count or confirmed payment.
- Follow each app's confirmed contract. Customer and Provider profile rules,
  market storage and logout recovery policies are not interchangeable.

## 1. Customer app

### Customer identity and session

Evidence: `apps/customer_app/lib/features/auth/`, `lib/app/customer_app.dart`,
`docs/customer-email-auth.md`, `docs/customer-phone-auth.md`; Customer API
sections 3–13. Customer role is exactly `CUSTOMER`.

#### C-AUTH-01 — Register with email
- Story: As a Customer, I want to create an account using email and password so that I can access care services.
- Status: Implemented | Priority: P0
- Acceptance: Validate email, 10–72-character password and matching confirmation; send only email, unchanged password and accountType CUSTOMER; registration alone does not create an authenticated session.
- Depends on: None

#### C-AUTH-02 — Verify my email
- Story: As a Customer, I want to verify my email with a code so that my account can be authenticated.
- Status: Implemented | Priority: P0
- Acceptance: Accept exactly six digits including leading zeroes, paste and OTP autofill; authenticate only after successful verification, secure persistence and active CUSTOMER validation; invalid/expired codes remain retryable.
- Depends on: C-AUTH-01

#### C-AUTH-03 — Resend or resume email verification
- Story: As a Customer, I want to request another email code or resume a pending verification so that I can finish registration later.
- Status: Implemented | Priority: P0
- Acceptance: Support existing-email verification without registering again; honor cooldown and longer server Retry-After; changing email clears the draft OTP; generic responses do not reveal account existence.
- Depends on: C-AUTH-02

#### C-AUTH-04 — Sign in with password
- Story: As a Customer, I want to sign in with email or username and password so that I can return to my account.
- Status: Implemented | Priority: P0
- Acceptance: POST identifier with trimmed email/username and unchanged password; reject wrong role/inactive account; persist the validated session and load confirmed profile state before entry routing.
- Depends on: None

#### C-AUTH-05 — Request phone registration or sign-in
- Story: As a Customer, I want to enter my international mobile number so that I can register or sign in without a password.
- Status: Implemented | Priority: P0
- Acceptance: Validate E.164 and send phoneNumber/accountType CUSTOMER to the public OTP request endpoint; no email/password is required; accepted OTP request does not itself authenticate or prove account creation.
- Depends on: None

#### C-AUTH-06 — Verify my phone
- Story: As a Customer, I want to verify an SMS code so that I can securely access my phone-based account.
- Status: Implemented | Priority: P0
- Acceptance: Send phoneNumber, six-digit string OTP and CUSTOMER; permit null email in a valid phone-only account; support invalid-code retry, resend cooldown and changing number without creating a separate email registration.
- Depends on: C-AUTH-05

#### C-AUTH-07 — See verification success
- Story: As a Customer, I want a clear email or phone verification confirmation so that I understand registration/sign-in succeeded.
- Status: Implemented | Priority: P0
- Acceptance: Show the appropriate wording and supplied one-shot animation only after secure authenticated success; support reduced motion; Continue follows profile/market routing; restart/logout does not replay stale success.
- Depends on: C-AUTH-02, C-AUTH-06

#### C-AUTH-08 — Restore and refresh my session
- Story: As a Customer, I want to reopen the app securely without unnecessary sign-in so that I can continue my journey.
- Status: Implemented | Priority: P0
- Acceptance: Read secure session and current user; serialize refresh and persist both rotated tokens; clear invalid credentials and show recoverable network failures accurately; restored sessions do not replay verification success.
- Depends on: C-AUTH-04

#### C-AUTH-09 — Sign out of this or every session
- Story: As a Customer, I want to sign out of one or all sessions so that I can control account access.
- Status: Implemented | Priority: P0
- Acceptance: Use the documented logout and logout-all operations; clear local credentials only through the current confirmed success policy; failed logout remains a visible retryable error; clear per-user market/catalog state on sign-out.
- Depends on: C-AUTH-08

#### C-AUTH-10 — Sign in with Google
- Story: As a Customer, I want to use Google identity so that I can access my account with fewer credentials.
- Status: Ready | Priority: P2
- Acceptance: Obtain a Google ID token and send accountType CUSTOMER; validate returned active role/session; handle cancellation and missing platform/backend client configuration without fake success. Backend deployment/configuration must be verified before activation.
- Depends on: C-AUTH-08, Contract

#### C-AUTH-11 — Link a phone to my email account
- Story: As an email-registered Customer, I want to add and verify a mobile number on the same account so that my contact details remain unified.
- Status: Blocked | Priority: P1
- Acceptance: Confirm authenticated linking/update endpoints, uniqueness and OTP rules; verify account identity is retained; never use standalone phone sign-in as an assumed account-linking operation.
- Depends on: Contract

#### C-AUTH-12 — Reset my password
- Story: As a Customer, I want to reset a forgotten password so that I can recover account access.
- Status: Blocked | Priority: P2
- Acceptance: Confirm recovery request/verification/password-change contracts and expiry rules; use non-enumerating responses and safe retries; keep the current unsupported action disabled rather than inventing a reset route.
- Depends on: Contract

#### C-AUTH-13 — Sign in with Apple
- Story: As a Customer, I want to use Apple identity so that I can access my account with an approved alternative identity method.
- Status: Blocked | Priority: P2
- Acceptance: Confirm Apple token exchange, account matching, platform configuration and role validation; handle cancellation and private relay addresses correctly under the confirmed contract; do not present the disabled Apple button as implemented sign-in.
- Depends on: Contract

### Customer profile and market onboarding

Evidence: `apps/customer_app/lib/features/profile/`, `lib/features/discovery/`,
`docs/customer-profile.md`, `docs/customer-market-home.md`; API sections 14–17,
22. Customer GET profile has documented 404 semantics; Provider history must not
be applied to this Customer flow. The current Customer photo URL returns HTTP
403 in the user's reported live case, so public image persistence is not marked
fully accepted.

#### C-PRO-01 — Create my customer profile
- Story: As a Customer, I want to enter my name and address in one form so that the app can personalize my experience.
- Status: Implemented | Priority: P0
- Acceptance: Require first/last name, address line 1, city and country; allow documented optional address/photo fields; submit exactly the ten profile DTO fields with no DOB, gender, NIC, IDs or completion flags.
- Depends on: C-AUTH-08

#### C-PRO-02 — Restore and edit my profile
- Story: As a Customer, I want my saved details restored when editing so that I can update them without losing other information.
- Status: Implemented | Priority: P0
- Acceptance: Use the documented profile GET; only its confirmed 404 opens creation; preserve optional fields under full-replacement PUT and retain edits after failed save; unknown failures remain errors.
- Depends on: C-PRO-01

#### C-PRO-03 — Select, upload, preview and remove my photo
- Story: As a Customer, I want to preview and change an optional profile photo so that I can recognize my account.
- Status: Implemented | Priority: P1
- Acceptance: Accept JPG/PNG/WebP within 10 MB; upload one binary file part and display the photo only from the returned server URL; show remote loading/error/retry without a selected-file fallback; remove clears the photo and profile submission uses only the returned URL.
- Depends on: C-PRO-01

#### C-PRO-04 — View my uploaded photo after reopening
- Story: As a Customer, I want my saved photo to load from its server URL so that it remains visible beyond the current form.
- Status: Partial | Priority: P0
- Acceptance: The documented public URL must return a decodable image without app Authorization; expose retry and visible failure rather than silent replacement; resolve the observed 403 and verify reopening and URL-only display after server access is corrected.
- Depends on: C-PRO-03, Contract

#### C-MKT-01 — Continue with the sole available market
- Story: As a Customer, I want the only available market selected automatically so that I do not make an unnecessary choice.
- Status: Implemented | Priority: P0
- Acceptance: Fetch active markets, select the single returned active market, display its country/currency/timezone and offer Continue; empty/error results never enable an invented market.
- Depends on: C-PRO-01

#### C-MKT-02 — Choose among multiple markets
- Story: As a Customer, I want to select my desired market so that I see relevant services.
- Status: Implemented | Priority: P0
- Acceptance: Offer returned active markets in a dropdown; suggest only a unique saved-country match with an explanation; disable Continue until valid selection; retain selected market in current app state without an invented server PUT.
- Depends on: C-MKT-01

#### C-MKT-03 — Change market from Home
- Story: As a Customer, I want to change markets later so that I can arrange care in another supported market.
- Status: Implemented | Priority: P0
- Acceptance: Keep the committed market until Continue; clear stale services on change and request the chosen ID; ignore late responses from a previous market; logout clears in-memory state; the account/environment-scoped device preference restores after restart only when the market remains active.
- Depends on: C-MKT-02

#### C-MKT-04 — Suggest a market from actual location
- Story: As a Customer, I want a location-based market suggestion so that I can choose the appropriate area faster.
- Status: Blocked | Priority: P2
- Acceptance: Confirm point-to-market boundaries/resolver and location/geocoding policy; request permission transparently and preserve manual selection when denied; never equate device locale or saved country with actual GPS location.
- Depends on: C-MKT-02, Contract

### Customer service discovery

Evidence: `apps/customer_app/lib/features/discovery/`; API sections 17–19.
Current card taps show details/access reasons, not a booking flow.

#### C-DIS-01 — Browse services in my market
- Story: As a Customer, I want a visual catalog for my market so that I can find relevant care services.
- Status: Implemented | Priority: P0
- Acceptance: Send the selected returned marketId; show real names/descriptions and optional cover/icon media; show distinct loading, empty and retry states; no sample services are inserted into production.
- Depends on: C-MKT-01

#### C-DIS-02 — Search the service catalog
- Story: As a Customer, I want to search services so that I can quickly find the care I need.
- Status: Implemented | Priority: P1
- Acceptance: Filter the currently returned unpaginated list by name/description; distinguish no matches from no market services; clearing search restores the list without fabricating server-side search results.
- Depends on: C-DIS-01

#### C-DIS-03 — Understand service access status
- Story: As a Customer, I want access badges and reasons so that I know whether I can proceed or must provide more information.
- Status: Implemented | Priority: P0
- Acceptance: Distinguish all documented statuses, including restricted/rejected/review/option checks; restricted services stay visible; show returned reasons and handle unknown statuses conservatively rather than labeling them Available.
- Depends on: C-DIS-01

#### C-DIS-04 — Select a service option
- Story: As a Customer, I want to choose an available option within a service so that I can request the correct type of care.
- Status: Ready | Priority: P0
- Acceptance: Read options using service.id as serviceTypeId plus marketId; use option-specific access and descriptions; handle no options/errors and preserve selected service/option context.
- Depends on: C-DIS-03

#### C-DIS-05 — Read booking context and responsibilities
- Story: As a Customer, I want to understand the selected option's rules and responsibilities so that I can prepare a valid request.
- Status: Ready | Priority: P0
- Acceptance: Fetch context with market/service/option IDs; render returned delivery modes, scheduling model and responsibilities; use bookingSchema rather than provider setup fields; invalidate context after selection changes.
- Depends on: C-DIS-04

### Customer reusable requirements and review

Evidence: Customer API sections 20–25 and dynamic-field reference. No Customer
requirements frontend exists yet. Provider documents are a separate contract.

#### C-REQ-01 — Complete configured personal requirements
- Story: As a Customer, I want forms built from applicable requirements so that I can become eligible for my chosen service.
- Status: Ready | Priority: P0
- Acceptance: Load GLOBAL/SERVICE/OPTION requirements for the selection; render configured types, choices and requiredness; do not add DOB/NIC/gender to the Customer profile DTO or ask for Provider-only setup fields.
- Depends on: C-DIS-05

#### C-REQ-02 — Save and restore reusable answers
- Story: As a Customer, I want saved answers reused so that I do not repeatedly provide the same information.
- Status: Ready | Priority: P0
- Acceptance: Restore existing submissions and preserve JSON value types; batch-save requirementId/value/optional expiry only; omitted answers follow documented preservation semantics; retain draft after failure.
- Depends on: C-REQ-01

#### C-REQ-03 — Upload private evidence
- Story: As a Customer, I want to attach identity or supporting documents securely so that required evidence can be reviewed.
- Status: Ready | Priority: P0
- Acceptance: Use the private document uploader, not public profile images; enforce endpoint and field count/type/size limits; submit returned keys in files arrays, never s3 URLs or local paths; handle 413 and partial workflow failure.
- Depends on: C-REQ-01

#### C-REQ-04 — View my private evidence
- Story: As a Customer, I want to preview my uploaded evidence so that I can confirm I attached the correct file.
- Status: Ready | Priority: P1
- Acceptance: Request a view URL for the owned returned key; honor signed URL expiry and request a fresh URL when needed; never expose private URLs/tokens in logs or treat a missing upload as approved evidence.
- Depends on: C-REQ-03

#### C-REQ-05 — Track requirement review and correct rejection
- Story: As a Customer, I want review statuses and rejection reasons so that I know what to correct before booking.
- Status: Ready | Priority: P0
- Acceptance: Distinguish missing/provided/pending/approved/rejected/expired from returned submissions; allow documented answer/evidence replacement; replacing evidence can reset dependent approval; never locally grant approval.
- Depends on: C-REQ-02, C-REQ-03

#### C-REQ-06 — Return to my service after requirements
- Story: As a Customer, I want to continue the same service journey after providing details so that I do not restart my selection.
- Status: Ready | Priority: P0
- Acceptance: Retain market/service/option and a return destination; recheck eligibility after submission, resume or explicit refresh; pending review remains pending and unknown reason codes display server guidance safely.
- Depends on: C-REQ-05

### Customer scheduling, provider search and booking

Evidence: Customer API sections 19, 26–33 and frontend acceptance checklist.
Search is contextual scheduled availability, not a price quote, hold or live ETA.

#### C-BKG-01 — Choose delivery and time
- Story: As a Customer, I want a supported delivery mode and future time window so that I can request care when and where needed.
- Status: Ready | Priority: P0
- Acceptance: Offer only returned modes; validate future time/range in market timezone; distinguish TIME_BASED from ROUTE_BASED; preserve correct offset-aware search timestamps and market-local booking timestamps.
- Depends on: C-DIS-05

#### C-BKG-02 — Provide a physical location
- Story: As a Customer, I want to supply a meeting location so that travelling providers can assess my request.
- Status: Ready | Priority: P0
- Acceptance: Request foreground location permission only when needed and allow manual entry if denied; validate coordinates/address; ONLINE needs no coordinates; map/geocoding provider configuration is a frontend prerequisite.
- Depends on: C-BKG-01

#### C-BKG-03 — Provide route-based search details
- Story: As a Customer, I want to specify route endpoints and time so that route-based services can be searched correctly.
- Status: Ready | Priority: P1
- Acceptance: Use the documented route-based search shape and required points; do not send mutually incompatible time-based fields; recalculate/reset results when route/time changes and do not claim live road ETA.
- Depends on: C-BKG-01, C-BKG-02

#### C-BKG-04 — Filter and search available providers
- Story: As a Customer, I want providers matching my exact option, schedule and preferences so that I can choose suitable care.
- Status: Ready | Priority: P0
- Acceptance: Submit documented provider-search fields and language/approved-skill preferences; use exact selected market/service/option/mode; handle no results with change-time/location actions; ignore stale in-flight results.
- Depends on: C-REQ-06, C-BKG-01, C-BKG-02

#### C-BKG-05 — Browse candidates and pagination
- Story: As a Customer, I want provider summaries and more results so that I can compare suitable candidates.
- Status: Ready | Priority: P0
- Acceptance: Show returned provider identity/photo/rating/skills with null-safe fallbacks; reset pagination when context changes; retain provider entity IDs and location IDs, not assignment/user IDs; no fabricated ratings or prices.
- Depends on: C-BKG-04

#### C-BKG-06 — Interpret service locations correctly
- Story: As a Customer, I want accurate candidate location information so that I understand where care is offered.
- Status: Ready | Priority: P1
- Acceptance: Distinguish fixed business locations from approximate travelling-provider coverage centres; retain candidate providerLocationId where required; never label a coverage pin as a live provider position.
- Depends on: C-BKG-05

#### C-BKG-07 — Select one provider or a compatible team
- Story: As a Customer, I want the required number of compatible providers so that the service is properly staffed.
- Status: Ready | Priority: P0
- Acceptance: Follow returned fulfillment/count rules; require distinct provider entities; multiple locations for one provider do not form a team; preserve selected location/context compatibility.
- Depends on: C-BKG-05

#### C-BKG-08 — Answer booking-specific questions
- Story: As a Customer, I want to answer only applicable booking questions so that my request includes the necessary care details.
- Status: Ready | Priority: P0
- Acceptance: Render common and selected-option bookingSchema fields; preserve typed values/choice IDs; support only documented conditions and clear hidden dependent answers; keep booking answers separate from reusable requirements.
- Depends on: C-DIS-05

#### C-BKG-09 — Review and submit a booking
- Story: As a Customer, I want to review my complete request before submitting so that I can confirm the correct care arrangement.
- Status: Ready | Priority: P0
- Acceptance: Summarize actual selection/time/location/providers/answers and allowed payment method; send the documented booking DTO without price/status overrides; honor server revalidation of eligibility, coverage, schedules and capacity.
- Depends on: C-BKG-07, C-BKG-08

#### C-BKG-10 — Recover safely from uncertain submission
- Story: As a Customer, I want clear guidance after a booking timeout so that I do not accidentally create duplicate requests.
- Status: Ready | Priority: P0
- Acceptance: Do not blindly auto-replay booking POST or invent an idempotency contract; explain uncertain outcome and refresh the documented owned booking list for inspection; surface unresolved ambiguity rather than claiming success or absence.
- Depends on: C-BKG-09, C-BKG-11

#### C-BKG-11 — View my bookings
- Story: As a Customer, I want to view my submitted bookings so that I can follow my care requests.
- Status: Ready | Priority: P0
- Acceptance: Read the owned booking array in backend order; show returned job/payment information and empty/error states; a detail view may use a returned list record but must not call an invented single-booking endpoint.
- Depends on: C-BKG-09

#### C-BKG-12 — Cancel or modify a booking
- Story: As a Customer, I want to request supported booking changes so that I can respond when my plans change.
- Status: Blocked | Priority: P1
- Acceptance: Confirm cancellation/modification endpoints, permitted states, ownership and financial consequences; do not expose a successful cancellation action against an unsupported route.
- Depends on: C-BKG-11, Contract

### Customer wallet and payments

Evidence: Customer reference wallet/payment appendix dated 17 October 2026.
`/me` wallet APIs explicitly support CUSTOMER and SERVICE_PROVIDER. MOCK is not
real money movement; current PAYHERE is an unconfigured integration slot.

#### C-PAY-01 — Discover enabled payment capabilities
- Story: As a Customer, I want only supported payment actions shown so that I do not attempt unavailable transactions.
- Status: Ready | Priority: P0
- Acceptance: Read payment-settings/capabilities on entry/resume and after relevant 503 responses; intersect capabilities with the selected option's allowed methods; never offer a gateway selector or admin settings access.
- Depends on: C-AUTH-08

#### C-PAY-02 — Create and view currency wallets
- Story: As a Customer, I want wallet balances in supported currencies so that I can understand available funds.
- Status: Ready | Priority: P1
- Acceptance: Use documented wallet create/read/list operations; show available/reserved/pending and fundingMode separately; distinguish missing wallet from empty history; use decimal-safe amounts and authoritative server balances.
- Depends on: C-PAY-01

#### C-PAY-03 — Review wallet transaction history
- Story: As a Customer, I want paginated wallet activity so that I can understand credits, debits and holds.
- Status: Ready | Priority: P1
- Acceptance: Read Spring Page content/metadata; show backend transaction values/currency; validate paging bounds and handle empty/error pages without calculating an authoritative balance from displayed entries.
- Depends on: C-PAY-02

#### C-PAY-04 — Set up and list payment methods
- Story: As a Customer, I want to manage supported card/bank instruments so that enabled wallet actions have a valid method.
- Status: Ready | Priority: P1
- Acceptance: Respect cardLinking/bankLinking flags; use documented setup/list operations; label VERIFIED_MOCK/test instruments honestly and do not imply real card verification or invent edit/delete endpoints.
- Depends on: C-PAY-01

#### C-PAY-05 — Top up a wallet
- Story: As a Customer, I want to initiate a permitted top-up so that I can fund a wallet booking.
- Status: Ready | Priority: P1
- Acceptance: Validate amount/currency/method and reuse the same idempotency key for the same attempt; retain intentId and read real backend outcome; refresh balance after confirmed success; test-mode actions remain clearly simulated.
- Depends on: C-PAY-02, C-PAY-04

#### C-PAY-06 — Withdraw supported available funds
- Story: As a Customer, I want an enabled withdrawal flow so that I can request available wallet funds back.
- Status: Ready | Priority: P1
- Acceptance: Require capabilities and an eligible owned bank method; use the documented idempotency key and intent handling; distinguish reserved/pending funds from withdrawable funds; current MOCK never claims a real bank payout.
- Depends on: C-PAY-04, C-PAY-02

#### C-PAY-07 — Reserve wallet funds for a booking
- Story: As a Customer, I want to pay an eligible booking with wallet funds so that its amount is reserved safely.
- Status: Ready | Priority: P0
- Acceptance: Use the owned booking wallet-payment endpoint with no client amount override; display RESERVED as a hold, not final settlement; insufficient funds offers top-up and retry of the same booking without duplicate reservation.
- Depends on: C-BKG-09, C-PAY-02

#### C-PAY-08 — Initiate card payment for a booking
- Story: As a Customer, I want to start a supported card payment so that I can complete an eligible card booking.
- Status: Ready | Priority: P1
- Acceptance: Intersect cardCheckout with option CARD support; create the documented idempotent session and retain intentId; do not invent hosted checkout URLs or send card data to the current mock session; PENDING is not paid.
- Depends on: C-BKG-09, C-PAY-01

#### C-PAY-09 — Recheck payment outcomes and balance integrity
- Story: As a Customer, I want reliable payment status after interruptions so that I do not repeat charges or trust an incorrect balance.
- Status: Ready | Priority: P0
- Acceptance: Read retained owned intents after timeout/resume; handle documented terminal/refund/conflict states without assuming automatic refunds; block further actions when reconciliation is unbalanced and report the issue rather than repairing balances locally.
- Depends on: C-PAY-05, C-PAY-07, C-PAY-08

#### C-PAY-10 — Use production card processing and refunds
- Story: As a Customer, I want real verified payment processing so that actual payments and supported refunds can be completed securely.
- Status: Blocked | Priority: P1
- Acceptance: Require configured gateway, hosted/tokenization flow, verified callbacks and finance/refund contracts; never send simulated SUCCESS events as proof of a real payment; PAID does not mean provider settlement.
- Depends on: C-PAY-08, Contract

## 2. Provider app

### Provider identity and account prerequisites

Evidence: `apps/provider_app/lib/features/auth/`, `core/session/`,
`features/onboarding/`, `docs/provider-service-registration.md`,
`docs/provider-password-sign-in.md`. Current Provider code supersedes historical
reports that said GET profile was unavailable; it now reads/restores that profile.

#### P-AUTH-01 — Register a provider account
- Story: As a Provider, I want to register with email/password so that I can apply to offer services.
- Status: Implemented | Priority: P0
- Acceptance: Validate required registration fields/confirmation and local agreement control; send SERVICE_PROVIDER identity through the confirmed contract; do not authenticate from registration alone or send UI-only agreement/confirmation fields without a contract.
- Depends on: None

#### P-AUTH-02 — Verify email and resend a code
- Story: As a Provider, I want to verify my email and request a replacement code so that I can activate my sign-in journey.
- Status: Implemented | Priority: P0
- Acceptance: Preserve six-digit codes and verified email context; handle invalid/expired code, cooldown and resend failures; validate SERVICE_PROVIDER session before entering onboarding.
- Depends on: P-AUTH-01

#### P-AUTH-03 — Sign in with password
- Story: As a Provider, I want to sign in using email or username so that I can manage my services.
- Status: Implemented | Priority: P0
- Acceptance: POST /auth/login sends identifier and unchanged password, not username as a payload key; require SERVICE_PROVIDER role, expiry checks and secure persistence; keep readable validation/network errors.
- Depends on: None

#### P-AUTH-04 — Restore and refresh my session
- Story: As a Provider, I want a secure restored session so that I can return to incomplete or registered services.
- Status: Implemented | Priority: P0
- Acceptance: Handle expired sessions through documented token rotation with single-flight refresh; protect routes by session and entry gate; late refresh cannot restore a signed-out account.
- Depends on: P-AUTH-03

#### P-AUTH-05 — Sign out safely
- Story: As a Provider, I want to sign out even when the network is unavailable so that local access to my account can be removed.
- Status: Implemented | Priority: P0
- Acceptance: Attempt server logout using the current documented refresh-token contract; current Provider policy permits local clear after server/network failure; redirect only after secure clear succeeds and retain a safe error if local clearing fails.
- Depends on: P-AUTH-04

#### P-AUTH-06 — Activate Google sign-in
- Story: As a Provider, I want to use Google identity so that I can access the provider app conveniently.
- Status: Partial | Priority: P2
- Acceptance: Reconnect the dormant implemented identity/controller path only after client/backend configuration validation; handle cancellation and role/session checks; disabled social buttons do not count as an active feature.
- Depends on: P-AUTH-04, Contract

#### P-AUTH-07 — Register or sign in with phone
- Story: As a Provider, I want a supported phone OTP entry method so that I can access the Provider app without email/password.
- Status: Blocked | Priority: P2
- Acceptance: Confirm Provider-specific accountType, linking and OTP/session behavior before connecting a Provider UI; preserve SERVICE_PROVIDER validation and nullable identity fields; the Customer phone screen does not count as a Provider implementation.
- Depends on: Contract

#### P-AUTH-08 — Reset my provider password
- Story: As a Provider, I want a supported password-reset flow so that I can recover access to my account.
- Status: Blocked | Priority: P2
- Acceptance: Confirm reset initiation, verification, password and rate-limit contracts; preserve generic account-existence responses; keep unsupported actions explanatory until they are connected.
- Depends on: Contract

#### P-AUTH-09 — Sign in with Apple
- Story: As a Provider, I want a supported Apple identity option so that I can use my preferred sign-in method.
- Status: Blocked | Priority: P2
- Acceptance: Confirm Provider role/token exchange, account matching and native configuration; handle cancellation and relay email without guessed account linking; dormant Google code does not implement Apple sign-in.
- Depends on: Contract

#### P-PRO-01 — Complete provider details and market
- Story: As a Provider, I want to provide my personal details and market so that I meet account prerequisites for service registration.
- Status: Implemented | Priority: P0
- Acceptance: Use confirmed name/DOB/gender/market/availability fields; offer MALE and FEMALE with exact uppercase wire values; validate market and dates; optional values are preserved according to Provider PUT semantics.
- Depends on: P-AUTH-04

#### P-PRO-02 — Restore and edit provider details
- Story: As a Provider, I want saved profile details restored when editing so that I do not lose existing information.
- Status: Implemented | Priority: P0
- Acceptance: Read the current confirmed GET profile implementation; preserve optional NIC/passport/photo fields on full-profile edits; use completion state for onboarding routing rather than treating arbitrary profile HTTP errors as missing data.
- Depends on: P-PRO-01

#### P-PRO-03 — Set my work availability status
- Story: As a Provider, I want to change whether I am available for work so that my account reflects my current availability.
- Status: Implemented | Priority: P0
- Acceptance: Update documented AVAILABLE/UNAVAILABLE/OFFLINE values using the current profile flow with other fields preserved; confirm server result before presenting saved state; do not equate OFFLINE with every future appointment being unavailable.
- Depends on: P-PRO-02

### Provider Home and service catalog

Evidence: `features/home/`, `features/services/`, `docs/provider-home.md`,
`docs/provider-explore-services.md`, `docs/provider-application-status.md`.

#### P-HOME-01 — See the right first-use dashboard
- Story: As a Provider, I want Home to reflect whether I have registered services so that the next action is relevant.
- Status: Implemented | Priority: P0
- Acceptance: A confirmed empty assignment list shows first-service invitation; existing pending/rejected/incomplete services still use the registered variant; loading/failure does not masquerade as a new provider.
- Depends on: P-PRO-01

#### P-HOME-02 — Review my registered services
- Story: As a Provider, I want service status and selected sub-services on Home so that I can resume the correct setup or review screen.
- Status: Implemented | Priority: P0
- Acceptance: Use actual assignments/options/completion data and current status precedence; route pending/rejected services to status/correction and incomplete setup to the proper flow; refresh after relevant edits and return/resume.
- Depends on: P-HOME-01

#### P-HOME-03 — Explore the service catalog
- Story: As a Provider, I want to browse services I can offer so that I can select the right registration opportunity.
- Status: Implemented | Priority: P0
- Acceptance: Load real catalog IDs and descriptions; distinguish registered and available services/statuses; categories absent from the catalog fall back to browsing rather than using fabricated IDs; retain loading/empty/retry states.
- Depends on: P-PRO-01

#### P-HOME-04 — Inspect approved sub-service information
- Story: As a Provider, I want to inspect an approved sub-service profile so that I understand the information published for that service.
- Status: Implemented | Priority: P1
- Acceptance: Load the actual selected option and saved related data; guard against inactive/unapproved options and route safely; show current locations, schedule and details without assuming approval from a local draft.
- Depends on: P-REG-03, P-REV-01

#### P-HOME-05 — View activity/community metrics and resources
- Story: As a Provider, I want real business metrics and resource content so that I can understand and improve my activity.
- Status: Partial | Priority: P2
- Acceptance: Retain honest unavailable placeholders until Provider-authorized metrics/content contracts exist; distinguish unknown from zero; never call Super Admin dashboard APIs for Provider data or fabricate counts/resources.
- Depends on: Contract

### Provider service registration and setup

Evidence: `features/services/application/`, `features/services/data/`,
`features/services/presentation/registration_*`,
`docs/provider-service-registration.md`, `docs/provider-google-maps.md`.
Provider operations use assignmentId where required; it is not serviceTypeId.

#### P-REG-01 — Register one or more main services
- Story: As a Provider, I want to choose main services so that I can offer multiple types of work.
- Status: Implemented | Priority: P0
- Acceptance: Resolve actual catalog IDs and existing assignments; register main services sequentially using the documented POST; recover an existing assignment before retry and do not accidentally replace unrelated assignments.
- Depends on: P-HOME-03

#### P-REG-02 — Load service-specific setup requirements
- Story: As a Provider, I want setup driven by the selected service so that I provide only applicable details.
- Status: Implemented | Priority: P0
- Acceptance: Read schema and public options plus existing registration; honor enabled/disabled/optional/required sections and documented constraints; unsupported/malformed metadata must not be silently considered complete.
- Depends on: P-REG-01

#### P-REG-03 — Select sub-services/options
- Story: As a Provider, I want to choose offered sub-services so that customers can request my supported options.
- Status: Implemented | Priority: P0
- Acceptance: Restore actual selected option IDs; apply backend minimum/maximum/membership rules; send exact optionIds using assignment context and preserve draft/error state if saving fails.
- Depends on: P-REG-02

#### P-REG-04 — Provide experience and basic service details
- Story: As a Provider, I want to enter required experience and service information so that my application accurately represents my offering.
- Status: Implemented | Priority: P0
- Acceptance: Use documented numeric assignment experience and applicable option/common fields; validate configured requirements; distinguish assignment-level values from option details and preserve saved values during unrelated edits.
- Depends on: P-REG-03

#### P-REG-05 — Select supported languages
- Story: As a Provider, I want to record languages for a service assignment so that compatible customers can find me.
- Status: Partial | Priority: P0
- Acceptance: Use ENGLISH/SINHALA/TAMIL only; restore saved selection and skip unchanged writes; after uncertain 5xx/transport error continue only if read-back confirms the exact set; verify resolution of the historically observed language PUT 500 before live acceptance.
- Depends on: P-REG-01, Contract

#### P-REG-06 — Select service skills
- Story: As a Provider, I want to select catalog skills so that my service application includes relevant capabilities.
- Status: Implemented | Priority: P0
- Acceptance: Persist unique catalog skillIds in assignment scope; preserve identity when different skills share a label; reflect returned review state and do not represent assignment skills as editable global profile skills.
- Depends on: P-REG-02

#### P-REG-07 — Configure weekly availability
- Story: As a Provider, I want to set service working days and hours so that matching considers my schedule.
- Status: Implemented | Priority: P0
- Acceptance: Use documented availableAnyDay/availableAnyTime/weeklySlots values and valid time ranges; restore saved days/times; saving unrelated information does not reset the schedule; do not write assignment hours as global hours.
- Depends on: P-REG-02

#### P-REG-08 — Manage unavailable dates
- Story: As a Provider, I want to mark exception dates so that I am not matched when I cannot work.
- Status: Implemented | Priority: P1
- Acceptance: List/add/remove dates using returned IDs and documented operations; validate dates/duplicates as contracted; refresh actual saved state after mutation and preserve errors/drafts accurately.
- Depends on: P-REG-07

#### P-REG-09 — Select supported delivery modes and service areas
- Story: As a Provider, I want to define where each option is delivered so that customers are matched to the correct coverage or business location.
- Status: Implemented | Priority: P0
- Acceptance: Use assignment/option/delivery-mode context; require coordinates and positive radius for provider visits, null radius for customer visits, and omit areas for ONLINE; persist the documented direct area array and restore existing values.
- Depends on: P-REG-03

#### P-REG-10 — Choose a map location with permission fallback
- Story: As a Provider, I want map search, a pin and optional current location so that I can enter service coverage accurately.
- Status: Implemented | Priority: P1
- Acceptance: Preserve existing saved pin; request foreground permission and permit address/manual fallback after denial, GPS failure or unavailable map; support radius preview; Google Maps/geocoding platform configuration must be validated for release.
- Depends on: P-REG-09

#### P-REG-11 — Complete dynamic service fields
- Story: As a Provider, I want fields based on the service schema so that I can provide all applicable service information.
- Status: Implemented | Priority: P0
- Acceptance: Render configured common and selected-option types while preserving JSON values; shared optionIds fields appear once; enforce choices/limits/requiredness and supported conditions; unsupported structures fail visibly.
- Depends on: P-REG-02, P-REG-03

#### P-REG-12 — Reuse approved inherited answers
- Story: As a Provider, I want eligible answers reused across configured scopes so that I do not repeat already approved information.
- Status: Implemented | Priority: P1
- Acceptance: Retain backend reuseScope/reused metadata and inherited values; do not overwrite approved inherited answers with empty draft defaults; editing follows the documented submission/review flow rather than local approval.
- Depends on: P-REG-11

#### P-REG-13 — Save and resume service drafts
- Story: As a Provider, I want incomplete registration retained securely so that I can finish later without losing valid work.
- Status: Implemented | Priority: P0
- Acceptance: Encrypt drafts and scope them by account/service; merge server values without allowing empty stale drafts to erase saved state; preserve pending edits after failure and prevent cross-account restoration.
- Depends on: P-REG-01

### Provider documents, qualifications and review

Evidence: `features/services/documents/`, registration document/qualification/review
widgets, `docs/provider-documents.md`, `docs/provider-application-status.md`,
`docs/provider-service-registration.md`. Use the latest recorded 100 MB document
contract, not historical 5 MB design copy; configured limits may be stricter.

#### P-DOC-01 — View applicable document requirements
- Story: As a Provider, I want required documents matched to my selected service/options so that I upload the correct evidence.
- Status: Implemented | Priority: P0
- Acceptance: Include common and selected-option requirements only; match existing documents by documentTypeId; show returned type/name, review and expiry information without invented review fields.
- Depends on: P-REG-03

#### P-DOC-02 — Upload and register a required document
- Story: As a Provider, I want to upload a valid document with its metadata so that my application can be reviewed.
- Status: Implemented | Priority: P0
- Acceptance: Enforce PDF/JPG/PNG/WebP and documented endpoint/field limits; upload binary first then register returned key and required metadata; retain file/draft on failure and prevent duplicate registration during retry.
- Depends on: P-DOC-01

#### P-DOC-03 — Preview existing private documents
- Story: As a Provider, I want to view my uploaded documents so that I can confirm their correctness.
- Status: Implemented | Priority: P1
- Acceptance: Use bounded session previews for recent images and documented signed view URLs for existing private keys; refresh expired viewing URLs; never treat s3 URLs as a public viewer or expose signed URLs in diagnostics.
- Depends on: P-DOC-02

#### P-DOC-04 — Replace or delete a document
- Story: As a Provider, I want to correct an attachment so that outdated or rejected evidence can be replaced.
- Status: Implemented | Priority: P0
- Acceptance: Use the current documented replacement/deletion workflow and returned document IDs; preserve old valid record until the contracted mutation succeeds; display the refreshed backend review result rather than keeping prior approval.
- Depends on: P-DOC-02

#### P-DOC-05 — Track review, expiry and rejection
- Story: As a Provider, I want clear document statuses and rejection reasons so that I know what action is required.
- Status: Implemented | Priority: P0
- Acceptance: Distinguish pending/approved/rejected/expired/missing from actual review/expiry data; show rejectionReason safely; do not invent grace periods or countdowns from createdAt.
- Depends on: P-DOC-01

#### P-QUAL-01 — Add certificates
- Story: As a Provider, I want to attach service certificates so that relevant qualifications can be reviewed.
- Status: Implemented | Priority: P1
- Acceptance: Upload evidence before the documented metadata POST; show existing records/review state; check returned key/records before retry to avoid duplicates; do not invent certificate update/delete operations.
- Depends on: P-REG-02, P-DOC-02

#### P-QUAL-02 — Add education records
- Story: As a Provider, I want to provide required education evidence so that my application meets service standards.
- Status: Implemented | Priority: P1
- Acceptance: Render only enabled requirements and documented fields; upload first and create the record through its confirmed contract; restore existing review state and preserve input after error without unsupported mutations.
- Depends on: P-REG-02, P-DOC-02

#### P-REV-01 — Review and finish service registration
- Story: As a Provider, I want to review all saved service information so that I can finish a complete application.
- Status: Implemented | Priority: P0
- Acceptance: Review/edit actual service sections; reread saved requirements/documents and server completion before advancement; do not replay already saved replacements or invent a submit-application endpoint; pending review is not approval.
- Depends on: P-REG-04, P-REG-05, P-REG-06, P-REG-07, P-REG-09, P-REG-11, P-DOC-02

#### P-REV-02 — Track application status
- Story: As a Provider, I want to see incomplete, pending, approved, rejected or inactive application status so that I know whether I can offer the service.
- Status: Implemented | Priority: P0
- Acceptance: Derive status from actual assignment/completion/option review data; preserve option-level pending/rejected details even when aggregate state differs; refresh after edits, resume and explicit refresh, with safe read-error recovery.
- Depends on: P-REV-01

#### P-REV-03 — Correct and resubmit rejected information
- Story: As a Provider, I want rejection reasons linked to their editors so that I can fix the exact issue.
- Status: Implemented | Priority: P0
- Acceptance: Open the first applicable correction/document editor; preserve unaffected saved details; refresh server recalculated verification after save and label re-upload only when actual returned state/key matches successful replacement history.
- Depends on: P-REV-02, P-DOC-04

### Provider account and global settings

Evidence: `features/account/`, `docs/provider-profile-api-requirements.md`.
Production ProfileSupplementRepository deliberately returns CONTRACT_REQUIRED;
test fixtures demonstrating editors are not evidence of live integration.

#### P-ACC-01 — View my account/profile overview
- Story: As a Provider, I want my confirmed profile and account information together so that I can understand my verification and service setup.
- Status: Implemented | Priority: P0
- Acceptance: Use current session/profile/completion/assignment/document sources; show returned ratings/counts only when available; missing optional values and read failures remain honest unavailable/error states.
- Depends on: P-PRO-02, P-REV-02

#### P-ACC-02 — Manage account-wide skills and languages
- Story: As a Provider, I want global skills/languages so that my account preferences can be managed independently of a service assignment.
- Status: Partial | Priority: P1
- Acceptance: Confirm global read/write/catalog and inheritance contracts; connect existing editor UI only to those confirmed endpoints; assignment-scoped skills/languages must not silently implement a global setting.
- Depends on: Contract

#### P-ACC-03 — Manage account-wide working hours
- Story: As a Provider, I want global working hours so that I can control my default schedule across services.
- Status: Partial | Priority: P1
- Acceptance: Confirm global slots/timezone and interaction with assignment schedules; connect the existing editor only after contract validation; preserve stored values and never label an unsent edit as saved.
- Depends on: Contract

#### P-ACC-04 — Manage payout account details
- Story: As a Provider, I want verified payout details so that supported earnings payouts use the correct destination.
- Status: Partial | Priority: P1
- Acceptance: Confirm global payout/profile and bank catalog/verification contracts or explicitly redesign around documented payment-method APIs; preserve masked reads and never submit an unchanged mask as a real account number; mock bank setup is not a real payout destination.
- Depends on: Contract, P-FIN-03

#### P-ACC-05 — Upload a provider profile photo
- Story: As a Provider, I want to upload/change my photo so that my public profile is recognizable.
- Status: Blocked | Priority: P1
- Acceptance: Confirm the Provider upload role/type/limit and durable URL/key contract before connecting a picker; preserve current saved photo during unrelated PUTs; do not assume Customer-specific uploader rules apply unchanged.
- Depends on: P-PRO-02, Contract

#### P-ACC-06 — Update my personal address
- Story: As a Provider, I want to update my residential address so that my personal information remains current.
- Status: Blocked | Priority: P1
- Acceptance: Confirm residential address read/write fields and validation; a business market or service area is not a residential address; preserve unrelated profile data and expose read/write failures honestly.
- Depends on: P-PRO-02, Contract

#### P-ACC-07 — View completed-booking and business metrics
- Story: As a Provider, I want accurate account-wide performance statistics so that I can monitor my work.
- Status: Blocked | Priority: P1
- Acceptance: Confirm Provider-owned counters and counted statuses; distinguish unavailable/error from zero; never derive unsupported completed-booking counts from service registrations or Admin-only statistics.
- Depends on: Contract

#### P-ACC-08 — Change verified email or phone
- Story: As a Provider, I want supported contact-change verification so that I can update how the platform reaches me.
- Status: Blocked | Priority: P1
- Acceptance: Confirm authenticated contact read/update, uniqueness and verification contracts; displaying session email/phone does not authorize changing them through profile PUT; retain the same account and prevent accidental account creation/linking.
- Depends on: P-PRO-02, Contract

### Provider opportunities, work and communication

Current Requests/Opportunities and Messages routes render placeholders. The
following operational stories are future requirements, not features inferred
from those tabs or from Customer booking endpoints.

#### P-JOB-01 — Browse my opportunities
- Story: As a Provider, I want eligible incoming opportunities so that I can decide which work to consider.
- Status: Blocked | Priority: P0
- Acceptance: Confirm Provider request/list ownership, visibility, filtering and paging contracts; show real empty/error states and backend eligible requests; a placeholder route is not an operational inbox.
- Depends on: P-REV-02, Contract

#### P-JOB-02 — Review an assigned/requested job
- Story: As a Provider, I want permitted job details so that I can assess the care request responsibly.
- Status: Blocked | Priority: P0
- Acceptance: Confirm Provider-owned detail fields, customer-contact visibility, schedule/location and payment information; reject unauthorized jobs; do not reuse Customer detail assumptions or expose private customer evidence without authority.
- Depends on: P-JOB-01, Contract

#### P-JOB-03 — Accept or decline work
- Story: As a Provider, I want to accept or decline an eligible request so that my work commitments are explicit.
- Status: Blocked | Priority: P0
- Acceptance: Confirm transitions, timeout/expiry, concurrency and conflict contracts; success must be server-confirmed; prevent duplicate acceptance and do not invent automatic OPEN_REQUEST dispatch/offer behavior.
- Depends on: P-JOB-02, Contract

#### P-JOB-04 — Manage an active job lifecycle
- Story: As a Provider, I want supported start/completion/cancellation actions so that actual work progress can be recorded.
- Status: Blocked | Priority: P1
- Acceptance: Define allowed states, authorization, evidence/dispute requirements and financial consequences; no locally advanced job or settlement status; expose only confirmed operations.
- Depends on: P-JOB-03, Contract

#### P-JOB-05 — View my work calendar
- Story: As a Provider, I want a calendar of confirmed work so that I can plan my time and avoid conflicts.
- Status: Blocked | Priority: P1
- Acceptance: Confirm Provider bookings/calendar source and market timezone rules; distinguish recurring availability from actual booked jobs; use server conflict checks rather than a local calendar as booking authority.
- Depends on: P-JOB-03, Contract

#### P-COM-01 — Exchange permitted job messages
- Story: As a Provider, I want authorized conversations with customers so that I can coordinate agreed care.
- Status: Blocked | Priority: P1
- Acceptance: Confirm conversation membership, message/read/attachment APIs and moderation/privacy rules; maintain retry/order/unread semantics; do not label the current Messages placeholder as functional chat.
- Depends on: P-JOB-02, Contract

### Provider wallet and finance

Evidence: wallet appendix explicitly authorizes SERVICE_PROVIDER on shared /me
routes. Account payout-editor schema gaps remain separate from these supported
wallet contracts. Admin finance approvals are outside both mobile app roles.

#### P-FIN-01 — View wallet balances and history
- Story: As a Provider, I want my supported currency wallets and ledger history so that I can understand available, held and pending funds.
- Status: Ready | Priority: P1
- Acceptance: Use owned /me wallet/list/read/history contracts with decimal-safe amounts and pagination; distinguish pending from withdrawable funds and label MOCK funding; do not manufacture job earnings or dashboard totals.
- Depends on: P-AUTH-04

#### P-FIN-02 — Use capability-controlled wallet actions
- Story: As a Provider, I want only enabled funding/payout actions so that I do not attempt unavailable financial operations.
- Status: Ready | Priority: P1
- Acceptance: Read shared payment capabilities on entry/resume; do not expose Admin gateway settings; handle disabled/unconfigured gateway and conflicts without claiming a completed real transaction.
- Depends on: P-FIN-01

#### P-FIN-03 — Set up a supported bank method and withdrawal
- Story: As a Provider, I want to initiate supported withdrawals so that available wallet funds can be requested through an eligible method.
- Status: Ready | Priority: P1
- Acceptance: Use documented owned payment-method setup/list and withdrawal intent/idempotency contracts; display VERIFIED_MOCK and test outcomes honestly; never imply real bank payout while only MOCK/unconfigured PAYHERE exists.
- Depends on: P-FIN-02

#### P-FIN-04 — Recheck payment outcome and reconciliation
- Story: As a Provider, I want reliable financial status after interruptions so that I do not repeat a withdrawal or trust an unbalanced wallet.
- Status: Ready | Priority: P0
- Acceptance: Retain intentId/idempotency key across retries and fetch authoritative outcome; distinguish pending/succeeded/failed and supported refund cases; block further actions on failed reconciliation and require backend handling.
- Depends on: P-FIN-03

#### P-FIN-05 — Receive production earnings settlement
- Story: As a Provider, I want completed work settled through a verified payout process so that I receive actual earnings.
- Status: Blocked | Priority: P1
- Acceptance: Confirm finance approval, earnings release, fee/distribution and real gateway/bank contracts; Customer PAID/RESERVED is not Provider settlement; no mobile client can approve finance or synthesize settlement.
- Depends on: P-JOB-04, P-FIN-03, Contract

## 3. Shared and cross-app product stories

These stories apply to both apps. Partial does not mean every screen lacks the
behavior; it means the complete cross-app/release outcome is not established by
this source review. They supplement, rather than replace, feature acceptance.

#### X-CORE-01 — Keep Customer and Provider accounts separated
- Story: As an app user, I want the correct role and app identity enforced so that I do not enter the wrong experience or access another role's data.
- Status: Implemented | Priority: P0
- Acceptance: Preserve distinct native app IDs/display names and role guards; validate restored and newly authenticated roles; never infer role from the launcher icon or a locally edited value.
- Depends on: C-AUTH-08, P-AUTH-04

#### X-CORE-02 — Keep credentials and diagnostics private
- Story: As an app user, I want credentials and personal uploads protected so that debugging and storage do not expose them.
- Status: Implemented | Priority: P0
- Acceptance: Keep tokens in secure storage and Provider drafts encrypted; exclude secrets/private image URLs from logs; public image hosts never receive app Authorization; preserve correct account scoping and safe error mapping.
- Depends on: C-AUTH-08, P-AUTH-04

#### X-CORE-03 — Recover from slow or failed requests
- Story: As an app user, I want clear loading and retry behavior so that I understand problems without losing my valid work.
- Status: Partial | Priority: P0
- Acceptance: Use shared accessible loading/error components where applicable; keep empty data distinct from transport failure; preserve feature drafts and verify coverage again as planned screens are added.
- Depends on: None

#### X-CORE-04 — Avoid duplicate or stale actions
- Story: As an app user, I want repeated taps and delayed responses handled safely so that the app does not submit duplicates or show another selection's data.
- Status: Partial | Priority: P0
- Acceptance: Guard duplicate in-flight writes and ignore replaced/disposed/account-scoped results; use only documented idempotency/read-back recovery; extend lifecycle tests to future booking/payment/job flows.
- Depends on: C-BKG-10, P-REG-13

#### X-CORE-05 — Use the app with accessible text and motion
- Story: As an app user, I want readable scaling, clear semantics and reduced-motion support so that I can complete tasks comfortably.
- Status: Partial | Priority: P0
- Acceptance: Support screen-reader labels, keyboard/focus, safe areas and large-text scrolling; expose validation and busy states; reduce success animation motion when requested; audit new workflows on real devices before release.
- Depends on: None

#### X-CORE-06 — Understand market time and money
- Story: As a Customer or Provider, I want times and currency interpreted consistently so that appointments and financial values are not misleading.
- Status: Partial | Priority: P0
- Acceptance: Use returned market timezone/currency, required timestamp formats and decimal-safe money; never derive them from device locale; verify both apps across timezones and changing markets as booking/payment code is added.
- Depends on: C-BKG-01, C-PAY-02, P-REG-07

#### X-CORE-07 — Receive meaningful notifications
- Story: As a Customer or Provider, I want verified notifications and unread counts so that I can respond to important account or service events.
- Status: Blocked | Priority: P1
- Acceptance: Confirm feed/read-count/push registration and event contracts plus opt-in behavior; no fabricated counts or silent assumptions of real-time approval; keep unsupported actions disabled or explanatory.
- Depends on: Contract

#### X-CORE-08 — Access support and legal/security actions
- Story: As an app user, I want approved support, privacy and account-security destinations so that I can find help and understand my account choices.
- Status: Partial | Priority: P1
- Acceptance: Replace disabled links/local guidance only with approved URLs or confirmed APIs; define password change/account deletion/contact support separately; do not create invented destinations or imply a nonfunctional control works.
- Depends on: Contract

#### X-CORE-09 — Preserve routes without bypassing prerequisites
- Story: As an app user, I want navigation and returning links to respect my current account state so that I can resume safely.
- Status: Partial | Priority: P0
- Acceptance: Keep current auth/onboarding guards and tab routes; invalid IDs/unknown state fail safely; add return-destination support for Customer requirements and future jobs without bypassing account/profile/eligibility checks.
- Depends on: C-REQ-06, P-REV-02

#### X-CORE-10 — Trust the released app on actual devices
- Story: As an app user, I want verified deployed integrations so that tested screens also work with real account data and native capabilities.
- Status: Partial | Priority: P0
- Acceptance: Validate live authentication/SMS, public/private media, maps/permissions and configured payment capabilities; run relevant workspace analysis/tests/builds and native smoke tests; do not equate a passing mock test/debug APK with production acceptance.
- Depends on: C-PRO-04, C-BKG-09, P-REV-01, Contract

## 4. Explicit product proposals outside confirmed contracts

These are useful candidate stories for a complete marketplace, but must not be
reported as existing backend capabilities. Product discovery can remove or split
them before implementation. No endpoint names are proposed here.

#### F-01 — Customer reviews and ratings submission
- Story: As a Customer, I want to review eligible completed care so that future customers can make informed choices.
- Status: Proposed | Priority: P2
- Acceptance: Define who can review, moderation, visibility and create/edit contracts; keep existing returned rating displays separate from the ability to submit a review.
- Depends on: C-BKG-11, Contract

#### F-02 — Favorites and repeat bookings
- Story: As a Customer, I want to save preferred providers and reuse past selections so that arranging future care is easier.
- Status: Proposed | Priority: P2
- Acceptance: Define persistence/privacy and repeat-booking behavior; every new booking must recheck current options, eligibility and availability rather than reuse old approval or prices.
- Depends on: C-BKG-11, Contract

#### F-03 — Customer/Provider live coordination
- Story: As a Customer or Provider, I want approved real-time communication or tracking so that I can coordinate a live care appointment.
- Status: Proposed | Priority: P2
- Acceptance: Separately define chat, live location consent, event infrastructure and retention; current approximate service pins/liveTrackingSupported false must never be relabeled as real-time tracking or ETA.
- Depends on: P-COM-01, P-JOB-04, Contract

#### F-04 — Disputes, cancellations and refunds
- Story: As a Customer or Provider, I want an auditable resolution process so that cancellations or service/payment disputes can be handled fairly.
- Status: Proposed | Priority: P1
- Acceptance: Define product rules, authorized roles, evidence, state transitions and finance integration; current mock refund events do not establish a general cancellation/dispute/refund capability.
- Depends on: C-BKG-12, P-FIN-05, Contract

#### F-05 — Automatic matching and quotes
- Story: As a Customer, I want a supported open request or quote workflow so that suitable providers can respond to my needs.
- Status: Proposed | Priority: P2
- Acceptance: Confirm dispatch/offer/quote lifecycle, provider consent and pricing authority; configured OPEN_REQUEST values alone do not authorize inventing automatic acceptance, quotes or reservations.
- Depends on: C-BKG-04, P-JOB-03, Contract

## 5. Delivery order and external dependencies

Recommended Customer order: C-DIS-04/05 → C-REQ-01–06 → C-BKG-01/02/04/05/07/08
→ C-BKG-09/10/11 → C-PAY-01/02/07 → other wallet/card/route capabilities. Resolve
C-PRO-04 (observed public-image 403) alongside that work.

Recommended Provider order: validate existing registration/live dependencies,
especially P-REG-05; confirm P-JOB-01–05 contracts before operational work; confirm
global settings contracts separately from assignment-scoped setup; implement
shared wallet capabilities only with honest MOCK/unconfigured-gateway handling.

Known external dependencies are public image access, SMS delivery configuration,
Google identity/maps setup, global Provider profile contracts, Provider operational
job/chat APIs, notification APIs, and production payment/settlement integration.
The historical language-save 500 requires fresh live/backend validation rather
than an assumed permanent failure or an assumed fix.

## 6. Evidence and exclusions

- Current source: `apps/customer_app/lib/`, `apps/provider_app/lib/` and their tests.
- Current Provider reports: `provider-service-registration.md`, `provider-home.md`,
  `provider-application-status.md`, `provider-profile-api-requirements.md`,
  `provider-google-maps.md`, `backend-language-save-failure.md` (all under docs).
- Current Customer reports: `customer-email-auth.md`, `customer-phone-auth.md`,
  `customer-profile.md`, `customer-market-home.md` (under docs).
- Customer source contract: supplied `481b13c7-d999-4573-9362-10143874247b/Pasted text.txt`,
  including the wallet appendix. Provider contract details are grounded in the
  current implementation/repository reports; no fresh Provider backend source or
  live service audit was available in this story-generation task.
- Older report sections can describe superseded behavior. Current source and
  explicitly updated contract reports take precedence; for example Provider GET
  profile is now implemented, while global ProfileSupplement integration is not.
- Admin configuration/review/finance approval are dependencies, not permissions
  or user stories granted to Customer/Provider mobile roles. Admin-only endpoints
  are outside this backlog. Feature splitting and priorities remain product-review
  decisions, and the included CSV is a portable backlog, not a tracker import.
