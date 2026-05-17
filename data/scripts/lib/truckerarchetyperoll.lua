-- Trait-weighted archetype selection.
-- Reads a faction's vanilla traits (`Faction:getTraits`) and computes per-
-- archetype weights from a fixed influence matrix. A weighted draw selects
-- the archetype. Falls back to uniform random when traits are empty or all
-- weights collapse to zero.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerArchetypes = include("truckerarchetypes")
local TruckerLog = include("truckerlog")

TruckerArchetypeRoll = {}

-- Influence matrix: trait -> archetype -> additive weight contribution.
-- A trait value in [-1, 1] is multiplied into these contributions and added
-- to the archetype's base weight (which is 1.0 across the board).
local INFLUENCE = {
    aggressive = { Militant = 0.8,  Frontier = 0.4, Mining = 0.2,
                   Agricultural = -0.6, Mercantile = -0.3 },
    brave      = { Frontier = 0.6,  Militant = 0.4, Mining = 0.3,
                   Mercantile = -0.2 },
    careful    = { Mercantile = 0.5, Refinery = 0.3, Industrial = 0.3,
                   Frontier = -0.4 },
    greedy     = { Mercantile = 0.7, Industrial = 0.3, Refinery = 0.2,
                   Agricultural = -0.2 },
    honorable  = { Mercantile = 0.5, Industrial = 0.2,
                   Militant = -0.3 },
    peaceful   = { Agricultural = 0.8, Mercantile = 0.4, Refinery = 0.2,
                   Militant = -0.7, Frontier = -0.3 },
    trusting   = { Agricultural = 0.5, Mercantile = 0.4,
                   Militant = -0.3 },
}

local BASE_WEIGHT = 1.0
local MIN_WEIGHT = 0.05  -- floor so a trait combo never zeros an archetype

-- Compute weights for one faction given its trait table.
local function computeWeights(traits)
    local weights = {}
    for _, name in ipairs(TruckerArchetypes.LIST) do
        weights[name] = BASE_WEIGHT
    end

    if not traits or next(traits) == nil then
        return weights, true  -- second return: "is uniform fallback"
    end

    for trait, value in pairs(traits) do
        local row = INFLUENCE[trait]
        if row and type(value) == "number" then
            for archetype, contribution in pairs(row) do
                weights[archetype] = (weights[archetype] or 0) + contribution * value
            end
        end
    end

    -- Floor and detect degenerate (all-zero) cases.
    local total = 0
    for name, w in pairs(weights) do
        if w < MIN_WEIGHT then weights[name] = MIN_WEIGHT end
        total = total + weights[name]
    end

    if total <= 0 then
        for _, name in ipairs(TruckerArchetypes.LIST) do
            weights[name] = BASE_WEIGHT
        end
        return weights, true
    end

    return weights, false
end

-- Apply per-archetype share cap. counts is a table of archetype -> currently
-- assigned count; total is the number of factions assigned so far. Returns
-- modified weights with capped archetypes removed (weight 0).
local function applyCap(weights, counts, total)
    if total <= 0 then return weights end
    local capped = {}
    for name, w in pairs(weights) do
        local share = (counts[name] or 0) / total
        if share >= TruckerArchetypes.MAX_SHARE then
            capped[name] = true
        end
    end
    -- If everything's capped, ignore the cap (defensive — should never happen
    -- with MAX_SHARE = 0.30 and 7 archetypes).
    local remaining = 0
    for name in pairs(weights) do
        if not capped[name] then remaining = remaining + 1 end
    end
    if remaining == 0 then return weights end

    local out = {}
    for name, w in pairs(weights) do
        out[name] = capped[name] and 0 or w
    end
    return out
end

-- Weighted draw. Returns the chosen archetype name.
local function draw(weights, rng)
    local total = 0
    for _, w in pairs(weights) do total = total + w end
    if total <= 0 then
        return TruckerArchetypes.LIST[1]
    end
    local r = rng:getFloat(0, total)
    local acc = 0
    for _, name in ipairs(TruckerArchetypes.LIST) do
        acc = acc + (weights[name] or 0)
        if r <= acc then return name end
    end
    return TruckerArchetypes.LIST[#TruckerArchetypes.LIST]
end

-- Roll one archetype for `faction`, respecting `counts` (running tally) and
-- `total` (running assignment count). Returns the chosen archetype name and
-- a boolean indicating whether the trait fallback fired.
local function defaultRng()
    -- `random()` is only defined in galaxy-generation contexts. Fall back
    -- to the Random constructor (always available) otherwise.
    if type(random) == "function" then
        local ok, r = pcall(random)
        if ok and r then return r end
    end
    return Random()
end

-- Strength is biased by how concentrated a faction's traits are. Sum the
-- absolute trait values: a faction with several strong traits leans harder
-- into its archetype than one with weak/mixed traits. Then random-jitter
-- to keep two same-trait factions from being identical.
local function rollStrength(traits, rng)
    local sMin = TruckerArchetypes.STRENGTH_MIN
    local sMax = TruckerArchetypes.STRENGTH_MAX
    local concentration = 0
    if traits then
        for _, v in pairs(traits) do
            if type(v) == "number" then concentration = concentration + math.abs(v) end
        end
    end
    -- Normalize concentration into [0, 1]; ~3.0 sum is "very concentrated".
    local norm = math.min(1.0, concentration / 3.0)
    -- Center around midpoint, push toward sMax for concentrated factions.
    local mid = (sMin + sMax) * 0.5
    local base = mid + (sMax - mid) * (norm * 2 - 1) * 0.6  -- ±60% of half-range
    -- Random jitter ±20% of full range.
    local jitter = rng:getFloat(-1, 1) * (sMax - sMin) * 0.2
    local s = base + jitter
    if s < sMin then s = sMin end
    if s > sMax then s = sMax end
    return s
end

function TruckerArchetypeRoll.rollFor(faction, counts, total, rng)
    rng = rng or defaultRng()
    counts = counts or {}
    total = total or 0

    local traits
    local ok = pcall(function() traits = faction:getTraits() end)
    if not ok then traits = nil end

    local weights, fallback = computeWeights(traits)
    weights = applyCap(weights, counts, total)
    local choice = draw(weights, rng)
    local strength = rollStrength(traits, rng)

    return choice, fallback, strength
end

return TruckerArchetypeRoll
