-- Pure functions that apply faction archetype bias to a vanilla price.
--
-- The bias is a multiplier looked up by good "category" (which we resolve
-- from the good's tags). Returns the vanilla price unchanged when the
-- faction has no archetype, the good has no matching tag, or anything else
-- prevents a clean bias lookup.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerArchetypes = include("truckerarchetypes")
local TruckerAssign     = include("truckerassignarchetypes")

TruckerPriceHook = {}

-- Tag keys we know about. Order matters: first match wins so more-specific
-- categories should appear earlier.
local TAG_PRIORITY = {
    "illegal",
    "military",
    "hightech",
    "consumer",
    "civil",
    "industrial",
    "refined",
    "raw",
}

local function pickTag(goodTags)
    if type(goodTags) ~= "table" then return nil end
    for _, key in ipairs(TAG_PRIORITY) do
        if goodTags[key] then return key end
    end
    return nil
end

local function biasFactor(faction, good)
    if not faction or not good then return 1.0 end
    -- Trigger lazy assignment; cheap if already done.
    TruckerAssign.ensureAssigned(faction)
    local bias = faction:getValue("trucker_bias")
    if type(bias) ~= "table" then return 1.0 end
    local tag = pickTag(good.tags)
    if not tag then return 1.0 end
    local m = bias[tag]
    if type(m) ~= "number" then return 1.0 end
    return m
end

function TruckerPriceHook.applyBuyBias(faction, good, vanillaPrice)
    if type(vanillaPrice) ~= "number" then return vanillaPrice end
    return vanillaPrice * biasFactor(faction, good)
end

function TruckerPriceHook.applySellBias(faction, good, vanillaPrice)
    if type(vanillaPrice) ~= "number" then return vanillaPrice end
    return vanillaPrice * biasFactor(faction, good)
end

return TruckerPriceHook
