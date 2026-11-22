# Customer UI integration check

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
