## Why

The trucker profession established by `introduce-trucker-mvp` gives players the tools to *read* the galaxy's markets, but no structured way to act on that knowledge beyond self-directed hauling. Cargo transport contracts — posted to station bulletin boards and rewarded with credits, faction relations, and a speed bonus — complete the loop: players now have a reason to route through specific sectors, filling cargo holds on demand rather than speculating.

## What Changes

- A new mission type, **Transport Mission**, appears on station bulletin boards at Trading Posts, Resource Depots, Factories, Habitats, and Biotopes; probability weight varies by station type.
- The player accepts a contract, loads cargo into their hold (with a graceful insufficient-space dialog), flies to a destination sector, and collects a reward.
- **Reward formula** scales with sector zone (`Balancing_GetSectorRewardFactor`), cargo value, and delivery distance; a +30% speed bonus applies when the player arrives before the sector-distance deadline.
- **Pirate ambush** is gated by cargo value: shipments worth >50,000 cr trigger a chance-based pirate spawn at the destination that must be cleared before delivery.
- Cargo amounts scale to the player's free cargo space and the sector ring (outer/mid/inner), keeping contracts consistently sized for the ship that accepts them.
- **BREAKING**: Adds `data/scripts/player/missions/transportmission.lua` and `data/scripts/entity/merchants/transportbroker.lua` as new script files; patches `data/scripts/entity/missionbulletins.lua` via `modinfo.lua` replacement to register the new mission type.

## Capabilities

### New Capabilities
- `transport-mission`: Full mission lifecycle — contract generation, cargo loading, in-transit HUD marker, destination arrival, optional pirate ambush, delivery dialog, and reward dispatch.
- `transport-broker`: Station-side contract generator and cargo-loader: chooses destination sector, picks cargo type by station archetype, checks player cargo space, and initiates the mission or offers a graceful refusal.
- `mission-bulletin-integration`: Registration of the transport mission type on the five target station types via the `missionbulletins.lua` patch pattern, with per-station-type probability weights.

### Modified Capabilities
<!-- No existing specs change requirements — this is an additive capability. -->

## Impact

- **`modinfo.lua`**: adds `transportmission.lua` and `transportbroker.lua` to the mod's script list; adds the `missionbulletins.lua` replacement entry.
- **`data/scripts/entity/missionbulletins.lua`**: new mission entry rows for Trading Post (weight 2.5), Resource Depot (weight 2.0), Factory / Habitat / Biotope (weight 1.5 each).
- **`structuredmission.lua` framework**: mission phases, timers, callbacks, and reward dispatch all flow through the vanilla structured-mission API — no new framework dependencies.
- **APIs used**: `ship:addCargo` / `ship:removeCargo`, `ship.cargoUsed` / `ship.cargoCapacity`, `Balancing_GetSectorRewardFactor`, `SectorSpecifics:getShuffledCoordinates`, `AsyncPirateGenerator`, `mission.data.reward`.
- **Compatibility**: no conflict with the price-hook layer from `introduce-trucker-mvp`; the transport mission is reward-side only and does not touch station price formulas.
