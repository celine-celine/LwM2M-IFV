# Bootstrap Query Catalog

## `bootstrap-core`

Model:

```text
framework/generated/bootstrap/Bootstrap_Core.xml
```

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `deadlock_freedom` | 0 | `A[] not deadlock` |
| `both_clients_bootstrap` | 1 | `E<> Client0.S_BOOTSTRAP_DONE and Client1.S_BOOTSTRAP_DONE` |
| `bootstrap_requires_verified_config` | 2 | `A[] forall(c: client_id_t) (client_bootstrapped[c] imply config_verified[c])` |
| `fake_config_rejected` | 3 | `A[] forall(c: client_id_t) (fake_config_received[c] imply client_error[c])` |
| `tampered_config_rejected` | 4 | `A[] forall(c: client_id_t) (message_tampered[c] imply client_error[c])` |
| `dtls_blocks_fake_and_tamper` | 5 | `A[] forall(c: client_id_t) (DTLS_ENABLED imply !(fake_config_received[c] or message_tampered[c]))` |

All six queries are satisfied in the current Bootstrap core profile.

## `bootstrap-no-dtls-attack`

Model:

```text
framework/generated/bootstrap/Bootstrap_NoDTLS_Attack.xml
```

Important queries:

| Name | verifyta index | Observed result |
| --- | ---: | --- |
| `deadlock_freedom` | 0 | satisfied |
| `both_clients_bootstrap` | 1 | not satisfied, expected for attack-only profile |
| `fake_config_reachable_and_rejected` | 6 | satisfied |
| `tampered_config_reachable_and_rejected` | 7 | satisfied |
| `only_valid_config_bootstraps` | 8 | satisfied |

This profile is intended to show attack reachability and safe rejection, not successful onboarding.

## `bootstrap-smc`

Model:

```text
framework/generated/bootstrap/Bootstrap_SMC.xml
```

SMC parameters:

| Parameter | Value |
| --- | ---: |
| `DTLS_HANDSHAKE_DELAY` | `100` |
| `BOOTSTRAP_DEADLINE` | `21000` |
| `ACK_TIMEOUT` | `2000` |
| `MAX_RETRANSMIT` | `4` |
| `WEIGHT_CONFIG_SUCCESS` | `995` |
| `WEIGHT_CONFIG_LOSS` | `5` |

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `bootstrap_success_probability` | 0 | `Pr[<=21000; 200] (<> client_bootstrapped[0])` |
| `bootstrap_failure_probability` | 1 | `Pr[<=21000; 200] (<> bootstrap_failed[0])` |
| `expected_retransmission_count` | 2 | `E[<=21000; 200] (max: retransmission_count[0])` |
| `expected_config_loss_count` | 3 | `E[<=21000; 200] (max: config_loss_count[0])` |

Initial SMC baseline:

| Metric | Observed result |
| --- | --- |
| Bootstrap success probability | `[0.981725, 1]` at 95% CI |
| Bootstrap failure probability | `[0, 0.0182753]` at 95% CI |
| Expected retransmission count | `0.01 +/- 0.0139088` at 95% CI |
| Expected config loss count | `0.01 +/- 0.0139088` at 95% CI |
