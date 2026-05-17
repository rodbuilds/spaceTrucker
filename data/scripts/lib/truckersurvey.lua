-- Sector Survey: derives best-buy / best-sell observations per commodity
-- for the player's effective journal (personal + alliance-shared) and
-- formats them for display.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerJournal = include("truckerjournal")
local TruckerReports = include("truckerreports")

TruckerSurvey = {}

-- For each unique commodity in `rows`, find the lowest-price BUY (player
-- buys from station) and the highest-price SELL (player sells to station).
local function digestRows(rows)
    local digest = {}  -- commodity -> { bestBuy = obs, bestSell = obs }
    for _, r in ipairs(rows) do
        local entry = digest[r.commodity] or {}
        if r.action == "buy" then
            if not entry.bestBuy or r.price < (entry.bestBuy.price or math.huge) then
                entry.bestBuy = r
            end
        elseif r.action == "sell" then
            if not entry.bestSell or r.price > (entry.bestSell.price or -math.huge) then
                entry.bestSell = r
            end
        end
        digest[r.commodity] = entry
    end
    return digest
end

local function relativeTime(now, ts)
    if not ts then return "?" end
    local d = (now or 0) - ts
    if d < 60 then return string.format("%ds ago", math.floor(d)) end
    if d < 3600 then return string.format("%dm ago", math.floor(d / 60)) end
    if d < 86400 then return string.format("%dh ago", math.floor(d / 3600)) end
    return string.format("%dd ago", math.floor(d / 86400))
end

-- Returns a list of formatted text lines summarizing the player's
-- knowledge of commodities currently visible at the player's location.
-- `commodityNames` is optional; if provided, only those commodities are
-- summarized. Otherwise summarizes everything in the journal.
function TruckerSurvey.formatLines(player, commodityNames)
    if not player then return {"(no player context)"} end
    local rows = TruckerJournal.effectiveJournal(player)
    if #rows == 0 then
        return {"Your trade journal will fill as you visit sectors with a Trading System equipped."}
    end

    local digest = digestRows(rows)
    local now = (Server and Server() and Server().unpausedRuntime) or os.time()

    local function fmtObs(label, o)
        if not o then return string.format("  %s: no observation", label) end
        local src = o.__source == "alliance" and " [alliance]" or ""
        return string.format(
            "  %s: %d cr  @  %s  in (%d,%d)  %s%s",
            label, o.price or 0, o.stationName or "?",
            o.sectorX or 0, o.sectorY or 0,
            relativeTime(now, o.timestamp), src
        )
    end

    local out = {}
    local names = commodityNames
    if not names then
        names = {}
        for k in pairs(digest) do table.insert(names, k) end
        table.sort(names)
    end
    for _, c in ipairs(names) do
        local entry = digest[c]
        if entry then
            table.insert(out, string.format("[%s]", c))
            table.insert(out, fmtObs("best buy ", entry.bestBuy))
            table.insert(out, fmtObs("best sell", entry.bestSell))
        else
            table.insert(out, string.format("[%s]  No observations yet", c))
        end
    end
    return out
end

-- Format the archetype hint for the current station's owning faction.
-- Returns a list of lines (typically 1-2).
function TruckerSurvey.formatArchetypeHint(player, faction)
    if not player or not faction then return {} end
    local report = TruckerReports.latestFor(player, faction.index)
    if not report then
        return {string.format(
            "[%s] Faction archetype unknown — purchase a Faction Commodity Report to learn.",
            tostring(faction.name))}
    end
    local sellsCheap, buysHigh = TruckerReports.summarizeBias(
        report.archetype, report.strength or 1.0)
    local cheap = #sellsCheap > 0 and table.concat(sellsCheap, ", ") or "(none)"
    local dear  = #buysHigh   > 0 and table.concat(buysHigh,   ", ") or "(none)"
    local lines = {
        string.format("[%s -- %s (strength %.2f)]",
            tostring(faction.name), tostring(report.archetype), report.strength or 1.0),
        string.format("  Sells cheap: %s", cheap),
        string.format("  Buys high  : %s", dear),
    }
    local atWar = TruckerReports.atWarWith(faction)
    if #atWar > 0 then
        table.insert(lines, "  WARNING: AT WAR with " .. table.concat(atWar, ", "))
    end
    return lines
end

return TruckerSurvey
