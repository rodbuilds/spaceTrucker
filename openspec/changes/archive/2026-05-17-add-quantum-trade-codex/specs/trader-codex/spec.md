## ADDED Requirements

### Requirement: Trader's Codex player-menu entry

The system SHALL register an entry on the player's main menu labelled "Trader's Codex" that opens a client-side Codex window. The entry SHALL be available to every player regardless of whether they currently own any Faction Surveys; the window's empty state SHALL onboard the player to acquiring their first Survey.

#### Scenario: Player opens menu with at least one acquired Survey
- **WHEN** a player clicks the Trader's Codex menu entry and has one or more Faction Surveys
- **THEN** the Codex window SHALL open and display the list view populated with the player's Surveys

#### Scenario: Player opens menu with zero acquired Surveys
- **WHEN** a player clicks the Trader's Codex menu entry and owns no Surveys
- **THEN** the Codex window SHALL open in its empty state, displaying an onboarding line that directs the player to visit a Trading Post and acquire a Faction Survey

#### Scenario: Menu entry persists across save/reload
- **WHEN** a player logs out and logs back in
- **THEN** the Trader's Codex menu entry SHALL remain available; no per-player re-registration step SHALL be required

### Requirement: Codex list view shows acquired Faction Surveys

The Codex list view SHALL display one row per acquired Faction Survey. Each row SHALL include the faction name, the faction's Economy (e.g. "Industrial"), a Specialization indicator rendered as one to five stars, and a short summary of the "Sells Low" and "Buys High" commodity-category tags. Row data SHALL be fetched from the server via an explicit RPC at window-open time; no per-frame polling SHALL occur.

#### Scenario: Row content
- **WHEN** the list view renders a row for an acquired Survey
- **THEN** the row SHALL show: faction name, Economy name, Specialization stars (1–5), Sells Low tag list, Buys High tag list

#### Scenario: List fetch is one-shot
- **WHEN** the Codex window opens
- **THEN** the client SHALL issue exactly one RPC to the server to obtain the list payload and SHALL NOT re-request the list on cursor movement, hover, or other UI events

### Requirement: Codex list view is sortable

The Codex list view SHALL support sorting by Faction name, Economy, Specialization (stars), and Date Acquired. The default sort SHALL be alphabetical by Faction name. The active sort SHALL be visually indicated. The sort SHALL be applied client-side over the already-fetched list payload.

#### Scenario: Default sort
- **WHEN** the Codex window opens
- **THEN** rows SHALL be sorted alphabetically by Faction name ascending

#### Scenario: User changes sort
- **WHEN** the user clicks a column header (or selects a sort option)
- **THEN** the rows SHALL re-sort accordingly without issuing a new server request

### Requirement: Codex detail view shows faction profile without station references

When the user opens a Survey row, the Codex SHALL render a detail view for that single faction containing: faction name; Economy name and Specialization (stars plus word label such as "Heavily" / "Pure"); the Sells Low and Buys High tag lists; and a commodity table comparing Galactic Avg to Faction Avg for every commodity whose Faction Avg differs from its Galactic Avg by more than a configured threshold. Commodities whose Faction Avg equals their Galactic Avg (neutral commodities) SHALL be filtered out of the detail-view table. The detail view SHALL NOT include any station names or sector coordinates; station-attributed data lives in the Quantum Trading AI Trade Report (separate capability).

#### Scenario: Open detail view
- **WHEN** the user clicks a row in the Codex list view
- **THEN** the client SHALL fetch the detail payload via a single RPC and render the detail view

#### Scenario: Neutral commodities are filtered
- **WHEN** the detail view renders the commodity table for a faction
- **THEN** commodities whose Faction Avg equals their Galactic Avg SHALL NOT appear in the table

#### Scenario: No station names in detail
- **WHEN** the detail view renders
- **THEN** no station name, station entity id, or sector coordinate SHALL appear in the detail view content

### Requirement: Show Home Sector on Map action

The detail view SHALL provide a "Show Home Sector on Map" action that opens the galaxy map and centers on the subject faction's home sector. The action SHALL NOT enumerate or visually mark individual stations or territory boundaries; its sole purpose is to give the player a one-click way to navigate toward the faction.

#### Scenario: Show home sector
- **WHEN** the user clicks "Show Home Sector on Map"
- **THEN** the galaxy map SHALL open centered on the faction's home sector

#### Scenario: Faction without a queryable home sector
- **WHEN** the faction's home sector cannot be retrieved (API returns nil, or the faction lacks a home)
- **THEN** the action SHALL display a non-blocking message ("Home sector unknown") and SHALL NOT crash or leave the UI in a broken state

### Requirement: First-purchase mail trigger

The first time a player acquires any Faction Survey, the system SHALL send the player an in-game mail informing them that the Survey has been filed in their Codex and instructing them to access the Codex from the player menu. The mail SHALL be sent at most once per player; subsequent Survey purchases SHALL NOT trigger additional mails.

#### Scenario: First Survey ever
- **WHEN** a player completes their very first Faction Survey purchase
- **THEN** the system SHALL send a single in-game mail to that player; the mail SHALL describe the Codex and the player-menu entry point

#### Scenario: Subsequent purchases
- **WHEN** a player completes a Faction Survey purchase and has previously received the first-purchase mail
- **THEN** the system SHALL NOT send any additional mail for this purchase

### Requirement: Codex content is live-rendered, not frozen

Codex list and detail views SHALL be live-rendered from the player's current state at view time (purchased Surveys + the faction's current Economy and Specialization). The system SHALL NOT cache rendered content in the Survey's stored payload; the persisted Survey contains only the minimum identifying information (faction id, name, economy, specialization, acquisition timestamp).

#### Scenario: Faction state changes after purchase
- **WHEN** a Survey was acquired and the underlying Economy or Specialization later evolves (e.g. via a future game mechanic)
- **THEN** subsequent Codex views of that Survey SHALL reflect the current state, not the state at purchase time

#### Scenario: Stored payload is minimal
- **WHEN** the server inspects a stored Survey entry
- **THEN** the entry SHALL contain only: subject faction id, faction display name, economy identifier, specialization scalar, acquisition timestamp

### Requirement: Monochrome-safe presentation

All Codex visual elements SHALL convey information without relying on color encoding. Hierarchy, status, and direction SHALL be expressed via typography weight, glyph shape (such as star characters and arrow glyphs), spacing, and column alignment. Color SHALL NOT be the sole carrier of meaningful information.

#### Scenario: Colorblind-safe rendering
- **WHEN** the Codex renders in any color scheme
- **THEN** every meaningful distinction (specialization rank, sort direction, neutral vs biased commodity, sells-low vs buys-high) SHALL be conveyed by a non-color cue
