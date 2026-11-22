# Customer booking chat

Implements the supplied Booking Chat API contract (18 November 2026). The user subsequently confirmed that these endpoints are deployed. Actual message delivery still requires manual customer/provider testing.

## Entry points

- Customer footer has no Messages destination. Existing inbox route remains available to internal navigation; booking details opens the shared chat sheet.
- Booking details has **Message your provider** for post-payment/history bookings. The server remains authoritative: an unopened cancelled chat can return 409.
- Inbox conversations open `/messages/{jobId}`. A team uses the same shared thread; participant and sender names identify providers.

## APIs

- `GET /customers/me/conversations`
- `GET /customers/me/bookings/{jobId}/messages` (latest); `?after=` for new messages; `?before=` for earlier messages.
- `POST /customers/me/bookings/{jobId}/messages` with `text` and a random, valid `clientMessageId`.
- `POST /customers/me/bookings/{jobId}/messages/read` with the newest message actually displayed in the visible viewport.

Paths use the existing authenticated API client and `/api/v1` configuration. Provider chat now uses the corresponding `/providers/me` endpoints; see `provider-booking-chat.md`.

## Behavior

- Poll every four seconds only while chat is the current route and the app is foregrounded; no background chat timer. Existing messages remain visible during refresh. Earlier messages load explicitly and merge by ID.
- Composer follows `canSend` and `sendUntil`; closed chats stay readable. A 404 disables the thread; an embedded sheet stays open with a readable error. A 409 reloads availability.
- Plain-text bubbles use server-returned masked text; null text displays **Message unavailable**. Contact masking has an explanatory note. No optimistic unmasked bubble, message-body logging or disk chat storage.
- An uncertain send retains the original text/id in session memory. Explicit Retry uses the same id; polling can reconcile an accepted send through `clientMessageId`. No automatic POST replay. A known 400 retains the draft for correction; 429 disables send until the retry interval has elapsed.
- Read receipts move forward; **Seen** uses `othersLastReadMessageId`. Account change/signout clears thread, draft and inbox state and ignores stale responses.
- Existing booking push delivery handles `CHAT_MESSAGE_FROM_PROVIDER`, checks the owned request/job, opens the matching chat and refreshes the inbox. Booking events and app resume refresh the badge too. Actual push delivery still depends on the app's existing push configuration.

## Current deployed v1 contract

- Chat opens at CONFIRMED; no frontend 30-minute gate. `canSend` and `sendUntil` control composition. Do not calculate a new 24-hour deadline locally.
- Polling catches up through all `hasNewer` pages and deduplicates by message ID. Only shared-team conversations show sender labels.
- HTTP Date synchronizes the repository clock for send deadlines and retry cooldowns; monotonic elapsed time avoids subsequent phone-clock changes.
- A pending uncertain message can be retried with the original client ID even after the new-message window closes. There is no automatic send replay.
- Wrong-role 403 does not log the customer out. Exact 409 detail distinguishes unconfirmed booking from closed chat.
- Backend G1?G3 (explicit availability, machine-readable errors, fixed end-time window) remain pending. No unsupported presence, attachment, or delivery state is displayed. Push remains optional; polling is the delivery fallback.

## Manual checks after backend deployment

1. Confirm a booking; open its chat from Booking details or Messages.
2. Exchange customer/provider messages, including Sinhala/Tamil/emoji. Confirm sender names, unread badge and Seen.
3. Send a phone/email and confirm masked server text plus the safety note. Null/unreadable content should show the unavailable placeholder.
4. Background the app or cover/pop the chat: no chat polling/receipts should continue. Resume/reopen and check missed messages.
5. Disconnect during send, reconnect and Retry: one server message, same client ID. Check validation and rate-limit draft retention.
6. Load more than 50 messages, page earlier/newer, and check ordering/deduplication.
7. Test server read-only/409/404 states, team membership removal, and signout/account switch. Do not fabricate chat availability from booking status.

Automated tests use only a fake HTTP adapter and do not send real messages or mark live chats read.
