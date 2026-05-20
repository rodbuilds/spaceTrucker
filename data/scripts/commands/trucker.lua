-- /trucker <subcommand>  -  Space Trucker diagnostic + codex commands.
package.path = package.path .. ";data/scripts/lib/?.lua;data/scripts/entity/merchants/?.lua"

local TruckerAssign        = include("truckerassignarchetypes")
local TruckerJournal       = include("truckerjournal")
local TruckerReports       = include("truckerreports")
local TruckerSurvey        = include("truckersurvey")
local TruckerArchetypes    = include("truckerarchetypes")
local Broker               = include("transportbroker")

local function send(player, msg)
    if player and player.sendChatMessage then
        player:sendChatMessage("Trucker", 0, msg)
    else
        print(msg)
    end
end

local function cmdDebug(player)
    TruckerAssign.dumpDistribution()
    if player then
        local p, s = TruckerJournal.size(player)
        local r    = TruckerReports.count(player)
        send(player, string.format(
            "Journal: %d personal, %d alliance-shared. Faction Surveys: %d.",
            p, s, r))
    end
end

-- Render one Faction Survey as live-computed text lines.
local function renderSurvey(player, survey, index)
    local lines = {}
    local economy        = survey.economy or "?"
    local specialization = survey.specialization or 1.0
    local stars = TruckerArchetypes.specializationStarString(specialization)
    local label = TruckerArchetypes.specializationLabel(specialization)

    table.insert(lines, string.format(
        "[%d] %s -- %s Economy  %s (%s)",
        index, tostring(survey.subjectFactionName), economy, stars, label))

    local sellsCheap, buysHigh = TruckerReports.summarizeBias(economy, specialization)
    table.insert(lines, string.format("    Sells cheap: %s",
        #sellsCheap > 0 and table.concat(sellsCheap, ", ") or "(none)"))
    table.insert(lines, string.format("    Buys high:   %s",
        #buysHigh > 0 and table.concat(buysHigh, ", ") or "(none)"))

    local band = TruckerReports.computePriceBand(economy, specialization)
    if #band > 0 then
        table.insert(lines, "    -- Expected price band  (Galactic Avg -> Faction Avg)")
        for i, row in ipairs(band) do
            if i > 12 then
                table.insert(lines, string.format("       ... and %d more", #band - 12))
                break
            end
            table.insert(lines, string.format(
                "       %-22s %6d -> %6d cr",
                string.sub(row.name, 1, 22), row.vanilla, math.floor(row.expected)))
        end
    end
    return lines
end

local function cmdReports(player)
    if not player then return end
    local list = TruckerReports.list(player)
    if #list == 0 then
        send(player, "No Faction Surveys in your Codex. Visit a Trading Post and use the Quantum Trading AI.")
        return
    end
    send(player, string.format("=== %d Faction Surveys ===", #list))
    for i, survey in ipairs(list) do
        for _, line in ipairs(renderSurvey(player, survey, i)) do
            send(player, line)
        end
    end
end

local function cmdSurvey(player)
    if not player then return end
    for _, line in ipairs(TruckerSurvey.formatLines(player)) do
        send(player, line)
    end
    send(player, "(Visit a Trading Post for the full Quantum Trading AI Trade Report.)")
end

-- /trucker transport [sim|bulletin]
-- sim      — simulate contract generation at your current sector and print what the bulletin
--            board entry would look like. No game state is changed.
-- bulletin — force-post one transport bulletin to the nearest station in this sector right now
--            (useful for testing without waiting 60 minutes for the bulletin timer to fire).
local function cmdTransport(player, sub)
    sub = sub or "sim"

    if sub == "sim" then
        if not onServer() then return end
        local sector = Sector()
        if not sector then send(player, "No sector loaded.") return end
        local x, y = sector:getCoordinates()

        send(player, string.format("=== Transport Contract Simulator  sector (%d:%d) ===", x, y))

        local ring   = Broker.getRing(x, y)
        local bounds = Broker.RING_BOUNDS[ring]
        send(player, string.format("Ring: %s  (zone bounds: %d–%d units, cap %.0f%% free space)",
            ring, bounds.min, bounds.max, bounds.frac * 100))

        -- Stations in sector — list titles and eligibility for Space Trucker transport missions
        local stations  = {sector:getEntitiesByType(EntityType.Station)}
        local eligible  = {}

        local function transportWeight(title)
            if title == "Trading Post"  then return 2.5 end
            if title == "Resource Depot" then return 2.0 end
            if title == "Habitat"       then return 1.5 end
            if title == "Biotope"       then return 1.5 end
            if string.match(title, "Factory$")
                and title ~= "Fighter Factory"
                and title ~= "Turret Factory" then return 1.5 end
            return nil
        end

        if #stations == 0 then
            send(player, "Stations in sector: none")
        else
            send(player, string.format("Stations in sector (%d):", #stations))
            for _, s in ipairs(stations) do
                local w = transportWeight(s.title)
                if w then
                    send(player, string.format("  ✓  '%s'  — eligible for transport missions (weight %.1f)", s.title, w))
                    table.insert(eligible, s)
                else
                    send(player, string.format("  ✗  '%s'  — not a transport mission source", s.title))
                end
            end
        end

        if #eligible == 0 then
            send(player, "No eligible stations here — transport bulletins will not appear in this sector.")
            return
        end

        -- Use first eligible station for the rest of the simulation
        local simStation = eligible[1]
        local factionId  = simStation.factionIndex

        local destX, destY = Broker.selectDestination(x, y, factionId)
        if not destX then
            send(player, "FAIL: selectDestination returned nil — no valid sector found 5–30 away.")
            return
        end
        local dist = math.floor(math.sqrt((destX-x)^2 + (destY-y)^2))
        send(player, string.format("Destination: (%d:%d)  dist=%d sectors", destX, destY, dist))

        -- Cargo
        local stationTitle = simStation.title
        local goodName     = Broker.selectCargo(stationTitle, ring)
        send(player, string.format("Simulating from: '%s'  →  cargo good: %s", stationTitle, goodName))

        -- Amount (simulate 200 free units of cargo space)
        local simFree  = 200
        local amount   = Broker.calcAmount(ring, simFree)
        send(player, string.format("Amount: %d units  (simulated %d free cargo space)", amount, simFree))

        -- Reward
        local total, speedBon, window, rel = Broker.calcReward(destX, destY, amount, goodName, dist)
        send(player, string.format("Reward: %d cr  (+%d speed bonus if under %d min)  relations +%d",
            total, speedBon, math.floor(window / 60), rel))

        -- Ambush check
        local g = goods and goods[goodName]
        if g then
            local cargoValue = amount * g.price
            local ambushStr = cargoValue > 50000 and "YES (en-route ambush active)" or "no"
            send(player, string.format("CargoValue: %d cr  → ambush? %s", cargoValue, ambushStr))
        end

        send(player, string.format(
            "--- Bulletin Board preview ---\n" ..
            "  Brief:      Transport %d %s to (%d:%d)\n" ..
            "  Difficulty: Normal\n" ..
            "  Reward:     ¢%d\n" ..
            "  Description: Deliver cargo to sector (%d:%d). Reward: ¢%d.",
            amount, goodName, destX, destY, total, destX, destY, total))

    elseif sub == "bulletin" then
        if not onServer() then return end
        local sector   = Sector()
        local stations = {sector:getEntitiesByType(EntityType.Station)}
        if #stations == 0 then
            send(player, "No stations in this sector — cannot post bulletin.")
            return
        end
        local station = stations[1]
        local ok, bulletin = run("data/scripts/player/missions/transportmission.lua", "getBulletin", station)
        if ok ~= 0 or not bulletin then
            send(player, string.format(
                "getBulletin returned nil (ok=%s). Check server log for [SpaceTrucker] warnings.", tostring(ok)))
            return
        end
        station:invokeFunction("bulletinboard", "postBulletin", bulletin)
        send(player, string.format(
            "Posted transport bulletin to %s: \"%s\"  reward %s",
            station.name, bulletin.brief, bulletin.reward))

    elseif sub == "ambush" then
        if not onServer() then return end
        if not player then send(player, "Must be called by a player.") return end
        player:setValue("trucker_debug_ambush", "1")
        send(player, "Ambush primed. Jump to any sector while carrying transport cargo — pirates will spawn on arrival.")

    else
        send(player,
            "Usage: /trucker transport [sim|bulletin|ambush]\n" ..
            "  sim      — simulate a contract from your current sector (no side effects)\n" ..
            "  bulletin — force-post one transport bulletin to the nearest station now\n" ..
            "  ambush   — prime next sector jump to force pirates (requires active transport mission)")
    end
end

local DISPATCH = {
    debug     = cmdDebug,
    reports   = cmdReports,
    survey    = cmdSurvey,
    codex     = cmdReports,     -- friendly alias
    transport = cmdTransport,   -- transport mission diagnostics
}

function execute(sender, commandName, sub, ...)
    sub = sub or "debug"
    local player = (type(sender) == "number") and Player(sender) or sender
    local fn = DISPATCH[sub]
    if not fn then
        send(player, "Unknown subcommand. Try: debug | reports | codex | survey | transport")
        return 1, "", ""
    end
    fn(player, ...)
    return 0, "", ""
end

function getDescription()
    return "Space Trucker: diagnostics, codex listing, journal survey, transport testing"
end

function getHelp()
    return "Usage: /trucker [debug|reports|codex|survey|transport]\n" ..
           "  debug              — faction archetype distribution + journal/survey counts\n" ..
           "  reports / codex    — list Faction Surveys with price band preview\n" ..
           "  survey             — journal cross-reference (best buy/sell per commodity)\n" ..
           "  transport sim      — simulate a transport contract at your current sector\n" ..
           "  transport bulletin — force-post a transport contract to the nearest station now\n" ..
           "  transport ambush   — prime next sector jump to force a pirate ambush (requires active transport mission)"
end
