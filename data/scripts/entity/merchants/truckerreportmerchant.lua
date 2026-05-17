-- Faction Commodity Reports merchant.
-- Attached on the server to qualifying stations from the trading post /
-- headquarters overlays. Reports are codex artifacts persisted on the
-- buyer's Player entity. The interaction window is a custom dialog.
package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")
include("faction")
include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TruckerReportMerchant
TruckerReportMerchant = {}

-- ---------- visibility gate ----------
-- This script is only attached server-side to stations whose faction has
-- a Trucker archetype assigned, so we don't re-check that here.
function TruckerReportMerchant.interactionPossible(playerIndex, option)
    return true
end

function TruckerReportMerchant.initialize()
    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/trade.png"
    end
end

-- ---------- server: archetype info + purchase RPC ----------

function TruckerReportMerchant.serverGetReportInfo(playerIndex)
    if not onServer() then return end
    local TruckerReports    = include("truckerreports")
    local TruckerArchetypes = include("truckerarchetypes")
    local TruckerAssign     = include("truckerassignarchetypes")
    local subject = Faction()
    if not subject then return end
    local arch = subject:getValue("trucker_archetype") or ""
    if not TruckerArchetypes.isValid(arch) then arch = "" end
    local strength = TruckerAssign.getStrength(subject) or 1.0
    local sellsCheap, buysHigh = TruckerReports.summarizeBias(arch, strength)
    local price = TruckerReports.priceFor(subject)
    invokeClientFunction(Player(playerIndex), "clientReceiveReportInfo",
        tostring(subject.name or "?"), arch, strength,
        table.concat(sellsCheap or {}, ","),
        table.concat(buysHigh  or {}, ","),
        price)
end
callable(TruckerReportMerchant, "serverGetReportInfo")

function TruckerReportMerchant.serverBuyReport(playerIndex)
    if not onServer() then return end
    local TruckerReports  = include("truckerreports")
    local TruckerExcluded = include("truckerexcluded")
    local TruckerAssign   = include("truckerassignarchetypes")
    local TruckerArchetypes = include("truckerarchetypes")
    local player = Player(playerIndex)
    local subject = Faction()
    if not player or not subject then return end
    if TruckerExcluded.isExcluded(subject) then return end
    TruckerAssign.ensureAssigned(subject)
    local arch = subject:getValue("trucker_archetype")
    if not arch or not TruckerArchetypes.isValid(arch) then return end
    local price = TruckerReports.priceFor(subject)
    local canPay = pcall(function() return player:canPayMoney(price) end)
    local ok = false
    if canPay then
        ok = player:canPayMoney(price)
    else
        ok = (player.money or 0) >= price
    end
    if not ok then
        player:sendChatMessage("Trucker Reports", 0,
            "Insufficient credits. Report costs %d cr."%_t, price)
        return
    end
    player:pay("Bought Faction Commodity Report"%_t, price)
    local entry = TruckerReports.purchase(player, subject)
    if entry then
        player:sendChatMessage("Trucker Reports", 0,
            "Purchased commodity report on %s (%s archetype)."%_t,
            subject.name, arch)
    end
end
callable(TruckerReportMerchant, "serverBuyReport")

-- ---------- client: interaction window ----------

local window
local infoLabel
local priceLabel

function TruckerReportMerchant.initUI()
    if not onClient() then return end
    local res  = getResolution()
    local size = vec2(480, 340)
    local menu = ScriptUI()
    window = menu:createWindow(Rect((res - size) * 0.5, (res + size) * 0.5))
    menu:registerWindow(window, "Faction Commodity Report"%_t)
    window.caption        = "Faction Commodity Report"%_t
    window.showCloseButton = 1
    window.moveable        = 1

    local pad   = 15
    local iw    = size.x - pad * 2  -- 450
    local ih    = size.y - pad * 2  -- 310
    local container = window:createContainer(Rect(vec2(pad, pad), vec2(pad + iw, pad + ih)))

    -- Layout (relative to container, 450x310):
    --   info      : y=0   .. 210   (210 tall)
    --   price     : y=220 .. 250   (30 tall)
    --   buyButton : y=265 .. 305   (40 tall)
    infoLabel  = container:createLabel(Rect(vec2(0, 0),   vec2(iw, 210)),
                    "Loading report info...", 14)
    infoLabel.wordBreak = true

    priceLabel = container:createLabel(Rect(vec2(0, 220), vec2(iw, 250)), "", 16)

    container:createButton(Rect(vec2(0, 265), vec2(200, 305)),
        "Purchase Report"%_t, "onBuyPressed")
    -- Survey is available via the /trucker survey chat command.
end

function TruckerReportMerchant.onShowWindow()
    if not onClient() then return end
    if infoLabel then infoLabel.caption = "Loading report info..." end
    if priceLabel then priceLabel.caption = "" end
    invokeServerFunction("serverGetReportInfo", Player().index)
end

function TruckerReportMerchant.clientReceiveReportInfo(factionName, arch, strength, cheapCsv, dearCsv, price)
    if not onClient() then return end
    if not infoLabel or not priceLabel then return end
    local cheap = (cheapCsv == "" or cheapCsv == nil) and "(none)" or cheapCsv
    local dear  = (dearCsv  == "" or dearCsv  == nil) and "(none)" or dearCsv
    local archDisplay = (arch == "" or arch == nil) and "Unassigned" or arch
    local strengthDisplay = string.format("%.2f", tonumber(strength) or 1.0)
    infoLabel.caption = string.format(
        "Subject:    %s\nArchetype:  %s   (strength %s)\n\n" ..
        "Sells cheap:  %s\nBuys high:    %s\n\n" ..
        "Purchasing this report unlocks live analytics for %s in your codex: " ..
        "expected price bands across every commodity, plus aggregated stats " ..
        "and best-station picks from your own journal. Use /trucker reports " ..
        "to view after purchase.",
        tostring(factionName), tostring(archDisplay), strengthDisplay,
        tostring(cheap), tostring(dear),
        tostring(factionName))
    priceLabel.caption = string.format("Price: %d cr", price or 0)
end

function TruckerReportMerchant.onBuyPressed()
    if not onClient() then return end
    invokeServerFunction("serverBuyReport", Player().index)
end

function TruckerReportMerchant.renderUI()
    -- no-op
end
