param(
    [Parameter(Mandatory = $true)]
    [string]$InputModel,

    [Parameter(Mandatory = $true)]
    [string]$OutputModel
)

Write-Warning "Experimental: use only for generated copies. Some legacy UPPAAL models contain encoding-sensitive declarations."

if (-not (Test-Path -LiteralPath $InputModel)) {
    throw "Input model was not found: $InputModel"
}

$outDir = Split-Path -Parent $OutputModel
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$text = Get-Content -LiteralPath $InputModel -Raw
$settings = New-Object System.Xml.XmlReaderSettings
$settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
$settings.XmlResolver = $null
$stringReader = New-Object System.IO.StringReader($text)
$reader = [System.Xml.XmlReader]::Create($stringReader, $settings)

$xml = New-Object System.Xml.XmlDocument
$xml.XmlResolver = $null
$xml.PreserveWhitespace = $true
$xml.Load($reader)

$resultNodes = @($xml.SelectNodes("//result"))
foreach ($node in $resultNodes) {
    [void]$node.ParentNode.RemoveChild($node)
}

$queryNodes = @($xml.SelectNodes("/nta/queries/query"))
foreach ($query in $queryNodes) {
    $formulaNode = $query.SelectSingleNode("formula")
    $formula = ""
    if ($formulaNode -and $formulaNode.InnerText) {
        $formula = $formulaNode.InnerText.Trim()
    }

    if (-not $formula -or $formula.StartsWith("//")) {
        [void]$query.ParentNode.RemoveChild($query)
    }
}

$writerSettings = New-Object System.Xml.XmlWriterSettings
$writerSettings.Encoding = New-Object System.Text.UTF8Encoding($false)
$writerSettings.Indent = $true
$writerSettings.NewLineChars = "`n"

$writer = [System.Xml.XmlWriter]::Create((Resolve-Path -LiteralPath (Split-Path -Parent $OutputModel)).Path + "\" + (Split-Path -Leaf $OutputModel), $writerSettings)
$xml.Save($writer)
$writer.Close()

Write-Host "Wrote clean model: $OutputModel"
