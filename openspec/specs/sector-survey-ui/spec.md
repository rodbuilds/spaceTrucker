# sector-survey-ui Specification

## Purpose

Inject a client-side Sector Survey panel into the vanilla station trade view that cross-references each displayed commodity against the player's effective trade journal and surfaces archetype hints for the current station's owning faction.

## Requirements

### Requirement: Sector Survey panel injected into vanilla station trade view

The system SHALL inject a Sector Survey panel into the vanilla station trade view at all merchant types that expose a buy/sell commodity table to the player. The panel SHALL be added in-place; the vanilla view's existing controls and layout SHALL NOT be removed or replaced. The panel SHALL render only on the client side.

#### Scenario: Player opens trade view at a Trading Post
- **WHEN** a player opens the trade view at a Trading Post
- **THEN** the Sector Survey panel SHALL appear within the trade window alongside the vanilla buy/sell controls

#### Scenario: Vanilla controls preserved
- **WHEN** the Sector Survey panel is rendered
- **THEN** all vanilla buy, sell, quantity, and confirm controls SHALL remain present and functional

#### Scenario: Server-side context unaffected
- **WHEN** the panel is rendered or hidden on the client
- **THEN** no server-side state SHALL be modified by the rendering action itself

### Requirement: Journal cross-reference for visible commodities

For each commodity displayed in the vanilla trade view, the Sector Survey panel SHALL display the player's best-buy and best-sell observation for that commodity drawn from the player's effective journal (personal + alliance-shared). Each cross-reference SHALL identify the station name, sector coordinates, observed price, and a relative timestamp ("3 days ago"). When no journal entry exists for a commodity, the panel SHALL display a neutral "No observations yet" indicator for that row.

#### Scenario: Commodity with prior observations
- **WHEN** the trade view shows `MedicalSupplies` and the player's journal contains observations for that commodity
- **THEN** the panel SHALL show the lowest-priced buy observation and the highest-priced sell observation, with station, sector, price, and relative time

#### Scenario: Commodity with no observations
- **WHEN** the trade view shows a commodity not present in the player's journal
- **THEN** the panel SHALL display "No observations yet" for that row instead of price data

#### Scenario: Alliance-shared observation surfaces
- **WHEN** another alliance member's observation is the player's best-known price for a commodity
- **THEN** the panel SHALL surface that observation and SHALL visually distinguish it as alliance-shared

### Requirement: Archetype hint badge for current faction

When a report has been purchased for the owning faction of the current station, the Sector Survey panel SHALL display an archetype hint badge naming the archetype and listing the categories that tend cheap and tend dear. When no report has been purchased for the current faction, the panel SHALL show a neutral "Faction archetype unknown — purchase a Faction Commodity Report" prompt instead.

#### Scenario: Player has report for current faction
- **WHEN** the player opens the trade view at a station whose owning faction has a report in the player's codex
- **THEN** the panel SHALL display the archetype name and a one-line bias summary

#### Scenario: Player has no report for current faction
- **WHEN** the player opens the trade view at a station whose owning faction has no purchased report
- **THEN** the panel SHALL display the "archetype unknown — purchase a Faction Commodity Report" prompt and SHALL NOT reveal the archetype identity

### Requirement: Graceful degradation without Trading System

When the player's controlling ship lacks a Trading System upgrade, the vanilla trade view's behavior is constrained by the engine. The Sector Survey panel SHALL still render its journal cross-reference for whatever commodities are visible, and SHALL continue to display the archetype hint badge if a report is held; the panel SHALL NOT crash, error, or block the vanilla view in this configuration.

#### Scenario: No Trading System equipped
- **WHEN** the player opens the trade view without a Trading System upgrade
- **THEN** the panel SHALL render against whatever commodity rows the vanilla view exposes, displaying journal data where available

### Requirement: Empty-state behavior on first install

The Sector Survey panel SHALL render gracefully when the player has zero journal entries and zero purchased reports. In this state, the panel SHALL display a brief onboarding line ("Your trade journal will fill as you visit sectors with a Trading System equipped.") and SHALL NOT show error states.

#### Scenario: Brand new player opens trade view
- **WHEN** a player with no journal entries and no reports opens the trade view
- **THEN** the panel SHALL render the onboarding line, the per-commodity rows SHALL show "No observations yet", and the archetype area SHALL show the unknown-faction prompt
