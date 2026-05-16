-- Sector init: runs whenever ANY sector is loaded. Attaches the Space
-- Trucker observation hook so we capture journal entries on player entry.
package.path = package.path .. ";data/scripts/lib/?.lua"

if onServer() then
    local sector = Sector()
    if sector then
        sector:addScriptOnce("data/scripts/sector/truckerobservationhook.lua")
    end
end
