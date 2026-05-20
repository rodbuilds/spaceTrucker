## ADDED Requirements

### Requirement: Transport mission registered on Trading Post bulletin boards
The `missionbulletins.lua` replacement SHALL insert a transport mission entry with probability weight 2.5 for stations whose title is "Trading Post".

#### Scenario: Trading Post bulletin board queried
- **WHEN** a player opens the bulletin board at a Trading Post station
- **THEN** the transport mission script (`data/scripts/player/missions/transportmission.lua`) SHALL appear among the eligible mission entries with weight 2.5

### Requirement: Transport mission registered on Resource Depot bulletin boards
The `missionbulletins.lua` replacement SHALL insert a transport mission entry with probability weight 2.0 for stations whose title is "Resource Depot".

#### Scenario: Resource Depot bulletin board queried
- **WHEN** a player opens the bulletin board at a Resource Depot station
- **THEN** the transport mission script SHALL appear among the eligible mission entries with weight 2.0

### Requirement: Transport mission registered on Factory, Habitat, and Biotope bulletin boards
The `missionbulletins.lua` replacement SHALL insert transport mission entries with probability weight 1.5 for stations whose title is "Factory", "Habitat", or "Biotope".

#### Scenario: Factory bulletin board queried
- **WHEN** a player opens the bulletin board at a Factory station
- **THEN** the transport mission script SHALL appear among the eligible mission entries with weight 1.5

#### Scenario: Habitat bulletin board queried
- **WHEN** a player opens the bulletin board at a Habitat station
- **THEN** the transport mission script SHALL appear among the eligible mission entries with weight 1.5

#### Scenario: Biotope bulletin board queried
- **WHEN** a player opens the bulletin board at a Biotope station
- **THEN** the transport mission script SHALL appear among the eligible mission entries with weight 1.5

### Requirement: Bulletin board replacement preserves all vanilla entries
The replacement `missionbulletins.lua` SHALL include all mission entries present in the vanilla file and add only the transport mission entries — no vanilla missions are removed or reweighted.

#### Scenario: Vanilla missions still appear at stations
- **WHEN** a player opens any bulletin board that had vanilla missions before the mod was installed
- **THEN** all vanilla mission types SHALL still appear with their original weights alongside the new transport mission entry

### Requirement: Bulletin board file versioned and documented
The replacement `missionbulletins.lua` SHALL carry a header comment identifying the base vanilla version it was derived from, so maintainers can detect when a vanilla update requires re-syncing the file.

#### Scenario: Maintainer reviews the replacement file
- **WHEN** a developer opens `data/scripts/entity/missionbulletins.lua` in the mod
- **THEN** the first comment block SHALL state the Avorion version the vanilla baseline was taken from and list the transport mission insertion points by line number
