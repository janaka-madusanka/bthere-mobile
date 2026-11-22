param(
    [Parameter(Mandatory = $true)][ValidateSet('Read', 'Save', 'Forget')][string]$Mode,
    [Parameter(Mandatory = $true)][string]$ApiScope,
    [string]$StoreDirectory = (Join-Path $env:LOCALAPPDATA 'BThere\ProviderAcceptance')
)

# PSCredential CLIXML encrypts SecureString with Windows DPAPI for this user on
# this computer. Clear credentials travel only through the private child pipes.
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
try {
    $hash = [System.Security.Cryptography.SHA256]::Create()
    try {
        $scopeHash = -join ($hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($ApiScope)) | ForEach-Object { $_.ToString('x2') })
    } finally { $hash.Dispose() }
    $path = Join-Path $StoreDirectory "$scopeHash.credential.xml"
    switch ($Mode) {
        'Read' {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Write-Output 'null'; break }
            $record = Import-Clixml -LiteralPath $path
            if ($record.ApiScope -cne $ApiScope -or $record.Credential -isnot [System.Management.Automation.PSCredential]) {
                throw 'Invalid saved credential.'
            }
            @{ identifier = $record.Credential.UserName; password = $record.Credential.GetNetworkCredential().Password } | ConvertTo-Json -Compress
        }
        'Save' {
            $inputRecord = [Console]::In.ReadToEnd() | ConvertFrom-Json
            if ([string]::IsNullOrWhiteSpace($inputRecord.identifier) -or [string]::IsNullOrEmpty($inputRecord.password)) { throw 'Missing credential.' }
            $secure = New-Object System.Security.SecureString
            foreach ($character in $inputRecord.password.ToCharArray()) { $secure.AppendChar($character) }
            $secure.MakeReadOnly()
            $credential = New-Object System.Management.Automation.PSCredential ($inputRecord.identifier, $secure)
            New-Item -ItemType Directory -Path $StoreDirectory -Force | Out-Null
            $tempPath = Join-Path $StoreDirectory "$scopeHash.$([guid]::NewGuid().ToString('N')).tmp"
            try {
                [pscustomobject]@{ ApiScope = $ApiScope; Credential = $credential } | Export-Clixml -LiteralPath $tempPath -Encoding UTF8
                Move-Item -LiteralPath $tempPath -Destination $path -Force
            } finally {
                if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath }
                $inputRecord = $null
                $credential = $null
                if ($secure) { $secure.Dispose() }
                $secure = $null
            }
        }
        'Forget' {
            if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path }
        }
    }
} catch {
    # Never print imported objects, stdin, exception detail or decrypted data.
    [Console]::Error.WriteLine('Encrypted provider credential operation failed. Re-save credentials on this Windows account.')
    exit 1
}
