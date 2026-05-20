-- Pure functions that apply faction archetype bias to a vanilla price.
--
-- Reads the archetype from the entity's own setValue cache (written
-- server-side at station-load time by TruckerPriceWrap.install). This
-- makes the bias visible on BOTH client and server, eliminating the
-- price-display vs transaction desync.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerArchetypes = include("truckerarchetypes")

TruckerPriceHook = {}

local STATION_ARCH_KEY     = "trucker_station_arch"
local STATION_STRENGTH_KEY = "trucker_station_strength"

local TAG_PRIORITY = {
    "illegal", "military", "hightech", "consumer",
    "civil",   "industrial", "refined", "raw",
}

local function pickTag(goodTags)
    if type(goodTags) ~= "table" then return nil end
    for _, key in ipairs(TAG_PRIORITY) do
        if goodTags[key] then return key end
    end
    return nil
end

local function entityArchAndStrength()
    local okE, entity = pcall(function() return Entity() end)
    if not okE or not entity then return nil, nil end
    local okA, arch = pcall(function() return entity:getValue(STATION_ARCH_KEY) end)
    if not okA or type(arch) ~= "string" or arch == "" then return nil, nil end
    if not TruckerArchetypes.isValid(arch) then return nil, nil end
    local okS, strength = pcall(function() return entity:getValue(STATION_STRENGTH_KEY) end)
    if not okS or type(strength) ~= "number" then strength = 1.0 end
    return arch, strength
end

local function biasFactor(good)
    if not good then return 1.0 end
    local arch, strength = entityArchAndStrength()
    if not arch then return 1.0 end
    local bias = TruckerArchetypes.getEffectiveBias(arch, strength)
    if type(bias) ~= "table" then return 1.0 end
    local tag = pickTag(good.tags)
    if not tag then return 1.0 end
    local m = bias[tag]
    if type(m) ~= "number" then return 1.0 end
    return m
end

function TruckerPriceHook.applyBuyBias(good, vanillaPrice)
    if type(vanillaPrice) ~= "number" then return vanillaPrice end
    return vanillaPrice * biasFactor(good)
end

function TruckerPriceHook.applySellBias(good, vanillaPrice)
    if type(vanillaPrice) ~= "number" then return vanillaPrice end
    return vanillaPrice * biasFactor(good)
end

return TruckerPriceHook
