# Customer phone OTP authentication

Contract: supplied Customer API reference, sections 7 and 8. This is an
alternative to email/password authentication, not phone linking to an existing
email account. No phone field is added to the Customer profile PUT.

From either auth tab, Continue with phone opens an international-number field.
E.164 validation requires + followed by 8–15 digits, with a nonzero first digit.
Whitespace around the number is trimmed; local numbers are not converted using
an assumed market. No password or email is required for this method.

- POST /auth/otp/request: exactly phoneNumber and accountType: CUSTOMER; public,
  expects 202 and positive expiresIn. A generic response does not prove that a
  number/account exists. No session is stored until verification succeeds.
- POST /auth/otp/verify: exactly phoneNumber, six-digit string otp (leading zeros
  preserved), and accountType: CUSTOMER; public. Uses the existing active CUSTOMER
  role validation, secure session persistence, expiry and current-user restore.
- Resend repeats the request endpoint after a local 60-second cooldown; 429
  Retry-After/body delays use the existing longer-wait handling. OTP validity is
  enforced by the backend; expiresIn is not treated as a resend interval.
- Existing Customer profile GET routing remains unchanged: confirmed missing
  profile opens the single profile form; a completed profile opens the account
  page. Phone-only users may have null email.
- Invalid/expired OTP retains the verification screen for retry. Back clears the
  pending OTP UI and permits switching to email. Duplicate submissions are blocked.
- No phone, OTP, token or request-body logging added. Provider and shared code
  are unchanged. No commit, push or PR.

Tests cover exact public payloads, E.164/OTP validation, nullable email, secure
storage/expiry, wrong role, invalid OTP, storage failure, request errors, cooldown,
duplicate requests, new/existing account routing and return to email authentication.
HTTP/session fixtures are local. Actual SMS delivery and deployed endpoints require
manual verification; the API document notes that Text.lk must be configured.

## Shared email/SMS verification design

Customer verification now uses a dedicated branded page matching the supplied
reference: original logo, verification heading, destination, six outlined code
slots, channel-specific help card, MM:SS resend cooldown, Verify and continue,
and change-email/phone action. The email and phone methods share this component.

One accessible native editable field backs all six slots. Numeric filtering,
full-code paste, one-time-code autofill, backspace and leading zeroes use the
same controller; validation requires six digits and submission stays explicit.
No automatic verify or API-contract change was introduced. Busy state disables
verify, resend, input and destination changes. Keyboard and large-text overflow
remain scrollable. Changing destination clears the draft OTP and returns to the
corresponding entry form. Existing cooldown and server Retry-After rules remain.

Preview artifacts: apps/customer_app/build/auth-previews/customer-email-verification.png
and customer-phone-verification.png. UI tests cover both channel layouts, slots,
validation, leading zeroes, cooldown/loading controls and large-text/keyboard
accessibility; existing email/phone auth and profile tests remain applicable.

## Animated verification success

After email or phone OTP verification, success is exposed only after secure token
persistence and restored active CUSTOMER validation. A transient channel flag
routes to /verification-success before normal profile routing. Continue clears
that flag and uses the existing confirmed profile GET state: missing goes to
profile creation, completed goes to the account page, and loading/error states
retain the existing startup handling. Restored sessions do not replay this screen;
logout clears the flag. The flag is not written to secure storage.

The original supplied ka555PzOgf.json is bundled byte-for-byte as
assets/animations/verification_success.json (SHA-256
E44B48FB6EA19EB6A1977C84878C7962FB362DC71BA1DD99B8BA7F2257E9F5FC).
It renders locally with lottie 3.6.1, once over its 2.4-second duration; no remote
image assets are required. Reduced motion shows the completed frame, and a local
check icon handles asset-load failure. Continue never waits on animation loading
or completion. Lottie source/API documentation: https://github.com/xvrh/lottie-flutter.
The root lockfile adds only lottie and its archive/posix transitive dependencies.

Both variants follow the supplied reference with original branding, success
headline, account/checklist card and explicit Continue action. Copy uses Customer
rather than Provider and says Account ready, since phone verification can sign
in an existing account. No backend contract or profile field changed.

Verification: 77 Customer tests passed; Customer analysis and formatting clean.
Tests cover the actual animation composition, persisted-success gating, failures,
Continue to missing/completed profiles, transient restore/logout behavior and
reduced-motion/large-text accessibility. Local visual preview artifacts:
customer-email-verified.png and customer-phone-verified.png under
apps/customer_app/build/auth-previews. No live account/SMS mutations were made.
