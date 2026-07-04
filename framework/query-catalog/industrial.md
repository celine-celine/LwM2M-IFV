# Industrial Scenario Query Catalog

## `industrial-policy-binding-cleanup`

Model:

```text
framework/generated/industrial/IndustrialPolicy_BindingCleanup.xml
```

Scenario:

```text
Legitimate device registration
  -> PolicyMonitor command authorization
  -> cloned duplicate endpoint rejection
  -> Deregister or abnormal offline cleanup
  -> command authorization revocation
```

Policy monitor predicates:

| Predicate | Meaning |
| --- | --- |
| `command_authorized[c]` | The industrial server or gateway may issue management commands to client `c`. |
| `policy_admission_granted[c]` | The policy monitor admitted a binding- and identity-verified device. |
| `cloned_device_rejected[c]` | The policy monitor rejected a cloned or duplicate endpoint. |
| `cloned_device_alarm` | A cloned-device alarm has been raised. |
| `stale_session_cleaned[c]` | The policy monitor cleaned a deregistered or abnormally offline device session. |
| `session_cleanup_done[c]` | A cleanup policy action has completed for client `c`. |

Queries:

| Name | verifyta index | Formula |
| --- | ---: | --- |
| `deadlock_freedom` | 0 | `A[] not deadlock` |
| `legitimate_device_authorized` | 1 | `E<> Client0.S_REGISTERED and command_authorized[0]` |
| `clone_rejected_by_policy` | 2 | `E<> duplicate_endpoint_detected and cloned_device_rejected[1]` |
| `deregister_cleanup_reachable` | 3 | `E<> deregister_ack_received[0] and stale_session_cleaned[0]` |
| `offline_cleanup_reachable` | 4 | `E<> offline_cleanup_done[0] and stale_session_cleaned[0]` |
| `commands_require_verified_active_session` | 5 | `A[] command_authorized[0] imply server_session_active[0] and binding_verified[0] and identity_binding_verified[0]` |
| `rejected_clone_not_authorized` | 6 | `A[] cloned_device_rejected[1] imply !client_registered[1] and !command_authorized[1] and cloned_device_alarm` |
| `cleanup_revokes_authorization` | 7 | `A[] stale_session_cleaned[0] imply !server_session_active[0] and !command_authorized[0]` |
| `duplicate_endpoint_is_attack_signal` | 8 | `A[] duplicate_endpoint_detected imply attack_detected` |
| `clone_never_authorized` | 9 | `A[] !command_authorized[1]` |

All ten queries are satisfied in the current industrial policy monitor scenario.
