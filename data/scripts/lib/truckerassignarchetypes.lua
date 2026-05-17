-- Archetype assignment.
--
-- Two paths:
--   1. Eager assignment via `initializeAIFaction` for newly created factions.
--   2. Lazy assignment when the price hook (or any other consumer) calls
--      `ensureAssigned(faction)` and finds no `trucker_archetype` value.
--
-- Both paths share a running tally on the Server entity so the share-cap
-- guardrail works across the lifetime of the save.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerArchetypes = include("truckerarchetypes")
local TruckerExcluded   = include("truckerexcluded")
local TruckerRoll       = include("truckerarchetyperoll")
local TruckerLog        = include("truckerlog")

TruckerAssignArchetypes = {}

local COUNT_PREFIX = "trucker_arch_count_"
local TOTAL_KEY    = "trucker_arch_total"
local ARCH_KEY     = "trucker_archetype"

local function readCounts()
    if not onServer() then return {}, 0 end
    local counts = {}
    for _, name in ipairs(TruckerArchetypes.LIST) do
        local n = Server():getValue(COUNT_PREFIX .. name)
        counts[name] = (type(n) == "number") and n or 0
    end
    local total = Server():getValue(TOTAL_KEY) or 0
    if type(total) ~= "number" then total = 0 end
    return counts, total
end

local function writeCount(archetype, n, total)
    if not onServer() then return end
    Server():setValue(COUNT_PREFIX .. archetype, n)
    Server():setValue(TOTAL_KEY, total)
end

-- Idempotent assignment for a single faction. Returns the archetype name
-- (existing or freshly assigned), or nil if the faction is excluded.
function TruckerAssignArchetypes.ensureAssigned(faction)
    if not onServer() then return nil end
    if not faction then return nil end

    local existing = faction:getValue(ARCH_KEY)
    if existing and TruckerArchetypes.isValid(existing) then
        return existing
    end

    if TruckerExcluded.isExcluded(faction) then
        return nil
    end

    local counts, total = readCounts()
    local choice, fallback = TruckerRoll.rollFor(faction, counts, total)

    faction:setValue(ARCH_KEY, choice)
    -- Bias is intentionally NOT persisted: it's a fixed function of archetype.
    -- Derive on demand via TruckerArchetypes.getBias(archetype).

    local newCount = (counts[choice] or 0) + 1
    writeCount(choice, newCount, total + 1)

    TruckerLog.info(
        "Assigned archetype %s to faction %s (#%d)%s",
        choice,
        tostring(faction.name or "?"),
        faction.index or -1,
        fallback and " [trait fallback]" or ""
    )

    return choice
end

-- Dump current distribution to the log. Useful for the §2.8 verification.
function TruckerAssignArchetypes.dumpDistribution()
    if not onServer() then return end
    local counts, total = readCounts()
    TruckerLog.info("Archetype distribution (%d factions assigned):", total)
    for _, name in ipairs(TruckerArchetypes.LIST) do
        local n = counts[name] or 0
        local pct = total > 0 and (100 * n / total) or 0
        TruckerLog.info("  %-13s %4d (%5.1f%%)", name, n, pct)
    end
end

return TruckerAssignArchetypes
