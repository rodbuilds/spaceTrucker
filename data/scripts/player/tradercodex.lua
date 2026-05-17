-- Trader's Codex — player-menu tab listing all acquired Faction Surveys.
--
-- Architecture matches vanilla's encyclopedia.lua: one script attached to
-- the player, runs on both client (UI) and server (RPC). Created as a
-- PlayerWindow tab so it's reachable from the standard player menu (P key).
package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")
include("callable")
include("faction")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TraderCodex
TraderCodex = {}
local self = TraderCodex

-- ========================================================================
-- Shared / server
-- ========================================================================

local function buildListEntry(player, survey)
    local TruckerReports = include("truckerreports")
    local sells, buys = TruckerReports.summarizeBias(
        survey.economy, survey.specialization or 1.0)
    return {
        factionId      = survey.subjectFactionId,
        factionName    = survey.subjectFactionName,
        economy        = survey.economy,
        specialization = survey.specialization or 1.0,
        sellsCheap     = table.concat(sells, ", "),
        buysHigh       = table.concat(buys, ", "),
        acquiredAt     = survey.acquiredAt or 0,
    }
end

function TraderCodex.serverGetCodexList(playerIndex)
    if not onServer() then return end
    local TruckerReports = include("truckerreports")
    local player = Player(playerIndex)
    if not player then return end
    local surveys = TruckerReports.list(player)
    local out = {}
    for _, s in ipairs(surveys) do
        table.insert(out, buildListEntry(player, s))
    end
    invokeClientFunction(player, "clientReceiveCodexList", out)
end
callable(TraderCodex, "serverGetCodexList")

function TraderCodex.serverGetCodexDetail(playerIndex, factionId)
    if not onServer() then return end
    local TruckerReports = include("truckerreports")
    local player = Player(playerIndex)
    if not player or not factionId then return end
    local survey = TruckerReports.latestFor(player, factionId)
    if not survey then return end

    local sells, buys = TruckerReports.summarizeBias(
        survey.economy, survey.specialization or 1.0)
    local band = TruckerReports.computePriceBand(
        survey.economy, survey.specialization or 1.0)

    -- Trim to displayable size (top N rows by multiplier).
    local trimmed = {}
    local CAP = 40
    for i = 1, math.min(CAP, #band) do
        local r = band[i]
        table.insert(trimmed, {
            name     = r.name,
            vanilla  = math.floor(r.vanilla),
            expected = math.floor(r.expected),
        })
    end

    invokeClientFunction(player, "clientReceiveCodexDetail", {
        factionId      = factionId,
        factionName    = survey.subjectFactionName,
        economy        = survey.economy,
        specialization = survey.specialization or 1.0,
        sellsCheap     = table.concat(sells, ", "),
        buysHigh       = table.concat(buys, ", "),
        priceBand      = trimmed,
        truncated      = #band > CAP,
        totalRows      = #band,
    })
end
callable(TraderCodex, "serverGetCodexDetail")

function TraderCodex.serverShowHomeSector(playerIndex, factionId)
    if not onServer() then return end
    local player = Player(playerIndex)
    if not player or not factionId then return end
    local faction = Faction(factionId)
    if not faction then
        invokeClientFunction(player, "clientReceiveHomeSector", nil, nil, "Faction not found")
        return
    end
    local ok, hx, hy = pcall(function()
        return faction:getHomeSectorCoordinates()
    end)
    if not ok or type(hx) ~= "number" or type(hy) ~= "number" then
        -- Try the alternate API name.
        local ok2, home = pcall(function() return faction.homeSector end)
        if ok2 and home then
            invokeClientFunction(player, "clientReceiveHomeSector", home.x, home.y, nil)
            return
        end
        invokeClientFunction(player, "clientReceiveHomeSector", nil, nil, "Home sector unknown")
        return
    end
    invokeClientFunction(player, "clientReceiveHomeSector", hx, hy, nil)
end
callable(TraderCodex, "serverShowHomeSector")

-- ========================================================================
-- Client
-- ========================================================================

if onClient() then

local tab
local listBox
local listSortMode = "faction"   -- one of: faction | economy | specialization | acquired
local listAscending = true
local cachedList = {}
local selectedFactionId

local headerLabel
local sellsLabel
local buysLabel
local commodityLabel
local truncatedLabel
local homeButton
local homeStatusLabel
local emptyStateLabel
local detailContainer
local listContainer

local function starString(spec)
    -- 1..5 stars, ASCII for source-encoding safety.
    if type(spec) ~= "number" then return "..." end
    local n = (spec < 0.60 and 1)
           or (spec < 0.90 and 2)
           or (spec < 1.20 and 3)
           or (spec < 1.50 and 4)
           or 5
    return string.rep("*", n) .. string.rep(".", 5 - n)
end

local function specLabel(spec)
    if type(spec) ~= "number" then return "?" end
    local n = (spec < 0.60 and 1)
           or (spec < 0.90 and 2)
           or (spec < 1.20 and 3)
           or (spec < 1.50 and 4)
           or 5
    return ({"Lightly", "Modestly", "Solidly", "Heavily", "Pure"})[n]
end

local function sortedList()
    local out = {}
    for _, r in ipairs(cachedList) do table.insert(out, r) end
    table.sort(out, function(a, b)
        local av, bv
        if listSortMode == "faction"        then av, bv = a.factionName or "", b.factionName or ""
        elseif listSortMode == "economy"    then av, bv = a.economy or "",     b.economy or ""
        elseif listSortMode == "specialization" then av, bv = a.specialization or 0, b.specialization or 0
        elseif listSortMode == "acquired"   then av, bv = a.acquiredAt or 0,   b.acquiredAt or 0
        else av, bv = a.factionName or "", b.factionName or ""
        end
        if listAscending then return av < bv else return av > bv end
    end)
    return out
end

local function refreshListBox()
    if not listBox then return end
    listBox:clear()
    local rows = sortedList()
    if #rows == 0 then
        if emptyStateLabel then emptyStateLabel:show() end
        return
    end
    if emptyStateLabel then emptyStateLabel:hide() end
    for _, r in ipairs(rows) do
        local stars   = starString(r.specialization)
        local row = string.format(
            "%-26s  %-13s  %-7s  Sells: %-22s  Buys: %s",
            string.sub(r.factionName or "?", 1, 26),
            string.sub(r.economy or "?", 1, 13),
            stars,
            string.sub(r.sellsCheap or "(none)", 1, 22),
            r.buysHigh or "(none)")
        listBox:addEntry(row)
        -- store factionId on the entry index for later retrieval
        -- (ListBox stores by integer index)
    end
end

local function setSort(mode)
    if listSortMode == mode then
        listAscending = not listAscending
    else
        listSortMode = mode
        listAscending = true
    end
    refreshListBox()
end

function TraderCodex.onSortByFaction()        setSort("faction") end
function TraderCodex.onSortByEconomy()        setSort("economy") end
function TraderCodex.onSortBySpecialization() setSort("specialization") end
function TraderCodex.onSortByAcquired()       setSort("acquired") end
function TraderCodex.onRefreshPressed()
    invokeServerFunction("serverGetCodexList", Player().index)
end

function TraderCodex.onListEntrySelected()
    if not listBox then return end
    local idx = listBox.selectedIndex
    if not idx or idx < 0 then return end
    local rows = sortedList()
    local row = rows[idx + 1]  -- 0-indexed
    if not row then return end
    selectedFactionId = row.factionId
    invokeServerFunction("serverGetCodexDetail", Player().index, row.factionId)
end

function TraderCodex.onHomeSectorPressed()
    if not selectedFactionId then return end
    invokeServerFunction("serverShowHomeSector", Player().index, selectedFactionId)
end

function TraderCodex.clientReceiveCodexList(list)
    cachedList = (type(list) == "table") and list or {}
    refreshListBox()
    -- Clear detail panel when list refreshes.
    if headerLabel    then headerLabel.caption = "Select a Faction Survey from the list above." end
    if sellsLabel     then sellsLabel.caption = "" end
    if buysLabel      then buysLabel.caption = "" end
    if commodityLabel then commodityLabel.caption = "" end
    if truncatedLabel then truncatedLabel.caption = "" end
    if homeStatusLabel then homeStatusLabel.caption = "" end
    if homeButton     then homeButton.active = false end
end

function TraderCodex.clientReceiveCodexDetail(payload)
    if not headerLabel or type(payload) ~= "table" then return end
    local stars = starString(payload.specialization)
    local lbl   = specLabel(payload.specialization)
    headerLabel.caption = string.format(
        "%s\n%s Economy  %s  (%s)",
        tostring(payload.factionName or "?"),
        tostring(payload.economy or "?"), stars, lbl)
    sellsLabel.caption = "Sells cheap: " ..
        ((payload.sellsCheap ~= "" and payload.sellsCheap) or "(none)")
    buysLabel.caption  = "Buys high  : " ..
        ((payload.buysHigh   ~= "" and payload.buysHigh)   or "(none)")

    local lines = {}
    table.insert(lines, string.format(
        "%-22s %12s %12s", "Commodity", "Galactic Avg", "Faction Avg"))
    table.insert(lines, string.rep("-", 50))
    for _, row in ipairs(payload.priceBand or {}) do
        table.insert(lines, string.format("%-22s %12d %12d",
            string.sub(row.name, 1, 22), row.vanilla, row.expected))
    end
    if #payload.priceBand == 0 then
        table.insert(lines, "(no biased commodities for this Economy/Specialization)")
    end
    commodityLabel.caption = table.concat(lines, "\n")

    if payload.truncated then
        truncatedLabel.caption = string.format(
            "(showing top %d of %d biased commodities)",
            #payload.priceBand, payload.totalRows)
    else
        truncatedLabel.caption = ""
    end

    if homeButton then homeButton.active = true end
    if homeStatusLabel then homeStatusLabel.caption = "" end
end

function TraderCodex.clientReceiveHomeSector(x, y, err)
    if err then
        if homeStatusLabel then homeStatusLabel.caption = tostring(err) end
        return
    end
    if type(x) ~= "number" or type(y) ~= "number" then
        if homeStatusLabel then homeStatusLabel.caption = "Home sector unknown" end
        return
    end
    if homeStatusLabel then
        homeStatusLabel.caption = string.format("Home sector: (%d, %d) - opening map...", x, y)
    end
    local ok = pcall(function()
        GalaxyMap():show(x, y)
    end)
    if not ok and homeStatusLabel then
        homeStatusLabel.caption = string.format("Home sector: (%d, %d)", x, y)
    end
end

local function buildTab()
    tab = PlayerWindow():createTab(
        "Trader's Codex"%_t,
        "data/textures/icons/pixel/trade.png",
        "Trader's Codex - Faction Surveys"%_t)

    local size = tab.size
    local pad  = 10
    local inner = Rect(vec2(pad, pad), vec2(size.x - pad, size.y - pad))

    -- Sort row across the top
    local sortBarHeight = 30
    local sortBarRect = Rect(inner.lower,
        vec2(inner.upper.x, inner.lower.y + sortBarHeight))
    local btnW = 130
    local x = sortBarRect.lower.x
    local y = sortBarRect.lower.y
    tab:createButton(Rect(vec2(x,           y), vec2(x +         btnW, y + 28)),
        "Sort: Faction"%_t,        "onSortByFaction")
    tab:createButton(Rect(vec2(x + btnW * 1 + 6, y), vec2(x + btnW * 2 + 6, y + 28)),
        "Sort: Economy"%_t,        "onSortByEconomy")
    tab:createButton(Rect(vec2(x + btnW * 2 + 12, y), vec2(x + btnW * 3 + 12, y + 28)),
        "Sort: Specialization"%_t, "onSortBySpecialization")
    tab:createButton(Rect(vec2(x + btnW * 3 + 18, y), vec2(x + btnW * 4 + 18, y + 28)),
        "Sort: Acquired"%_t,       "onSortByAcquired")
    tab:createButton(Rect(vec2(x + btnW * 4 + 30, y), vec2(x + btnW * 4 + 110, y + 28)),
        "Refresh"%_t,              "onRefreshPressed")

    -- Split below sort bar: list (top half) / detail (bottom half)
    local belowSortLower = inner.lower.y + sortBarHeight + 10
    local listH = math.floor((inner.upper.y - belowSortLower) * 0.45)

    local listRect = Rect(
        vec2(inner.lower.x, belowSortLower),
        vec2(inner.upper.x, belowSortLower + listH))
    local detailLower = belowSortLower + listH + 10
    local detailRect = Rect(
        vec2(inner.lower.x, detailLower),
        vec2(inner.upper.x, inner.upper.y))

    listBox = tab:createListBox(listRect)
    listBox.onSelectFunction = "onListEntrySelected"

    emptyStateLabel = tab:createLabel(listRect,
        "Visit any Trading Post and use the Quantum Trading AI to acquire your first Faction Survey.", 14)
    emptyStateLabel.wordBreak = true
    emptyStateLabel:hide()

    -- Detail panel layout:
    --   header        : 60 tall
    --   sells/buys    : 22 + 22
    --   commodity     : remaining minus button
    --   homeStatus    : 22
    --   homeButton    : 32 tall at bottom
    local dx = detailRect.lower.x
    local dyTop = detailRect.lower.y
    local dyBot = detailRect.upper.y
    local dw    = detailRect.upper.x - detailRect.lower.x

    headerLabel = tab:createLabel(
        Rect(vec2(dx, dyTop), vec2(dx + dw, dyTop + 60)),
        "Select a Faction Survey from the list above.", 16)
    headerLabel.wordBreak = true

    sellsLabel = tab:createLabel(
        Rect(vec2(dx, dyTop + 66), vec2(dx + dw, dyTop + 88)), "", 13)
    buysLabel = tab:createLabel(
        Rect(vec2(dx, dyTop + 90), vec2(dx + dw, dyTop + 112)), "", 13)

    local commodityTop    = dyTop + 120
    local homeButtonTop   = dyBot - 36
    local homeStatusTop   = homeButtonTop - 24
    local truncatedTop    = homeStatusTop - 22

    commodityLabel = tab:createLabel(
        Rect(vec2(dx, commodityTop), vec2(dx + dw, truncatedTop - 4)),
        "", 12)
    commodityLabel.wordBreak = true

    truncatedLabel = tab:createLabel(
        Rect(vec2(dx, truncatedTop), vec2(dx + dw, truncatedTop + 20)),
        "", 12)

    homeStatusLabel = tab:createLabel(
        Rect(vec2(dx, homeStatusTop), vec2(dx + dw, homeStatusTop + 20)),
        "", 12)

    homeButton = tab:createButton(
        Rect(vec2(dx, homeButtonTop), vec2(dx + 260, homeButtonTop + 32)),
        "Show Home Sector on Map"%_t, "onHomeSectorPressed")
    homeButton.active = false

    listContainer = listRect
    detailContainer = detailRect
end

function TraderCodex.initialize()
    buildTab()
    invokeServerFunction("serverGetCodexList", Player().index)
end

-- A simple manual refresh path: re-fetch the list. Called by external
-- triggers (e.g. when a new Faction Survey is acquired at a Trading Post).
function TraderCodex.clientRefreshList()
    invokeServerFunction("serverGetCodexList", Player().index)
end

end -- onClient
