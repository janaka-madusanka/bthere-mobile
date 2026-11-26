# Retired Booking UI Lab

The standalone Customer UI Lab and its launcher were retired on 26 November 2026.
Run the real Customer app with `scripts/run-customer.ps1`.

Its scene fixtures now live under `apps/customer_app/test/support/booking_ui` for automated widget and accessibility tests only. They are not application entry points or routes.
Old launcher sources, screenshot generators and unused artwork are archived under `docs/archive/customer-ui-lab` and are excluded from Flutter application assets. The `.txt` source snapshots are historical references, not runnable scripts.

Run regression tests from `apps/customer_app` with `flutter test --no-pub`. Native branding generation remains available in `tool/generate_branding_assets.dart`.
