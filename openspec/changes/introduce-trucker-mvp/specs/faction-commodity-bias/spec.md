## ADDED Requirements

### Requirement: Faction archetype assignment at galaxy generation

The system SHALL assign exactly one economic archetype to every eligible NPC faction the first time the mod observes that faction without an existing archetype assignment. The archetype value SHALL be one of a fixed set defined by the mod (initial set: Agricultural, Industrial, Mining, Refinery, Frontier, Mercantile, Militant). Pirate, smuggler, Xsotan, and other excluded faction categories SHALL NOT receive an archetype. The assignment SHALL be persisted via `Faction:setValue("trucker_archetype", <name>)` and SHALL NOT be recomputed on subsequent observations of the same faction.

#### Scenario: New galaxy, new faction
- **WHEN** the mod runs its galaxy initialization pass on a faction that has no `trucker_archetype` value and is not in the excluded category list
- **THEN** the system selects an archetype via the weighted-roll algorithm and writes it to `Faction:setValue("trucker_archetype", <name>)`

#### Scenario: Existing save without mod history (mid-game install)
- **WHEN** the mod is installed on a save that was generated without it and the server starts
- **THEN** the backfill pass iterates all eligible factions, assigns archetypes to those lacking one, and leaves any pre-existing archetype assignments untouched

#### Scenario: Excluded faction categories
- **WHEN** the assignment pass encounters a pirate, smuggler, Xsotan, or otherwise excluded faction
- **THEN** the system SHALL skip that faction and SHALL NOT write any `trucker_archetype` value

#### Scenario: Idempotent re-runs
- **WHEN** the assignment pass runs a second time on a faction that already has a `trucker_archetype` value
- **THEN** the system SHALL leave the existing value unchanged and SHALL NOT re-roll

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

For every faction with an assigned archetype, the system SHALL persist the resolved commodity bias table via `Faction:setValue("trucker_bias", <table>)` so that price-hook code can look it up without recomputing from the archetype name on every call. The bias table SHALL map commodity-category identifiers to multiplicative price modifiers (where `1.0` is no change, `0.7` is 30% cheaper, `1.3` is 30% more expensive).

#### Scenario: Bias lookup by faction
- **WHEN** a station price hook queries `Faction:getValue("trucker_bias")` for an archetype-assigned faction
- **THEN** the system SHALL return the bias table associated with that faction's archetype

#### Scenario: Faction without archetype
- **WHEN** a station price hook queries `trucker_bias` on an excluded or unassigned faction
- **THEN** the lookup SHALL return nil and the price hook SHALL apply no modification

### Requirement: Server-side price modification at merchant boundary

The system SHALL apply the bias table as a multiplicative final layer on station buy and sell prices for stations owned by archetype-assigned factions. The vanilla price formula (including stock-based elasticity) SHALL be evaluated first; the bias multiplier SHALL be applied to the result. The hook SHALL be installed at the price-getter boundary of every merchant script that exposes price-affecting calls (factory, tradingpost, biotope, refinery, habitat, militaryoutpost, planetarytradingpost, scrapyard, casino, equipmentdock, and any other vanilla merchant exposing `getBuyableGoods` / `getSellableGoods`).

#### Scenario: Buy price modification
- **WHEN** a station owned by an archetype-assigned faction returns a buy price for a commodity
- **THEN** the price returned to client and AI consumers SHALL equal `vanilla_price × archetype_bias[commodity_category]`

#### Scenario: Sell price modification
- **WHEN** a station owned by an archetype-assigned faction returns a sell price for a commodity
- **THEN** the price returned SHALL equal `vanilla_price × archetype_bias[commodity_category]`

#### Scenario: Commodity not in bias table
- **WHEN** a commodity's category has no entry in the bias table
- **THEN** the bias multiplier SHALL be treated as `1.0` and the vanilla price SHALL pass through unchanged

#### Scenario: Missing merchant coverage
- **WHEN** the server starts and a known vanilla merchant script type is detected without the bias hook installed
- **THEN** the system SHALL log a warning naming the missing merchant type, and SHALL NOT modify prices for that merchant
