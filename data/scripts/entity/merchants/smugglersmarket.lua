-- Space Trucker overlay for the vanilla Smuggler's Market merchant.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerPriceWrap = include("truckerpricewrap")

-- namespace SmugglersMarket
TruckerPriceWrap.install(SmugglersMarket, "SmugglersMarket")
