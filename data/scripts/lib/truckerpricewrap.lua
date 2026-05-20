-- Helper that wraps a TradingAPI shop table price functions with the
-- archetype bias AND stashes the archetype on the station entity itself
-- (Entity:setValue) so client-side price reads can apply the same bias.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerPriceHook = include("truckerpricehook")
local TruckerLog       = include("truckerlog")

TruckerPriceWrap = {}

local STATION_ARCH_KEY     = "trucker_station_arch"
local STATION_STRENGTH_KEY = "trucker_station_strength"

-- Server-side: set the archetype + strength on the entity so clients can
-- read them and apply the same bias.
local function markEntityArchetype()
    if not onServer() then return end
    local entity = Entity()
    if not entity then return end
    local faction = Faction()
    if not faction then return end
    local TruckerExcluded = include("truckerexcluded")
    local TruckerAssign   = include("truckerassignarchetypes")
    if TruckerExcluded.isExcluded(faction) then return end
    local arch = TruckerAssign.ensureAssigned(faction)
    if not arch then return end
    local strength = TruckerAssign.getStrength(faction) or 1.0

    pcall(function()
        if entity:getValue(STATION_ARCH_KEY) ~= arch then
            entity:setValue(STATION_ARCH_KEY, arch)
        end
        if entity:getValue(STATION_STRENGTH_KEY) ~= strength then
            entity:setValue(STATION_STRENGTH_KEY, strength)
        end
    end)
end

-- Wrap the price functions and initialize on `namespace`. Idempotent.
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
        local trader = namespace.trader
        local good   = trader and trader.getBoughtGoodByName and trader:getBoughtGoodByName(goodName)
        local biased = TruckerPriceHook.applyBuyBias(good, price)
        return biased, basePrice, supply, relation, factor
    end

    namespace.getSellPrice = function(goodName, buyingFactionIndex)
        local price, basePrice, supply, relation, factor =
            original_getSellPrice(goodName, buyingFactionIndex)
        local trader = namespace.trader
        local good   = trader and trader.getSoldGoodByName and trader:getSoldGoodByName(goodName)
        local biased = TruckerPriceHook.applySellBias(good, price)
        return biased, basePrice, supply, relation, factor
    end

    -- Wrap initialize to mark the entity with its faction archetype.
    local original_initialize = namespace.initialize
    namespace.initialize = function(...)
        if original_initialize then original_initialize(...) end
        markEntityArchetype()
    end

    namespace.__truckerWrapped = true
    TruckerLog.info("Wrapped price functions on %s", tostring(namespaceName))
end

-- For non-namespaced merchant scripts (like headquarters.lua) that use
-- the global `initialize`. Call from the overlay's initialize directly.
function TruckerPriceWrap.markCurrentEntity()
    markEntityArchetype()
end

return TruckerPriceWrap
