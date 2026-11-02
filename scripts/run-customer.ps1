param(
    [string]$ConfigFile = '',
    [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    $ConfigFile = Join-Path $PSScriptRoot '../config/customer.local.json'
}
if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
    throw 'Customer config not found. Copy config/customer.example.json to config/customer.local.json and edit its values.'
}
$resolvedConfig = (Resolve-Path -LiteralPath $ConfigFile).Path
$configuration = Get-Content -LiteralPath $resolvedConfig -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($configuration.BTHERE_API_BASE_URL)) {
    throw 'Customer config must contain BTHERE_API_BASE_URL.'
}
$flutterArguments = @('run', "--dart-define-from-file=$resolvedConfig")
if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
    $flutterArguments += @('-d', $DeviceId)
}
Push-Location (Join-Path $PSScriptRoot '../apps/customer_app')
try {
    & flutter @flutterArguments
    if ($LASTEXITCODE -ne 0) { throw 'Customer Flutter run failed.' }
} finally {
    Pop-Location
}
