-- Trade journal: per-player observation log of station prices, with
-- alliance auto-share. Stored on Player and Alliance entities via
-- setValue / getValue. Capture is gated on a Trading System upgrade being
-- installed on the player's ship in a loaded sector.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerLog = include("truckerlog")

TruckerJournal = {}

local PLAYER_KEY    = "trucker_journal"
local ALLIANCE_KEY  = "trucker_journal_shared"

-- Configurable via spacetrucker config; default 5,000 entries.
TruckerJournal.MAX_ENTRIES = 5000

-- Trading System scripts that gate observation capture.
local TRADING_SYSTEM_SCRIPTS = {
    "data/scripts/systems/tradingoverview.lua",
    "data/scripts/systems/hypertradingsystem.lua",
    "internal/dlc/rift/systems/hypertradingsystem.lua",
}

local function isTradingSystem(scriptPath)
    if not scriptPath then return false end
    for _, candidate in ipairs(TRADING_SYSTEM_SCRIPTS) do
        if scriptPath == candidate or string.match(scriptPath, candidate) then
            return true
        end
    end
    return false
end

-- Returns true if `craft` (an Entity) has a Trading System installed.
function TruckerJournal.hasTradingSystem(craft)
    if not craft then return false end
    -- Try the cleanest API first.
    local ok, scripts = pcall(function() return {craft:getScripts()} end)
    if ok and scripts then
        for _, s in pairs(scripts) do
            if isTradingSystem(s) then return true end
        end
    end
    -- Fallback: probe via invokeFunction (returns nonzero if missing).
    for _, candidate in ipairs(TRADING_SYSTEM_SCRIPTS) do
        local probeOk = pcall(function() return craft:invokeFunction(candidate, "getUpdateInterval") end)
        if probeOk then return true end
    end
    return false
end

-- ---------- storage ----------

local function readJournal(entity, key)
    if not entity then return {} end
    local raw = entity:getValue(key)
    if type(raw) ~= "table" then return {} end
    return raw
end

local function writeJournal(entity, key, journal)
    if not entity then return end
    -- Cap and prune oldest first.
    if #journal > TruckerJournal.MAX_ENTRIES then
        local excess = #journal - TruckerJournal.MAX_ENTRIES
        for i = 1, excess do table.remove(journal, 1) end
    end
    entity:setValue(key, journal)
end

local function append(entity, key, observations)
    local journal = readJournal(entity, key)
    for _, obs in ipairs(observations) do
        table.insert(journal, obs)
    end
    writeJournal(entity, key, journal)
end

-- ---------- capture ----------

local function buildObservation(station, factionIdx, sectorX, sectorY, action, good, price, stock, maxStock, ts)
    return {
        stationId    = station and station.id and station.id.string or tostring(station and station.index or "?"),
        stationName  = station and station.name or "?",
        sectorX      = sectorX,
        sectorY      = sectorY,
        factionId    = factionIdx,
        commodity    = good and good.name or "?",
        category     = good and good.tagDescription or nil,
        action       = action,  -- "buy" or "sell"
        price        = price,
        stock        = stock,
        maxStock     = maxStock,
        timestamp    = ts,
    }
end

-- Pull buy/sell goods from a station and produce observation rows.
-- Returns the array of observation tables.
local function harvestStation(station, factionIdx, sectorX, sectorY, ts)
    local out = {}
    -- Try the documented Station/Entity API: getBuyableGoods, getSellableGoods.
    local okBuy, buyGoods = pcall(function() return {station:getBuyableGoods()} end)
    if okBuy and buyGoods then
        for _, good in pairs(buyGoods) do
            -- Station "buys" from the player; that's the player's "sell" action.
            local price = good.price or 0
            local stock = good.amount or 0
            local maxS  = good.maxStock or stock
            table.insert(out, buildObservation(station, factionIdx, sectorX, sectorY, "sell", good, price, stock, maxS, ts))
        end
    end
    local okSell, sellGoods = pcall(function() return {station:getSellableGoods()} end)
    if okSell and sellGoods then
        for _, good in pairs(sellGoods) do
            local price = good.price or 0
            local stock = good.amount or 0
            local maxS  = good.maxStock or stock
            table.insert(out, buildObservation(station, factionIdx, sectorX, sectorY, "buy", good, price, stock, maxS, ts))
        end
    end
    return out
end

-- Record observations for one player based on the current sector.
-- Server-only. Safe to call when no Trading System is present (no-op).
function TruckerJournal.recordObservations(player, sector)
    if not onServer() then return end
    if not player or not sector then return end
    local x, y = sector:getCoordinates()
    local ts = (Server and Server() and Server().unpausedRuntime) or os.time()

    -- Find this player's controlled craft in the sector for the upgrade gate.
    local playerCraft
    for _, e in pairs({sector:getEntitiesByFaction(player.index)}) do
        if e and e.isShip and e:getPilotIndices and ({e:getPilotIndices()})[1] == player.index then
            playerCraft = e
            break
        end
    end
    if not playerCraft then
        -- Fallback: any ship the player owns in this sector.
        for _, e in pairs({sector:getEntitiesByFaction(player.index)}) do
            if e and e.isShip then playerCraft = e; break end
        end
    end
    if not TruckerJournal.hasTradingSystem(playerCraft) then return end

    local stations = {sector:getEntitiesByType(EntityType.Station)}
    if #stations == 0 then return end

    local observations = {}
    for _, station in pairs(stations) do
        local factionIdx = station.factionIndex
        local rows = harvestStation(station, factionIdx, x, y, ts)
        for _, r in ipairs(rows) do table.insert(observations, r) end
    end

    if #observations == 0 then return end

    append(player, PLAYER_KEY, observations)

    -- Alliance auto-share (D5 / spec §5).
    if player.allianceIndex and player.allianceIndex > 0 then
        local alliance = Alliance(player.allianceIndex)
        if alliance then
            append(alliance, ALLIANCE_KEY, observations)
        end
    end

    TruckerLog.info(
        "Captured %d observations for %s in sector (%d,%d) from %d stations",
        #observations, tostring(player.name), x, y, #stations
    )
end

-- ---------- queries ----------

local function dedupeAndSortNewestFirst(rows)
    local seen = {}
    local out  = {}
    for _, r in ipairs(rows) do
        local k = string.format("%s|%s|%s|%s", r.stationId, r.commodity, r.action, tostring(r.timestamp))
        if not seen[k] then
            seen[k] = true
            table.insert(out, r)
        end
    end
    table.sort(out, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    return out
end

function TruckerJournal.effectiveJournal(player)
    if not player then return {} end
    local personal = readJournal(player, PLAYER_KEY)
    local shared = {}
    if player.allianceIndex and player.allianceIndex > 0 then
        local alliance = Alliance(player.allianceIndex)
        if alliance then
            shared = readJournal(alliance, ALLIANCE_KEY)
        end
    end
    local merged = {}
    for _, r in ipairs(personal) do
        r.__source = "personal"
        table.insert(merged, r)
    end
    for _, r in ipairs(shared) do
        local copy = {}
        for k, v in pairs(r) do copy[k] = v end
        copy.__source = "alliance"
        table.insert(merged, copy)
    end
    return dedupeAndSortNewestFirst(merged)
end

local function filter(player, predicate)
    local out = {}
    for _, r in ipairs(TruckerJournal.effectiveJournal(player)) do
        if predicate(r) then table.insert(out, r) end
    end
    return out
end

function TruckerJournal.queryByCommodity(player, name)
    return filter(player, function(r) return r.commodity == name end)
end

function TruckerJournal.queryByFaction(player, factionId)
    return filter(player, function(r) return r.factionId == factionId end)
end

function TruckerJournal.queryBySector(player, x, y)
    return filter(player, function(r) return r.sectorX == x and r.sectorY == y end)
end

function TruckerJournal.size(player)
    if not player then return 0, 0 end
    local personal = #readJournal(player, PLAYER_KEY)
    local shared = 0
    if player.allianceIndex and player.allianceIndex > 0 then
        local alliance = Alliance(player.allianceIndex)
        if alliance then shared = #readJournal(alliance, ALLIANCE_KEY) end
    end
    return personal, shared
end

return TruckerJournal
