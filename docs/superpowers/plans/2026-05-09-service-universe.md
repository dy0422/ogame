# Service-Style Universe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start all eight OGame service-style systems in a playable first slice.

**Architecture:** Add `UniverseTopologyEngine` as the deterministic core rule source for coordinates, planet profiles, colony target generation, moon chance, and expedition slot handling. Wire existing starter universe, colonization, combat, AI expansion, and star map UI to that shared source.

**Tech Stack:** Swift 5.9, SwiftPM, OGameCore deterministic tests, SwiftUI macOS shell.

---

### Task 1: Core Topology Tests

**Files:**
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] Add failing tests for topology constants, slot ecology, moon chance, and starter neutral target count.
- [x] Run `swift run OGameCoreTests` and confirm failure because `UniverseTopologyEngine` is missing.

### Task 2: Core Topology Engine

**Files:**
- Create: `Sources/OGameCore/UniverseTopologyEngine.swift`
- Modify: `Sources/OGameCore/StarterUniverseFactory.swift`

- [x] Implement topology constants and coordinate validation.
- [x] Implement deterministic planet profile generation.
- [x] Replace starter hard-coded field/temperature formulas with topology profiles.
- [x] Expand starter neutral colony targets from 3 to a deterministic regional pool.
- [x] Run `swift run OGameCoreTests`.

### Task 3: Colonization And Moon Rules

**Files:**
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/CombatEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] Test that colonization applies topology-derived profile to the claimed world.
- [x] Test that moon chance is `0%` below `100,000`, `1%` at `100,000`, and capped at `20%`.
- [x] Wire colonization and combat to `UniverseTopologyEngine`.
- [x] Run `swift run OGameCoreTests`.

### Task 4: AI And Expedition Slot

**Files:**
- Modify: `Sources/OGameCore/AIStrategyEngine.swift`
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] Ensure AI expansion can seed or select neutral coordinates from topology helpers.
- [x] Ensure expedition slot `16` is valid for exploration and invalid for colonization.
- [x] Run `swift run OGameCoreTests`.

### Task 5: Star Map UI

**Files:**
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`

- [x] Expose a selected solar-system summary with 16 slots.
- [x] Render a compact `1...16` panel on the star map.
- [x] Show owned, AI, neutral, unknown, moon, debris, and expedition states.
- [x] Run `swift build`.

### Task 6: Final Verification

**Files:**
- All touched files.

- [x] Run `swift run OGameCoreTests`.
- [x] Run `swift run OGamePersistenceTests`.
- [x] Run `swift build`.
- [x] Run `./script/build_and_run.sh --verify`.
- [ ] Commit and push `codex/realtime-loop`.
