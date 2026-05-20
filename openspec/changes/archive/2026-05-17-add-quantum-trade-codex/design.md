## Context

The MVP shipped four capabilities (faction-commodity-bias, faction-commodity-reports, sector-survey-ui, trade-journal). All player-facing surface is currently text in chat (`/trucker reports`, `/trucker survey`) or a small `ScriptUI` window at the report merchant. Two architectural facts emerged from MVP playtesting that shape this design:

1. **Avorion exposes a clean split between Server and Client Lua contexts.** `Faction:setValue` and `Player:setValue` are server-only. `Entity:setValue` values DO sync to clients (this is how the MVP closed the price-bias UI/transaction desync). Client code must request server-side data via `invokeServerFunction` and receive it via `invokeClientFunction` callbacks.

2. **`data/scripts/sector/init.lua` and `data/scripts/player/init.lua` mod-overlay vanilla additively** — confirmed by MVP behaviour where our overlays attach scripts without removing vanilla attachments. Same is presumed true for `data/scripts/entity/merchants/*.lua` (proven by the price-wrap pattern).

The existing MVP scope already iterated through and resolved: the bias hook desync, the per-faction store of archetype + specialization on entity-values, the script-attach pattern from `TradingPost.initialize`, and the journal capture path via `Player:registerCallback("onSectorEntered", ...)`. This change builds on those foundations rather than re-architecting them.

Persistence is via `setValue`/`getValue` only, with our `truckerserialize.lua` Lua-literal encoder for tables. No external storage.

The mod targets co-op multiplayer (single Server, multiple Players) from day one. Per-player UI must keep its state on the client and authoritative data on the server.

## Goals / Non-Goals

**Goals:**

- Replace chat-only intel surfaces with proper in-game UI (player-menu Codex + at-TP Trade Report window)
- Normalize all player-facing language to in-fiction terms while preserving the underlying mod architecture
- Flip the Survey/Report terms so they read naturally to the player
- Land the rename + UI in a single migration window so legacy reports keep working without manual user action
- Keep monochrome-safe rendering throughout (typography + glyph + position, no color encoding for critical info)
- Preserve current performance characteristics (sub-100ms compute on user click; no per-frame work)
- Match the Workshop discoverability conventions (new mod display name + thumbnail already in place)

**Non-Goals:**

- Trade Routes (cross-faction arbitrage computation) — explicitly future spec
- In-place injection into vanilla `tradingmanager` UI (markers in vanilla buy/sell window) — deferred since MVP
- Codex free-text search and pagination
- Notifications beyond the first-purchase mail (no badges, no toasts)
- Cross-player Codex visibility (alliance-shared) — out of scope; only personal Codex
- Tutorial / onboarding beyond the first-purchase mail
- Re-architecting price-bias, journal capture, or specialization rolls — those are MVP foundations and are intentionally untouched

## Decisions

### D1. Term flip (Survey ↔ Report) is a one-shot rename, no compatibility shim, no data migration

**Decision:** Rename in one PR. No dual-language aliases. No migration of MVP-era stored report data.

**Why:** The MVP is a freshly-archived single capability set on a pre-release mod with a single tester. The cost of writing, testing, and reasoning about an auto-upgrade migration exceeds the cost to that one tester of starting a fresh galaxy. The new code expects the new shape; entries persisted under the MVP shape will not be read meaningfully.

**Alternatives considered:**
- *Dual aliases for a release:* Rejected — doubles the surface area of every reference and forces every future change to know both terms.
- *Auto-upgrade migration:* Rejected — non-zero implementation + test cost, and zero player impact at this stage.
- *Defer the rename:* Rejected — the rename is the immersion fix; UI without it ships immersion-broken text.

**Handling legacy entries:** If the read path encounters an entry missing the `economy` field (the new shape's marker), it SHALL silently skip that entry. No transformation. No logging beyond a single one-time warning per galaxy ("Skipped N legacy report entries; create a fresh galaxy to reset."). Tester action: new galaxy.

### D2. Codex lives on `Player` entity; UI is client-side; data is fetched via RPC

**Decision:** Codex data is stored as a serialized table on the Player via `setValue`. The codex window UI is a client-side `ScriptUI` panel attached to the player. When the panel opens, it `invokeServerFunction`s to fetch the list of Faction Survey headers; row-click fetches detail per faction.

**Why:** `Player:getValue` is server-only. The client cannot read its own player state directly. RPC is the only path. Two-fold query (list-then-detail) keeps the list cheap and the detail computed lazily.

**Alternatives considered:**
- *Stash Codex content on `Entity()` like we did for archetype:* Rejected — Player has no station entity to attach to.
- *Push all reports to client on player join:* Rejected — bandwidth and memory waste for a panel the player may never open.

### D3. Trade Report at TPs replaces the existing report merchant

**Decision:** Repurpose `truckerreportmerchant.lua` as the **Quantum Trading AI** merchant. Its interaction window becomes the Trade Report UI (per-use paid analysis of the player's whole journal). The "Acquire Faction Survey" cross-sell lives inside it.

**Why:** We already have the attach-to-TPs/headquarters plumbing working (in `tradingpost.lua` / `headquarters.lua` overlays). Reusing the merchant entity script means no new attachment work. The old "show preview + buy" flow becomes "show data (you paid for it) + offer permanent acquisition".

**Alternatives considered:**
- *Add a second merchant entity script:* Rejected — doubles attachment paths and increases the "no script with index N" warnings we already see in vanilla logs.
- *Use Avorion's ShopAPI for Trade Reports:* Rejected — Trade Reports aren't inventory items; ShopAPI doesn't fit.

### D4. Trade Report scope = whole journal, Faction Survey scope = one faction

**Decision:** Trade Report displays the player's entire journal aggregated by commodity, with station name + sector coords per row. Faction Survey displays one faction's economy profile (Galactic Avg vs Faction Avg), no station references.

**Why:** Reinforces the architectural split: Survey = analysed by AI (your data, full attribution); Codex Survey = formal economic profile (faction data, anonymous-of-station).

**Alternatives considered:**
- *Trade Report faction-scoped:* Rejected — already what `/trucker survey` was; the point of Quantum AI is "beyond vanilla Trading Subsystem's range".
- *Codex with station names:* Rejected — couples codex value to the player's specific travels; pollutes the formal-document feel.

### D5. Specialization renders as stars (list) + adjective (detail), single source of truth in the lib

**Decision:** `truckerarchetypes.lua` exposes `specializationToStars(spec)` returning 1-5 and `specializationLabel(spec)` returning `"Lightly" | "Modestly" | "Solidly" | "Heavily" | "Pure"`. Both consume the same underlying 0.3-1.8 scalar that was rolled at faction assignment.

**Why:** Single bucket-mapping function = consistency across list + detail + future surfaces. Stars + label keeps it monochrome-safe and avoids surfacing the underlying float to the player.

**Bucket cuts:** `[0.30, 0.59] [0.60, 0.89] [0.90, 1.19] [1.20, 1.49] [1.50, 1.80]` → 1-5 stars respectively.

### D6. Codex access: new Player script + player-menu button

**Decision:** Add a player-level script `tradercodexmenu.lua` that registers an entry on the player's main menu (vanilla pattern; see `data/scripts/player/init.lua` reference) and opens the codex window on click.

**Why:** Standard Avorion UX. Vanilla missions/inventory work the same way. Menu buttons aren't faction-gated, which matches the Codex being "always available once you own at least one Survey".

**Open question deferred:** Exact label ("Trader's Codex" vs "Faction Surveys" vs other). The button text is one config change away from final.

### D7. First-purchase mail trigger, not toast

**Decision:** When a player purchases their first Faction Survey, send an in-game mail (vanilla mail API) with a short orientation pointing to the menu button. Subsequent purchases trigger no notification.

**Why:** Mail is persistent, dismissable, and discoverable in vanilla UI. Toasts/badges are intrusive and visually noisy. Discoverability problem is "does the player know the Codex exists?" — one mail solves that durably.

**Alternatives considered:**
- *Toast on every purchase:* Rejected — annoying after the first.
- *Permanent badge on the menu button:* Rejected — colorblind-unsafe and unnecessary noise after first interaction.

### D8. Pricing: two-step explicit-consent flow at the Quantum Trading AI

**Decision:**
- Quantum Trading AI window: opens FREE. Displays a "Pay X cr to run Trade Report" button as the primary action. No content until paid.
- Trade Report: flat `tradeReportFee` (default 50,000 cr). Charged when the player clicks the run button. Renders the per-commodity table after payment.
- Faction Survey: `1,000,000 × specialization` (range ~300k–1.8M). Acquisition button is inactive until a Trade Report has been run this session, after which the button activates with the price in its label.

**Why two-step:** First version auto-charged on window open and surfaced a Survey button alongside the report. Player feedback was that this felt like a double payment — by the time they saw the Acquire button, they'd already been silently charged. Splitting the flow into (a) free open → (b) explicit-consent run → (c) optional Survey acquisition makes each money moment intentional. No surprise deductions; the player always clicks to spend.

**Both numbers in `data/config/spacetrucker.lua`** as `tradeReportFee` and `factionSurveyBasePrice`. Operators can set `tradeReportFee = 0` to make Trade Reports free (Survey acquisition still costs the configured amount); the run button just renders as "Run Trade Report (free)" in that case.

**Validity window:** once a player pays the Trade Report fee, the report stays valid for `tradeReportValiditySeconds` (default 3600 = 1 hour). Reopening the Quantum Trading AI at any station during the validity window auto-loads the report without charging again. The window shows the remaining time. This addresses the UX problem where accidentally closing the window — or stepping out to check the galaxy map — would otherwise force a re-payment. Validity is per-player, persisted on the Player entity (`trucker_trade_report_paid_at` scalar).

### D9. "Show Home Sector on Map" — single, simple behaviour

**Decision:** The Codex detail-view button is labelled **"Show Home Sector on Map"** and always behaves identically: it opens the galaxy map and centers on the subject faction's home sector (via `Faction:getHomeSector()` or the equivalent stable API). No territory enumeration is attempted.

**Why:** Full territory highlighting was a stretch goal with an unknown API surface and a non-trivial map-annotation rendering job. Home sector covers the practical use case ("where do I go to find them?") with a single stable API call. Removing the fallback also removes the spike, the conditional UX, and the risk of the button behaving differently per Avorion version. If a richer territory view becomes valuable later, it ships as its own change.

**Alternatives considered:**
- *Full territory highlight (original D9):* Rejected — unknown API surface, spike cost, conditional UX complexity, low marginal value over home-sector navigation.
- *No map action at all:* Rejected — players need a way to physically reach the faction they're reading about, and forcing them to galaxy-map search by faction name is a worse UX than one click.

### D10. Performance: two-fold query, soft observation cap

**Decision:**
- Codex list-view RPC returns minimal per-Survey headers (faction name, economy, specialization, sells-low/buys-high tag tuples). O(reports).
- Codex detail RPC computes the commodity table for ONE faction. O(goods).
- Trade Report RPC aggregates whole-journal observations. Capped at `surveyObservationCap` (default 2000 entries) — newest-first. Hidden from UI.

**Why:** Bounded worst-case compute, predictable user perception. Cap is invisible config; tunable if pathological saves emerge.

### D11. Mod name change is `modinfo.lua` only

**Decision:** Update `modinfo.lua`'s `name` field to `"Space Trucker: Quantum Trade"`. Do not rename any directories, internal Lua identifiers, or save-key prefixes — the directory is `mods/spaceTrucker/` and stays that way.

**Why:** Internal renames break save compatibility for testers who upgrade in place. The Workshop display name is the only visible surface that matters for searchability.

## Risks / Trade-offs

- **[Mail API may not support clickable links to open UIs]** → Mitigation: Mail body is plain text describing the menu path; no link required. Discoverability still works.
- **[Player-menu integration patterns may have evolved across Avorion versions]** → Mitigation: Cross-check with `avorion-scripts/player/init.lua` and existing player scripts before authoring. If the pattern is brittle, fall back to a hotkey registration as a v2.1 stopgap.
- **[Two-fold query under load: rapid open/close of detail could spam RPC]** → Mitigation: Acceptable in MP because each player drives independent RPCs; server-side detail compute is O(100). If profiling shows hot spots, add a client-side cache keyed by faction index with a short TTL (~30s) — out of scope unless measured.
- **[Mod name change confuses existing Workshop subscribers]** → Mitigation: Pre-publish; this is v0.1.0 → v0.2.0, not a Workshop-released artifact yet.
- **[New Player script (`tradercodexmenu.lua`) registration on existing saves]** → Mitigation: Add via `data/scripts/player/init.lua` overlay so it attaches on next player join; existing players get it on relogin without manual intervention.

## Migration Plan

- v0.1.0 (MVP, archived) is the starting baseline.
- v0.2.0 ships this change. **No data migration** — testers create a new galaxy to exercise the new code paths. Pre-release scope; one tester.
- On a fresh galaxy after v0.2.0:
  1. Player init attaches the new codex menu script.
  2. First TP visit shows the Quantum Trading AI merchant entry.
  3. First Faction Survey purchase triggers the orientation mail.
- No save break for in-progress saves either — vanilla Avorion continues to load; legacy mod data is silently skipped per D1. Tester just won't see codex content until they buy a Survey on the new shape (or start fresh).
