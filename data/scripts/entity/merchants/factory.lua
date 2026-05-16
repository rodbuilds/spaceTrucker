-- Space Trucker overlay for the vanilla Factory merchant.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerPriceWrap = include("truckerpricewrap")

-- namespace Factory
TruckerPriceWrap.install(Factory, "Factory")
