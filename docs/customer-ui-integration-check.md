# Customer UI integration check

## PR validation update — 2026-11-04

The final implementation is integrated into the normal Customer entry point.
Booking cards open the redesigned full Details page directly; confirmation stays
visible until the customer chooses an action. Card confirmation goes from the
accepted-provider countdown to the documented hosted PayHere checkout. Cancelled,
expired and unmatched recovery preserves the booking draft. Services, Booking,
Details and Wallet use the updated presentation.

The PR is based on `main` and excludes the older Provider integration, temporary
PDF tools and shared-theme migration present in the local development history.
The shared design-system change is limited to loading-button contrast and its
regression test. Local configuration and generated build/screenshot files remain
untracked. The removed runtime preview environment has not been restored; `tool/`
contains standalone widget-rendering utilities only.

Validation on the final main-based PR tree:

- Customer app: **338 tests passed**.
- Shared packages: **245 tests passed**.
- Provider acceptance helper: **17 tests passed**.
- Flutter analysis for `apps/customer_app` and `packages`: **no issues**.
- Changed Dart files pass the formatting check.
- Android debug APK build: **passed** on this main-based PR tree.
- Services, Booking list and Details rendering/large-text checks: **3 passed**.
- Provider comparison: **691 passed / 30 failed** on both untouched `main` and
  the PR branch. All 30 failing test names match; there are no new failures.
- Workspace-wide analysis has one pre-existing Provider `withOpacity` deprecation
  in `service_catalog_visuals.dart`; the Customer/shared scope is clean.

Live PayHere payment and iOS on-device checkout are not covered by these checks.
The local Android debug builds and emulator UI checks are recorded in the handoff;
PR-specific build results are listed in the pull request.

Checked: 2026-11-03 (Asia/Colombo).

The offline preview environment was subsequently removed at the user's request:
its alternate entry point, gallery/sample backend, run script and dependent tests
and screenshot tools are no longer part of the project. Normal Customer UI and
production regression tests are retained. Run from the repository root:

```powershell
.\scripts\run-customer.ps1 -DeviceId emulator-5554
```

The existing `config/customer.local.json` supplies the normal API configuration.

The recent UI changes are wired into the normal Customer application, not only
the offline preview. No additional production UI wiring was needed in this audit.

## Entry points and shared presentation

| Area | Normal Customer integration |
| --- | --- |
| App entry | `lib/main.dart` starts `CustomerBootstrap` and `CustomerApp` |
| Authentication | Real auth widgets use the updated branding SVG and shared design-system button |
| Home | `/home` uses the refined service grid and recent-booking cards |
| Service catalog | `/services` uses the compact expanded option cards |
| Booking footer | Booking label and calendar/check SVGs route to `/opportunities` (internal route retained) |
| Booking list | `/opportunities` and `/bookings` use the updated list, filters, tinted cards and typography |
| Booking details | `/bookings/:jobId` uses the shared teal details page and redesigned details view |
| Provider selection | Live booking screen mounts the shared provider-results canvas and details dialog |
| Matching/acceptance | Live booking screen mounts `BookingRequestProgressScreen` |
| Payment results | Live booking controller state drives the shared success/failure screen |
| Request receipts | Live booking screen mounts the shared confirmation, pending, confirmed and closed-request widgets |
| Pending status | Visible foreground pending screen reads status every five seconds and checks immediately on resume |
| Cancellation | Live cancellation confirmation uses the redesigned dialog |
| Return to form | Cancelled/expired receipt calls the draft-preserving controller action |
| Send again | Expired receipt uses validation and the normal submit path with a fresh submission identity |
| Confirmed details | Uses the server's positive `jobId` and existing booking-details routing; no fabricated booking ID |

The normal app uses configured API repositories and secure storage. The preview
backend, fixtures and frozen scenes have been removed.

## Verification

- Normal entry-point bundle: `flutter build bundle --debug --no-pub --target=lib/main.dart` passed.
- Updated logo, both Booking SVG icons and confirmation artwork were found in the generated production-entry-point asset bundle.
- Flutter analysis: clean.
- Shared design-system suite: 24 tests passed.
- Before preview removal: all 345 Customer tests passed (`apps/customer_app/build/customer-integration-final.log`). Post-removal results are recorded in the project handoff.
- After removal: all 307 retained/new Customer tests passed (`apps/customer_app/build/customer-after-preview-removal.log`); analysis and normal `main.dart` bundle build passed again. Four receipt-action widget tests replace important checks formerly tied to the preview gallery.
- Updated one stale booking-history assertion to match the new separate service-name and booking-number labels.

This check verifies source wiring, compilation, assets and automated behavior.
It does not claim a fresh installed-device or live-backend booking/payment run.
