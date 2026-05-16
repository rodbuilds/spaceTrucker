-- Standalone client-side Sector Survey window. Opens in front of the
-- player when invoked; shows journal cross-references for the current
-- sector plus the archetype hint for the docked station's faction.
--
-- v1 scope: standalone window opened from the report merchant interaction
-- (a "Sector Survey" button), or by player chat command. Direct in-place
-- injection into vanilla's TradingManager UI is deferred.
package.path = package.path .. ";data/scripts/lib/?.lua"

local TruckerSurvey = include("truckersurvey")

TruckerSurveyPanel = {}

local window
local body

function TruckerSurveyPanel.show(player, faction)
    if not onClient() then return end
    if not window then
        local res = getResolution()
        local size = vec2(620, 480)
        local menu = ScriptUI()
        window = menu:createWindow(Rect((res - size) * 0.5, (res + size) * 0.5))
        menu:registerWindow(window, "Sector Survey"%_t)
        window.caption = "Sector Survey"%_t
        window.showCloseButton = 1
        window.moveable = 1
        local container = window:createContainer(Rect(vec2(15, 15), size - vec2(30, 30)))
        body = container:createLabel(container.rect.lower, "", 13)
        body.wordBreak = true
    end

    local lines = {}

    -- Archetype hint for the docked faction (if any).
    if faction then
        for _, l in ipairs(TruckerSurvey.formatArchetypeHint(player, faction)) do
            table.insert(lines, l)
        end
        table.insert(lines, "")
    end

    -- Per-commodity best buy / sell digest.
    table.insert(lines, "JOURNAL CROSS-REFERENCE")
    table.insert(lines, "----------------------------------------")
    for _, l in ipairs(TruckerSurvey.formatLines(player)) do
        table.insert(lines, l)
    end

    body.caption = table.concat(lines, "\n")
    window:show()
end

return TruckerSurveyPanel
