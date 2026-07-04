# LwM2M-IFV Framework

This directory is a non-invasive scaffold around the UPPAAL models in
`../LwM2M Models/`. It contains profile entry points, generated framework
models, query catalogs, and protocol-audit notes for the revised manuscript.

The framework follows the current three-layer paper structure:

1. **Protocol Core Layer**: reusable lifecycle behavior for Bootstrap,
   Registration, Registration Update, Deregister/offline cleanup, and
   Observation.
2. **Configurable Profile Layer**: security, attacker, timing, loss,
   retransmission, and SMC reliability variants.
3. **Industrial Scenario Layer**: policy-monitor predicates for command
   authorization, cloned-device rejection, stale-session cleanup, and telemetry
   freshness.

Use `../FRAMEWORK_REFACTOR_PLAN.md` as the master manuscript revision plan.
This README is only the framework entry point.

## Profile Commands

Run profiles through the helper script:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\<profile>.json
```

### Observation

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\observation-long-lived-reset.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\observation-long-lived-reset-smc.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\observation-non-non.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\observation-oscore-non.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\observation-oscore-retransmission.json
```

Evidence:

- `framework/query-catalog/observation.md`
- `framework/protocol-audit/observation.md`

### Bootstrap

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\bootstrap-core.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\bootstrap-no-dtls-attack.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\bootstrap-smc.json
```

Evidence:

- `framework/query-catalog/bootstrap.md`
- `framework/protocol-audit/bootstrap.md`

### Registration

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-core.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-attack.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-smc.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-lifecycle.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-bootstrap-binding.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-identity-binding.json
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\registration-deregister-offline.json
```

Evidence:

- `framework/query-catalog/registration.md`
- `framework/protocol-audit/registration.md`

### Industrial Scenario

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_framework_profile.ps1 -Profile .\framework\profiles\industrial-policy-binding-cleanup.json
```

Evidence:

- `framework/query-catalog/industrial.md`

The current industrial model introduces a lightweight `PolicyMonitor` automaton
that maps lifecycle/profile evidence to operational decisions. It is the main
model evidence for the Industrial Scenario Layer in the revised paper.
