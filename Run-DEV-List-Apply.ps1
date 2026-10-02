[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$approvedPlanHash = Read-Host 'Paste the approved DEV plan hash from the latest preview'
if ([string]::IsNullOrWhiteSpace($approvedPlanHash)) {
    throw 'An approved DEV plan hash is required.'
}
$secureSecret = Read-Host 'Paste the Trident-M365-Provisioner client secret' -AsSecureString
$secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)

try {
    $env:TC_PROVISIONER_CLIENT_SECRET = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)
    $env:TC_ENVIRONMENT = 'DEV'
    & (Join-Path $PSScriptRoot 'infra\provision-dev-lists.ps1') -Apply -ApprovedPlanHash $approvedPlanHash
}
finally {
    $env:TC_PROVISIONER_CLIENT_SECRET = $null
    $env:TC_ENVIRONMENT = $null
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
}

Write-Host ''
Write-Host 'DEV apply finished. Keep this window open and send a screenshot of the result to Codex.' -ForegroundColor Green
Read-Host 'Press Enter to close'
