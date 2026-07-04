# Registration Query Catalog

## `registration-core`

Model:

```text
framework/generated/registration/Registration_Core.xml
```

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `deadlock_freedom` | 0 | `A[] not deadlock` |
| `both_clients_register` | 1 | `E<> Client0.S_REGISTERED and Client1.S_REGISTERED` |
| `registration_requires_bootstrap` | 2 | `A[] forall(c: client_id_t) (client_registered[c] imply bootstrap_completed[c])` |
| `registration_requires_object_list` | 3 | `A[] forall(c: client_id_t) (client_registered[c] imply object_list_received[c])` |
| `registered_message_id_is_current` | 4 | `A[] forall(c: client_id_t) (client_registered[c] imply server_last_msg_id[c] == client_message_id[c])` |

All five queries are satisfied in the current Registration core profile.

## `registration-attack`

Model:

```text
framework/generated/registration/Registration_Attack.xml
```

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `deadlock_freedom` | 0 | `A[] not deadlock` |
| `replay_reachable_and_detected` | 1 | `E<> replay_message_detected and attack_detected` |
| `dos_throttling_reachable` | 2 | `E<> dos_throttling_active` |
| `replay_implies_detection` | 3 | `A[] (replay_message_detected imply attack_detected)` |
| `dos_throttling_implies_detection` | 4 | `A[] (dos_throttling_active imply attack_detected)` |

All five queries are satisfied in the current attack profile.

## `registration-smc`

Model:

```text
framework/generated/registration/Registration_SMC.xml
```

SMC parameters:

| Parameter | Value |
| --- | ---: |
| `DTLS_DELAY` | `50` |
| `REGISTRATION_DEADLINE` | `21000` |
| `ACK_TIMEOUT` | `2000` |
| `MAX_RETRANSMIT` | `4` |
| `WEIGHT_REGISTER_SUCCESS` | `995` |
| `WEIGHT_REGISTER_LOSS` | `5` |
| `WEIGHT_OBJECT_SUCCESS` | `995` |
| `WEIGHT_OBJECT_LOSS` | `5` |

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `registration_success_probability` | 0 | `Pr[<=21000; 200] (<> client_registered[0])` |
| `registration_failure_probability` | 1 | `Pr[<=21000; 200] (<> registration_failed[0])` |
| `expected_retransmission_count` | 2 | `E[<=21000; 200] (max: retransmission_count[0])` |
| `expected_lost_registration_messages` | 3 | `E[<=21000; 200] (max: register_loss_count[0] + object_loss_count[0])` |

Initial SMC baseline:

| Metric | Observed result |
| --- | --- |
| Registration success probability | `[0.981725, 1]` at 95% CI |
| Registration failure probability | `[0, 0.0182753]` at 95% CI |
| Expected retransmission count | `0.02 +/- 0.0195704` at 95% CI |
| Expected lost registration messages | `0.02 +/- 0.0195704` at 95% CI |

## `registration-lifecycle`

Model:

```text
framework/generated/registration/Registration_Lifecycle.xml
```

Lifecycle parameters:

| Parameter | Value |
| --- | ---: |
| `LIFETIME` | `100` |
| `UPDATE_EARLY` | `60` |
| `MAX_UPDATES` | `2` |

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `deadlock_freedom` | 0 | `A[] not deadlock` |
| `update_reachable` | 1 | `E<> update_ack_received[0]` |
| `expiration_reachable` | 2 | `E<> lifetime_expired[0]` |
| `expired_session_inactive` | 3 | `A[] lifetime_expired[0] imply !server_session_active[0]` |
| `commands_require_active_session` | 4 | `A[] command_authorized[0] imply server_session_active[0] and !lifetime_expired[0]` |
| `renewed_session_is_registered` | 5 | `A[] (lifetime_renewed[0] and !lifetime_expired[0]) imply client_registered[0]` |
| `bounded_multiple_updates` | 6 | `E<> update_count[0] == MAX_UPDATES and server_session_active[0]` |

All seven queries are satisfied in the current lifecycle profile.

## `registration-bootstrap-binding`

Model:

```text
framework/generated/registration/Registration_BootstrapBinding.xml
```

Binding constants:

| Parameter | Value |
| --- | ---: |
| `BINDING_ENABLED` | `true` |
| `AUTHORIZED_SERVER_ID` | `10` |
| `ROGUE_SERVER_ID` | `99` |
| `BOOTSTRAPPED_CREDENTIAL` | `700` |
| `ROGUE_CREDENTIAL` | `999` |

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `deadlock_freedom` | 0 | `A[] not deadlock` |
| `bound_registration_reachable` | 1 | `E<> Client0.S_REGISTERED and binding_verified[0]` |
| `binding_violation_rejected` | 2 | `E<> binding_violation[0] and registration_rejected[0]` |
| `registered_server_identity_matches_bootstrap` | 3 | `A[] client_registered[0] imply registration_server_id[0] == bootstrapped_server_id[0]` |
| `registered_credential_matches_bootstrap` | 4 | `A[] client_registered[0] imply registration_credential[0] == bootstrapped_credential[0]` |
| `commands_require_binding` | 5 | `A[] command_authorized[0] imply client_registered[0] and binding_verified[0]` |
| `binding_violation_not_accepted` | 6 | `A[] binding_violation[0] imply !rogue_registration_accepted[0]` |

All seven queries are satisfied in the current Bootstrap-to-Registration binding profile.

## `registration-identity-binding`

Model:

```text
framework/generated/registration/Registration_IdentityBinding.xml
```

Identity-binding constants:

| Parameter | Value |
| --- | ---: |
| `IDENTITY_BINDING_ENABLED` | `true` |
| `DUPLICATE_ENDPOINT_DETECTION_ENABLED` | `true` |
| `DUPLICATE_ENDPOINT_ID` | `0` |
| `LEGIT_SECRET` | `321` |
| `CLONE_SECRET` | `999` |

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `deadlock_freedom` | 0 | `A[] not deadlock` |
| `legitimate_registration_reachable` | 1 | `E<> Client0.S_REGISTERED and identity_binding_verified[0]` |
| `duplicate_endpoint_rejected` | 2 | `E<> duplicate_endpoint_detected and Client1.S_REJECTED` |
| `duplicate_endpoint_implies_attack` | 3 | `A[] duplicate_endpoint_detected imply attack_detected` |
| `clone_cannot_register` | 4 | `A[] duplicate_endpoint_detected imply !client_registered[1]` |
| `legitimate_owner_preserved` | 5 | `A[] client_registered[0] imply server_session_owner[endpoint_id[0]] == OWNER_CLIENT0` |
| `clone_not_authorized` | 6 | `A[] server_session_owner[DUPLICATE_ENDPOINT_ID] == OWNER_CLIENT0 imply !command_authorized[1]` |
| `commands_require_identity_binding` | 7 | `A[] command_authorized[0] imply identity_binding_verified[0] and server_session_owner[endpoint_id[0]] == OWNER_CLIENT0` |

All eight queries are satisfied in the current identity-binding profile.

## `registration-deregister-offline`

Model:

```text
framework/generated/registration/Registration_DeregisterOffline.xml
```

Cleanup constants:

| Parameter | Value |
| --- | ---: |
| `CLEANUP_POLICY_ENABLED` | `true` |

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `deadlock_freedom` | 0 | `A[] not deadlock` |
| `deregister_reachable` | 1 | `E<> deregister_ack_received[0]` |
| `offline_cleanup_reachable` | 2 | `E<> offline_cleanup_done[0]` |
| `deregister_removes_session` | 3 | `A[] deregister_ack_received[0] imply !server_session_active[0]` |
| `offline_cleanup_removes_session` | 4 | `A[] offline_cleanup_done[0] imply !server_session_active[0]` |
| `commands_require_uncleaned_active_session` | 5 | `A[] command_authorized[0] imply server_session_active[0] and !deregister_ack_received[0] and !offline_cleanup_done[0]` |
| `deregister_disables_commands` | 6 | `A[] deregister_ack_received[0] imply !command_authorized[0]` |
| `offline_cleanup_disables_commands` | 7 | `A[] offline_cleanup_done[0] imply !command_authorized[0]` |

All eight queries are satisfied in the current Deregister/offline cleanup profile.
