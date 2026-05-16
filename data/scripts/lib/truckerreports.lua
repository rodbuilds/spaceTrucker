-- Faction Commodity Reports: business logic shared by the merchant and the
-- codex view. Keeps pricing, snapshot construction, and persistence in one
-- place so client and server can both reason about reports.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerArchetypes = include("truckerarchetypes")
local TruckerJournal    = include("truckerjournal")
local TruckerLog        = include("truckerlog")

TruckerReports = {}

local REPORTS_KEY = "trucker_reports"

-- Configurable via spacetrucker config; default scaling formula.
TruckerReports.PRICE_BASE  = 50000        -- credits, baseline
TruckerReports.PRICE_PER_POWER = 5000     -- credits per faction power point
TruckerReports.MAX_SNAPSHOT_ROWS = 100    -- cap rows captured in snapshot

-- Bias summary into "Tends CHEAP" / "Tends DEAR" lists for codex display.
function TruckerReports.summarizeBias(archetype)
    local bias = TruckerArchetypes.getBias(archetype)
    if not bias then return {}, {} end
    local cheap, dear = {}, {}
    for tag, m in pairs(bias) do
        if m < 0.95 then table.insert(cheap, tag)
        elseif m > 1.05 then table.insert(dear, tag) end
    end
    table.sort(cheap); table.sort(dear)
    return cheap, dear
end

-- Compute a report's price in credits for a given subject faction.
function TruckerReports.priceFor(faction)
    local power = 0
    if faction and faction.power then power = faction.power end
    if type(power) ~= "number" then power = 0 end
    return math.max(TruckerReports.PRICE_BASE,
                    TruckerReports.PRICE_BASE + math.floor(power * TruckerReports.PRICE_PER_POWER))
end

-- Build the report snapshot for a buyer / subject faction. Pulls the
-- buyer's effective journal, filters to that faction's observations,
-- and copies up to MAX_SNAPSHOT_ROWS rows (newest first).
local function buildSnapshot(buyer, subjectFaction)
    if not buyer or not subjectFaction then return {} end
    local rows = TruckerJournal.queryByFaction(buyer, subjectFaction.index)
    if #rows > TruckerReports.MAX_SNAPSHOT_ROWS then
        local trimmed = {}
        for i = 1, TruckerReports.MAX_SNAPSHOT_ROWS do trimmed[i] = rows[i] end
        rows = trimmed
    end
    return rows
end

local function readReports(player)
    if not player then return {} end
    local raw = player:getValue(REPORTS_KEY)
    if type(raw) ~= "table" then return {} end
    return raw
end

local function writeReports(player, reports)
    if not player then return end
    player:setValue(REPORTS_KEY, reports)
end

-- Persist a freshly purchased report. Returns the entry that was stored.
function TruckerReports.purchase(buyer, subjectFaction)
    if not onServer() then return nil end
    if not buyer or not subjectFaction then return nil end

    local archetype = subjectFaction:getValue("trucker_archetype")
    if not archetype or not TruckerArchetypes.isValid(archetype) then
        return nil, "subject faction has no archetype"
    end

    local cheap, dear = TruckerReports.summarizeBias(archetype)
    local ts = (Server and Server() and Server().unpausedRuntime) or os.time()

    local entry = {
        subjectFactionId   = subjectFaction.index,
        subjectFactionName = subjectFaction.name,
        archetype          = archetype,
        biasCheap          = cheap,
        biasDear           = dear,
        snapshot           = buildSnapshot(buyer, subjectFaction),
        purchasedAt        = ts,
    }

    local reports = readReports(buyer)
    table.insert(reports, entry)
    writeReports(buyer, reports)

    TruckerLog.info("Player %s purchased report on %s (%s)",
        tostring(buyer.name), tostring(subjectFaction.name), archetype)

    return entry
end

function TruckerReports.list(player)
    return readReports(player)
end

function TruckerReports.count(player)
    return #readReports(player)
end

-- Return the most-recent report for `subjectFactionId`, or nil if none.
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

-- Live war-status warning. Queries faction relations at render time.
-- Returns a list of faction NAMES the subject is currently at war with.
function TruckerReports.atWarWith(subjectFaction)
    local out = {}
    if not subjectFaction then return out end
    local ok, statuses = pcall(function() return subjectFaction:getRelationsStatuses() end)
    if not ok or type(statuses) ~= "table" then return out end
    for otherIdx, status in pairs(statuses) do
        if status == RelationStatus.War or status == 1 then  -- best-effort
            local other = Faction(otherIdx)
            if other and other.name then table.insert(out, other.name) end
        end
    end
    return out
end

return TruckerReports
