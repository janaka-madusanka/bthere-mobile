# Provider booking UI contract audit - 31 October 2026

Scope: provider app only. Customer payment, verification-code retrieval, and Search longer endpoints belong to the customer app and must never be called with a provider session.

## Implemented

- Booking details: themed status and net earnings cards, readable schedule/location, labelled customer answers, no projected earnings on cancelled/expired bookings, explicit booking MOCK indicator.
- START: four numeric characters sent as a string, including leading zeros; funded CONFIRMED and legacy BOOKING_CONFIRMED supported. Server enforces service window and code locking. Provider completion waits for customer confirmation.
- Assigned provider payment window: authenticated GET /providers/me/booking-requests/{requestId}/payment-window. Server flags and deadline gate actions; refresh before action and periodic recheck while displayed.
- Unpaid cancel: authenticated bodyless POST /providers/me/booking-requests/{requestId}/cancel after confirmation, then reload booking state.
- Deadline extension: authenticated PUT /providers/me/booking-requests/{requestId}/payment-deadline, absolute UTC confirmationExpiresAt. Choices increase the existing deadline, do not exceed immutable paymentDeadlineLimit and precede known service start. Server remains authoritative for races and lifecycle transitions.
- Acceptance persists job-to-request references across restarts; existing job contracts need not change. Legacy journal entries without a request reference need a backend-provided requestId or support; the app does not guess that a job ID equals a request ID.
- Grouped offers: current offers reloaded before decisions, server acceptance resolves the winner, push reconciliation removes cancelled/expired offers and dismisses the alert through the existing host.
- Payment settings provider/testMode retained; test setup clearly labelled in method management. Brand comes only from explicit VISA/MASTERCARD response fields, never display-label inference.
- Saved methods: authenticated bodyless DELETE /me/payment-methods/{methodId}, accepts 204, refreshes methods, explains 404 and pending-payment 409. Removal preserves the pending payment journal and wallet history.

## Verification limits

API tests use adapters and synthetic sessions. Widget tests exercise 320/430 booking layouts, four-digit input, payment controls, and method transport. These checks do not prove hosted deployment, merchant settlement, device push display, or backend migrations. The existing wallet golden comparison reports text differences; its reference image has not been replaced.
