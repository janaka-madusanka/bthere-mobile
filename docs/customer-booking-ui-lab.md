# Booking UI Lab

A separate debug app for reviewing the actual Customer Booking Details widgets with controlled sample API responses. UI code is reused, not copied. Start the review with **Ready**, then **Ready / start code**; other lifecycle fixtures are available for later passes.

## Run on Android emulator

From the repository root:

```powershell
.\scripts\run-booking-ui-lab.ps1 -DeviceId emulator-5554
.\scripts\run-booking-ui-lab.ps1 -DeviceId emulator-5554 -Scene ready-code
```

Android installs **Booking UI Lab** (`com.bthere.customer.bookinglab`) alongside **B there Customer** (`com.bthere.customer`). The normal app's login and storage are not read, replaced or cleared. To return to live testing, launch the normal app or use `scripts/run-customer.ps1`.

The script deliberately does not read `config/customer.local.json`, provider credentials, API tokens or Maps keys. The lab entry requires debug mode plus its explicit launch flag. Normal `main.dart` does not import it.

## Controls

The amber sample-data toolbar stays visible:

- Left sliders icon: choose a booking state.
- **Aa**: cycle 1x / 1.3x / 2x text.
- Phone icon: toggle a 320 logical-pixel content width.
- Reset icon: discard sample actions and restore the selected state.

Flutter hot reload updates the shared UI widgets; full restart resets the lab. There is no lab account to log into.

## First review: Ready

1. Check the title, booking ID, Ready pill and start countdown.
2. Check the actual provider row, call/chat spacing and optional-phone rules. The sample call is intercepted and shows an informational snackbar; no phone app is opened.
3. Inspect map-card sizing, service schedule, location and real payment labels. This lab uses a clearly labelled offline sample-map renderer; native Maps/route accuracy is checked later against real API data.
4. Expand Patient details and inspect labels, values and narrow/large text.
5. Open cancellation preview, then Keep booking. Even explicit cancellation in this lab only changes sample memory; Reset restores it.
6. Select **Ready / 23 min**; Show code, Hide and optional Copy exercise the production START-code widget with a sample leading-zero code.
7. Open provider chat; inspect the sheet/keyboard and close it. Messages stay in sample memory only.

Sample provider/service pictures use the existing fallback artwork; this does not establish live photo delivery.

## Other fixtures

`in-progress`, `confirm-completion`, `completed`, `reviewed`, `payment-failed`, `payment-expired`, `cancelled`, `loading`, `error`.

These render the same actual screen and components. Completion, rating and cancellation writes are local simulations. Payment details/recovery states can be viewed, but opening a checkout stops at an explicit later-review boundary; the lab never launches a live payment gateway. Those states will be refined after Ready is reviewed.

## Isolation

- Auth/session and recovery keys use memory-only stores.
- A fake HTTP adapter accepts only `booking-ui-lab.invalid`; unknown paths return a local 501 and never fall through.
- The lab entry blocks Dart HTTP network connections as a second guard.
- Map rendering is overridden before a native Maps view is created; there is no device location lookup or Directions request.
- Native dialler launch is injected and intercepted. No push registration or normal app startup host is mounted.
- Production API repositories, booking widgets, status guards and UI actions are used unchanged except the normal call launcher is now injectable.

The lab is for visual/state review, not proof of live API behavior. After each reviewed part, perform a real customer/provider smoke test; complete end-to-end verification after all states are approved.

## Coordinate mapping correction

The full BookingResponse contract contains flat `latitude` / `longitude`. `bookingLocationPoint` now accepts and validates those fields as well as existing nested projections. Missing, incomplete and out-of-range pairs still use the honest location fallback; device GPS is never substituted for a booking location.
