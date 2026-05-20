-- Player init: attaches the Space Trucker per-player scripts.
-- Both client and server contexts run this; addScriptOnce is idempotent.
package.path = package.path .. ";data/scripts/lib/?.lua"

if onServer() then
    local player = Player()
    if player then
        player:addScriptOnce("data/scripts/player/truckerplayerobserver.lua")
        player:addScriptOnce("data/scripts/player/tradercodex.lua")
    end
end
