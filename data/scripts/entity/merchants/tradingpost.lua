-- Space Trucker overlay for the vanilla Trading Post merchant.
-- Loads after vanilla data/scripts/entity/merchants/tradingpost.lua and
-- wraps its price functions to apply faction archetype bias.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerPriceWrap = include("truckerpricewrap")

-- namespace TradingPost
TruckerPriceWrap.install(TradingPost, "TradingPost")
