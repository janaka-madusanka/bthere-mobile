# Customer live tracking and booking notifications

Manual review is postponed until the remaining customer implementation is ready,
as requested on 10 November 2026. Automated checks remain part of development.
This extends the status-only step in customer-tracking-status.md.

## Live tracking

The existing owned tracking GET now retains provider/location/target/display-field
data. The Booking details journey card includes a live map for EN_ROUTE, IN_TRIP,
and FULL_TRIP ARRIVED; other statuses show text/provider information without a
live map. ENDED removes live provider content. Unsupported options remain hidden.

- Provider positions use stable IDs, backend marker artwork and heading. Public
  artwork uses the existing bounded, cached, unauthenticated icon loader with a
  standard marker fallback. The target is a distinct orange marker.
- Camera bounds include the target and all shared provider points. New coordinates
  refit while following; timestamps/ETA changes alone do not recenter. Touching
  the map stops camera following; Show all locations resumes it. No client GPS
  permission or tracking-location upload is requested from the customer.
- Null provider location remains absent; no old/unshared coordinate, default
  Colombo provider pin or invented road route is drawn. Last returned stale
  locations remain visible with Updating location. A timer at the next location
  expiry handles staleness even if subsequent reads are unchanged.
- Backend stale flag or recordedAt + staleAfterSeconds suppresses live ETA.
  Failed reads retain the previous pin but suppress ETA. Approximate ETA/distance
  are explicitly described as direct-distance estimates, not road routing.
- Provider name/photo and approved public attributes are rendered only from the
  owned tracking response. Labels/choices come from providerDisplayFields.
  Provider details & reviews links to the existing public feedback dialog.
- No journey start/arrival action, service transition, fare recalculation,
  booking mutation or payment is introduced. Foreground/current-route polling
  and lifecycle/account guards from step 7 remain in place.

Provider app GPS upload/Start journey/Arrived implementation is separate: the
previously audited Provider app did not contain these actions. The supplied
customer contract documents the resulting tracking GET, not the full provider
write contract. Real movement requires that producer and deployed backend.

## Notifications

The Customer app now uses the official firebase_core/firebase_messaging plugins,
behind a testable gateway. No Firebase project or credentials are fabricated.

- Home's notification bell opens Booking notifications settings. The app checks
  existing permission silently after authentication; only Enable notifications
  requests OS permission. Denied/unconfigured setup leaves the rest of the app
  usable with explicit feedback.
- Authorized registration POSTs token/platform/deviceName to /me/booking-devices.
  Token changes update registration; replaced device IDs are removed. Only the
  server device ID is stored, scoped by API URL and account. A binding change
  revokes the prior Firebase token before registering another environment/user.
- A pre-logout hook DELETEs the owned device while authentication still exists,
  then revokes the token even if the network removal fails. Authentication loss
  clears pending notices and discards late account responses. Stored IDs and
  token revocation are best effort offline; no successful live removal is claimed
  without a server response. Tokens/notification payloads are not logged.
- Follow-up audit: a failed network logout re-arms registration for the retained
  session. A secure-store read failure keeps registration blocked until the
  account/API binding is successfully recovered. Missing/invalid auth during
  registration or push lookup reconciles auth state, rather than retaining a
  cached signed-in view. Regression tests cover these recovery paths.
- Foreground notifications produce a generic booking-update snackbar. View and
  background/cold-start notification taps resolve requestId through an authorized
  GET before navigation. Payment states go to the existing same-request payment
  route; funded/service states go to owned Booking details. Payload amounts,
  provider details, URLs and jobId never determine trusted state or money.
- Event IDs deduplicate repeated delivery, while a later tap on a foreground
  notice remains actionable. A tap racing an in-flight foreground lookup is
  retained. Startup navigation waits for profile and market readiness. No payment,
  cancellation or completion POST is triggered by a push.
- Background notification payloads are displayed by the OS. The background Dart
  handler initializes Firebase only and never accesses customer accounts/money.
  Existing booking-events recovery refreshes on app resume to cover missed push.

### Configuration still required for real delivery

No customer Firebase config files were present when implementing this feature.
Without them Firebase initialization is caught and push remains unconfigured.

Android:
1. Register `com.bthere.customer` in the correct Firebase project.
2. Put its `google-services.json` at `apps/customer_app/android/app/` locally.
3. The Google Services Gradle plugin is applied only when that file exists.
   Android POST_NOTIFICATIONS permission is declared. Rebuild the native app;
   hot reload is insufficient after plugin/config changes.
4. Backend Firebase credentials must target the same Firebase project.

iOS (requires macOS/Xcode validation):
1. Add the matching GoogleService-Info.plist to the Runner target resources.
2. Enable Push Notifications signing capability and appropriate APNs entitlement,
   configure APNs with Firebase, and use a compatible provisioning profile.
3. remote-notification background mode is declared in Info.plist. No signing
   entitlement or developer-account identity is fabricated in this workspace.

Current backend /booking-devices explicitly accepts legacy FCM registration
tokens. firebase_messaging 17 recommends FIDs via register/onRegistered; this app
uses its still-supported legacy token APIs only at the gateway boundary (with
documented deprecation suppressions) to honor the supplied backend contract.
Do not silently replace the payload token with a FID without backend agreement.

Official references: [Flutter messaging setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[receiving messages](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages),
[Android config/plugin](https://firebase.google.com/docs/android/google-services-plugin-and-file).

## Final device test checklist

1. Rebuild Customer on phone and Provider on emulator with matching API settings.
2. Provider accept -> customer payment success/failure + same-request retry ->
   return Home/Booking details -> countdown and retry recovery.
3. Confirmed job -> valid START code -> provider start -> request completion ->
   customer confirm -> wallet/history settlement -> one rating per provider.
4. Search/public details: service-specific rating, overall/service distributions,
   empty reviews, pagination and retry errors.
5. Tracking-enabled job: scheduled -> en route -> arrived -> full trip -> ended.
   Check marker identity/artwork/heading, target change, camera fit and manual pan.
6. Stop provider location updates past the server stale threshold. Keep the last
   pin, show Updating location, suppress ETA; null location must have no provider
   pin. Check unavailable endpoint/permission/background/resume paths.
7. With real Firebase configured, enable permission and verify backend device
   registration, foreground banner, background OS notification and cold-start tap.
8. Verify duplicate event delivery, token rotation, logout and another account/API
   do not expose the former account's booking content. Missed events should be
   recovered on resume. Push delivery is not proof of payment/service success.

Automated checks use stubbed backend/push data and a map builder without native
views. They do not send real ratings, payments, journeys or notifications. Live
merchant/device delivery, backend rollout and provider GPS remain external checks.
