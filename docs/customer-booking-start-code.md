# Booking completion work: step 1 — customer START code

The user requested one feature at a time, followed by manual review before the
next implementation. This step adds the customer START-code presentation
inside Booking Details. The user has since approved step 2 (service progress);
its foreground poll now supplies lifecycle updates to this card. Completion
confirmation, tracking and push registration remain future steps.

## Behavior

- Shows Service start code after the booking header for CONFIRMED jobs with
  CARD/PAID or WALLET/RESERVED funding.
- Show start code first rereads the customer's own booking history by job ID,
  then GETs `/customers/me/bookings/{jobId}/verification-codes`.
- The backend enforces the opening window (30 minutes before service start).
  The client does not guess a timezone or generate a code.
- Accepts purpose START, exactly four numeric string characters, and a valid
  absolute UTC expiry. Preserves leading zeros and rejects six-digit legacy or
  malformed responses. Expired codes are hidden.
- Hide code, backgrounding, logout and booking lifecycle changes remove the
  revealed code. A late response after Hide/background cannot reveal it again.
- While revealed and the details route is foreground, own history is reread
  every five seconds. A service start/cancellation hides the code and refreshes
  the booking header. Ordinary reads do not show a loading spinner on the card.
- No code is written to persistent storage or logs. Copying to the system clipboard
  is available only through an explicit tap on the revealed code's copy icon;
  hidden, expired or identity-invalid codes cannot be copied. There is no customer call to
  provider `/start`, no completion write and no payment action in this feature.
- The current API has no locked status. The UI does not invent or infer it.

## Manual review

1. Hot restart the Customer app (`R`). Open Booking → a confirmed paid Hospital
   Care booking → Booking Details.
2. Check the Service start code card and Show start code action.
3. Before the server's service window, expect unavailable/service-window
   feedback. This is expected; a newly scheduled booking with a two-hour minimum
   notice will not immediately have an accessible code.
4. With a booking inside its allowed window, tap Show start code: all four
   digits, including any leading zero, should be visible.
5. Hide it, then reveal again. Background/resume the app: it should stay hidden
   until explicitly revealed again. Confirm long text/larger system fonts fit.
6. If the provider starts the service, a revealed code should disappear on the
   next successful foreground status read. IN_PROGRESS/COMPLETED/unpaid bookings
   should not offer a START code.

No live booking, payment or provider action was performed during implementation.
Automated tests stub owned booking/code responses and exercise errors, expiry,
duplicate taps, invalid formats, logout/late responses and real details routing.
