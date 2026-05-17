-- Faction Commodity Reports: business logic shared by merchant + codex.
--
-- Stored per-report: subject faction, archetype, strength, purchase time.
-- Everything else (price band, observation aggregates, war status) is
-- LIVE-COMPUTED at view time so the report stays current as the player
-- collects more observations and the galaxy state changes.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerArchetypes = include("truckerarchetypes")
local TruckerJournal    = include("truckerjournal")
local TruckerLog        = include("truckerlog")
local TruckerSerialize  = include("truckerserialize")
local TruckerAssign     = include("truckerassignarchetypes")

TruckerReports = {}

local REPORTS_KEY = "trucker_reports"

TruckerReports.PRICE_BASE = 50000

-- Strict thresholds for "cheap" / "high" classification (after strength
-- has been applied). Keeps Mercantile's narrow spreads from cluttering.
local CHEAP_THRESHOLD = 0.95
local DEAR_THRESHOLD  = 1.05

-- ---------- bias / band ----------

-- Sells-cheap (player buys here for less) / Buys-high (player sells here
-- for more) lists. Uses STRENGTH-ADJUSTED bias.
function TruckerReports.summarizeBias(archetype, strength)
    local bias = TruckerArchetypes.getEffectiveBias(archetype, strength or 1.0)
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

-- Predicted price band: for every vanilla commodity that has a matching
-- tag in this archetype's bias, compute baseline × effective bias. Only
-- includes commodities whose multiplier deviates more than 5% from 1.0,
-- so the list shows the signal (cheap things and dear things) rather than
-- a long neutral list. Returns rows sorted by multiplier ascending
-- (cheapest first), so the player sees the best buys at the top.
function TruckerReports.computePriceBand(archetype, strength)
    local bias = TruckerArchetypes.getEffectiveBias(archetype, strength or 1.0)
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
                    name      = name,
                    tag       = tag,
                    vanilla   = g.price,
                    expected  = g.price * m,
                    multiplier = m,
                })
            end
        end
    end
    table.sort(rows, function(a, b) return a.multiplier < b.multiplier end)
    return rows
end

-- ---------- observation aggregates ----------

-- Per-commodity aggregates over the player's journal entries for this
-- faction's stations. Returns rows sorted by commodity name.
function TruckerReports.computeObservationStats(player, subjectFactionId)
    if not player or not subjectFactionId then return {} end
    local rows = TruckerJournal.queryByFaction(player, subjectFactionId)

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
        local bestSell = bestOf(data.sells, function(a, b) return (a.price or 0) > (b.price or 0) end)
        table.insert(out, {
            commodity = commodity,
            buyStats  = statsOf(data.buys),   -- player buys (station sells)
            sellStats = statsOf(data.sells),  -- player sells (station buys)
            bestBuy   = bestBuy,              -- cheapest station to buy from
            bestSell  = bestSell,             -- richest station to sell to
        })
    end
    table.sort(out, function(a, b) return a.commodity < b.commodity end)
    return out
end

-- ---------- persistence ----------

function TruckerReports.priceFor(faction)
    return TruckerReports.PRICE_BASE
end

local function readReports(player)
    if not player then return {} end
    local raw = player:getValue(REPORTS_KEY)
    if type(raw) ~= "string" then return {} end
    local decoded = TruckerSerialize.decode(raw)
    return (type(decoded) == "table") and decoded or {}
end

local function writeReports(player, reports)
    if not player then return end
    player:setValue(REPORTS_KEY, TruckerSerialize.encode(reports))
end

-- Record a purchase. Only the minimum is stored — content is live-rendered.
function TruckerReports.purchase(buyer, subjectFaction)
    if not onServer() then return nil end
    if not buyer or not subjectFaction then return nil end

    local archetype = subjectFaction:getValue("trucker_archetype")
    if not archetype or not TruckerArchetypes.isValid(archetype) then
        return nil, "subject faction has no archetype"
    end
    local strength = TruckerAssign.getStrength(subjectFaction) or 1.0
    local ts = (Server and Server() and Server().unpausedRuntime) or os.time()

    local entry = {
        subjectFactionId   = subjectFaction.index,
        subjectFactionName = subjectFaction.name,
        archetype          = archetype,
        strength           = strength,
        purchasedAt        = ts,
    }
    local reports = readReports(buyer)
    -- Replace any existing entry for the same faction (live re-render makes
    -- duplicates redundant).
    for i = #reports, 1, -1 do
        if reports[i].subjectFactionId == subjectFaction.index then
            table.remove(reports, i)
        end
    end
    table.insert(reports, entry)
    writeReports(buyer, reports)

    TruckerLog.info("Player %s purchased report on %s (%s, strength %.2f)",
        tostring(buyer.name), tostring(subjectFaction.name), archetype, strength)
    return entry
end

function TruckerReports.list(player)
    return readReports(player)
end

function TruckerReports.count(player)
    return #readReports(player)
end

function TruckerReports.latestFor(player, subjectFactionId)
    local reports = readReports(player)
    local latest, latestTs
    for _, r in ipairs(reports) do
        if r.subjectFactionId == subjectFactionId then
            if not latestTs or (r.purchasedAt or 0) > latestTs then
                latest, latestTs = r, r.purchasedAt
            end
        end
    end
    return latest
end

-- Live war-status warning.
-- Faction.getRelationsStatuses isn't exposed in this Avorion build. The
-- correct API is Galaxy():getFactionRelationStatus(a, b), but enumerating
-- all factions in the galaxy per report render is expensive. Deferred:
-- return an empty list for now. Stubs out the war badge cleanly.
function TruckerReports.atWarWith(subjectFaction)
    return {}
end

return TruckerReports
