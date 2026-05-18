## REMOVED Requirements

### Requirement: Sector Survey panel injected into vanilla station trade view

**Reason:** Direct in-place injection into vanilla's `tradingmanager` UI was deferred from MVP because the buy/sell tab structure proved too entangled for safe overlay. The replacement surface for surfacing journal cross-reference data to the player is now the Quantum Trading AI Trade Report (see quantum-trade-ai capability), which is a dedicated paid window at Trading Posts rather than an injection into vanilla controls.

**Migration:** Player-facing functionality moves to the Quantum Trading AI Trade Report. No player data changes. The shared data-layer helpers (per-commodity best buy/sell aggregation) are retained internally and consumed by the new merchant.

### Requirement: Journal cross-reference for visible commodities

**Reason:** This requirement scoped the cross-reference to "commodities visible in the vanilla trade view", which presupposes in-place UI injection. The new Quantum Trading AI Trade Report scopes the cross-reference to the player's entire journal (commodity-keyed), not to whatever the current vanilla trade view happens to show. The new scope is captured by the quantum-trade-ai capability's "Trade Report shows per-commodity best buy / best sell with station attribution" requirement.

**Migration:** Players see equivalent or richer data via the new Trade Report. The alliance-shared observation distinction is preserved in the underlying journal model and continues to be surfaced wherever observations are rendered.

### Requirement: Archetype hint badge for current faction

**Reason:** The standalone "archetype hint" surface (presented inside an in-place vanilla-trade panel) is superseded by the Codex (full Faction Survey detail, browsable any time) and by the Faction Survey cross-sell button in the Quantum Trading AI Trade Report (contextual prompt when at a station whose Survey the player does not yet own).

**Migration:** The "purchase a Faction Commodity Report" prompt moves into the Quantum Trading AI Trade Report's Faction Survey cross-sell action. The full archetype identity (now Economy) and its bias summary live in the Codex detail view after Survey acquisition.

### Requirement: Graceful degradation without Trading System

**Reason:** Originally written about a panel injected into vanilla trade view. The new Quantum Trading AI Trade Report is a paid AI service at Trading Posts that uses the player's journal — it does not depend on the vanilla Trading Subsystem upgrade, but rather complements it. The "no Trading System" state is no longer a degraded mode but a different fictional context (the AI explicitly exceeds the subsystem's range).

**Migration:** No player action required. The Trade Report works whether or not the player has a Trading Subsystem installed; the journal-capture path's Trading-System gate (in trade-journal capability) is unchanged.

### Requirement: Empty-state behavior on first install

**Reason:** Scoped to the deferred in-place panel. Equivalent empty-state requirements now live in two places: trader-codex (when the player owns zero Surveys) and quantum-trade-ai (when the player has zero journal entries — the Trade Report still renders with the appropriate empty state).

**Migration:** Players see informative empty states in the new surfaces; no functionality is lost.
