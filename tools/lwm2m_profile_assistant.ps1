param(
    [string]$Requirement,

    [string]$Config,

    [string]$OutConfig,

    [switch]$DraftOnly,

    [switch]$DraftPrompt,

    [switch]$UseLLM,

    [switch]$ListLLMModels,

    [switch]$Run,

    [switch]$ValidateOnly,

    [switch]$FullReport,

    [string]$Catalog = ".\framework\catalog\profile-routing.json",

    [string]$TemplateCatalog = ".\framework\catalog\profile-templates.json",

    [string]$ReportDir = ".\framework\generated\reports",

    [string]$LLMBaseUrl = "https://dashscope.aliyuncs.com/compatible-mode/v1",

    [string]$LLMModel = "deepseek-v4-pro",

    [string]$LLMApiKeyEnv = "DASHSCOPE_API_KEY",

    [int]$LLMTimeoutSec = 120,

    [string]$Verifyta = $env:UPPAAL_VERIFYTA
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Resolve-RepoPath $Path
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "JSON file was not found: $resolved"
    }
    return Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
}

function ConvertTo-CompactJson {
    param([Parameter(Mandatory = $true)]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 50 -Compress)
}

function Get-EnvironmentValue {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [System.Environment]::GetEnvironmentVariable($Name, "Process")
}

function Get-LLMApiKey {
    param([Parameter(Mandatory = $true)][string]$PreferredEnv)

    $candidateNames = @($PreferredEnv, "BAILIAN_API_KEY", "DASHSCOPE_API_KEY", "ALIYUN_BAILIAN_API_KEY") | Select-Object -Unique
    foreach ($name in $candidateNames) {
        $value = Get-EnvironmentValue -Name $name
        if ($value) {
            return [pscustomobject]@{
                name = $name
                value = $value
            }
        }
    }

    throw "No LLM API key found. Set one environment variable, for example: `$env:DASHSCOPE_API_KEY = '<your-key>'"
}

function Get-JsonFromLLMText {
    param([Parameter(Mandatory = $true)][string]$Text)

    $trimmed = $Text.Trim()
    $fence = ([string][char]96) * 3
    if ($trimmed.StartsWith($fence)) {
        $trimmed = $trimmed -replace '(?s)^```(?:json)?\s*', ""
        $trimmed = $trimmed -replace '(?s)\s*```$', ""
        $trimmed = $trimmed.Trim()
    }

    try {
        return $trimmed | ConvertFrom-Json
    } catch {
        $firstBrace = $trimmed.IndexOf("{")
        $lastBrace = $trimmed.LastIndexOf("}")
        if ($firstBrace -ge 0 -and $lastBrace -gt $firstBrace) {
            $jsonSlice = $trimmed.Substring($firstBrace, $lastBrace - $firstBrace + 1)
            return $jsonSlice | ConvertFrom-Json
        }
        throw "LLM response was not valid JSON: $($_.Exception.Message)"
    }
}

function Get-PropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-ProfileInstances {
    param([Parameter(Mandatory = $true)]$Draft)

    if ($Draft.profile_instances -and @($Draft.profile_instances).Count -gt 0) {
        return @($Draft.profile_instances)
    }

    $instances = @()
    foreach ($profileNameValue in $Draft.selected_profiles) {
        $profileName = [string]$profileNameValue
        $queries = @()
        if ($Draft.query_selection) {
            foreach ($selection in $Draft.query_selection) {
                if ([string]$selection.profile -eq $profileName) {
                    $queries = @($selection.queries)
                }
            }
        }
        $instances += [pscustomobject][ordered]@{
            template = $null
            profile = $profileName
            queries = $queries
            parameters = $Draft.parameters
        }
    }

    return $instances
}

function Get-SelectedProfileNames {
    param([Parameter(Mandatory = $true)]$Draft)

    $names = @()
    foreach ($instance in (Get-ProfileInstances -Draft $Draft)) {
        $profileName = [string]$instance.profile
        if ($names -notcontains $profileName) {
            $names += $profileName
        }
    }
    return $names
}

function Get-DraftIntentIds {
    param([Parameter(Mandatory = $true)]$Draft)

    $intentIds = @()
    if ($Draft.analysis -and $Draft.analysis.intent) {
        $intentIds += [string]$Draft.analysis.intent
    }
    if ($Draft.analysis -and $Draft.analysis.intents) {
        foreach ($intentValue in $Draft.analysis.intents) {
            $intentId = [string]$intentValue
            if ($intentIds -notcontains $intentId) {
                $intentIds += $intentId
            }
        }
    }
    return $intentIds
}

function Get-QueryNamesForProfile {
    param(
        [Parameter(Mandatory = $true)]$Draft,
        [Parameter(Mandatory = $true)][string]$ProfileName,
        [Parameter(Mandatory = $true)]$ProfileObject
    )

    $queryNames = @()
    foreach ($instance in (Get-ProfileInstances -Draft $Draft)) {
        if ([string]$instance.profile -eq $ProfileName -and $instance.queries -and @($instance.queries).Count -gt 0) {
            foreach ($queryNameValue in @($instance.queries)) {
                $queryName = [string]$queryNameValue
                if ($queryNames -notcontains $queryName) {
                    $queryNames += $queryName
                }
            }
        }
    }

    if ($queryNames.Count -gt 0) {
        return $queryNames
    }

    if ($Draft.query_selection) {
        foreach ($selection in $Draft.query_selection) {
            if ([string]$selection.profile -eq $ProfileName) {
                foreach ($queryNameValue in @($selection.queries)) {
                    $queryName = [string]$queryNameValue
                    if ($queryNames -notcontains $queryName) {
                        $queryNames += $queryName
                    }
                }
            }
        }
    }

    if ($queryNames.Count -gt 0) {
        return $queryNames
    }

    if ($ProfileObject.primary_query) {
        return @([string]$ProfileObject.primary_query)
    }

    $queryProperties = @($ProfileObject.queries.PSObject.Properties)
    if ($queryProperties.Count -eq 0) {
        throw "Profile has no query list: $ProfileName"
    }

    return @([string]$queryProperties[0].Name)
}

function Get-MergedQuerySets {
    param([Parameter(Mandatory = $true)]$Draft)

    $merged = @()
    foreach ($profileName in (Get-SelectedProfileNames -Draft $Draft)) {
        $profilePath = Join-Path $repoRoot "framework\profiles\$profileName.json"
        if (Test-Path -LiteralPath $profilePath) {
            $profileObject = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
            $queries = Get-QueryNamesForProfile -Draft $Draft -ProfileName $profileName -ProfileObject $profileObject
        } else {
            $queries = @()
        }
        $merged += [pscustomobject][ordered]@{
            profile = $profileName
            queries = @($queries)
        }
    }
    return $merged
}

function Get-RouteScore {
    param(
        [Parameter(Mandatory = $true)]$Route,
        [Parameter(Mandatory = $true)][string]$Text
    )

    $score = 0
    $lowerText = $Text.ToLowerInvariant()
    foreach ($keyword in $Route.keywords) {
        $needle = ([string]$keyword).ToLowerInvariant()
        if ($lowerText.Contains($needle)) {
            $score += 1
        }
    }
    return $score
}

function New-DraftFromRoute {
    param(
        [Parameter(Mandatory = $true)]$Route,
        [Parameter(Mandatory = $true)][string]$SourceText,
        $TemplateCatalogObject
    )

    $id = ([string]$Route.intent).ToLowerInvariant() -replace "[^a-z0-9]+", "_"
    $id = $id.Trim("_")

    $profileInstances = @()
    foreach ($selection in $Route.query_selection) {
        $profileName = [string]$selection.profile
        $templateId = $null
        if ($TemplateCatalogObject -and $TemplateCatalogObject.templates) {
            foreach ($template in $TemplateCatalogObject.templates) {
                if (@($template.supported_intents) -contains [string]$Route.intent -and @($template.executable_profiles) -contains $profileName) {
                    $templateId = [string]$template.template_id
                    break
                }
            }
        }
        $profileInstances += [pscustomobject][ordered]@{
            template = $templateId
            profile = $profileName
            queries = @($selection.queries)
            parameters = $Route.parameters
        }
    }

    $payload = [ordered]@{
        requirement_id = "${id}_draft"
        source_text = $SourceText.Trim()
        analysis = [ordered]@{
            mode = [string]$Route.mode
            intent = [string]$Route.intent
            intents = @([string]$Route.intent)
        }
        scenario = [ordered]@{
            domain = "shop_floor_lwm2m"
            note = "Prototype-generated scenario. Refine this field before using it in a manuscript case study."
        }
        coverage_status = "fully_supported"
        supported_requirements = @($Route.summary)
        unsupported_requirements = @()
        clarification_questions = @()
        assumptions = @("Default parameters from the matched route are used where the requirement is underspecified.")
        profile_instances = $profileInstances
        selected_profiles = @($Route.selected_profiles)
        query_selection = @($Route.query_selection)
        parameters = $Route.parameters
        assistant_notes = @(
            "This draft was generated by deterministic catalog routing, not by an LLM API.",
            "UPPAAL verification results must be produced separately with -Run."
        )
    }

    return [pscustomobject]$payload
}

function Find-BestRoute {
    param(
        [Parameter(Mandatory = $true)]$CatalogObject,
        [Parameter(Mandatory = $true)][string]$SourceText
    )

    $bestRoute = $null
    $bestScore = 0
    foreach ($route in $CatalogObject.routes) {
        $score = Get-RouteScore -Route $route -Text $SourceText
        if ($score -gt $bestScore) {
            $bestScore = $score
            $bestRoute = $route
        }
    }

    if ($null -eq $bestRoute) {
        throw "No catalog route matched the requirement. Add keywords or provide -Config."
    }

    return [pscustomobject]@{
        route = $bestRoute
        score = $bestScore
    }
}

function Test-Draft {
    param(
        [Parameter(Mandatory = $true)]$Draft,
        $CatalogObject,
        $TemplateCatalogObject
    )

    if (-not $Draft.requirement_id) {
        throw "Draft is missing requirement_id."
    }
    if (-not $Draft.analysis -or -not $Draft.analysis.mode -or -not $Draft.analysis.intent) {
        throw "Draft is missing analysis.mode or analysis.intent."
    }
    $profileInstances = @(Get-ProfileInstances -Draft $Draft)
    if ($profileInstances.Count -eq 0) {
        throw "Draft must define selected_profiles/query_selection or profile_instances."
    }

    if (-not $CatalogObject) {
        return
    }

    $allowedModes = @{}
    $allowedIntents = @{}
    $profileNames = @{}
    foreach ($route in $CatalogObject.routes) {
        $allowedModes[[string]$route.mode] = $true
        $allowedIntents[[string]$route.intent] = $true
        foreach ($profileNameValue in $route.selected_profiles) {
            $profileNames[[string]$profileNameValue] = $true
        }
    }

    $draftMode = [string]$Draft.analysis.mode
    $draftIntent = [string]$Draft.analysis.intent
    if (-not $allowedModes.ContainsKey($draftMode)) {
        throw "Draft analysis.mode must be one of: $(@($allowedModes.Keys) -join ', ')"
    }
    if (-not $allowedIntents.ContainsKey($draftIntent)) {
        throw "Draft analysis.intent must be one of the catalog intent ids: $(@($allowedIntents.Keys) -join ', ')"
    }

    $draftIntentIds = @(Get-DraftIntentIds -Draft $Draft)
    foreach ($intentId in $draftIntentIds) {
        if (-not $allowedIntents.ContainsKey($intentId)) {
            throw "Draft analysis.intents contains unknown catalog intent id: $intentId"
        }
    }

    $allowedCoverage = @("fully_supported", "partially_supported", "unsupported", "ambiguous")
    $coverageStatus = "fully_supported"
    if ($Draft.coverage_status) {
        $coverageStatus = [string]$Draft.coverage_status
    }
    if ($allowedCoverage -notcontains $coverageStatus) {
        throw "Draft coverage_status must be one of: $($allowedCoverage -join ', ')"
    }

    $templateById = @{}
    if ($TemplateCatalogObject -and $TemplateCatalogObject.templates) {
        foreach ($template in $TemplateCatalogObject.templates) {
            $templateById[[string]$template.template_id] = $template
        }
    }

    foreach ($instance in $profileInstances) {
        $profileName = [string]$instance.profile
        if (-not $profileNames.ContainsKey($profileName)) {
            throw "Draft selects unknown or non-routable profile: $profileName"
        }

        $profilePath = Join-Path $repoRoot "framework\profiles\$profileName.json"
        if (-not (Test-Path -LiteralPath $profilePath)) {
            throw "Draft selects missing profile file: $profilePath"
        }

        if ($instance.template) {
            $templateId = [string]$instance.template
            if (-not $templateById.ContainsKey($templateId)) {
                throw "Draft references unknown profile template: $templateId"
            }
            $templateObject = $templateById[$templateId]

            $candidateInstanceIntents = @()
            if ($instance.intent) {
                $instanceIntent = [string]$instance.intent
                if (-not $allowedIntents.ContainsKey($instanceIntent)) {
                    throw "Profile instance for '$profileName' references unknown intent id: $instanceIntent"
                }
                $candidateInstanceIntents += $instanceIntent
            } else {
                $candidateInstanceIntents += $draftIntentIds
            }

            $templateSupportsAtLeastOneIntent = $false
            foreach ($intentId in $candidateInstanceIntents) {
                if (@($templateObject.supported_intents) -contains $intentId) {
                    $templateSupportsAtLeastOneIntent = $true
                    break
                }
            }
            if (-not $templateSupportsAtLeastOneIntent) {
                throw "Template '$templateId' does not support any covered intent for profile '$profileName'. Covered intents: $($draftIntentIds -join ', ')"
            }
            if (@($templateObject.executable_profiles) -notcontains $profileName) {
                throw "Template '$templateId' cannot instantiate profile '$profileName'."
            }
        }

        $profileObject = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
        foreach ($queryNameValue in @($instance.queries)) {
            $queryName = [string]$queryNameValue
            if (-not $profileObject.queries.PSObject.Properties[$queryName]) {
                throw "Draft references unknown query '$queryName' for profile '$profileName'."
            }
        }
    }
}

function Invoke-ProfileQuery {
    param(
        [Parameter(Mandatory = $true)]$ProfileName,
        [Parameter(Mandatory = $true)]$QueryName,
        [Parameter(Mandatory = $true)]$ProfileObject,
        [string]$VerifytaPath
    )

    $queryIndexValue = Get-PropertyValue -Object $ProfileObject.queries -Name $QueryName
    if ($null -eq $queryIndexValue) {
        throw "Query '$QueryName' is not defined by profile '$ProfileName'."
    }

    $queryIndex = [int]$queryIndexValue
    $modelPath = Resolve-RepoPath ([string]$ProfileObject.model)
    if (-not (Test-Path -LiteralPath $modelPath)) {
        throw "Model from profile '$ProfileName' was not found: $modelPath"
    }

    $runnerPath = Join-Path $repoRoot "tools\run_verifyta.ps1"
    $arguments = @(
        "-ExecutionPolicy", "Bypass",
        "-File", $runnerPath,
        "-Model", $modelPath,
        "-QueryIndex", $queryIndex
    )

    if ($VerifytaPath) {
        $arguments += "-Verifyta"
        $arguments += $VerifytaPath
    }

    $started = Get-Date
    $outputLines = & powershell @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $finished = Get-Date
    $outputText = ($outputLines | Out-String).Trim()

    $status = "UNKNOWN"
    if ($exitCode -ne 0) {
        $status = "ERROR"
    } elseif ($outputText -match "(?i)formula is satisfied|property is satisfied") {
        $status = "SAT"
    } elseif ($outputText -match "(?i)formula is not satisfied|property is not satisfied|not satisfied") {
        $status = "NOT_SAT"
    } elseif ($outputText -match "(?i)confidence|probability|Pr\(|E\(") {
        $status = "SMC_COMPLETED"
    } else {
        $status = "COMPLETED"
    }

    $tail = @($outputLines | Select-Object -Last 12)

    return [pscustomobject][ordered]@{
        profile = $ProfileName
        model = [string]$ProfileObject.model
        query = $QueryName
        query_index = $queryIndex
        status = $status
        exit_code = $exitCode
        started_at = $started.ToString("o")
        finished_at = $finished.ToString("o")
        output_tail = $tail
    }
}

function Write-RunSummary {
    param(
        [Parameter(Mandatory = $true)]$Report,
        [Parameter(Mandatory = $true)][string]$ReportPath
    )

    $total = @($Report.results).Count
    $sat = @($Report.results | Where-Object { $_.status -eq "SAT" }).Count
    $notSat = @($Report.results | Where-Object { $_.status -eq "NOT_SAT" }).Count
    $errors = @($Report.results | Where-Object { $_.status -eq "ERROR" -or $_.status -eq "UNKNOWN" }).Count
    $smcCompleted = @($Report.results | Where-Object { $_.status -eq "SMC_COMPLETED" -or $_.status -eq "COMPLETED" }).Count

    Write-Host ""
    Write-Host "Verification summary"
    Write-Host "--------------------"
    Write-Host "Requirement : $($Report.requirement_id)"
    Write-Host "Mode        : $($Report.analysis.mode)"
    Write-Host "Intent      : $($Report.analysis.intent)"
    if ($Report.analysis.intents) {
        Write-Host "Intents     : $(@($Report.analysis.intents) -join ', ')"
    }
    Write-Host "Coverage    : $($Report.coverage_status)"
    Write-Host "Accepted    : $($Report.accepted)"
    Write-Host "Completed   : $($Report.verification_completed)"
    Write-Host "Profiles    : $(@($Report.selected_profiles) -join ', ')"
    Write-Host "Queries     : $total total, $sat SAT, $notSat NOT_SAT, $smcCompleted completed/SMC, $errors error"

    if (@($Report.not_satisfied_queries).Count -gt 0) {
        Write-Host "Not SAT     : $(@($Report.not_satisfied_queries) -join ', ')"
    }
    if (@($Report.unsupported_requirements).Count -gt 0) {
        Write-Host "Unsupported : $(@($Report.unsupported_requirements | ForEach-Object { $_.text }) -join '; ')"
    }
    if (@($Report.assumptions).Count -gt 0) {
        Write-Host "Assumptions : $(@($Report.assumptions) -join '; ')"
    }

    Write-Host "Report file : $ReportPath"
    Write-Host ""
    Write-Host "Per-query results"
    foreach ($result in $Report.results) {
        Write-Host ("  [{0}] {1} :: {2} (q{3})" -f $result.status, $result.profile, $result.query, $result.query_index)
    }
}

function Write-DraftValidationSummary {
    param([Parameter(Mandatory = $true)]$Draft)

    Write-Host "Draft validation summary"
    Write-Host "------------------------"
    Write-Host "Requirement : $($Draft.requirement_id)"
    Write-Host "Mode        : $($Draft.analysis.mode)"
    Write-Host "Intent      : $($Draft.analysis.intent)"
    if ($Draft.analysis.intents) {
        Write-Host "Intents     : $(@($Draft.analysis.intents) -join ', ')"
    }
    $coverageStatus = "fully_supported"
    if ($Draft.coverage_status) {
        $coverageStatus = [string]$Draft.coverage_status
    }
    Write-Host "Coverage    : $coverageStatus"
    Write-Host "Profiles    : $(@(Get-SelectedProfileNames -Draft $Draft) -join ', ')"
    Write-Host "Profile instances:"
    foreach ($instance in (Get-ProfileInstances -Draft $Draft)) {
        $templateText = "legacy"
        if ($instance.template) {
            $templateText = [string]$instance.template
        }
        Write-Host "  $templateText -> $($instance.profile): $(@($instance.queries) -join ', ')"
    }
    Write-Host "Merged query sets:"
    foreach ($merged in (Get-MergedQuerySets -Draft $Draft)) {
        Write-Host "  $($merged.profile): $(@($merged.queries) -join ', ')"
    }
    Write-Host "Status      : valid against local catalog"
}

function New-DraftPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$SourceText,
        [Parameter(Mandatory = $true)]$CatalogObject,
        [Parameter(Mandatory = $true)]$SchemaObject,
        [Parameter(Mandatory = $true)]$TemplateCatalogObject
    )

    $allowedRoutes = @()
    foreach ($route in $CatalogObject.routes) {
        $allowedRoutes += [ordered]@{
            intent = [string]$route.intent
            mode = [string]$route.mode
            summary = [string]$route.summary
            selected_profiles = @($route.selected_profiles)
            query_selection = @($route.query_selection)
            parameters = $route.parameters
        }
    }

    $allowedProfiles = @()
    foreach ($route in $CatalogObject.routes) {
        foreach ($profileNameValue in $route.selected_profiles) {
            $profileName = [string]$profileNameValue
            if ($allowedProfiles -notcontains $profileName) {
                $profilePath = Join-Path $repoRoot "framework\profiles\$profileName.json"
                $profileObject = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
                $allowedProfiles += $profileName
            }
        }
    }

    $profileDetails = @()
    foreach ($profileName in $allowedProfiles) {
        $profilePath = Join-Path $repoRoot "framework\profiles\$profileName.json"
        $profileObject = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
        $profileDetails += [ordered]@{
            profile = $profileName
            procedure = [string]$profileObject.procedure
            description = [string]$profileObject.description
            queries = @($profileObject.queries.PSObject.Properties.Name)
            primary_query = [string]$profileObject.primary_query
        }
    }

    $schemaJson = ConvertTo-CompactJson -InputObject $SchemaObject
    $routesJson = ConvertTo-CompactJson -InputObject $allowedRoutes
    $profilesJson = ConvertTo-CompactJson -InputObject $profileDetails
    $templatesJson = ConvertTo-CompactJson -InputObject $TemplateCatalogObject

    return @"
You are generating a configuration draft for the LwM2M-IFV Profile Assistant.

Task:
Map the natural-language shop-floor requirement to one or more existing verification profiles.

Strict rules:
1. Output valid JSON only. Do not use Markdown fences.
2. Do not invent profile names, query names, model names, parameters, predicates, or verification results.
3. Select profiles and queries only from the allowed catalog below.
4. The JSON must follow the draft schema below.
5. Keep `source_text` semantically identical to the user requirement.
6. Use analysis.mode only from: qualitative_security, quantitative_reliability, industrial_policy.
7. Use analysis.intent only from the intent ids in Allowed route templates. Do not write a free-form sentence in analysis.intent.
8. For combined requirements, set analysis.intent to the primary intent and set analysis.intents to all covered intent ids.
9. Use coverage_status only from: fully_supported, partially_supported, unsupported, ambiguous.
10. First choose profile templates, then instantiate executable profiles from those templates.
11. Fill profile_instances with template, intent, profile, queries, and any template parameters used.
12. The intent field inside each profile_instances item should be the catalog intent supported by that template instance.
13. If a requirement is only partly covered, set coverage_status to partially_supported and list unsupported_requirements.
14. If no existing template supports the core requirement, set coverage_status to unsupported and do not invent profiles.
15. If the requirement is too vague to choose a template, set coverage_status to ambiguous and add clarification_questions.
16. Do not claim that a property is verified. Verification will be performed later by UPPAAL.
17. Include a short assistant_notes array explaining why the selected templates/profiles were chosen.

Natural-language requirement:
---
$($SourceText.Trim())
---

Draft schema:
$schemaJson

Allowed route templates:
$routesJson

Allowed profile templates:
$templatesJson

Allowed profile/query catalog:
$profilesJson

Return JSON with these top-level fields:
- requirement_id
- source_text
- analysis
- scenario
- coverage_status
- supported_requirements
- unsupported_requirements
- clarification_questions
- assumptions
- profile_instances
- selected_profiles
- query_selection
- parameters
- assistant_notes
"@
}

function Invoke-LLMDraft {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model,
        [Parameter(Mandatory = $true)][string]$ApiKeyEnv,
        [Parameter(Mandatory = $true)][int]$TimeoutSec
    )

    $apiKey = Get-LLMApiKey -PreferredEnv $ApiKeyEnv
    $endpoint = $BaseUrl.TrimEnd("/")
    if (-not $endpoint.EndsWith("/chat/completions")) {
        $endpoint = "$endpoint/chat/completions"
    }

    $body = [ordered]@{
        model = $Model
        messages = @(
            [ordered]@{
                role = "system"
                content = "You are a cautious configuration generator. Return valid JSON only. Never invent verification results."
            },
            [ordered]@{
                role = "user"
                content = $Prompt
            }
        )
        temperature = 0.1
        stream = $false
    }

    $headers = @{
        "Authorization" = "Bearer $($apiKey.value)"
        "Content-Type" = "application/json"
    }

    Write-Host "Calling LLM model '$Model' via OpenAI-compatible endpoint..."
    $response = Invoke-RestMethod `
        -Method Post `
        -Uri $endpoint `
        -Headers $headers `
        -Body ($body | ConvertTo-Json -Depth 20) `
        -ContentType "application/json" `
        -TimeoutSec $TimeoutSec

    if (-not $response.choices -or @($response.choices).Count -eq 0) {
        throw "LLM response did not contain choices."
    }

    $content = [string]$response.choices[0].message.content
    if (-not $content) {
        throw "LLM response did not contain message.content."
    }

    return Get-JsonFromLLMText -Text $content
}

function Invoke-LLMModelList {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$ApiKeyEnv,
        [Parameter(Mandatory = $true)][int]$TimeoutSec
    )

    $apiKey = Get-LLMApiKey -PreferredEnv $ApiKeyEnv
    $endpoint = $BaseUrl.TrimEnd("/")
    if ($endpoint.EndsWith("/chat/completions")) {
        $endpoint = $endpoint.Substring(0, $endpoint.Length - "/chat/completions".Length)
    }
    $endpoint = "$endpoint/models"

    $headers = @{
        "Authorization" = "Bearer $($apiKey.value)"
        "Content-Type" = "application/json"
    }

    $response = Invoke-RestMethod `
        -Method Get `
        -Uri $endpoint `
        -Headers $headers `
        -TimeoutSec $TimeoutSec

    if ($response.data) {
        Write-Host "Available models:"
        foreach ($model in $response.data) {
            Write-Host "  $($model.id)"
        }
    } else {
        $response | ConvertTo-Json -Depth 20
    }
}

$catalogObject = Read-JsonFile -Path $Catalog
$templateCatalogObject = Read-JsonFile -Path $TemplateCatalog
$schemaObject = Read-JsonFile -Path ".\framework\schemas\profile-draft.schema.json"

if ($ListLLMModels) {
    Invoke-LLMModelList -BaseUrl $LLMBaseUrl -ApiKeyEnv $LLMApiKeyEnv -TimeoutSec $LLMTimeoutSec
    return
}

if ($Config -and $Requirement) {
    throw "Use either -Config or -Requirement, not both."
}

if (-not $Config -and -not $Requirement) {
    throw "Provide -Config for an existing draft or -Requirement for natural-language routing/prompt generation."
}

$draft = $null
$routeMatch = $null

if ($Config) {
    $draft = Read-JsonFile -Path $Config
} else {
    $requirementPath = Resolve-RepoPath $Requirement
    if (-not (Test-Path -LiteralPath $requirementPath)) {
        throw "Requirement file was not found: $requirementPath"
    }
    $sourceText = Get-Content -LiteralPath $requirementPath -Raw

    if ($DraftPrompt) {
        New-DraftPrompt -SourceText $sourceText -CatalogObject $catalogObject -SchemaObject $schemaObject -TemplateCatalogObject $templateCatalogObject
        return
    }

    if ($UseLLM) {
        $prompt = New-DraftPrompt -SourceText $sourceText -CatalogObject $catalogObject -SchemaObject $schemaObject -TemplateCatalogObject $templateCatalogObject
        $draft = Invoke-LLMDraft -Prompt $prompt -BaseUrl $LLMBaseUrl -Model $LLMModel -ApiKeyEnv $LLMApiKeyEnv -TimeoutSec $LLMTimeoutSec
    } else {
        $routeMatch = Find-BestRoute -CatalogObject $catalogObject -SourceText $sourceText
        $draft = New-DraftFromRoute -Route $routeMatch.route -SourceText $sourceText -TemplateCatalogObject $templateCatalogObject
    }
}

Test-Draft -Draft $draft -CatalogObject $catalogObject -TemplateCatalogObject $templateCatalogObject

if ($OutConfig) {
    $outConfigPath = Resolve-RepoPath $OutConfig
    $outConfigDir = Split-Path -Parent $outConfigPath
    if ($outConfigDir -and -not (Test-Path -LiteralPath $outConfigDir)) {
        New-Item -ItemType Directory -Force -Path $outConfigDir | Out-Null
    }
    $draft | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outConfigPath -Encoding UTF8
    Write-Host "Wrote draft config: $outConfigPath"
}

if ($ValidateOnly) {
    Write-DraftValidationSummary -Draft $draft
    return
}

if ($DraftOnly -or -not $Run) {
    if ($routeMatch) {
        Write-Host "Matched route: $($routeMatch.route.intent) (score: $($routeMatch.score))"
    }
    $draft | ConvertTo-Json -Depth 20
    if (-not $Run) {
        return
    }
}

$coverageStatus = "fully_supported"
if ($draft.coverage_status) {
    $coverageStatus = [string]$draft.coverage_status
}
if ($coverageStatus -eq "unsupported" -or $coverageStatus -eq "ambiguous") {
    throw "Draft coverage_status is '$coverageStatus'; refusing to run verification until the requirement is supported or clarified."
}

$reportDirPath = Resolve-RepoPath $ReportDir
if (-not (Test-Path -LiteralPath $reportDirPath)) {
    New-Item -ItemType Directory -Force -Path $reportDirPath | Out-Null
}

$results = @()
foreach ($profileNameValue in (Get-SelectedProfileNames -Draft $draft)) {
    $profileName = [string]$profileNameValue
    $profilePath = Join-Path $repoRoot "framework\profiles\$profileName.json"
    if (-not (Test-Path -LiteralPath $profilePath)) {
        throw "Selected profile was not found: $profilePath"
    }

    $profileObject = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
    $queryNames = Get-QueryNamesForProfile -Draft $draft -ProfileName $profileName -ProfileObject $profileObject

    foreach ($queryNameValue in $queryNames) {
        $queryName = [string]$queryNameValue
        Write-Host "Running $profileName :: $queryName"
        $result = Invoke-ProfileQuery -ProfileName $profileName -QueryName $queryName -ProfileObject $profileObject -VerifytaPath $Verifyta
        $results += $result
        Write-Host "  -> $($result.status)"
    }
}

$verificationCompleted = $true
$allSatisfactionQueriesSatisfied = $true
$notSatisfiedQueries = @()
foreach ($result in $results) {
    if ($result.status -eq "ERROR" -or $result.status -eq "UNKNOWN") {
        $verificationCompleted = $false
    }
    if ($result.status -eq "NOT_SAT") {
        $allSatisfactionQueriesSatisfied = $false
        $notSatisfiedQueries += "$($result.profile)::$($result.query)"
    }
}

$accepted = $verificationCompleted
if ([string]$draft.analysis.mode -ne "quantitative_reliability") {
    $accepted = $verificationCompleted -and $allSatisfactionQueriesSatisfied
}
if ($coverageStatus -eq "partially_supported") {
    $accepted = $false
}

$report = [pscustomobject][ordered]@{
    tool = "lwm2m-ifv-profile-assistant"
    prototype_version = "0.1"
    generated_at = (Get-Date).ToString("o")
    accepted = $accepted
    verification_completed = $verificationCompleted
    all_satisfaction_queries_satisfied = $allSatisfactionQueriesSatisfied
    not_satisfied_queries = $notSatisfiedQueries
    coverage_status = $coverageStatus
    supported_requirements = @($draft.supported_requirements)
    unsupported_requirements = @($draft.unsupported_requirements)
    clarification_questions = @($draft.clarification_questions)
    assumptions = @($draft.assumptions)
    requirement_id = [string]$draft.requirement_id
    analysis = $draft.analysis
    selected_profiles = @(Get-SelectedProfileNames -Draft $draft)
    profile_instances = @(Get-ProfileInstances -Draft $draft)
    merged_query_sets = @(Get-MergedQuerySets -Draft $draft)
    parameters = $draft.parameters
    results = $results
    claim_boundary = "This prototype reports only the listed UPPAAL query results under the selected bounded models and profile parameters. LLM or routing text is not a formal claim."
}

$safeId = ([string]$draft.requirement_id).ToLowerInvariant() -replace "[^a-z0-9]+", "_"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path $reportDirPath "$safeId-$timestamp.json"
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host "Wrote report: $reportPath"
if ($FullReport) {
    $report | ConvertTo-Json -Depth 30
} else {
    Write-RunSummary -Report $report -ReportPath $reportPath
}
