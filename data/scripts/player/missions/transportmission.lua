package.path = package.path .. ";data/scripts/lib/?.lua;data/scripts/entity/merchants/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
include("goods")
include("randomext")
include("utility")
include("callable")
include("galaxy")
include("relations")
include("stringutility")

local Log                  = include("truckerlog")
local SectorSpecifics      = include("sectorspecifics")
local Balancing            = include("galaxy")
local AsyncPirateGenerator = include("asyncpirategenerator")
local SpawnUtility         = include("spawnutility")
local MissionUT            = include("missionutility")
local Broker               = include("transportbroker")

Log.info("transportmission loaded")

-- ============================================================
-- Shared sector-distance helper
-- ============================================================
local function sectorDist(x1, y1, x2, y2)
    return math.floor(math.sqrt((x2-x1)^2 + (y2-y1)^2))
end

-- ============================================================
-- Mission metadata (top-level defaults)
-- ============================================================
mission.data.title            = "Transport Contract"%_t
mission.data.brief            = mission.data.title
mission.data.autoTrackMission = true

mission.data.description    = {}
mission.data.description[1] = {text = "Transport cargo to a distant station for a reward."%_T}
mission.data.description[2] = {text = "Dock at ${giver} to pick up your cargo."%_T,
                                bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[3] = {text = "Deliver ${amount} ${good} to ${station} in sector (${x}:${y})."%_T,
                                bulletPoint = true, fulfilled = false, visible = false}

mission.data.custom.goodName         = ""
mission.data.custom.amount           = 0
mission.data.custom.displayAmount    = 0
mission.data.custom.destX            = 0
mission.data.custom.destY            = 0
mission.data.custom.ring             = "outer"
mission.data.custom.reward           = 0
mission.data.custom.speedBonus       = 0
mission.data.custom.speedBonusWindow = 0
mission.data.custom.relations        = 0
mission.data.custom.elapsed          = 0
mission.data.custom.destStationId    = ""
mission.data.custom.destStationName  = ""

-- ============================================================
-- Bulletin generation  (called server-side from missionbulletins)
-- ============================================================
mission.makeBulletin = function(station)
    if onClient() then return end

    local x, y      = Sector():getCoordinates()
    local ring      = Broker.getRing(x, y)
    local bounds    = Broker.RING_BOUNDS[ring]
    local factionId = station.factionIndex

    local destX, destY = Broker.selectDestination(x, y, factionId)
    if not destX then return nil end

    local goodName = Broker.selectCargo(station.title, ring)
    if not goods[goodName] then
        Log.warn("transportmission.makeBulletin: unknown good '%s'", tostring(goodName))
        return nil
    end

    local displayAmount = random():getInt(bounds.min, bounds.max)
    local dist          = sectorDist(x, y, destX, destY)
    local total, speedBon, window, rel = Broker.calcReward(destX, destY, displayAmount, goodName, dist)

    local g        = goods[goodName]
    local dispName = g and g:good():displayName(displayAmount) or goodName

    Log.info("makeBulletin: station='%s' ring=%s good=%s amount=%d dest=(%d:%d) dist=%d reward=%d speedBonus=%d window=%ds",
        station.title or "?", ring, goodName, displayAmount, destX, destY, dist, total, speedBon, math.floor(window))

    return {
        -- Pre-formatted unique brief — template-string briefs get deduplicated by the bulletin board
        brief       = string.format("Transport %d %s to (%d:%d)", displayAmount, dispName, destX, destY),
        title       = "Transport: ${good}"%_T,
        description = "Deliver cargo to sector (${x}:${y}). Reward: ¢${reward}."%_T,
        difficulty  = "Normal"%_T,
        reward      = "¢${reward}"%_T,
        script      = "missions/transportmission.lua",
        formatArguments = {
            amount = displayAmount, good = dispName,
            x = destX, y = destY,
            reward = createMonetaryString(total),
        },
        giverTitle     = station.title,
        giverTitleArgs = station:getTitleArguments(),
        arguments = {{
            giver            = station.id,
            goodName         = goodName,
            displayAmount    = displayAmount,
            destX            = destX,
            destY            = destY,
            ring             = ring,
            rewardTotal      = total,
            speedBonus       = speedBon,
            speedBonusWindow = window,
            relations        = rel,
        }},
    }
end

-- ============================================================
-- Phase 1 — Cargo pickup at source station
-- ============================================================
mission.phases[1] = {}

mission.phases[1].initialize = function(restoring)
    if restoring then return end

    local a = mission.data.arguments
    local c = mission.data.custom
    c.goodName         = a.goodName
    c.displayAmount    = a.displayAmount
    c.destX            = a.destX
    c.destY            = a.destY
    c.ring             = a.ring
    c.reward           = a.rewardTotal
    c.speedBonus       = a.speedBonus
    c.speedBonusWindow = a.speedBonusWindow
    c.relations        = a.relations
    c.elapsed          = 0
    c.destStationId    = ""
    c.destStationName  = ""

    mission.data.targets = {mission.data.giver.id.string}
    mission.data.description[2].visible   = true
    mission.data.description[2].arguments = {giver = mission.data.giver.baseTitle}
end

mission.phases[1].onStartDialog = function(entityId)
    if tostring(mission.data.giver.id) ~= tostring(entityId) then return end
    local ui = ScriptUI(entityId)
    ui:addDialogOption("Pick up transport cargo"%_t, "tryPickupCargo")
end

-- No confirmation dialog: the player already committed by accepting the bulletin.
-- Server side loads cargo directly and sends a mail receipt.
-- Space-check failure sends a chat notification instead of a dialog.
function tryPickupCargo()
    if onClient() then
        invokeServerFunction("tryPickupCargo")
        return
    end

    local player = Player(callingPlayer)
    local ship   = player and player.craft
    if not ship then return end

    local c      = mission.data.custom
    local bounds = Broker.RING_BOUNDS[c.ring] or Broker.RING_BOUNDS.outer
    local free   = ship.freeCargoSpace or (ship.cargoCapacity - ship.cargoUsed)

    if free < bounds.min then
        player:sendChatMessage("Transport", 1, string.format(
            "Not enough cargo space. Need at least %d units, you have %d free.", bounds.min, free))
        return
    end

    local gx, gy = Sector():getCoordinates()
    local dist   = sectorDist(gx, gy, c.destX, c.destY)
    local amount = Broker.calcAmount(c.ring, free)
    local total, speedBon, window, rel = Broker.calcReward(c.destX, c.destY, amount, c.goodName, dist)
    c.amount           = amount
    c.reward           = total
    c.speedBonus       = speedBon
    c.speedBonusWindow = window
    c.relations        = rel
    c.playerIndex      = callingPlayer

    local g = goods[c.goodName]
    if not g then
        Log.warn("tryPickupCargo: good '%s' not found", tostring(c.goodName))
        return
    end

    ship:addCargo(g:good(), amount)

    local dispName = g:good():displayName(amount)
    Log.info("tryPickupCargo: loaded %d %s onto ship; dest=(%d:%d) reward=%d speedBonus=%d window=%ds",
        amount, c.goodName, c.destX, c.destY, total, speedBon, math.floor(window))

    Log.sendMail(player,
        "Transport Contract: Cargo Loaded"%_t,
        string.format(
            "Loaded %d %s.\nDeliver to sector (%d:%d).\nBase reward: %s credits (+%s speed bonus if delivered within %d min).",
            amount, dispName,
            c.destX, c.destY,
            createMonetaryString(total),
            createMonetaryString(speedBon),
            math.floor(window / 60)))

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible   = true
    mission.data.description[3].arguments = {
        amount  = amount, good = dispName,
        x       = c.destX, y  = c.destY,
        station = "a station",  -- updated to the specific station name when Phase 3 initialises
    }

    setPhase(2)
end
callable(nil, "tryPickupCargo")

-- ============================================================
-- Phase 2 — In Transit
-- ============================================================
mission.phases[2] = {}

mission.phases[2].initialize = function(restoring)
    local c = mission.data.custom
    mission.data.location = {x = c.destX, y = c.destY}
    mission.data.targets  = {}
    if not restoring then
        c.elapsed = 0
    end
end

mission.phases[2].updateServer = function(dt)
    local c = mission.data.custom
    c.elapsed = (c.elapsed or 0) + dt

    local sector = Sector()
    if not sector then return end
    local x, y = sector:getCoordinates()
    if x == c.destX and y == c.destY then
        setPhase(3)
    end
end

mission.phases[2].onSectorEntered = function(x, y)
    if onClient() then return end

    local c = mission.data.custom
    local g = goods[c.goodName]
    if not g then return end

    local cargoValue = (c.amount or 0) * g.price
    Log.info("onSectorEntered (%d:%d): cargoValue=%d elapsed=%.0fs", x, y, cargoValue, c.elapsed or 0)

    -- Debug override: /trucker transport ambush sets this flag on the player
    local player       = c.playerIndex and Player(c.playerIndex)
    local debugAmbush  = player and player:getValue("trucker_debug_ambush") == "1"
    if debugAmbush then
        player:setValue("trucker_debug_ambush", "0")
        Log.info("onSectorEntered (%d:%d): debug ambush override — force-spawning pirates", x, y)
        spawnAmbushPirates()
        return
    end

    if cargoValue > 50000 then
        local regular, _, blocked, home = SectorSpecifics():determineContent(x, y, Server().seed)
        if (regular or home) and not blocked then
            Log.info("onSectorEntered: cargoValue>50000 — rolling ambush in (%d:%d)", x, y)
            spawnAmbushPirates()
        else
            Log.info("onSectorEntered: cargoValue>50000 but sector (%d:%d) is offgrid/blocked — no ambush", x, y)
        end
    else
        Log.info("onSectorEntered: cargoValue=%d ≤ 50000 — no ambush", cargoValue)
    end
end

function spawnAmbushPirates()
    if onClient() then invokeServerFunction("spawnAmbushPirates") return end

    local dir   = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up    = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos   = dir * 1200

    local generator = AsyncPirateGenerator(nil, onAmbushGenerated)
    local count     = random():getInt(1, 3)

    generator:startBatch()
    for i = 1, count do
        generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * 60 * (i - 1)))
    end
    generator:endBatch()

    Log.info("transportmission: ambush %d pirate(s) spawned en route to (%d:%d)",
        count, mission.data.custom.destX, mission.data.custom.destY)
end
callable(nil, "spawnAmbushPirates")

function onAmbushGenerated(generated)
    SpawnUtility.addEnemyBuffs(generated)
end

-- ============================================================
-- Phase 3 — Delivery
-- ============================================================
mission.phases[3] = {}

mission.phases[3].initialize = function(restoring)
    if restoring then return end
    local c        = mission.data.custom
    local stations = {Sector():getEntitiesByType(EntityType.Station)}

    if #stations > 0 then
        local s     = stations[random():getInt(1, #stations)]
        local sType = s.title or "station"
        local sName = s.name

        c.destStationId   = s.id.string
        -- Build "Name (Type)" when an owner name exists, otherwise just the type
        c.destStationName = (sName and sName ~= "" and sName ~= sType)
            and (sName .. " (" .. sType .. ")")
            or  sType

        mission.data.targets = {s.id.string}

        mission.data.description[3].arguments = {
            amount  = c.amount,
            good    = goods[c.goodName] and goods[c.goodName]:good():displayName(c.amount) or c.goodName,
            x       = c.destX,
            y       = c.destY,
            station = c.destStationName,
        }

        Log.info("Phase3.initialize: delivery target '%s' (%s) id=%s",
            c.destStationName, sType, c.destStationId)
    else
        -- No stations in sector — accept delivery at any station the player docks at
        Log.warn("Phase3.initialize: no stations in destination sector (%d:%d)", c.destX, c.destY)
    end
end

mission.phases[3].onStartDialog = function(entityId)
    local c = mission.data.custom
    -- If we have a target station, only add the option at that station.
    -- If destStationId is empty (no stations at initialize time), accept at any station.
    if c.destStationId ~= "" and tostring(entityId) ~= c.destStationId then return end

    local g = goods[c.goodName]
    if not g then return end

    local ui = ScriptUI(entityId)
    ui:addDialogOption(("Deliver ${amount} ${good}"%_t) % {
        amount = c.amount,
        good   = g:good():displayName(c.amount),
    }, "tryDeliverCargo")
end

function tryDeliverCargo()
    if onClient() then
        invokeServerFunction("tryDeliverCargo")
        return
    end

    local player = Player(callingPlayer)
    local ship   = player and player.craft
    if not ship then return end

    local c = mission.data.custom
    local g = goods[c.goodName]
    if not g then return end

    local good   = g:good()
    local actual = ship:getCargoAmount(good)

    if actual <= 0 then
        mission.data.failMessage = "You lost all the cargo! No payment will be made."%_T
        fail()
        return
    end

    local removed  = math.min(actual, c.amount)
    ship:removeCargo(good, removed)

    local fraction = removed / c.amount
    local credits  = math.floor(c.reward * fraction)
    local speedBon = 0
    if c.elapsed < c.speedBonusWindow then
        speedBon = math.floor(c.speedBonus * fraction)
    end

    local total   = credits + speedBon
    local mBefore = player.money or 0
    player:receive(total)
    local mAfter  = player.money or 0

    mission.data.reward         = total
    mission.data.paymentMessage = speedBon > 0
        and "Earned %1% Credits for cargo delivery (speed bonus included)."%_T
        or  "Earned %1% Credits for cargo delivery."%_T

    mission.data.accomplishMessage = speedBon > 0
        and "Cargo delivered ahead of schedule! Speed bonus awarded."%_T
        or  "Cargo delivered successfully."%_T

    Log.info("onDelivery: removed=%d/%d fraction=%.2f base=%d speedBon=%d total=%d elapsed=%.0fs window=%.0fs",
        removed, c.amount, fraction, credits, speedBon, total, c.elapsed or 0, c.speedBonusWindow or 0)
    Log.info("payment: moneyBefore=%d reward=%d moneyAfter=%d", mBefore, total, mAfter)

    accomplish()
end
callable(nil, "tryDeliverCargo")

-- ============================================================
-- Mission UI helpers
-- ============================================================
function getMissionTitle()
    local c = mission.data.custom
    if c.goodName and c.goodName ~= "" then
        local g = goods[c.goodName]
        local n = g and g:good():displayName(c.amount or 0) or c.goodName
        return ("Transport: ${good}"%_T) % {good = n}
    end
    return mission.data.title
end

function getMissionDescription()
    local c = mission.data.custom
    if not c.goodName or c.goodName == "" then
        return "Transport goods to a destination sector for a reward."%_T
    end

    local g        = goods[c.goodName]
    local goodDisp = g and g:good():displayName(c.amount or 0) or c.goodName
    local phase    = mission.internals and mission.internals.phaseIndex or 1

    if phase <= 1 then
        return ("Return to ${giver} to pick up ${amount} ${good} for delivery to (${x}:${y})."%_T) % {
            giver  = mission.data.giver and (mission.data.giver.baseTitle or "the station") or "the station",
            amount = c.displayAmount or c.amount or 0,
            good   = goodDisp,
            x      = c.destX, y = c.destY,
        }
    elseif phase == 2 then
        local timeLeft  = math.max(0, (c.speedBonusWindow or 0) - (c.elapsed or 0))
        local bonusLine = timeLeft > 0
            and (" Speed bonus: ${m} min remaining."%_T % {m = math.floor(timeLeft / 60)})
            or  ""
        return ("Deliver ${amount} ${good} to sector (${x}:${y}).${b}"%_T) % {
            amount = c.amount or 0, good = goodDisp,
            x = c.destX, y = c.destY, b = bonusLine,
        }
    else
        local label = (c.destStationName ~= "") and c.destStationName or "the station"
        return ("Dock at ${station} in sector (${x}:${y}) to deliver the cargo."%_T) % {
            station = label, x = c.destX, y = c.destY,
        }
    end
end
