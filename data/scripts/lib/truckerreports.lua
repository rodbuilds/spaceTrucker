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

-- Defaults; overridden by SpaceTruckerConfig.apply()
TruckerReports.PRICE_BASE        = 1000000   -- Faction Survey base; * specialization
TruckerReports.TRADE_REPORT_FEE  = 50000     -- per-open fee at the AI merchant
TruckerReports.OBSERVATION_CAP   = 2000      -- max journal rows per Trade Report

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

return TruckerReports
