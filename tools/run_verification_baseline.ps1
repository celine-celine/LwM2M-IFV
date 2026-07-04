param(
    [string]$ModelRoot = ".\LwM2M Models",
    [string]$OutFile = ".\results\verification_baseline.tsv",
    [string]$Verifyta = $env:UPPAAL_VERIFYTA,
    [int]$TimeoutSeconds = 60,
    [switch]$IncludeSmc
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

$outDir = Split-Path -Parent $OutFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

function Read-UppaalXml($Path) {
    $text = Get-Content -LiteralPath $Path -Raw
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $settings.XmlResolver = $null
    $stringReader = New-Object System.IO.StringReader($text)
    $reader = [System.Xml.XmlReader]::Create($stringReader, $settings)
    $xml = New-Object System.Xml.XmlDocument
    $xml.XmlResolver = $null
    $xml.Load($reader)
    return $xml
}

function Invoke-VerifytaQuery($Model, $Index) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Verifyta
    $psi.Arguments = "--query-index $Index `"$Model`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { $process.Kill() } catch {}
        return [pscustomobject]@{
            Status = "timeout"
            ExitCode = ""
            Output = ""
        }
    }

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $combined = ($stdout + "`n" + $stderr).Trim()

    $status = "unknown"
    if ($process.ExitCode -ne 0) {
        $status = "error"
    } elseif ($combined -match "Formula is satisfied") {
        $status = "satisfied"
    } elseif ($combined -match "Formula is NOT satisfied") {
        $status = "not_satisfied"
    } elseif ($combined -match "Pr\[[^\r\n]+" -or $combined -match "95% CI" -or $combined -match "Formula is satisfied with") {
        $status = "quantity"
    }

    return [pscustomobject]@{
        Status = $status
        ExitCode = $process.ExitCode
        Output = ($combined -replace "`r?`n", " " -replace "`t", " ")
    }
}

$workspace = (Get-Location).Path
$rows = @()

Get-ChildItem -Recurse -File -LiteralPath $ModelRoot -Filter *.xml | ForEach-Object {
    $model = $_.FullName
    $relative = $model.Replace($workspace + "\", "")

    try {
        $xml = Read-UppaalXml $model
        $queryNodes = @($xml.nta.queries.query)

        $verifyIndex = 0
        for ($i = 0; $i -lt $queryNodes.Count; $i++) {
            $formula = [string]$queryNodes[$i].formula
            $trimmed = $formula.Trim()

            if (-not $trimmed -or $trimmed.StartsWith("//")) {
                continue
            }

            $isSmc = $trimmed.StartsWith("Pr[") -or $trimmed.StartsWith("E[") -or $trimmed.StartsWith("simulate") -or $trimmed.StartsWith("N[")
            if ($isSmc -and -not $IncludeSmc) {
                $rows += [pscustomobject]@{
                    Model = $relative
                    XmlQueryIndex = $i
                    VerifytaQueryIndex = $verifyIndex
                    Kind = "smc"
                    Status = "skipped"
                    ExitCode = ""
                    Formula = $trimmed
                }
                $verifyIndex++
                continue
            }

            $kind = if ($isSmc) { "smc" } else { "symbolic" }
            $result = Invoke-VerifytaQuery -Model $model -Index $verifyIndex
            $rows += [pscustomobject]@{
                Model = $relative
                XmlQueryIndex = $i
                VerifytaQueryIndex = $verifyIndex
                Kind = $kind
                Status = $result.Status
                ExitCode = $result.ExitCode
                Formula = $trimmed
            }
            $verifyIndex++
        }
    } catch {
        $rows += [pscustomobject]@{
            Model = $relative
            XmlQueryIndex = ""
            VerifytaQueryIndex = ""
            Kind = "parse"
            Status = "error"
            ExitCode = ""
            Formula = $_.Exception.Message
        }
    }
}

$rows | Export-Csv -Path $OutFile -Delimiter "`t" -NoTypeInformation -Encoding UTF8
$rows | Group-Object Kind, Status | Select-Object Name, Count | Format-Table -AutoSize
Write-Host "Wrote $OutFile"
