-- Trader's Codex - player-menu tab listing all acquired Faction Surveys.
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

    local trimmed = {}
    local CAP = 60
    for i = 1, math.min(CAP, #band) do
        local r = band[i]
        table.insert(trimmed, {
            name       = r.name,
            vanilla    = math.floor(r.vanilla),
            expected   = math.floor(r.expected),
            tag        = r.tag,
            multiplier = r.multiplier,   -- raw (specialization-adjusted) bias multiplier
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
local surveyList            -- ListBoxEx of acquired Faction Surveys
local commodityList         -- ListBoxEx of the selected Survey's commodities
local sortCombo             -- vanilla-style sort dropdown
local listSortMode = 1      -- combo index (1 = Faction A-Z default; see SORT_OPTIONS)
local cachedList = {}
local sortedRows = {}       -- mirrors current visible row order so index lookup works
local selectedFactionId

local headerLabel
local sellsLabel
local buysLabel
local truncatedLabel
local homeButton
local homeStatusLabel
local emptyStateLabel

local function starString(spec)
    if type(spec) ~= "number" then return "....." end
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

-- Sort options shown in the dropdown. Order here MUST match `addEntry` order
-- in `buildTab`. Each entry has a label (for display) and a comparator.
local SORT_OPTIONS = {
    { label = "Faction Name (A-Z)",
      cmp = function(a, b) return (a.factionName or "") < (b.factionName or "") end },
    { label = "Faction Name (Z-A)",
      cmp = function(a, b) return (a.factionName or "") > (b.factionName or "") end },
    { label = "Economy (A-Z)",
      cmp = function(a, b) return (a.economy or "")     < (b.economy or "")     end },
    { label = "Specialization (high to low)",
      cmp = function(a, b) return (a.specialization or 0) > (b.specialization or 0) end },
    { label = "Specialization (low to high)",
      cmp = function(a, b) return (a.specialization or 0) < (b.specialization or 0) end },
    { label = "Date Acquired (newest first)",
      cmp = function(a, b) return (a.acquiredAt or 0)  > (b.acquiredAt or 0)  end },
    { label = "Date Acquired (oldest first)",
      cmp = function(a, b) return (a.acquiredAt or 0)  < (b.acquiredAt or 0)  end },
}

local function computeSortedList()
    local out = {}
    for _, r in ipairs(cachedList) do table.insert(out, r) end
    local opt = SORT_OPTIONS[listSortMode] or SORT_OPTIONS[1]
    table.sort(out, opt.cmp)
    return out
end

local function refreshListBox()
    if not surveyList then return end
    -- Clear all rows
    while surveyList.rows > 0 do surveyList:removeRow(surveyList.rows - 1) end

    sortedRows = computeSortedList()
    if #sortedRows == 0 then
        if emptyStateLabel then emptyStateLabel:show() end
        return
    end
    if emptyStateLabel then emptyStateLabel:hide() end

    for _, r in ipairs(sortedRows) do
        surveyList:addRow()
        local idx = surveyList.rows - 1
        local white = ColorRGB(1, 1, 1)
        surveyList:setEntry(0, idx, tostring(r.factionName or "?"), false, false, white)
        surveyList:setEntry(1, idx, tostring(r.economy     or "?"), false, false, white)
        surveyList:setEntry(2, idx, starString(r.specialization),   false, false, white)
        surveyList:setEntry(3, idx,
            ((r.sellsCheap or "") ~= "" and r.sellsCheap) or "(none)",
            false, false, white)
        surveyList:setEntry(4, idx,
            ((r.buysHigh or "") ~= "" and r.buysHigh) or "(none)",
            false, false, white)
    end
end

function TraderCodex.onSortChanged()
    if not sortCombo then return end
    local sel = sortCombo.selectedIndex
    if type(sel) == "number" then
        -- ComboBox is 0-indexed; SORT_OPTIONS is 1-indexed.
        listSortMode = sel + 1
    end
    refreshListBox()
end

function TraderCodex.onRefreshPressed()
    invokeServerFunction("serverGetCodexList", Player().index)
end

-- ListBoxEx fires onSelectFunction with (index, value). Index is 0-based.
function TraderCodex.onSurveyRowSelected(index, value)
    if type(index) ~= "number" then return end
    local row = sortedRows[index + 1]
    if not row then return end
    selectedFactionId = row.factionId
    invokeServerFunction("serverGetCodexDetail", Player().index, row.factionId)
end

function TraderCodex.onHomeSectorPressed()
    if not selectedFactionId then return end
    invokeServerFunction("serverShowHomeSector", Player().index, selectedFactionId)
end

local function clearCommodityTable()
    if not commodityList then return end
    while commodityList.rows > 0 do commodityList:removeRow(commodityList.rows - 1) end
end

function TraderCodex.clientReceiveCodexList(list)
    cachedList = (type(list) == "table") and list or {}
    refreshListBox()
    if headerLabel    then headerLabel.caption = "Select a Faction Survey from the list above." end
    if sellsLabel     then sellsLabel.caption = "" end
    if buysLabel      then buysLabel.caption = "" end
    if truncatedLabel then truncatedLabel.caption = "" end
    if homeStatusLabel then homeStatusLabel.caption = "" end
    if homeButton     then homeButton.active = false end
    clearCommodityTable()
end

function TraderCodex.clientReceiveCodexDetail(payload)
    if not headerLabel or type(payload) ~= "table" then return end
    local stars = starString(payload.specialization)
    local lbl   = specLabel(payload.specialization)
    headerLabel.caption = string.format(
        "%s   :   %s Economy   %s   (%s)",
        tostring(payload.factionName or "?"),
        tostring(payload.economy or "?"), stars, lbl)
    sellsLabel.caption = "Sells cheap : " ..
        ((payload.sellsCheap ~= "" and payload.sellsCheap) or "(none)")
    buysLabel.caption  = "Buys high   : " ..
        ((payload.buysHigh   ~= "" and payload.buysHigh)   or "(none)")

    clearCommodityTable()
    local white = ColorRGB(1, 1, 1)
    for _, row in ipairs(payload.priceBand or {}) do
        commodityList:addRow()
        local idx = commodityList.rows - 1
        commodityList:setEntry(0, idx, tostring(row.name), false, false, white)
        commodityList:setEntry(1, idx, tostring(row.vanilla),  false, false, white)
        commodityList:setEntry(2, idx, tostring(row.expected), false, false, white)
        -- Per-row tooltip: full name + tag + multiplier + credit delta.
        local mult  = tonumber(row.multiplier) or 1.0
        local delta = (tonumber(row.expected) or 0) - (tonumber(row.vanilla) or 0)
        local deltaText = (delta >= 0 and string.format("+%d cr", delta))
                       or string.format("%d cr", delta)
        local tooltip = string.format(
            "%s\nTag category: %s\nFaction multiplier: x%.2f\nGalactic Avg: %d cr\nFaction Avg:  %d cr\nDelta:        %s",
            tostring(row.name),
            tostring(row.tag or "?"),
            mult,
            tonumber(row.vanilla) or 0,
            tonumber(row.expected) or 0,
            deltaText)
        commodityList:setEntryTooltip(0, idx, tooltip)
        commodityList:setEntryTooltip(1, idx, tooltip)
        commodityList:setEntryTooltip(2, idx, tooltip)
    end

    if payload.truncated then
        truncatedLabel.caption = string.format(
            "(showing top %d of %d biased commodities)",
            #(payload.priceBand or {}), payload.totalRows or 0)
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
    local ok = pcall(function() GalaxyMap():show(x, y) end)
    if not ok then
        -- Map call failed; surface the coords so the player can navigate manually.
        if homeStatusLabel then
            homeStatusLabel.caption = string.format("Home sector: (%d, %d)", x, y)
        end
    else
        -- Map opened successfully; the transient "opening map" status would
        -- otherwise linger here forever when the player returns to the codex.
        if homeStatusLabel then homeStatusLabel.caption = "" end
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

    -- Sort bar: vanilla-style "Sort by: [combo]" + Refresh
    local sortBarH = 30
    local x, y = inner.lower.x, inner.lower.y
    tab:createLabel(Rect(vec2(x, y + 4), vec2(x + 70, y + 28)),
        "Sort by:", 14)
    sortCombo = tab:createComboBox(
        Rect(vec2(x + 80, y), vec2(x + 80 + 320, y + 28)),
        "onSortChanged")
    for _, opt in ipairs(SORT_OPTIONS) do
        sortCombo:addEntry(opt.label)
    end
    sortCombo.selectedIndex = 0   -- "Faction Name (A-Z)"

    tab:createButton(
        Rect(vec2(x + 80 + 320 + 12, y), vec2(x + 80 + 320 + 92, y + 28)),
        "Refresh"%_t, "onRefreshPressed")

    -- Below sort bar: column headers row, then survey list, then detail panel
    local belowSort = inner.lower.y + sortBarH + 10
    local surveyHeaderH = 22
    local listW = inner.upper.x - inner.lower.x
    local lc0 = math.floor(listW * 0.25)   -- Faction
    local lc1 = math.floor(listW * 0.12)   -- Economy
    local lc2 = math.floor(listW * 0.08)   -- Spec stars
    local lc3 = math.floor(listW * 0.25)   -- Sells low
    local lc4 = listW - (lc0 + lc1 + lc2 + lc3)  -- Buys high

    -- Survey list column headers
    local lhx = inner.lower.x
    local function surveyHeader(label, w)
        tab:createLabel(Rect(vec2(lhx, belowSort), vec2(lhx + w, belowSort + surveyHeaderH)),
            label, 13)
        lhx = lhx + w
    end
    surveyHeader("Faction",         lc0)
    surveyHeader("Economy",         lc1)
    surveyHeader("Spec",            lc2)
    surveyHeader("Sells low",       lc3)
    surveyHeader("Buys high",       lc4)

    local listTop  = belowSort + surveyHeaderH + 4
    local listH    = math.floor((inner.upper.y - listTop) * 0.4)
    local listRect = Rect(vec2(inner.lower.x, listTop),
                          vec2(inner.upper.x, listTop + listH))
    local detailTop = listTop + listH + 10
    local detailRect = Rect(vec2(inner.lower.x, detailTop),
                            vec2(inner.upper.x, inner.upper.y))

    -- Surveys list (ListBoxEx with 5 columns)
    surveyList = tab:createListBoxEx(listRect)
    surveyList.columns = 5
    surveyList.rowHeight = 22
    surveyList:setColumnWidth(0, lc0)
    surveyList:setColumnWidth(1, lc1)
    surveyList:setColumnWidth(2, lc2)
    surveyList:setColumnWidth(3, lc3)
    surveyList:setColumnWidth(4, lc4)
    surveyList.onSelectFunction = "onSurveyRowSelected"

    emptyStateLabel = tab:createLabel(listRect,
        "Visit any Trading Post and use the Quantum Trading AI to acquire your first Faction Survey.", 14)
    emptyStateLabel.wordBreak = true
    emptyStateLabel:hide()

    -- Detail panel: header, sells/buys lines, commodity table, status + button
    local dx, dyTop, dyBot = detailRect.lower.x, detailRect.lower.y, detailRect.upper.y
    local dw = detailRect.upper.x - detailRect.lower.x

    headerLabel = tab:createLabel(
        Rect(vec2(dx, dyTop), vec2(dx + dw, dyTop + 30)),
        "Select a Faction Survey from the list above.", 16)

    sellsLabel = tab:createLabel(
        Rect(vec2(dx, dyTop + 36), vec2(dx + dw, dyTop + 56)), "", 13)
    buysLabel  = tab:createLabel(
        Rect(vec2(dx, dyTop + 58), vec2(dx + dw, dyTop + 78)), "", 13)

    -- Bottom-anchored controls
    local btnH = 32
    local homeButtonTop = dyBot - btnH
    local homeStatusTop = homeButtonTop - 24
    local truncatedTop  = homeStatusTop - 20

    -- Commodity table area = headers row + scrollable list
    local commodityHeaderTop = dyTop + 86
    local commodityHeaderBot = commodityHeaderTop + 20
    local commodityTop       = commodityHeaderBot + 4
    local commodityBottom    = truncatedTop - 6

    local cw0 = math.floor(dw * 0.50)
    local cw1 = math.floor(dw * 0.25)
    local cw2 = dw - (cw0 + cw1)

    -- Column headers
    local hx = dx
    tab:createLabel(Rect(vec2(hx, commodityHeaderTop), vec2(hx + cw0, commodityHeaderBot)),
        "Commodity", 13)
    hx = hx + cw0
    tab:createLabel(Rect(vec2(hx, commodityHeaderTop), vec2(hx + cw1, commodityHeaderBot)),
        "Galactic Avg", 13)
    hx = hx + cw1
    tab:createLabel(Rect(vec2(hx, commodityHeaderTop), vec2(hx + cw2, commodityHeaderBot)),
        "Faction Avg", 13)

    commodityList = tab:createListBoxEx(
        Rect(vec2(dx, commodityTop), vec2(dx + dw, commodityBottom)))
    commodityList.columns = 3
    commodityList.rowHeight = 20
    commodityList:setColumnWidth(0, cw0)
    commodityList:setColumnWidth(1, cw1)
    commodityList:setColumnWidth(2, cw2)

    truncatedLabel = tab:createLabel(
        Rect(vec2(dx, truncatedTop), vec2(dx + dw, truncatedTop + 18)), "", 12)
    homeStatusLabel = tab:createLabel(
        Rect(vec2(dx, homeStatusTop), vec2(dx + dw, homeStatusTop + 20)), "", 12)
    homeButton = tab:createButton(
        Rect(vec2(dx, homeButtonTop), vec2(dx + 260, homeButtonTop + btnH)),
        "Show Home Sector on Map"%_t, "onHomeSectorPressed")
    homeButton.active = false
end

function TraderCodex.initialize()
    buildTab()
    invokeServerFunction("serverGetCodexList", Player().index)
end

function TraderCodex.clientRefreshList()
    invokeServerFunction("serverGetCodexList", Player().index)
end

end -- onClient
