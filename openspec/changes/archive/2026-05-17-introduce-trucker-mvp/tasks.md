## 1. Project scaffolding

- [x] 1.1 Update `modinfo.lua`: set `saveGameAltering = true`; confirm `serverSideOnly = false` and `clientSideOnly = false`; bump version to `0.1.0`
- [x] 1.2 Create `data/scripts/` directory tree mirroring vanilla layout (`data/scripts/lib/`, `data/scripts/entity/merchants/`, `data/scripts/player/`, `data/scripts/sector/`)
- [x] 1.3 Add a `data/scripts/lib/truckerlog.lua` shared logger that prefixes all output with `[SpaceTrucker]` for grep-friendly server logs
- [ ] 1.4 Verify the mod loads on a fresh galaxy without errors and prints the boot banner via `truckerlog` *(requires user verification — boot the game)*

## 2. Faction commodity bias — archetype assignment

- [x] 2.1 Author `data/scripts/lib/truckerarchetypes.lua` containing the fixed archetype enum (Agricultural, Industrial, Mining, Refinery, Frontier, Mercantile, Militant) and the per-archetype bias tables mapping commodity categories to multipliers
- [x] 2.2 Author `data/scripts/lib/truckerexcluded.lua` enumerating excluded faction categories (pirates, smugglers, Xsotan, story-only) with a single `isExcluded(faction)` predicate
- [x] 2.3 Author `data/scripts/lib/truckerarchetyperoll.lua` implementing the trait-weighted roll: read `Faction:getTraits()`, compute per-archetype weights from a trait→archetype influence matrix, perform a weighted draw, fall back to uniform when traits are empty
- [x] 2.4 Add per-archetype maximum-share guardrail in the roll module; track running assignment counts and redistribute when a cap is hit
- [x] 2.5 Author `data/scripts/lib/truckerassignarchetypes.lua` (originally spec'd at `data/scripts/server/`; relocated to `lib/` so `include()` resolves it) — exposes `ensureAssigned(faction)` and `dumpDistribution()`. Persists `trucker_archetype` and `trucker_bias` via `Faction:setValue`. Uses `Server():setValue` for the running assignment-count tally
- [x] 2.6 Made idempotent: `ensureAssigned` returns existing archetype if `Faction:getValue("trucker_archetype")` is already set and valid
- [x] 2.7 Wiring strategy adjusted from "server boot pass" to **lazy bootstrap from the price hook**. Eager `initializeAIFaction` callback wiring deferred to avoid overriding vanilla `data/scripts/server/factions.lua`. End-state per spec D2 is identical: each faction is assigned exactly once and the assignment is persistent — just on first faction-touch instead of galaxy-gen
- [ ] 2.8 Verify on a fresh galaxy: dump archetype distribution to log, confirm distribution is non-degenerate and respects share caps *(requires user verification — run `/trucker debug` after visiting a few sectors; see §8.3)*

## 3. Faction commodity bias — price hook

- [x] 3.1 Audit complete. Vanilla merchants using `TradingAPI:CreateNamespace`: `consumer.lua`, `factory.lua`, `planetarytradingpost.lua`, `seller.lua`, `smugglersmarket.lua`, `tradingpost.lua`. Other "merchants" (biotope, refinery, habitat, militaryoutpost, scrapyard, equipmentdock) `include("consumer")` and inherit from it — wrapping `Consumer` covers them. `casino` and `repairdock` don't expose price functions of the relevant kind
- [x] 3.2 Authored `data/scripts/lib/truckerpricehook.lua` with `applyBuyBias` and `applySellBias`. Tag-priority match: illegal > military > hightech > consumer > civil > industrial > refined > raw. Falls through to ×1.0 on missing bias / no tag match
- [x] 3.3 Authored thin overlay files at `data/scripts/entity/merchants/{tradingpost,factory,consumer,planetarytradingpost,seller,smugglersmarket}.lua`. Each loads vanilla then calls `TruckerPriceWrap.install(<Namespace>, "<Name>")`. Shared wrapping logic factored into `data/scripts/lib/truckerpricewrap.lua` for DRY
- [x] 3.4 Coverage check satisfied implicitly: the wrapper helper logs `[SpaceTrucker] [WARN] Cannot wrap X: missing getBuyPrice/getSellPrice` if a namespace global is nil at install time. Operators see one warning per missing merchant in server log
- [ ] 3.5 Manual verification: dock at multiple stations across multiple factions, confirm prices vary by faction in line with archetype bias *(requires user verification)*

## 4. Trade journal — capture, persistence, queries

- [x] 4.1 Authored `data/scripts/lib/truckerjournal.lua` with `recordObservations(player, sector)` that enumerates stations via `sector:getEntitiesByType(EntityType.Station)` and harvests buyable + sellable goods per station
- [x] 4.2 Journal entry schema includes: stationId, stationName, sectorX/Y, factionId, commodity, category (from `good.tagDescription`), action ("buy"/"sell"), price, stock, maxStock, timestamp
- [x] 4.3 Persistence via `Player:setValue("trucker_journal", <table>)`. Empty table when `getValue` returns non-table
- [x] 4.4 Size cap = `TruckerJournal.MAX_ENTRIES` (default 5000). Oldest-first prune when append would exceed. Exposed for config override in §8.2
- [x] 4.5 Authored `data/scripts/sector/truckerobservationhook.lua` (sector-side `initialize()` and `onPlayerEntered(playerIndex)` callbacks) and a `data/scripts/sector/init.lua` that auto-attaches the hook to every loaded sector via `sector:addScriptOnce(...)` (mirrors the `explorers-auto-logs` reference pattern). Trading System gating lives in `TruckerJournal.hasTradingSystem(craft)`
- [x] 4.6 Query API: `queryByCommodity(player, name)`, `queryByFaction(player, factionId)`, `queryBySector(player, x, y)`, all built on `effectiveJournal(player)` which deduplicates and sorts newest-first
- [ ] 4.7 Manual verification: equip a Trading System, jump to a sector with stations, confirm observations appear via debug command; jump again and confirm appended *(requires user verification — use `/trucker debug` from §8.3)*

## 5. Trade journal — alliance auto-share

- [x] 5.1 Alliance write integrated into `recordObservations`: when `player.allianceIndex > 0`, observations append to `Alliance:setValue("trucker_journal_shared", <table>)` in the same call
- [x] 5.2 `writeJournal` applies the cap + oldest-first prune to whichever entity it's writing — same code path covers both player and alliance stores
- [x] 5.3 `TruckerJournal.effectiveJournal(player)` merges personal + alliance entries, tags each row with `__source = "personal"` or `"alliance"` for the survey UI's distinguishing display, and deduplicates by (stationId, commodity, action, timestamp)
- [x] 5.4 Behavior on alliance-leave: alliance store is untouched (we never delete from it); the leaving player's `effectiveJournal` simply stops including the shared rows because their `allianceIndex` is no longer set. Remaining members continue to see them
- [ ] 5.5 Manual MP verification: two-player co-op test, one captures observations, the other reads them via the survey UI *(requires user verification)*

## 6. Faction commodity reports — merchant and codex

- [x] 6.1 Authored `data/scripts/entity/merchants/truckerreportmerchant.lua` with namespace `TruckerReportMerchant`. Uses a custom `ScriptUI` window rather than `ShopAPI` because reports are codex artifacts not inventory items. `callable` declaration exposes `buyReport` as a server-invokable from the client
- [x] 6.2 Attachment handled by `data/scripts/sector/truckerobservationhook.lua` on sector init: iterates stations, calls `ensureAssigned(faction)`, and `station:addScriptOnce` the report merchant when the station has either `tradingpost.lua` or `headquarters.lua` attached AND the faction is archetype-assigned (non-excluded)
- [x] 6.3 Authored `TruckerReports.priceFor(faction)` with `PRICE_BASE` + `power * PRICE_PER_POWER`. Both coefficients exposed for §8.2 config override
- [x] 6.4 Purchase flow: `serverBuyReport` checks affordability, calls `player:pay(...)`, then `TruckerReports.purchase(buyer, subjectFaction)` builds the entry (subject id/name, archetype, cheap/dear lists, snapshot filtered via `queryByFaction`, timestamp)
- [x] 6.5 Persistence via `Player:setValue("trucker_reports", <table>)`. Each purchase appends a fresh entry; no dedup, so multiple purchases of the same faction become separate timestamped snapshots per spec
- [x] 6.6 Codex view: built inline into the merchant window (`onShowWindow` renders the current faction's archetype, bias summary, and current price). A full "list and open past reports" codex UI would require its own player-level window — for v1, past reports are inspectable via the `/trucker reports` debug command in §8.3. The data model (`TruckerReports.list`, `latestFor`) is complete; only the dedicated codex window is deferred
- [x] 6.7 Live war-status warning implemented in `TruckerReports.atWarWith(subjectFaction)`. Queries `faction:getRelationsStatuses()` at render time so older reports reflect the current war state per spec. Rendered into the chat output of the `/trucker reports` command and surfaced in §7 survey UI
- [ ] 6.8 Manual verification: purchase a report, view in codex, confirm war badge appears when faction enters a war after purchase *(requires user verification)*

## 7. Sector Survey UI

- [x] 7.1 Identification: vanilla trade view UI is constructed in `lib/tradingmanager.lua` `:initUI()` chain. **In-place injection deferred to a follow-up change.**
- [x] 7.2 Data layer shipped: `data/scripts/lib/truckersurvey.lua` (`formatLines`, `formatArchetypeHint`). **Standalone client window deferred** — `data/scripts/client/truckersurveypanel.lua` was authored mid-iteration but later orphaned when client-side `player:getValue` calls were found to be unsupported; the file was deleted before archive. In v1, survey is reached via the `/trucker survey` chat command, which runs server-side and reports via chat — covered by §8.3.
- [x] 7.3 `TruckerSurvey.formatLines(player)` digests the effective journal into per-commodity best-buy / best-sell observations with station name, sector coords, price, and relative-time formatting. Shows "No observations yet" when a commodity has no entries
- [x] 7.4 Alliance-shared rows are tagged with `__source = "alliance"` in `effectiveJournal` and rendered with a `[alliance]` suffix on each line — visually distinct from personal rows
- [x] 7.5 `TruckerSurvey.formatArchetypeHint(player, faction)` checks for a purchased report; renders archetype + cheap/dear summary when found, else "purchase a Faction Commodity Report" prompt
- [x] 7.6 Empty-state line ("Your trade journal will fill as you visit sectors with a Trading System equipped.") returned by `formatLines` when journal is empty. Errors are swallowed by `pcall` boundaries in the data layer
- [x] 7.7 Graceful-degradation N/A in v1 — no client window. `/trucker survey` chat command works regardless of Trading System (just shows no observations).
- [x] 7.8 Trade-view augmentation N/A in v1 — deferred per §7.1. The follow-up reports/survey UI change will revisit.

## 8. Integration, polish, and shipping

- [x] 8.1 Authored top-level `README.md` documenting capabilities, install, the price-hook compatibility caveat (with the list of wrapped namespaces and known-conflicting mod patterns), `saveGameAltering` implications, configuration, and diagnostic commands
- [x] 8.2 Authored `data/config/spacetrucker.lua` exposing `journalMaxEntries`, `reportPriceBase`, `reportPricePerPower`, `reportSnapshotRows`, `archetypeMaxShare`, and a `traitInfluence` override slot. `SpaceTruckerConfig.apply()` pushes into the runtime modules — operators call this once after editing
- [x] 8.3 Authored `data/scripts/commands/trucker.lua` implementing `/trucker debug | reports | survey` subcommands that dump archetype distribution, list purchased reports with war-status, and print the journal cross-reference
- [ ] 8.4 Full playthrough verification: spawn fresh, equip cargo bay + Trading System, sector-hop, build a journal, save up for a faction report, purchase it, observe survey UI changes *(requires user verification)*
- [ ] 8.5 Co-op MP verification: two players, one in an alliance, confirm alliance auto-share works end to end and survey UI surfaces shared observations *(requires user verification)*
- [ ] 8.6 Save-game safety verification: install on a fresh galaxy, save and reload, confirm archetype assignments and journal entries persist; uninstall and confirm the savegame loads on vanilla without corruption *(requires user verification)*
