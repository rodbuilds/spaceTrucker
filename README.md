# Space Trucker: Quantum Trade

A mod for Avorion (2.5.11–3.0.0) that introduces trucking as a fourth
profession alongside salvage, mining, and combat. Faction-flavored
markets, a persistent trade journal, an at-station Quantum Trading AI,
and a Trader's Codex of Faction Surveys let you progress from
sector-hopping merchant to galaxy-spanning trader by reading markets.

## What it does

- **Faction Economy + Specialization.** At first observation, every NPC
  faction is assigned an **Economy** (Agricultural, Industrial, Mining,
  Refinery, Frontier, Mercantile, Militant) via a trait-weighted roll,
  plus a **Specialization** scalar (rendered as 1–5 stars) that controls
  how strongly the Economy biases their commodity prices. Stations in
  that faction's space sell low / buy high on their characteristic goods.
- **Trade journal.** With a Trading System upgrade equipped, every
  station price you can see is recorded into a per-player journal as
  you enter sectors. Journals auto-share within alliances.
- **Quantum Trading AI.** At every Trading Post and Faction Headquarters,
  pay a flat fee to run a Trade Report — a whole-journal analysis of the
  best buy and sell stations per commodity, far beyond the range of a
  vanilla Trading Subsystem. The AI also offers a Faction Survey for the
  current station's faction.
- **Faction Surveys + Trader's Codex.** Acquire a permanent Survey of a
  faction's economy from the Quantum Trading AI; review them any time
  from the **Trader's Codex** tab on your player menu (P). Each Codex
  entry shows the faction's Economy, Specialization, Sells Low / Buys
  High tag lists, a Galactic Avg vs Faction Avg commodity table, and a
  "Show Home Sector on Map" button to navigate to their space.

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

**Upgrading from v0.1.0 (MVP):** no migration is performed. Legacy
report entries are silently skipped on read with a one-time log
warning. For best results, create a new galaxy when upgrading to
v0.2.0.

## Configuration

Server operators can edit `data/config/spacetrucker.lua` to tune:

- `journalMaxEntries` (default 5000) — per-player / per-alliance journal cap
- `tradeReportFee` (default 50,000 cr) — Quantum Trading AI per-open fee
- `factionSurveyBasePrice` (default 1,000,000 cr) — Faction Survey base; final
  acquisition price is `base × specialization`, so range is ~300k–1.8M cr
- `surveyObservationCap` (default 2000) — max journal observations
  aggregated into a single Trade Report
- `archetypeMaxShare` (default 0.30) — distribution guardrail across
  factions for any one Economy

## Player menu

Open the **Trader's Codex** tab from the player menu (P) to browse
acquired Faction Surveys. Sort buttons across the top: Faction (default),
Economy, Specialization, Acquired (date). Click a row to open detail.

## Diagnostics

In-game admin commands (require server-admin privileges):

- `/trucker debug` — dump Economy distribution; show journal + Survey
  counts
- `/trucker reports` (alias `/trucker codex`) — chat output of every
  Faction Survey you own with the live Galactic Avg vs Faction Avg
  price band
- `/trucker survey` — chat output of your journal cross-reference per
  commodity (best buy / best sell stations)

## Authors

Rodx, Servamp
