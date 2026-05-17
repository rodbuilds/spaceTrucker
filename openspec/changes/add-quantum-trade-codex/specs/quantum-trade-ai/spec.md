## ADDED Requirements

### Requirement: Quantum Trading AI merchant at Trading Posts and Headquarters

The system SHALL attach a Quantum Trading AI merchant interaction to every Trading Post and Faction Headquarters whose owning faction has an assigned Economy (i.e. is not in the excluded faction set). The merchant SHALL NOT be available at stations of excluded factions.

#### Scenario: Player approaches a Trading Post of an Economy-assigned faction
- **WHEN** a player opens the interaction menu at a Trading Post whose owning faction has an assigned Economy
- **THEN** the interaction list SHALL include a "Quantum Trading AI" entry

#### Scenario: Player approaches a Headquarters of an Economy-assigned faction
- **WHEN** a player opens the interaction menu at a Faction Headquarters whose owning faction has an assigned Economy
- **THEN** the interaction list SHALL include a "Quantum Trading AI" entry

#### Scenario: Excluded faction stations
- **WHEN** a player approaches a station owned by an excluded faction (pirate, smuggler, Xsotan, story-only)
- **THEN** the Quantum Trading AI merchant entry SHALL NOT be available

### Requirement: Trade Report is a paid per-use service

Selecting the Quantum Trading AI merchant SHALL open a Trade Report window. Opening the Trade Report SHALL charge the player a flat fee defined by the `tradeReportFee` configuration value (default 50,000 cr). If the player cannot pay, the window SHALL display a clear "insufficient credits" message and SHALL NOT render report content. Each successful purchase SHALL produce one Trade Report view; closing and reopening the window SHALL incur another charge.

#### Scenario: Successful Trade Report purchase
- **WHEN** a player with sufficient credits opens the Trade Report
- **THEN** the configured fee SHALL be deducted and the Trade Report content SHALL render

#### Scenario: Insufficient credits
- **WHEN** a player attempts to open the Trade Report without sufficient credits
- **THEN** the system SHALL display an "insufficient credits" message naming the required amount and SHALL NOT deduct any credits or render report content

#### Scenario: Creative mode / infinite resources
- **WHEN** a player with `infiniteResources` opens the Trade Report
- **THEN** the system SHALL render the report regardless of the credit check (matching vanilla behaviour at other paid merchants)

### Requirement: Trade Report scope is the player's entire journal

The Trade Report SHALL analyse the player's entire trade journal (personal observations plus any alliance-shared observations available to the player), not only observations within the current station's faction. The intent is that the Quantum Trading AI exceeds the range of the vanilla Trading Subsystem upgrade by drawing on the player's accumulated travels.

#### Scenario: Whole-journal aggregation
- **WHEN** the Trade Report renders
- **THEN** observation data displayed SHALL be drawn from the player's complete effective journal regardless of the station's owning faction

### Requirement: Trade Report shows per-commodity best buy / best sell with station attribution

For each commodity the player has observation data for, the Trade Report SHALL display the lowest-priced buy observation and the highest-priced sell observation, each attributed by station name and sector coordinates, with a relative time stamp ("12h ago"). The report SHALL also show the aggregate count of observations contributing to each line and the observed price range.

#### Scenario: Commodity with observations
- **WHEN** the report renders a commodity the player has observed buying or selling
- **THEN** the row SHALL show: commodity name, best buy price + station + sector + age, best sell price + station + sector + age, observation count

#### Scenario: Commodity with no observations
- **WHEN** a commodity exists in the goods catalog but is absent from the player's journal
- **THEN** that commodity SHALL be omitted from the report (it SHALL NOT show "no observations" placeholder rows)

### Requirement: Trade Report performance is bounded

The Trade Report aggregation SHALL be capped at `surveyObservationCap` observations (default 2000), drawing the newest entries first. The cap SHALL be invisible to the player but configurable by server operators. Compute time SHALL remain sub-100ms on a player click for the default cap on typical hardware.

#### Scenario: Player with journal under the cap
- **WHEN** a player's total observation count is below the cap
- **THEN** all observations SHALL be considered in the aggregation

#### Scenario: Player with journal above the cap
- **WHEN** a player's total observation count exceeds the cap
- **THEN** only the most recent `surveyObservationCap` observations SHALL be considered

### Requirement: Faction Survey cross-sell in Trade Report

The Trade Report window SHALL display a clearly-labelled action to acquire the Faction Survey for the current station's owning faction, including the computed price (per faction-commodity-reports pricing). If the player already owns a Faction Survey for that faction, the action SHALL be replaced by a non-actionable status line confirming ownership.

#### Scenario: Faction Survey not yet owned
- **WHEN** a player opens the Trade Report at a station whose owning faction has no Survey in the player's Codex
- **THEN** the Trade Report SHALL display an "Acquire Faction Survey — N cr" action where N is the computed price

#### Scenario: Faction Survey already owned
- **WHEN** a player opens the Trade Report at a station whose owning faction has a Survey in the player's Codex
- **THEN** the Trade Report SHALL display a "Faction Survey owned" status line and SHALL NOT display the acquire action

### Requirement: Quantum Trading AI displays no biased pricing language

All Trade Report text SHALL use the immersive vocabulary established by this change: "Galactic Avg" rather than "vanilla price"; "Faction Avg" rather than "biased" or "expected"; "Economy" rather than "archetype"; "Specialization" (or stars) rather than "strength" or "multiplier". Modder jargon SHALL NOT appear in any player-facing text.

#### Scenario: Vocabulary audit
- **WHEN** any player-facing label or message renders inside the Quantum Trading AI window
- **THEN** the displayed text SHALL NOT include the words "vanilla", "bias", "biased", "archetype", "strength", or "multiplier"
