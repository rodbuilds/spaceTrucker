-- /trucker <subcommand>  — Space Trucker diagnostic and codex commands.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerAssign  = include("truckerassignarchetypes")
local TruckerJournal = include("truckerjournal")
local TruckerReports = include("truckerreports")
local TruckerSurvey  = include("truckersurvey")

local function send(sender, msg)
    if sender and sender.sendChatMessage then
        sender:sendChatMessage("Trucker", 0, msg)
    else
        print(msg)
    end
end

local function cmdDebug(sender)
    TruckerAssign.dumpDistribution()
    if sender then
        local p, s = TruckerJournal.size(sender)
        local r    = TruckerReports.count(sender)
        send(sender, string.format(
            "Journal: %d personal, %d alliance-shared. Reports purchased: %d.",
            p, s, r))
    end
end

local function cmdReports(sender)
    if not sender then return end
    local reports = TruckerReports.list(sender)
    if #reports == 0 then
        send(sender, "No purchased reports.")
        return
    end
    send(sender, string.format("=== %d purchased reports ===", #reports))
    for i, r in ipairs(reports) do
        local cheap = #r.biasCheap > 0 and table.concat(r.biasCheap, ",") or "(none)"
        local dear  = #r.biasDear  > 0 and table.concat(r.biasDear,  ",") or "(none)"
        send(sender, string.format(
            "[%d] %s — %s | CHEAP: %s | DEAR: %s | snapshot: %d rows | bought: %d",
            i, tostring(r.subjectFactionName), tostring(r.archetype),
            cheap, dear, #(r.snapshot or {}), r.purchasedAt or 0))
        local atWar = TruckerReports.atWarWith(Faction(r.subjectFactionId))
        if #atWar > 0 then
            send(sender, "    WARNING: AT WAR with " .. table.concat(atWar, ", "))
        end
    end
end

local function cmdSurvey(sender)
    if not sender then return end
    for _, line in ipairs(TruckerSurvey.formatLines(sender)) do
        send(sender, line)
    end
end

local DISPATCH = {
    debug   = cmdDebug,
    reports = cmdReports,
    survey  = cmdSurvey,
}

function execute(sender, commandName, sub, ...)
    sub = sub or "debug"
    local fn = DISPATCH[sub]
    if not fn then
        send(sender, "Unknown subcommand. Try: debug | reports | survey")
        return 1, "", ""
    end
    fn(sender, ...)
    return 0, "", ""
end

function getDescription()
    return "Space Trucker diagnostics: distribution, reports, survey"
end

function getHelp()
    return "Usage: /trucker [debug|reports|survey]"
end
