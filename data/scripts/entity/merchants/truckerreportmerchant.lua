-- Quantum Trading AI - the at-Trading-Post analytics merchant.
--
-- v0.3.0: tabbed window. Two tabs:
--   * Best Prices  -- per-commodity best buy / best sell with margin
--   * Trade Routes -- canonical sector-pair round-trip loops
--
-- Both tabs unlocked by a single Trade Report payment (1-hour validity).
-- Faction Survey acquisition is gated behind running the Trade Report.
--
-- File path stays at .../truckerreportmerchant.lua so the attach calls
-- from tradingpost.lua / headquarters.lua overlays do not change.
package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")
include("faction")
include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace QuantumTradeAI
QuantumTradeAI = {}

function QuantumTradeAI.interactionPossible(playerIndex, option)
    return true
end

function QuantumTradeAI.initialize()
    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/trade.png"
    end
end

-- =========================================================================
-- Server
-- =========================================================================

local function relativeAge(now, ts)
    local diff = math.max(0, (now or 0) - (ts or 0))
    if diff < 60          then return string.format("%ds ago", math.floor(diff)) end
    if diff < 3600        then return string.format("%dm ago", math.floor(diff / 60)) end
    if diff < 3600 * 24   then return string.format("%dh ago", math.floor(diff / 3600)) end
    return string.format("%dd ago", math.floor(diff / 86400))
end

local function canAfford(player, price)
    local ok, can = pcall(function() return player:canPayMoney(price) end)
    if ok and can ~= nil then return can end
    return (player.money or 0) >= price
end

-- Build Best Prices rows. Includes both cell text and per-cell tooltip text.
local function buildBestPricesRows(player)
    local TruckerReports = include("truckerreports")
    local stats = TruckerReports.computeObservationStats(player)
    local now = (Server and Server() and Server().unpausedRuntime) or os.time()

    local rows = {}
    for _, o in ipairs(stats) do
        local bestBuyText, bestSellText, marginText = "--", "--", "--"
        local buyTip, sellTip, marginTip = "", "", ""
        local marginValue = nil

        if o.buyStats and o.bestBuy then
            bestBuyText = string.format("%d cr  @  %s (%d,%d)  %s",
                o.bestBuy.price or 0,
                tostring(o.bestBuy.stationName or "?"),
                o.bestBuy.sectorX or 0, o.bestBuy.sectorY or 0,
                relativeAge(now, o.bestBuy.timestamp))
            buyTip = string.format(
                "%s\nBest buy: %d cr\nStation: %s\nSector: (%d, %d)\nObserved: %s\nObservation count: %d\nRange: %d - %d",
                tostring(o.commodity),
                o.bestBuy.price or 0,
                tostring(o.bestBuy.stationName or "?"),
                o.bestBuy.sectorX or 0, o.bestBuy.sectorY or 0,
                relativeAge(now, o.bestBuy.timestamp),
                o.buyStats.count, o.buyStats.min, o.buyStats.max)
        end
        if o.sellStats and o.bestSell then
            bestSellText = string.format("%d cr  @  %s (%d,%d)  %s",
                o.bestSell.price or 0,
                tostring(o.bestSell.stationName or "?"),
                o.bestSell.sectorX or 0, o.bestSell.sectorY or 0,
                relativeAge(now, o.bestSell.timestamp))
            sellTip = string.format(
                "%s\nBest sell: %d cr\nStation: %s\nSector: (%d, %d)\nObserved: %s\nObservation count: %d\nRange: %d - %d",
                tostring(o.commodity),
                o.bestSell.price or 0,
                tostring(o.bestSell.stationName or "?"),
                o.bestSell.sectorX or 0, o.bestSell.sectorY or 0,
                relativeAge(now, o.bestSell.timestamp),
                o.sellStats.count, o.sellStats.min, o.sellStats.max)
        end
        if o.bestBuy and o.bestSell and o.bestBuy.price and o.bestSell.price then
            marginValue = (o.bestSell.price or 0) - (o.bestBuy.price or 0)
            if marginValue >= 0 then
                marginText = string.format("+%d cr", marginValue)
            else
                marginText = string.format("%d cr", marginValue)
            end
            marginTip = string.format(
                "%s\nPer-unit margin: %s\n(best sell %d cr - best buy %d cr)",
                tostring(o.commodity), marginText,
                o.bestSell.price or 0, o.bestBuy.price or 0)
        end

        table.insert(rows, {
            commodity     = o.commodity,
            buy           = bestBuyText,
            sell          = bestSellText,
            margin        = marginText,
            marginNum     = marginValue,
            bestBuyNum    = (o.bestBuy  and o.bestBuy.price)  or nil,
            bestSellNum   = (o.bestSell and o.bestSell.price) or nil,
            commodityTip  = string.format("%s\n%s", tostring(o.commodity),
                                          (buyTip ~= "" or sellTip ~= "")
                                              and "Hover Best Buy or Best Sell for station detail."
                                              or "No observations yet."),
            buyTip        = buyTip,
            sellTip       = sellTip,
            marginTip     = marginTip,
        })
    end
    return rows
end

-- Build Trade Routes rows. One row per canonical sector pair with both legs
-- profitable. Each row carries cell text + rich tooltips.
local function buildRouteRows(player)
    local TruckerReports = include("truckerreports")
    local raw = TruckerReports.computeRoundTripRoutes(player)
    local now = (Server and Server() and Server().unpausedRuntime) or os.time()

    local function fmtLeg(leg)
        local cell = string.format("%s  S:%d / D:%d  +%d/u",
            tostring(leg.commodity or "?"), leg.buyStock or 0, leg.sellDemand or 0,
            leg.perUnitProfit or 0)
        local tip = string.format(
            "%s\nBuy at:    %s\nSell at:   %s\nStock at buyer:    %d\nDemand at seller:  %d\nPer-unit profit:   +%d cr\nTrip cap (units):  %d\nTrip profit:       +%d cr\nObserved buy:  %s\nObserved sell: %s",
            tostring(leg.commodity or "?"),
            tostring(leg.buyStation or "?"),
            tostring(leg.sellStation or "?"),
            leg.buyStock or 0, leg.sellDemand or 0,
            leg.perUnitProfit or 0, leg.tripCap or 0, leg.tripProfit or 0,
            relativeAge(now, leg.buyTimestamp),
            relativeAge(now, leg.sellTimestamp))
        return cell, tip
    end

    local rows = {}
    for _, r in ipairs(raw) do
        local outCell, outTip   = fmtLeg(r.outbound)
        local backCell, backTip = fmtLeg(r.backhaul)
        table.insert(rows, {
            fromText    = string.format("(%d,%d)", r.fromX, r.fromY),
            toText      = string.format("(%d,%d)", r.toX,   r.toY),
            fromX       = r.fromX, fromY = r.fromY,
            toX         = r.toX,   toY   = r.toY,
            distance    = r.distance or 0,
            outCell     = outCell,
            outTip      = outTip,
            outProfit   = r.outbound.tripProfit or 0,
            outProfitText  = string.format("+%d cr", r.outbound.tripProfit or 0),
            backCell    = backCell,
            backTip     = backTip,
            backProfit  = r.backhaul.tripProfit or 0,
            backProfitText = string.format("+%d cr", r.backhaul.tripProfit or 0),
            roundTrip   = r.roundTripProfit or 0,
            roundTripText  = string.format("+%d cr", r.roundTripProfit or 0),
        })
    end
    return rows
end

function QuantumTradeAI.serverGetTradeReportMeta(playerIndex)
    if not onServer() then return end
    local TruckerReports = include("truckerreports")
    local player = Player(playerIndex)
    if not player then return end

    local subject = Faction()
    local subjectName = subject and tostring(subject.name) or "?"
    local owns        = subject and TruckerReports.ownsSurveyFor(player, subject.index) or false
    local surveyPrice = subject and TruckerReports.priceFor(subject) or 0
    local fee         = TruckerReports.TRADE_REPORT_FEE or 0
    local valid, remaining = TruckerReports.tradeReportValidity(player)

    invokeClientFunction(player, "clientReceiveTradeReportMeta",
        subjectName, fee, surveyPrice, owns, valid, remaining)
end
callable(QuantumTradeAI, "serverGetTradeReportMeta")

function QuantumTradeAI.serverRunTradeReport(playerIndex)
    if not onServer() then return end
    local TruckerReports = include("truckerreports")
    local player = Player(playerIndex)
    if not player then return end

    local valid, _ = TruckerReports.tradeReportValidity(player)
    if not valid then
        local fee = TruckerReports.TRADE_REPORT_FEE or 0
        if fee > 0 and not player.infiniteResources then
            if not canAfford(player, fee) then
                player:sendChatMessage("Quantum Trading AI", 0,
                    "Insufficient credits. Trade Report costs %d cr."%_t, fee)
                invokeClientFunction(player, "clientReceiveTradeReportRefused", fee)
                return
            end
            player:pay("Paid Quantum Trading AI"%_t, fee)
        end
        TruckerReports.markTradeReportPaid(player)
    end

    local priceRows = buildBestPricesRows(player)
    local routeRows = buildRouteRows(player)
    local _, remaining = TruckerReports.tradeReportValidity(player)
    invokeClientFunction(player, "clientReceiveTradeReportRows",
        priceRows, routeRows, remaining or 0)
end
callable(QuantumTradeAI, "serverRunTradeReport")

function QuantumTradeAI.serverAcquireFactionSurvey(playerIndex)
    if not onServer() then return end
    local TruckerReports    = include("truckerreports")
    local TruckerExcluded   = include("truckerexcluded")
    local TruckerAssign     = include("truckerassignarchetypes")
    local TruckerArchetypes = include("truckerarchetypes")
    local TruckerLog        = include("truckerlog")

    local player  = Player(playerIndex)
    local subject = Faction()
    if not player or not subject then return end
    if TruckerExcluded.isExcluded(subject) then return end
    TruckerAssign.ensureAssigned(subject)
    local economy = subject:getValue("trucker_archetype")
    if not economy or not TruckerArchetypes.isValid(economy) then return end

    local price = TruckerReports.priceFor(subject)
    if not player.infiniteResources then
        if not canAfford(player, price) then
            player:sendChatMessage("Quantum Trading AI", 0,
                "Insufficient credits. Faction Survey costs %d cr."%_t, price)
            return
        end
        player:pay("Acquired Faction Survey"%_t, price)
    end

    local entry = TruckerReports.purchase(player, subject)
    if not entry then return end

    player:sendChatMessage("Quantum Trading AI", 0,
        "Filed Faction Survey for %s in your Codex."%_t, subject.name)

    local INTRO_KEY = "trucker_codex_intro_sent"
    if not player:getValue(INTRO_KEY) then
        local body = string.format(
            "Captain,\n\n" ..
            "Your acquisition of intel on %s has been filed in your Trader's Codex.\n" ..
            "Open the Codex any time from your player menu - no need to revisit a Trading Post.\n\n" ..
            "The Codex tracks every Faction Survey you acquire. As your library grows,\n" ..
            "cross-faction comparison becomes a powerful tool for plotting trade routes.\n\n" ..
            "- Quantum Trading AI",
            tostring(subject.name))
        TruckerLog.sendMail(player, "Faction Survey Acquired", body)
        player:setValue(INTRO_KEY, true)
    end

    invokeClientFunction(player, "clientReceiveAcquiredAck", subject.index)
end
callable(QuantumTradeAI, "serverAcquireFactionSurvey")

-- =========================================================================
-- Client (tabbed window: Best Prices | Trade Routes)
-- =========================================================================

local window
local tabbedWindow
local bestPricesTab
local tradeRoutesTab

-- Shared header/CTA elements (live OUTSIDE the tabbed window, in the main container)
local headerLabel
local subtitleLabel
local runReportButton
local validityLabel
local surveyStatusLabel
local acquireButton

-- Best Prices tab elements
local commodityList
local commoditySortCombo
local bpPrePaidLabel
local bpEmptyLabel
local cachedBestPricesRows = {}
local bestPricesSortMode = 1   -- 1 = Commodity A-Z (default)

-- Trade Routes tab elements
local routesList
local routesEmptyLabel
local routesPrePaidLabel
local routesSortCombo

-- Client state
local hasRunReport = false
local lastOwns = false
local lastSurveyPrice = 0
local lastFee = 0
local lastSubjectName = ""
local cachedRouteRows = {}
local routesSortMode = 1   -- 1 = round-trip desc (default)

local function formatDuration(seconds)
    if type(seconds) ~= "number" or seconds <= 0 then return "0s" end
    if seconds < 60 then return string.format("%ds", math.floor(seconds)) end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    if m < 60 then return string.format("%dm %ds", m, s) end
    local h = math.floor(m / 60)
    m = m % 60
    return string.format("%dh %dm", h, m)
end

-- ---------- Best Prices tab ----------

local function sortBestPrices(rows, mode)
    local out = {}
    for _, r in ipairs(rows) do table.insert(out, r) end
    -- Helper: treat missing numeric values as -inf for asc sorts where we
    -- want them at the bottom, or +inf for desc sorts (same idea).
    local sorters = {
        function(a, b) return (a.commodity or "")  < (b.commodity or "")  end,  -- 1
        function(a, b) return (a.commodity or "")  > (b.commodity or "")  end,  -- 2
        function(a, b)                                                            -- 3 margin high->low
            return (a.marginNum or -math.huge) > (b.marginNum or -math.huge)
        end,
        function(a, b)                                                            -- 4 margin low->high
            return (a.marginNum or math.huge) < (b.marginNum or math.huge)
        end,
        function(a, b)                                                            -- 5 best buy low->high
            return (a.bestBuyNum or math.huge) < (b.bestBuyNum or math.huge)
        end,
        function(a, b)                                                            -- 6 best sell high->low
            return (a.bestSellNum or -math.huge) > (b.bestSellNum or -math.huge)
        end,
    }
    table.sort(out, sorters[mode] or sorters[1])
    return out
end

local function setBestPricesRows(rows)
    if not commodityList then return end
    while commodityList.rows > 0 do commodityList:removeRow(commodityList.rows - 1) end
    if not rows or #rows == 0 then return end
    local white = ColorRGB(1, 1, 1)
    for _, r in ipairs(rows) do
        commodityList:addRow()
        local idx = commodityList.rows - 1
        local marginBold = (type(r.marginNum) == "number" and r.marginNum > 0)
        commodityList:setEntry(0, idx, tostring(r.commodity), false, false, white)
        commodityList:setEntry(1, idx, tostring(r.buy),       false, false, white)
        commodityList:setEntry(2, idx, tostring(r.sell),      false, false, white)
        commodityList:setEntry(3, idx, tostring(r.margin), marginBold, false, white)
        if r.commodityTip and r.commodityTip ~= "" then
            commodityList:setEntryTooltip(0, idx, r.commodityTip)
        end
        if r.buyTip and r.buyTip ~= "" then
            commodityList:setEntryTooltip(1, idx, r.buyTip)
        end
        if r.sellTip and r.sellTip ~= "" then
            commodityList:setEntryTooltip(2, idx, r.sellTip)
        end
        if r.marginTip and r.marginTip ~= "" then
            commodityList:setEntryTooltip(3, idx, r.marginTip)
        end
    end
end

function QuantumTradeAI.onBestPricesSortChanged()
    if not commoditySortCombo then return end
    local sel = commoditySortCombo.selectedIndex
    if type(sel) == "number" then
        bestPricesSortMode = sel + 1   -- combo is 0-indexed; sorters 1-indexed
    end
    setBestPricesRows(sortBestPrices(cachedBestPricesRows, bestPricesSortMode))
end

local function buildBestPricesTab(tab)
    local size = tab.size
    local pad  = 10
    local iw   = size.x - pad * 2
    local ih   = size.y - pad * 2
    local ox, oy = pad, pad

    -- Sort row at the top
    local sortRowH = 28
    tab:createLabel(Rect(vec2(ox, oy + 4), vec2(ox + 70, oy + sortRowH)),
        "Sort by:", 13)
    commoditySortCombo = tab:createComboBox(
        Rect(vec2(ox + 80, oy), vec2(ox + 80 + 320, oy + sortRowH)),
        "onBestPricesSortChanged")
    commoditySortCombo:addEntry("Commodity (A-Z)")
    commoditySortCombo:addEntry("Commodity (Z-A)")
    commoditySortCombo:addEntry("Margin (high to low)")
    commoditySortCombo:addEntry("Margin (low to high)")
    commoditySortCombo:addEntry("Best Buy price (low to high)")
    commoditySortCombo:addEntry("Best Sell price (high to low)")
    commoditySortCombo.selectedIndex = 0   -- "Commodity (A-Z)"

    -- Column headers (above the table)
    local headerTop = oy + sortRowH + 8
    local headerH = 22
    local c0w = math.floor(iw * 0.14)
    local c1w = math.floor(iw * 0.36)
    local c2w = math.floor(iw * 0.36)
    local c3w = iw - (c0w + c1w + c2w)
    local hx = ox
    local function header(label, w)
        tab:createLabel(Rect(vec2(hx, headerTop), vec2(hx + w, headerTop + headerH)),
            label, 13)
        hx = hx + w
    end
    header("Commodity", c0w)
    header("Best Buy  (price @ station (sector) age)", c1w)
    header("Best Sell  (price @ station (sector) age)", c2w)
    header("Margin", c3w)

    local tableTop = headerTop + headerH + 4
    local tableBottom = oy + ih
    commodityList = tab:createListBoxEx(
        Rect(vec2(ox, tableTop), vec2(ox + iw, tableBottom)))
    commodityList.columns = 4
    commodityList.rowHeight = 22
    commodityList:setColumnWidth(0, c0w)
    commodityList:setColumnWidth(1, c1w)
    commodityList:setColumnWidth(2, c2w)
    commodityList:setColumnWidth(3, c3w)

    bpPrePaidLabel = tab:createLabel(
        Rect(vec2(ox, tableTop), vec2(ox + iw, tableBottom)), "", 14)
    bpPrePaidLabel.wordBreak = true

    bpEmptyLabel = tab:createLabel(
        Rect(vec2(ox, tableTop), vec2(ox + iw, tableBottom)), "", 14)
    bpEmptyLabel.wordBreak = true
    bpEmptyLabel:hide()
end

-- ---------- Trade Routes tab ----------

local function sortRoutes(rows, mode)
    local out = {}
    for _, r in ipairs(rows) do table.insert(out, r) end
    local sorters = {
        function(a, b) return (a.roundTrip or 0)  > (b.roundTrip or 0)  end,  -- 1
        function(a, b) return (a.roundTrip or 0)  < (b.roundTrip or 0)  end,  -- 2
        function(a, b) return (a.outProfit or 0)  > (b.outProfit or 0)  end,  -- 3
        function(a, b) return (a.backProfit or 0) > (b.backProfit or 0) end,  -- 4
        function(a, b) return (a.distance or 0)   < (b.distance or 0)   end,  -- 5
        function(a, b) return (a.distance or 0)   > (b.distance or 0)   end,  -- 6
        function(a, b)                                                          -- 7  from-sector alpha
            if a.fromX ~= b.fromX then return (a.fromX or 0) < (b.fromX or 0) end
            return (a.fromY or 0) < (b.fromY or 0)
        end,
    }
    table.sort(out, sorters[mode] or sorters[1])
    return out
end

local function setRouteRows(rows)
    if not routesList then return end
    while routesList.rows > 0 do routesList:removeRow(routesList.rows - 1) end
    if not rows or #rows == 0 then return end
    local white = ColorRGB(1, 1, 1)
    for _, r in ipairs(rows) do
        routesList:addRow()
        local idx = routesList.rows - 1
        local boldRT = (r.roundTrip or 0) > 0
        routesList:setEntry(0, idx, r.fromText,       false, false, white)
        routesList:setEntry(1, idx, r.toText,         false, false, white)
        routesList:setEntry(2, idx, r.outCell,        false, false, white)
        routesList:setEntry(3, idx, r.outProfitText,  false, false, white)
        routesList:setEntry(4, idx, r.backCell,       false, false, white)
        routesList:setEntry(5, idx, r.backProfitText, false, false, white)
        routesList:setEntry(6, idx, r.roundTripText,  boldRT, false, white)
        if r.outTip  and r.outTip  ~= "" then routesList:setEntryTooltip(2, idx, r.outTip)  end
        if r.backTip and r.backTip ~= "" then routesList:setEntryTooltip(4, idx, r.backTip) end
    end
end

function QuantumTradeAI.onRoutesSortChanged()
    if not routesSortCombo then return end
    local sel = routesSortCombo.selectedIndex
    if type(sel) == "number" then
        -- ComboBox is 0-indexed; our sorters are 1-indexed.
        routesSortMode = sel + 1
    end
    setRouteRows(sortRoutes(cachedRouteRows, routesSortMode))
end

local function buildTradeRoutesTab(tab)
    local size = tab.size
    local pad  = 10
    local iw   = size.x - pad * 2
    local ih   = size.y - pad * 2
    local ox, oy = pad, pad

    -- Sort combo + label row
    local sortRowH = 28
    tab:createLabel(Rect(vec2(ox, oy + 4), vec2(ox + 70, oy + sortRowH)),
        "Sort by:", 13)
    routesSortCombo = tab:createComboBox(
        Rect(vec2(ox + 80, oy), vec2(ox + 80 + 320, oy + sortRowH)),
        "onRoutesSortChanged")
    routesSortCombo:addEntry("Round-Trip Profit (high to low)")
    routesSortCombo:addEntry("Round-Trip Profit (low to high)")
    routesSortCombo:addEntry("Outbound Profit (high to low)")
    routesSortCombo:addEntry("Backhaul Profit (high to low)")
    routesSortCombo:addEntry("Distance (shortest first)")
    routesSortCombo:addEntry("Distance (longest first)")
    routesSortCombo:addEntry("From Sector (alphabetical)")
    routesSortCombo.selectedIndex = 0

    -- Column headers
    local headerTop = oy + sortRowH + 8
    local headerH = 22
    local c0w = math.floor(iw * 0.08)   -- From
    local c1w = math.floor(iw * 0.08)   -- To
    local c2w = math.floor(iw * 0.24)   -- Outbound
    local c3w = math.floor(iw * 0.11)   -- Out Profit
    local c4w = math.floor(iw * 0.24)   -- Backhaul
    local c5w = math.floor(iw * 0.11)   -- Back Profit
    local c6w = iw - (c0w + c1w + c2w + c3w + c4w + c5w)  -- Round-Trip
    local hx = ox
    local function header(label, w)
        tab:createLabel(Rect(vec2(hx, headerTop), vec2(hx + w, headerTop + headerH)), label, 13)
        hx = hx + w
    end
    header("From", c0w)
    header("To",   c1w)
    header("Outbound  (commodity  S:stock/D:demand  +/u)", c2w)
    header("Out Profit", c3w)
    header("Backhaul  (commodity  S:stock/D:demand  +/u)", c4w)
    header("Back Profit", c5w)
    header("Round-Trip", c6w)

    local tableTop = headerTop + headerH + 4
    local tableBottom = oy + ih
    routesList = tab:createListBoxEx(
        Rect(vec2(ox, tableTop), vec2(ox + iw, tableBottom)))
    routesList.columns = 7
    routesList.rowHeight = 22
    routesList:setColumnWidth(0, c0w)
    routesList:setColumnWidth(1, c1w)
    routesList:setColumnWidth(2, c2w)
    routesList:setColumnWidth(3, c3w)
    routesList:setColumnWidth(4, c4w)
    routesList:setColumnWidth(5, c5w)
    routesList:setColumnWidth(6, c6w)

    routesPrePaidLabel = tab:createLabel(
        Rect(vec2(ox, tableTop), vec2(ox + iw, tableBottom)),
        "Run the Trade Report to discover round-trip loops between sectors you have observations for.", 14)
    routesPrePaidLabel.wordBreak = true

    routesEmptyLabel = tab:createLabel(
        Rect(vec2(ox, tableTop), vec2(ox + iw, tableBottom)),
        "Visit more sectors with a Trading System equipped and record observations on BOTH buy and sell sides to discover round-trip loops.", 14)
    routesEmptyLabel.wordBreak = true
    routesEmptyLabel:hide()
end

-- ---------- Shared CTA state ----------

local function updateAcquireButtonState()
    if not acquireButton then return end
    if lastOwns then
        if surveyStatusLabel then
            surveyStatusLabel.caption = string.format(
                "Faction Survey for %s : on file in your Codex.", lastSubjectName)
        end
        acquireButton.caption = "Faction Survey owned"
        acquireButton.active  = false
        return
    end
    if not hasRunReport then
        if surveyStatusLabel then
            surveyStatusLabel.caption = "Run the Trade Report above to unlock Faction Survey acquisition."
        end
        acquireButton.caption = string.format(
            "Acquire Faction Survey  -  %d cr", lastSurveyPrice)
        acquireButton.active = false
        return
    end
    if surveyStatusLabel then
        surveyStatusLabel.caption = string.format(
            "Save a permanent Faction Survey for %s to keep its economic profile in your Codex.",
            lastSubjectName)
    end
    acquireButton.caption = string.format(
        "Acquire Faction Survey  -  %d cr", lastSurveyPrice)
    acquireButton.active = true
end

-- ---------- Lifecycle ----------

function QuantumTradeAI.initUI()
    if not onClient() then return end

    local res  = getResolution()
    local size = vec2(950, 640)
    local menu = ScriptUI()
    window = menu:createWindow(Rect((res - size) * 0.5, (res + size) * 0.5))
    menu:registerWindow(window, "Quantum Trading AI"%_t)
    window.caption        = "Quantum Trading AI"%_t
    window.showCloseButton = 1
    window.moveable        = 1

    local pad = 15
    local iw  = size.x - pad * 2
    local ih  = size.y - pad * 2
    local container = window:createContainer(
        Rect(vec2(pad, pad), vec2(pad + iw, pad + ih)))

    headerLabel = container:createLabel(
        Rect(vec2(0, 0), vec2(iw, 28)),
        "Quantum Trading AI"%_t, 18)

    subtitleLabel = container:createLabel(
        Rect(vec2(0, 32), vec2(iw, 56)),
        "Pay the AI to analyze your trade journal. Both tabs unlock with one payment; valid 1 hour across any Trading Post. Hover any cell for full details.", 12)
    subtitleLabel.wordBreak = true

    -- Top action row
    local actionTop = 64
    local actionBot = 100
    runReportButton = container:createButton(
        Rect(vec2(0, actionTop), vec2(420, actionBot)),
        "Run Trade Report"%_t, "onRunReportPressed")
    runReportButton.active = false

    validityLabel = container:createLabel(
        Rect(vec2(430, actionTop + 8), vec2(iw, actionTop + 32)), "", 13)

    -- Tabbed window: Best Prices + Trade Routes
    local tabTop = 108
    local tabBottom = ih - 90  -- leave room for survey CTA below
    tabbedWindow = container:createTabbedWindow(
        Rect(vec2(0, tabTop), vec2(iw, tabBottom)))

    bestPricesTab = tabbedWindow:createTab(
        "Best Prices"%_t,
        "data/textures/icons/procure-command.png",
        "Best Prices: per-commodity best buy and best sell across your journal"%_t)
    tradeRoutesTab = tabbedWindow:createTab(
        "Trade Routes"%_t,
        "data/textures/icons/wormhole.png",
        "Trade Routes: round-trip loops between sectors with profitable backhauls"%_t)

    buildBestPricesTab(bestPricesTab)
    buildTradeRoutesTab(tradeRoutesTab)

    -- Survey CTA (below the tabbed window)
    surveyStatusLabel = container:createLabel(
        Rect(vec2(0, tabBottom + 8), vec2(iw, tabBottom + 30)), "", 13)
    surveyStatusLabel.wordBreak = true

    acquireButton = container:createButton(
        Rect(vec2(0, tabBottom + 38), vec2(420, tabBottom + 78)),
        "Acquire Faction Survey"%_t, "onAcquirePressed")
    acquireButton.active = false
end

function QuantumTradeAI.onShowWindow()
    if not onClient() then return end
    hasRunReport = false
    lastOwns = false
    cachedRouteRows = {}
    cachedBestPricesRows = {}
    setBestPricesRows({})
    setRouteRows({})
    if bpEmptyLabel       then bpEmptyLabel:hide() end
    if routesEmptyLabel   then routesEmptyLabel:hide() end
    if bpPrePaidLabel     then bpPrePaidLabel:show(); bpPrePaidLabel.caption = "Loading..." end
    if routesPrePaidLabel then routesPrePaidLabel:show() end
    if runReportButton    then runReportButton.active = false; runReportButton.caption = "Run Trade Report" end
    if validityLabel      then validityLabel.caption = "" end
    if acquireButton      then acquireButton.active = false end
    if surveyStatusLabel  then surveyStatusLabel.caption = "" end
    if headerLabel        then headerLabel.caption = "Quantum Trading AI" end
    invokeServerFunction("serverGetTradeReportMeta", Player().index)
end

function QuantumTradeAI.clientReceiveTradeReportMeta(subjectName, fee, surveyPrice, owns, valid, remaining)
    if not onClient() then return end
    lastSubjectName = tostring(subjectName or "?")
    lastFee         = tonumber(fee) or 0
    lastSurveyPrice = tonumber(surveyPrice) or 0
    lastOwns        = owns and true or false

    if headerLabel then
        headerLabel.caption = string.format("Quantum Trading AI : %s", lastSubjectName)
    end

    if valid then
        if validityLabel then
            validityLabel.caption = string.format(
                "Trade Report valid for %s", formatDuration(remaining or 0))
        end
        if runReportButton then
            runReportButton.caption = "Trade Report active"
            runReportButton.active  = false
        end
        if bpPrePaidLabel     then bpPrePaidLabel.caption = "Re-loading your active Trade Report..." end
        if routesPrePaidLabel then routesPrePaidLabel.caption = "Loading routes..." end
        invokeServerFunction("serverRunTradeReport", Player().index)
    else
        if validityLabel then validityLabel.caption = "" end
        if runReportButton then
            if lastFee > 0 then
                runReportButton.caption = string.format("Pay %d cr to run Trade Report", lastFee)
            else
                runReportButton.caption = "Run Trade Report (free)"
            end
            runReportButton.active = true
        end
        if bpPrePaidLabel then
            bpPrePaidLabel.caption = string.format(
                "Click the button above to pay %d cr and analyze your trade journal.\nThe report stays active for 1 hour across any Trading Post.",
                lastFee)
            bpPrePaidLabel:show()
        end
        if routesPrePaidLabel then routesPrePaidLabel:show() end
    end
    updateAcquireButtonState()
end

function QuantumTradeAI.onRunReportPressed()
    if not onClient() then return end
    if runReportButton then runReportButton.active = false end
    if bpPrePaidLabel  then bpPrePaidLabel.caption  = "Running analysis..." end
    invokeServerFunction("serverRunTradeReport", Player().index)
end

function QuantumTradeAI.clientReceiveTradeReportRefused(fee)
    if not onClient() then return end
    if bpPrePaidLabel then
        bpPrePaidLabel.caption = string.format(
            "Insufficient credits. The Quantum Trading AI charges %d cr per Trade Report.", tonumber(fee) or 0)
    end
    if runReportButton then runReportButton.active = true end
end

function QuantumTradeAI.clientReceiveTradeReportRows(priceRows, routeRows, remainingSeconds)
    if not onClient() then return end
    hasRunReport = true
    if bpPrePaidLabel     then bpPrePaidLabel:hide() end
    if routesPrePaidLabel then routesPrePaidLabel:hide() end
    if runReportButton then
        runReportButton.active = false
        runReportButton.caption = "Trade Report active"
    end
    if validityLabel then
        validityLabel.caption = string.format(
            "Trade Report valid for %s", formatDuration(tonumber(remainingSeconds) or 0))
    end

    -- Best Prices
    cachedBestPricesRows = (type(priceRows) == "table") and priceRows or {}
    if #cachedBestPricesRows == 0 then
        setBestPricesRows({})
        if bpEmptyLabel then
            bpEmptyLabel.caption = "The AI analyzed your journal but found nothing.\nEquip a Trading System and visit station-bearing sectors to record prices first."
            bpEmptyLabel:show()
        end
    else
        if bpEmptyLabel then bpEmptyLabel:hide() end
        setBestPricesRows(sortBestPrices(cachedBestPricesRows, bestPricesSortMode))
    end

    -- Trade Routes
    cachedRouteRows = (type(routeRows) == "table") and routeRows or {}
    if #cachedRouteRows == 0 then
        setRouteRows({})
        if routesEmptyLabel then routesEmptyLabel:show() end
    else
        if routesEmptyLabel then routesEmptyLabel:hide() end
        setRouteRows(sortRoutes(cachedRouteRows, routesSortMode))
    end

    updateAcquireButtonState()
end

function QuantumTradeAI.clientReceiveAcquiredAck(factionId)
    if not onClient() then return end
    lastOwns = true
    updateAcquireButtonState()
end

function QuantumTradeAI.onAcquirePressed()
    if not onClient() then return end
    if lastOwns then return end
    if not hasRunReport then return end
    invokeServerFunction("serverAcquireFactionSurvey", Player().index)
    if surveyStatusLabel then
        surveyStatusLabel.caption = "Filing Faction Survey..."
    end
    if acquireButton then acquireButton.active = false end
end

function QuantumTradeAI.renderUI()
    -- no-op
end
