param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,
    [ValidateRange(1, 65535)]
    [int]$Port = 8080,
    [string]$ConfigFile = ''
)

$ErrorActionPreference = 'Stop'

# ADB reverse works with physical phones and emulators, including wireless ADB.
# Check the backend first so an absent server does not become a signup timeout.
$connection = [System.Net.Sockets.TcpClient]::new()
try {
    $pending = $connection.ConnectAsync('127.0.0.1', $Port)
    if (-not $pending.Wait(3000) -or -not $connection.Connected) {
        throw 'Connection failed.'
    }
} catch {
    throw "No local backend is reachable on port $Port. Start your API first, or supply its actual port with -Port."
} finally {
    $connection.Dispose()
}

& adb -s $DeviceId reverse "tcp:$Port" "tcp:$Port"
if ($LASTEXITCODE -ne 0) { throw 'Could not set up ADB reverse. Check adb devices.' }

Push-Location (Join-Path $PSScriptRoot '../apps/provider_app')
try {
    $providerConfig = $ConfigFile
    if ([string]::IsNullOrWhiteSpace($providerConfig)) {
        $providerConfig = Join-Path $PSScriptRoot '../config/provider.local.json'
    }
    $flutterArguments = @('run', '-d', $DeviceId)
    if (Test-Path -LiteralPath $providerConfig) {
        $resolvedConfig = (Resolve-Path -LiteralPath $providerConfig).Path
        $flutterArguments += "--dart-define-from-file=$resolvedConfig"
    } elseif (-not [string]::IsNullOrWhiteSpace($ConfigFile)) {
        throw 'The provider configuration file could not be found.'
    }
    $flutterArguments += "--dart-define=BTHERE_API_BASE_URL=http://127.0.0.1:$Port/api/v1"
    & flutter @flutterArguments
    if ($LASTEXITCODE -ne 0) { throw 'Flutter run failed.' }
} finally {
    Pop-Location
}
