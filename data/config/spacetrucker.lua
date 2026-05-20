-- Space Trucker: Quantum Trade — server-side configuration.
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

-- Trade Report (Quantum Trading AI) fee per run. The Quantum AI window
-- itself opens for free; the player clicks an explicit "Pay X cr to run
-- Trade Report" button to spend the fee and load the report. Faction
-- Survey acquisition is a separate, more expensive transaction.
SpaceTruckerConfig.tradeReportFee = 50000

-- Trade Report validity window, in seconds. After payment, the player
-- can reopen the Trade Report at ANY Quantum Trading AI for free until
-- this window expires. Prevents punishing accidental closes / map checks.
SpaceTruckerConfig.tradeReportValiditySeconds = 3600

-- Faction Survey acquisition price base.
-- Final price = factionSurveyBasePrice * specialization
-- (specialization is the per-faction scalar rolled at assignment, ~0.3..1.8)
SpaceTruckerConfig.factionSurveyBasePrice = 1000000

-- Trade Report observation cap: aggregate at most this many journal
-- observations (newest first) when computing the Trade Report payload.
-- Invisible to the player; a safety belt against pathological saves.
SpaceTruckerConfig.surveyObservationCap = 2000

-- Maximum share of assigned factions any single Economy may occupy.
-- Distribution guardrail; values in (0, 1].
SpaceTruckerConfig.archetypeMaxShare = 0.30

-- Trait influence overrides. Set to nil to use built-in defaults.
-- Format: { traitName = { economyName = additiveWeight, ... }, ... }
SpaceTruckerConfig.traitInfluence = nil

-- --- Deprecated MVP-era aliases (do not edit; kept so older configs still load). ---
SpaceTruckerConfig.reportPriceBase     = nil
SpaceTruckerConfig.reportPricePerPower = nil
SpaceTruckerConfig.reportSnapshotRows  = nil

-- Apply the configured values to the runtime modules. Call this once
-- after loading. (Deferred so users can edit this file in isolation.)
function SpaceTruckerConfig.apply()
    local TruckerJournal    = include("truckerjournal")
    local TruckerReports    = include("truckerreports")
    local TruckerArchetypes = include("truckerarchetypes")

    if SpaceTruckerConfig.journalMaxEntries then
        TruckerJournal.MAX_ENTRIES = SpaceTruckerConfig.journalMaxEntries
    end
    if SpaceTruckerConfig.tradeReportFee then
        TruckerReports.TRADE_REPORT_FEE = SpaceTruckerConfig.tradeReportFee
    end
    if SpaceTruckerConfig.factionSurveyBasePrice then
        TruckerReports.PRICE_BASE = SpaceTruckerConfig.factionSurveyBasePrice
    end
    if SpaceTruckerConfig.surveyObservationCap then
        TruckerReports.OBSERVATION_CAP = SpaceTruckerConfig.surveyObservationCap
    end
    if SpaceTruckerConfig.tradeReportValiditySeconds then
        TruckerReports.TRADE_REPORT_VALIDITY = SpaceTruckerConfig.tradeReportValiditySeconds
    end
    if SpaceTruckerConfig.archetypeMaxShare then
        TruckerArchetypes.MAX_SHARE = SpaceTruckerConfig.archetypeMaxShare
    end

    -- Deprecated keys map to new ones if a user-edited config still sets them.
    if SpaceTruckerConfig.reportPriceBase then
        TruckerReports.PRICE_BASE = SpaceTruckerConfig.reportPriceBase
    end
end

return SpaceTruckerConfig
