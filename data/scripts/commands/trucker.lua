-- /trucker <subcommand>  — Space Trucker diagnostic and codex commands.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerAssign  = include("truckerassignarchetypes")
local TruckerJournal = include("truckerjournal")
local TruckerReports = include("truckerreports")
local TruckerSurvey  = include("truckersurvey")

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
            "Journal: %d personal, %d alliance-shared. Reports purchased: %d.",
            p, s, r))
    end
end

-- Render one report as live-computed text lines for the chat output.
local function renderReport(player, r, index)
    local lines = {}
    local arch     = r.archetype or "?"
    local strength = r.strength or 1.0
    local subject  = Faction(r.subjectFactionId)

    table.insert(lines, string.format(
        "[%d] %s --- %s (strength %.2f)",
        index, tostring(r.subjectFactionName), arch, strength))

    local sellsCheap, buysHigh = TruckerReports.summarizeBias(arch, strength)
    table.insert(lines, string.format("    Sells cheap: %s",
        #sellsCheap > 0 and table.concat(sellsCheap, ", ") or "(none)"))
    table.insert(lines, string.format("    Buys high:   %s",
        #buysHigh > 0 and table.concat(buysHigh, ", ") or "(none)"))

    local atWar = TruckerReports.atWarWith(subject)
    if #atWar > 0 then
        table.insert(lines, "    AT WAR with: " .. table.concat(atWar, ", "))
    end

    local band = TruckerReports.computePriceBand(arch, strength)
    if #band > 0 then
        table.insert(lines, "    -- Expected price band (vanilla * archetype * strength)")
        for i, row in ipairs(band) do
            if i > 12 then
                table.insert(lines, string.format(
                    "       ... and %d more", #band - 12))
                break
            end
            table.insert(lines, string.format(
                "       %-22s %6d cr  (vanilla %d, x%.2f)",
                row.name, math.floor(row.expected), row.vanilla, row.multiplier))
        end
    end

    local obs = TruckerReports.computeObservationStats(player, r.subjectFactionId)
    local function fmtStation(o)
        if not o then return "?" end
        local name = o.stationName or "?"
        if o.sectorX and o.sectorY then
            return string.format("%s in (%d,%d)", name, o.sectorX, o.sectorY)
        end
        return name
    end

    if #obs > 0 then
        table.insert(lines, "    -- Your observations in their space")
        for _, o in ipairs(obs) do
            if o.buyStats then
                table.insert(lines, string.format(
                    "       BUY  %-18s avg %d  range %d-%d  (%d obs)  best: %s",
                    o.commodity, math.floor(o.buyStats.avg),
                    o.buyStats.min, o.buyStats.max, o.buyStats.count,
                    fmtStation(o.bestBuy)))
            end
            if o.sellStats then
                table.insert(lines, string.format(
                    "       SELL %-18s avg %d  range %d-%d  (%d obs)  best: %s",
                    o.commodity, math.floor(o.sellStats.avg),
                    o.sellStats.min, o.sellStats.max, o.sellStats.count,
                    fmtStation(o.bestSell)))
            end
        end
    else
        table.insert(lines, "    (no observations yet -- visit their stations with a Trading System)")
    end
    return lines
end

local function cmdReports(player)
    if not player then return end
    local reports = TruckerReports.list(player)
    if #reports == 0 then
        send(player, "No purchased reports.")
        return
    end
    send(player, string.format("=== %d purchased reports ===", #reports))
    for i, r in ipairs(reports) do
        for _, line in ipairs(renderReport(player, r, i)) do
            send(player, line)
        end
    end
end

local function cmdSurvey(player)
    if not player then return end
    for _, line in ipairs(TruckerSurvey.formatLines(player)) do
        send(player, line)
    end
end

local DISPATCH = {
    debug   = cmdDebug,
    reports = cmdReports,
    survey  = cmdSurvey,
}

function execute(sender, commandName, sub, ...)
    sub = sub or "debug"
    local player = (type(sender) == "number") and Player(sender) or sender
    local fn = DISPATCH[sub]
    if not fn then
        send(player, "Unknown subcommand. Try: debug | reports | survey")
        return 1, "", ""
    end
    fn(player, ...)
    return 0, "", ""
end

function getDescription()
    return "Space Trucker diagnostics: distribution, reports, survey"
end

function getHelp()
    return "Usage: /trucker [debug|reports|survey]"
end
