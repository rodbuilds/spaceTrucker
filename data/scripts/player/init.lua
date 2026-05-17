-- Player init: attaches the Space Trucker per-player observer.
package.path = package.path .. ";data/scripts/lib/?.lua"

if onServer() then
    local player = Player()
    if player then
        player:addScriptOnce("data/scripts/player/truckerplayerobserver.lua")
    end
end
