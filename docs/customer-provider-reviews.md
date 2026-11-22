# Provider public feedback — step 6

Provider details opened from real provider search now includes Ratings & reviews.
The same panel is attached to existing remembered-provider details in Booking
Details. It does not create a new assigned-provider identity endpoint or fabricate
missing historical provider profiles.

## Contract and behavior

- Authenticated GET `/customers/me/providers/{id}/ratings` fetches the overall
  summary and per-option summaries. The selected search/booking option starts
  selected; All services and named service chips change the feedback scope.
- Each summary displays server average/count and five distribution bars. Null
  averages or zero counts display Not yet rated, without invented zero-star
  averages or using another option's ratings.
- GET `/customers/me/providers/{id}/reviews?page=0&size=10&optionId=...` fetches
  visible, newest-first public reviews. All services omits optionId. Display the
  server-shortened customer name, star rating, option name, optional comment and
  date component as provided. Backend local date strings are not reinterpreted
  as UTC/device time.
- Load more reviews appends one page at a time, deduplicating ratingId. A failed
  subsequent page retains earlier content and retries the same page number.
- Scope changes reset pagination; a revision guard ignores late previous-scope
  responses. Duplicate taps cannot start overlapping reads in the same scope.
- Summary/review errors are independent, with separate read-only retries. The
  provider profile and Close remain usable if the new endpoints are unavailable.
- Requests occur only on opening, explicit scope change, paging or retry: no
  polling, booking/payment mutation, hidden automatic rating or local persistence.
- Auth changes clear feedback; late results after logout/disposal are discarded.
  Unknown/invalid payloads never become invented reviews/ratings.

The existing standalone profile widget can still be rendered without a network
feedback panel, preserving callers that only have candidate metadata.

## Manual test

1. Hot restart and open a service's provider results, then provider details.
2. Scroll to Ratings & reviews. Expect that service selected and its distribution.
3. Select All services and another available service; review labels must match
   the selection without mixing old reviews or changing the selected provider.
4. Load more reviews where available; scroll should stay in the dialog, and Close
   must still work. Empty feedback should show Not yet rated / No reviews yet.
5. If endpoints are unavailable, expect independent Retry summary / Retry reviews
   controls. Retry must not create a booking or payment.

Six controller/parser tests and three dialog tests cover read-only transport,
pagination, failed-page retry, late-scope responses, overlapping reads, logout,
partial failure recovery, malformed feedback, empty states and 320px/2x text.
Tests use fake API responses only. The supplied API reference says this backend
addition is locally implemented, not deployed; live deployment/manual review is
still required. Live tracking and push are subsequent separate steps.
