param(
    [Parameter(Mandatory = $true)]
    [string]$Profile,

    [int]$QueryIndex = -1,

    [string]$Verifyta = $env:UPPAAL_VERIFYTA
)

if (-not (Test-Path -LiteralPath $Profile)) {
    throw "Profile file was not found: $Profile"
}

$profileObject = Get-Content -LiteralPath $Profile -Raw | ConvertFrom-Json
if (-not $profileObject.model) {
    throw "Profile does not define a model path: $Profile"
}

$modelPath = Join-Path (Get-Location) $profileObject.model
if (-not (Test-Path -LiteralPath $modelPath)) {
    throw "Model from profile was not found: $modelPath"
}

if ($QueryIndex -lt 0) {
    if ($profileObject.primary_query -and $profileObject.queries) {
        $primaryName = [string]$profileObject.primary_query
        $queryValue = $profileObject.queries.$primaryName
        if ($null -ne $queryValue) {
            $QueryIndex = [int]$queryValue
        }
    }
}

if ($QueryIndex -lt 0) {
    $QueryIndex = 0
}

Write-Host "Profile: $($profileObject.profile_id)"
Write-Host "Procedure: $($profileObject.procedure)"
Write-Host "Model: $($profileObject.model)"
Write-Host "Query index: $QueryIndex"

$args = @(
    "-ExecutionPolicy", "Bypass",
    "-File", ".\tools\run_verifyta.ps1",
    "-Model", $modelPath,
    "-QueryIndex", $QueryIndex
)

if ($Verifyta) {
    $args += "-Verifyta"
    $args += $Verifyta
}

powershell @args
