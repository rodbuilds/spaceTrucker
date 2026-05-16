-- Space Trucker overlay for the vanilla Seller merchant base.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerPriceWrap = include("truckerpricewrap")

-- namespace Seller
TruckerPriceWrap.install(Seller, "Seller")
