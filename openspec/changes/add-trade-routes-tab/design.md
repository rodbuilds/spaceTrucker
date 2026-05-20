## Context

v0.2.0 shipped the Quantum Trading AI with a single Trade Report view (per-commodity best buy / best sell / margin). Playtesting confirmed the data is valuable but the **shape** isn't optimal for committed trading: players want to know "what loop do I run" not "what's the next single trade." The Trade Routes tab introduces a sector-pair lens over the same journal data.

Several smaller items also accumulated during the v0.2.0 iteration that are best bundled here:

1. **Sort UI inconsistency** — Codex uses four buttons (toggle direction on second click); vanilla Avorion uses a single combo dropdown with explicit direction entries (`avorion-scripts/player/ui/diplomacy.lua:783-794`). Adding Trade Routes sort options as more buttons would compound the divergence.
2. **Silent truncation in dense cells** — long commodity names like "Industrial Tesla Coil" already clip in the existing Best Prices Commodity column. We've been getting away with it because testing used short-name commodities.
3. **No multi-line wrap in ListBoxEx** — confirmed by code search: vanilla never wraps in listbox cells. `rowHeight = 25` is universal. Wrapping is not an option.

The data foundation is already in place: `TruckerJournal` records stock and maxStock per observation; `TruckerReports.computeObservationStats` aggregates by commodity. We extend with a new server function that produces sector-pair rows.

## Goals / Non-Goals

**Goals:**

- Make the trader's strategic question — "what loop do I run?" — first-class in the Quantum Trading AI UI
- Standardise sort UI on the vanilla dropdown pattern so future surfaces reuse the convention without inventing new vocabulary
- Solve the long-commodity-name truncation problem properly across every dense listbox in the mod (Best Prices, Trade Routes, Codex commodity table)
- Reuse the existing fee + validity flow — no new payment surface; the Trade Report fee covers both tabs
- Keep monochrome-safe rendering throughout
- Keep changes additive — no schema changes, no save break, no migration

**Non-Goals:**

- Multi-leg routes (A → B → C → A) — graph problem, future spec
- Cross-faction arbitrage routes using Faction Survey predictive prices — explored as "Direction C" but deferred
- Per-route waypoint pin action — vanilla Trade Routes has it via the pin icon; nice-to-have, defer
- Profit-per-jump efficiency column — would help veterans but adds noise for new players
- "Show only routes touching faction X" filter — future iteration
- Renaming or restructuring the existing Best Prices content beyond adding tooltips

## Decisions

### D1. Trade Routes row = canonical sector pair, one row per loop

**Decision:** Group journal observations by sector pair `(A, B)` with canonical ordering (sort the two coords so A is always the "lower" one — e.g. by x then y). Each pair is one row. The outbound direction is A → B; backhaul is B → A.

**Why:** A round trip A→B→A is the same loop as B→A→B. Showing both creates duplicates the player has to mentally dedupe. Canonical ordering gives each LOOP one row.

**Alternatives considered:**
- *One row per direction* — duplicates each loop, doubles the table, no information gain.
- *Per-station pairs instead of per-sector pairs* — within a sector, multiple stations are reasonable to dock at sequentially. Player decisions happen at sector granularity; stations are an implementation detail of "the best station in that sector for this commodity."

### D2. Outbound / Backhaul cell format: combined inline

**Decision:** Cells in columns 3 and 5 render `<Commodity>   S:<stock> / D:<demand>   +<perUnitProfit>/u`. Long commodity names truncate visually; the cell's tooltip provides the full text plus the underlying station + sector detail.

**Why:** Splitting Stock, Demand, profit/unit into their own columns explodes to 11+ columns at 900px, with each cell narrow enough that everything truncates. The combined format keeps the row navigable while making the bottleneck visually obvious — the smaller of `S:80 / D:40` is where the player will be capped.

**Alternatives considered:**
- *Icon + name columns* — vanilla Trading Overview's pattern. Adds 2 columns and an icon-recognition learning curve. Rejected for v1; tooltips solve the same disambiguation problem more cheaply.
- *Separate columns for stock and demand* — surfaces sortability per metric, but pushes column count past readable; deferred.

### D3. Tooltips solve truncation; no icons in v1

**Decision:** Use `ListBoxEx:setEntryTooltip(column, row, text)` on every cell that may truncate. Tooltip text contains the full canonical detail (commodity name in full, both station names, both sector coords, stock/demand context, trip cap, trip profit, age of observation). Apply the same pattern to Best Prices and Codex.

**Why:** Wrapping isn't supported in ListBoxEx cells. Icons add columns and a learning curve. Tooltips are a vanilla-native pattern (`sectorshipoverview.lua:648-654`) that gives unlimited per-cell detail without bloating the table.

### D4. Sort UI: single combo dropdown (vanilla pattern)

**Decision:** Replace the Codex's four "Sort:" buttons with a single `ComboBox` populated with explicit-direction entries ("Faction Name (A-Z)", "Faction Name (Z-A)", "Specialization (high to low)", etc.). Trade Routes gets its own combo (default: Round-Trip Profit (high to low)).

**Why:** Vanilla's `diplomacy.lua` does exactly this; it's the established pattern. The current toggle-on-second-click behavior is hidden, undiscoverable, and inconsistent with what Avorion players expect.

**Alternatives considered:**
- *Click column headers to sort* — confirmed not supported in vanilla; would be inventing UI.
- *Per-column ascending button + descending button* — visually noisy.

### D5. Trade Routes filters to round-trip loops only (both legs profitable)

**Decision:** Only show sector pairs where both outbound and backhaul have computable profit > 0. Pairs where only one direction is profitable are already represented in Best Prices' Margin column.

**Why:** The Trade Routes tab's distinct value is showing **loops**. Including one-sided trades dilutes that focus and creates redundancy with Best Prices. The empty/sparse state ("Visit more sectors and record both buy and sell observations") onboards the player toward what they need to do.

**Alternatives considered:**
- *Show one-sided routes with $0 backhaul* — clutters the table for no new info.
- *Toggle to show one-sided* — premature UI complexity; revisit if requested.

### D6. Tabs inside the Quantum Trading AI window

**Decision:** Wrap the existing Trade Report content + new Trade Routes content in a `TabbedWindow`. Two tabs: "Best Prices" (existing) and "Trade Routes" (new). The pay-to-run gating and 1-hour validity window apply to BOTH tabs simultaneously — a single Trade Report payment unlocks both views.

**Why:** The two views answer different questions and use different row shapes (per-commodity vs per-sector-pair). Tabs let the player switch lenses without losing the paid state. Vanilla Trading Overview uses tabs for the same reason. The validity-window unification respects the player's payment.

**Alternatives considered:**
- *Stacked panels* — long scroll, less navigable, two empty tables visible at once.
- *Replace Best Prices with Trade Routes* — loses the per-commodity lens; some players want it.
- *Separate fees per tab* — punishes the player twice for what feels like one analysis.

### D7. Window resize: 950×640

**Decision:** Bump the Quantum Trading AI window from 900×600 to 950×640 to accommodate the tab strip header without compressing the table rows.

**Why:** The Best Prices commodity table already runs close to the bottom edge; adding a ~30px tab strip would push the Acquire button into too-tight territory. 50px more width / 40px more height gives breathing room with no impact at common resolutions.

### D8. Round-trip computation: O(M² × C) at the player's observation cap

**Decision:** Server-side `computeRoundTripRoutes(player)` enumerates the player's distinct visited sectors (M), then for each unordered pair (A, B) computes the best A → B route per commodity and the best B → A route per commodity. Total candidates bounded by `M² × commodities`, capped at the existing `surveyObservationCap`.

**Why:** With typical playtest counts (M ≈ 20-30 sectors, C ≈ 30 commodities seen per sector), the worst case is a few thousand operations — sub-100ms in Lua. No need for a new performance config knob.

**Implementation note:** Returns top-N pairs (default 50) sorted by round-trip profit descending; client can re-sort using the dropdown without round-tripping to the server.

### D9. Empty-state messaging — actionable, not blame

**Decision:** When `computeRoundTripRoutes` returns zero pairs (no round-trip loops yet), show: "Visit more sectors with a Trading System equipped and record observations on BOTH buy and sell sides to discover round-trip loops." When it returns pairs but all have margin <= 0, show: "No profitable round-trip loops in your current journal."

**Why:** The MVP / v0.2 empty states phrased the message in observation terms. For Trade Routes, the player needs to understand that BOTH legs of a loop must be observed; an empty state that says "no routes" doesn't tell them why.

## Risks / Trade-offs

- **[TabbedWindow inside a merchant interaction window may not be straightforward]** → Mitigation: vanilla `sectorshipoverview.lua` uses `tabbedWindow = window:createTabbedWindow(rect)` cleanly, but that's on the Hud, not a merchant ScriptUI window. If the merchant `ScriptUI()` container doesn't support `createTabbedWindow`, fall back to two side-by-side tables or a manual "tab" implemented via show/hide of containers + a button strip. Document the chosen approach in the implementation tasks.
- **[Long commodity name truncation still visible in the cell]** → Mitigation: tooltips recover the full text on hover. Acceptable.
- **[Round-trip data sparseness early game]** → Mitigation: empty-state guidance; Best Prices tab still provides immediate value.
- **[Players might not discover hover tooltips]** → Mitigation: subtitle copy in the Quantum Trading AI window mentions "hover any row for full details" once tooltips are in.
- **[Distance metric — Euclidean vs Manhattan vs jump count]** → Mitigation: Euclidean (rounded) is simplest and matches what the player sees on the galaxy map. If players ask for jump count later, swap in a smarter metric without changing the sort dropdown.

## Migration Plan

- v0.2.0 (current) is the starting baseline.
- v0.3.0 ships this change. No save break, no migration.
- On first player login after upgrade:
  - The Codex sort UI swaps from 4 buttons to a dropdown — players will see the new control on next Codex open; default sort unchanged (Faction A-Z).
  - The Quantum Trading AI window now opens as a tabbed window — first time players open it post-upgrade, they'll see the tab strip; default tab is "Best Prices" so the existing flow continues unchanged.
- No rollback needed; both surfaces are read-only views over data we already persist.
