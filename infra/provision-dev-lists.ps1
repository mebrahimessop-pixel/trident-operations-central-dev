[CmdletBinding()]
param(
    [string]$TenantId = '0ce9148a-fd30-4ca7-8e88-e3d4f1cc54a0',
    [string]$ClientId = 'ff47a62f-3546-4038-be00-1bfda40d7bab',
    [string]$SiteId = 'tridentclinical.sharepoint.com,41e89a91-010c-43f2-b5da-57232ae4154f,09b6625b-4eb8-4357-bf36-2aa3777ffee6',
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\config\lists\achieve-ram-pilot.json'),
    [switch]$Apply,
    [string]$ApprovedPlanHash
)

$ErrorActionPreference = 'Stop'
if ($env:TC_ENVIRONMENT -and $env:TC_ENVIRONMENT -ne 'DEV') { throw 'This provisioner is restricted to TC_ENVIRONMENT=DEV.' }
if (-not (Test-Path -LiteralPath $ManifestPath)) { throw "Manifest not found: $ManifestPath" }
if (-not $env:TC_PROVISIONER_CLIENT_SECRET) { throw 'Set TC_PROVISIONER_CLIENT_SECRET in the current session. The value is never printed or written to disk.' }

function Get-GraphToken {
    $body = @{
        client_id = $ClientId
        client_secret = $env:TC_PROVISIONER_CLIENT_SECRET
        scope = 'https://graph.microsoft.com/.default'
        grant_type = 'client_credentials'
    }
    $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -ContentType 'application/x-www-form-urlencoded' -Body $body
    if (-not $response.access_token) { throw 'The provisioner token response did not contain an access token.' }
    return $response.access_token
}

$script:GraphHeaders = @{ Authorization = "Bearer $(Get-GraphToken)"; Accept = 'application/json' }

function Invoke-Graph {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PATCH')][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [object]$Body
    )
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            $parameters = @{ Method = $Method; Uri = $Uri; Headers = $script:GraphHeaders }
            if ($null -ne $Body) {
                $parameters.ContentType = 'application/json'
                $parameters.Body = $Body | ConvertTo-Json -Depth 20 -Compress
            }
            return Invoke-RestMethod @parameters
        }
        catch {
            $status = [int]$_.Exception.Response.StatusCode
            if (($status -eq 429 -or $status -ge 500) -and $attempt -lt 5) {
                Start-Sleep -Seconds ([math]::Min(30, [math]::Pow(2, $attempt)))
                continue
            }
            throw
        }
    }
}

function Get-AllPages {
    param([Parameter(Mandatory)][string]$Uri)
    $items = @()
    $next = $Uri
    while ($next) {
        $page = Invoke-Graph -Method GET -Uri $next
        $items += @($page.value)
        $next = $page.'@odata.nextLink'
    }
    return $items
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash($bytes)
    }
    finally {
        $sha256.Dispose()
    }
    return ([BitConverter]::ToString($hash).Replace('-', '')).ToLowerInvariant()
}

function Convert-ColumnDefinition {
    param(
        [Parameter(Mandatory)]$Column,
        [Parameter(Mandatory)][hashtable]$ListsByName
    )
    $definition = [ordered]@{
        name = [string]$Column.name
        displayName = [string]$Column.name
        required = [bool]$Column.required
        indexed = [bool]$Column.indexed
    }
    switch ([string]$Column.type) {
        'Single line text' { $definition.text = @{ allowMultipleLines = $false } }
        'Multiple lines text' { $definition.text = @{ allowMultipleLines = $true; appendChangesToExistingText = $false } }
        'Choice' {
            $choices = @([string]$Column.choicesOrLookup -split ';' | Where-Object { $_ })
            $definition.choice = @{ allowTextEntry = $false; choices = $choices; displayAs = 'dropDownMenu' }
        }
        'Date' { $definition.dateTime = @{ displayAs = 'default'; format = 'dateOnly' } }
        'Date & Time' { $definition.dateTime = @{ displayAs = 'default'; format = 'dateTime' } }
        'Person' { $definition.personOrGroup = @{ allowMultipleSelection = $false; chooseFromType = 'peopleOnly' } }
        'Yes/No' { $definition.boolean = @{} }
        'Number' { $definition.number = @{ decimalPlaces = 'automatic' } }
        'Hyperlink' { $definition.hyperlinkOrPicture = @{ isPicture = $false } }
        'Lookup' {
            $parts = @([string]$Column.choicesOrLookup -split ':', 2)
            if ($parts.Count -ne 2 -or -not $ListsByName.ContainsKey($parts[0].ToLowerInvariant())) {
                throw "Lookup target is unavailable for $($Column.name): $($Column.choicesOrLookup)"
            }
            $target = $ListsByName[$parts[0].ToLowerInvariant()]
            $definition.lookup = @{ allowMultipleValues = $false; listId = [string]$target.id; columnName = [string]$parts[1] }
        }
        default { throw "Unsupported column type: $($Column.type)" }
    }
    return $definition
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$siteSegment = [Uri]::EscapeDataString($SiteId)
$listsUri = "https://graph.microsoft.com/v1.0/sites/$siteSegment/lists"
$existingLists = @(Get-AllPages -Uri "${listsUri}?%24select=id,displayName,list&%24top=999")
$listsByName = @{}
foreach ($list in $existingLists) {
    if (-not $list.list.hidden) { $listsByName[[string]$list.displayName.ToLowerInvariant()] = $list }
}

$desiredNames = @($manifest.lists | ForEach-Object { [string]$_.name })
$missingLists = @($desiredNames | Where-Object { -not $listsByName.ContainsKey($_.ToLowerInvariant()) })
$unresolvedLookups = @(
    $manifest.lists.columns |
        Where-Object { $_.type -eq 'Lookup' } |
        ForEach-Object { ([string]$_.choicesOrLookup -split ':', 2)[0] } |
        Sort-Object -Unique |
        Where-Object {
            $target = $_.ToLowerInvariant()
            -not $listsByName.ContainsKey($target) -and -not ($desiredNames | Where-Object { $_.ToLowerInvariant() -eq $target })
        }
)

$operations = @()
foreach ($desiredList in $manifest.lists) {
    $listKey = ([string]$desiredList.name).ToLowerInvariant()
    if (-not $listsByName.ContainsKey($listKey)) {
        $operations += [ordered]@{
            action = 'create_list_and_missing_columns'
            list = [string]$desiredList.name
            condition = 'list_not_present_or_column_missing'
        }
        continue
    }

    $list = $listsByName[$listKey]
    $columnsUri = "$listsUri/$($list.id)/columns"
    $existingColumns = @(Get-AllPages -Uri "${columnsUri}?%24select=id,name,displayName,required,indexed&%24top=999")
    $columnsByName = @{}
    foreach ($existingColumn in $existingColumns) {
        $columnsByName[[string]$existingColumn.name.ToLowerInvariant()] = $existingColumn
        $columnsByName[[string]$existingColumn.displayName.ToLowerInvariant()] = $existingColumn
    }

    foreach ($desiredColumn in @($desiredList.columns | Sort-Object order)) {
        $columnKey = ([string]$desiredColumn.name).ToLowerInvariant()
        if (-not $columnsByName.ContainsKey($columnKey)) {
            $operations += [ordered]@{
                action = 'create_missing_column'
                list = [string]$desiredList.name
                column = [string]$desiredColumn.name
                condition = 'column_not_present'
            }
            continue
        }

        $existingColumn = $columnsByName[$columnKey]
        if ([bool]$existingColumn.required -ne [bool]$desiredColumn.required) {
            $operations += [ordered]@{
                action = 'update_column_required_setting'
                list = [string]$desiredList.name
                column = [string]$desiredColumn.name
                from = [bool]$existingColumn.required
                to = [bool]$desiredColumn.required
            }
        }
    }
}

$plan = [ordered]@{
    mode = 'create_if_missing'
    environment = 'DEV'
    siteId = $SiteId
    operations = @($operations)
    destructiveOperations = @()
    blockers = @($unresolvedLookups | ForEach-Object { [ordered]@{ code = 'missing_lookup_target'; list = $_ } })
    readyToApply = ($unresolvedLookups.Count -eq 0)
    requiresExplicitApproval = $true
}
$planJson = $plan | ConvertTo-Json -Depth 20 -Compress
$planHash = Get-Sha256 -Text $planJson
[pscustomobject]@{ planHash = $planHash; plan = $plan } | ConvertTo-Json -Depth 20

if (-not $Apply) { return }
if ($unresolvedLookups.Count -gt 0) { throw "Plan is blocked by unresolved lookups: $($unresolvedLookups -join ', ')" }
if (-not $ApprovedPlanHash -or $ApprovedPlanHash -ne $planHash) { throw "ApprovedPlanHash must exactly equal $planHash" }

foreach ($desiredList in $manifest.lists) {
    $key = ([string]$desiredList.name).ToLowerInvariant()
    if (-not $listsByName.ContainsKey($key)) {
        Write-Host "Creating DEV list $($desiredList.name)"
        $created = Invoke-Graph -Method POST -Uri $listsUri -Body ([ordered]@{
            displayName = [string]$desiredList.name
            description = 'Trident Operations Central DEV list. Fictitious data only.'
            list = @{ template = 'genericList' }
        })
        $listsByName[$key] = $created
    }
    $list = $listsByName[$key]
    $columnsUri = "$listsUri/$($list.id)/columns"
    $existingColumns = @(Get-AllPages -Uri "${columnsUri}?%24select=id,name,displayName,required,indexed&%24top=999")
    $columnsByName = @{}
    foreach ($column in $existingColumns) {
        $columnsByName[[string]$column.name.ToLowerInvariant()] = $column
        $columnsByName[[string]$column.displayName.ToLowerInvariant()] = $column
    }
    foreach ($column in @($desiredList.columns | Sort-Object order)) {
        $columnKey = ([string]$column.name).ToLowerInvariant()
        if ($columnsByName.ContainsKey($columnKey)) {
            $existingColumn = $columnsByName[$columnKey]
            if ([bool]$existingColumn.required -ne [bool]$column.required) {
                Write-Host "Updating required setting for $($desiredList.name).$($column.name)"
                $updatedColumn = Invoke-Graph -Method PATCH -Uri "$columnsUri/$($existingColumn.id)" -Body ([ordered]@{
                    required = [bool]$column.required
                })
                $columnsByName[$columnKey] = $updatedColumn
            }
            continue
        }
        Write-Host "Creating $($desiredList.name).$($column.name)"
        $body = Convert-ColumnDefinition -Column $column -ListsByName $listsByName
        $createdColumn = Invoke-Graph -Method POST -Uri $columnsUri -Body $body
        $columnsByName[$columnKey] = $createdColumn
    }
}

$verification = @()
foreach ($desiredList in $manifest.lists) {
    $list = $listsByName[([string]$desiredList.name).ToLowerInvariant()]
    $columns = @(Get-AllPages -Uri "$listsUri/$($list.id)/columns?%24select=name,displayName,required,indexed&%24top=999")
    $columnsByName = @{}
    foreach ($column in $columns) {
        $columnsByName[[string]$column.name.ToLowerInvariant()] = $column
        $columnsByName[[string]$column.displayName.ToLowerInvariant()] = $column
    }
    $missingColumns = @($desiredList.columns | Where-Object { -not $columnsByName.ContainsKey(([string]$_.name).ToLowerInvariant()) } | ForEach-Object name)
    $requiredSettingMismatches = @(
        $desiredList.columns |
            Where-Object {
                $columnKey = ([string]$_.name).ToLowerInvariant()
                $columnsByName.ContainsKey($columnKey) -and
                    ([bool]$columnsByName[$columnKey].required -ne [bool]$_.required)
            } |
            ForEach-Object name
    )
    $verification += [pscustomobject]@{
        list = [string]$desiredList.name
        listId = [string]$list.id
        missingColumns = $missingColumns
        requiredSettingMismatches = $requiredSettingMismatches
        passed = ($missingColumns.Count -eq 0 -and $requiredSettingMismatches.Count -eq 0)
    }
}

$failed = @($verification | Where-Object { -not $_.passed })
[pscustomobject]@{
    status = if ($failed.Count -eq 0) { 'applied_and_verified' } else { 'verification_failed' }
    environment = 'DEV'
    planHash = $planHash
    verification = $verification
    productionWritesEnabled = $false
} | ConvertTo-Json -Depth 20
if ($failed.Count -gt 0) { throw 'One or more DEV lists failed read-back verification.' }
