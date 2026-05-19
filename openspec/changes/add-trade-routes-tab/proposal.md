## Why

The v0.2.0 Quantum Trading AI answers "what should I buy/sell?" via the Best Prices tab — a per-commodity view of best buys and best sells. That's good for spot trades but it doesn't answer the trader's strategic question: "what **loop** should I run?" A profitable Iron run from sector A → B is worth more if there's a profitable Servo run back from B → A; together that's a round trip and the player commits to the route.

Adding a **Trade Routes** tab surfaces round-trip loops as the unit of decision — one row per sector pair, with outbound and backhaul collapsed into a single trip total. It uses the same journal data the AI already crunches, so no new data sources are required.

This change also unifies the **sort UI** across the Quantum Trading AI and the Trader's Codex. Today the Codex uses four "Sort: X" buttons (one per criterion); vanilla Avorion uses a single dropdown combo with explicit direction entries (per `avorion-scripts/player/ui/diplomacy.lua`). Standardizing on the dropdown pattern makes both surfaces feel native and lets us add the Trade Routes sort options without inventing new UI vocabulary.

Finally, it introduces **cell tooltips** on every dense listbox — Best Prices commodity cells, Trade Routes trade cells, Codex commodity table — to solve the truncation problem we already silently have for long commodity names like "Industrial Tesla Coil". The truncated cell stays compact; the hover reveals the full picture. Vanilla precedent: `sectorshipoverview.lua` uses `setEntryTooltip` extensively.

## What Changes

- **Add a Trade Routes tab** to the Quantum Trading AI window
  - Tabbed window (two tabs: Best Prices, Trade Routes) — preserves the existing Best Prices content
  - Trade Routes row = sector pair (A, B), canonicalised so each loop appears once
  - 7 columns: From | To | Outbound | Out Profit | Backhaul | Back Profit | Round-Trip
  - "Outbound" / "Backhaul" cells encode `<Commodity>  S:<stock> / D:<demand>  +<profit>/u`
  - "Out Profit" / "Back Profit" = `per-unit profit × min(stock, demand)` (trip total)
  - "Round-Trip" = Out Profit + Back Profit
  - Filters to pairs where BOTH legs have profit > 0 (one-way trades belong in Best Prices)
  - Canonical sector-pair ordering so A→B→A and B→A→B aren't shown as separate rows
  - Empty state: "Visit more sectors and record both buy and sell observations to discover round-trip loops."
- **Distance** is dropped from the row but kept as a sort option (Euclidean, integer sectors)
- **Sort UI standardisation** — switch from buttons to dropdowns
  - Trade Routes tab: dropdown with Round-Trip Profit (high → low) as default
  - Codex list: dropdown replaces the four Sort: buttons; same options exposed but with explicit direction entries
- **Tooltips on dense listbox cells**
  - Best Prices tab — hover any commodity cell to see full station + sector + price + observation count + age
  - Trade Routes tab — hover Outbound / Backhaul cell to see commodity, both station names, both sector coords, stock + demand context, trip cap, trip profit
  - Codex commodity table — hover a row to see the underlying multiplier, tag category, and bias direction
- **Validity window applies to both tabs** — paying for the Trade Report (existing flow) unlocks both Best Prices and Trade Routes for the configured validity window (default 1 hour). One payment, two tabs.
- **Quantum Trading AI window resized slightly** (from 900×600 to ~950×640) to give the tabbed header room without compressing the tables

## Capabilities

### New Capabilities

(none — this is a refinement of existing capabilities)

### Modified Capabilities

- `quantum-trade-ai`: Adds the Trade Routes tab as a sibling view inside a tabbed window; the existing Trade Report becomes the "Best Prices" tab. Adds the sort dropdown requirement. Adds the cell-tooltip requirement.
- `trader-codex`: Replaces the multi-button sort UI with a single dropdown (same sort options, more explicit direction control). Adds tooltips to commodity table rows.

## Impact

- **New files**: none
- **Modified files**:
  - `data/scripts/entity/merchants/truckerreportmerchant.lua` — add tabbed window, second ListBoxEx for Trade Routes, sort dropdown for each tab, tooltip wiring on both tables
  - `data/scripts/player/tradercodex.lua` — replace the 4-button sort bar with a dropdown; add tooltips to the commodity table
  - `data/scripts/lib/truckerreports.lua` — add `computeRoundTripRoutes(player)` server function that returns canonical sector-pair rows with both legs computed
  - `data/config/spacetrucker.lua` — no new keys (uses existing `surveyObservationCap`)
  - `openspec/specs/quantum-trade-ai/spec.md`, `openspec/specs/trader-codex/spec.md` — updated via deltas
- **Player-facing**:
  - Quantum Trading AI window now has two tabs after running a Trade Report; the existing flow (pay → table loads) is preserved
  - Codex sort changes from buttons to a dropdown; sort options expand (explicit asc/desc per criterion)
  - Hover tooltips appear on dense listbox cells everywhere we have them
- **Out of scope (future)**:
  - Multi-leg routes (A → B → C → A)
  - Cross-faction arbitrage routes powered by Faction Surveys (Direction C from exploration)
  - Profit-per-jump column / time-aware sort
  - Waypoint-pin action per route row
  - Filter "show only routes touching faction X"
- **Compatibility**: No save break, no migration required. Existing Trade Report payments and validity flags continue to work. New tab requires only a code-side rewire of the merchant UI.
