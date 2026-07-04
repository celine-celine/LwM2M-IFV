# LwM2M-IFV Profile Assistant: Tool Design Draft

## 1. Motivation

The current manuscript introduces an LwM2M-IFV framework with three layers:

- Protocol Core Layer: reusable LwM2M lifecycle automata and baseline properties.
- Configurable Profile Layer: security and reliability profiles instantiated by parameters.
- Industrial Scenario Layer: shop-floor policy interpretation and admission decisions.

The LLM-related contribution should therefore not be presented as an isolated discussion. A better role is a small assistant tool that translates a natural-language industrial requirement into a constrained profile configuration, runs the corresponding UPPAAL verification profile, and returns an auditable result bundle.

The key principle is:

> The LLM proposes configurations; UPPAAL verifies claims.

The tool should never allow the LLM to invent model states, predicates, query names, or verification results.

## 2. Proposed Tool Name

Working name:

```text
lwm2m-ifv-profile-assistant
```

Paper-facing name:

```text
LwM2M-IFV Profile Assistant
```

## 3. Scope

The tool is designed as a lightweight bridge between natural-language shop-floor requirements and executable UPPAAL verification profiles.

In the first implementation, the tool should support:

1. Natural-language requirement input.
2. A constrained configuration draft in YAML or JSON.
3. Schema validation against known profile fields.
4. Internal routing to Level 2 qualitative verification or Level 3 quantitative SMC verification.
5. Execution through existing verification scripts.
6. A compact evidence report that records the selected model, profile, queries, commands, and results.

Out of scope for the first version:

- automatic generation of new UPPAAL automata;
- automatic proof of claims not covered by the query catalog;
- unrestricted LLM access to arbitrary files;
- direct modification of manuscript text.

## 4. Unified Entry, Internal Routing

The user should interact with one entry point rather than separate Level 2 and Level 3 tools.

Conceptual command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Requirement ".\framework\examples\requirements\clone_rejection.txt" `
  -OutConfig ".\framework\generated\configs\clone_rejection.yaml" `
  -Run
```

Internally, the assistant routes the configuration to one of three execution modes:

| Mode | Framework layer focus | Verification type | Typical purpose |
|---|---|---|---|
| `qualitative_security` | Configurable Profile Layer | exhaustive UPPAAL verification | security/admission properties |
| `quantitative_reliability` | Configurable Profile Layer | UPPAAL SMC | reliability and timing trade-offs |
| `industrial_policy` | Industrial Scenario Layer | exhaustive verification, optionally with SMC inputs | shop-floor command authorization and cleanup |

This preserves a single user-facing workflow while keeping the verification semantics explicit.

## 5. End-to-End Workflow

The intended workflow is:

1. The engineer writes a short requirement in natural language.
2. The tool asks the LLM to produce a configuration draft under a strict schema.
3. The tool validates the draft against allowed profile names, parameter names, model paths, and query identifiers.
4. The router selects a verification profile.
5. The runner calls `verifyta` through existing scripts.
6. The reporter emits an evidence bundle.

```text
Natural-language requirement
        |
        v
Constrained LLM draft
        |
        v
Schema validation and catalog lookup
        |
        v
Profile routing
        |
        +--> qualitative_security      --> verifyta exhaustive queries
        +--> quantitative_reliability  --> verifyta SMC queries
        +--> industrial_policy         --> policy monitor queries
        |
        v
Evidence report
```

## 6. Configuration Draft Format

The LLM output should be a configuration draft, not a verification result.

Example 1: cloned endpoint rejection.

```yaml
requirement_id: clone_rejection_demo
source_text: >
  A cloned endpoint must be rejected. The legitimate shop-floor device may
  receive management commands only after bootstrap binding, endpoint identity,
  and registration have all been verified.

analysis:
  mode: qualitative_security
  intent: duplicate_endpoint_rejection

scenario:
  domain: shop_floor_lwm2m
  devices:
    - id: client_0
      role: legitimate_device
    - id: client_1
      role: cloned_endpoint

selected_profiles:
  - registration-identity-binding
  - industrial-policy-binding-cleanup

queries:
  - duplicate_endpoint_rejected
  - cloned_device_not_authorized
  - command_requires_binding_identity_and_session

parameters:
  dtls_enabled: true
  identity_binding_required: true
  duplicate_endpoint_policy: reject
```

Example 2: telemetry freshness under lossy industrial LAN conditions.

```yaml
requirement_id: telemetry_freshness_lan_demo
source_text: >
  The monitoring application should accept telemetry only when it belongs to a
  fresh observation relation. The plant network is a low-loss LAN, but occasional
  packet loss and retransmission should be considered.

analysis:
  mode: quantitative_reliability
  intent: telemetry_freshness_under_loss

scenario:
  domain: shop_floor_lwm2m
  devices:
    - id: client_0
      role: sensor_or_plc_endpoint

selected_profiles:
  - observation-smc-retransmission

queries:
  - notification_delivery_probability
  - expected_received_notifications
  - stale_telemetry_flag_probability

parameters:
  oscore_enabled: true
  retransmission_enabled: true
  network_loss_profile: shop_floor_lan_low_loss
  observation_reset_enabled: true
  freshness_deadline_profile: bounded_control_monitoring
```

## 7. Profile Routing Table

The first version can use a deterministic routing table before introducing an LLM API. The LLM can later fill the same fields.

| Natural-language intent | Mode | Candidate profile | Representative properties |
|---|---|---|---|
| fake bootstrap server, malicious provisioning | `qualitative_security` | `bootstrap-security-binding` | fake server rejected; tampering detected |
| secure bootstrap before registration | `qualitative_security` | `registration-bootstrap-binding` | registration requires valid bootstrap binding |
| cloned endpoint rejection | `qualitative_security` | `registration-identity-binding` | duplicate endpoint rejected; command not authorized |
| abnormal offline cleanup | `industrial_policy` | `industrial-policy-binding-cleanup` | stale session revoked; command authorization removed |
| telemetry freshness under loss | `quantitative_reliability` | `observation-smc-retransmission` | notification delivery; freshness probability |
| onboarding reliability with security overhead | `quantitative_reliability` | `bootstrap-smc` | bootstrap success probability; expected delay |
| registration lifetime and update reliability | `quantitative_reliability` | `registration-smc` | update success; expiration probability |

## 8. Evidence Report Format

The result should separate three things:

- what the user requested;
- what configuration the assistant selected;
- what UPPAAL actually verified.

Example evidence bundle:

```json
{
  "requirement_id": "clone_rejection_demo",
  "accepted": true,
  "analysis_mode": "qualitative_security",
  "selected_profiles": [
    "registration-identity-binding",
    "industrial-policy-binding-cleanup"
  ],
  "model_files": [
    "framework/generated/registration_identity_binding.xml",
    "framework/generated/industrial_policy_binding_cleanup.xml"
  ],
  "queries": [
    {
      "name": "duplicate_endpoint_rejected",
      "index": 2,
      "result": "SAT"
    },
    {
      "name": "command_requires_binding_identity_and_session",
      "index": 5,
      "result": "SAT"
    }
  ],
  "warnings": [],
  "claim_boundary": "The report supports only the listed queries under the selected bounded model and parameters."
}
```

For SMC profiles, the report should include confidence level, simulation count or bound, and avoid presenting sampled values as deterministic guarantees.

## 9. Relationship to the Paper

This tool can strengthen the manuscript in three ways.

First, it makes the LLM-enabled part operational. The LLM is not a loose future-work paragraph; it becomes a constrained profile-generation interface.

Second, it connects Section 4 and Section 5. Both qualitative security profiles and quantitative SMC profiles are produced through the same configuration workflow.

Third, it gives Section 5 a concrete industrial case-study mechanism. A shop-floor requirement can be translated into a policy-monitor configuration and checked against admission, cleanup, and freshness properties.

Possible paper wording:

> The LLM-enabled assistant is used only as a configuration front end. It maps natural-language industrial requirements to a schema-constrained profile draft, while the formal claims reported in this paper are obtained exclusively from UPPAAL verification results.

## 10. MVP Implementation Plan

### Phase 0: Catalog Cleanup

Create or refine machine-readable catalogs:

- `framework/catalog/profile-routing.json`
- `framework/catalog/query-catalog.json`
- `framework/schemas/profile-draft.schema.json`

The catalog should mark:

- executable model path;
- supported mode;
- query names and indices;
- required parameters;
- whether a profile is qualitative or SMC;
- known limitations.

### Phase 1: Deterministic Assistant Without LLM API

Implement a simple runner that accepts either:

- a manually written config file; or
- a requirement file matched by deterministic keywords.

This gives us a testable path before adding an LLM dependency.

Candidate command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Config ".\framework\examples\configs\clone_rejection.yaml" `
  -Run
```

### Phase 2: Prompt-Based Draft Generation

Add a `-DraftOnly` mode that prints a strict prompt and expected YAML schema. The user can paste the prompt into an LLM and save the returned draft.

Candidate command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Requirement ".\framework\examples\requirements\telemetry_freshness.txt" `
  -DraftOnly
```

This avoids immediate API-key and dependency issues.

### Phase 3: Optional LLM API Integration

After the deterministic runner is stable, add optional API-based draft generation:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Requirement ".\framework\examples\requirements\telemetry_freshness.txt" `
  -UseLLM `
  -Run
```

The API output must still pass schema validation and catalog lookup before verification.

### Phase 4: Paper Case Study

Use one complete example as a manuscript case study:

1. Natural-language shop-floor requirement.
2. Generated profile draft.
3. Selected verification profile.
4. UPPAAL result bundle.
5. Interpretation for industrial operation.

This can replace the current lightweight LLM discussion with an auditable tool-supported example.

## 11. Safety and Trust Boundaries

The assistant should enforce the following rules:

- The LLM may select only known profile names.
- The LLM may select only known query identifiers.
- The LLM may set only schema-defined parameters.
- The LLM may not write UPPAAL model code in the MVP.
- The final report must distinguish verification results from explanatory text.
- A failed query must be reported directly, not paraphrased away.
- SMC results must be reported with their probabilistic interpretation.

## 12. Known Issues to Handle

Several current project details should shape the implementation:

- Legacy Level 3 SMC XML files include saved GUI result nodes and can be awkward to run by query index. The MVP should prefer clean generated framework profiles where possible.
- Some inherited query sets are not meaningful for every attack profile. The catalog should define scenario-specific query subsets.
- The no-DTLS attack profile should not be summarized using a normal "both clients bootstrap" query; it should use attack-relevant reachability and rejection properties.
- SMC tables in the manuscript should describe trends and confidence rather than exact deterministic values.
- Industrial-policy profiles currently support a bounded number of clients. Any case study should state this bound explicitly.

## 13. Suggested Repository Additions

Suggested files for the next development step:

```text
framework/
  catalog/
    profile-routing.json
    query-catalog.json
  schemas/
    profile-draft.schema.json
  examples/
    requirements/
      clone_rejection.txt
      telemetry_freshness_lan.txt
    configs/
      clone_rejection.yaml
      telemetry_freshness_lan.yaml
  generated/
    configs/
    reports/

tools/
  lwm2m_profile_assistant.ps1
```

## 14. Immediate Next Step

The next concrete task should be:

1. Build `framework/catalog/profile-routing.json` from the profiles that already run.
2. Define `framework/schemas/profile-draft.schema.json`.
3. Add two example configs:
   - cloned endpoint rejection;
   - telemetry freshness under lossy LAN conditions.
4. Implement the first deterministic version of `tools/lwm2m_profile_assistant.ps1`.

Once this works, the LLM part can be introduced as a controlled draft generator rather than as a source of formal claims.

## 15. Prototype Status

The first prototype has been added with a deterministic catalog router:

```text
tools/lwm2m_profile_assistant.ps1
framework/catalog/profile-routing.json
framework/schemas/profile-draft.schema.json
framework/examples/requirements/
framework/examples/configs/
framework/generated/reports/
```

Current supported usage:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Requirement .\framework\examples\requirements\clone_rejection.txt `
  -DraftOnly
```

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Config .\framework\examples\configs\clone_rejection.json `
  -Run
```

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Config .\framework\examples\configs\telemetry_freshness_lan.json `
  -Run
```

Prototype behavior:

- `-Requirement` uses keyword routing from `profile-routing.json`.
- `-DraftOnly` prints a constrained template-driven JSON configuration draft.
- `-DraftPrompt` prints a vendor-neutral LLM prompt that contains the requirement, schema, allowed route templates, allowed profile templates, and allowed profile/query catalog.
- `-OutConfig` saves the generated draft.
- `-ValidateOnly` validates an existing JSON draft against the route catalog, profile template catalog, executable profile catalog, and query names without running UPPAAL.
- `-Config` runs from an existing JSON draft.
- `-Run` calls the selected UPPAAL profile queries, prints a compact terminal summary, and writes a JSON evidence report.
- `-FullReport` additionally prints the complete JSON report to the terminal.
- `-UseLLM` calls an OpenAI-compatible chat-completions endpoint to generate the JSON draft, then validates the draft locally before any verification run.

For LLM-generated drafts, `analysis.intent` must be one of the stable intent ids in `framework/catalog/profile-routing.json`, such as `duplicate_endpoint_rejection` or `telemetry_freshness_under_loss`. Natural-language explanations should be placed in `assistant_notes`, not in machine-readable routing fields.

For combined requirements, `analysis.intent` is the primary intent and `analysis.intents` lists all covered catalog intent ids. For example, a shop-floor admission requirement may combine `secure_bootstrap_registration_admission` and `duplicate_endpoint_rejection`. Each `profile_instances` item may also include an `intent` field indicating which catalog intent that executable instance supports.

When multiple profile instances instantiate the same executable profile, the runner merges their query sets by profile name before execution. For example, two `industrial-policy-binding-cleanup` instances may contribute admission queries and clone-rejection queries; the runner executes the union of those queries once under the same profile and records the merged query set in the report.

The current prototype separates three levels:

- `intent`: the requirement category selected from `framework/catalog/profile-routing.json`;
- `profile_instances`: executable instances generated from bounded templates in `framework/catalog/profile-templates.json`;
- `query`: UPPAAL query names already implemented by the selected executable profile.

The tool does not enumerate every possible profile in advance. Instead, an LLM or deterministic router must select a profile template and instantiate one or more executable profiles from its allowed profile/query/parameter domain.

Coverage behavior:

- `fully_supported`: verification may run normally.
- `partially_supported`: verification may run for the supported part, but the final report is not treated as full acceptance.
- `unsupported`: verification is refused because the core requirement is outside the registered template catalog.
- `ambiguous`: verification is refused until clarification questions are answered.

LLM-assisted draft workflow:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Requirement .\framework\examples\requirements\clone_rejection.txt `
  -DraftPrompt
```

Paste the generated prompt into an LLM, save the returned JSON draft, then validate it:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Config .\framework\generated\configs\llm_clone_rejection.json `
  -ValidateOnly
```

If validation succeeds, run the selected profiles:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Config .\framework\generated\configs\llm_clone_rejection.json `
  -Run
```

OpenAI-compatible API workflow:

```powershell
$env:DASHSCOPE_API_KEY = '<your-api-key>'

powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Requirement .\framework\examples\requirements\clone_rejection.txt `
  -UseLLM `
  -LLMModel deepseek-v4-pro `
  -OutConfig .\framework\generated\configs\llm_clone_rejection.json `
  -ValidateOnly
```

Then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -Config .\framework\generated\configs\llm_clone_rejection.json `
  -Run
```

Default LLM settings:

- `LLMBaseUrl`: `https://dashscope.aliyuncs.com/compatible-mode/v1`
- `LLMModel`: `deepseek-v4-pro`
- `LLMApiKeyEnv`: `DASHSCOPE_API_KEY`

The API key is read only from environment variables. It is not written to generated configs, reports, or source files.

If a model name returns `model_not_found`, list the models visible to the current API key:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\lwm2m_profile_assistant.ps1 `
  -ListLLMModels
```

The report distinguishes:

- `verification_completed`: whether all selected queries executed without tool/runtime errors;
- `all_satisfaction_queries_satisfied`: whether every selected query returned SAT;
- `accepted`: qualitative profiles require all selected satisfaction queries to be SAT, while quantitative SMC profiles are accepted if verification completed and any NOT_SAT probability query is reported for interpretation.

Example compact output:

```text
Verification summary
--------------------
Requirement : clone_rejection_demo
Mode        : qualitative_security
Intent      : duplicate_endpoint_rejection
Accepted    : True
Completed   : True
Profiles    : registration-identity-binding, industrial-policy-binding-cleanup
Queries     : 6 total, 6 SAT, 0 NOT_SAT, 0 completed/SMC, 0 error
Report file : framework/generated/reports/clone_rejection_demo-*.json

Per-query results
  [SAT] registration-identity-binding :: duplicate_endpoint_rejected (q2)
  [SAT] registration-identity-binding :: clone_not_authorized (q6)
```

## 16. Prototype Regression Examples

The current prototype includes five executable example configurations, covering all catalog routes:

| Example config | Intent | Mode | Expected interpretation |
|---|---|---|---|
| `framework/examples/configs/clone_rejection.json` | `duplicate_endpoint_rejection` | `qualitative_security` | all selected clone rejection and command-authorization queries should be SAT |
| `framework/examples/configs/bootstrap_registration_admission.json` | `secure_bootstrap_registration_admission` | `qualitative_security` | bootstrap-registration binding and policy-admission queries should be SAT |
| `framework/examples/configs/offline_cleanup_policy.json` | `offline_cleanup_policy` | `industrial_policy` | deregister/offline cleanup and authorization revocation queries should be SAT |
| `framework/examples/configs/telemetry_freshness_lan.json` | `telemetry_freshness_under_loss` | `quantitative_reliability` | SMC queries should complete; probability-threshold NOT_SAT results are reported for interpretation |
| `framework/examples/configs/onboarding_reliability.json` | `onboarding_reliability` | `quantitative_reliability` | bootstrap and registration SMC queries should complete |

Regression command:

```powershell
$configs = @(
  'clone_rejection',
  'bootstrap_registration_admission',
  'offline_cleanup_policy',
  'telemetry_freshness_lan',
  'onboarding_reliability'
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
