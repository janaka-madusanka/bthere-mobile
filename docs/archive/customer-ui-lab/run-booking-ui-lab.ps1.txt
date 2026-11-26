param(
    [string]$DeviceId = 'emulator-5554',
    [ValidateSet('ready', 'ready-code', 'in-progress', 'confirm-completion', 'completed', 'reviewed', 'payment-failed', 'payment-expired', 'cancelled', 'loading', 'error')]
    [string]$Scene = 'ready'
)

$ErrorActionPreference = 'Stop'
# Deliberately does not read customer.local.json or any credentials/API keys.
$labPreviousDebug = $env:DEBUG
$env:DEBUG = ''
Push-Location (Join-Path $PSScriptRoot '../apps/customer_app')
try {
    & flutter run --debug -d $DeviceId -t lib/main_booking_ui_lab.dart `
        --dart-define=BTHERE_BOOKING_UI_LAB=true `
        "--dart-define=BTHERE_BOOKING_UI_LAB_SCENE=$Scene"
    if ($LASTEXITCODE -ne 0) { throw 'Booking UI lab failed to launch.' }
} finally {
    Pop-Location
    $env:DEBUG = $labPreviousDebug
}
