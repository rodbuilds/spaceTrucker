-- Space Trucker overlay for the vanilla Consumer merchant base.
-- Wrapping here covers Biotope, Refinery, Habitat, MilitaryOutpost, and any
-- other consumer-derived merchant that calls TradingAPI:CreateNamespace.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerPriceWrap = include("truckerpricewrap")

-- namespace Consumer
TruckerPriceWrap.install(Consumer, "Consumer")
