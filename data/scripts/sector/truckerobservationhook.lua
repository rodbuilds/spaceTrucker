-- Sector-side journal-capture path for players already in the sector when
-- it loads from disk. (For first entry into a sector, the player-level
-- observer at data/scripts/player/truckerplayerobserver.lua handles capture
-- via the onSectorEntered callback — sector scripts in this Avorion build
-- do not receive a reliable player-entry callback.)
--
-- Report merchant attachment is NOT done here. It is attached from the
-- trading post and headquarters entity overlays where Entity() and
-- Faction() are always valid.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerJournal = include("truckerjournal")
local TruckerLog     = include("truckerlog")

function initialize()
    if not onServer() then return end
    local sector = Sector()
    if not sector then return end
    local x, y = sector:getCoordinates()
    TruckerLog.info("hook.initialize() sector (%d,%d)", x, y)
    for _, p in pairs({sector:getPlayers()}) do
        if p then TruckerJournal.recordObservations(p, sector) end
    end
end
