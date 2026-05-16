-- Space Trucker server-side configuration.
--
-- This file is loaded once at server start by including it from any of
-- the lib modules that need configurable values. Edit and reload the
-- server to apply.
--
-- All values have sensible defaults if this file is missing; this file
-- exists so server operators can tune without editing library code.
package.path = package.path .. ";data/scripts/lib/?.lua"

SpaceTruckerConfig = {}

-- Trade journal: maximum entries per player and per alliance store.
-- Older entries are pruned first when the cap is reached.
SpaceTruckerConfig.journalMaxEntries = 5000

-- Faction commodity reports pricing.
-- Final price = priceBase + max(0, faction.power) * pricePerPower
SpaceTruckerConfig.reportPriceBase     = 50000
SpaceTruckerConfig.reportPricePerPower = 5000

-- Maximum snapshot rows captured into a purchased report.
SpaceTruckerConfig.reportSnapshotRows  = 100

-- Maximum share of assigned factions any single archetype may occupy.
-- Distribution guardrail; values in (0, 1].
SpaceTruckerConfig.archetypeMaxShare   = 0.30

-- Trait influence overrides. Set to nil to use built-in defaults.
-- Format: { traitName = { archetypeName = additiveWeight, ... }, ... }
SpaceTruckerConfig.traitInfluence = nil

-- Apply the configured values to the runtime modules. Call this once
-- after loading. (Deferred so users can edit this file in isolation.)
function SpaceTruckerConfig.apply()
    local TruckerJournal = include("truckerjournal")
    local TruckerReports = include("truckerreports")
    local TruckerArchetypes = include("truckerarchetypes")

    if SpaceTruckerConfig.journalMaxEntries then
        TruckerJournal.MAX_ENTRIES = SpaceTruckerConfig.journalMaxEntries
    end
    if SpaceTruckerConfig.reportPriceBase then
        TruckerReports.PRICE_BASE = SpaceTruckerConfig.reportPriceBase
    end
    if SpaceTruckerConfig.reportPricePerPower then
        TruckerReports.PRICE_PER_POWER = SpaceTruckerConfig.reportPricePerPower
    end
    if SpaceTruckerConfig.reportSnapshotRows then
        TruckerReports.MAX_SNAPSHOT_ROWS = SpaceTruckerConfig.reportSnapshotRows
    end
    if SpaceTruckerConfig.archetypeMaxShare then
        TruckerArchetypes.MAX_SHARE = SpaceTruckerConfig.archetypeMaxShare
    end
end

return SpaceTruckerConfig
