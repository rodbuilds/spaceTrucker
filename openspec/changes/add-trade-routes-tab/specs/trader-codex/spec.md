## MODIFIED Requirements

### Requirement: Codex list view is sortable

The Codex list view SHALL support sorting via a single vanilla-style combo dropdown with explicit-direction entries: "Faction Name (A-Z)" (default), "Faction Name (Z-A)", "Economy (A-Z)", "Specialization (high to low)", "Specialization (low to high)", "Date Acquired (newest first)", "Date Acquired (oldest first)". The dropdown SHALL apply sort client-side over the already-fetched list payload; no server round-trip SHALL occur on sort change.

#### Scenario: Default sort
- **WHEN** the Codex window opens
- **THEN** rows SHALL be sorted alphabetically by Faction name ascending (the default dropdown entry)

#### Scenario: User changes sort via the dropdown
- **WHEN** the user selects a different sort entry from the dropdown
- **THEN** the rows SHALL re-sort accordingly without issuing a new server request

#### Scenario: Sort UI matches vanilla pattern
- **WHEN** the Codex sort control is rendered
- **THEN** it SHALL be a single combo dropdown (no separate per-criterion buttons); each entry SHALL include explicit direction

## ADDED Requirements

### Requirement: Codex commodity table rows expose full detail via hover tooltips

Each row in the Codex detail view's commodity table SHALL register a tooltip via `setEntryTooltip` that reveals the underlying multiplier (e.g. "x0.66"), the tag category (raw / refined / industrial / consumer / civil / military / hightech / illegal), and the absolute price delta (Faction Avg − Galactic Avg). Visible cell text MAY truncate; the tooltip SHALL include the full untruncated commodity name and the bias context.

#### Scenario: Hover a commodity row in Codex detail
- **WHEN** the player hovers any row in the commodity table of a Faction Survey detail view
- **THEN** a tooltip SHALL show the full commodity name, its tag category, the multiplier this faction applies to the category, and the credit delta (Faction Avg − Galactic Avg)

#### Scenario: Long commodity name display
- **WHEN** a commodity name exceeds the visible cell width
- **THEN** the cell text MAY truncate visually but the tooltip SHALL show the full name
