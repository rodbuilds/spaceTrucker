## Context

Avorion is a sandbox space game with a Lua scripting layer split across `client/` and `server/` script directories, mod-installable under a `data/scripts/` tree that mirrors vanilla. The vanilla economy is per-station with stock-based price elasticity and faction-owned regional clusters. Sector simulation is gated on player presence: unloaded sectors freeze combat and physics but allow lazy-catchup of factory production, while faction-level state (relations, war declarations) is always global. The Faction API exposes a `getTraits()` map of personality floats (`aggressive`, `peaceful`, `greedy`, `honorable`, `careful`, `brave`, `trusting`) but no industry-typing — economic character is something this mod will introduce.

The mod runs in co-op multiplayer from day one. The reference mod `previous-avorion-mods/explorers-auto-logs` and the workshop mod `avorionTradeExport` both demonstrate that per-sector observation harvesting on Trading-System sector entry is a tractable, well-trodden pattern. Player-facing UI must work within Avorion's `ScriptUI` system (frames, labels, buttons, no native chart primitives).

## Goals / Non-Goals

**Goals:**
- Establish trucking as a fourth profession alongside salvage, mining, and combat — a player can spawn into a server, equip a cargo bay and Trading System, and progress from sector-hopping merchant to galaxy-spanning trader by reading markets.
- Make geography meaningful: each faction has a learnable economic personality the player can recognize and exploit.
- Provide a personal record (journal) that converts every trade into durable knowledge, with alliance auto-share so co-op truckers can divide labor.
- Provide a paid intel tier (faction reports) that lets wealth substitute for time spent surveying.
- Surface enough information at the point of decision (Sector Survey UI) without dictating choices — the mod augments perception, the player still does the math.

**Non-Goals:**
- No background simulation of unloaded sectors. Combat, raids, and station damage outside loaded sectors are out of scope.
- No charts, trends, or price-history time-series UI. Vanilla prices are point-in-time snapshots; the journal is the only history mechanism.
- No archetype drift. Bias is rolled once at galaxy gen and frozen for the life of the save.
- No new economy simulation. The vanilla price formula remains authoritative; archetype bias is a multiplicative final layer.
- No smuggling expansion, mission overhaul, fleet/captain layer, per-commodity reputation, or player-to-player intel trading. All deferred to future changes.
- No UI replacement. The vanilla station trade view is augmented in-place, not rewritten.

## Decisions

### D1: Bias modifies prices via wrapper hook (Path A, not Path B)

The archetype bias is applied as a multiplicative final layer on station buy/sell prices, hooked into the merchant scripts (`factory.lua`, `tradingpost.lua`, etc.) at the price-getter boundary. Vanilla per-station variance is preserved underneath — the bias is `vanilla_price × archetype_bias[commodity_category]`.

**Alternatives considered:** Pure UX/intel mod that only *describes* vanilla variance without modifying prices (Path B). Rejected because vanilla economy lacks the geographic character the mod's premise needs — without modifying prices, "Industrial faction" would be a label without mechanical meaning.

**Implications:** `saveGameAltering = true`. Server-side execution required for the price hook. Compatibility friction with any other economy mod that hooks station price formulas (documented as a known limitation; no automatic detection).

### D2: Archetypes derived at galaxy gen via weighted roll from vanilla traits

A fixed enum of ~7 archetypes (Agricultural, Industrial, Mining, Refinery, Frontier, Mercantile, Militant) carries the bias tables. At galaxy generation, each NPC faction's archetype is selected by a weighted random roll where the weights are influenced by the faction's vanilla traits — e.g., `aggressive` and `brave` increase the weight on Militant and Frontier; `peaceful` and `trusting` increase Agricultural; `greedy` increases Mercantile.

The roll is one-shot per faction; the archetype name and resolved bias table are persisted via `Faction:setValue("trucker_archetype", ...)` and `Faction:setValue("trucker_bias", ...)`. They are never recomputed.

**Alternatives considered:** (a) Pure random per-faction with no trait coupling — rejected because faction personality should feel coherent. (b) Hand-authored per-faction archetypes — impossible in a procgen galaxy. (c) Dynamic archetypes that drift over time — explicitly out of scope for v1.

### D3: Persistent state via `setValue` on existing engine entities

All new persistent state lives on existing engine entities through their `setValue`/`getValue` APIs, not in a parallel database file:

- Per-faction: `Faction:setValue("trucker_archetype", string)`, `Faction:setValue("trucker_bias", table)`
- Per-player: `Player:setValue("trucker_journal", table)`, `Player:setValue("trucker_reports", table)`
- Per-alliance: `Alliance:setValue("trucker_journal_shared", table)` (used as the auto-share mailbox)

**Why:** This rides the savegame's existing serialization, survives loads cleanly, and avoids inventing parallel persistence. The cost is that journal size is bounded by what the engine will tolerate in player setValue tables — addressed by capped journal length (D4).

### D4: Journal capture is gated on Trading System upgrade in a loaded sector

A player's ship must (a) be present in a loaded sector and (b) have a Trading System upgrade equipped for the journal capture event to fire. On entering such a sector, the server-side journal hook enumerates all stations and records one observation per (station, commodity) pair. The journal is capped at a configurable maximum (default 5,000 entries per player); when full, oldest entries are pruned first.

**Why this gating:** It mirrors how the vanilla Trading System already gates the player's ability to *see* prices. It keeps journal growth bounded by player effort and equipment investment, preserving the progression curve.

### D5: Alliance auto-share via server-side journal merge

When a player records a journal observation, the server-side hook checks for alliance membership and writes the same observation to `Alliance:setValue("trucker_journal_shared", ...)`. Alliance members reading their effective journal see the union of personal + alliance-shared entries. There is no per-message broadcast; reads happen at UI open time.

**Alternatives considered:** Live broadcast notifications ("Alice just spotted Iron at 8c in Sector 47-12") — out of scope for v1; the deferred-read model avoids notification spam and is sufficient for the "you scout, I haul" co-op loop.

### D6: Reports are snapshots, not subscriptions

Purchasing a faction commodity report copies the current state of (archetype identity + aggregated alliance journal observations for that faction's space) into the player's codex at that moment, with a timestamp. Reports do not refresh. Want fresh data? Buy another report. Each report is a discrete codex entry the player can compare side-by-side ("my report from 12 days ago vs. my report from 2 days ago").

**Why:** Eliminates the "live galactic price feed" performance trap. Adds a satisfying "is my intel still good?" tension. Maps naturally to the vanilla "buy a faction map" pattern.

### D7: War-status warnings derived live from faction relations

When a report is rendered, the UI checks the live faction relations table for the report's subject faction. If that faction is at war with anyone, a "⚠ AT WAR with X" warning badge is appended to the rendered report. The warning is derived live (not cached in the report data), so a stale report can still show fresh war information.

**Why:** Faction relations are global and free to query. This is the only "event-driven modifier" in v1 — keeps the design honest about what the engine actually simulates outside loaded sectors.

### D8: UI augmentation in-place, not replacement

The vanilla station trade view (`tradingpost.lua` and friends) is hooked to inject an additional Sector Survey panel at the bottom of the existing layout, rather than replacing the view. The panel contains: best-buy and best-sell entries from the player's journal for the currently displayed commodities, and an archetype hint badge if the player has unlocked a report for the current faction. The panel is client-side only and degrades silently when no relevant journal data exists.

**Why:** Lowest UI risk path. Survives Avorion patches that touch the trading UI better than a full replacement would. Clean uninstall — vanilla view returns to vanilla rendering.

## Risks / Trade-offs

- **Compatibility with other economy mods** → No automatic detection in v1. Documented in README. Power users disable conflicting mods; future change can introduce a price-hook adapter layer.
- **`saveGameAltering = true` orphans scripts on uninstall** → Player accepts vanilla savegame warning. Persistent state under `setValue` keys is silently ignored if the mod is removed; no corruption.
- **Bias must be applied consistently across all merchant types** → Audit and hook every script under `data/scripts/entity/merchants/` that exposes price-affecting calls. Risk of missing one (e.g., DLC merchants) → Add coverage check at galaxy load that logs a warning if a known merchant type lacks the wrapper.
- **Journal write-amplification in MP with many active truckers** → Cap journal length; observations are batched per sector entry, not per UI tick. Alliance share writes are O(1) per observation, not O(N members).
- **Player setValue table size limits** → Journal cap (D4) plus archetype/bias being on the *faction* (not player) side keeps per-player state small.
- **Trait-weighted archetype roll producing degenerate distributions** (e.g., 90% of factions roll Mercantile in a "peaceful galaxy" seed) → Add per-archetype maximum-share guardrail in the roll loop; if cap reached, redistribute toward the next-best archetype.
- **Vanilla `getTraits()` returning empty tables for some factions** (story factions, special factions) → Fall back to uniform random roll; exclude pirate/smuggler/Xsotan factions explicitly from archetype assignment.
- **War-status warning rendering for stale reports of conquered factions** → Acceptable; the warning text honestly reflects the live faction state. Future change can add "this faction no longer exists" handling.

## Migration Plan

This is a greenfield mod. "Migration" means: how does the mod behave on a galaxy that didn't have it installed at generation time?

1. On first server start with the mod loaded, run a one-shot **archetype backfill pass** that iterates all known NPC factions, checks for `Faction:getValue("trucker_archetype")`, and rolls + persists for any faction that lacks one. This makes the mod safe to install mid-game.
2. The backfill is idempotent: subsequent server starts re-check and only fill missing assignments. Factions added later (e.g., by other mods) get backfilled on next server start.
3. Player journals and reports start empty for everyone on first install — no synthetic backfill of historical observations.
4. **Rollback:** uninstalling the mod reverts the savegame to vanilla price calculations on next load. `setValue`-stored archetype tables, journals, and reports become orphaned (silent, no corruption). A reinstall recovers them; a permanent uninstall leaks the keys but does not affect gameplay.

## Open Questions

- **Exact archetype list and bias magnitudes** — the seven archetypes named here are a starting point; tuning will require playtesting. Spec'd as fixed for v1 but the table is a single file (`data/scripts/lib/truckerarchetypes.lua`) editable without code changes elsewhere.
- **Report pricing tier** — flat per-faction price, or scaled by faction size/distance/wealth? Leaning scaled, but exact formula deferred to implementation.
- **Which stations sell faction commodity reports** — leaning Trading Posts and Faction Headquarters in that faction's space (so you must visit a faction to get its report), but Resistance Outposts and travelling merchants are also candidates. Deferred to implementation.
- **Sector Survey UI panel placement** — bottom of existing trade view vs. side panel vs. toggleable overlay. Deferred until first prototype; ScriptUI layout constraints will probably decide for us.
