## Why

The MVP introduced faction-bias pricing, a trade journal, purchased intel, and an at-TP analytics tool, but its presentation is chat-only (`/trucker reports`, `/trucker survey`) and its naming leaks mod-speak ("archetype", "strength", "vanilla price"). Players have no in-game UI to browse purchased intel; they have to remember chat commands and parse dense text. The terms also break immersion — a "Quantum Trading AI" merchant character can't speak in modder jargon.

This change ships the Trader's Codex (a player-menu UI for purchased faction intel) and an in-game **Quantum Trading AI** analytics tool at Trading Posts, while normalizing all player-facing language to in-fiction terms. It also flips the names of the two products to match how players actually use them — what we shipped as "Report" is really a one-shot snapshot (now **Trade Report**), and what we shipped as "Survey" is the permanent archived intel (now **Faction Survey**).

## What Changes

- **BREAKING (terminology)** Swap two product names across all UI, commands, mail, and stored data:
  - Old "Faction Commodity Report" → new **Faction Survey** (permanent codex artifact)
  - Old "Sector Survey" → new **Trade Report** (at-TP one-shot AI analysis)
- **BREAKING (terminology)** Rename in-fiction terms throughout the UI:
  - "archetype" → **Economy** (e.g. "Industrial Economy")
  - "strength" → **Specialization** (displayed as 1–5 stars + word label)
  - "vanilla price" → **Galactic Avg**
  - "biased / expected price" → **Faction Avg**
  - Multipliers (`x0.66`) replaced with side-by-side number comparison
- **Add Trader's Codex** — new player-menu button + window showing all purchased Faction Surveys:
  - List view: Faction, Economy, Specialization (stars), Sells Low / Buys High
  - Detail view: faction header + commodity table (Galactic Avg vs Faction Avg), neutrals filtered, "Highlight Their Territory" button (opens galaxy map with their sectors marked)
  - Sortable columns (alphabetical default; specialization, economy, date acquired also available)
  - First-purchase mail trigger directs the player to the new menu button
- **Add Trade Report at TPs** — paid in-game UI replacement for the current `/trucker survey` chat output:
  - Flat per-use fee (default 50,000 cr)
  - Whole-journal AI analysis (all factions, all sectors visited), surfacing per-commodity best buy/sell stations with coordinates
  - Includes a cross-sell button: "Acquire Faction Survey for [this TP's faction] — N cr"
- **Faction Survey purchase model**:
  - Price formula: `1,000,000 × specialization` (range ~300k–1.8M)
  - Permanently stored in player's Codex; live re-renders from journal each open
  - Only purchasable at the subject faction's own Trading Posts
- **No migration path for MVP-era stored reports.** The mod is pre-release with a single tester; the existing report data does not warrant a migration. Testers create a new galaxy if they encounter legacy data.
- **Monochrome design language** throughout — colorblind-safe; uses weight, glyphs (★, ▲/▼), spacing, and typography for hierarchy
- **Performance architecture**: two-fold query (cheap list, on-demand detail). Configurable safety cap on observations consumed per Trade Report compute (default 2000).
- **Mod display name** updated to **"Space Trucker: Quantum Trade"** in `modinfo.lua` for Workshop searchability

## Capabilities

### New Capabilities
- `trader-codex`: Player-menu UI for browsing purchased Faction Surveys; list view, detail view, sort/filter, "Highlight Their Territory" map action, first-purchase mail trigger.
- `quantum-trade-ai`: Paid at-TP service that analyses the player's whole trade journal and surfaces per-commodity best buy/sell stations with coordinates; includes Faction-Survey cross-sell.

### Modified Capabilities
- `faction-commodity-reports`: Renamed to **Faction Survey** in player-facing language; pricing changes from flat to `1,000,000 × specialization`; sells-cheap/buys-high tag categorization renamed and re-grouped per Economy/Specialization framing; stored content reduced to faction + economy + specialization + timestamp (live re-rendered from journal on view); migration path for old shape.
- `sector-survey-ui`: Renamed to **Trade Report**; access constrained to Trading Posts only (was: chat command); paid per use; whole-journal scope is now the only mode (the previous archetype-hint sub-feature moves into the Trade Report's faction cross-sell section).
- `faction-commodity-bias`: Adds per-faction **specialization** scalar (already present in code after MVP iterations) as a first-class spec requirement; bias multiplier becomes `1 + (baseBias - 1) × specialization`.

## Impact

- **New files**:
  - `data/scripts/player/tradercodexpanel.lua` (client-side codex window)
  - `data/scripts/entity/merchants/quantumtradeai.lua` (at-TP Trade Report merchant; replaces the report-merchant pre-purchase preview)
  - Mail template helper (e.g. `data/scripts/lib/truckermail.lua`)
- **Modified files**:
  - `data/scripts/lib/truckerreports.lua` — content reshaping + rename; migration helper
  - `data/scripts/lib/truckersurvey.lua` — re-scoped to power Trade Report; remove faction-hint output (moves into Trade Report)
  - `data/scripts/lib/truckerarchetypes.lua` — keep specialization helpers; expose star-bucket mapping; rename external accessors to match new terms
  - `data/scripts/entity/merchants/truckerreportmerchant.lua` — repurposed as the Quantum Trading AI merchant
  - `data/scripts/entity/merchants/{tradingpost,headquarters}.lua` — attach the renamed merchant
  - `data/scripts/commands/trucker.lua` — chat commands kept for admin/diagnostics; user-facing surface migrates to UI; rename internal references
  - `data/config/spacetrucker.lua` — new tunables (`tradeReportFee`, `factionSurveyBasePrice`, `surveyObservationCap`); rename existing ones to new vocabulary
  - `modinfo.lua` — `name` → "Space Trucker: Quantum Trade"; `version` → 0.2.0
  - `README.md` — terminology pass; new UI overview
- **Player-facing**:
  - New player-menu button (TBD label: "Trader's Codex"); first-purchase mail
  - At-TP interaction list gains a new entry ("Quantum Trading AI"); the standalone report merchant entry is replaced by it
  - All chat output (`/trucker *`) re-worded; legacy stored reports auto-upgrade
- **Out of scope (future spec)**:
  - Trade Routes tab inside the Trade Report (cross-faction arbitrage)
  - In-place injection into vanilla Trading Overview tabs
  - Codex free-text search and pagination
- **Compatibility**: stored MVP report data continues to load (auto-upgrade). No save break. Mod still wraps the same six merchant namespaces; no new vanilla overlay surfaces.
