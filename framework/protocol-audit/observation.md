# Observation Protocol Audit

This audit compares the current UPPAAL Observation models with the LwM2M Information Reporting logic.

Primary references:

- OMA LwM2M Core v1.2.2, Information Reporting Interface.
- OMA LwM2M Transport bindings for Observe/Notify and CoAP reset behavior.

## Expected LwM2M Observation Logic

At the abstraction level used in this repository, a compliant Observation flow should preserve these protocol facts:

1. The LwM2M Server initiates observation after registration.
2. The Client enters an observing relationship after receiving Observe.
3. The Client sends Notify messages to the Server when notification conditions are met.
4. The Server can end the relationship through Cancel Observation.
5. A Notify can be confirmable or non-confirmable depending on the transport/profile abstraction.
6. If the Client receives a CoAP Reset in response to Notify, it must cancel the observation.
7. Security mechanisms such as OSCORE should protect notification integrity and freshness, but should not change the core Observe/Notify causal order.

## Existing Level 3 Observation Models

### `Smc_Observation_Non_Non.xml`

Role:

- No security.
- No retransmission.
- Stochastic notification delivery with packet loss.

Protocol match:

- Preserves the main order: registered client -> observe_start -> observing -> notification -> observe_stop.
- Uses `registration_completed_count == MAX_CLIENTS` as an abstraction for "Observation only after Registration."
- Uses probabilistic success/loss branches for Notify delivery.

Important simplifications:

- `observe_stop` is sent after every received notification. In LwM2M, Cancel Observation is optional and normally ends the observation relationship; it is not required after each Notify. This is acceptable only if interpreted as "one observation cycle per selected client" rather than a long-lived observation relation.
- The initial Observe response carrying the current value is abstracted away.
- Notification attributes such as pmin, pmax, gt, lt, and step are abstracted into stochastic notification generation.
- CoAP Reset cancellation is not modeled.

Recommended adjustment:

- Rename the modeled behavior in the paper as a bounded observation cycle.
- Add a monitor/query for "fresh and on time" rather than claiming full long-lived LwM2M Observe semantics.

### `Smc_Observation_OSCORE_Non.xml`

Role:

- OSCORE/security delay.
- No retransmission.

Protocol match:

- Keeps the same core Observe/Notify causal order.
- Adds encryption/decryption delay as timing overhead.

Important simplifications:

- OSCORE is represented as timing overhead and/or a boolean guard, not as a full object/security context model.
- Freshness is not explicitly tied to a replay window in the SMC model.

Recommended adjustment:

- Treat this as a security-overhead profile, not a complete OSCORE protocol proof.

### `Smc_Observation_OSCORE_Retransmisssion.xml`

Role:

- OSCORE/security delay.
- Notify retransmission and acknowledgement.

Protocol match:

- Captures a confirmable-notification style reliability loop.
- Counts retransmissions and failures.

Important simplifications:

- Retransmission is modeled at the abstract message level, not full CoAP message ID/token behavior.
- ACK is modeled as a direct server-to-client signal after Notify is received.
- CoAP Reset is not represented.

Recommended adjustment:

- Present this as CoAP-style retransmission abstraction.
- Add an optional future extension for Reset-triggered cancellation.

## Existing Level 2 Observation Security Model

### `Oscore_Observation.xml`

Role:

- Attacker model for tamper/replay.
- OSCORE boolean protection.

Protocol match:

- Models attacker interception between Client Notify and Server receive.
- Uses sequence-like variables as a freshness abstraction.

Potential issue:

- Some guards combine `oscore_enabled` with `seq_num == expected_seq`, while attacker templates separately block tamper/replay when OSCORE is enabled. This is directionally correct, but the sequence-number abstraction is not fully aligned with real OSCORE replay-window behavior.

Recommended adjustment:

- State explicitly that OSCORE is modeled by integrity and freshness predicates, not by cryptographic detail.
- In the configurable layer, expose `freshness_protection` separately from `security_overhead`.

## Framework Refactor Rules Derived From Audit

The configurable Observation slice should expose:

- `security_mode`: `none`, `oscore`
- `security_overhead_enabled`
- `freshness_protection_enabled`
- `confirmable_notify`
- `retransmission_enabled`
- `loss_weight_success`
- `loss_weight_failure`
- `observation_deadline`
- `max_observation_cycles`

The paper should avoid claiming:

- full CoAP token/message-ID fidelity,
- complete OSCORE cryptographic verification,
- full long-lived observation semantics.

The paper can safely claim:

- preservation of the core LwM2M Observe/Notify/Cancel causal order,
- abstract integrity/freshness protection against replay and tampering,
- quantitative analysis of security overhead and retransmission under packet loss,
- industrial bounded-cycle monitoring of timely and fresh notification delivery.

## Implemented Flow Adjustment

The generated model `framework/generated/observation/Observation_LongLived_Reset.xml` implements the two most important protocol-flow improvements:

1. Notify no longer forces an immediate `observe_stop`. After an accepted Notify, the Server sends an abstract `coap_ack` and returns to `S_WAIT_NOTIFY`, preserving a long-lived Observe relation.
2. An abstract `coap_reset` path is added. When the Client receives Reset, it clears `client_observed[id]` and returns to `S_REGISTERED`.

The model remains bounded by `MAX_NOTIFICATIONS_PER_OBSERVATION`, so it should be described as a bounded monitoring instance of a long-lived Observe relation rather than an unbounded full protocol model.
