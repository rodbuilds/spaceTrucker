# Space Trucker: Quantum Trade

A mod for Avorion (2.5.11–3.0.0) that introduces trucking as a fourth
profession alongside salvage, mining, and combat. Faction-flavored
markets, a persistent trade journal, an at-station Quantum Trading AI,
and a Trader's Codex of Faction Surveys let you progress from
sector-hopping merchant to galaxy-spanning trader by reading markets.

## What it does

- **Cargo Transport Missions.** Station bulletin boards at Trading Posts,
  Resource Depots, Factories, Habitats, and Biotopes now post **Transport
  Contracts** — pick up a cargo shipment, fly it to a destination sector
  5–30 sectors away, and collect a reward. Cargo amounts and rewards
  scale with the sector zone (outer / mid / inner). Deliver before the
  speed-bonus window for a +30% credit bonus. High-value shipments
  (>50,000 cr cargo value) attract en-route pirate ambushes — pirates
  are already waiting in sectors you jump through. No hard time limit;
  the contract persists across saves.
  > **Maintenance note:** `data/scripts/entity/missionbulletins.lua` is
  > a full replacement of the vanilla file (baseline: Avorion 2.5.11).
  > Re-sync this file when the vanilla version changes.

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
  pay a flat fee to run a Trade Report — a whole-journal analysis with
  two tabs:
  - **Best Prices**: per-commodity best buy and best sell stations across
    your entire journal, far beyond the range of a vanilla Trading Subsystem.
  - **Trade Routes**: canonical sector-pair round-trip loops where BOTH
    legs are profitable, including stock/demand context per leg, per-trip
    profit, and round-trip total. Sortable via a vanilla-style dropdown.
  One payment unlocks both tabs and stays valid for 1 hour across any
  Trading Post. The AI also offers a Faction Survey for the current
  station's faction. **Hover any cell for full details.**
- **Faction Surveys + Trader's Codex.** Acquire a permanent Survey of a
  faction's economy from the Quantum Trading AI; review them any time
  from the **Trader's Codex** tab on your player menu (P). Each Codex
  entry shows the faction's Economy, Specialization, Sells Low / Buys
  High tag lists, a Galactic Avg vs Faction Avg commodity table (hover
  any row for tag + multiplier detail), and a "Show Home Sector on Map"
  button to navigate to their space.

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
acquired Faction Surveys. A vanilla-style sort dropdown at the top
offers Faction (A-Z / Z-A, default A-Z), Economy (A-Z), Specialization
(high/low), and Date Acquired (newest/oldest). Click a row to open
detail; hover any commodity in the detail table for full tag +
multiplier info.

## Diagnostics & Testing

In-game admin commands (require server-admin privileges):

- `/trucker debug` — dump Economy distribution; show journal + Survey
  counts
- `/trucker reports` (alias `/trucker codex`) — chat output of every
  Faction Survey you own with the live Galactic Avg vs Faction Avg
  price band
- `/trucker survey` — chat output of your journal cross-reference per
  commodity (best buy / best sell stations)

### Testing transport missions

| Command | What it does |
|---|---|
| `/trucker transport sim` | Simulates a contract from your current sector. Prints ring, destination, cargo good, amount, reward, speed-bonus window, and ambush threshold — **no game state changed**. Use this first to confirm the broker math is working. |
| `/trucker transport bulletin` | Force-posts one transport bulletin to the nearest station in your sector right now, bypassing the 60-minute bulletin timer. Use this to test the bulletin board UI without waiting. |

**Checklist for first boot:**

1. Start a new galaxy, load in.
2. Open server log — look for:
   ```
   [SpaceTrucker] [INFO] transportbroker loaded
   [SpaceTrucker] [INFO] transportmission loaded
   ```
3. Fly to any Trading Post. Run `/trucker transport sim` — confirm it prints ring, cargo, reward.
4. Run `/trucker transport bulletin` — open the station bulletin board and confirm a "Transport: ..." entry appears.
5. Accept the bulletin. Dock at the source station, open dialog, click **Pick up transport cargo** — confirm cargo appears in hold and a mail arrives.
6. Fly toward the destination. Check server log for:
   ```
   [SpaceTrucker] [INFO] onSectorEntered (x:y): cargoValue=... elapsed=...
   ```
7. Arrive at destination, dock at any station, click **Deliver** — confirm credits and relations are awarded.

**What to look for in server log during a run:**

```
[SpaceTrucker] [INFO] makeBulletin: station='Trading Post' ring=mid good=Steel amount=80 dest=(230:160) dist=22 reward=88200 speedBonus=26460 window=2640s
[SpaceTrucker] [INFO] _loadCargo: loaded 80 Steel onto ship; dest=(230:160) reward=88200 speedBonus=26460 window=2640s
[SpaceTrucker] [INFO] onSectorEntered (225:170): cargoValue=22160 elapsed=45s
[SpaceTrucker] [INFO] onSectorEntered (225:170): cargoValue=22160 ≤ 50000 — no ambush
[SpaceTrucker] [INFO] onDelivery: removed=80/80 fraction=1.00 base=88200 speedBon=26460 total=114660 elapsed=1820s window=2640s
```

## Authors

Rodx, Servamp
