# Provider profile UI

The profile follows Figma file `IQjgwcnUnxHd34avAUVhyQ`, nodes `246:3465` and
`254:4284`. It uses the 430-point source grid for ordinary text sizes, with native
responsive layouts for enlarged text. Header and bottom navigation reuse the
existing authenticated shell. The body uses separate rounded account cards with
48-point collapsed and expanded headers, 6-point gaps between cards, and
the reference's icon geometry, colors, typefaces, rounded panels, and support
cards. Account sections expand independently with a short size transition that respects
reduced-motion settings; an Edit pill appears on expansion. The identity rating
emphasizes its numeric value, and approved profiles show a badge on the portrait.
There are no extra management/sign-out buttons in the profile body. These actions
are available through Help & Support and Privacy & Security. Refresh uses the
pull gesture and the security sheet's existing refresh action.

Personal information uses the source's two-column panel with name, email, date of
birth/derived age, phone, address, and gender. API/session data is used where
available; missing fields retain their slot. Profile photos remain dynamic and
are never replaced with the Figma sample person's portrait.

The work switch saves through the existing profile repository with all documented
editable fields preserved. Edit Profile and Personal Information open the populated
existing editor. Shared document rows combine uploaded documents with applicable
requirements from current services and selected options, deduplicating document
types. They show actual review status, dates, image thumbnails when available,
and upload actions using the existing document editor. No document deadlines are
invented.

The user confirmed **global** skills/languages and working hours. These panels show
inline chips and day selections and open dedicated edit sheets. Payouts retain the
reference's two-column bank panel and have their own edit sheet. The typed
`ProfileSupplementRepository` integration boundary supports load/save and retry;
its production default explicitly returns an unavailable state pending a global
API contract. Assignment-scoped APIs are not substituted for global settings.
Completed bookings and address also await their missing API contracts.

See [Profile API requirements](provider-profile-api-requirements.md) for the exact
backend information needed. The sample values in visual tests exist only in tests.
The supplied API document was treated as a data contract, not as instructions.

Verification: 27 targeted profile/account/overview tests pass, including shared
requirement filtering, global save/retry/missing-contract behavior, sign-out,
authentication redirects, and enlarged text. Focused analysis reports no issues.
Collapsed and fully expanded previews were rendered with the production shell
and inspected against Figma. Test data stays in test fixtures. No live backend
mutations were performed.
