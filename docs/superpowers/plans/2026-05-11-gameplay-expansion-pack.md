# Gameplay Expansion Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three full gameplay expansion phases: dynamic sector events/PVE/action chains, sector control/trade/intelligence, and fleet doctrines/artifacts/late-game crises.

**Architecture:** Keep `OGameCore` as the source of truth. Add persistent expansion state to `Universe`, implement one focused `GameplayExpansionEngine` that refreshes derived opportunities during simulation, and expose high-signal opportunities through `StrategicAdvisorEngine`. The macOS UI initially sees the new systems through advisor rows and existing star map/fleet/victory navigation, avoiding a large UI rewrite in this pass.

**Tech Stack:** Swift 5.9, SwiftPM, deterministic OGameCore simulation, existing executable test targets.

---

## File Structure

- Modify `Sources/OGameCore/DomainModels.swift`: add persistent gameplay expansion models and default decoding for old saves.
- Create `Sources/OGameCore/GameplayExpansionEngine.swift`: generate/refresh sector events, hostile sites, action chains, sector control, trade routes, deep intel, artifacts, fleet doctrine summaries, and crisis state.
- Modify `Sources/OGameCore/SimulationEngine.swift`: refresh expansion state during normal ticks.
- Modify `Sources/OGameCore/StrategicAdvisorEngine.swift`: surface the most important expansion opportunities and risks.
- Modify `Sources/OGameMac/Views/DashboardViews.swift`: add icons and navigation for new advisor kinds.
- Modify `Sources/OGameBalanceTool/main.swift`: include expansion counts in the autoplay audit output.
- Modify `Tests/OGameCoreTests/main.swift`: add tests first for all three phases and save migration defaults.
- Add `docs/native-macos-ogame/gameplay-expansion-2026-05-11.md`: player-facing summary of the new gameplay loops.

## Task 1: Persistent Expansion State

- [x] Write failing tests that expect `Universe` to expose expansion state with safe defaults when decoding older save JSON.
- [x] Add `SectorEvent`, `HostileSite`, `ActionChain`, `SectorControlSummary`, `TradeRoute`, `DeepIntelOperation`, `FleetDoctrineSummary`, `Artifact`, and `CrisisState`.
- [x] Add these fields to `Universe` with default empty values and strict optional decoding.
- [x] Run `swift run OGameCoreTests` and confirm the new tests pass.

## Task 2: Dynamic Expansion Engine

- [x] Write failing tests for `GameplayExpansionEngine.refresh(in:)`.
- [x] Generate deterministic sector events, PVE hostile sites, action chains, sector control summaries, trade route suggestions, deep intel operations, doctrine summaries, artifact discoveries, and late-game crisis state.
- [x] Integrate refresh into `SimulationEngine.tick`.
- [x] Run `swift run OGameCoreTests`.

## Task 3: Advisor And Tool Visibility

- [x] Write failing tests that strategic advisor recommendations include new expansion kinds.
- [x] Add advisor kinds for sector events, hostile sites, action chains, trade routes, deep intel, artifacts, and crisis.
- [x] Update macOS advisor icons/navigation.
- [x] Add expansion counts to `OGameBalanceTool` audit output.
- [x] Run `swift build` and `swift run OGameBalanceTool`.

## Task 4: Documentation And Verification

- [x] Document the three phases in `docs/native-macos-ogame/gameplay-expansion-2026-05-11.md`.
- [x] Run `swift run OGameCoreTests`.
- [x] Run `swift run OGamePersistenceTests`.
- [x] Run `swift build`.
- [x] Run `swift run OGameBalanceTool`.
- [x] Run `git diff --check`.
- [ ] Commit and push to `codex/realtime-loop`.
