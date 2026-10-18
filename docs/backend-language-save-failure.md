# Backend handoff: provider language replacement returns HTTP 500

## Observed failure

The Android app repeatedly receives HTTP 500 from:

`PUT /api/v1/providers/me/services/2/languages`

The preceding `PUT /providers/me/services/2/options` succeeds with HTTP 200.
Observed on 16 October 2026 at 11:48:04, 11:48:29, and 11:55:34 (Asia/Colombo).
The mobile workspace does not contain the backend source or its server logs, so
the underlying exception has not been established.

The documented authenticated request shape is an object, for example:

```json
{"languages":["SINHALA","ENGLISH"]}
```

This is a contract example, not a captured personal request body. The app sends
unique uppercase values from SINHALA, ENGLISH, TAMIL. The response/read contract
is a JSON array of language strings. The path uses assignmentId, not serviceTypeId
or providerOptionId. No new submission endpoint is needed.

## Backend work required

1. Find the exception in server logs for the failed assignment/request. Inspect
   language replacement, persistence constraints, assignment ownership checks,
   and completion/approval recalculation executed by the handler. A particular
   database or approval exception must not be assumed without the stack trace.
2. Make language replacement idempotent and transactional: a repeated identical
   set must return success; a changed valid set must replace the saved set without
   duplicate records or partial updates. Treat order as irrelevant.
3. Return a valid 2xx response after a successful commit. A failed transaction
   must leave the previous language set intact. Invalid input, missing assignment,
   and ownership failures need their documented 4xx responses rather than 500.
4. Add backend integration tests for initial save, unchanged/reordered repeat,
   adding/removing languages, invalid enum, another provider's assignment, and
   completion recalculation. Check both the response and subsequent GET state.

## Frontend recovery implemented

Step 2 reads the latest language set before writing. If it already matches the
requested set, no PUT is sent. If a changed-set PUT returns 5xx or an uncertain
transport failure, the app reads back and continues only when the server confirms
the exact requested set. Otherwise it keeps the draft and blocks advancement with
a section-specific error. It never treats HTTP 500 by itself as success.

This removes unnecessary duplicate language writes and safely handles a committed
write followed by a failed response. It cannot repair a backend that refuses to
persist a genuinely changed language set. That case requires the backend work above.
