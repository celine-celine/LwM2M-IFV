param(
    [Parameter(Mandatory = $true)]
    [string]$Model,

    [string]$Query,

    [int]$QueryIndex = -1,

    [string]$Verifyta = $env:UPPAAL_VERIFYTA
)

if (-not $Verifyta) {
    $defaultVerifyta = "C:\Program Files\UPPAAL-5.0.0\app\bin\verifyta.exe"
    if (Test-Path -LiteralPath $defaultVerifyta) {
        $Verifyta = $defaultVerifyta
    }
}

if (-not (Test-Path -LiteralPath $Verifyta)) {
    throw "verifyta.exe was not found. Set UPPAAL_VERIFYTA or pass -Verifyta."
}

if (-not (Test-Path -LiteralPath $Model)) {
    throw "Model file was not found: $Model"
}

$args = @()
if ($QueryIndex -ge 0) {
    $args += "--query-index"
    $args += $QueryIndex
}

$args += $Model

if ($Query) {
    if (-not (Test-Path -LiteralPath $Query)) {
        throw "Query file was not found: $Query"
    }
    $args += $Query
}

& $Verifyta @args
