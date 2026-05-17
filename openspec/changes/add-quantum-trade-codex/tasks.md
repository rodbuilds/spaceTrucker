## 1. Foundation — vocabulary + config

- [ ] 1.1 Add new config keys to `data/config/spacetrucker.lua`: `tradeReportFee` (default 50_000), `factionSurveyBasePrice` (default 1_000_000), `surveyObservationCap` (default 2000). Keep MVP keys as deprecated aliases that map to the new ones on `apply()`.
- [ ] 1.2 Add specialization-to-stars + label helpers to `data/scripts/lib/truckerarchetypes.lua`: `specializationToStars(s) -> 1..5`, `specializationLabel(s) -> "Lightly"|"Modestly"|"Solidly"|"Heavily"|"Pure"`. Use bucket boundaries `[0.30,0.59] [0.60,0.89] [0.90,1.19] [1.20,1.49] [1.50,1.80]`.
- [ ] 1.3 Update `data/scripts/lib/truckerlog.lua` with a shared mail helper `TruckerLog.sendMail(player, subject, body)` (wraps vanilla mail API); leaves logging functions unchanged.
- [ ] 1.4 Update `modinfo.lua`: `name = "Space Trucker: Quantum Trade"`; bump `version` to `0.2.0`. Keep `saveGameAltering = true`.

## 2. Faction Survey persistence — storage migration

- [ ] 2.1 In `data/scripts/lib/truckerreports.lua`, define the new minimal entry shape `{subjectFactionId, subjectFactionName, economy, specialization, acquiredAt}`. Drop fields `archetype` (renamed via field key `economy`), `biasCheap`, `biasDear`, `snapshot`, `strength` (renamed via `specialization`).
- [ ] 2.2 Add `readSurveys(player)` + `writeSurveys(player, list)` that go through `TruckerSerialize`. On read, silently skip any entry missing the `economy` field (legacy MVP shape). Log a one-time per-galaxy warning ("Skipped N legacy report entries; create a fresh galaxy to reset.") if any were skipped. NO auto-upgrade.
- [ ] 2.3 Rewrite `TruckerReports.purchase(buyer, subjectFaction)` to produce the new minimal entry; replace existing entry for same faction id rather than appending; charge `factionSurveyBasePrice × specialization`; use `player:canPayMoney(price)` with fallback to `player.money or 0`.
- [ ] 2.4 Add `TruckerReports.priceFor(faction)` returning `factionSurveyBasePrice × getStrength(faction)` (renamed to `getSpecialization` internally via §3.3; keep `getStrength` as alias).
- [ ] 2.5 Remove `TruckerReports.atWarWith` and all war-status code paths (corresponding to the REMOVED spec requirement).
- [ ] 2.6 Add `TruckerReports.summarizeBias(economy, specialization)` returning `(sellsCheap, buysHigh)` tag lists derived from the effective bias table (apply specialization before threshold check).
- [ ] 2.7 Add `TruckerReports.computePriceBand(economy, specialization)` returning `{ {name, vanilla, expected, multiplier, tag}, ... }` sorted by multiplier ascending; filters neutral commodities (multiplier within [0.95, 1.05]); used by Codex detail view.

## 3. Faction-commodity-bias — formalize specialization

- [ ] 3.1 Verify `truckerarchetyperoll.rollFor` already returns `(choice, fallback, strength)` from MVP iterations; no change required if so.
- [ ] 3.2 Verify `truckerassignarchetypes.ensureAssigned` persists `Faction:setValue("trucker_strength", n)`. Add a back-fill branch: if `trucker_archetype` exists but `trucker_strength` does not, roll specialization only (without touching the archetype) and persist.
- [ ] 3.3 Rename internal API: `TruckerAssignArchetypes.getStrength` → `getSpecialization`; keep `getStrength` as a one-line alias for back-compat.
- [ ] 3.4 Verify `truckerpricewrap.lua` stashes both `trucker_station_arch` and `trucker_station_strength` on every wrapped merchant's entity at `initialize` time — confirmed by MVP fix; no code change expected.
- [ ] 3.5 Verify `truckerpricehook.lua` reads both keys from Entity and applies `effectiveBias = 1 + (baseBias - 1) × specialization` — confirmed by MVP fix; no code change expected.

## 4. Quantum Trading AI merchant — at-TP UI

- [ ] 4.1 Rename `data/scripts/entity/merchants/truckerreportmerchant.lua` namespace to `QuantumTradeAI` (file path stays the same for attachment compatibility; update the `-- namespace` directive line and all internal references). Confirm `-- namespace` directive stays on its own line per Avorion's scanner.
- [ ] 4.2 Replace the pre-purchase preview UI with the Trade Report layout: scrollable per-commodity rows (commodity name, best buy `price @ station (sector) Ns ago`, best sell, observation count + range). Layout uses correctly-bounded `Rect(topLeft, bottomRight)` constructors (avoid the inverted-rect bug from MVP).
- [ ] 4.3 Server RPC `serverOpenTradeReport(playerIndex)`: deduct `tradeReportFee` (skip for `infiniteResources`); compute whole-journal aggregation capped at `surveyObservationCap`; return payload via `invokeClientFunction("clientReceiveTradeReport", ...)`.
- [ ] 4.4 Server RPC `serverAcquireFactionSurvey(playerIndex)`: validates affordability, calls `TruckerReports.purchase(...)`, sends success chat + mail-on-first-purchase.
- [ ] 4.5 Client `onShowWindow` triggers `serverOpenTradeReport` (the pay-on-open flow). Show "insufficient credits" state if server returns refusal payload.
- [ ] 4.6 Client renders cross-sell button: "Acquire Faction Survey — N cr" — uses pre-computed N from the report payload. If player owns the Survey, render "Faction Survey owned ✓" status line instead.
- [ ] 4.7 Vocabulary audit: scan all visible strings in the merchant file; remove "vanilla", "bias", "biased", "archetype", "strength", "multiplier". Replace per the mapping in `proposal.md`.

## 5. Trader's Codex — player UI

- [ ] 5.1 Create `data/scripts/player/tradercodexmenu.lua`. Server-side: `initialize()` registers a menu entry via Player's `addScriptOnce` and UI registration pattern (cross-check `avorion-scripts/player/init.lua` for the canonical pattern).
- [ ] 5.2 Add to `data/scripts/player/init.lua` (mod overlay): `player:addScriptOnce("data/scripts/player/tradercodexmenu.lua")` so the menu attaches on player join. Preserve any other mod-attached scripts.
- [ ] 5.3 Create `data/scripts/player/tradercodexpanel.lua` (client-side UI script attached by `tradercodexmenu.lua`). Two-panel layout: list view on top, detail view shown when a row is selected.
- [ ] 5.4 List view: columns Faction, Economy, Specialization (stars rendered via `★`/`☆` glyphs), Sells Low (joined tags), Buys High (joined tags). Implement sort by column header click; default sort = Faction name ascending.
- [ ] 5.5 Server RPC `serverGetCodexList(playerIndex)`: returns array of `{factionId, factionName, economy, specialization, sellsCheap, buysHigh, acquiredAt}` per stored Survey. One-shot; no streaming.
- [ ] 5.6 Detail view: header (faction name, Economy + Specialization stars + word label), sells-low/buys-high tag lines, commodity table (Commodity, Galactic Avg, Faction Avg), "Show Home Sector on Map" button. NO station names. Filter neutral commodities.
- [ ] 5.7 Server RPC `serverGetCodexDetail(playerIndex, factionId)`: returns `{factionName, economy, specialization, sellsCheap, buysHigh, priceBand: [{name, vanilla, expected}, ...]}`. Compute via `TruckerReports.computePriceBand` + `summarizeBias`.
- [ ] 5.8 Empty state: when `serverGetCodexList` returns empty, the list view renders an onboarding line ("Visit any Trading Post and use the Quantum Trading AI to acquire your first Faction Survey.") with no table.
- [ ] 5.9 "Show Home Sector on Map" button → client invokes server RPC `serverGetHomeSector(factionId)`, which returns `(x, y)` via `Faction:getHomeSector()` (or the equivalent stable getter); client opens the galaxy map centered on those coords. If the API returns nil, show a "Home sector unknown" status line instead of opening the map.
- [ ] 5.10 Monochrome rendering audit: no color-only encoding; star characters for Specialization rank; arrow glyphs for sort direction; column alignment + whitespace for grouping.

## 6. First-purchase mail

- [ ] 6.1 Add a one-time flag on player (`Player:setValue("trucker_codex_intro_sent", true)`).
- [ ] 6.2 In `serverAcquireFactionSurvey`, after a successful purchase, check the flag. If absent, send the orientation mail via `TruckerLog.sendMail` and set the flag.
- [ ] 6.3 Mail body draft (plain text, no clickable links): "Captain, your purchase of intel on [Faction] has been filed in your Trader's Codex. Open the Codex from your player menu to review. — Quantum Trading AI"

## 7. Chat command updates

- [ ] 7.1 In `data/scripts/commands/trucker.lua`, rename internal variables and chat output labels: archetype→Economy, strength→Specialization, "Tends CHEAP"/"Tends DEAR" stay as already-renamed "Sells cheap"/"Buys high".
- [ ] 7.2 `/trucker reports` output: render via the new live-render path; include Specialization as `★★★☆☆ (Solidly)` rather than `strength 1.05`.
- [ ] 7.3 `/trucker survey` keeps the chat-text path as admin/diagnostic surface only. Add a one-line hint to its output: "(Visit a Trading Post for the full Quantum Trading AI Trade Report.)"
- [ ] 7.4 `/trucker debug` outputs unchanged in structure; verify it still works after the rename pass.

## 8. Cleanup + verification

- [ ] 8.1 Update `README.md`: terminology pass (Economy / Specialization / Galactic Avg / Faction Avg / Trade Report / Faction Survey); add a "Trader's Codex" section describing the menu button and first-purchase mail; refresh the `/trucker` command list.
- [ ] 8.2 Update `data/config/spacetrucker.lua` doc comments to use the new vocabulary; keep deprecated key aliases noted.
- [ ] 8.3 Delete any stale references to "Sector Survey" and "Faction Commodity Report" from in-mod docs and code comments where they could confuse a future reader. Code-level Lua identifiers can stay (refactor scope is bounded; rename what's player-visible only).
- [ ] 8.4 Manual verification on a fresh galaxy: install the v0.2.0 build, jump through several sectors, observe Economy assignments + Specialization values in the log. *(requires user verification)*
- [ ] 8.5 Manual verification of Codex UI: open player menu, click Trader's Codex with zero entries (see empty state), purchase one Faction Survey at a TP, see first-purchase mail arrive, re-open Codex and see the row + detail view. *(requires user verification)*
- [ ] 8.6 Manual verification of Trade Report at TP: open Quantum Trading AI, confirm the fee deducts, confirm per-commodity rows render with station + sector + relative time, confirm cross-sell button appears/changes based on Survey ownership. *(requires user verification)*
- [ ] 8.7 Manual verification of "Show Home Sector on Map": open Codex detail for any faction, click the button, confirm the galaxy map opens centered on that faction's home sector. *(requires user verification)*
- [ ] 8.8 Manual verification of monochrome rendering: open Codex in default color scheme; confirm Specialization stars, sort direction, neutral-vs-biased commodities, and sells-low/buys-high differ visually without relying on color. *(requires user verification)*
- [ ] 8.9 Multiplayer sanity check: with two players in the same alliance, confirm each player's Codex is independent (no cross-player visibility), and that one player acquiring a Survey does not produce a mail for the other player. *(requires user verification)*
