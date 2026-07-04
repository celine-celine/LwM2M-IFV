# LLM Draft Test Example

This example is intended for testing the `-UseLLM` path of the LwM2M-IFV Profile Assistant.

Requirement file:

```text
framework/examples/requirements/llm_shopfloor_admission_test.txt
```

Run prompt-only mode first if you want to inspect what will be sent to the LLM:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Requirement .\framework\examples\requirements\llm_shopfloor_admission_test.txt `
  -DraftPrompt
```

Run the OpenAI-compatible LLM draft generation path:

```powershell
$env:DASHSCOPE_API_KEY = "<your-api-key>"

powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Requirement .\framework\examples\requirements\llm_shopfloor_admission_test.txt `
  -UseLLM `
  -LLMModel deepseek-v4-pro `
  -OutConfig .\framework\generated\configs\llm_shopfloor_admission_test.json `
  -ValidateOnly
```

If the model name is not available to your account or region, list available models:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -ListLLMModels
```

If validation succeeds, run UPPAAL verification:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Config .\framework\generated\configs\llm_shopfloor_admission_test.json `
  -Run
```

Expected behavior:

- The LLM should choose `coverage_status = "fully_supported"`.
- The LLM should use stable intent ids rather than a free-form intent sentence.
- The draft should instantiate one or more templates from `framework/catalog/profile-templates.json`.
- A likely valid mapping is:
  - `registration_bootstrap_binding_template -> registration-bootstrap-binding`
  - `registration_identity_binding_template -> registration-identity-binding`
  - `industrial_policy_monitor_template -> industrial-policy-binding-cleanup`
- The validator will reject invented profile names, invented query names, incompatible template/profile pairs, and unsupported/ambiguous drafts.
