-- Faction Surveys: business logic shared by the Quantum Trading AI merchant
-- and the Trader's Codex UI.
--
-- Stored per-Survey (minimal shape): subjectFactionId, subjectFactionName,
-- economy, specialization, acquiredAt. Everything else (price band,
-- observation aggregates, sells-cheap/buys-high tag lists) is LIVE-COMPUTED
-- on demand so the Codex stays current as the player travels.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerArchetypes = include("truckerarchetypes")
local TruckerJournal    = include("truckerjournal")
local TruckerLog        = include("truckerlog")
local TruckerSerialize  = include("truckerserialize")
local TruckerAssign     = include("truckerassignarchetypes")

TruckerReports = {}

local SURVEYS_KEY     = "trucker_reports"   -- legacy key name kept for back-compat
local LEGACY_WARN_KEY = "trucker_legacy_warn_sent"
local TRADE_REPORT_PAID_AT_KEY = "trucker_trade_report_paid_at"

-- Defaults; overridden by SpaceTruckerConfig.apply()
TruckerReports.PRICE_BASE              = 1000000   -- Faction Survey base; * specialization
TruckerReports.TRADE_REPORT_FEE        = 50000     -- per-run fee at the AI merchant
TruckerReports.OBSERVATION_CAP         = 2000      -- max journal rows per Trade Report
TruckerReports.TRADE_REPORT_VALIDITY   = 3600      -- seconds a paid Trade Report stays valid

-- Tag classification thresholds (after specialization is applied).
local CHEAP_THRESHOLD = 0.95
local DEAR_THRESHOLD  = 1.05

-- ---------- price-band / bias summary (live) ----------

function TruckerReports.summarizeBias(economy, specialization)
    local bias = TruckerArchetypes.getEffectiveBias(economy, specialization or 1.0)
    if not bias then return {}, {} end
    local sellsCheap, buysHigh = {}, {}
    for tag, m in pairs(bias) do
        if m < CHEAP_THRESHOLD then table.insert(sellsCheap, tag)
        elseif m > DEAR_THRESHOLD then table.insert(buysHigh, tag) end
    end
    table.sort(sellsCheap); table.sort(buysHigh)
    return sellsCheap, buysHigh
end

local TAG_PRIORITY = {
    "illegal", "military", "hightech", "consumer",
    "civil",   "industrial", "refined", "raw",
}
local function pickTag(goodTags)
    if type(goodTags) ~= "table" then return nil end
    for _, key in ipairs(TAG_PRIORITY) do
        if goodTags[key] then return key end
    end
    return nil
end

function TruckerReports.computePriceBand(economy, specialization)
    local bias = TruckerArchetypes.getEffectiveBias(economy, specialization or 1.0)
    if not bias then return {} end
    local ok = pcall(function() include("goods") end)
    if not ok or type(goods) ~= "table" then return {} end

    local rows = {}
    for name, g in pairs(goods) do
        if type(g) == "table" and type(g.price) == "number" then
            local tag = pickTag(g.tags)
            local m = tag and bias[tag] or nil
            if type(m) == "number" and (m < CHEAP_THRESHOLD or m > DEAR_THRESHOLD) then
                table.insert(rows, {
                    name       = name,
                    tag        = tag,
                    vanilla    = g.price,
                    expected   = g.price * m,
                    multiplier = m,
                })
            end
        end
    end
    table.sort(rows, function(a, b) return a.multiplier < b.multiplier end)
    return rows
end

-- ---------- observation aggregates (live, for Trade Report) ----------

function TruckerReports.computeObservationStats(player, optionalFactionId)
    if not player then return {} end
    local rows
    if optionalFactionId then
        rows = TruckerJournal.queryByFaction(player, optionalFactionId)
    else
        rows = TruckerJournal.effectiveJournal(player)
    end
    -- Cap to newest N for performance (already sorted newest-first by
    -- effectiveJournal); queryByFaction inherits the same sort.
    if #rows > TruckerReports.OBSERVATION_CAP then
        local trimmed = {}
        for i = 1, TruckerReports.OBSERVATION_CAP do trimmed[i] = rows[i] end
        rows = trimmed
    end

    local agg = {}  -- commodity -> {buys=[], sells=[]}
    for _, r in ipairs(rows) do
        local c = r.commodity or "?"
        agg[c] = agg[c] or { buys = {}, sells = {} }
        local bucket = (r.action == "buy") and agg[c].buys or agg[c].sells
        table.insert(bucket, r)
    end

    local function bestOf(list, comparator)
        local best
        for _, r in ipairs(list) do
            if not best or comparator(r, best) then best = r end
        end
        return best
    end
    local function statsOf(list)
        if #list == 0 then return nil end
        local total, mn, mx = 0, math.huge, -math.huge
        for _, r in ipairs(list) do
            total = total + (r.price or 0)
            if (r.price or 0) < mn then mn = r.price end
            if (r.price or 0) > mx then mx = r.price end
        end
        return { count = #list, avg = total / #list, min = mn, max = mx }
    end

    local out = {}
    for commodity, data in pairs(agg) do
        local bestBuy  = bestOf(data.buys,  function(a, b) return (a.price or math.huge) < (b.price or math.huge) end)
        local bestSell = bestOf(data.sells, function(a, b) return (a.price or 0)         > (b.price or 0)         end)
        table.insert(out, {
            commodity = commodity,
            buyStats  = statsOf(data.buys),
            sellStats = statsOf(data.sells),
            bestBuy   = bestBuy,
            bestSell  = bestSell,
        })
    end
    table.sort(out, function(a, b) return a.commodity < b.commodity end)
    return out
end

-- ---------- persistence ----------

function TruckerReports.priceFor(faction)
    if not faction then return TruckerReports.PRICE_BASE end
    local spec = TruckerAssign.getSpecialization and TruckerAssign.getSpecialization(faction)
              or TruckerAssign.getStrength(faction)
              or 1.0
    return math.floor(TruckerReports.PRICE_BASE * spec)
end

-- Trade Report validity window. Once the player pays for a Trade Report,
-- they can reopen it for free for the next TRADE_REPORT_VALIDITY seconds.
local function nowTs()
    return (Server and Server() and Server().unpausedRuntime) or os.time()
end

function TruckerReports.markTradeReportPaid(player)
    if not onServer() or not player then return end
    player:setValue(TRADE_REPORT_PAID_AT_KEY, nowTs())
end

-- Returns (isValid, secondsRemaining). secondsRemaining is 0 when expired.
function TruckerReports.tradeReportValidity(player)
    if not player then return false, 0 end
    local paidAt = player:getValue(TRADE_REPORT_PAID_AT_KEY)
    if type(paidAt) ~= "number" then return false, 0 end
    local elapsed = nowTs() - paidAt
    local validity = TruckerReports.TRADE_REPORT_VALIDITY or 0
    if elapsed < 0 or elapsed >= validity then return false, 0 end
    return true, math.floor(validity - elapsed)
end

local function readSurveys(player)
    if not player then return {} end
    local raw = player:getValue(SURVEYS_KEY)
    if type(raw) ~= "string" then return {} end
    local decoded = TruckerSerialize.decode(raw)
    if type(decoded) ~= "table" then return {} end

    local kept, skipped = {}, 0
    for _, entry in ipairs(decoded) do
        if type(entry) == "table" and entry.economy then
            table.insert(kept, entry)
        else
            skipped = skipped + 1
        end
    end

    if skipped > 0 and not player:getValue(LEGACY_WARN_KEY) then
        TruckerLog.warn(
            "Skipped %d legacy report entries for %s; create a fresh galaxy to reset.",
            skipped, tostring(player.name))
        player:setValue(LEGACY_WARN_KEY, true)
    end
    return kept
end

local function writeSurveys(player, list)
    if not player then return end
    player:setValue(SURVEYS_KEY, TruckerSerialize.encode(list))
end

-- Acquire a Faction Survey. Replaces any existing entry for the same faction.
function TruckerReports.purchase(buyer, subjectFaction)
    if not onServer() then return nil end
    if not buyer or not subjectFaction then return nil end

    local economy = subjectFaction:getValue("trucker_archetype")
    if not economy or not TruckerArchetypes.isValid(economy) then
        return nil, "subject faction has no economy"
    end
    local specialization = (TruckerAssign.getSpecialization and TruckerAssign.getSpecialization(subjectFaction))
                        or TruckerAssign.getStrength(subjectFaction)
                        or 1.0
    local ts = (Server and Server() and Server().unpausedRuntime) or os.time()

    local entry = {
        subjectFactionId   = subjectFaction.index,
        subjectFactionName = subjectFaction.name,
        economy            = economy,
        specialization     = specialization,
        acquiredAt         = ts,
    }
    local list = readSurveys(buyer)
    for i = #list, 1, -1 do
        if list[i].subjectFactionId == subjectFaction.index then
            table.remove(list, i)
        end
    end
    table.insert(list, entry)
    writeSurveys(buyer, list)

    TruckerLog.info(
        "Player %s acquired Faction Survey on %s (%s, specialization %.2f)",
        tostring(buyer.name), tostring(subjectFaction.name), economy, specialization)
    return entry
end

function TruckerReports.list(player)
    return readSurveys(player)
end

function TruckerReports.count(player)
    return #readSurveys(player)
end

function TruckerReports.latestFor(player, subjectFactionId)
    local list = readSurveys(player)
    local latest, latestTs
    for _, r in ipairs(list) do
        if r.subjectFactionId == subjectFactionId then
            if not latestTs or (r.acquiredAt or 0) > latestTs then
                latest, latestTs = r, r.acquiredAt
            end
        end
    end
    return latest
end

function TruckerReports.ownsSurveyFor(player, factionId)
    return TruckerReports.latestFor(player, factionId) ~= nil
end

-- ---------- Round-trip routes (Trade Routes tab) ----------

-- Bucket observations by sector + action (player-buy or player-sell), keeping
-- the BEST row per commodity within each sector (lowest buy price / highest
-- sell price). Returns a sorted-canonical-order list of sectors.
local function bucketBySector(rows)
    local sectors = {}
    for _, r in ipairs(rows) do
        local skey = string.format("%d|%d", r.sectorX or 0, r.sectorY or 0)
        local b = sectors[skey]
        if not b then
            b = { key = skey, x = r.sectorX or 0, y = r.sectorY or 0,
                  bestBuys = {}, bestSells = {} }
            sectors[skey] = b
        end
        local c = r.commodity or "?"
        if r.action == "buy" then
            -- Player buys here -> station sells. Track cheapest buy.
            local cur = b.bestBuys[c]
            if not cur or (r.price or math.huge) < (cur.price or math.huge) then
                b.bestBuys[c] = r
            end
        else
            -- Player sells here -> station buys. Track richest sell.
            local cur = b.bestSells[c]
            if not cur or (r.price or 0) > (cur.price or 0) then
                b.bestSells[c] = r
            end
        end
    end
    local list = {}
    for _, b in pairs(sectors) do table.insert(list, b) end
    table.sort(list, function(a, b)
        if a.x ~= b.x then return a.x < b.x end
        return a.y < b.y
    end)
    return list
end

-- Find the best (commodity, buy-at-A, sell-at-B) route between two sector
-- buckets. Returns the route table or nil if no profitable route exists.
local function bestRouteBetween(srcBucket, dstBucket)
    local best
    for commodity, buyRow in pairs(srcBucket.bestBuys) do
        local sellRow = dstBucket.bestSells[commodity]
        if sellRow then
            local perUnit = (sellRow.price or 0) - (buyRow.price or 0)
            if perUnit > 0 then
                local stock  = math.max(0, buyRow.stock or 0)
                local demand = math.max(0, (sellRow.maxStock or 0) - (sellRow.stock or 0))
                local cap    = math.min(stock, demand)
                local tripProfit = perUnit * cap
                if not best or tripProfit > best.tripProfit then
                    best = {
                        commodity     = commodity,
                        buyStation    = buyRow.stationName or "?",
                        buyStock      = stock,
                        buyPrice      = buyRow.price or 0,
                        buyTimestamp  = buyRow.timestamp or 0,
                        sellStation   = sellRow.stationName or "?",
                        sellDemand    = demand,
                        sellPrice     = sellRow.price or 0,
                        sellTimestamp = sellRow.timestamp or 0,
                        perUnitProfit = perUnit,
                        tripCap       = cap,
                        tripProfit    = tripProfit,
                    }
                end
            end
        end
    end
    return best
end

-- Compute round-trip routes. Returns an array of canonical sector-pair rows
-- where BOTH outbound and backhaul are profitable. Sorted by roundTripProfit
-- descending, capped at MAX_PAIRS.
local MAX_PAIRS = 50
function TruckerReports.computeRoundTripRoutes(player)
    if not player then return {} end

    local rows = TruckerJournal.effectiveJournal(player)
    if #rows > TruckerReports.OBSERVATION_CAP then
        local trimmed = {}
        for i = 1, TruckerReports.OBSERVATION_CAP do trimmed[i] = rows[i] end
        rows = trimmed
    end

    local sectors = bucketBySector(rows)
    local routes  = {}

    -- Canonical ordering: i < j so each unordered pair appears once.
    for i = 1, #sectors do
        for j = i + 1, #sectors do
            local A, B = sectors[i], sectors[j]
            local bestOut  = bestRouteBetween(A, B)   -- buy at A, sell at B
            local bestBack = bestRouteBetween(B, A)   -- buy at B, sell at A
            if bestOut and bestBack then
                local dx, dy = A.x - B.x, A.y - B.y
                local distance = math.floor(math.sqrt(dx*dx + dy*dy))
                table.insert(routes, {
                    fromX = A.x, fromY = A.y,
                    toX   = B.x, toY   = B.y,
                    distance        = distance,
                    outbound        = bestOut,
                    backhaul        = bestBack,
                    roundTripProfit = bestOut.tripProfit + bestBack.tripProfit,
                })
            end
        end
    end

    table.sort(routes, function(a, b)
        return a.roundTripProfit > b.roundTripProfit
    end)
    if #routes > MAX_PAIRS then
        local trimmed = {}
        for i = 1, MAX_PAIRS do trimmed[i] = routes[i] end
        routes = trimmed
    end
    return routes
end

return TruckerReports
