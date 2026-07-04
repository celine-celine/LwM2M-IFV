param(
    [string]$ModelRoot = ".\LwM2M Models",
    [switch]$Detailed
)

$root = (Resolve-Path $ModelRoot).Path
$workspace = (Get-Location).Path
$rows = @()

Get-ChildItem -Recurse -File -LiteralPath $root -Filter *.xml | ForEach-Object {
    $file = $_.FullName
    $relative = $file.Replace($workspace + "\", "")

    try {
        $text = Get-Content -LiteralPath $file -Raw
        $settings = New-Object System.Xml.XmlReaderSettings
        $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
        $settings.XmlResolver = $null
        $stringReader = New-Object System.IO.StringReader($text)
        $reader = [System.Xml.XmlReader]::Create($stringReader, $settings)
        $xml = New-Object System.Xml.XmlDocument
        $xml.XmlResolver = $null
        $xml.Load($reader)
        $templates = @(
            $xml.nta.template | ForEach-Object {
                if ($_.name.'#text') {
                    $_.name.'#text'
                } elseif ($_.name) {
                    [string]$_.name
                } else {
                    "(unnamed)"
                }
            }
        )
        $queries = @($xml.nta.queries.query | ForEach-Object { $_.formula } | Where-Object { $_ })

        $rows += [pscustomobject]@{
            File = $relative
            Templates = ($templates -join ", ")
            Locations = @($xml.nta.template.location).Count
            Transitions = @($xml.nta.template.transition).Count
            Queries = $queries.Count
            Parse = "ok"
        }
    } catch {
        $message = $_.Exception.Message
        if ($_.Exception.InnerException) {
            $message = $_.Exception.InnerException.Message
        }
        $rows += [pscustomobject]@{
            File = $relative
            Templates = ""
            Locations = ""
            Transitions = ""
            Queries = ""
            Parse = $message.Split([Environment]::NewLine)[0]
        }
    }
}

if ($Detailed) {
    $rows | Format-Table -AutoSize -Wrap
} else {
    $rows |
        Select-Object File, Locations, Transitions, Queries, Parse |
        Format-Table -AutoSize -Wrap
}
