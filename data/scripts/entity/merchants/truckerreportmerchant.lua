-- Faction Commodity Reports merchant.
-- Modeled on cargotransportlicensemerchant.lua but reports are not items;
-- they are codex artifacts persisted on the buyer's Player entity. The
-- interaction window is a custom dialog rather than ShopAPI.
package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")
include("faction")

local TruckerReports    = include("truckerreports")
local TruckerExcluded   = include("truckerexcluded")
local TruckerArchetypes = include("truckerarchetypes")
local TruckerAssign     = include("truckerassignarchetypes")
local TruckerLog        = include("truckerlog")

-- Don't remove or alter the following comment, it tells the game the
-- namespace this script lives in. If you remove it, the script will break.
-- namespace TruckerReportMerchant
TruckerReportMerchant = {}

TruckerReportMerchant.interactionThreshold = 10000   -- modest reputation gate

function TruckerReportMerchant.interactionPossible(playerIndex, option)
    local faction = Faction()
    if not faction or TruckerExcluded.isExcluded(faction) then return false end
    -- Lazy bootstrap: ensure the owning faction has an archetype before we
    -- offer reports for it.
    TruckerAssign.ensureAssigned(faction)
    local arch = faction:getValue("trucker_archetype")
    if not arch or not TruckerArchetypes.isValid(arch) then return false end
    return CheckFactionInteraction(playerIndex, TruckerReportMerchant.interactionThreshold)
end

function TruckerReportMerchant.initialize()
    if onClient() and EntityIcon().icon == "" then
        -- Reuse a generic merchant icon; could swap for a custom one later.
        EntityIcon().icon = "data/textures/icons/pixel/trade.png"
    end
end

-- ---------- server: purchase RPC ----------

function TruckerReportMerchant.serverBuyReport(playerIndex)
    if not onServer() then return end
    local player = Player(playerIndex)
    local subject = Faction()
    if not player or not subject then return end

    if TruckerExcluded.isExcluded(subject) then return end
    TruckerAssign.ensureAssigned(subject)
    local arch = subject:getValue("trucker_archetype")
    if not arch or not TruckerArchetypes.isValid(arch) then return end

    local price = TruckerReports.priceFor(subject)
    if (player.money or 0) < price then
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

-- Avorion exposes a callable convention: the function name `buyReport`
-- becomes invokable from the client via `invokeServerFunction`.
function TruckerReportMerchant.buyReport(playerIndex)
    TruckerReportMerchant.serverBuyReport(playerIndex)
end
callable(TruckerReportMerchant, "buyReport")

-- ---------- client: interaction window ----------

local window
local infoLabel
local priceLabel
local buyButton
local surveyButton

function TruckerReportMerchant.initUI()
    if not onClient() then return end
    local res = getResolution()
    local size = vec2(460, 340)

    local menu = ScriptUI()
    window = menu:createWindow(Rect((res - size) * 0.5, (res + size) * 0.5))
    menu:registerWindow(window, "Faction Commodity Report"%_t)

    window.caption = "Faction Commodity Report"%_t
    window.showCloseButton = 1
    window.moveable = 1

    local container = window:createContainer(Rect(vec2(15, 15), size - vec2(30, 30)))

    local splitter = UIVerticalSplitter(container.rect, 10, 0, 0.65)
    infoLabel  = container:createLabel(splitter.top.lower, "", 14)
    infoLabel.wordBreak = true

    local bottom = UIVerticalSplitter(splitter.bottom, 10, 0, 0.4)
    priceLabel = container:createLabel(bottom.left.lower, "", 16)

    local rightSplit = UIVerticalSplitter(bottom.right, 10, 0, 0.5)
    buyButton    = container:createButton(rightSplit.left,  "Purchase"%_t,      "onBuyPressed")
    surveyButton = container:createButton(rightSplit.right, "Sector Survey"%_t, "onSurveyPressed")
end

function TruckerReportMerchant.onSurveyPressed()
    if not onClient() then return end
    local TruckerSurveyPanel = include("client/truckersurveypanel")
    TruckerSurveyPanel.show(Player(), Faction())
end

function TruckerReportMerchant.onShowWindow()
    if not onClient() then return end
    local subject = Faction()
    if not subject then return end
    local arch = subject:getValue("trucker_archetype") or "Unassigned"
    local cheap, dear = TruckerReports.summarizeBias(arch)
    local cheapStr = #cheap > 0 and table.concat(cheap, ", ") or "(none)"
    local dearStr  = #dear  > 0 and table.concat(dear,  ", ") or "(none)"
    local price = TruckerReports.priceFor(subject)
    infoLabel.caption = string.format(
        "Subject:  %s\nArchetype:  %s\n\nTends CHEAP:  %s\nTends DEAR:  %s\n\n" ..
        "A purchased report is a frozen snapshot of this faction's archetype " ..
        "plus your current observations within their space.",
        tostring(subject.name), tostring(arch), cheapStr, dearStr)
    priceLabel.caption = string.format("Price: %d cr", price)
end

function TruckerReportMerchant.onBuyPressed()
    if not onClient() then return end
    invokeServerFunction("buyReport", Player().index)
end

function TruckerReportMerchant.renderUI()
    -- no-op; window is event-driven
end
