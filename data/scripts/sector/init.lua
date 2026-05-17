-- Sector init: runs whenever ANY sector is loaded. Attaches the Space
-- Trucker observation hook so we capture journal entries on player entry.
package.path = package.path .. ";data/scripts/lib/?.lua"

if onServer() then
    local sector = Sector()
    if sector then
        local x, y = sector:getCoordinates()
        print(string.format("[SpaceTrucker] sector/init.lua firing for (%d,%d)", x, y))
        sector:addScriptOnce("data/scripts/sector/truckerobservationhook.lua")
    end
end
