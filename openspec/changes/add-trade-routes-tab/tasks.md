## 1. Server: Round-trip route computation

- [x] 1.1 `computeRoundTripRoutes(player)` added with the documented payload shape.
- [x] 1.2 Canonical lex ordering by `(x, y)`; `bucketBySector` returns the sorted list and the pair loop uses `i < j` indexing so each pair appears once.
- [x] 1.3 Per-sector best-buy / best-sell buckets; `bestRouteBetween` picks max-profit commodity per direction; demand = `max(0, maxStock - stock)` for sell-side rows.
- [x] 1.4 Filter to pairs where BOTH `bestOut` and `bestBack` exist (each requires perUnit > 0).
- [x] 1.5 Distance = `floor(sqrt(dx^2 + dy^2))`.
- [x] 1.6 `MAX_PAIRS = 50` cap; respects `OBSERVATION_CAP` when scanning journal.
- [x] 1.7 `serverRunTradeReport` now sends `(priceRows, routeRows, remainingSeconds)`; single payment populates both tabs.

## 2. Merchant UI: Tabbed window

- [x] 2.1 Confirmed `ScriptUI() → createWindow → createContainer → createTabbedWindow` works in entity-script merchants (vanilla `entitydbg.lua:191-199`). No fallback needed.
- [x] 2.2 Window resized 900×600 → 950×640.
- [x] 2.3 Best Prices content moved into `bestPricesTab` (no behavioural change).
- [x] 2.4 Trade Routes tab added next to Best Prices; populated when `clientReceiveTradeReportRows` arrives.
- [x] 2.5 Default active tab on window open is "Best Prices" (vanilla TabbedWindow defaults to first-added tab).

## 3. Merchant UI: Trade Routes table

- [x] 3.1 7-column ListBoxEx built with widths From 8% | To 8% | Outbound 24% | Out Profit 11% | Backhaul 24% | Back Profit 11% | Round-Trip 14%; rowHeight 22.
- [x] 3.2 Rows render From/To as `(x,y)`; Outbound/Backhaul cells use `<Commodity>  S:<stock> / D:<demand>  +<perUnit>/u` format; profit columns as `+<n> cr`.
- [x] 3.3 Per-cell tooltips on Outbound (col 2) and Backhaul (col 4) include full commodity name, both station names, both sector coords, stock, demand, per-unit profit, trip cap, trip profit, and observed-buy/sell ages.
- [x] 3.4 Empty-state label registered ("Visit more sectors...") and shown when routes payload is empty.
- [x] 3.5 ListBoxEx is natively scrollable; the 50-pair cap fits within the table's scroll region with no additional setup.

## 4. Merchant UI: Trade Routes sort dropdown

- [x] 4.1 ComboBox added with all 7 entries in the spec'd order; default = index 0 (Round-Trip Profit high to low).
- [x] 4.2 `onRoutesSortChanged` reads `selectedIndex`, re-sorts `cachedRouteRows` client-side, calls `setRouteRows`; no server round-trip.
- [x] 4.3 First render uses default sort via `sortRoutes(cachedRouteRows, routesSortMode)` in `clientReceiveTradeReportRows`.

## 5. Merchant UI: Best Prices tooltip retrofit

- [x] 5.1 `setEntryTooltip` registered on all 4 columns (Commodity / Best Buy / Best Sell / Margin) per row.
- [x] 5.2 Tooltip text includes full commodity name, station + sector + price + age for both sides, observation count, range, and margin breakdown.

## 6. Codex UI: sort dropdown retrofit

- [x] 6.1 Four `Sort: <X>` buttons removed.
- [x] 6.2 `ComboBox` added with all 7 entries in the spec'd order; default selected index = 0 (Faction A-Z).
- [x] 6.3 Refresh button preserved alongside the dropdown.
- [x] 6.4 `onSortChanged` re-sorts `cachedList` and calls `refreshListBox()` client-side only.
- [x] 6.5 Old per-criterion handlers (`onSortByFaction` etc.) removed; replaced by `onSortChanged` reading `selectedIndex`. `SORT_OPTIONS` array drives label + comparator parity.

## 7. Codex UI: commodity table tooltip retrofit

- [x] 7.1 `setEntryTooltip` registered on all 3 columns (Commodity, Galactic Avg, Faction Avg) per row.
- [x] 7.2 Tooltip includes full commodity name, tag category, faction multiplier (e.g. "x0.66"), Galactic Avg, Faction Avg, and the credit delta. Server payload extended with `tag` + `multiplier` fields.

## 8. Documentation + cleanup

- [x] 8.1 README updated: Quantum Trading AI bullet now describes both tabs; Trade Routes feature added; Trader's Codex bullet mentions hover tooltips; "Player menu" section describes the new sort dropdown.
- [x] 8.2 No new config keys needed; existing `surveyObservationCap` governs Trade Routes compute. No doc-comment changes required.
- [x] 8.3 Grep sweep clean: no stale references to "4 buttons", "Sort:", or "toggle direction" remain in `data/scripts`.

## 9. Manual verification (requires user)

- [ ] 9.1 Deploy v0.3.0 and open the Quantum Trading AI at a Trading Post. Confirm the tab strip appears with "Best Prices" and "Trade Routes". *(requires user verification)*
- [ ] 9.2 Pay for a Trade Report. Confirm both tabs populate; switch between them and confirm content persists. *(requires user verification)*
- [ ] 9.3 Hover a Best Prices commodity cell with a long name (e.g. Industrial Tesla Coil if observed). Confirm the tooltip shows the full name plus station/sector/price/age. *(requires user verification)*
- [ ] 9.4 Switch to the Trade Routes tab. Confirm sector-pair rows are present (assuming sufficient journal); hover an Outbound or Backhaul cell and confirm the tooltip reveals the full detail. *(requires user verification)*
- [ ] 9.5 Change the Trade Routes sort dropdown to "Outbound Profit (high to low)" and confirm the table re-sorts without a delay. *(requires user verification)*
- [ ] 9.6 Open the Trader's Codex. Confirm the sort bar is now a single dropdown plus Refresh; cycle through sort entries and confirm rows re-order. *(requires user verification)*
- [ ] 9.7 Click a Codex row; in the detail commodity table, hover a row and confirm the tooltip shows the multiplier + tag category + credit delta. *(requires user verification)*
- [ ] 9.8 With a sparse journal (1 sector visited), confirm the Trade Routes tab shows the empty-state message rather than a table. *(requires user verification)*
- [ ] 9.9 Reopen the Quantum Trading AI within the 1-hour validity window and confirm both tabs auto-populate without re-charging. *(requires user verification)*
