-- Quantum Trading AI - the at-Trading-Post analytics merchant.
--
-- Two distinct money flows:
--   1. Trade Report (per-use, ~50k cr): one-shot analysis of the player's
--      whole trade journal. The window opens for FREE; the player clicks
--      an explicit "Pay X cr to run Trade Report" button to spend the fee
--      and load the report content. No content shows until they pay.
--   2. Faction Survey (permanent, ~1M+ cr): unlocks AFTER the Trade Report
--      has been run. Files a permanent entry for THIS station's owning
--      faction in the player's Trader's Codex.
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

local function buildReportRows(player)
    local TruckerReports = include("truckerreports")
    local stats = TruckerReports.computeObservationStats(player)
    local now = (Server and Server() and Server().unpausedRuntime) or os.time()

    local rows = {}
    for _, o in ipairs(stats) do
        local bestBuyText, bestSellText, marginText = "--", "--", "--"
        local marginValue = nil
        if o.buyStats and o.bestBuy then
            bestBuyText = string.format("%d cr  @  %s (%d,%d)  %s",
                o.bestBuy.price or 0,
                tostring(o.bestBuy.stationName or "?"),
                o.bestBuy.sectorX or 0, o.bestBuy.sectorY or 0,
                relativeAge(now, o.bestBuy.timestamp))
        end
        if o.sellStats and o.bestSell then
            bestSellText = string.format("%d cr  @  %s (%d,%d)  %s",
                o.bestSell.price or 0,
                tostring(o.bestSell.stationName or "?"),
                o.bestSell.sectorX or 0, o.bestSell.sectorY or 0,
                relativeAge(now, o.bestSell.timestamp))
        end
        -- Margin = best sell price - best buy price. Only meaningful when
        -- both sides have observations. Negative numbers possible.
        if o.bestBuy and o.bestSell and o.bestBuy.price and o.bestSell.price then
            marginValue = (o.bestSell.price or 0) - (o.bestBuy.price or 0)
            if marginValue >= 0 then
                marginText = string.format("+%d cr", marginValue)
            else
                marginText = string.format("%d cr", marginValue)
            end
        end
        table.insert(rows, {
            commodity = o.commodity,
            buy       = bestBuyText,
            sell      = bestSellText,
            margin    = marginText,
            marginNum = marginValue,   -- for future client-side sorting
        })
    end
    -- Already sorted alphabetically by computeObservationStats.
    return rows
end

-- Free: returns meta. Includes validity status so a recently-paid Trade
-- Report can auto-load without re-paying.
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

-- Paid: charges the fee (unless within validity window), builds rows.
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

    local rows = buildReportRows(player)
    local _, remaining = TruckerReports.tradeReportValidity(player)
    invokeClientFunction(player, "clientReceiveTradeReportRows", rows, remaining or 0)
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

    -- Push the latest Codex list back to the client so their Codex tab
    -- shows the new entry without needing a Refresh click.
    invokeClientFunction(player, "clientReceiveAcquiredAck", subject.index)
end
callable(QuantumTradeAI, "serverAcquireFactionSurvey")

-- =========================================================================
-- Client (Trade Report window)
-- =========================================================================

local window
local headerLabel
local subtitleLabel
local commodityList     -- ListBoxEx 4 columns: Commodity / Best Buy / Best Sell / Margin
local prePaidLabel      -- center "pay to run" copy shown over the empty table
local runReportButton   -- "Pay X cr to run Trade Report"
local validityLabel     -- "Trade Report valid for Nm Ns" (right of the run button)
local emptyStateLabel
local surveyStatusLabel
local acquireButton
local hasRunReport = false
local lastOwns = false
local lastSurveyPrice = 0
local lastFee = 0
local lastSubjectName = ""

function QuantumTradeAI.initUI()
    if not onClient() then return end

    local res  = getResolution()
    local size = vec2(900, 600)
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
        "Pay the AI to run a one-shot analysis of your trade journal. Best buy and sell stations across every commodity you've recorded.", 12)
    subtitleLabel.wordBreak = true

    -- Top action row: "Pay X to run Trade Report" + validity status to its right
    local actionTop = 64
    local actionBot = 104
    runReportButton = container:createButton(
        Rect(vec2(0, actionTop), vec2(420, actionBot)),
        "Run Trade Report"%_t, "onRunReportPressed")
    runReportButton.active = false

    validityLabel = container:createLabel(
        Rect(vec2(430, actionTop + 8), vec2(iw, actionTop + 32)), "", 13)

    -- Column headers row, just above the table
    local headerTop = 116
    local headerBot = 138
    local c0w = math.floor(iw * 0.14)
    local c1w = math.floor(iw * 0.36)
    local c2w = math.floor(iw * 0.36)
    local c3w = iw - (c0w + c1w + c2w)
    local hx = 0
    local function header(label, w)
        local h = container:createLabel(
            Rect(vec2(hx, headerTop), vec2(hx + w, headerBot)), label, 13)
        hx = hx + w
        return h
    end
    header("Commodity", c0w)
    header("Best Buy  (price @ station (sector) age)", c1w)
    header("Best Sell  (price @ station (sector) age)", c2w)
    header("Margin", c3w)

    -- Commodity table (hidden until report is run)
    local tableTop    = headerBot + 4
    local tableBottom = ih - 90
    commodityList = container:createListBoxEx(
        Rect(vec2(0, tableTop), vec2(iw, tableBottom)))
    commodityList.columns = 4
    commodityList.rowHeight = 22
    commodityList:setColumnWidth(0, c0w)
    commodityList:setColumnWidth(1, c1w)
    commodityList:setColumnWidth(2, c2w)
    commodityList:setColumnWidth(3, c3w)

    -- Pre-paid overlay: shown until the player runs the report
    prePaidLabel = container:createLabel(
        Rect(vec2(0, tableTop), vec2(iw, tableBottom)),
        "", 14)
    prePaidLabel.wordBreak = true

    -- Empty-state overlay (shown when no observations exist)
    emptyStateLabel = container:createLabel(
        Rect(vec2(0, tableTop), vec2(iw, tableBottom)),
        "", 14)
    emptyStateLabel.wordBreak = true
    emptyStateLabel:hide()

    -- Survey CTA at the bottom
    surveyStatusLabel = container:createLabel(
        Rect(vec2(0, tableBottom + 8), vec2(iw, tableBottom + 30)),
        "", 13)
    surveyStatusLabel.wordBreak = true

    acquireButton = container:createButton(
        Rect(vec2(0, tableBottom + 38), vec2(420, tableBottom + 78)),
        "Acquire Faction Survey"%_t, "onAcquirePressed")
    acquireButton.active = false
end

local function setCommodityRows(rows)
    if not commodityList then return end
    while commodityList.rows > 0 do commodityList:removeRow(commodityList.rows - 1) end
    if not rows or #rows == 0 then return end
    local white = ColorRGB(1, 1, 1)
    for _, r in ipairs(rows) do
        commodityList:addRow()
        local idx = commodityList.rows - 1
        -- Bold the margin cell when it's a positive profit opportunity,
        -- so the eye picks up the actionable rows without color encoding.
        local marginBold = (type(r.marginNum) == "number" and r.marginNum > 0)
        commodityList:setEntry(0, idx, tostring(r.commodity), false, false, white)
        commodityList:setEntry(1, idx, tostring(r.buy),       false, false, white)
        commodityList:setEntry(2, idx, tostring(r.sell),      false, false, white)
        commodityList:setEntry(3, idx, tostring(r.margin), marginBold, false, white)
    end
end

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
            "This Trade Report expires when you leave. Save a permanent Faction Survey for %s to keep its economic profile in your Codex.",
            lastSubjectName)
    end
    acquireButton.caption = string.format(
        "Acquire Faction Survey  -  %d cr", lastSurveyPrice)
    acquireButton.active = true
end

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

function QuantumTradeAI.onShowWindow()
    if not onClient() then return end
    hasRunReport = false
    lastOwns = false
    setCommodityRows({})
    if emptyStateLabel    then emptyStateLabel:hide()    end
    if prePaidLabel       then prePaidLabel:show(); prePaidLabel.caption = "Loading..." end
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
        -- Already paid recently; auto-load the report without the pay step.
        if validityLabel then
            validityLabel.caption = string.format(
                "Trade Report valid for %s", formatDuration(remaining or 0))
        end
        if runReportButton then
            runReportButton.caption = "Trade Report active"
            runReportButton.active  = false
        end
        if prePaidLabel then prePaidLabel.caption = "Re-loading your active Trade Report..." end
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
        if prePaidLabel then
            prePaidLabel.caption = string.format(
                "The Quantum Trading AI will analyze your entire trade journal and surface the best buy and sell stations across every commodity you've observed - far beyond what a Trading Subsystem can see in one sector.\n\nClick the button above to pay %d cr and run the analysis. The report stays active for 1 hour, so you can close this window and come back without paying again.",
                lastFee)
            prePaidLabel:show()
        end
    end
    updateAcquireButtonState()
end

function QuantumTradeAI.onRunReportPressed()
    if not onClient() then return end
    if runReportButton then runReportButton.active = false end
    if prePaidLabel    then prePaidLabel.caption = "Running analysis..." end
    invokeServerFunction("serverRunTradeReport", Player().index)
end

function QuantumTradeAI.clientReceiveTradeReportRefused(fee)
    if not onClient() then return end
    if prePaidLabel then
        prePaidLabel.caption = string.format(
            "Insufficient credits. The Quantum Trading AI charges %d cr per Trade Report.", tonumber(fee) or 0)
    end
    if runReportButton then runReportButton.active = true end
end

function QuantumTradeAI.clientReceiveTradeReportRows(rows, remainingSeconds)
    if not onClient() then return end
    hasRunReport = true
    if prePaidLabel then prePaidLabel:hide() end
    if runReportButton then
        runReportButton.active = false
        runReportButton.caption = "Trade Report active"
    end
    if validityLabel then
        validityLabel.caption = string.format(
            "Trade Report valid for %s", formatDuration(tonumber(remainingSeconds) or 0))
    end

    if not rows or #rows == 0 then
        setCommodityRows({})
        if emptyStateLabel then
            emptyStateLabel.caption = "The AI analyzed your journal but found nothing.\nEquip a Trading System and visit station-bearing sectors to record prices first."
            emptyStateLabel:show()
        end
    else
        if emptyStateLabel then emptyStateLabel:hide() end
        setCommodityRows(rows)
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
