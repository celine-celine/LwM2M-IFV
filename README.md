# LwM2M-IFV UPPAAL Framework

This repository contains an UPPAAL-based framework for modeling and verifying LwM2M behavior in industrial IoT scenarios.

The current prototype includes a small assistant tool that maps natural-language shop-floor requirements to bounded profile templates, validates the generated configuration against a local catalog, and runs UPPAAL `verifyta` queries to produce formal evidence.

## Repository Layout

```text
framework/
  catalog/          Profile routing and template catalogs
  schemas/          JSON draft schema
  examples/         Requirement and configuration examples
  profiles/         Executable profile descriptors
  generated/        Generated UPPAAL XML models

tools/
  lwm2m_profile_assistant.ps1
  run_verifyta.ps1
  run_framework_profile.ps1

LwM2M Models/       Original and layered UPPAAL model files
```

Generated LLM drafts and verification reports are ignored by git:

```text
framework/generated/configs/
framework/generated/reports/
```

## Requirements

- Windows PowerShell
- UPPAAL command-line verifier `verifyta.exe`
- Optional: an OpenAI-compatible LLM endpoint, such as Alibaba Cloud Bailian/DashScope

The local default `verifyta` path is:

```powershell
C:\Program Files\UPPAAL-5.0.0\app\bin\verifyta.exe
```

You may also set:

```powershell
$env:UPPAAL_VERIFYTA = "C:\Program Files\UPPAAL-5.0.0\app\bin\verifyta.exe"
```

## Deterministic Draft Example

Generate and validate a template-driven draft without calling an LLM:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Requirement .\framework\examples\requirements\clone_rejection.txt `
  -OutConfig .\framework\generated\configs\clone_rejection_draft.json `
  -ValidateOnly
```

Run UPPAAL verification from an existing example configuration:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Config .\framework\examples\configs\clone_rejection.json `
  -Run
```

## LLM-Assisted Draft Example

Set your API key in the current PowerShell session. Do not commit keys to the repository.

```powershell
$env:DASHSCOPE_API_KEY = "<your-api-key>"
```

Generate an LLM draft through an OpenAI-compatible endpoint and validate it locally:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Requirement .\framework\examples\requirements\llm_shopfloor_admission_test.txt `
  -UseLLM `
  -LLMModel deepseek-v4-pro `
  -OutConfig .\framework\generated\configs\llm_shopfloor_admission_test.json `
  -ValidateOnly
```

Then run verification:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Config .\framework\generated\configs\llm_shopfloor_admission_test.json `
  -Run
```

## Safety Boundary

The LLM is used only as a constrained configuration generator. Formal claims are not accepted from the LLM.

The tool validates that:

- `analysis.intent` and `analysis.intents` are registered catalog intent ids;
- `profile_instances` use known profile templates;
- each template can instantiate the selected executable profile;
- each query name exists in the selected executable profile;
- `unsupported` and `ambiguous` drafts are not run.

UPPAAL `verifyta` is the only source of SAT, NOT_SAT, and SMC evidence.

For SMC profiles, the assistant extracts structured probability and expectation
summaries from `verifyta` output when available. Terminal summaries may include
items such as:

```text
Pr in [0.981725,1] (200/200 runs)
E~0.005
```

The full JSON report keeps the raw output tail together with the parsed `smc`
field for auditability.

## Regression Examples

The current minimum regression set is:

```text
clone_rejection
bootstrap_registration_admission
offline_cleanup_policy
telemetry_freshness_lan
onboarding_reliability
```

Run validation and verification:

```powershell
$configs = @(
  "clone_rejection",
  "bootstrap_registration_admission",
  "offline_cleanup_policy",
  "telemetry_freshness_lan",
  "onboarding_reliability"
)

foreach ($name in $configs) {
  powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
    -Config ".\framework\examples\configs\$name.json" `
    -ValidateOnly

  powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
    -Config ".\framework\examples\configs\$name.json" `
    -Run
}
```
