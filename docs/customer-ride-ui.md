# Customer Ride layout and route preview

`ROUTE_BASED` service configuration selects the Ride details presentation. No
service name, vehicle label or field ID is hardcoded. Pickup and destination
share an editable trip card, backend pricing choices use compact choice cards,
and booking questions remain schema driven. The existing fare/Continue footer
stays pinned. Ride now groups inputs into three presentation steps: route,
vehicle/pickup time and passenger details. Booking stages, backend validation and
payment confirmation remain unchanged. Back navigation retains the draft.
The initial route sheet caps at 36% of the viewport; later Ride sheets cap at
48%, including review, and can be expanded manually. Keyboard focus still
expands the form for readable inputs. Vehicle choices use horizontal compact
cards for backend-configured pricing filters, without invented seat counts or
per-vehicle fares. Other provider filters retain their configured input types.

The map shows distinct pickup/destination markers and an outlined teal driving
polyline. Camera fitting includes returned road geometry and runs when
endpoints change, geometry first arrives or the visible map viewport resizes.
Resize fitting waits for the sheet drag to settle; normal status refreshes do
not reset manual pan/zoom. Top padding keeps endpoints below the map's service
selector and availability badge. Route geometry requests depend only on endpoint values,
not countdowns, availability polling, panel resizing or question changes.

The preview uses Google Routes `computeRoutes` with an overview encoded polyline:
https://developers.google.com/maps/documentation/routes/compute_route_directions

`BTHERE_GOOGLE_ROUTES_API_KEY` can override the existing
`BTHERE_GOOGLE_MAPS_API_KEY`. The selected key must allow Routes API usage.
No customer bearer token or booking answers are sent to Google. Only pickup and
destination coordinates are sent for geometry; no key is logged. Failure leaves
the markers and booking form usable with “Route preview unavailable”, without
drawing a straight line and claiming it is a road route. Display geometry never
changes backend pricing, matching, payment or booking distance.

Verified the configured key with one route-preview request (HTTP 200); this
did not create or modify a booking. Native emulator rendering has not been
visually inspected in this change. Regression tests exercise route layout,
dynamic questions, decoder validation, destination marker, polyline rendering
and no repeated geometry fetch on an idle timer.
