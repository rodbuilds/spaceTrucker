-- Per-player background script. Registers onSectorEntered to capture trade
-- journal observations every time the player enters a sector.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerJournal = include("truckerjournal")
local TruckerLog     = include("truckerlog")

function initialize()
    if not onServer() then return end
    Player():registerCallback("onSectorEntered", "onSectorEntered")
    TruckerLog.info("Player observer attached for %s", tostring(Player().name))
end

function onSectorEntered(playerIndex, x, y)
    if not onServer() then return end
    local player = Player(playerIndex)
    if not player then return end
    local sector = Sector()
    if not sector then return end
    TruckerJournal.recordObservations(player, sector)
end
