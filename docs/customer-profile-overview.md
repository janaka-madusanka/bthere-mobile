# Customer Profile overview integration

The /account route now renders the Customer Profile reference layout using GET /customers/me/profile-overview?recentLimit=5. /profile continues to use the existing full-profile edit/photo flow. Pull-to-refresh, foreground refresh and return from actions reload the account-scoped overview. Errors show retry; missing profile offers completion. No placeholder names, verified flags or money are invented.

## Data and navigation

- Server pending/completed counts; real spending per currency only. Reserved funds are not added. Debug-only test spending is explicitly separated and labelled not real money; release hides it. Excluded payments show a processing note.
- Contact flags are authoritative. Signed-in email/phone OTP flow freezes the requested destination until verification, supports current-password accounts, handles resend delay/expiry and 400 without logout. Writes are never auto-replayed; ambiguous verification is reconciled by GET or blocked pending manual profile refresh. Password/OTP controllers are disposed; no private payloads are logged.
- Documents load actual scoped requirements by requirementId before opening file controls, retain private evidence uploader/view-url, validate type/size/count/expiry and use explicit PUT submission. Unknown save results block blind replay. Submission IDs are never used as requirement IDs. Existing booking evidence behavior is retained.
- History View all opens the existing complete booking view, retaining legacy direct bookings. Pending requests use the paginated list, deduplicate IDs, exclude known terminal states and retain unknown active states. Legacy bookings remain linked through Booking. Job IDs open existing details; matching requests have a read-only current-status sheet.
- No profile nav tab is selected; Home remains actionable. Booking Details selected Booking tab can return to the list after removal of the former View all button.

## Manual verification

1. Open Profile from Home; check the displayed name/photo, verified flags and amounts against overview.
2. Open Edit profile; save the full replacement through the existing editor and confirm refreshed name/photo.
3. Send/verify a code only to a test contact owned by the tester. Wrong code should remain signed in; resend disabled until allowed. Password accounts require current password at verify.
4. Review documents, then explicitly upload/submit a permitted test file. Confirm pending review status after reload.
5. Navigate pending/history items, paginate pending requests and verify old direct bookings remain available in Booking.
6. Verify 320px/enlarged text, empty profile, request errors, logout/account switching and release money labels.

API contract is preserved in CUSTOMER_PROFILE_OVERVIEW_API.md. The user confirmed deployment. Fake-backend tests do not prove actual SMS/email delivery or live document review.
