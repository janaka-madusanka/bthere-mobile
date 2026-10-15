# Provider profile UI

The `/profile` tab follows Figma nodes `246:3465` (collapsed) and `254:4284`
(expanded) in file `IQjgwcnUnxHd34avAUVhyQ`. It reuses the authenticated shell's
header, gradient, logo, and bottom navigation. Account sections expand independently.
Figma icons are bundled in `assets/profile`; profile photos remain API supplied.

The supplied **Complete Provider Registration and Service Approval API Flow (1).pdf**
was read as the API reference. Identity, photo, verification, availability,
`averageRating`, and `totalRatings` come from GET `/providers/me/profile`.
Registered services use the existing assignments provider. Shared document rows
use the existing documents repository, including actual approval and expiry status.
No sample identity, review count, document, bank account, or booking count is seeded.

Edit Profile opens the existing populated profile editor. The work switch sends
the documented full profile PUT through the existing repository, preserving names,
market, date of birth, gender, bio, identity numbers, and photo. It blocks duplicate
saves, reloads on success, and retains the confirmed state with safe feedback on
failure. Pull-to-refresh reloads account, profile, assignments, and documents.
Sign-out confirmation and secure-session clearing use the existing controller.

Skills/languages and working hours are service-assignment settings. Their expanded
sections link to each service's existing setup editor; they are not represented as
global profile settings. The supplied API has no completed-bookings or payout
contract, so those slots explicitly show unavailable states. Help and security
cards open local guidance sheets; no support destination is invented.

Verification includes account/session regression tests, API identity and rating
rendering, section expansion, preserved fields on failed availability saves,
320-point layouts at enlarged text, and production-shell visual previews:
`test/goldens/provider_profile.png` and `provider_profile_expanded.png`.

Final checks: 22 profile/account tests passed; focused analysis of the screen and
its tests reported no issues. Both rendered previews were visually inspected.
The broader `service_first_test.dart` run had five failures in catalog/setup tests
(duplicate catalog labels, catalog navigation expectations, and sub-service
interaction tests); profile/account checks in that run passed. These unrelated
screens were not changed for this task. No live backend mutations were performed.
