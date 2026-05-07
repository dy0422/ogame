# Milestone 1 Verification

Milestone 1 creates the native macOS Swift foundation for the OGame sandbox while leaving the legacy PHP/template code untouched. It establishes the SwiftPM package, a pure Swift simulation core, JSON persistence, a minimal SwiftUI app shell, and executable test runners.

## Expected Commands

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

The repo uses executable test runners because the local Apple unit-test modules and Swift Testing are unavailable in this environment.

## Implemented Capabilities

- SwiftPM package with `OGameCore`, `OGamePersistence`, `OGameMac`, and executable validation targets.
- Codable core model for universes, factions, planets, fleets, research, events, resources, and rulesets.
- Deterministic starter universe factory with stable entity IDs and seeded AI planet placement.
- Simulation tick entry point that advances game time and records system events.
- JSON save/load repository with versioned envelopes and schema checks.
- SwiftUI shell with dashboard, planet detail, fleet/research placeholders, event feed, tick, save, and new-game actions.

## Safety And Review Highlights

- Stable enum-map JSON encoding/decoding for buildings, ships, defenses, and technologies.
- Deterministic starter universe output for repeatable tests and saved-game comparisons.
- Non-finite/huge delta safety in simulation tick coverage.
- Hardened save file names plus schema-header validation before full save decode.
- Autosave load-failure protection that disables advancing/saving until a new game is started.

## Deferred To Later Milestones

- Resource production formulas, building/research queues, and online economy ticking.
- Offline catch-up and AI economic growth.
- Fleet missions, scouting, combat, debris, and reports.
- Star map interactions, victory conditions, rankings, exploration, balancing, and app polish.
