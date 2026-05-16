-- Predicate for factions that should never receive a Trucker archetype.
-- Pirates, smugglers, the Xsotan, and the player faction itself are all
-- excluded; archetypes apply only to civilian NPC factions.
package.path = package.path .. ";data/scripts/lib/?.lua"

TruckerExcluded = {}

function TruckerExcluded.isExcluded(faction)
    if not faction then return true end

    -- Player & alliance factions: they pick their own destinies.
    if faction.isPlayer then return true end
    if faction.isAlliance then return true end

    -- Vanilla flags for special non-civilian factions.
    if faction.isAIFaction == false then
        -- non-AI is a player or alliance, already covered, but be defensive
        return true
    end

    if faction.isPirate then return true end
    if faction.isXsotan then return true end

    -- Smuggler & special story factions: detected via the "invisible" trait
    -- which vanilla uses to mark hidden / non-civilian groups.
    local ok, invisible = pcall(function() return faction:getTrait("invisible") end)
    if ok and invisible and invisible > 0.5 then return true end

    return false
end

return TruckerExcluded
