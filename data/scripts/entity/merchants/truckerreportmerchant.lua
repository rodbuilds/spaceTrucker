-- Quantum Trading AI — the at-Trading-Post analytics merchant.
--
-- Pay-per-open Trade Report:
--   * Fee deducted on open (skip for infiniteResources)
--   * Whole-journal aggregation: per-commodity best buy / best sell with
--     station name + sector coords + relative age
--
-- Faction Survey cross-sell:
--   * Action button to acquire the permanent Codex entry for THIS TP's
--     owning faction
--   * Shows "owned" status if the player already has the Survey
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

local function buildTradeReportPayload(player)
    local TruckerReports    = include("truckerreports")
    local TruckerAssign     = include("truckerassignarchetypes")
    local TruckerArchetypes = include("truckerarchetypes")

    local subject = Faction()
    local subjectName = subject and tostring(subject.name) or "?"

    -- Per-commodity stats (whole-journal scope; capped inside the call).
    local stats = TruckerReports.computeObservationStats(player)
    local now = (Server and Server() and Server().unpausedRuntime) or os.time()

    local lines = {}
    table.insert(lines, string.format("QUANTUM TRADING AI : %s", subjectName))
    table.insert(lines, "(Cross-galaxy journal analysis)")
    table.insert(lines, "")

    if #stats == 0 then
        table.insert(lines, "Your trade journal is empty.")
        table.insert(lines, "Equip a Trading System and visit station-bearing sectors")
        table.insert(lines, "to begin recording prices the AI can analyze.")
    else
        for _, o in ipairs(stats) do
            table.insert(lines, string.format("[ %s ]", o.commodity))
            if o.buyStats then
                local bb = o.bestBuy
                local loc = string.format("%s (%d,%d)",
                    tostring(bb and bb.stationName or "?"),
                    bb and bb.sectorX or 0, bb and bb.sectorY or 0)
                table.insert(lines, string.format(
                    "  BUY  best %d cr @ %s   %s   [avg %d, %d-%d, %d obs]",
                    bb and bb.price or 0, loc,
                    relativeAge(now, bb and bb.timestamp),
                    math.floor(o.buyStats.avg), o.buyStats.min, o.buyStats.max,
                    o.buyStats.count))
            end
            if o.sellStats then
                local bs = o.bestSell
                local loc = string.format("%s (%d,%d)",
                    tostring(bs and bs.stationName or "?"),
                    bs and bs.sectorX or 0, bs and bs.sectorY or 0)
                table.insert(lines, string.format(
                    "  SELL best %d cr @ %s   %s   [avg %d, %d-%d, %d obs]",
                    bs and bs.price or 0, loc,
                    relativeAge(now, bs and bs.timestamp),
                    math.floor(o.sellStats.avg), o.sellStats.min, o.sellStats.max,
                    o.sellStats.count))
            end
        end
    end

    local body = table.concat(lines, "\n")

    -- Cross-sell info
    local owns = false
    local price = 0
    if subject then
        owns  = TruckerReports.ownsSurveyFor(player, subject.index)
        price = TruckerReports.priceFor(subject)
    end

    return body, subjectName, owns, price
end

function QuantumTradeAI.serverOpenTradeReport(playerIndex)
    if not onServer() then return end
    local TruckerReports = include("truckerreports")
    local player = Player(playerIndex)
    if not player then return end

    local fee = TruckerReports.TRADE_REPORT_FEE or 50000
    if not player.infiniteResources then
        if not canAfford(player, fee) then
            invokeClientFunction(player, "clientReceiveTradeReport",
                "", "", false, 0, false, fee)
            player:sendChatMessage("Quantum Trading AI", 0,
                "Insufficient credits. The AI charges %d cr per analysis."%_t, fee)
            return
        end
        player:pay("Paid Quantum Trading AI"%_t, fee)
    end

    local body, subjectName, owns, surveyPrice = buildTradeReportPayload(player)
    invokeClientFunction(player, "clientReceiveTradeReport",
        body, subjectName, owns, surveyPrice, true, fee)
end
callable(QuantumTradeAI, "serverOpenTradeReport")

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

    -- First-purchase mail (one-time per player)
    local INTRO_KEY = "trucker_codex_intro_sent"
    if not player:getValue(INTRO_KEY) then
        local subjectLine = "Faction Survey Acquired"
        local body = string.format(
            "Captain,\n\n" ..
            "Your acquisition of intel on %s has been filed in your Trader's Codex.\n" ..
            "Open the Codex any time from your player menu - no need to revisit a Trading Post.\n\n" ..
            "The Codex tracks every Faction Survey you acquire. As your library grows,\n" ..
            "cross-faction comparison becomes a powerful tool for plotting trade routes.\n\n" ..
            "- Quantum Trading AI",
            tostring(subject.name))
        TruckerLog.sendMail(player, subjectLine, body)
        player:setValue(INTRO_KEY, true)
    end
end
callable(QuantumTradeAI, "serverAcquireFactionSurvey")

-- =========================================================================
-- Client (Trade Report window)
-- =========================================================================

local window
local bodyLabel
local feeLabel
local acquireButton
local acquireStatusLabel
local lastOwns = false
local lastPrice = 0

function QuantumTradeAI.initUI()
    if not onClient() then return end

    local res  = getResolution()
    local size = vec2(720, 560)
    local menu = ScriptUI()
    window = menu:createWindow(Rect((res - size) * 0.5, (res + size) * 0.5))
    menu:registerWindow(window, "Quantum Trading AI"%_t)
    window.caption        = "Quantum Trading AI"%_t
    window.showCloseButton = 1
    window.moveable        = 1

    local pad = 15
    local iw  = size.x - pad * 2     -- 690
    local ih  = size.y - pad * 2     -- 530
    local container = window:createContainer(
        Rect(vec2(pad, pad), vec2(pad + iw, pad + ih)))

    -- Layout (relative to container, 690x530):
    --   feeLabel        : y=0   .. 24
    --   bodyLabel       : y=32  .. 432
    --   acquireStatus   : y=440 .. 470
    --   acquireButton   : y=478 .. 518
    feeLabel = container:createLabel(
        Rect(vec2(0, 0), vec2(iw, 24)), "", 14)

    bodyLabel = container:createLabel(
        Rect(vec2(0, 32), vec2(iw, 432)),
        "Initializing Quantum Trading AI...", 13)
    bodyLabel.wordBreak = true

    acquireStatusLabel = container:createLabel(
        Rect(vec2(0, 440), vec2(iw, 470)), "", 14)

    acquireButton = container:createButton(
        Rect(vec2(0, 478), vec2(280, 518)),
        "Acquire Faction Survey"%_t, "onAcquirePressed")
end

function QuantumTradeAI.onShowWindow()
    if not onClient() then return end
    if bodyLabel then bodyLabel.caption = "Charging fee and analyzing journal..." end
    if feeLabel  then feeLabel.caption  = "" end
    if acquireStatusLabel then acquireStatusLabel.caption = "" end
    if acquireButton then acquireButton.active = false end
    invokeServerFunction("serverOpenTradeReport", Player().index)
end

function QuantumTradeAI.clientReceiveTradeReport(body, subjectName, owns, surveyPrice, paid, fee)
    if not onClient() then return end
    if not bodyLabel or not feeLabel then return end

    lastOwns  = owns and true or false
    lastPrice = tonumber(surveyPrice) or 0

    if not paid then
        feeLabel.caption  = string.format("Fee: %d cr  (insufficient credits)", tonumber(fee) or 0)
        bodyLabel.caption = "The Quantum Trading AI requires payment to run an analysis.\nReturn when you have the funds."
        acquireStatusLabel.caption = ""
        if acquireButton then acquireButton.active = false end
        return
    end

    feeLabel.caption  = string.format("Analysis fee: %d cr  -  paid", tonumber(fee) or 0)
    bodyLabel.caption = body or ""

    -- Cross-sell button / status line
    if lastOwns then
        acquireStatusLabel.caption = "Faction Survey owned : on file in your Codex"
        if acquireButton then acquireButton.active = false end
    else
        acquireStatusLabel.caption = string.format(
            "Acquire permanent intel on %s (%d cr)",
            tostring(subjectName or "this faction"), lastPrice)
        if acquireButton then acquireButton.active = true end
    end
end

function QuantumTradeAI.onAcquirePressed()
    if not onClient() then return end
    if lastOwns then return end
    invokeServerFunction("serverAcquireFactionSurvey", Player().index)
    -- Optimistic UI: disable button + update status; server-side will chat-confirm.
    if acquireStatusLabel then
        acquireStatusLabel.caption = "Acquiring Faction Survey..."
    end
    if acquireButton then acquireButton.active = false end
    lastOwns = true
end

function QuantumTradeAI.renderUI()
    -- no-op; window is event-driven
end
