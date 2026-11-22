# Customer booking feedback — step 4

Based on the 10 November 2026 Provider ratings addition to the customer API
reference. This step implements booking feedback. The search-card step below uses
service-specific rating summaries. Public review browsing and distributions are
now implemented in [step 6](customer-provider-reviews.md); tracking and push remain
separate subsequent steps.

- Completed Booking details displays Rate your provider below service progress.
- GET `/customers/me/bookings/{jobId}/ratings` supplies owned provider IDs,
  names, rating eligibility and saved feedback. No cached search identity is used
  to decide who may be rated. Team members are listed separately.
- Tap an unrated provider, choose 1–5 stars and optionally enter up to 1000
  characters. The UI explains feedback cannot be edited/deleted. No default star
  value, automatic dialog, automatic submission or payment action is introduced.
- Explicit Submit rating POSTs `{providerId,rating,comment?}` to the same route.
  Empty comments are omitted. Repeated taps are blocked. Saved stars/comment
  remain visible and the editor disappears after acknowledgement.
- Unknown writes trigger a GET, never an automatic POST retry. If that read also
  fails, submission stays blocked until Check rating status succeeds. A backend
  duplicate 409 is reconciled through the same read. Successful acknowledgements
  cannot be undone by a temporarily stale read within this screen session.
- Authentication changes discard late responses; feedback is not persisted
  locally or shared between accounts. Unsupported/unavailable endpoint errors
  leave booking details usable with an explicit read retry.

## Manual check

1. Hot restart and open an owned COMPLETED booking from Booking tab.
2. Scroll to Rate your provider and tap an unrated provider.
3. Check that Submit rating is disabled until stars are selected; add a comment.
4. Submit once, then check the saved stars/comment and absence of an editor.
5. Leave and reopen the booking: saved feedback must come from the backend.
6. Where available, check a team booking can rate each actual provider separately.

Automated widget tests exercise actual Booking-tab navigation, explicit submit,
duplicate taps, failed GET recovery, unknown POST plus failed reconciliation,
already-rated feedback and narrow large text. Repository tests reject invalid
stars/comment length before transport. All test writes use a fake backend.

The supplied reference labels this backend addition implemented locally, not
deployed. Device/API deployment and a real completed booking must be confirmed
for live manual testing. No live rating is submitted by automated tests.

## Step 5: service-specific search ratings

Provider result cards read `optionAverageRating` and `optionTotalRatings` when
either field is present, with the selected service name below the rating. Explicit
null or zero-count option feedback displays Not yet rated, never borrowing the
provider's overall rating. Older responses without both new fields display the
existing overall figures, explicitly labelled Overall rating. Overall fields are
preserved for accepted-provider/profile/tracking usage. No new network call,
search filter, ranking, selection or payment behavior is introduced.

The candidate parser validates optional score/count types, finite 1–5 scores and
nonnegative integer counts. Five tests cover service-vs-overall values, unrated
options, legacy responses, 320px/2x typography and malformed inputs.

Manual check: open a service's provider results. Check the service label, score
and count against its API fields. Change service to verify its own figures; an
unrated service must not inherit the same provider's rating from another service.
If the deployed backend still omits the new fields, expect Overall rating.

## Completion review sheet (17 November 2026)

When the open booking details screen observes a transition to COMPLETED, it opens a rounded white review sheet once for the first unrated provider. Existing completed bookings retain a provider entry to open the same sheet manually. Closing the sheet does not submit or reopen it on the next poll. Team bookings keep separate provider reviews.

The sheet uses the app typography, five explicit star choices, an optional note (the API limit remains 1000 characters), and Submit Review. No star is selected initially. Submission, duplicate prevention and GET-only reconciliation of uncertain writes retain the existing rating contract. Large text and narrow screens scroll; logout removes the account-specific sheet.
Unrated completed single-provider bookings show an Add a Review mint banner within the booking summary. Dismissing the sheet retains the banner, which reopens the same editor. Saved reviews and team-specific review lists retain their existing behavior.
