## Context

Avorion's `structuredmission.lua` framework handles mission phases, timers, sector markers, reward dispatch, and mail — the vanilla `Mining`, `Salvage`, and `Patrol` missions all use it. The mission bulletin board (`missionbulletins.lua`) is a vanilla file that enumerates which mission scripts are eligible per station type; mods register new mission types by replacing it via `modinfo.lua`.

The mod already ships a price-hook layer (`truckerpricehook.lua`, `truckerpricewrap.lua`) and a journal system (`truckerjournal.lua`). The transport mission is purely reward-side: it touches cargo holds, rewards, and pirate generation — none of the price-formula hooks. The two features are additive and non-conflicting.

Cargo space mechanics use `ship.cargoUsed` / `ship.cargoCapacity` (always available on the player ship entity). Pirate generation uses `AsyncPirateGenerator` with sector coordinates, which already scales ship size and power by zone — the mission only controls count and wave structure.

## Goals / Non-Goals

**Goals:**
- Implement the full transport mission lifecycle (contract → load → transit → optional ambush → delivery → reward) using vanilla APIs.
- Scale contract parameters (cargo amount, pirate intensity, reward) to sector zone so contracts feel appropriate regardless of where in the galaxy they are accepted.
- Integrate gracefully with the existing mod structure: new files only, no changes to any file authored in `introduce-trucker-mvp`.
- Support co-op MP without per-player state complexity: mission state lives in the `structuredmission` save slot, which is already player-scoped by the vanilla framework.

**Non-Goals:**
- No partial load option — player must return with sufficient space (matches finalized design decision in PROJECT_PLAN.md).
- No time limit with mission failure — only a speed bonus window (+30% if early).
- No smuggling / contraband cargo path in v1.
- No NPC escort or convoy mechanics.
- No integration with the journal: transport deliveries do not auto-record price observations (the observation hook in `truckerobservationhook.lua` already covers sector entry).

## Decisions

### D1: Mission script follows the vanilla `structuredmission` 3-phase model

Three phases map cleanly onto the PROJECT_PLAN.md flow:
- **Phase 1 (OFFERED)** — runs while at the source station; ends when player docks and accepts.
- **Phase 2 (IN_TRANSIT)** — active while the player is en route; registers the destination sector marker; starts the speed-bonus timer.
- **Phase 3 (DELIVERY)** — triggers on arrival at the destination sector; handles the ambush roll, pirate spawning, delivery dialog, cargo removal, and reward.

**Alternatives considered:** A flat single-phase mission that polls position — rejected because it would duplicate logic already in `structuredmission` and would not survive saves cleanly.

### D2: Broker script owns contract generation and cargo-loading

`transportbroker.lua` is the station-side script that:
1. Selects a destination sector via `SectorSpecifics:getShuffledCoordinates()` — filters for same-faction territory in the 5–30 sector distance band.
2. Picks cargo type based on station title (Trading Post → manufactured goods, Resource Depot → raw materials scaled by ring, Factory → production-matched goods, Habitat/Biotope → consumer/bio goods).
3. Checks `ship.cargoUsed + amount ≤ ship.cargoCapacity`; if insufficient, presents the refusal dialog only (no partial load per D1's non-goal).
4. On accept: calls `ship:addCargo(good, amount)` and hands off to `transportmission.lua` via `mission:start()`.

This separation keeps the mission script stateless regarding origin-station details beyond what is serialised into `mission.data`.

### D3: Pirate ambush fires en route using the existing sector-ambush mechanic

The ambush roll fires in the Phase 2 `onPlayerEntered` callback (every sector the player jumps into while in transit), not at the destination:
```
cargoValue = amount × good.price
if cargoValue > 50000 then
    -- delegate to existing sector ambush mechanic; pirates are pre-positioned
    -- on sector entry rather than spawned after arrival
    triggerSectorAmbush(sector, x, y)
end
```
The implementation delegates to Avorion's existing ambush system so pirates are already waiting when the player arrives — consistent with how vanilla ambushes feel. This removes the Phase 3 "clear before delivery" gate; the destination sector itself is a normal docking interaction.

**Alternatives considered:** Spawning pirates at the destination only (original design) — rejected per user revision; mid-route ambushes on every jump are more tense and use the engine's built-in ambush pattern rather than a custom spawn sequence.

### D4: Reward formula uses `Balancing_GetSectorRewardFactor` at the destination

```lua
local factor  = Balancing_GetSectorRewardFactor(destX, destY)
local base    = 15000 * factor
local perUnit = cargoAmount * good.price * 0.10
local dist    = sectorDistance * 500
local total   = base + perUnit + dist
local speed   = total * 0.30  -- added if timePassed < speedBonusWindow
local rel     = 2000 + math.round(cargoAmount * 3)
```
Factor is read at destination (not source) so inner-ring destinations pay more regardless of where the player picked up the contract — incentivising deep-galaxy routes.

### D5: `missionbulletins.lua` patched via modinfo.lua file replacement

The vanilla `missionbulletins.lua` is overridden in `modinfo.lua` using the standard `<filepath>` replacement tag. The replacement file is a verbatim copy of the vanilla file with the five new `table.insert` blocks added. This is the same pattern used by dozens of workshop mods and is the only supported mechanism for modifying bulletin boards.

**Implications:** The replacement file must be kept in sync with any vanilla update that modifies `missionbulletins.lua`. Document in README as a known maintenance point.

## Risks / Trade-offs

- **`missionbulletins.lua` replacement conflicts with other mission mods** → Same conflict as any other bulletin-board mod; no automatic resolution in v1. Document in README. A future change could introduce a script-injection loader that avoids full-file replacement.
- **`SectorSpecifics:getShuffledCoordinates()` returning no valid destinations in sparse regions** → Fall back to a random sector in the 5–30 band regardless of faction; if still empty, disable the mission at that station for this session (no contract offered).
- **`AsyncPirateGenerator` timing: pirates may spawn after the delivery dialog opens** → Gate the delivery dialog behind a `onEntityDestroyed` listener that counts down the spawned wave; only unlock dialog when count reaches zero.
- **Speed-bonus window starting at accept time vs. departure time** → Start at accept time (cargo loaded) to mirror the "clock starts when you take the job" feel; this is slightly disadvantageous to players who browse multiple contracts. Acceptable for v1.
- **Cargo removal on delivery if player sold some en route** → Check `ship:removeCargo(good, amount)` return value; if partial removal only (player sold some), deduct reward proportionally rather than failing the mission. Prevents frustrating edge cases where a small cargo sale mid-route fails a long-haul contract entirely.

## Migration Plan

This is an additive change to an existing mod. No migration of saved game state is required — transport missions are accepted fresh per session. The `missionbulletins.lua` replacement file will be added; existing saves will begin showing transport contracts at the next bulletin board interaction after the mod update is installed. No rollback risk beyond the standard `saveGameAltering` warning already set by `introduce-trucker-mvp`.

## Open Questions

- **Zone-scaled pirate ambush (full PROJECT_PLAN.md formula)** — ship as a v1 enhancement or defer to a follow-up change? Currently deferred; the simple 30% gate ships in v1.
- **Cargo type selection for Factory stations** — production-matched cargo requires reading the factory's production script to determine what it makes. Fallback to "manufactured goods" bucket if the production type cannot be determined at contract generation time?
- **Destination sector faction filter strictness** — require strictly same faction, or allow allied factions? Same faction preferred; allied fallback acceptable if no same-faction sector in range.
