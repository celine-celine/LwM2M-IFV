# Observation Query Catalog

This catalog records the intended query names for the profile-driven Observation slice.

## Profiles

### `observation-long-lived-reset`

Model:

```text
framework/generated/observation/Observation_LongLived_Reset.xml
```

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `deadlock_freedom` | 0 | `A[] not deadlock` |
| `workflow_completion` | 1 | `E<> ObservationHandler1.S_COMPLETED` |
| `multiple_notify_before_cancel` | 2 | `E<> notification_received[0] == MAX_NOTIFICATIONS_PER_OBSERVATION and !reset_received[0]` |
| `reset_reachable` | 3 | `E<> reset_received[0]` |
| `reset_cancels_observation` | 4 | `A[] forall(c: client_id_t) (reset_received[c] imply !client_observed[c])` |
| `bounded_notification_count` | 5 | `A[] forall(c: client_id_t) notification_received[c] <= MAX_NOTIFICATIONS_PER_OBSERVATION` |

Protocol improvement:

- A received Notify is acknowledged and the observation relation remains active.
- The server cancels only after the bounded monitoring goal is reached.
- A CoAP Reset path cancels the observation relation immediately.

### `observation-long-lived-reset-smc`

Model:

```text
framework/generated/observation/Observation_LongLived_Reset_SMC.xml
```

SMC parameters:

| Parameter | Value |
| --- | ---: |
| `NOTIFICATION_RATE` | `0.01` |
| `WEIGHT_NOTIFY_SUCCESS` | `995` |
| `WEIGHT_NOTIFY_LOSS` | `5` |
| `WEIGHT_ACK` | `990` |
| `WEIGHT_RESET` | `10` |
| `OBSERVATION_DEADLINE` | `210000` |
| `MAX_NOTIFICATIONS_PER_OBSERVATION` | `2` |

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `notification_delivery` | 6 | `Pr[<=210000; 200] (<> notification_received[0] > 0)` |
| `bounded_cycle_completion_probability` | 7 | `Pr[<=210000; 200] (<> notification_received[0] == MAX_NOTIFICATIONS_PER_OBSERVATION)` |
| `reset_probability` | 8 | `Pr[<=210000; 200] (<> reset_received[0])` |
| `expected_received` | 9 | `E[<=210000; 200] (max: notification_received[0])` |
| `expected_lost` | 10 | `E[<=210000; 200] (max: notification_lost[0])` |

Initial SMC baseline:

| Metric | Observed result |
| --- | --- |
| At least one notification delivered | `[0.981725, 1]` at 95% CI |
| Bounded cycle reaches two notifications | about `99/200` to `103/200` runs in sampled checks |
| Reset reachable probability | about `[0.00310411, 0.0432083]` at 95% CI in one run |
| Expected received notifications | `1.485 +/- 0.0698627` at 95% CI |
| Expected lost notifications | `0.005 +/- 0.00985978` at 95% CI |

### `observation-non-non`

Model:

```text
LwM2M Models/Level 3/Observation/Smc_Observation_Non_Non.xml
```

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `bounded_completion` | 1 | `Pr[<=210000; 200] (<> ObservationHandler1.S_COMPLETED)` |
| `notification_sent` | 2 | `Pr[<=210000; 200] (<> notification_sent[0] > 0)` |
| `notification_delivery` | 3 | `Pr[<=210000; 200] (<> notification_received[0] > 0)` |
| `expected_received` | 4 | `E[<=210000; 200] (max: notification_received[0])` |

### `observation-oscore-non`

Model:

```text
LwM2M Models/Level 3/Observation/Smc_Observation_OSCORE_Non.xml
```

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `expected_received` | 0 | `E[<=210000; 200] (max: notification_received[0])` |
| `notification_delivery` | 1 | `Pr[<=210000; 200] (<> notification_received[0] > 0)` |

### `observation-oscore-retransmission`

Model:

```text
LwM2M Models/Level 3/Observation/Smc_Observation_OSCORE_Retransmisssion.xml
```

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `notification_delivery` | 1 | `Pr[<=210000; 500] (<> notification_received[0] > 0)` |
| `expected_received` | 2 | `E[<=210000; 200] (max: notification_received[0])` |

## Artifact Notes

The legacy SMC XML files include:

- formula nodes used as comments,
- historical UPPAAL result and plot nodes,
- encoding-sensitive comments in declaration blocks.

Do not blindly reserialize these XML files. If query cleanup is needed, create a new generated model carefully and validate it with `verifyta` before using it in experiments.
