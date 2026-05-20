## ADDED Requirements

### Requirement: Mission initialises with contract parameters
The transport mission script SHALL accept contract parameters from the broker (cargo good, amount, destination sector coords, reward total, speed-bonus window) and persist them in `mission.data` at the moment of acceptance.

#### Scenario: Contract accepted at source station
- **WHEN** the player accepts a transport contract at a source station
- **THEN** `mission.data` SHALL contain `good`, `amount`, `destX`, `destY`, `destName`, `reward`, `speedBonusWindow`, and `acceptTime`

### Requirement: Phase 2 registers destination sector marker
During the in-transit phase the mission SHALL register the destination sector as a waypoint in the HUD and display the mission description in the active-mission list.

#### Scenario: Player departs source station with cargo loaded
- **WHEN** the mission enters Phase 2 (in-transit)
- **THEN** the destination sector SHALL appear as a named HUD marker readable as "Deliver [good] to [station] in sector (X:Y)"

#### Scenario: Mission description reflects cargo and destination
- **WHEN** the player opens the mission log during transit
- **THEN** the entry SHALL read "Deliver [amount]x [good] to [station] in sector (X:Y)"

### Requirement: Speed-bonus window tracked from acceptance
The mission SHALL track elapsed time from `acceptTime` and flag whether the delivery qualifies for the speed bonus.

#### Scenario: Delivery within speed-bonus window
- **WHEN** the player delivers cargo and `timePassed < speedBonusWindow`
- **THEN** the reward SHALL include an additional 30% bonus credits

#### Scenario: Delivery after speed-bonus window
- **WHEN** the player delivers cargo and `timePassed >= speedBonusWindow`
- **THEN** the base reward SHALL be paid without a speed bonus

### Requirement: Pirate ambush triggers en route for high-value shipments
When cargo value exceeds 50,000 credits, the mission SHALL trigger chance-based pirate ambushes in sectors the player jumps through while in transit, using the engine's existing sector-ambush mechanic (pirates pre-positioned and waiting on sector entry).

#### Scenario: High-value cargo triggers en-route ambush roll
- **WHEN** the player enters any sector while in Phase 2 (in-transit) and `cargoAmount × good.price > 50000`
- **THEN** there is a chance-based roll each sector entry that spawns pirates waiting in that sector via the existing ambush mechanic

#### Scenario: Low-value cargo travels without ambush
- **WHEN** the player is in Phase 2 and `cargoAmount × good.price ≤ 50000`
- **THEN** no ambush rolls occur and sectors are entered normally

#### Scenario: Pirates are pre-positioned on sector entry
- **WHEN** an ambush roll succeeds for a sector the player is jumping into
- **THEN** pirates SHALL already be present in the sector when the player arrives, using the existing Avorion ambush mechanic rather than spawning after arrival

### Requirement: Delivery dialog removes cargo and pays reward
The mission SHALL verify cargo presence, remove it via `ship:removeCargo`, and pay the calculated reward when the player docks at the destination station.

#### Scenario: Full cargo present at delivery
- **WHEN** the player docks at the destination station with the full contracted amount
- **THEN** cargo is removed, base reward plus optional speed bonus is paid, and faction relations increase by `2000 + round(amount × 3)`

#### Scenario: Partial cargo present at delivery
- **WHEN** the player docks at the destination station with less than the contracted amount
- **THEN** cargo is removed, reward is reduced proportionally to the fraction delivered, and the mission completes without failure

#### Scenario: No cargo present at delivery
- **WHEN** the player docks at the destination station with zero contracted cargo
- **THEN** the mission fails with a "cargo lost" failure message and no reward is paid

### Requirement: Mission persists across save and reload
Mission state stored in `mission.data` SHALL survive a save/load cycle so in-transit contracts are not lost when the game is restarted.

#### Scenario: Player saves mid-transit and reloads
- **WHEN** the player saves while in Phase 2 and reloads the save
- **THEN** the HUD marker, mission description, and timer state SHALL be restored correctly
