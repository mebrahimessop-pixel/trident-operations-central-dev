[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$secureSecret = Read-Host 'Paste the Trident-M365-Provisioner client secret' -AsSecureString
$secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)

try {
    $env:TC_PROVISIONER_CLIENT_SECRET = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)
    $env:TC_ENVIRONMENT = 'DEV'
    & (Join-Path $PSScriptRoot 'infra\provision-dev-lists.ps1')
}
finally {
    $env:TC_PROVISIONER_CLIENT_SECRET = $null
    $env:TC_ENVIRONMENT = $null
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
}

Write-Host ''
Write-Host 'Preview complete. Copy only the plan hash and summary back to Codex. Do not copy the secret.' -ForegroundColor Green
Read-Host 'Press Enter to close'
