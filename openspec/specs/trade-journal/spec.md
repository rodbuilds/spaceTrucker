# trade-journal Specification

## Purpose

Capture per-player and alliance-shared observations of station commodity prices and stock when a Trading-System-equipped ship enters a sector, persist them durably, cap their size, and expose query APIs used by the survey UI and the report generator.

## Requirements

### Requirement: Observation capture on Trading-System sector entry

The system SHALL record one journal observation per (station, commodity, action) tuple when a player's controlled ship enters a loaded sector while equipped with a Trading System upgrade. Capture SHALL fire on sector entry only, not on every UI interaction or per-tick. Each observation SHALL include: station identifier, station name, sector coordinates, owning faction id, commodity name, commodity category, action (`buy` or `sell`), price, current stock, maximum stock, and a galactic-time timestamp.

#### Scenario: Equipped trader enters a sector with stations
- **WHEN** a player's ship with a Trading System upgrade enters a loaded sector containing stations
- **THEN** the server-side capture hook iterates each station and records an observation per buyable and sellable commodity into that player's journal

#### Scenario: Player ship without Trading System enters a sector
- **WHEN** a player's ship without a Trading System upgrade enters a sector
- **THEN** no journal observations SHALL be recorded for that sector entry

#### Scenario: Sector with no stations
- **WHEN** a player's ship with a Trading System upgrade enters a loaded sector containing zero stations
- **THEN** the capture hook SHALL run, find no stations, and produce zero observations without error

#### Scenario: Re-entry to same sector
- **WHEN** a player re-enters a sector they have visited before
- **THEN** new observations SHALL be appended to the journal with the current timestamp; previous observations for the same station/commodity pair SHALL NOT be deleted

### Requirement: Per-player journal persistence

The journal SHALL persist across game sessions via `Player:setValue("trucker_journal", <table>)`. The journal table SHALL be readable by the player's client-side UI without round-tripping through additional persistence layers.

#### Scenario: Server restart preserves journal
- **WHEN** the server restarts and a player rejoins
- **THEN** the player's prior journal entries SHALL still be present and queryable

#### Scenario: Player joins fresh on a new save
- **WHEN** a player joins a server with no prior journal data
- **THEN** the journal SHALL be initialized as empty without error

### Requirement: Journal size cap with oldest-first pruning

The journal SHALL be capped at a configurable maximum entry count (default 5,000). When a new observation would exceed the cap, the system SHALL prune the oldest entries (by timestamp) until the journal is below the cap before appending.

#### Scenario: Cap reached on append
- **WHEN** a new observation is recorded and the journal is at the cap
- **THEN** the oldest entries SHALL be removed in chronological order until there is room, and the new observation SHALL be appended

#### Scenario: Cap configurable
- **WHEN** the server operator changes the configured cap value
- **THEN** subsequent capture events SHALL respect the new cap

### Requirement: Journal queryability by commodity, faction, and sector

The journal SHALL support read queries by commodity name, by owning faction id, and by sector coordinates, returning matching observations in chronological order (newest first). Query implementations SHALL be available to both the survey UI and the report-generation system.

#### Scenario: Query by commodity name
- **WHEN** UI code queries the journal for observations of `MedicalSupplies`
- **THEN** the system SHALL return all matching observations across all sectors and factions, newest first

#### Scenario: Query by faction
- **WHEN** the report-generation system queries the journal for observations within faction id 42
- **THEN** the system SHALL return all observations whose `owning faction id` field equals 42

#### Scenario: Query by sector coordinates
- **WHEN** UI code queries the journal for observations in sector (47, -12)
- **THEN** the system SHALL return all observations recorded in that sector

### Requirement: Alliance auto-share on observation

When a player records a journal observation and is a member of an alliance, the same observation SHALL be appended to a shared alliance journal stored at `Alliance:setValue("trucker_journal_shared", <table>)`. Alliance members reading their effective journal SHALL see the union of their personal entries and the alliance-shared entries, deduplicated by (station, commodity, action, timestamp). The alliance-shared journal SHALL respect the same size cap and oldest-first pruning rules as the per-player journal.

#### Scenario: Alliance member observation propagates
- **WHEN** an alliance member with a Trading System captures observations in a sector
- **THEN** those observations SHALL appear in the alliance-shared journal and SHALL be readable by other alliance members on their next journal query

#### Scenario: Player not in alliance
- **WHEN** a non-aligned player captures observations
- **THEN** observations SHALL be written only to that player's personal journal; no alliance store SHALL be touched

#### Scenario: Player leaves alliance
- **WHEN** a player leaves an alliance
- **THEN** previously-shared alliance entries SHALL remain in the alliance store for remaining members; the leaving player SHALL retain only their personal journal entries
