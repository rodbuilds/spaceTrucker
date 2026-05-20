# faction-commodity-bias Specification

## Purpose

Assign hidden Economies (formerly "archetypes") and per-faction Specialization scalars to NPC factions, and apply Specialization-adjusted, per-faction commodity price biases at the merchant boundary, so that station prices reflect each faction's economic character and the intensity of that character.

## Requirements

### Requirement: Faction archetype assignment at galaxy generation

The system SHALL assign exactly one Economy (display name; internally still "archetype" in stored keys for back-compat) to every eligible NPC faction the first time the mod observes that faction without an existing Economy assignment. The Economy value SHALL be one of a fixed set defined by the mod (initial set: Agricultural, Industrial, Mining, Refinery, Frontier, Mercantile, Militant). Pirate, smuggler, Xsotan, and other excluded faction categories SHALL NOT receive an Economy. The assignment SHALL be persisted via `Faction:setValue("trucker_archetype", <name>)` (storage key retained for compatibility with MVP saves) and SHALL NOT be recomputed on subsequent observations of the same faction.

#### Scenario: New galaxy, new faction
- **WHEN** the mod observes a faction with no `trucker_archetype` value that is not in the excluded category list
- **THEN** the system selects an Economy via the weighted-roll algorithm and writes it to `Faction:setValue("trucker_archetype", <name>)`

#### Scenario: Existing save without mod history (mid-game install)
- **WHEN** the mod is installed on a save that was generated without it
- **THEN** eligible factions receive Economy assignments lazily on first observation; pre-existing assignments are left untouched

#### Scenario: Excluded faction categories
- **WHEN** assignment is invoked against a pirate, smuggler, Xsotan, or otherwise excluded faction
- **THEN** the system SHALL skip that faction and SHALL NOT write any Economy value

#### Scenario: Idempotent re-runs
- **WHEN** assignment is invoked a second time on a faction that already has an Economy
- **THEN** the system SHALL leave the existing Economy unchanged and SHALL NOT re-roll

### Requirement: Per-faction Specialization scalar

In addition to assigning an Economy (formerly "archetype") to each eligible NPC faction, the system SHALL roll and persist a per-faction Specialization scalar in the range `[STRENGTH_MIN, STRENGTH_MAX]` (configurable; default 0.3 to 1.8). The roll SHALL be biased by the concentration of the faction's trait values (sum of absolute trait magnitudes) with a uniform-random jitter component. Specialization SHALL be persisted via `Faction:setValue("trucker_strength", <number>)` and SHALL NOT be recomputed on subsequent observations of the same faction.

#### Scenario: New assignment includes Specialization
- **WHEN** the system assigns an Economy to a faction that previously had none
- **THEN** the system SHALL also roll and persist a Specialization scalar in the configured range

#### Scenario: Existing assignment lacks Specialization (mid-iteration upgrade)
- **WHEN** a faction has an Economy persisted but no Specialization value
- **THEN** the system SHALL roll and persist a Specialization on next observation, without re-rolling the Economy

#### Scenario: Specialization is stable across observations
- **WHEN** the same faction is observed multiple times
- **THEN** the persisted Specialization SHALL remain unchanged

### Requirement: Specialization maps to a 1-5 star bucket for display

The system SHALL expose a deterministic mapping from the Specialization scalar to an integer star count in `[1, 5]` and a paired word label ("Lightly", "Modestly", "Solidly", "Heavily", "Pure"). Both the star count and the word label SHALL be derived from the same bucket boundaries, ensuring consistency across UI surfaces.

#### Scenario: Star mapping
- **WHEN** the system is asked to render Specialization for a faction
- **THEN** the scalar SHALL be mapped to a star count via the documented bucket boundaries; the same scalar SHALL always produce the same star count

#### Scenario: Label mapping
- **WHEN** the system is asked for the word label of a Specialization
- **THEN** the label SHALL match the star-count bucket (1 star = "Lightly", 5 stars = "Pure")

### Requirement: Trait-weighted archetype selection

The archetype selection roll SHALL be a weighted random draw where the weight of each archetype is influenced by the faction's vanilla traits as exposed by `Faction:getTraits()`. Traits with values closer to `1.0` SHALL increase the weight of archetypes associated with that trait; traits closer to `-1.0` (or absent) SHALL decrease them. When a faction returns an empty traits table, the system SHALL fall back to uniform random selection from the archetype set.

#### Scenario: Aggressive faction biases toward Militant/Frontier
- **WHEN** a faction's `aggressive` trait is high (>0.5)
- **THEN** the weighted-roll computation SHALL increase the weight on Militant and Frontier archetypes relative to the uniform baseline

#### Scenario: Peaceful trusting faction biases toward Agricultural
- **WHEN** a faction's `peaceful` and `trusting` traits are both high (>0.5)
- **THEN** the weighted-roll computation SHALL increase the weight on Agricultural relative to the uniform baseline

#### Scenario: Empty trait table
- **WHEN** `Faction:getTraits()` returns an empty table for a faction
- **THEN** the system SHALL perform a uniform random selection over the archetype set

### Requirement: Distribution guardrail

The galaxy-wide assignment pass SHALL enforce a maximum share for any single archetype. If applying the trait-weighted roll would cause an archetype to exceed its maximum share of the assigned-faction population, the system SHALL redistribute the affected assignment toward the next-highest-weighted eligible archetype that has not exceeded its share cap.

#### Scenario: Archetype share cap reached
- **WHEN** a faction's weighted roll selects an archetype whose share of currently-assigned factions is already at or above its cap
- **THEN** the system SHALL select the next-highest-weighted archetype that is below its cap

### Requirement: Bias table persistence and lookup

The bias multiplier for a (faction, commodity-tag) pair SHALL be derived on demand from the faction's Economy and Specialization rather than cached on the Faction entity. The derivation SHALL apply Specialization as `effective[tag] = 1 + (baseBias[tag] - 1) × specialization`, where `baseBias` is the fixed table associated with the Economy. To enable client-side price-hook reads (because `Faction:getValue` is server-only in this Avorion build), the system SHALL ALSO cache the resolved Economy name and Specialization scalar on each station-merchant entity via `Entity:setValue("trucker_station_arch", <name>)` and `Entity:setValue("trucker_station_strength", <number>)`. These entity-level values sync to clients and are read by the merchant's price hook on both sides.

#### Scenario: Bias lookup on server
- **WHEN** a station price hook is invoked on the server
- **THEN** the system SHALL read the Economy and Specialization from the entity-level cache and SHALL compute the effective bias multiplier on demand

#### Scenario: Bias lookup on client
- **WHEN** a station price hook is invoked on the client (e.g. for UI price display)
- **THEN** the system SHALL read the Economy and Specialization from the entity-level cache and compute the same multiplier the server uses, eliminating UI/transaction desync

#### Scenario: Specialization absent at station load
- **WHEN** a station entity's owning faction has an Economy but no Specialization persisted
- **THEN** the system SHALL default Specialization to 1.0 for that entity's cache and SHALL trigger a server-side roll on the faction at next opportunity

### Requirement: Server-side price modification at merchant boundary

The system SHALL apply the Specialization-adjusted bias as a multiplicative final layer on station buy and sell prices for stations owned by Economy-assigned factions. The vanilla price formula (including stock-based elasticity) SHALL be evaluated first; the bias multiplier SHALL be applied to the result. The hook SHALL be installed at the price-getter boundary of every merchant script that exposes price-affecting calls (factory, tradingpost, consumer-derived merchants, seller, smugglersmarket, planetarytradingpost). Both client and server SHALL produce identical biased prices via the entity-level Economy/Specialization cache.

#### Scenario: Buy price modification
- **WHEN** a station owned by an Economy-assigned faction returns a buy price for a commodity
- **THEN** the price returned to client and AI consumers SHALL equal `vanilla_price × effectiveBias[commodity_category]`

#### Scenario: Sell price modification
- **WHEN** a station owned by an Economy-assigned faction returns a sell price for a commodity
- **THEN** the price returned SHALL equal `vanilla_price × effectiveBias[commodity_category]`

#### Scenario: Client and server agree
- **WHEN** the client renders a price and the server validates the corresponding transaction
- **THEN** both SHALL produce the same biased price; no desync SHALL exist between displayed and charged amounts

#### Scenario: Commodity not in bias table
- **WHEN** a commodity's category has no entry in the Economy's bias table
- **THEN** the multiplier SHALL be `1.0` and the vanilla price SHALL pass through unchanged
