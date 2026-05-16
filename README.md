# Space Trucker

A mod for Avorion (2.5.11–3.0.0) that introduces trucking as a fourth
profession alongside salvage, mining, and combat. Faction-flavored markets,
a personal trade journal, and purchasable intel let you progress from
sector-hopping merchant to galaxy-spanning trader by reading markets.

## What it does

- **Faction commodity bias.** At galaxy generation, every NPC faction is
  assigned an economic archetype (Agricultural, Industrial, Mining,
  Refinery, Frontier, Mercantile, Militant) derived from a weighted roll
  biased by the faction's vanilla traits. Station prices in that faction's
  space are modified to reflect the archetype.
- **Trade journal.** When your ship has a Trading System upgrade and you
  enter a sector, every station price you can see is recorded into a
  per-player journal. Journals auto-share within alliances.
- **Faction commodity reports.** Trading Posts and Faction Headquarters
  in archetype-assigned space sell snapshot reports identifying that
  faction's archetype and the relevant slice of your alliance's
  observations. War-status warnings are derived live.
- **Sector Survey panel.** A standalone window (reached via the report
  merchant interaction) cross-references your journal against the
  current location, surfacing best-buy and best-sell observations per
  commodity.

## Installation

Drop into your Avorion `mods/` directory or subscribe via Steam Workshop
once published.

## Compatibility

**This mod modifies station buy/sell prices** by wrapping the merchant
namespaces' `getBuyPrice` and `getSellPrice` functions. It is therefore
incompatible with other mods that override the same functions on these
namespaces:
- `TradingPost`
- `Factory`
- `Consumer` (and inheriting merchants: Biotope, Refinery, Habitat,
  MilitaryOutpost)
- `PlanetaryTradingPost`
- `Seller`
- `SmugglersMarket`

**Known incompatibilities:**
- Any "Trading Overhaul" workshop mod that replaces these scripts.
- Carrier Commander's economy adjustments (untested but likely conflicts).

The mod uses `saveGameAltering = true`. Disabling the mod after install
will leave orphaned `Faction:setValue("trucker_*", ...)` and
`Player:setValue("trucker_*", ...)` keys in the savegame; they are
silently ignored without the mod running.

## Configuration

Server operators can edit `data/config/spacetrucker.lua` to tune:
- `journalMaxEntries` (default 5000) — per-player / per-alliance journal cap
- `reportPriceBase`, `reportPricePerPower` — faction report pricing formula
- `reportSnapshotRows` (default 100) — rows captured per report
- `archetypeMaxShare` (default 0.30) — distribution guardrail

## Diagnostics

In-game admin commands (require server-admin privileges):

- `/trucker debug` — dump archetype distribution; show your journal/report
  totals
- `/trucker reports` — list your purchased reports with archetype, bias
  summary, snapshot size, war-status
- `/trucker survey` — print your journal cross-reference for every
  commodity you've observed

## Authors

Rodx, Servamp
