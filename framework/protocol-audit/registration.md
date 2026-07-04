# Registration Protocol Audit

This audit compares the generated Registration models with the LwM2M Registration interface at the abstraction level used in this framework.

## Expected LwM2M Registration Logic

At framework level, Registration should preserve these protocol facts:

1. A Client registers only after bootstrap or local provisioning has completed.
2. The Client sends a Register request to the LwM2M Server.
3. The Register exchange includes the Client endpoint identity and supported object/object-instance list.
4. The Server accepts registration only after receiving the required object list.
5. Message freshness should prevent replayed Register requests from being accepted.
6. A replayed registration attempt should be detected or rejected when freshness protection is active.
7. DoS attempts should be represented separately from successful registration, for example through throttling or service recovery states.
8. Security mechanisms such as DTLS are abstracted as protection against replay and unauthorized registration effects, not as cryptographic proof.
9. A Registration Server identity or credential provisioned during Bootstrap should bind later Registration admission.
10. Duplicate endpoint identities should not allow a cloned device to overwrite or impersonate the legitimate registered endpoint owner.
11. Explicit Deregister and abnormal offline cleanup should remove server sessions and disable command authorization.

## Existing Model Notes

The existing Level 2 Registration models already contain separate variants for:

- replay attack behavior,
- DoS attack behavior,
- DTLS-protected registration,
- simplified message-id checks.

Some original logic is specialized per model and uses fixed attack/security choices. The generated framework profiles make those choices explicit as profile parameters and keep the core Registration procedure reusable.

## Generated Core Model

Model:

```text
framework/generated/registration/Registration_Core.xml
```

This generated model is a clean Registration core profile with:

- two clients,
- one Registration Server,
- bootstrap completion as a prerequisite,
- Register and object-list phases,
- server-side message-id freshness,
- a simple multi-client turn variable to avoid artificial server/client races.

Verified properties:

| Property | Meaning |
| --- | --- |
| `A[] not deadlock` | The Registration workflow is deadlock-free. |
| `E<> Client0.S_REGISTERED and Client1.S_REGISTERED` | Both clients can complete registration. |
| `A[] forall(c) client_registered[c] imply bootstrap_completed[c]` | Registration requires prior bootstrap/provisioning. |
| `A[] forall(c) client_registered[c] imply object_list_received[c]` | A registered client must have sent its object list. |
| `A[] forall(c) client_registered[c] imply server_last_msg_id[c] == client_message_id[c]` | The server records the current client message id. |

## Attack Profile

Model:

```text
framework/generated/registration/Registration_Attack.xml
```

This profile sets `DTLS_ENABLED = false` and enables replay and DoS attackers. The server:

- detects replayed Register messages,
- detects DoS attempts,
- activates throttling after `MAX_DOS_ATTACKS`,
- recovers from attack-detection states before accepting a normal client request.

The recovery edge is important: it models an industrial gateway/server that filters the attack and returns to a controlled waiting state, instead of confusing attack reachability with permanent model deadlock.

## SMC Reliability Profile

Model:

```text
framework/generated/registration/Registration_SMC.xml
```

This profile adds:

- DTLS delay,
- probabilistic Register request loss,
- probabilistic object-list loss,
- ACK timeout,
- retransmission limit,
- a registration/admission deadline.

Current parameters:

```text
DTLS_DELAY = 50
REGISTRATION_DEADLINE = 21000
ACK_TIMEOUT = 2000
MAX_RETRANSMIT = 4
WEIGHT_REGISTER_SUCCESS = 995
WEIGHT_REGISTER_LOSS = 5
WEIGHT_OBJECT_SUCCESS = 995
WEIGHT_OBJECT_LOSS = 5
```

## Lifecycle Profile

Model:

```text
framework/generated/registration/Registration_Lifecycle.xml
```

This profile extends initial Registration with two LwM2M lifecycle facts:

- a registered Client can send Registration Update before its lifetime expires;
- if no timely Update is performed, the Server expires the stale registration and disables command authorization.

Current parameters:

```text
LIFETIME = 100
UPDATE_EARLY = 60
MAX_UPDATES = 2
```

The `MAX_UPDATES` bound keeps the model finite while still covering repeated renewal cycles. In the paper this should be described as bounded lifecycle verification.

Verified properties:

| Property | Meaning |
| --- | --- |
| `A[] not deadlock` | The lifecycle workflow is deadlock-free. |
| `E<> update_ack_received[0]` | Registration Update can renew the session lifetime. |
| `E<> lifetime_expired[0]` | A stale registration can expire if Update is not performed in time. |
| `A[] lifetime_expired[0] imply !server_session_active[0]` | Expired registrations cannot remain active sessions. |
| `A[] command_authorized[0] imply server_session_active[0] and !lifetime_expired[0]` | Commands are authorized only for active non-expired registrations. |
| `A[] (lifetime_renewed[0] and !lifetime_expired[0]) imply client_registered[0]` | A renewed non-expired lifetime belongs to a registered client. |
| `E<> update_count[0] == MAX_UPDATES and server_session_active[0]` | The bounded model covers multiple successful Update cycles. |

## Bootstrap-to-Registration Binding Profile

Model:

```text
framework/generated/registration/Registration_BootstrapBinding.xml
```

This profile connects Bootstrap and Registration by requiring the Registration server identity and credential to match the values provisioned during Bootstrap.

Current profile constants:

```text
BINDING_ENABLED = true
AUTHORIZED_SERVER_ID = 10
ROGUE_SERVER_ID = 99
BOOTSTRAPPED_CREDENTIAL = 700
ROGUE_CREDENTIAL = 999
```

The model includes both a valid path and a rogue-registration path:

- a correctly bound client can complete Registration and receive command authorization;
- a client attempting to register with a rogue server identity or credential mismatch triggers a binding violation and is rejected.

Verified properties:

| Property | Meaning |
| --- | --- |
| `A[] not deadlock` | The binding workflow is deadlock-free. |
| `E<> Client0.S_REGISTERED and binding_verified[0]` | A correctly bound client can register. |
| `E<> binding_violation[0] and registration_rejected[0]` | A rogue Registration binding is reachable and rejected. |
| `A[] client_registered[0] imply registration_server_id[0] == bootstrapped_server_id[0]` | Registered clients use the bootstrapped server identity. |
| `A[] client_registered[0] imply registration_credential[0] == bootstrapped_credential[0]` | Registered clients use the bootstrapped credential. |
| `A[] command_authorized[0] imply client_registered[0] and binding_verified[0]` | Industrial commands require successful binding. |
| `A[] binding_violation[0] imply !rogue_registration_accepted[0]` | Binding violations cannot be accepted as rogue registrations. |

## Duplicate Endpoint / Identity Binding Profile

Model:

```text
framework/generated/registration/Registration_IdentityBinding.xml
```

This profile models a cloned-device attempt:

- `Client0` is the legitimate endpoint owner.
- `Client1` presents the same endpoint id but a mismatched identity secret.
- The server detects the duplicate endpoint and rejects the clone.
- The legitimate endpoint owner remains bound to the server-side session.

Current profile constants:

```text
IDENTITY_BINDING_ENABLED = true
DUPLICATE_ENDPOINT_DETECTION_ENABLED = true
DUPLICATE_ENDPOINT_ID = 0
LEGIT_SECRET = 321
CLONE_SECRET = 999
```

Verified properties:

| Property | Meaning |
| --- | --- |
| `A[] not deadlock` | The identity-binding workflow is deadlock-free. |
| `E<> Client0.S_REGISTERED and identity_binding_verified[0]` | The legitimate endpoint owner can register. |
| `E<> duplicate_endpoint_detected and Client1.S_REJECTED` | A cloned duplicate endpoint is reachable and rejected. |
| `A[] duplicate_endpoint_detected imply attack_detected` | Duplicate endpoint detection raises an attack flag. |
| `A[] duplicate_endpoint_detected imply !client_registered[1]` | The cloned endpoint cannot become registered. |
| `A[] client_registered[0] imply server_session_owner[endpoint_id[0]] == OWNER_CLIENT0` | The legitimate device owns its endpoint session after registration. |
| `A[] server_session_owner[DUPLICATE_ENDPOINT_ID] == OWNER_CLIENT0 imply !command_authorized[1]` | The clone cannot receive command authorization after the legitimate owner is bound. |
| `A[] command_authorized[0] imply identity_binding_verified[0] and server_session_owner[endpoint_id[0]] == OWNER_CLIENT0` | Command authorization requires successful identity binding and preserved endpoint ownership. |

## Deregister / Abnormal Offline Cleanup Profile

Model:

```text
framework/generated/registration/Registration_DeregisterOffline.xml
```

This profile completes the Registration lifecycle with two removal paths:

- explicit LwM2M Deregister followed by server-side session cleanup;
- abnormal device offline followed by cleanup policy enforcement.

Current profile constants:

```text
CLEANUP_POLICY_ENABLED = true
```

Verified properties:

| Property | Meaning |
| --- | --- |
| `A[] not deadlock` | The Deregister/offline cleanup workflow is deadlock-free. |
| `E<> deregister_ack_received[0]` | A registered client can explicitly deregister. |
| `E<> offline_cleanup_done[0]` | The server can clean up an abnormally offline device. |
| `A[] deregister_ack_received[0] imply !server_session_active[0]` | Deregistered devices cannot retain active server sessions. |
| `A[] offline_cleanup_done[0] imply !server_session_active[0]` | Offline-cleaned devices cannot retain active server sessions. |
| `A[] command_authorized[0] imply server_session_active[0] and !deregister_ack_received[0] and !offline_cleanup_done[0]` | Commands are authorized only before cleanup. |
| `A[] deregister_ack_received[0] imply !command_authorized[0]` | Deregister cleanup disables command authorization. |
| `A[] offline_cleanup_done[0] imply !command_authorized[0]` | Abnormal offline cleanup disables command authorization. |

## Simplifications

The model abstracts away:

- exact CoAP method codes and response codes,
- endpoint name string content,
- detailed Object/Instance/Resource structures,
- detailed Registration Update payloads and binding-mode changes,
- detailed Deregister response codes and offline detection timers,
- DTLS handshake internals,
- server-side account/ACL database details.
- full credential formats and certificate-chain validation.
- detailed endpoint-name string comparison and server-side persistent database behavior.

The paper should describe this as a configurable timed-automata abstraction of Registration safety/reliability, not a byte-level implementation of the LwM2M specification.

## Next Extensions

Useful follow-up profiles:

1. `registration-industrial-gateway`: model an edge gateway admitting multiple shopfloor devices under deadline and DoS pressure.
2. `registration-integrated-lifecycle`: compose Bootstrap binding, identity binding, Update, Deregister, and offline cleanup into one larger end-to-end model if the paper needs a single showcase model.
