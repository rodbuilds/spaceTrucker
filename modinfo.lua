
meta =
{
    -- ID of your mod; Make sure this is unique!
    -- Will be used for identifying the mod in dependency lists
    -- Will be changed to workshop ID (ensuring uniqueness) when you upload the mod to the workshop
    id = "spaceTrucker",

    -- Name of your mod; You may want this to be unique, but it's not absolutely necessary.
    -- This is an additional helper attribute for you to easily identify your mod in the Mods() list
    name = "spaceTrucker",

    -- Title of your mod that will be displayed to players
    title = "Space Trucker: Quantum Trade",

    -- Type of your mod, either "mod" or "factionpack"
    type = "mod",

    -- Description of your mod that will be displayed to players
    description = [[You came to Avorion to salvage, mine, or fight. Then you noticed The Iron Coalition pays double for raw ore -- and you understood there was a fourth way.

Space Trucker: Quantum Trade makes hauling a real profession. Every NPC faction quietly gets a hidden Economy (Industrial, Mining, Refinery, Frontier, Mercantile, Militant, Agricultural) and a Specialization rating from 1 to 5 stars. Those two numbers bias every station price in their territory: a Heavily Industrial faction sells parts cheap and pays premium for raw inputs; a Pure Mining faction practically gives ore away. The bigger the Specialization, the wider the spread.

Equip a Trading System and the mod starts a persistent journal of every price you can see, sector after sector, far beyond what one ship can remember. At any Trading Post, pay the Quantum Trading AI to crunch the entire log into per-commodity best-buy and best-sell intel: who sells lowest, who buys highest, which stations are worth the jump. Like the vanilla Trading Subsystem, but unbound by range.

Find a faction worth specializing in? Acquire a permanent Faction Survey from the AI and file it in your Trader's Codex -- a tab on your player menu listing every faction you've studied, sortable by name, Economy, Specialization, or date. Each entry shows Galactic Avg vs Faction Avg per commodity so you know exactly what they pay for what.

Read the markets. Run the routes. Get rich. The cargo bay doesn't care how you feel about combat.

----------------------------------------------------------------
TROUBLESHOOTING / DIAGNOSTICS

In-game chat commands (run on the server):

  /trucker debug               faction Economy distribution, plus your
                               journal and Faction Survey counts
  /trucker reports             list your Faction Surveys with the live
    (alias /trucker codex)     Galactic Avg vs Faction Avg price band
  /trucker survey              journal cross-reference: best buy and
                               best sell station per commodity
  /trucker transport sim       simulate a transport contract from your
                               current sector; changes no game state
  /trucker transport bulletin  force-post one transport bulletin to the
                               nearest station, bypassing the 60 min timer
  /trucker transport ambush    prime the next jump to force a pirate
                               ambush; needs an active transport mission

Server log lines are prefixed [SpaceTrucker]. On first boot, confirm:
  [SpaceTrucker] [INFO] transportbroker loaded
  [SpaceTrucker] [INFO] transportmission loaded

Known conflicts: this mod wraps getBuyPrice / getSellPrice on the
TradingPost, Factory, Consumer, PlanetaryTradingPost, Seller and
SmugglersMarket namespaces, and fully replaces
data/scripts/entity/missionbulletins.lua (vanilla baseline 2.5.11).
Any other mod touching those will conflict.

saveGameAltering is true: disabling the mod leaves inert trucker_*
keys in the savegame. Upgrading from v0.1.0 performs no migration;
start a new galaxy for best results.

Source, issue tracker and full documentation:
https://github.com/rodbuilds/spaceTrucker]],

    -- Insert all authors into this list
    authors = {"Rodx", "Servamp"},

    -- Version of your mod, should be in format 1.0.0 (major.minor.patch) or 1.0 (major.minor)
    -- This will be used to check for unmet dependencies or incompatibilities, and to check compatibility between clients and dedicated servers with mods.
    -- If a client with an unmatching major or minor mod version wants to log into a server, login is prohibited.
    -- Unmatching patch version still allows logging into a server. This works in both ways (server or client higher or lower version).
    version = "0.3.0",
    -- v0.3.0 adds cargo transport missions:
    --   data/scripts/player/missions/transportmission.lua  (new mission script)
    --   data/scripts/entity/merchants/transportbroker.lua  (contract generation lib)
    --   data/scripts/entity/missionbulletins.lua           (replaces vanilla — adds transport entries)

    -- If your mod requires dependencies, enter them here. The game will check that all dependencies given here are met.
    -- Possible attributes:
    -- id: The ID of the other mod as stated in its modinfo.lua
    -- min, max, exact: version strings that will determine minimum, maximum or exact version required (exact is only syntactic sugar for min == max)
    -- optional: set to true if this mod is only an optional dependency (will only influence load order, not requirement checks)
    -- incompatible: set to true if your mod is incompatible with the other one
    -- Example:
    -- dependencies = {
    --      {id = "Avorion", min = "0.17", max = "0.21"}, -- we can only work with Avorion between versions 0.17 and 0.21
    --      {id = "SomeModLoader", min = "1.0", max = "2.0"}, -- we require SomeModLoader, and we need its version to be between 1.0 and 2.0
    --      {id = "AnotherMod", max = "2.0"}, -- we require AnotherMod, and we need its version to be 2.0 or lower
    --      {id = "IncompatibleMod", incompatible = true}, -- we're incompatible with IncompatibleMod, regardless of its version
    --      {id = "IncompatibleModB", exact = "2.0", incompatible = true}, -- we're incompatible with IncompatibleModB, but only exactly version 2.0
    --      {id = "OptionalMod", min = "0.2", optional = true}, -- we support OptionalMod optionally, starting at version 0.2
    -- },
    dependencies = {
        {id = "Avorion", min = "2.5.11", max = "3.0.0"},
    },

    -- Set to true if the mod only has to run on the server. Clients will get notified that the mod is running on the server, but they won't download it to themselves
    serverSideOnly = false,

    -- Set to true if the mod only has to run on the client, such as UI mods
    clientSideOnly = false,

    -- Set to true if the mod changes the savegame in a potentially breaking way, as in it adds scripts or mechanics that get saved into database and no longer work once the mod gets disabled
    -- logically, if a mod is client-side only, it can't alter savegames, but Avorion doesn't check for that at the moment
    saveGameAltering = true,

    -- Contact info for other users to reach you in case they have questions
    contact = "https://github.com/rodbuilds/spaceTrucker",
}
