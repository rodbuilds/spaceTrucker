-- Transport contract generation utilities for the Space Trucker mod.
-- Include this module from the transport mission script.
-- Baseline: Avorion 2.5.x
package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("goods")
local SectorSpecifics = include("sectorspecifics")
local Balancing        = include("galaxy")
local TruckerLog       = include("truckerlog")

-- namespace TransportBroker
TransportBroker = {}

TruckerLog.info("transportbroker loaded")

-- ============================================================
-- Cargo tables
-- ============================================================
local CARGO_BY_STATION = {
    ["Trading Post"]   = {"Ore", "Steel", "Medical Supplies", "Food", "Fertilizer"},
    ["Resource Depot"] = {
        outer = {"Iron Ore", "Titanium Ore", "Naonite Ore"},
        mid   = {"Naonite Ore", "Trinium Ore", "Xanion Ore"},
        inner = {"Xanion Ore", "Ogonite Ore", "Avorion Ore"},
    },
    ["Factory"]  = {"Steel", "Fertilizer", "Ore", "Bio Gas"},
    ["Habitat"]  = {"Food", "Medical Supplies", "Fabric"},
    ["Biotope"]  = {"Food", "Fertilizer", "Bio Gas"},
}

-- Per-ring cargo amount bounds: {min, max, cap, frac_of_free_space}
local RING_BOUNDS = {
    outer = {min = 50, max = 200, cap = 200, frac = 0.60},
    mid   = {min = 40, max = 150, cap = 150, frac = 0.50},
    inner = {min = 20, max = 80,  cap = 80,  frac = 0.40},
}
TransportBroker.RING_BOUNDS = RING_BOUNDS

-- ============================================================
-- getRing(x, y) → "outer" | "mid" | "inner"
-- ============================================================
function TransportBroker.getRing(x, y)
    local dist = math.sqrt(x * x + y * y)
    if dist > 400 then return "outer"
    elseif dist > 200 then return "mid"
    else return "inner" end
end

-- ============================================================
-- selectCargo(stationTitle, ring) → goodName string
-- ============================================================
function TransportBroker.selectCargo(stationTitle, ring)
    local pool = CARGO_BY_STATION[stationTitle] or CARGO_BY_STATION["Trading Post"]
    -- Resource Depot has ring-specific sub-tables
    if pool.outer then
        pool = pool[ring] or pool.outer
    end
    return pool[random():getInt(1, #pool)]
end

-- ============================================================
-- calcAmount(ring, freeSpace) → integer units
-- ============================================================
function TransportBroker.calcAmount(ring, freeSpace)
    local b = RING_BOUNDS[ring] or RING_BOUNDS.outer
    local raw    = random():getInt(b.min, b.max)
    local capped = math.min(b.cap, math.floor(freeSpace * b.frac))
    return math.max(1, math.min(raw, capped))
end

-- ============================================================
-- calcReward(destX, destY, amount, goodName, dist)
--   → total, speedBonus, speedBonusWindow, relations
-- ============================================================
function TransportBroker.calcReward(destX, destY, amount, goodName, dist)
    local factor  = Balancing.GetSectorRewardFactor(destX, destY)
    local g       = goods[goodName]
    local price   = g and g.price or 100
    local base    = 15000 * factor
    local perUnit = amount * price * 0.10
    local distBon = dist * 500
    local total   = math.floor(base + perUnit + distBon)
    local speedBon = math.floor(total * 0.30)
    local window   = dist * 120
    local rel      = 2000 + math.floor(amount * 3)
    return total, speedBon, window, rel
end

-- ============================================================
-- selectDestination(sourceX, sourceY, sourceFactionId)
--   → destX, destY  (nil, nil if none found)
-- ============================================================
function TransportBroker.selectDestination(sourceX, sourceY, sourceFactionId)
    if not SectorSpecifics then
        -- sectorspecifics not available in this context (e.g. command scripts); return a simple random sector
        local r     = random()
        local angle = r:getFloat(0, 2 * math.pi)
        local dist  = r:getInt(5, 30)
        return sourceX + math.floor(dist * math.cos(angle) + 0.5),
               sourceY + math.floor(dist * math.sin(angle) + 0.5)
    end

    local specs      = SectorSpecifics()
    local serverSeed = Server().seed
    local coords     = specs.getShuffledCoordinates(random(), sourceX, sourceY, 5, 30)

    -- Prefer same-faction sectors
    for _, c in pairs(coords) do
        local regular, _, blocked, home = specs:determineContent(c.x, c.y, serverSeed)
        if (regular or home) and not blocked then
            specs:initialize(c.x, c.y, serverSeed)
            local tpl = specs.generationTemplate
            if tpl and tpl.factionId and tpl.factionId == sourceFactionId then
                return c.x, c.y
            end
        end
    end

    -- Fallback: any regular non-blocked sector in range
    for _, c in pairs(coords) do
        local regular, _, blocked, home = specs:determineContent(c.x, c.y, serverSeed)
        if (regular or home) and not blocked then
            return c.x, c.y
        end
    end

    TruckerLog.warn("TransportBroker.selectDestination: no valid sector found from (%d:%d)", sourceX, sourceY)
    return nil, nil
end

return TransportBroker
