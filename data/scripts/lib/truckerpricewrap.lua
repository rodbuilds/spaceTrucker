-- Helper that wraps a TradingAPI-derived namespace's price functions with
-- the archetype bias. Each per-merchant overlay file calls this once.
--
-- Why this lives in lib/: every merchant overlay shares the exact same
-- wrapping logic, so it's factored out. The actual `getBuyPrice` /
-- `getSellPrice` overrides happen in the entity-script files where the
-- namespace is defined and `Faction()` returns the entity's owner.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerPriceHook = include("truckerpricehook")
local TruckerLog       = include("truckerlog")

TruckerPriceWrap = {}

-- Wrap the price functions on `namespace` (e.g. TradingPost, Factory).
-- Caller supplies the namespace table. Idempotent: no-op if already wrapped.
function TruckerPriceWrap.install(namespace, namespaceName)
    if not namespace then return end
    if namespace.__truckerWrapped then return end

    local original_getBuyPrice  = namespace.getBuyPrice
    local original_getSellPrice = namespace.getSellPrice

    if not original_getBuyPrice or not original_getSellPrice then
        TruckerLog.warn("Cannot wrap %s: missing getBuyPrice/getSellPrice", tostring(namespaceName))
        return
    end

    namespace.getBuyPrice = function(goodName, sellingFactionIndex)
        local price, basePrice, supply, relation, factor =
            original_getBuyPrice(goodName, sellingFactionIndex)
        local faction = Faction()
        local trader  = namespace.trader
        local good    = trader and trader:getBoughtGoodByName and trader:getBoughtGoodByName(goodName)
        local biased  = TruckerPriceHook.applyBuyBias(faction, good, price)
        return biased, basePrice, supply, relation, factor
    end

    namespace.getSellPrice = function(goodName, buyingFactionIndex)
        local price, basePrice, supply, relation, factor =
            original_getSellPrice(goodName, buyingFactionIndex)
        local faction = Faction()
        local trader  = namespace.trader
        local good    = trader and trader:getSoldGoodByName and trader:getSoldGoodByName(goodName)
        local biased  = TruckerPriceHook.applySellBias(faction, good, price)
        return biased, basePrice, supply, relation, factor
    end

    namespace.__truckerWrapped = true
    TruckerLog.info("Wrapped price functions on %s", tostring(namespaceName))
end

return TruckerPriceWrap
