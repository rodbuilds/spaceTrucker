## Why

Avorion's vanilla economy is mechanically dynamic but experientially flat: prices vary station-to-station with little geographic character, and the player has no way to remember or reason about what they've seen across the galaxy. There is no fourth profession alongside salvage, mining, and combat — only mission-driven hauling chores. Space Trucker introduces *the trucker as a first-class career path*: faction-flavored markets that reward learning the galaxy, a personal trade journal that grows with experience, and purchasable intel that scales with player wealth.

## What Changes

- Each NPC faction is assigned a static **economic archetype** at galaxy generation (e.g., Agricultural, Industrial, Mining, Refinery, Frontier, Mercantile, Militant), derived from a weighted roll biased by the faction's vanilla traits.
- Each archetype carries a **commodity bias table** that modifies station buy/sell prices for that faction's stations. Vanilla per-station variance is preserved; the bias is a multiplicative layer on top.
- A **trade journal** records every commodity observation (price, stock, station, sector, timestamp) made by a player whose ship has a Trading System upgrade in the sector. Observations are personal but auto-shared with alliance members.
- A new merchant type, the **Faction Commodity Reports merchant**, sells purchasable codex artifacts that grant the buyer the faction's archetype identity plus an aggregated snapshot of recent observations in that faction's space. Reports are timestamped and carry a war-status warning badge when relevant.
- The vanilla station trade UI is augmented with a **Sector Survey panel** that cross-references the current station's prices against the player's journal entries and any unlocked faction reports.
- **BREAKING**: `modinfo.lua` flips `saveGameAltering = true` because per-faction archetype assignments and player journals are persisted. Disabling the mod will leave orphaned scripts referenced in the save until the player accepts the savegame migration warning.

## Capabilities

### New Capabilities
- `faction-commodity-bias`: Static per-faction economic archetypes assigned at galaxy gen, with bias tables that modify station prices server-side.
- `trade-journal`: Per-player observation log captured automatically when a Trading System is present in a loaded sector, auto-merged across alliance members.
- `faction-commodity-reports`: Purchasable intel artifacts sold by a new merchant type, granting archetype knowledge and aggregated observation snapshots.
- `sector-survey-ui`: Client-side augmentation of the vanilla station trade view that surfaces journal cross-references and unlocked archetype hints.

### Modified Capabilities
<!-- None — this is a greenfield mod with no prior specs in the repo. -->

## Impact

- **`modinfo.lua`**: `saveGameAltering` flips from `false` to `true`. Mod remains both client- and server-side (server runs price hooks and bias assignment; client renders journal/report/survey UI).
- **Vanilla scripts hooked, not replaced**: `entity/merchants/factory.lua`, `entity/merchants/tradingpost.lua`, and other merchant scripts that expose `getBuyableGoods` / `getSellableGoods` are wrapped by the bias layer. The vanilla price formula is preserved; the bias is applied as a final multiplier.
- **New persistent state**:
  - `Faction:setValue("trucker_archetype", <name>)` and `Faction:setValue("trucker_bias", <table>)` per faction, written once at galaxy generation.
  - `Player:setValue("trucker_journal", <table>)` per player, appended on observation events.
  - `Player:setValue("trucker_reports", <table>)` per player, codex of purchased reports.
- **New scripts directory layout** under `data/scripts/` mirroring vanilla conventions (`data/scripts/entity/merchants/`, `data/scripts/lib/`, `data/scripts/player/`).
- **Compatibility risk**: any other mod that hooks station price formulas (e.g., Trading Overhaul derivatives) will conflict on the price-multiplier hook. Documented as a known limitation; no automatic detection in v1.
- **Co-op MP**: alliance auto-share of journals requires the journal store to live server-side and broadcast deltas to alliance members on observation. Single-player and dedicated server are both supported by the same code path.
- **Out of scope for this change** (deferred to future proposals): smuggling expansion, mission overhaul, per-commodity reputation, fleet/captain management, player-to-player intel trading, archetype drift over time.
