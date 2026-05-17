-- Predicate for factions that should never receive a Trucker archetype.
-- Pirates, smugglers, the Xsotan, and the player faction itself are all
-- excluded; archetypes apply only to civilian NPC factions.
package.path = package.path .. ";data/scripts/lib/?.lua"

TruckerExcluded = {}

function TruckerExcluded.isExcluded(faction)
    if not faction then return true end

    -- Note: isPirate/isXsotan are NOT used because Avorion logs a hard error
    -- when an undefined Faction property is read, even inside pcall. Pirate
    -- and Xsotan factions are filtered downstream because the report merchant
    -- only attaches to stations with tradingpost.lua / headquarters.lua,
    -- which those factions do not own.
    local function probe(name)
        local ok, v = pcall(function() return faction[name] end)
        return ok and v
    end

    if probe("isPlayer") then return true end
    if probe("isAlliance") then return true end

    local okAI, aiFaction = pcall(function() return faction.isAIFaction end)
    if okAI and aiFaction == false then return true end

    -- "invisible" trait covers smugglers & story-only factions.
    local okT, invisible = pcall(function() return faction:getTrait("invisible") end)
    if okT and invisible and invisible > 0.5 then return true end

    return false
end

return TruckerExcluded
