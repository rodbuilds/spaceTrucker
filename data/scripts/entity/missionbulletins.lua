-- Space Trucker mod replacement for vanilla missionbulletins.lua
-- Baseline: Avorion 2.5.11 (vanilla file at avorion-scripts/entity/missionbulletins.lua)
-- Transport mission insertion points:
--   Line ~95  : "Trading Post" block  → transport entry added (weight 2.5)
--   Line ~111 : "Biotope" block       → transport entry added (weight 1.5)
--   Line ~131 : "Resource Depot" block → transport entry added (weight 2.0)
--   New block  : "Factory" block      → transport entry added (weight 1.5)
--   New block  : "Habitat" block      → transport entry added (weight 1.5)
-- MAINTENANCE: Re-sync this file when Avorion updates vanilla missionbulletins.lua.

package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MissionBulletins
MissionBulletins = {}

if onServer() then

function MissionBulletins.random()
    if not MissionBulletins.randomGenerator then
        local id = Server().sessionId
        local seed = Seed(id.string .. Entity().id.string .. tostring(os.time()))

        MissionBulletins.randomGenerator = Random(seed)
    end

    return MissionBulletins.randomGenerator
end

local TRANSPORT_PATH = "data/scripts/player/missions/transportmission.lua"
local TRANSPORT_MIN  = 1   -- minimum per eligible station
local TRANSPORT_MAX  = 2   -- hard cap per eligible station

local function isTransportEligible(title)
    if title == "Trading Post"  then return true end
    if title == "Resource Depot" then return true end
    if title == "Habitat"        then return true end
    if title == "Biotope"        then return true end
    if string.match(title, "Factory$") and title ~= "Fighter Factory" and title ~= "Turret Factory" then return true end
    return false
end

-- Count transport bulletins currently on the board by inspecting the bulletin list.
-- Falls back to 0 if the board API is unavailable.
local function countTransportBulletins()
    local ok, bulletins = Entity():invokeFunction("bulletinboard", "getBulletins")
    if ok ~= 0 or type(bulletins) ~= "table" then return 0 end
    local n = 0
    for _, b in ipairs(bulletins) do
        if type(b.script) == "string" and string.find(b.script, "transportmission", 1, true) then
            n = n + 1
        end
    end
    return n
end

local function postOneTransportBulletin()
    if countTransportBulletins() >= TRANSPORT_MAX then return false end
    local ok, bulletin = run(TRANSPORT_PATH, "getBulletin", Entity())
    if ok == 0 and bulletin then
        Entity():invokeFunction("bulletinboard", "postBulletin", bulletin)
        return true
    end
    return false
end

-- Ensure at least `target` transport bulletins are on the board.
local function ensureTransportBulletins(target)
    if not isTransportEligible(Entity().title) then return end
    local current = countTransportBulletins()
    local needed  = target - current
    for i = 1, needed do
        postOneTransportBulletin()
    end
end

function MissionBulletins.initialize()
    ensureTransportBulletins(TRANSPORT_MIN)
end

function MissionBulletins.getUpdateInterval()
    return 1
end

function MissionBulletins.updateServer(timeStep)
    MissionBulletins.updateBulletins(timeStep)
end

local updateFrequency = 15 * 60
local updateTime
function MissionBulletins.updateBulletins(timeStep)

    if not updateTime then
        -- by adding half the time here, we have a chance that a military outpost immediately has a bulletin
        updateTime = 0

        local r = MissionBulletins.random()
        local minutesSimulated = r:getInt(10, 80)
        minutesSimulated = 65
        for i = 1, minutesSimulated do -- simulate bulletin posting / removing
            MissionBulletins.updateBulletins(60)
        end
    end

    updateTime = updateTime + timeStep

    -- don't execute the following code if the time hasn't exceeded the posting frequency
    if updateTime < updateFrequency then return end
    updateTime = updateTime - updateFrequency

    MissionBulletins.addOrRemoveMissionBulletin()
end

function MissionBulletins.addOrRemoveMissionBulletin()
    local scripts = MissionBulletins.getPossibleMissions()
    if #scripts == 0 then return end

    local scriptPath = MissionBulletins.getWeightedRandomEntry(scripts)
    local ok, bulletin = run(scriptPath, "getBulletin", Entity())

    if ok == 0 and bulletin then
        local r = MissionBulletins.random()

        -- since in this case "add" can override "remove", adding a bulletin is slightly more likely than removing one
        local add = r:test(0.3)
        local remove = r:test(0.2)

        if add then
            -- add bulletins
            Entity():invokeFunction("bulletinboard", "postBulletin", bulletin)
        elseif remove then
            -- ... or remove bulletins
            Entity():invokeFunction("bulletinboard", "removeBulletin", bulletin.brief)
        end
    end

    -- Space Trucker: top up transport bulletins to minimum on every tick
    ensureTransportBulletins(TRANSPORT_MIN)
end

function MissionBulletins.getWeightedRandomEntry(scripts)
    -- ... determine which mission will be generated at this station
    local scriptsByWeight = {}

    for i, script in pairs(scripts) do
        if script then
            scriptsByWeight[i] = script.prob
        end
    end

    local i = selectByWeight(MissionBulletins.random(), scriptsByWeight)
    return scripts[i].path
end

function MissionBulletins.getPossibleMissions()
    local station = Entity()
    local stationTitle = station.title

    local scripts = {}

    -- delivery and organize are done by tradingmanager.lua without getBulletin-Function
--    table.insert(scripts, {path = "data/scripts/player/missions/delivery.lua", prob = 0})
--    table.insert(scripts, {path = "data/scripts/player/missions/organizegoods.lua", prob = 0})

    -- use this to have missions only spawn at certain stations
    -- Probabilites always have to add up to 10, so that ratio of missions can be seen easier
    if stationTitle == "Habitat" then
        table.insert(scripts, {path = "data/scripts/player/missions/settlertreck/settlertreck.lua", prob = 2})
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission1.lua", prob = 2.5, maxDistToCenter = 300}) -- find relic
        table.insert(scripts, {path = "data/scripts/player/missions/freeslaves.lua", prob = 1, minDistToCenter = 25})
        table.insert(scripts, {path = "data/scripts/player/missions/bountyhuntmission.lua", prob = 2})
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission4.lua", prob = 1.5}) -- prove innocence
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 3})
        -- Space Trucker: transport contracts at Habitats
        table.insert(scripts, {path = "data/scripts/player/missions/transportmission.lua", prob = 1.5})
    end

    if stationTitle == "${faction} Headquarters" then
        table.insert(scripts, {path = "data/scripts/player/missions/settlertreck/settlertreck.lua", prob = 1})
        table.insert(scripts, {path = "data/scripts/player/missions/hideevidence.lua", prob = 1})
        table.insert(scripts, {path = "data/scripts/player/missions/exploresector/exploresector.lua", prob = 2})
        table.insert(scripts, {path = "data/scripts/player/missions/clearpiratesector.lua", prob = 2})
        table.insert(scripts, {path = "data/scripts/player/missions/clearxsotansector.lua", prob = 1})
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission4.lua", prob = 3}) -- prove innocence
    end

    if stationTitle == "Research Station" then
        table.insert(scripts, {path = "data/scripts/player/missions/exploresector/exploresector.lua", prob = 5})
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission3.lua", prob = 2}) -- hackathon
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission1.lua", prob = 2.5, maxDistToCenter = 300}) -- find relic
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 4.0})
    end

    if stationTitle == "Trading Post" then
        table.insert(scripts, {path = "data/scripts/player/missions/transfervessel.lua", prob = 0.5})
        table.insert(scripts, {path = "data/scripts/player/missions/investigatemissingfreighters.lua", prob = 2, minDistToCenter = 50})
        table.insert(scripts, {path = "data/scripts/player/missions/freeslaves.lua", prob = 0.5, minDistToCenter = 25})
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission2.lua", prob = 2, maxDistToCenter = 300}) -- illuminated
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission4.lua", prob = 2.5}) -- prove innocence
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 2.0})
        -- Space Trucker: transport contracts at Trading Posts (highest weight)
        table.insert(scripts, {path = "data/scripts/player/missions/transportmission.lua", prob = 2.5})
    end

    if stationTitle == "Military Outpost" then
        table.insert(scripts, {path = "data/scripts/player/missions/hideevidence.lua", prob = 2})
        table.insert(scripts, {path = "data/scripts/player/missions/exploresector/exploresector.lua", prob = 1.5})
        table.insert(scripts, {path = "data/scripts/player/missions/clearpiratesector.lua", prob = 1.5})
        table.insert(scripts, {path = "data/scripts/player/missions/clearxsotansector.lua", prob = 1.5})
        table.insert(scripts, {path = "data/scripts/player/missions/coverretreat.lua", prob = 2})
        table.insert(scripts, {path = "data/scripts/player/missions/bountyhuntmission.lua", prob = 1})
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 2.0})
    end

    if stationTitle == "Shipyard" then
        table.insert(scripts, {path = "data/scripts/player/missions/transfervessel.lua", prob = 4})
        table.insert(scripts, {path = "data/scripts/player/missions/investigatemissingfreighters.lua", prob = 3, minDistToCenter = 50})
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission2.lua", prob = 2, maxDistToCenter = 300}) -- illuminated
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 2.0})
    end

    if stationTitle == "Repair Dock" then
        table.insert(scripts, {path = "data/scripts/player/missions/transfervessel.lua", prob = 4})
        table.insert(scripts, {path = "data/scripts/player/missions/investigatemissingfreighters.lua", prob = 3, minDistToCenter = 50})
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission2.lua", prob = 2, maxDistToCenter = 300}) -- illuminated
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 2.0})
    end

    if stationTitle == "Smuggler's Market" or stationTitle == "Smuggler Hideout" then
        table.insert(scripts, {path = "data/scripts/player/missions/bountyhuntmission.lua", prob = 4})
        table.insert(scripts, {path = "data/scripts/player/missions/clearpiratesector.lua", prob = 4})
        table.insert(scripts, {path = "data/scripts/player/missions/clearxsotansector.lua", prob = 1})
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 3})
    end

    if stationTitle == "Equipment Dock" then
        table.insert(scripts, {path = "data/scripts/player/missions/bountyhuntmission.lua", prob = 4})
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission3.lua", prob = 6}) -- hackathon
    end

    if stationTitle == "Casino" then
        table.insert(scripts, {path = "data/scripts/player/missions/bountyhuntmission.lua", prob = 4})
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission1.lua", prob = 3, maxDistToCenter = 300}) -- find relic
        table.insert(scripts, {path = "internal/dlc/blackmarket/player/missions/sidemissions/sidemission3.lua", prob = 2}) -- hackathon
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 3})
    end

    if stationTitle == "Biotope" then
        table.insert(scripts, {path = "data/scripts/player/missions/investigatemissingfreighters.lua", prob = 5, minDistToCenter = 50})
        table.insert(scripts, {path = "data/scripts/player/missions/bountyhuntmission.lua", prob = 5})
        -- Space Trucker: transport contracts at Biotopes
        table.insert(scripts, {path = "data/scripts/player/missions/transportmission.lua", prob = 1.5})
    end

    if stationTitle == "Fighter Factory" then
        table.insert(scripts, {path = "data/scripts/player/missions/investigatemissingfreighters.lua", prob = 5, minDistToCenter = 50})
        table.insert(scripts, {path = "data/scripts/player/missions/bountyhuntmission.lua", prob = 5})
    end

    if stationTitle == "Resource Depot" then
        table.insert(scripts, {path = "data/scripts/player/missions/investigatemissingfreighters.lua", prob = 5, minDistToCenter = 50})
        table.insert(scripts, {path = "data/scripts/player/missions/bountyhuntmission.lua", prob = 5})
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 3.0})
        -- Space Trucker: transport contracts at Resource Depots
        table.insert(scripts, {path = "data/scripts/player/missions/transportmission.lua", prob = 2.0})
    end

    if stationTitle == "Turret Factory" then
        table.insert(scripts, {path = "data/scripts/player/missions/investigatemissingfreighters.lua", prob = 5, minDistToCenter = 50})
        table.insert(scripts, {path = "data/scripts/player/missions/bountyhuntmission.lua", prob = 5})
    end

    -- Space Trucker: transport contracts at Factories (any factory type)
    if string.match(stationTitle, "Factory$") and stationTitle ~= "Fighter Factory" and stationTitle ~= "Turret Factory" then
        table.insert(scripts, {path = "data/scripts/player/missions/transportmission.lua", prob = 1.5})
    end

    if string.match(stationTitle, " Mine") then
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 10})
    end

    if stationTitle == "Scrapyard" then
        table.insert(scripts, {path = "data/scripts/player/missions/receivecaptainmission.lua", prob = 10})
    end

    -- only choose the missions that should be occuring in that region
    local possibleScripts = {}
    local x, y = Sector():getCoordinates()
    local distance = (x * x) + (y * y)

    for _, script in pairs(scripts) do
        local minDist = script.minDistToCenter or 0
        local maxDist = script.maxDistToCenter or 710 -- this is the highest possible distance (corner sectors)

        if distance >= (minDist * minDist) and distance <= (maxDist * maxDist) then
            table.insert(possibleScripts, script)
        end
    end

    return possibleScripts
end

end
