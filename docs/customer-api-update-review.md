# Updated Customer API contract review â€” 2026-10-22

Source: supplied attachment `f278794b-464d-4c1e-b613-2e0a48ab51b1/Pasted text.txt`,
including the 21 October shared-options/combination-pricing update and 20 October
provider-filter update. Compared with the current Customer booking implementation.
This review changes no runtime behavior and does not verify deployed availability.
The document explicitly describes locally implemented APIs with deployment unverified.
Example IDs are illustrative and must not be hardcoded.

## Implementation differences

| Contract addition | Current app | Required work |
| --- | --- | --- |
| `booking-context.providerFilters` | Not parsed/rendered | Separate dynamic filter models and controls for IN choice arrays, inclusive numeric RANGE and boolean EQUALS; clear stale values on context changes |
| Search `providerFilters` | Sends language/skill filters only | Serialize enabled field IDs and typed values, respecting 50-filter/100-choice limits; never put them in booking answers |
| Candidate `providerAttributes` | Not displayed | Render known labels/values using configured metadata; do not label self-declared profile attributes as verified |
| Candidate `mapMarker` | Generic provider pin | Render backend-resolved marker asset with safe fallback; retain `profilePhoto` for cards; do not compute competing rule precedence in the client |
| Field/choice `icon` versus `mapMarkerIcon` | No new icon metadata support | Use selection/list icons separately from map assets, without distortion or recoloring |
| Shared option links | Option cache is scoped by service, booking identity includes market/service/option | Add regression cases for the same option ID under different services and link-local fields/order/status; do not globally deduplicate options |
| `POST /customers/me/bookings/quote` | No quote call; total known after create | Quote the complete final booking request after provider/payment/answer selection; show server amount/currency before confirmation and invalidate quote after edits |
| `pricingSelections` | Not sent | Separate final single string choice per pricing field, maximum 10 distinct IDs; validate each selected provider supports choices |
| `pricingSnapshot` | Raw booking data retained, snapshot not presented | Parse nullable legacy/new snapshots and show returned pricing information in review/history without recomputing or overriding server fares |

## Pricing discovery — original gap, resolved 2026-10-26

The original attachment required every distinct pricing field used by active, effective,
geographically applicable rates, rejects extra fields, and allows legacy bookings
to omit selections. It does not explicitly document a context response member or
customer-readable endpoint identifying that exact required pricing-field set and
its allowed final choices. `providerFilters` identifies searchable fields, not
necessarily pricing fields; `mapMarkerFieldId` identifies marker configuration,
not necessarily pricing configuration. A quote response's pricing snapshot is
available only after submitting a valid complete request.

The original follow-up was to ask how the client discovers these required pricing field
IDs/choices, including changes with location/time and shared service links. Do not
copy all selected search filters into pricingSelections or hardcode example IDs
145/147. IN search filters may contain several alternatives, whereas each booking
pricing selection must be one final stable string. Quote support for requests
without conditional selections can be implemented independently.

## Gender

Gender is supported through configured providerFilters and providerAttributes,
not a top-level candidate gender or arbitrary client-defined filter. Render it
only when the actual context publishes a supported field with its real ID/values.
The update gives no deployed gender field ID or concrete gender-filter example.
Separate male/female team quantities remain unsupported by this contract.

## Quote and payment semantics

Quote is read-only but validates the complete booking input, including explicit
provider selection, eligibility, schedule, addresses, answers and payment method.
It reserves neither capacity nor wallet funds and locks no price. Creation checks
again and recalculates; the final returned booking amount remains authoritative.
No quote token/expiry or price-lock property should be invented. The route
distance is a straight-line estimate, not road distance or live ETA. No additional
fee/tax breakdown is specified beyond the shown pricing snapshot parameters.
Card remains mock; quotation or PENDING creation is not payment success.

## Still missing or unverified

- Deployment of these new fields/endpoints and actual admin configuration.
- Pricing-field discovery described above.
- Automatic OPEN_REQUEST dispatch, invitations, acceptance/rejection streams and
  the FigJam 30-second cancellation flow.
- Gender-specific team quantities, live tracking/road ETA and messaging contracts.
- Production card/eZ Cash processing, automatic settlement/refunds.
- Idempotent booking creation and dedicated booking-by-ID reconciliation.

## Suggested order

1. Add contract fixtures/models and shared-option regression coverage.
2. Implement configured provider filters and candidate attributes/icons/markers.
3. Implement quote/review for documented complete requests; obtain pricing-field
   discovery clarification before enabling general conditional-pricing selection.
4. Add separate final pricing choices and booking/history snapshot presentation.
5. Verify deployed responses, then run contract/UI tests, analysis and APK build.


## Confirmed backend clarification — 2026-10-26

The supplied full context response confirms root `pricingFieldIds`. Match only these IDs to `providerFilters` for allowed stable choice values; each pricing selection is a single string, independently of multi-choice search filters. Missing metadata remains compatible with legacy contexts. Reject duplicate, unknown, non-choice or more than ten pricing IDs instead of inventing fields. Before a fresh provider search, refresh context with both `pricingLatitude` and `pricingLongitude` for the selected physical service point; ONLINE omits both. This discovers area-specific pricing without a new endpoint.

Implemented Customer behavior: backend-resolved `candidate.mapMarker.icon.url` rendering with safe pin fallback; separate final pricing controls; complete-request quote preview with returned amount/currency and available rate parameters; unchanged request reused for creation, which recalculates. Preview becomes invalid after request edits, provider/payment changes or context reload. Search has no fare, quote reserves neither capacity nor price, and no client totals are submitted. Marker rules remain server-owned, so vehicle-only markers need no client gender-based selection.

Settlement clarification: customer completion does not credit provider wallets automatically. Earnings/fees, exactly-once wallet credit and ledger history require backend settlement work. The newly mentioned PayHere flow has no supplied customer request/response contract here; existing capability-gated payment behavior is preserved rather than inventing PayHere endpoints or claiming production settlement. No Provider/Admin code or live configuration was changed.
