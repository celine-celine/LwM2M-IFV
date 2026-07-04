# Bootstrap Protocol Audit

This audit compares the Bootstrap generated model with the LwM2M Bootstrap interface at the abstraction level used in this framework.

## Expected LwM2M Bootstrap Logic

At framework level, Bootstrap should preserve these protocol facts:

1. A Client starts in an unconfigured or initial state.
2. The Client initiates Bootstrap with a Bootstrap Server.
3. The Bootstrap Server provisions security/server configuration objects.
4. The Client verifies and stores the received configuration.
5. A Client is considered bootstrapped only after accepting a valid configuration.
6. A fake Bootstrap Server or tampered configuration must not lead to successful bootstrap.
7. Security mechanisms such as DTLS should abstractly provide server authentication and protect the Bootstrap exchange from MITM/fake-server tampering.

## Existing Model Notes

The existing Level 2 Bootstrap models already capture:

- MITM interception and tampered configuration.
- Fake Bootstrap Server behavior.
- Eavesdropping flags.
- DTLS-enabled protection that blocks fake/tampered configuration.

Several query outcomes depend on manually fixed configuration variables such as `attack_mode` and `dtls_enabled`. This is a strong motivation for the profile layer.

## Generated Core Model

Model:

```text
framework/generated/bootstrap/Bootstrap_Core.xml
```

This generated model is a clean Bootstrap core profile with:

- two clients,
- one Bootstrap Server,
- one Fake Bootstrap Server template,
- one MITM tamper template,
- a DTLS-enabled profile flag,
- client-side configuration verification.

Current profile constants:

```text
DTLS_ENABLED = true
MITM_ENABLED = true
FAKE_BS_ENABLED = true
```

With `DTLS_ENABLED = true`, fake and tampered configuration paths are guarded out. This means the current model is a protected Bootstrap core, not an attack-success profile.

## Verified Properties

| Property | Meaning |
| --- | --- |
| `A[] not deadlock` | The Bootstrap workflow is deadlock-free. |
| `E<> Client0.S_BOOTSTRAP_DONE and Client1.S_BOOTSTRAP_DONE` | Both clients can complete Bootstrap. |
| `A[] forall(c) client_bootstrapped[c] imply config_verified[c]` | Successful Bootstrap requires verified configuration. |
| `A[] forall(c) fake_config_received[c] imply client_error[c]` | Fake config is rejected. |
| `A[] forall(c) message_tampered[c] imply client_error[c]` | Tampered config is rejected. |
| `A[] forall(c) DTLS_ENABLED imply !(fake_config_received[c] or message_tampered[c])` | DTLS blocks fake/tampered config paths. |

## Simplifications

The model abstracts away:

- exact LwM2M Security Object and Server Object content,
- detailed CoAP message codes,
- cryptographic details of DTLS,
- credential storage formats,
- bootstrap delete/write operation granularity.

The paper should state that DTLS is modeled through authentication/integrity effects, not cryptographic proof.

## Next Extensions

Useful follow-up profiles:

1. `bootstrap-no-dtls-attack`: set `DTLS_ENABLED = false` and show fake/tampered config reaches `S_ERROR` rather than successful bootstrap.
2. `bootstrap-smc`: add packet loss, timeout, retransmission, and DTLS handshake delay.
3. `bootstrap-industrial-onboarding`: add onboarding deadline and probability of successful shopfloor device admission.

## Implemented Extensions

Two extensions have been added:

1. `framework/generated/bootstrap/Bootstrap_NoDTLS_Attack.xml`
   - Sets `DTLS_ENABLED = false`.
   - Uses an attack-only profile to show fake/tampered configurations are reachable.
   - Verifies that reachable invalid configurations are rejected and do not lead to successful bootstrap.

2. `framework/generated/bootstrap/Bootstrap_SMC.xml`
   - Adds DTLS handshake delay, configuration loss, timeout, retransmission, and onboarding deadline.
   - Provides SMC queries for bootstrap success probability, failure probability, expected retransmissions, and expected configuration losses.
