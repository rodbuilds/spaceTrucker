## ADDED Requirements

### Requirement: Broker selects a valid destination sector
The transport broker script SHALL select a destination sector 5–30 sectors away from the source station, preferring same-faction territory, using `SectorSpecifics:getShuffledCoordinates()`.

#### Scenario: Same-faction destination found within range
- **WHEN** the broker generates a contract
- **THEN** the destination sector SHALL be within 5–30 sector distance and owned by the same faction as the source station when one exists in range

#### Scenario: No same-faction sector in range
- **WHEN** no same-faction sector exists within the 5–30 sector band
- **THEN** the broker SHALL fall back to any non-pirate sector within the distance band

#### Scenario: No valid sector found at all
- **WHEN** no valid destination sector can be found in the distance band
- **THEN** no contract is generated and the bulletin-board entry for this station is suppressed this session

### Requirement: Broker selects cargo type by station archetype
The broker SHALL choose cargo goods appropriate to the station type: manufactured goods (medicine, electronics, food) for Trading Posts; raw materials scaled by sector ring for Resource Depots; production-matched goods for Factories; consumer goods for Habitats and Biotopes.

#### Scenario: Trading Post cargo selection
- **WHEN** the broker runs on a Trading Post station
- **THEN** the contracted cargo SHALL be drawn from the manufactured goods bucket (medicine, electronics, food)

#### Scenario: Resource Depot outer-ring cargo selection
- **WHEN** the broker runs on a Resource Depot in the outer ring (sector distance > 400 from galaxy center)
- **THEN** the contracted cargo SHALL be a low-tier raw material (iron, titanium, naonite)

#### Scenario: Resource Depot inner-ring cargo selection
- **WHEN** the broker runs on a Resource Depot in the inner ring (sector distance < 200)
- **THEN** the contracted cargo SHALL be a high-tier raw material (ogonite, avorion)

#### Scenario: Factory cargo selection fallback
- **WHEN** the broker runs on a Factory and the factory production type cannot be determined
- **THEN** the contracted cargo SHALL fall back to the manufactured goods bucket

### Requirement: Cargo amount scales to player free space and sector ring
The broker SHALL size the cargo amount within zone-appropriate bounds capped at a fraction of the player's free cargo space.

#### Scenario: Outer-ring contract sizing
- **WHEN** the broker generates a contract in the outer ring
- **THEN** cargo amount SHALL be `random(50, 200)` capped at `min(200, floor(freeSpace × 0.60))`

#### Scenario: Mid-ring contract sizing
- **WHEN** the broker generates a contract in the mid ring
- **THEN** cargo amount SHALL be `random(40, 150)` capped at `min(150, floor(freeSpace × 0.50))`

#### Scenario: Inner-ring contract sizing
- **WHEN** the broker generates a contract in the inner ring
- **THEN** cargo amount SHALL be `random(20, 80)` capped at `min(80, floor(freeSpace × 0.40))`

### Requirement: Insufficient cargo space shows refusal dialog
When the player's free cargo space is less than the minimum cargo amount for the zone, the broker SHALL present a refusal dialog and NOT start the mission.

#### Scenario: Player ship has insufficient space
- **WHEN** the player opens the contract dialog and free cargo space < minimum amount for the zone
- **THEN** the broker SHALL display: "We need [amount] units transported. Your ship has only [free] units free." with options "I'll come back with a larger ship" and "Not interested" — no accept option is shown

#### Scenario: Player returns with sufficient space
- **WHEN** the player re-opens the contract dialog after increasing cargo space above the minimum
- **THEN** the accept option SHALL be available

### Requirement: Broker loads cargo and initiates mission on accept
On player acceptance the broker SHALL call `ship:addCargo(good, amount)`, send a confirmation mail, and hand control to the transport mission script.

#### Scenario: Contract accepted with sufficient space
- **WHEN** the player selects the accept option in the contract dialog
- **THEN** `ship:addCargo` is called with the contracted good and amount, a mail is sent with contract details, and `transportmission.lua` is started with the serialised contract parameters
