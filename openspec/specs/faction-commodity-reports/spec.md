# faction-commodity-reports Specification

## Purpose

Provide an in-game pathway for players to acquire per-faction Faction Surveys — minimal, live-rendered intel artifacts identifying a faction's Economy and Specialization — through the Quantum Trading AI merchant at Trading Posts and Faction Headquarters, and persist acquired Surveys as personal entries on the buying player.

## Requirements

### Requirement: Faction Survey purchase available at Trading Posts and Headquarters

The system SHALL make Faction Survey acquisition available at every Trading Post and Faction Headquarters whose owning faction has an assigned Economy. The acquisition action SHALL only offer a Survey for the station's OWN faction; players SHALL NOT be able to acquire a Survey for any other faction at this station. Acquisition is presented as a button inside the Quantum Trading AI Trade Report window (see quantum-trade-ai capability), not as a standalone merchant interaction.

#### Scenario: Trading Post in Economy-assigned faction
- **WHEN** a player opens the Quantum Trading AI Trade Report at a Trading Post owned by an Economy-assigned faction
- **THEN** an "Acquire Faction Survey — N cr" action SHALL be present, where the subject faction is the station's owning faction

#### Scenario: Faction Headquarters in Economy-assigned faction
- **WHEN** a player opens the Quantum Trading AI Trade Report at a Faction Headquarters owned by an Economy-assigned faction
- **THEN** the same "Acquire Faction Survey" action SHALL be present for that station's owning faction

#### Scenario: Station owned by excluded faction
- **WHEN** a player is at a station whose owning faction has no Economy assignment (pirate, smuggler, etc.)
- **THEN** the Quantum Trading AI merchant SHALL NOT be available, and therefore no Faction Survey acquisition path SHALL exist at that station

### Requirement: Faction Survey purchase grants codex artifact

Acquiring a Faction Survey SHALL deduct the configured credit cost from the buyer and SHALL append a new entry to the player's stored Survey collection. The entry SHALL contain the minimum identifying information required to live-render the Survey: subject faction id, faction display name, economy identifier, specialization scalar, and acquisition timestamp. The entry SHALL NOT cache any commodity table, bias summary, journal snapshot, or other derived data — all of which are live-rendered at view time (see trader-codex capability).

#### Scenario: Successful acquisition
- **WHEN** a player acquires a Faction Survey with sufficient credits
- **THEN** the credits SHALL be deducted, and a new minimal entry (faction id, name, economy, specialization, timestamp) SHALL be appended to the player's stored Survey collection

#### Scenario: Insufficient credits
- **WHEN** a player attempts to acquire a Faction Survey without sufficient credits
- **THEN** the system SHALL refuse the purchase with an informative message and SHALL NOT modify the player's Survey collection

#### Scenario: Re-acquiring the same faction
- **WHEN** a player acquires a Faction Survey for a faction they already have a Survey for
- **THEN** the prior entry for that faction SHALL be replaced by the new acquisition (no duplicate entries) and the acquisition timestamp SHALL update to the current time; the credit cost SHALL still be charged

### Requirement: Faction Survey pricing scales by Specialization

The credit cost of acquiring a Faction Survey SHALL be computed as `factionSurveyBasePrice × specialization`, where `factionSurveyBasePrice` is a configuration value (default 1,000,000 cr) and `specialization` is the per-faction scalar persisted by faction-commodity-bias. Higher Specialization SHALL produce a higher Survey price. The system SHALL NOT charge a flat per-faction price.

#### Scenario: Higher Specialization costs more
- **WHEN** the price is computed for two factions of the same Economy but different Specializations (e.g. 0.5 vs 1.5)
- **THEN** the higher-Specialization faction's Survey SHALL cost proportionally more

#### Scenario: Operator tunes base price
- **WHEN** the server operator changes `factionSurveyBasePrice` in `data/config/spacetrucker.lua`
- **THEN** subsequent acquisition prompts SHALL use the new base value

#### Scenario: Edge specialization at bounds
- **WHEN** Specialization is at the minimum (e.g. 0.3) or maximum (e.g. 1.8) of its defined range
- **THEN** the price SHALL compute correctly for those endpoints without error

### Requirement: Stored Faction Survey content is minimal and live-rendered

The Faction Survey stored on the player SHALL contain only the identifying information necessary to reconstruct its display via live computation. The system SHALL NOT persist commodity tables, sells-cheap/buys-high tag lists, journal snapshots, or war-status data. All such display content SHALL be derived at render time from the live state of the player's journal, the faction's current Economy, and the faction's current Specialization.

#### Scenario: Minimal stored fields
- **WHEN** the server reads a stored Faction Survey entry
- **THEN** the entry SHALL include subject faction id, faction name, economy, specialization, acquisition timestamp — and SHALL NOT include cached commodity tables, snapshots, or summary tag lists

#### Scenario: Faction state evolves after acquisition
- **WHEN** a player views a previously-acquired Faction Survey after the faction's Economy or Specialization has changed via a future game mechanic
- **THEN** the rendered view SHALL reflect the current Economy and Specialization, not the values at acquisition time

#### Scenario: Legacy MVP entries are silently skipped
- **WHEN** the server reads a stored Survey entry persisted under the MVP schema (missing the `economy` field)
- **THEN** the system SHALL skip that entry without rendering it; a single one-time warning per galaxy SHALL be logged. Players SHALL create a new galaxy to reset; no auto-upgrade SHALL be performed.

<!--
Removed in add-quantum-trade-codex: "Live war-status warning badge".
Reason: `Faction:getRelationsStatuses` is not exposed in this Avorion build; a per-render scan via
`Galaxy():getFactionRelationStatus` against every other faction is prohibitively expensive. The
requirement is dropped honestly until a viable API surface exists.
-->

### Requirement: Faction Surveys are non-transferable

A Faction Survey SHALL exist only as a personal entry on the acquiring player. Surveys SHALL NOT be giftable, tradeable, or visible to other players or alliance members. Each player SHALL acquire their own Survey for any faction whose intel they wish to view.

#### Scenario: Alliance member cannot read another member's Surveys
- **WHEN** a player opens their Codex while in an alliance
- **THEN** the Codex SHALL display only that player's own acquired Surveys; no alliance-shared Survey store SHALL exist
