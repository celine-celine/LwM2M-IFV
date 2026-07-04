# LwM2M-IFV Manuscript Revision Plan

This file is the single working plan for the revised manuscript and the
supporting UPPAAL framework artifacts. Older narrative notes are superseded by
this plan. Query catalogs and protocol audits remain factual evidence records.

## Revision Goal

The revised paper should no longer read as a set of isolated UPPAAL models for
selected LwM2M procedures. The paper should present **LwM2M-IFV** as a
configurable lifecycle verification framework for industrial LwM2M deployments.

Core thesis:

```text
LwM2M-IFV separates reusable LwM2M lifecycle behavior, configurable
security/reliability profiles, and industrial policy consequences, so that
Bootstrap, Registration, Observation, and lifecycle cleanup properties can be
checked systematically rather than model by model.
```

The revised contribution should emphasize:

1. A three-layer UPPAAL modeling framework for industrial LwM2M.
2. Lifecycle coverage across Bootstrap, Registration, Registration Update,
   Deregister/offline cleanup, and Observation.
3. Configurable security and reliability profiles, including DTLS/no-DTLS,
   OSCORE abstraction, replay, DoS, duplicate endpoint, packet loss, timeout,
   retransmission, and deadline parameters.
4. Industrial policy monitoring that maps protocol/profile evidence to command
   authorization, cloned-device rejection, stale-session cleanup, and telemetry
   freshness.
5. A mixed verification workflow: exhaustive UPPAAL model checking for safety
   and reachability, plus UPPAAL SMC for probabilistic reliability.

## Three-Layer Architecture

### Layer 1: Protocol Core

Question answered:

```text
What LwM2M lifecycle behavior is independent of a specific deployment profile?
```

Contents:

- Bootstrap request, configuration provisioning, verification, and completion.
- Registration request, endpoint/object-list submission, validation, and
  acknowledgement.
- Registration Update and bounded lifetime renewal.
- Deregister and server-side session removal.
- Observation start, notification, acknowledgement, cancellation, and Reset.
- Candidate future core: Device Management operations.

Typical properties:

```text
A[] client_registered[c] imply bootstrap_completed[c]
A[] client_registered[c] imply object_list_received[c]
E<> update_ack_received[c]
E<> deregister_success[c]
A[] observation_started[c] imply client_registered[c]
```

### Layer 2: Configurable Profile

Question answered:

```text
Under which version, security, attacker, transport, timing, and reliability
assumptions is the protocol core instantiated?
```

Contents:

- LwM2M version knobs: 1.0, 1.1, 1.2, and 1.2.x-oriented behavior where the
  abstraction supports it.
- Security modes: none, DTLS/TLS, and OSCORE-style integrity/freshness
  abstraction.
- Security constraints: message freshness, Bootstrap-to-Registration binding,
  endpoint identity binding.
- Threat profiles: fake Bootstrap Server, tampering, replay, DoS, duplicate
  endpoint/cloned device.
- Reliability/timing profiles: packet loss, timeout, retransmission,
  notification loss, Reset probability, security overhead, registration
  lifetime, and deadlines.

Typical properties:

```text
A[] DTLS_ENABLED imply not fake_config_received[c]
A[] replay_message_detected imply attack_detected
A[] duplicate_endpoint_detected imply not cloned_device_registered
A[] client_registered[c] imply registration_server_id[c] == bootstrapped_server_id[c]
Pr[<=T; N] (<> client_registered[c])
```

### Layer 3: Industrial Scenario

Question answered:

```text
What operational consequence does a verified or violated protocol state have in
an industrial deployment?
```

Contents:

- MES/server and shop-floor device roles.
- Policy monitor for admission, authorization, cleanup, and telemetry status.
- Command authorization only for verified, active, non-stale sessions.
- Cloned-device rejection and alarm predicates.
- Stale-session cleanup after Deregister, lifetime expiration, or abnormal
  offline detection.
- Telemetry freshness and observation deadline interpretation.

Typical properties:

```text
A[] lifetime_expired[c] imply !command_authorized[c]
A[] cloned_device_detected[c] imply !command_authorized[c]
A[] offline_device[c] imply !server_session_active[c]
A[] stale_observation[c] imply !control_decision_enabled[c]
Pr[<=T; N] (<> fresh_telemetry_received[c])
```

## Layer Placement Rule

Use this rule when adding features or writing the manuscript:

```text
If it is a standard LwM2M action, place it in Protocol Core.
If it is a version/security/network/attacker/timing choice, place it in
Configurable Profile.
If it describes shop-floor operational meaning, place it in Industrial Scenario.
```

| Feature | Main layer | Manuscript role |
| --- | --- | --- |
| Bootstrap | Protocol Core | Standard onboarding procedure. |
| Registration | Protocol Core | Standard endpoint admission procedure. |
| Registration Update | Protocol Core | Standard lifetime renewal action; parameters are profile-level. |
| Deregister | Protocol Core | Standard removal action; cleanup meaning is scenario-level. |
| DTLS/OSCORE | Configurable Profile | Security profile choices. |
| Replay/DoS/MITM | Configurable Profile | Threat profile choices. |
| Bootstrap-to-Registration binding | Configurable Profile | Security constraint for server identity/credential continuity. |
| Duplicate endpoint detection | Configurable Profile | Identity constraint for cloned-device rejection. |
| Packet loss/retransmission | Configurable Profile | Reliability profile choices. |
| Command authorization | Industrial Scenario | Operational policy driven by protocol evidence. |
| Telemetry freshness | Industrial Scenario | Monitoring policy driven by Observation evidence. |
| Stale-session cleanup | Industrial Scenario | Safety consequence of expiration, Deregister, or abnormal offline behavior. |

## Current Verification Artifacts

Original models remain under:

```text
LwM2M Models/
```

Framework profiles, generated models, query catalogs, and audit notes remain
under:

```text
framework/
tools/
```

### Observation

Profiles:

- `framework/profiles/observation-long-lived-reset.json`
- `framework/profiles/observation-long-lived-reset-smc.json`
- wrapper profiles for legacy Observation variants.

Generated models:

- `framework/generated/observation/Observation_LongLived_Reset.xml`
- `framework/generated/observation/Observation_LongLived_Reset_SMC.xml`

Verified evidence:

- Bounded long-lived Observe relation with multiple notifications.
- CoAP ACK abstraction after Notify.
- Reset-based cancellation path.
- SMC profile for notification delivery/loss and bounded observation cycles.

Evidence record:

- `framework/query-catalog/observation.md`
- `framework/protocol-audit/observation.md`

### Bootstrap

Profiles:

- `framework/profiles/bootstrap-core.json`
- `framework/profiles/bootstrap-no-dtls-attack.json`
- `framework/profiles/bootstrap-smc.json`

Generated models:

- `framework/generated/bootstrap/Bootstrap_Core.xml`
- `framework/generated/bootstrap/Bootstrap_NoDTLS_Attack.xml`
- `framework/generated/bootstrap/Bootstrap_SMC.xml`

Verified evidence:

- DTLS-style protection blocks fake Bootstrap Server and tampering paths.
- No-DTLS attack profile makes fake/tampered configurations reachable but
  rejected.
- SMC profile estimates onboarding success/failure under delay, packet loss,
  timeout, and retransmission.

Evidence record:

- `framework/query-catalog/bootstrap.md`
- `framework/protocol-audit/bootstrap.md`

### Registration

Profiles:

- `framework/profiles/registration-core.json`
- `framework/profiles/registration-attack.json`
- `framework/profiles/registration-smc.json`
- `framework/profiles/registration-lifecycle.json`
- `framework/profiles/registration-bootstrap-binding.json`
- `framework/profiles/registration-identity-binding.json`
- `framework/profiles/registration-deregister-offline.json`

Generated models:

- `framework/generated/registration/Registration_Core.xml`
- `framework/generated/registration/Registration_Attack.xml`
- `framework/generated/registration/Registration_SMC.xml`
- `framework/generated/registration/Registration_Lifecycle.xml`
- `framework/generated/registration/Registration_BootstrapBinding.xml`
- `framework/generated/registration/Registration_IdentityBinding.xml`
- `framework/generated/registration/Registration_DeregisterOffline.xml`

Verified evidence:

- Core registration requires bootstrap/provisioning, object-list submission, and
  current message-id state.
- Attack profile detects replay and DoS behavior.
- Lifecycle profile verifies Registration Update, lifetime renewal, expiration,
  and command authorization only for active non-expired sessions.
- Bootstrap-to-Registration binding verifies server identity/credential
  continuity and rejects rogue binding attempts.
- Identity-binding profile rejects a cloned duplicate endpoint and preserves the
  legitimate endpoint owner.
- Deregister/offline cleanup removes active sessions and disables command
  authorization.

Evidence record:

- `framework/query-catalog/registration.md`
- `framework/protocol-audit/registration.md`

### Industrial Scenario

Profile:

- `framework/profiles/industrial-policy-binding-cleanup.json`

Generated model:

- `framework/generated/industrial/IndustrialPolicy_BindingCleanup.xml`

Verified evidence:

- `PolicyMonitor` consumes profile evidence for admission, cloned-device
  rejection, explicit Deregister cleanup, and abnormal offline cleanup.
- The monitor maintains command authorization, policy admission,
  cloned-device alarm, cloned-device rejection, stale-session cleanup, and
  cleanup completion predicates.
- Current query catalog records ten satisfied policy-monitor properties,
  including command authorization requiring verified active sessions, rejected
  clones never being authorized, and cleanup revoking authorization.

Evidence record:

- `framework/query-catalog/industrial.md`

## Manuscript Revision Roadmap

### Section 3: LwM2M-IFV Framework

Purpose:

- Establish the three-layer architecture before model details.
- Explain parameter groups and the questions they support.
- Use Fig. 3 and Fig. 4-style diagrams sparingly; keep only representative
  automata screenshots instead of reporting every state machine.
- Make `Fig.~\ref{fig:industrial-binding}` the visual anchor for the Industrial
  Scenario Layer.

Required consistency:

- Refer to Protocol Core, Configurable Profile, and Industrial Scenario
  consistently.
- Keep `Remark (Layered property compatibility)` conservative:
  universal safety/ordering properties over core events may be reused through
  projection when extensions preserve the core event order; profile-specific and
  industrial properties must be checked on the extended models.

### Section 4: Qualitative Security and Admission Profiles

Recommended structure:

```text
4. Qualitative Security and Admission Profiles
4.1 Profile Instantiation Strategy
4.2 Bootstrap Security Profile
4.3 Registration Admission Profiles
4.4 Observation Integrity and Freshness Profile
4.5 Qualitative Verification Results
```

Writing direction:

- Do not narrate one automaton after another.
- Position Section 4 as qualitative instantiations of the Configurable Profile
  Layer.
- Bootstrap should focus on DTLS/no-DTLS, fake Bootstrap Server, and tampering.
- Registration should focus on replay/DoS, Bootstrap-to-Registration binding,
  duplicate endpoint rejection, and Deregister/offline cleanup.
- Observation should focus on OSCORE abstraction, freshness, and Reset-based
  cancellation.
- Results should be grouped by `profile -> risk addressed -> representative
  queries -> result`.

### Section 5: Quantitative SMC Reliability Profiles

Recommended structure:

```text
5. Quantitative SMC Reliability Profiles
5.1 SMC Profile Design
5.2 Observation Reliability Profile
5.3 Bootstrap and Registration Reliability Profiles
5.4 Reliability Results and Industrial Interpretation
5.5 Summary of Profile Trade-offs
```

Writing direction:

- Do not frame SMC as a separate architecture layer devoted only to performance.
- Present SMC as probabilistic reliability profiling inside the Configurable
  Profile Layer, then interpret the results through the Industrial Scenario
  Layer.
- Explain parameters by the questions they answer:
  - security overhead adjusts DTLS/OSCORE delay;
  - loss/retransmission adjusts network reliability;
  - deadline/lifetime/update adjusts industrial timing constraints;
  - notification/reset adjusts telemetry freshness.
- Interpret numerical results in terms of onboarding success, registration
  admission success, observation freshness, retransmission burden, and failure
  probability.

### Conclusion and Future Work

Purpose:

- Close on configurability, lifecycle coverage, and industrial policy
  interpretation rather than on isolated UPPAAL examples.
- Keep gateway/queue admission control, richer LwM2M Device Management, deeper
  OSCORE/DTLS cryptographic abstraction, and LLM-assisted profile/query
  generation as future work unless they are implemented and evaluated.

## Terminology Alignment

| Avoid / old wording | Use instead | Reason |
| --- | --- | --- |
| Old functional-layer wording | Protocol Core Layer | Matches the current three-layer framework. |
| Old security-layer wording | Configurable Profile Layer | Security is one kind of profile, not the whole layer. |
| Old performance-layer wording | Configurable Profile Layer / SMC reliability profile | SMC is a quantitative profile, not a separate architectural layer. |
| Isolated UPPAAL models | Profile-driven framework instantiations | Supports the novelty claim. |
| Full DTLS/OSCORE proof | DTLS/OSCORE-style authentication, integrity, freshness, and overhead abstraction | Avoids cryptographic overclaim. |
| Full unbounded Observe relation | Bounded monitoring instance of a long-lived Observe relation | Matches the generated Observation model. |
| Property preservation | Layered property compatibility | Keeps the proof claim conservative. |
| Unimplemented LLM tooling as a contribution | Future work: LLM-assisted profile/query generation | Not implemented in the current artifact set. |

## Result, Figure, and Evidence Map

| Manuscript item | Source artifact | Intended role |
| --- | --- | --- |
| Three-layer framework figure | Section 3 framework text and parameter tables | Explain architecture before models. |
| Communication sequence figure | Bootstrap, Registration, Update, Observation, Deregister/offline cleanup flow | Connect lifecycle flow to model families. |
| `Fig.~\ref{fig:industrial-binding}` | `figs/industryscenario.png` in Overleaf paper | Show how LwM2M lifecycle evidence feeds industrial policy decisions. |
| Representative UPPAAL screenshots | Selected generated models | Keep 1-2 screenshots as examples, not a model-by-model diary. |
| Qualitative query table | `framework/query-catalog/*.md` | Support Section 4 profile results. |
| SMC result tables | Observation, Bootstrap, Registration SMC query catalogs | Support Section 5 reliability interpretation. |
| Protocol fidelity caveats | `framework/protocol-audit/*.md` | State abstractions and avoid overclaiming. |

Current table labels to preserve:

- `tab:obs-perf-results` for the Observation SMC table.
- `tab:bootstrap-registration-perf-results` for the Bootstrap/Registration SMC
  table.

## Verification Commands

Use profile entry points where possible:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\bootstrap-core.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\bootstrap-no-dtls-attack.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\bootstrap-smc.json

powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-core.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-attack.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-smc.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-lifecycle.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-bootstrap-binding.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-identity-binding.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-deregister-offline.json

powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\observation-long-lived-reset.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\observation-long-lived-reset-smc.json

powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\industrial-policy-binding-cleanup.json
```

Run a model audit with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\audit_uppaal_models.ps1 -ModelRoot .\framework\generated
```

UPPAAL models do not need to be rerun for manuscript-only edits unless a model
claim or property statement is changed.

## Markdown Maintenance Rules

- Keep this file as the master plan.
- Keep query catalogs as factual verification evidence.
- Keep protocol audits as abstraction and conformance notes.
- Do not reintroduce implemented-vs-candidate brainstorming into this file
  unless it directly affects the manuscript rewrite.
- Do not present LLM-assisted query/profile generation as a contribution until
  it has been implemented and evaluated.
