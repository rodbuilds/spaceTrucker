-- Space Trucker overlay for the vanilla Planetary Trading Post merchant.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerPriceWrap = include("truckerpricewrap")

-- namespace PlanetaryTradingPost
TruckerPriceWrap.install(PlanetaryTradingPost, "PlanetaryTradingPost")
