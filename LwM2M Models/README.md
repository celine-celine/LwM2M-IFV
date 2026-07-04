# LwM2M Models

This repository contains UPPAAL XML models for the LwM2M (Lightweight Machine-to-Machine) protocol. The models are organized into three levels according to modeling complexity and protocol detail.

## Directory Structure

```text
LwM2M Models/
|-- Level 1/
|   `-- BaselineModel.xml
|-- Level 2/
|   |-- Bootstrap/
|   |-- Observation/
|   `-- Registration/
`-- Level 3/
    |-- Bootstrap/
    |-- Observation/
    `-- Registration/
```

## Model Overview

### Level 1

- `BaselineModel.xml`: A baseline model that describes the main LwM2M protocol flow and core states.

### Level 2

Level 2 models are organized by protocol procedure and include attacker behavior.

- `Bootstrap/`
  - `DTLS_Bootstrap.xml`
  - `Attacker_Bootstrap.xml`
- `Registration/`
  - `DTLS_Registration.xml`
  - `Attacker_Registration.xml`
- `Observation/`
  - `Oscore_Observation.xml`
  - `Attacker_Observation.xml`

### Level 3

Level 3 models provide more detailed protocol interactions, including sequential flows, retransmission scenarios, and refined security behavior.

- `Bootstrap/Smc_Seq_Bootstrap.xml`
- `Registration/smc_seq_registration.xml`
- `Observation/`
  - `Smc_Observation_Non_Non.xml`
  - `Smc_Observation_OSCORE_Non.xml`
  - `Smc_Observation_OSCORE_Retransmisssion.xml`

## Usage

1. Open the required `.xml` model file with UPPAAL.
2. Select a model level based on the analysis goal:
   - Level 1: Basic protocol flow.
   - Level 2: Specific procedures, security mechanisms, or attacker models.
   - Level 3: Detailed protocol interactions and state transitions.
3. Run simulation or verification queries in UPPAAL to check whether the model behavior matches the expected properties.

