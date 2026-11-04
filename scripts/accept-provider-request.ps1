param(
    [int]$RequestId = 0,
    [int]$WaitSeconds = 300,
    [string]$ConfigFile = '',
    [switch]$AcceptOnArrival
)
$ErrorActionPreference = 'Stop'
if ($RequestId -lt 0) { throw 'RequestId must be positive, or omit it to enter it interactively.' }
$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
$helperArguments = @('-B', (Join-Path $PSScriptRoot 'accept-provider-request.py'), '--wait-seconds', "$WaitSeconds")
if ($pythonCommand -and $pythonCommand.Source -notmatch 'WindowsApps') {
    $pythonExecutable = $pythonCommand.Source
} else {
    $launcherCommand = Get-Command py -ErrorAction SilentlyContinue
    if (-not $launcherCommand) { throw 'Install Python 3 or add python to PATH.' }
    $pythonExecutable = $launcherCommand.Source
    $helperArguments = @('-3') + $helperArguments
}
if ($RequestId -gt 0) { $helperArguments += @('--request-id', "$RequestId") }
if ($ConfigFile) { $helperArguments += @('--config', $ConfigFile) }
if ($AcceptOnArrival) { $helperArguments += '--accept-on-arrival' }
& $pythonExecutable @helperArguments
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Helper stopped. No automatic acceptance retry was sent. See the error above.' -ForegroundColor Yellow
}
