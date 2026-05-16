-- Server-side sector script. Two responsibilities:
--   1. Capture player observations into the trade journal on sector entry.
--   2. Attach the Faction Commodity Reports merchant to qualifying stations
--      (Trading Posts and Faction Headquarters in archetype-assigned space).
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerJournal    = include("truckerjournal")
local TruckerExcluded   = include("truckerexcluded")
local TruckerAssign     = include("truckerassignarchetypes")
local TruckerLog        = include("truckerlog")

local REPORT_MERCHANT_SCRIPT = "data/scripts/entity/merchants/truckerreportmerchant.lua"
local QUALIFYING_HOST_SCRIPTS = {
    "data/scripts/entity/merchants/tradingpost.lua",
    "data/scripts/entity/merchants/headquarters.lua",
}

local function stationHasQualifyingHost(station)
    if not station then return false end
    local ok, scripts = pcall(function() return {station:getScripts()} end)
    if not ok or not scripts then return false end
    for _, s in pairs(scripts) do
        for _, candidate in ipairs(QUALIFYING_HOST_SCRIPTS) do
            if s == candidate then return true end
        end
    end
    return false
end

local function attachReportMerchants()
    if not onServer() then return end
    local sector = Sector()
    if not sector then return end
    local stations = {sector:getEntitiesByType(EntityType.Station)}
    for _, station in pairs(stations) do
        local faction = Faction(station.factionIndex)
        if faction and not TruckerExcluded.isExcluded(faction) then
            TruckerAssign.ensureAssigned(faction)
            if faction:getValue("trucker_archetype") and stationHasQualifyingHost(station) then
                station:addScriptOnce(REPORT_MERCHANT_SCRIPT)
            end
        end
    end
end

function initialize()
    if not onServer() then return end
    local sector = Sector()
    if not sector then return end
    attachReportMerchants()
    -- Capture observations for any players already in the sector on load.
    for _, p in pairs({sector:getPlayers()}) do
        if p then TruckerJournal.recordObservations(p, sector) end
    end
end

function onPlayerEntered(playerIndex)
    if not onServer() then return end
    local player = Player(playerIndex)
    local sector = Sector()
    if not player or not sector then return end
    TruckerJournal.recordObservations(player, sector)
end
