param(
    [string]$DeviceId = '',
    [string]$ConfigFile = ''
)

$ErrorActionPreference = 'Stop'
$providerConfigPath = if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    Join-Path $PSScriptRoot '../config/provider.local.json'
} else { $ConfigFile }
if (-not (Test-Path -LiteralPath $providerConfigPath)) {
    throw 'Provider config is missing. Copy config/provider.example.json to config/provider.local.json and configure it first.'
}
$providerConfigPath = (Resolve-Path -LiteralPath $providerConfigPath).Path
$providerConfig = Get-Content -LiteralPath $providerConfigPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($providerConfig.BTHERE_API_BASE_URL)) {
    throw 'Set BTHERE_API_BASE_URL in the provider config.'
}
$mapsKey = [string]$providerConfig.BTHERE_GOOGLE_MAPS_API_KEY
if ($mapsKey -notmatch '^AIza[A-Za-z0-9_-]{35}$') {
    throw 'Set a valid Google Maps API key in the provider config before launching.'
}

# Windows Gradle wrappers echo all arguments when DEBUG is set. Build defines
# can include API keys, so keep wrapper tracing disabled for this launch.
$previousDebug = $env:DEBUG
$env:DEBUG = ''
Push-Location (Join-Path $PSScriptRoot '../apps/provider_app')
try {
    $flutterArguments = @('run', "--dart-define-from-file=$providerConfigPath")
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        $flutterArguments += @('-d', $DeviceId)
    }
    & flutter @flutterArguments
    if ($LASTEXITCODE -ne 0) { throw 'Provider launch failed.' }
} finally {
    Pop-Location
    $env:DEBUG = $previousDebug
}
