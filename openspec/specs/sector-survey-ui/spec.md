# sector-survey-ui Specification

## Purpose

DEPRECATED in v0.2.0. The user-facing functionality moved to the `quantum-trade-ai` and `trader-codex` capabilities. This file is retained as a historical reference; no behavioural requirements remain — only a deprecation marker.

## Migration

- Per-commodity journal cross-reference (formerly the injected Sector Survey panel) is now part of the Quantum Trading AI Trade Report — see the `quantum-trade-ai` capability.
- Archetype hint / faction profile surfaces are now the Trader's Codex — see the `trader-codex` capability.
- The "purchase a Faction Commodity Report" prompt is now the Faction Survey cross-sell action inside the Trade Report.

## Requirements

### Requirement: Capability is deprecated and SHALL NOT be implemented

The `sector-survey-ui` capability is deprecated. No code SHALL implement requirements under this capability. Any prior placeholder code (an injected panel into the vanilla `tradingmanager` UI) SHALL be considered out-of-scope; replacement functionality lives in `quantum-trade-ai` and `trader-codex`.

#### Scenario: New work is not added here
- **WHEN** a contributor considers extending or implementing functionality previously scoped to `sector-survey-ui`
- **THEN** the work SHALL instead be proposed against `quantum-trade-ai` or `trader-codex`; no new requirements SHALL be added to this spec

#### Scenario: Validator coverage
- **WHEN** `openspec validate --specs --strict` runs
- **THEN** this spec SHALL pass by virtue of this deprecation marker; the marker exists solely to satisfy the validator's "at least one requirement" rule while signalling deprecation
