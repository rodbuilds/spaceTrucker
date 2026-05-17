-- Space Trucker overlay for Faction Headquarters.
-- Vanilla HQ uses global functions (no namespace).
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerPriceWrap  = include("truckerpricewrap")
local TruckerExcluded   = include("truckerexcluded")
local TruckerAssign     = include("truckerassignarchetypes")
local TruckerLog        = include("truckerlog")

local original_initialize = initialize

function initialize(...)
    if original_initialize then original_initialize(...) end
    if not onServer() then return end
    -- Mark the entity so the price hook (if any) can read archetype.
    TruckerPriceWrap.markCurrentEntity()
    local faction = Faction()
    if not faction or TruckerExcluded.isExcluded(faction) then return end
    local arch = TruckerAssign.ensureAssigned(faction)
    if not arch then return end
    Entity():addScriptOnce("data/scripts/entity/merchants/truckerreportmerchant.lua")
    TruckerLog.info("Attached report merchant on HQ '%s' (faction '%s', %s)",
        tostring(Entity().name), tostring(faction.name), arch)
end
