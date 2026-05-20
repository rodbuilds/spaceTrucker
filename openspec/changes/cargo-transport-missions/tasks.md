## 1. Project scaffolding

- [x] 1.1 Add `transportmission.lua` and `transportbroker.lua` to `modinfo.lua`'s script list and add the `missionbulletins.lua` file-replacement entry
- [x] 1.2 Create `data/scripts/player/missions/` directory if not already present; create empty `transportmission.lua` stub that logs `[SpaceTrucker] transportmission loaded` via `truckerlog`
- [x] 1.3 Create `data/scripts/entity/merchants/transportbroker.lua` stub that logs `[SpaceTrucker] transportbroker loaded`
- [x] 1.4 Copy vanilla `missionbulletins.lua` to `data/scripts/entity/missionbulletins.lua`; add version comment header identifying the baseline Avorion version and listing transport-mission insertion points

## 2. Mission bulletin board integration

- [x] 2.1 Insert `transportmission.lua` entry for Trading Post (weight 2.5) in the replacement `missionbulletins.lua`
- [x] 2.2 Insert entry for Resource Depot (weight 2.0)
- [x] 2.3 Insert entries for Factory, Habitat, and Biotope (weight 1.5 each)
- [x] 2.4 Verify all vanilla entries are preserved and no weights were accidentally altered

## 3. Transport broker — contract generation

- [x] 3.1 Implement `selectDestination(sourceX, sourceY, sourceFactionId)` in `transportbroker.lua`: calls `SectorSpecifics:getShuffledCoordinates()`, filters for same-faction sectors within 5–30 sector distance, falls back to any non-pirate sector, returns `nil` if none found
- [x] 3.2 Implement `selectCargo(stationTitle, sectorRing)` returning `{good, amount}`: station-type routing table (Trading Post → manufactured, Resource Depot → raw by ring, Factory → production match with fallback, Habitat/Biotope → consumer/bio)
- [x] 3.3 Implement `getRing(destX, destY)` returning `"outer"` / `"mid"` / `"inner"` from distance to galaxy center
- [x] 3.4 Implement `calcAmount(ring, freeSpace)`: zone min/max bounds and `min(cap, floor(freeSpace × fraction))` cap per spec
- [x] 3.5 Implement `calcReward(destX, destY, amount, good, dist)` using `Balancing_GetSectorRewardFactor`, per-unit fee, and distance bonus; expose `speedBonus = total × 0.30` and `speedBonusWindow = dist × 120`

## 4. Transport broker — dialog and cargo loading

- [x] 4.1 Implement `onShowContract(player)` dialog: show cargo type, amount, destination, reward, speed-bonus window; present accept / decline options
- [x] 4.2 Implement cargo-space check before showing accept option: if `freeSpace < minAmount`, show refusal dialog with "I'll come back with a larger ship" and "Not interested" — no accept option
- [x] 4.3 On accept: call `ship:addCargo(good, amount)`, send confirmation mail via `player:sendMail(...)` with contract summary, then call `mission:start(transportmission, contractParams)`
- [x] 4.4 Handle `nil` destination gracefully: if `selectDestination` returns nil, skip contract generation and return from the broker without opening a dialog

## 5. Transport mission — Phase 1 (contract initialisation)

- [x] 5.1 Implement `initialize(contractParams)` in `transportmission.lua`: deserialise and store all fields into `mission.data`; set `mission.data.acceptTime = Server().gameTime`
- [x] 5.2 Implement phase transition to Phase 2 immediately after initialisation (no player action needed in Phase 1 beyond acceptance which already happened at the broker)

## 6. Transport mission — Phase 2 (in-transit)

- [x] 6.1 Implement Phase 2 `onBegin`: register destination sector as HUD waypoint; set mission description string
- [x] 6.2 Implement `getMissionTitle()` and `getMissionDescription()` returning human-readable strings that reference good, amount, station name, and destination sector coords
- [x] 6.3 Implement `update(diff)` in Phase 2: advance `mission.data.elapsed` by `diff`; check if player has entered the destination sector and transition to Phase 3

## 7. Transport mission — Phase 2 ambush + Phase 3 (delivery)

- [x] 7.1 Implement `onPlayerEntered(playerIndex)` in Phase 2: compute `cargoValue = amount × good.price`; if `cargoValue > 50000`, call `triggerSectorAmbush(sector, x, y)` to pre-position pirates via the existing Avorion ambush mechanic
- [x] 7.2 Verify pirates appear pre-positioned in the sector (already waiting) rather than spawning after player entry — no custom spawn sequence needed
- [x] 7.3 Implement Phase 3 entry when the player arrives at the destination sector; no pirate gate — delivery dialog is available as soon as the player docks
- [x] 7.4 Implement `onDelivery(player)` when player docks at destination station: call `ship:removeCargo(good, amount)` and capture actual removed amount; compute proportional reward if partial; apply speed bonus if `elapsed < speedBonusWindow`; call `mission:complete(reward)` with credits and relations
- [x] 7.5 Handle zero-cargo edge case: if `ship:removeCargo` returns 0, call `mission:fail("cargo lost")` with no reward

## 8. Integration and verification

- [x] 8.1 Load mod on a fresh galaxy; confirm both stubs log boot messages and no Lua errors appear in server log
- [ ] 8.2 Open bulletin board at a Trading Post, Resource Depot, and Factory; confirm transport mission entries appear *(requires user verification)*
- [ ] 8.3 Accept a contract, confirm cargo is added to ship hold and confirmation mail arrives *(requires user verification)*
- [ ] 8.4 Complete a transit run: fly to destination, verify HUD marker and mission log entry are correct *(requires user verification)*
- [ ] 8.5 Trigger a pirate ambush run: choose a high-value cargo route, verify pirates spawn and delivery is gated until cleared *(requires user verification)*
- [ ] 8.6 Verify speed bonus: deliver within the window and confirm +30% credit line in the reward message *(requires user verification)*
- [ ] 8.7 Save mid-transit, reload save, confirm mission state (cargo, destination, timer) is intact *(requires user verification)*
- [x] 8.8 Update `README.md` to document the transport mission: how contracts work, pirate ambush mechanics, speed bonus, and the `missionbulletins.lua` maintenance note
