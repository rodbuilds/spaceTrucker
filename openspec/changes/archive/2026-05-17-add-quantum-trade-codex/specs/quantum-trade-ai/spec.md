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

### Requirement: Trade Report is a paid per-use service with explicit consent

Selecting the Quantum Trading AI merchant SHALL open the window for FREE. The window SHALL display a "Pay X cr to run Trade Report" button (label includes the fee from `tradeReportFee`, default 50,000 cr) and SHALL NOT display report content until the player clicks that button. Clicking it SHALL deduct the fee, after which the Trade Report content SHALL load. Players with `infiniteResources` SHALL still see the explicit button but SHALL NOT have credits deducted. If the player cannot pay, the system SHALL display an "insufficient credits" message and leave the button enabled.

#### Scenario: Opening the window is free
- **WHEN** a player selects the Quantum Trading AI merchant
- **THEN** the window opens immediately with no credit deduction; the pay-to-run button is displayed showing the configured fee

#### Scenario: Running the report charges the fee
- **WHEN** a player with sufficient credits clicks the pay-to-run button
- **THEN** the fee is deducted and the Trade Report content (commodity table) loads

#### Scenario: Insufficient credits at run time
- **WHEN** a player without sufficient credits clicks the pay-to-run button
- **THEN** the system displays an "insufficient credits" message and the button stays enabled so the player can try again later

#### Scenario: Creative mode / infinite resources
- **WHEN** a player with `infiniteResources` clicks the pay-to-run button
- **THEN** the report content loads without credit deduction

### Requirement: Paid Trade Report stays valid for a configurable window

After a player pays for a Trade Report, the report SHALL remain valid for the next `tradeReportValiditySeconds` seconds (default 3600 — one hour). During the validity window, reopening the Quantum Trading AI at ANY Trading Post or Headquarters SHALL auto-load the Trade Report content without any additional payment. The window SHALL display the remaining validity time. Validity is per-player and persisted via `Player:setValue`.

#### Scenario: Reopen during validity
- **WHEN** a player pays for a Trade Report and reopens the Quantum Trading AI window before the validity window expires
- **THEN** the report content auto-loads without prompting for payment; the window shows the remaining validity time

#### Scenario: Reopen at a different station during validity
- **WHEN** a player pays at one Trading Post and reopens the Quantum Trading AI at a different Trading Post or Headquarters within the validity window
- **THEN** the report auto-loads for free; validity is global per player, not per station

#### Scenario: Validity expires
- **WHEN** a player reopens the Quantum Trading AI after the validity window has expired
- **THEN** the pay-to-run button reappears and the player must pay again to load report content

### Requirement: Faction Survey acquisition unlocks only after a Trade Report has been run

The "Acquire Faction Survey" button in the Quantum Trading AI window SHALL be inactive until the player has run the Trade Report at least once during this window session. Once a Trade Report has been run, the button SHALL become active and display the Survey price (Faction Survey acquisition still costs `factionSurveyBasePrice × specialization` as defined elsewhere).

#### Scenario: Survey unavailable before running report
- **WHEN** the Quantum Trading AI window first opens (Trade Report not yet run)
- **THEN** the Acquire Faction Survey button is visible but inactive; a status line explains that running the Trade Report unlocks it

#### Scenario: Survey unlocks after running report
- **WHEN** the player has clicked the pay-to-run button and the Trade Report has loaded
- **THEN** the Acquire Faction Survey button becomes active; clicking it begins the Survey acquisition flow as defined in faction-commodity-reports

#### Scenario: Survey owned already
- **WHEN** the player already owns a Faction Survey for the current station's faction
- **THEN** the button displays "Faction Survey owned" and is inactive regardless of whether the Trade Report has been run this session

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
