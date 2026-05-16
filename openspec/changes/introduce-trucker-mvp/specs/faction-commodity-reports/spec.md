## ADDED Requirements

### Requirement: Faction Commodity Reports merchant availability

The system SHALL provide a new merchant type, the Faction Commodity Reports merchant, available at Trading Posts and Faction Headquarters in archetype-assigned faction space. The merchant SHALL offer reports for the owning faction of the station, and SHALL NOT offer reports for excluded factions (pirates, smugglers, Xsotan).

#### Scenario: Trading Post in archetype-assigned faction
- **WHEN** a player docks at a Trading Post owned by an archetype-assigned faction
- **THEN** the Faction Commodity Reports merchant interaction SHALL be available, offering at least the report for that station's owning faction

#### Scenario: Faction Headquarters in archetype-assigned faction
- **WHEN** a player docks at a Faction Headquarters owned by an archetype-assigned faction
- **THEN** the Faction Commodity Reports merchant interaction SHALL be available

#### Scenario: Station owned by excluded faction
- **WHEN** a player docks at a station whose owning faction has no archetype assignment (pirate, smuggler, etc.)
- **THEN** the Faction Commodity Reports merchant SHALL NOT be available

### Requirement: Report purchase grants codex artifact

Purchasing a faction commodity report SHALL deduct the configured credit cost from the buyer and SHALL append a new report entry to `Player:setValue("trucker_reports", <table>)`. The entry SHALL include: subject faction id, archetype identity, the resolved bias table summary, an aggregated snapshot of journal observations for that faction's space drawn from the buyer's effective journal (personal + alliance-shared), and a galactic-time purchase timestamp. The snapshot SHALL be a copy at purchase time and SHALL NOT update afterward.

#### Scenario: Successful purchase
- **WHEN** a player purchases a report from the merchant and has sufficient credits
- **THEN** the credits are deducted, a new entry is appended to the player's `trucker_reports`, and the entry includes the subject faction id, archetype name, bias summary, observation snapshot, and timestamp

#### Scenario: Insufficient credits
- **WHEN** a player attempts to purchase a report without sufficient credits
- **THEN** the system SHALL deny the purchase with an informative message and SHALL NOT modify `trucker_reports`

#### Scenario: Snapshot is frozen
- **WHEN** a player views a previously purchased report after time has passed and new observations have entered the journal
- **THEN** the report SHALL display the observations as of its original purchase timestamp; the report SHALL NOT include observations recorded after purchase

#### Scenario: Multiple purchases of the same faction's report
- **WHEN** a player purchases a report for the same faction more than once
- **THEN** each purchase SHALL produce a separate codex entry with its own timestamp and snapshot, allowing side-by-side comparison

### Requirement: Report pricing scales by faction characteristics

The credit cost of a faction commodity report SHALL scale by characteristics of the subject faction. The minimum implementation SHALL include scaling by faction power (larger factions cost more) and SHALL NOT charge a uniform flat price. Operators SHALL be able to configure the scaling formula coefficients.

#### Scenario: Larger faction costs more
- **WHEN** the merchant prices a report for a high-power faction versus a low-power faction
- **THEN** the high-power faction's report SHALL be more expensive

#### Scenario: Operator tunes pricing
- **WHEN** the server operator changes the configured pricing coefficients
- **THEN** subsequent merchant interactions SHALL price reports using the new coefficients

### Requirement: Codex display of archetype and bias summary

The codex view of a purchased report SHALL display the subject faction name, the assigned archetype, a human-readable summary of which commodity categories tend cheap and which tend dear under the archetype's bias table, and the original purchase timestamp.

#### Scenario: Open report in codex
- **WHEN** a player opens a purchased report in the codex
- **THEN** the rendered view SHALL include the faction name, archetype name, "Tends CHEAP" and "Tends DEAR" commodity-category lists, the snapshot's best-buy and best-sell observations, and a "Purchased <timestamp>" line

### Requirement: Live war-status warning badge

When a report is rendered in the codex, the system SHALL query live faction relations for the report's subject faction. If the subject faction is currently at war with one or more factions, the rendered view SHALL append a "⚠ AT WAR with X" warning badge naming the at-war counterpart(s). The warning SHALL be derived live at render time and SHALL NOT be cached in the report data.

#### Scenario: Faction goes to war after report purchase
- **WHEN** a player views a previously-purchased report whose subject faction is now at war (war declared after purchase)
- **THEN** the rendered view SHALL show the war warning badge, even though the snapshot is older than the war

#### Scenario: Faction not at war
- **WHEN** a player views a report whose subject faction is currently at peace
- **THEN** no war warning badge SHALL be rendered

#### Scenario: Faction at war with multiple counterparts
- **WHEN** the subject faction is at war with two or more other factions
- **THEN** the rendered warning SHALL list all current at-war counterparts

### Requirement: Reports are non-transferable in v1

In this version, reports SHALL exist only as personal codex entries on the purchasing player. Reports SHALL NOT be giftable, tradeable, or visible to alliance members other than via independent purchase. Player-to-player intel exchange is explicitly out of scope.

#### Scenario: Alliance member cannot read another member's reports
- **WHEN** a player queries the codex while in an alliance
- **THEN** the system SHALL display only that player's own purchased reports; no alliance-shared report store SHALL exist
