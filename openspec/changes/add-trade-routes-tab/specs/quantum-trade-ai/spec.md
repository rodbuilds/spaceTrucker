## ADDED Requirements

### Requirement: Quantum Trading AI window uses a tabbed layout

The Quantum Trading AI window SHALL host its content inside a tabbed window with at least two tabs: "Best Prices" (containing the existing per-commodity Trade Report content) and "Trade Routes" (the round-trip loop view). Both tabs SHALL be populated simultaneously when the player runs the Trade Report; the tab strip SHALL be visible regardless of payment state.

#### Scenario: Tabs visible on window open
- **WHEN** a player selects the Quantum Trading AI merchant
- **THEN** the window opens with a tab strip displaying "Best Prices" and "Trade Routes"; the default active tab SHALL be "Best Prices"

#### Scenario: Both tabs unlocked by a single Trade Report payment
- **WHEN** the player pays for a Trade Report (or has a Trade Report already valid in the validity window)
- **THEN** both "Best Prices" and "Trade Routes" SHALL be populated; no separate payment SHALL be required to view either tab

#### Scenario: Tab switching preserves state
- **WHEN** the player switches between tabs after the Trade Report has been run
- **THEN** the previously-displayed content of each tab SHALL remain rendered without an additional server fetch

### Requirement: Trade Routes tab shows round-trip loops by sector pair

The Trade Routes tab SHALL display one row per canonical sector pair (A, B) for which BOTH the outbound A→B leg AND the backhaul B→A leg yield positive per-trip profit. Sector pairs SHALL be canonicalised so that each loop appears exactly once (no duplicate A→B and B→A rows). Pairs where only one direction is profitable SHALL be omitted; those are covered by the Best Prices tab.

#### Scenario: Canonical pair ordering
- **WHEN** the player has profitable observations in both directions between sectors A and B
- **THEN** exactly one row SHALL appear for that pair; the row label distinguishes "From" (canonical first sector) and "To" (canonical second sector)

#### Scenario: One-sided pair excluded
- **WHEN** the player has profitable observations in only one direction between two sectors
- **THEN** no row SHALL appear in the Trade Routes tab for that pair

#### Scenario: Empty journal
- **WHEN** the player has not yet recorded enough observations for any round-trip loop
- **THEN** the Trade Routes tab SHALL display an empty-state message ("Visit more sectors with a Trading System equipped and record observations on BOTH buy and sell sides to discover round-trip loops.") and no table rows

### Requirement: Trade Routes row columns and cell layout

Each Trade Routes row SHALL have seven columns: From (sector coords), To (sector coords), Outbound (commodity + stock/demand + per-unit profit), Out Profit (per-trip total), Backhaul (commodity + stock/demand + per-unit profit), Back Profit (per-trip total), Round-Trip (Out Profit + Back Profit). The Outbound and Backhaul cells SHALL encode `<Commodity>  S:<stock> / D:<demand>  +<perUnitProfit>/u`. The Out Profit / Back Profit / Round-Trip columns SHALL render integer credit totals.

#### Scenario: Row content
- **WHEN** the Trade Routes table renders a row for a profitable loop
- **THEN** the row SHALL include all seven columns with the formats specified

#### Scenario: Trip profit computation
- **WHEN** a per-trip profit is computed for either leg
- **THEN** the value SHALL equal `perUnitProfit × min(buyStationStock, sellStationDemand)` where demand at the seller is `maxStock - currentStock` (or the closest available approximation from the journal record)

### Requirement: Trade Routes uses a vanilla-style sort dropdown

The Trade Routes tab SHALL provide a single combo dropdown for sort selection with explicit-direction entries: "Round-Trip Profit (high to low)" (default), "Round-Trip Profit (low to high)", "Outbound Profit (high to low)", "Backhaul Profit (high to low)", "Distance (shortest first)", "Distance (longest first)", "From Sector (alphabetical)". The dropdown SHALL apply sort client-side without re-requesting data from the server.

#### Scenario: Default sort on first open
- **WHEN** the Trade Routes tab is first displayed
- **THEN** rows SHALL be sorted by Round-Trip Profit descending

#### Scenario: Sort change is client-side
- **WHEN** the player selects a different sort option from the dropdown
- **THEN** the table re-orders without a server round-trip

### Requirement: Cell tooltips disambiguate truncated content

Every dense ListBoxEx cell in the Quantum Trading AI window — both Best Prices commodity cells AND Trade Routes Outbound/Backhaul cells — SHALL register a per-cell tooltip via `setEntryTooltip`. The tooltip SHALL include the full untruncated detail for that cell: full commodity name, full station name, sector coordinates, stock/demand values, per-unit profit, trip cap, trip profit, and age of the contributing observation(s). The visible cell text MAY truncate; the tooltip SHALL NOT.

#### Scenario: Long commodity name in Best Prices
- **WHEN** a row's commodity name (e.g. "Industrial Tesla Coil") exceeds the cell width
- **THEN** the cell SHALL display the truncated name and the tooltip SHALL reveal the full name plus station/sector/price/age detail

#### Scenario: Trade Routes Outbound cell hover
- **WHEN** the player hovers a Trade Routes Outbound or Backhaul cell
- **THEN** the tooltip SHALL include: full commodity name, buy station name + sector, sell station name + sector, stock at buyer, demand at seller, per-unit profit, trip cap (min of stock and demand), and trip profit (per-unit × cap)

#### Scenario: Tooltips do not block interaction
- **WHEN** any tooltip is displayed
- **THEN** the player SHALL still be able to click the cell, sort the table, or interact with other window controls

### Requirement: Trade Routes computation is bounded by the existing observation cap

The Trade Routes computation SHALL reuse the same `surveyObservationCap` configuration that bounds Best Prices. The server function that builds the routes payload SHALL operate over at most that many observations and SHALL return at most a configured top-N pairs (default 50) sorted by round-trip profit descending. Compute time SHALL remain sub-200ms on a player click for the default cap on typical hardware.

#### Scenario: Player with sparse journal
- **WHEN** the player's journal yields fewer round-trip pairs than the cap
- **THEN** the Trade Routes payload SHALL contain all available pairs

#### Scenario: Player with abundant journal
- **WHEN** the journal yields more round-trip pairs than the top-N
- **THEN** only the top-N pairs by round-trip profit SHALL be sent to the client