# Provider booking offers and earnings

Implemented from the supplied **Complete Provider Registration and Service Approval
API Flow (3)** document, including the 25 October 2026 booking update.

The provider-only `features/bookings` feature contains transport, response models,
secure recovery references, a Riverpod controller, Opportunities, booking details,
and an incoming-request dialog. The app composition uses the existing API client,
session token bridge, shell and navigation. Customer and administrator routes are
not called.

| Operation | Relative API path |
| --- | --- |
| Pending offers | GET `/providers/me/booking-offers` |
| Event recovery | GET `/providers/me/booking-events?after={eventId}` |
| Accept / decline | POST `/providers/me/booking-offers/{offerId}/accept` or `/decline`, no body |
| Assigned details | GET `/providers/me/bookings/{jobId}` |
| Start | POST `/providers/me/bookings/{jobId}/start`, `{code}` |
| Request completion | POST `/providers/me/bookings/{jobId}/complete`, no body |
| Register device | POST `/me/booking-devices`, `{token, platform, deviceName}` |
| Unregister device | DELETE `/me/booking-devices/{deviceId}`, no body |

Paths are relative to the configured `/api/v1` base. Device endpoints are ready in
the repository; Firebase token acquisition, token-change registration, push handlers,
notification permissions and logout device cleanup await Firebase configuration,
as agreed. Foreground/resume polling works independently of Firebase. Android
registers `booking_calls` and `booking_updates` channels and uses a looping system
ringtone while the request dialog is visible. Other platforms use a system alert.
Background/locked-screen delivery and continuous iOS ringing are not implemented.

The host polls every five seconds while foregrounded. Each event recovery fetch
is reconciled with current offers before presentation; expired or revoked offers
are dismissed. It stores the event cursor and accepted job IDs under a user-specific
secure-storage key. No private answers, start codes, money, or offer payloads are
stored. There is no invented general bookings list API. Accepted and Completed
tabs display bookings known through this device's recovery journal.

Accept does not imply payment. Start requires a customer code and paid booking;
server lifecycle/time validation remains authoritative. Completion stays at
"Waiting for customer confirmation" until the backend confirms it. Completion
events invalidate the existing wallet controller so balance/history refresh.
Only the server's `providerEarnings` and `currencyCode` appear as earnings; gross
amounts and platform commission are omitted. Wallet history supports settlement
type, booking reference, currency, net earnings and sandbox funding metadata.

The existing registration repository also supports shared-option source lookup
and atomic `POST /providers/me/service-registrations`, with typed request/result
models. Existing registration screens continue using the document's supported
individual update endpoints. Atomic creation is never automatically retried;
recover uncertain creation through the assignment list before further writes.

The requested Messages screen provides search, filters, and an empty state. No
messaging API was supplied; the user requested this empty state. Figma nodes
`416:1725` and `328:2094` supply layout and local static assets. The incoming
reference `425:2185` is largely a raster mockup; its dialog has been rebuilt as
interactive Flutter widgets, with the exported logo asset and live server data.
Missing names, patient answers, distance or schedule tags are never fabricated.

Validation: booking transport tests, recovery/expiry/duplicate-action tests,
responsive UI tests at 320/430 widths, navigation and existing wallet tests.
UI tests render review images to `apps/provider_app/build/booking-previews`.
Live backend calls and native Android/iOS device behavior still need validation.
