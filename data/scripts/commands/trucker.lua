-- /trucker <subcommand>  -  Space Trucker diagnostic + codex commands.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerAssign     = include("truckerassignarchetypes")
local TruckerJournal    = include("truckerjournal")
local TruckerReports    = include("truckerreports")
local TruckerSurvey     = include("truckersurvey")
local TruckerArchetypes = include("truckerarchetypes")

local function send(player, msg)
    if player and player.sendChatMessage then
        player:sendChatMessage("Trucker", 0, msg)
    else
        print(msg)
    end
end

local function cmdDebug(player)
    TruckerAssign.dumpDistribution()
    if player then
        local p, s = TruckerJournal.size(player)
        local r    = TruckerReports.count(player)
        send(player, string.format(
            "Journal: %d personal, %d alliance-shared. Faction Surveys: %d.",
            p, s, r))
    end
end

-- Render one Faction Survey as live-computed text lines.
local function renderSurvey(player, survey, index)
    local lines = {}
    local economy        = survey.economy or "?"
    local specialization = survey.specialization or 1.0
    local stars = TruckerArchetypes.specializationStarString(specialization)
    local label = TruckerArchetypes.specializationLabel(specialization)

    table.insert(lines, string.format(
        "[%d] %s -- %s Economy  %s (%s)",
        index, tostring(survey.subjectFactionName), economy, stars, label))

    local sellsCheap, buysHigh = TruckerReports.summarizeBias(economy, specialization)
    table.insert(lines, string.format("    Sells cheap: %s",
        #sellsCheap > 0 and table.concat(sellsCheap, ", ") or "(none)"))
    table.insert(lines, string.format("    Buys high:   %s",
        #buysHigh > 0 and table.concat(buysHigh, ", ") or "(none)"))

    local band = TruckerReports.computePriceBand(economy, specialization)
    if #band > 0 then
        table.insert(lines, "    -- Expected price band  (Galactic Avg -> Faction Avg)")
        for i, row in ipairs(band) do
            if i > 12 then
                table.insert(lines, string.format("       ... and %d more", #band - 12))
                break
            end
            table.insert(lines, string.format(
                "       %-22s %6d -> %6d cr",
                string.sub(row.name, 1, 22), row.vanilla, math.floor(row.expected)))
        end
    end
    return lines
end

local function cmdReports(player)
    if not player then return end
    local list = TruckerReports.list(player)
    if #list == 0 then
        send(player, "No Faction Surveys in your Codex. Visit a Trading Post and use the Quantum Trading AI.")
        return
    end
    send(player, string.format("=== %d Faction Surveys ===", #list))
    for i, survey in ipairs(list) do
        for _, line in ipairs(renderSurvey(player, survey, i)) do
            send(player, line)
        end
    end
end

local function cmdSurvey(player)
    if not player then return end
    for _, line in ipairs(TruckerSurvey.formatLines(player)) do
        send(player, line)
    end
    send(player, "(Visit a Trading Post for the full Quantum Trading AI Trade Report.)")
end

local DISPATCH = {
    debug   = cmdDebug,
    reports = cmdReports,
    survey  = cmdSurvey,
    codex   = cmdReports,   -- friendly alias
}

function execute(sender, commandName, sub, ...)
    sub = sub or "debug"
    local player = (type(sender) == "number") and Player(sender) or sender
    local fn = DISPATCH[sub]
    if not fn then
        send(player, "Unknown subcommand. Try: debug | reports | codex | survey")
        return 1, "", ""
    end
    fn(player, ...)
    return 0, "", ""
end

function getDescription()
    return "Space Trucker: diagnostics, codex listing, journal survey"
end

function getHelp()
    return "Usage: /trucker [debug|reports|codex|survey]"
end
