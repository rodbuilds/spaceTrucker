## 1. Foundation — vocabulary + config

- [x] 1.1 Add new config keys to `data/config/spacetrucker.lua`: `tradeReportFee` (default 50_000), `factionSurveyBasePrice` (default 1_000_000), `surveyObservationCap` (default 2000). Keep MVP keys as deprecated aliases that map to the new ones on `apply()`.
- [x] 1.2 Add specialization-to-stars + label helpers to `data/scripts/lib/truckerarchetypes.lua`: `specializationToStars(s) -> 1..5`, `specializationLabel(s) -> "Lightly"|"Modestly"|"Solidly"|"Heavily"|"Pure"`. Bucket boundaries match spec.
- [x] 1.3 Update `data/scripts/lib/truckerlog.lua` with a shared mail helper `TruckerLog.sendMail(player, subject, body)` (wraps vanilla mail API); leaves logging functions unchanged.
- [x] 1.4 Update `modinfo.lua`: `title = "Space Trucker: Quantum Trade"`; bump `version` to `0.2.0`. Keep `saveGameAltering = true`.

## 2. Faction Survey persistence — storage migration

- [x] 2.1 New minimal entry shape `{subjectFactionId, subjectFactionName, economy, specialization, acquiredAt}` in `truckerreports.lua`.
- [x] 2.2 `readSurveys`/`writeSurveys` via `TruckerSerialize`. Silently skip entries without `economy`. One-time legacy-warn flag stored on player.
- [x] 2.3 `TruckerReports.purchase` rewritten: minimal entry, replaces same-faction entries, uses `getSpecialization`. (Affordability check lives in the merchant — see §4.4.)
- [x] 2.4 `TruckerReports.priceFor(faction)` returns `PRICE_BASE * specialization` via `getSpecialization` (alias to `getStrength`).
- [x] 2.5 `atWarWith` and all war-status code paths removed.
- [x] 2.6 `TruckerReports.summarizeBias(economy, specialization)` uses effective (specialization-adjusted) bias.
- [x] 2.7 `TruckerReports.computePriceBand(economy, specialization)` filters neutrals, sorts by multiplier asc.

## 3. Faction-commodity-bias — formalize specialization

- [x] 3.1 `truckerarchetyperoll.rollFor` returns `(choice, fallback, specialization)` — verified.
- [x] 3.2 Back-fill branch added to `ensureAssigned`: if archetype exists but specialization is missing, roll specialization only.
- [x] 3.3 `getSpecialization` is now the canonical method; `getStrength` aliases it.
- [x] 3.4 `truckerpricewrap.lua` stashes both keys on entity — verified by grep.
- [x] 3.5 `truckerpricehook.lua` reads both keys and applies effective bias — verified by grep.

## 4. Quantum Trading AI merchant — at-TP UI

- [x] 4.1 Namespace renamed to `QuantumTradeAI`; `-- namespace` directive on its own line; file path unchanged for attachment compatibility.
- [x] 4.2 Trade Report layout in place: fee line, body label (per-commodity rows with station + sector + relative age + stats), status line, Acquire button. Rects properly bounded.
- [x] 4.3 `serverOpenTradeReport` deducts `TRADE_REPORT_FEE` (skips for `infiniteResources`), builds whole-journal aggregation, sends payload via `invokeClientFunction("clientReceiveTradeReport", ...)`.
- [x] 4.4 `serverAcquireFactionSurvey` validates affordability, charges price, calls `TruckerReports.purchase`, sends chat confirmation + first-purchase mail.
- [x] 4.5 Client `onShowWindow` triggers `serverOpenTradeReport`; insufficient-credits state renders cleanly.
- [x] 4.6 Cross-sell button: "Acquire Faction Survey" with price in status line, or "Faction Survey owned : on file in your Codex" when owned.
- [x] 4.7 Vocabulary audit: only matches are code identifiers (storage keys + include paths), no player-facing strings.

## 5. Trader's Codex — player UI

- [x] 5.1 *Simplified*: single file `data/scripts/player/tradercodex.lua` handles both menu registration and UI (matches vanilla `encyclopedia.lua` pattern — separation into two files was unnecessary).
- [x] 5.2 `data/scripts/player/init.lua` now attaches `tradercodex.lua` on player join (and preserves the existing observer script).
- [x] 5.3 Same as 5.1: list-on-top / detail-on-bottom layout inside a single tab on `PlayerWindow`.
- [x] 5.4 List shows Faction / Economy / Specialization (stars as `*`/`.` for source safety; spec allows alternate glyphs at render time) / Sells / Buys, with sort buttons for Faction / Economy / Specialization / Acquired. Default = Faction ascending; second click toggles direction.
- [x] 5.5 `serverGetCodexList` returns the array shape; pushed to client via `clientReceiveCodexList`.
- [x] 5.6 Detail view: header (name + Economy + stars + word label), sells/buys lines, commodity table (Galactic Avg / Faction Avg), "Show Home Sector on Map" button. No station names. Neutrals filtered by `computePriceBand`.
- [x] 5.7 `serverGetCodexDetail` returns the detail payload, computed via `computePriceBand` + `summarizeBias`. Trimmed to top 40 rows with "(showing top N of M)" truncation hint.
- [x] 5.8 Empty-state label "Visit any Trading Post..." rendered when the list is empty.
- [x] 5.9 `serverShowHomeSector` returns `(x, y)` via `Faction:getHomeSectorCoordinates()` with `faction.homeSector` fallback; client opens galaxy map via `GalaxyMap():show(x, y)`; nil response renders "Home sector unknown" status.
- [x] 5.10 Monochrome: stars (ASCII), column alignment, whitespace dividers, no color-only encoding.

## 6. First-purchase mail

- [x] 6.1 One-time flag `trucker_codex_intro_sent` set on player.
- [x] 6.2 `serverAcquireFactionSurvey` checks the flag; if absent, sends mail via `TruckerLog.sendMail` and sets the flag.
- [x] 6.3 Mail body drafted inline, plain text, addresses the captain and points to the player menu.

## 7. Chat command updates

- [x] 7.1 Command rewritten with new vocabulary (Economy / Specialization / Galactic Avg / Faction Avg); survey lib `formatArchetypeHint` also updated.
- [x] 7.2 `/trucker reports` renders via `renderSurvey` with stars + word label; live-computed price band via `computePriceBand`. Added `/trucker codex` as a friendly alias.
- [x] 7.3 `/trucker survey` appended with the "Visit a Trading Post for the full Quantum Trading AI Trade Report." hint.
- [x] 7.4 `/trucker debug` still works; label updated to "Faction Surveys: N" (was "Reports purchased: N").

## 8. Cleanup + verification

- [x] 8.1 README rewritten with new title "Space Trucker: Quantum Trade", new What-it-does section, Trader's Codex section, updated config + commands lists, upgrade note.
- [x] 8.2 `data/config/spacetrucker.lua` rewritten with new vocabulary; deprecated key aliases noted in comment + handled in `apply()`.
- [x] 8.3 Stale player-facing references swept; only Lua identifiers (function names, storage keys) retain old terms for compat.
- [x] 8.10 Rewrote `modinfo.lua` `description` per D12 into a player-facing pitch (multi-paragraph, story-led, explains Economy / Specialization / Trade Report / Codex without modder jargon).
- [ ] 8.4 Manual verification on a fresh galaxy: install the v0.2.0 build, jump through several sectors, observe Economy assignments + Specialization values in the log. *(requires user verification)*
- [ ] 8.5 Manual verification of Codex UI: open player menu, click Trader's Codex with zero entries (see empty state), purchase one Faction Survey at a TP, see first-purchase mail arrive, re-open Codex and see the row + detail view. *(requires user verification)*
- [ ] 8.6 Manual verification of Trade Report at TP: open Quantum Trading AI, confirm the fee deducts, confirm per-commodity rows render with station + sector + relative time, confirm cross-sell button appears/changes based on Survey ownership. *(requires user verification)*
- [ ] 8.7 Manual verification of "Show Home Sector on Map": open Codex detail for any faction, click the button, confirm the galaxy map opens centered on that faction's home sector. *(requires user verification)*
- [ ] 8.8 Manual verification of monochrome rendering: open Codex in default color scheme; confirm Specialization stars, sort direction, neutral-vs-biased commodities, and sells-low/buys-high differ visually without relying on color. *(requires user verification)*
- [ ] 8.9 Multiplayer sanity check: with two players in the same alliance, confirm each player's Codex is independent (no cross-player visibility), and that one player acquiring a Survey does not produce a mail for the other player. *(requires user verification)*
