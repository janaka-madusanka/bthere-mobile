# Customer profile completion and editing

The supplied Customer API reference separates account registration from profile
completion. POST `/auth/register` remains exactly email/password/accountType
CUSTOMER. Email verification authenticates the account; its profile is read only
after authentication and current-user validation.

## Routing and data

GET `/customers/me/profile` returns the documented CustomerProfileResponse.
Only HTTP 404 means no saved Customer profile and opens `/profile`. Other HTTP,
transport, storage, malformed response and owner-mismatch failures remain a real
profile-loading error with retry/sign-out. A returned profile must belong to the
authenticated user. Unknown/non-ACTIVE profile status is not treated as active.
The profile controller is session-bound and ignores stale results after logout.

An ACTIVE completed profile opens `/account`, where Edit profile opens the saved
form. A successful profile PUT returns to that account screen. Market selection,
service discovery and booking remain subsequent milestones; profile completion
is not document approval or booking eligibility.

## Exact replacement payload

PUT `/customers/me/profile` sends exactly these ten properties:

- Required: firstName (100), lastName (100), addressLine1 (255), city (100),
  country (100).
- Optional nullable: addressLine2 (255), district (100), province (100),
  postalCode (20), profilePhoto (2048).

Numbers in parentheses are maximum character counts. Names/address text is
trimmed; blank optional values become null. Customer/user IDs, status and
profileCompleted never go in the request. DOB, gender and NIC are configurable
reusable requirements and are not profile fields.

Existing optional values, including the photo URL, are restored when editing
because this PUT replaces all ten fields. Failed saves retain the user's draft;
duplicate saves and fields/back navigation are blocked while saving/uploading.
No automatic write replay occurs after 401: renew credentials and ask the user
to retry. Rejected refresh returns through the existing auth gate.

## Optional photo

The native file picker selects JPG/PNG/WebP. File length is checked before a
bounded stream read; header checks select the actual MIME type. Maximum 10 MiB.
Authenticated POST `/uploads/images` sends multipart with one binary `file`
part and lets Dio generate the boundary. Only a successful 201 and valid
returned public URL updates the form's photo; the URL is submitted on profile
save. Existing photos can be retained, replaced or removed. 413 gets a readable
10 MB error. Failed/cancelled upload preserves existing field values and photo.
No identity evidence goes to this public endpoint; no bucket/prefix is guessed.
Uploaded photos are not automatically rolled back if the later profile PUT fails.

## Verification

The Customer suite covers auth-to-profile registration routing, documented GET
404 vs other errors, exact authenticated ten-key PUT, full-replacement optional
preservation, draft retry, owner/session boundaries, late result after logout,
multipart MIME/body and returned URL, disallowed/oversized files, upload 413,
write-401 no-replay, narrow large-text layout and existing email/session behavior.
Tests use fake HTTP/session state only; no live account/profile mutations.

Customer analysis and formatting are clean. Workspace analysis retains the
existing Provider withOpacity deprecation notice. Provider/shared source and
root lockfile are unchanged. Native picker interaction and deployed Customer
API availability still need manual verification; Android build alone does not
prove backend deployment. No commit, push or PR.

Final results: all 64 Customer tests passed; Customer analysis found no issues;
formatting checked 18 Dart files with no changes; the configured Customer debug
APK built successfully. The actual-font/asset preview test passed and profile
form renders were visually inspected. Screenshots are in
`apps/customer_app/build/auth-previews/customer-profile.png` and
`customer-profile-bottom.png`.

## Single profile form

All required and optional fields appear in one scrollable form, with the original
brand asset, “Let’s get to know you” heading and personalization subtitle. One Save action validates
all fields and submits the unchanged ten-field payload. Saved optional values,
photo controls, failed-save drafts and authentication routing remain supported.

Phone layout tests at 360×800, 390×844 and 430×932 verify every field exists,
the Save action is reachable, and opening the form sends no PUT. Enlarged-text
coverage verifies scrolling without overflow.

On Windows the debug build may require a process-only workaround for Kotlin
incremental cache paths spanning C: pub cache and D: project:
`GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false`.

## Reference design update

The supplied profile reference now guides the circular avatar with camera upload
action, navy heading, muted subtitle, outlined icon fields and Save and continue
action. First/last name, city/district and province/postal code appear side by
side on ordinary phones; narrow layouts and enlarged text stack these fields.
Original SVG branding, validation, photo upload/remove, saved-field restoration,
failed-save drafts, exact PUT payload and routing remain unchanged.

District, province and country remain editable text. The supplied API defines
strings but no geographic option catalogs. No fake dropdowns or Sri Lanka
default were added. Existing country values are restored when editing.

## Server-only profile photo display (21 October 2026)

Profile photos render only from the exact returned server URL. The earlier
selected-file memory preview/fallback has been removed at the user's request.
Upload bytes are read for multipart submission only; the form does not retain
them for display. The profile payload remains the returned URL, with no local
path or binary data. Upload failure/cancellation preserves the previous URL.

The avatar shows loading while the remote image is fetched. A failed server
image shows the placeholder, a readable error and Retry. Retry evicts the failed
network image and fetches the same URL without Authorization headers. Remove
clears the URL and image-load error; changing URL resets stale error state.

Debug-only diagnostics retain source=server_image and HTTP status when available,
never URL/query/signature, image bytes, credentials or personal values. The user
observed HTTP 403 on a returned public URL; this server access problem remains
visible and requires backend/image-hosting correction. No local preview masks it.
