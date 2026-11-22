# Provider booking chat

The Messages tab is connected to deployed v1 and Booking details opens a shared chat sheet. Provider keeps its PublicSans font and the booking chat palette matches Customer.

## Transport

Authenticated provider paths beneath the configured /api/v1 base:
- GET /providers/me/conversations (latest 50; totalUnread drives the footer badge).
- GET /providers/me/bookings/{jobId}/messages, with before/after cursor pagination.
- POST /providers/me/bookings/{jobId}/messages with text and a stable random clientMessageId.
- POST /providers/me/bookings/{jobId}/messages/read with the latest actually displayed message ID.

Chat opens from CONFIRMED. Server canSend/sendUntil remain authoritative. Team members share one thread. Read-only history remains visible. No presence, attachments, typing, block/report, or delivered state is fabricated.

## Lifecycle and safety

- Open thread polls every four seconds only while visible and foregrounded. Inbox polls no faster than 30 seconds; badge also refreshes on resume and actual read/send acknowledgement.
- Pagination drains hasNewer pages, orders/deduplicates IDs, and explicitly loads older messages.
- Server-returned masked text is displayed, without an optimistic unmasked bubble. Seen uses the server read cursor.
- Timeout retains original text/client ID for explicit retry, including after new sends close. POST is never automatically replayed on auth refresh. Rate limit cooldown and sendUntil use HTTP Date plus monotonic elapsed time.
- Account identity is checked before and after I/O. Old sessions cannot send/read as a new owner; no message data is persisted to disk or logged.
- 403 does not clear credentials. 404/409 show a stable unavailable/read-only state; the embedded sheet does not disappear automatically.

## Verification

Fake HTTP controller tests cover provider prefix, newer-page catchup, stable retry, account switch, 403, read-only, displayed read receipts, hidden polling, expired-window retry, server clock and badge refresh. Widget tests exercise inbox -> sheet -> message send and 320/430px booking UI. They send no live messages or read receipts.

Manual end-to-end test still requires Customer and Provider accounts on the same confirmed booking. Check shared-team sender labels, contact masking, unread/Seen, background/resume, disconnect/retry, completed/cancelled history and membership removal. Push events are not reliable on the current server; polling must work independently.

Pending backend G1-G3 are not guessed: explicit availability fields, machine-readable errors and an immutable completed/cancelled chat deadline.
