-- Faction economic archetypes and their commodity bias tables.
--
-- The bias multiplier is applied as a final layer on top of vanilla station
-- prices. A multiplier of 1.0 leaves the price unchanged. Lower numbers mean
-- a faction tends to sell that category cheaply (and pay less to buy it);
-- higher numbers mean the opposite.
--
-- Categories are matched against `TradingGood.tags` (which is a string of
-- space-separated tags on each commodity in vanilla, e.g. "raw consumer").
-- Lookups are tag-based rather than per-commodity-name so the table stays
-- small and survives vanilla content additions.
package.path = package.path .. ";data/scripts/lib/?.lua"

TruckerArchetypes = {}

-- The fixed enum. Order is irrelevant; the strings are persisted in saves.
TruckerArchetypes.LIST = {
    "Agricultural",
    "Industrial",
    "Mining",
    "Refinery",
    "Frontier",
    "Mercantile",
    "Militant",
}

-- Bias tables keyed by archetype, then by good tag.
-- Tags: raw, refined, industrial, consumer, civil, military, hightech, illegal
TruckerArchetypes.BIAS = {
    Agricultural = {
        consumer    = 0.75,  -- food/luxury surplus
        civil       = 0.85,
        raw         = 0.95,
        refined     = 1.10,
        industrial  = 1.20,
        military    = 1.30,
        hightech    = 1.30,
    },
    Industrial = {
        industrial  = 0.75,  -- parts/machines surplus
        refined     = 0.85,
        raw         = 1.20,  -- needs raw materials
        consumer    = 1.10,
        military    = 1.05,
        hightech    = 1.00,
    },
    Mining = {
        raw         = 0.70,  -- ore/raw surplus
        refined     = 1.20,  -- needs refined goods
        consumer    = 1.25,  -- frontier hunger for food
        industrial  = 1.20,
        hightech    = 1.30,
    },
    Refinery = {
        refined     = 0.75,  -- alloys/fuel surplus
        raw         = 1.20,  -- needs raw inputs
        industrial  = 0.95,
        consumer    = 1.10,
        military    = 1.05,
    },
    Frontier = {
        -- Pays a premium for nearly everything; supply lines are thin.
        consumer    = 1.30,
        civil       = 1.30,
        industrial  = 1.30,
        refined     = 1.20,
        military    = 1.40,
        hightech    = 1.50,
        raw         = 1.10,
    },
    Mercantile = {
        -- Narrow spreads, low variance. Predictable but unprofitable.
        raw         = 0.95, refined = 0.95, industrial = 0.95,
        consumer    = 0.95, civil   = 0.95, military   = 0.95,
        hightech    = 0.95,
    },
    Militant = {
        military    = 0.70,  -- weapons/ammo surplus
        hightech    = 0.85,
        consumer    = 1.20,  -- demands medical/food during operations
        civil       = 1.20,
        refined     = 1.10,
    },
}

-- Maximum share of assigned factions any single archetype may occupy.
-- Distribution guardrail per spec.
TruckerArchetypes.MAX_SHARE = 0.30

-- Per-faction strength range. 1.0 = base table values; higher = more
-- extreme bias (deeper discounts on cheap goods, larger premiums on dear);
-- lower = subtler bias. Rolled once per faction at assignment time.
TruckerArchetypes.STRENGTH_MIN = 0.3
TruckerArchetypes.STRENGTH_MAX = 1.8

function TruckerArchetypes.isValid(name)
    for _, n in ipairs(TruckerArchetypes.LIST) do
        if n == name then return true end
    end
    return false
end

function TruckerArchetypes.getBias(name)
    return TruckerArchetypes.BIAS[name]
end

-- effective[tag] = 1.0 + (base[tag] - 1.0) * specialization
-- A specialization of 0 collapses every multiplier back to 1.0 (neutral).
-- A specialization of 1.0 returns the table as-is.
function TruckerArchetypes.getEffectiveBias(name, specialization)
    local base = TruckerArchetypes.BIAS[name]
    if not base then return nil end
    if type(specialization) ~= "number" then specialization = 1.0 end
    local out = {}
    for tag, m in pairs(base) do
        out[tag] = 1.0 + (m - 1.0) * specialization
    end
    return out
end

-- Player-facing rendering: convert specialization scalar to 1..5 stars.
-- Bucket boundaries: [0.30,0.59] [0.60,0.89] [0.90,1.19] [1.20,1.49] [1.50,1.80]
function TruckerArchetypes.specializationToStars(s)
    if type(s) ~= "number" then return 3 end
    if s < 0.60 then return 1
    elseif s < 0.90 then return 2
    elseif s < 1.20 then return 3
    elseif s < 1.50 then return 4
    else return 5 end
end

-- Word label matching the same bucket as specializationToStars.
function TruckerArchetypes.specializationLabel(s)
    local stars = TruckerArchetypes.specializationToStars(s)
    return ({"Lightly", "Modestly", "Solidly", "Heavily", "Pure"})[stars]
end

-- Render specialization as a fixed-width star string. Uses ASCII glyphs
-- ("*" filled, "." empty) for maximum Avorion-Lua source compatibility;
-- UI surfaces can substitute unicode at render time if desired.
function TruckerArchetypes.specializationStarString(s)
    local n = TruckerArchetypes.specializationToStars(s)
    return string.rep("*", n) .. string.rep(".", 5 - n)
end

return TruckerArchetypes
