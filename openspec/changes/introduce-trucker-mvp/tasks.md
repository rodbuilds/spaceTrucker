## 1. Project scaffolding

- [ ] 1.1 Update `modinfo.lua`: set `saveGameAltering = true`; confirm `serverSideOnly = false` and `clientSideOnly = false`; bump version to `0.1.0`
- [ ] 1.2 Create `data/scripts/` directory tree mirroring vanilla layout (`data/scripts/lib/`, `data/scripts/entity/merchants/`, `data/scripts/player/`, `data/scripts/sector/`)
- [ ] 1.3 Add a `data/scripts/lib/truckerlog.lua` shared logger that prefixes all output with `[SpaceTrucker]` for grep-friendly server logs
- [ ] 1.4 Verify the mod loads on a fresh galaxy without errors and prints the boot banner via `truckerlog`

## 2. Faction commodity bias — archetype assignment

- [ ] 2.1 Author `data/scripts/lib/truckerarchetypes.lua` containing the fixed archetype enum (Agricultural, Industrial, Mining, Refinery, Frontier, Mercantile, Militant) and the per-archetype bias tables mapping commodity categories to multipliers
- [ ] 2.2 Author `data/scripts/lib/truckerexcluded.lua` enumerating excluded faction categories (pirates, smugglers, Xsotan, story-only) with a single `isExcluded(faction)` predicate
- [ ] 2.3 Author `data/scripts/lib/truckerarchetyperoll.lua` implementing the trait-weighted roll: read `Faction:getTraits()`, compute per-archetype weights from a trait→archetype influence matrix, perform a weighted draw, fall back to uniform when traits are empty
- [ ] 2.4 Add per-archetype maximum-share guardrail in the roll module; track running assignment counts and redistribute when a cap is hit
- [ ] 2.5 Author `data/scripts/server/truckerassignarchetypes.lua` server-side initialization script that iterates all known factions on first boot, applies the roll for any faction lacking `trucker_archetype`, and persists both `trucker_archetype` and `trucker_bias` via `Faction:setValue`
- [ ] 2.6 Make the assignment pass idempotent: re-running on a faction with an existing `trucker_archetype` SHALL leave the value unchanged
- [ ] 2.7 Wire the assignment script into the server boot path so it runs once per server start (mid-game install backfill)
- [ ] 2.8 Verify on a fresh galaxy: dump archetype distribution to log, confirm distribution is non-degenerate and respects share caps

## 3. Faction commodity bias — price hook

- [ ] 3.1 Audit `previous-avorion-mods/` and `avorion-scripts/entity/merchants/` for the full list of merchant scripts exposing buy/sell prices that need wrapping
- [ ] 3.2 Author `data/scripts/lib/truckerpricehook.lua` providing two pure functions: `applyBuyBias(faction, commodity, vanillaPrice)` and `applySellBias(faction, commodity, vanillaPrice)`, each looking up `Faction:getValue("trucker_bias")` and applying the multiplier; pass-through nil bias / unknown commodity category as `× 1.0`
- [ ] 3.3 Add wrapper hooks in `data/scripts/entity/merchants/factory.lua`, `tradingpost.lua`, `biotope.lua`, `refinery.lua`, `habitat.lua`, `militaryoutpost.lua`, `planetarytradingpost.lua`, `scrapyard.lua`, `casino.lua`, `equipmentdock.lua` (and any others surfaced in 3.1) that delegate to the price-hook functions on price-getter calls
- [ ] 3.4 Add coverage check at server boot: enumerate vanilla merchant types known to expose prices and log a warning for any not wrapped
- [ ] 3.5 Manual verification: dock at multiple stations across multiple factions, confirm prices vary by faction in line with archetype bias

## 4. Trade journal — capture, persistence, queries

- [ ] 4.1 Author `data/scripts/lib/truckerjournal.lua` with `recordObservations(player, sector)` that enumerates stations and emits one observation per (station, commodity, action) tuple
- [ ] 4.2 Implement journal entry schema: station id, station name, sector coords, owning faction id, commodity name, commodity category, action, price, current stock, max stock, galactic timestamp
- [ ] 4.3 Implement journal persistence: read/write `Player:setValue("trucker_journal", <table>)`; initialize empty for new players without error
- [ ] 4.4 Implement size cap (default 5,000) with oldest-first pruning when appending would exceed it; expose cap as a server config value
- [ ] 4.5 Author `data/scripts/sector/truckerobservationhook.lua` server-side sector-entry hook gated on player ship having a Trading System upgrade; call `recordObservations` on entry
- [ ] 4.6 Implement query API in `truckerjournal.lua`: `queryByCommodity(player, name)`, `queryByFaction(player, factionId)`, `queryBySector(player, x, y)`, all returning newest-first
- [ ] 4.7 Manual verification: equip a Trading System, jump to a sector with stations, confirm observations appear via debug command; jump again and confirm appended

## 5. Trade journal — alliance auto-share

- [ ] 5.1 Extend `truckerjournal.lua` with `alliance` write path: when `recordObservations` runs and the player belongs to an alliance, append the same observations to `Alliance:setValue("trucker_journal_shared", <table>)`
- [ ] 5.2 Apply the same size cap and oldest-first pruning to the alliance store as to the per-player journal
- [ ] 5.3 Implement `effectiveJournal(player)` helper that merges personal + alliance-shared entries deduplicated by (station, commodity, action, timestamp); use this everywhere the UI reads the journal
- [ ] 5.4 Verify behavior when a player leaves an alliance: shared entries remain in the alliance store; the leaving player retains only their personal entries
- [ ] 5.5 Manual MP verification: two-player co-op test, one captures observations, the other reads them via the survey UI

## 6. Faction commodity reports — merchant and codex

- [ ] 6.1 Author `data/scripts/entity/merchants/truckerreportmerchant.lua` modeled on `cargotransportlicensemerchant.lua` exposing a Faction Commodity Reports interaction
- [ ] 6.2 Wire the merchant onto Trading Posts and Faction Headquarters in archetype-assigned faction space; skip excluded factions
- [ ] 6.3 Implement report pricing function with at least faction-power scaling; expose pricing coefficients as server config values
- [ ] 6.4 Implement purchase flow: deduct credits, build a report entry containing subject faction id, archetype name, bias summary, and a snapshot of the buyer's effective journal filtered to that faction's space, with purchase timestamp
- [ ] 6.5 Persist purchased reports via `Player:setValue("trucker_reports", <table>)`; allow multiple purchases of the same faction's report (each a separate dated codex entry)
- [ ] 6.6 Author `data/scripts/player/truckerreportscodex.lua` client-side codex view: list reports, open a report to render faction name, archetype, "Tends CHEAP" / "Tends DEAR" lines, snapshot best-buy/best-sell entries, and purchase timestamp
- [ ] 6.7 Implement live war-status warning: at render time, query faction relations for the subject faction; if at war, append a "⚠ AT WAR with X" badge listing all current war counterparts
- [ ] 6.8 Manual verification: purchase a report, view in codex, confirm war badge appears when faction enters a war after purchase

## 7. Sector Survey UI

- [ ] 7.1 Identify the vanilla client-side trade view script(s) that need augmenting (likely the client-rendered side of the merchant scripts wrapped in section 3)
- [ ] 7.2 Author `data/scripts/client/truckersurveypanel.lua` that injects a Sector Survey panel into the trade view's existing layout (in-place augmentation, no replacement)
- [ ] 7.3 Implement per-row journal cross-reference: for each commodity row, show the player's best-buy and best-sell observation from the effective journal with station name, sector coords, price, relative-time formatting; show "No observations yet" when empty
- [ ] 7.4 Visually distinguish alliance-shared observations from personal ones (icon or label)
- [ ] 7.5 Implement archetype hint area: when a report exists for the current station's owning faction, display archetype name and one-line bias summary; otherwise show the "purchase a report" prompt
- [ ] 7.6 Implement empty-state behavior: when the player has zero journal entries and zero reports, show the onboarding line; never show error states
- [ ] 7.7 Verify graceful degradation when no Trading System is equipped: panel still renders against whatever vanilla rows are visible
- [ ] 7.8 Manual verification across all wrapped merchant types: panel appears and renders correctly without breaking vanilla controls

## 8. Integration, polish, and shipping

- [ ] 8.1 Document compatibility caveat in a top-level README: the price-hook layer conflicts with other mods that override station price formulas; list known-incompatible workshop mods
- [ ] 8.2 Add a `data/config/spacetrucker.lua` config file exposing journal cap, report pricing coefficients, archetype share caps, and trait-influence matrix tunings
- [ ] 8.3 Add an in-game `/trucker debug` command (server-only) that dumps archetype assignments, journal sizes, and report counts for diagnostic purposes
- [ ] 8.4 Full playthrough verification: spawn fresh, equip cargo bay + Trading System, sector-hop, build a journal, save up for a faction report, purchase it, observe survey UI changes
- [ ] 8.5 Co-op MP verification: two players, one in an alliance, confirm alliance auto-share works end to end and survey UI surfaces shared observations
- [ ] 8.6 Save-game safety verification: install on a fresh galaxy, save and reload, confirm archetype assignments and journal entries persist; uninstall and confirm the savegame loads on vanilla without corruption
