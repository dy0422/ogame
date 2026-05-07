# Native macOS OGame Milestones 2-3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Milestone 1 shell into a playable fast-session economy loop with offline catch-up and basic AI economic growth.

**Architecture:** `OGameCore` remains the pure simulation layer. Milestone 2 adds balance tables, resource production, construction/research queues, and start/complete actions. Milestone 3 adds deterministic AI economic choices plus offline catch-up driven from the save wall-clock timestamp. `OGameMac` stays a thin SwiftUI orchestration/UI layer over core actions and persistence.

**Tech Stack:** Swift 5.9+, SwiftPM, SwiftUI, Foundation, executable Swift test runners, Codable JSON persistence.

---

## Scope Check

Milestone 2 and 3 are intentionally limited to economy and offline growth. They do not implement fleets, combat, colonization, espionage, victory conditions, or a full star map. Those remain Milestones 4 and 5.

This plan preserves the existing executable test runner approach:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Do not introduce Apple unit-check frameworks, SwiftPM dedicated test-target entries, or legacy PHP/template changes.

## File Structure

- `Sources/OGameCore/Resources.swift`: add arithmetic helpers for resource math.
- `Sources/OGameCore/DomainModels.swift`: add queue models and default-compatible Codable fields on `Planet`, `Faction`, and `Universe`.
- `Sources/OGameCore/BalanceRules.swift`: balance definitions for building/research cost, time, production, energy, and AI priority.
- `Sources/OGameCore/EconomyEngine.swift`: resource production, storage, and energy recomputation.
- `Sources/OGameCore/QueueEngine.swift`: building/research affordability, enqueue, and completion logic.
- `Sources/OGameCore/AIEconomyEngine.swift`: deterministic AI building/research choices.
- `Sources/OGameCore/OfflineSimulationEngine.swift`: bounded offline catch-up and summary events.
- `Sources/OGameCore/SimulationEngine.swift`: call economy, queue, and AI hooks.
- `Sources/OGameCore/StarterUniverseFactory.swift`: seed starter resources/buildings/AI state for economy.
- `Sources/OGameMac/AppModel.swift`: expose building/research/offline actions and load-time catch-up.
- `Sources/OGameMac/ContentView.swift`: show production, queues, build/research controls, and catch-up status.
- `Tests/OGameCoreTests/main.swift`: add economy, queue, AI, and offline tests.
- `Tests/OGamePersistenceTests/main.swift`: verify save/load round-trips after new fields.
- `docs/native-macos-ogame/milestone-2-3-verification.md`: final verification notes.

## Milestone 2 Task 1: Resource Math And Balance Tables

**Files:**
- Modify: `Sources/OGameCore/Resources.swift`
- Create: `Sources/OGameCore/BalanceRules.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing tests**

Add tests that require:

- `ResourceBundle` addition, subtraction, scalar multiplication, affordability, and nonnegative clamping.
- `RuleSet.fastSkirmish.buildingRules` contains rules for mines, solar plant, robotics factory, shipyard, and research lab.
- `RuleSet.fastSkirmish.researchRules` contains early research rules for energy, computer, espionage, weapons, shielding, and armor.
- Rules encode as raw-value keyed JSON objects, not alternating arrays.

Run:

```bash
swift run OGameCoreTests
```

Expected: build fails because balance rules and helpers are missing.

- [ ] **Step 2: Implement resource helpers**

Add pure helpers to `ResourceBundle` and `ResourceStorage`:

- `adding(_:)`
- `subtracting(_:)`
- `scaled(by:)`
- `nonnegative`
- `canAfford(_:)`
- `asResourceBundle` or equivalent conversion from storage to resource display values.

All helpers must tolerate finite negative inputs by clamping only where the method name says it clamps.

- [ ] **Step 3: Implement balance rules**

Create `BuildingRule` and `ResearchRule` as `Codable`, `Equatable`, `Sendable` value types with:

- base cost
- cost multiplier
- base duration
- duration multiplier
- production per hour for building rules
- energy produced/used for building rules
- storage bonus reserved for future storage buildings
- AI priority weight for simple AI scoring

Extend `RuleSet` with `buildingRules` and `researchRules`. Preserve backwards decode compatibility by defaulting missing rules to `RuleSet.fastSkirmish` values.

- [ ] **Step 4: Run verification and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add economy balance rules"
```

## Milestone 2 Task 2: Queue Domain Models

**Files:**
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Tests/OGameCoreTests/main.swift`
- Modify: `Tests/OGamePersistenceTests/main.swift`

- [ ] **Step 1: Add failing queue round-trip tests**

Add tests for:

- `BuildQueueItem` with id, planetID, building kind, target level, start time, finish time, and paid cost.
- `ResearchQueueItem` with id, factionID, technology kind, target level, start time, finish time, and paid cost.
- `Planet.buildQueue` round-trips through JSON and defaults to empty when missing from older JSON.
- `Faction.researchQueue` round-trips through JSON and defaults to empty when missing from older JSON.
- `Universe.lastSimulatedWallClockTime` or equivalent optional metadata round-trips and defaults safely.

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Expected: build fails because queue fields are missing.

- [ ] **Step 2: Implement queue models**

Add `BuildQueueItem` and `ResearchQueueItem` as public `Codable`, `Equatable`, `Sendable`, `Identifiable` structs. Use deterministic ids where engines create events/tests need stable equality.

Add:

- `Planet.buildQueue: [BuildQueueItem]`
- `Faction.researchQueue: [ResearchQueueItem]`
- `Universe.lastSimulatedWallClockTime: Date?`

Update manual Codable implementations to decode missing queue fields as empty arrays and missing wall-clock field as `nil`.

- [ ] **Step 3: Run verification and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests
git commit -m "feat: add economy queue models"
```

## Milestone 2 Task 3: Economy Production Tick

**Files:**
- Create: `Sources/OGameCore/EconomyEngine.swift`
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing production tests**

Add tests that:

- A one-hour tick increases resources based on mine levels.
- Storage caps resources.
- Energy shortage reduces mine output.
- Solar plant updates `EnergyState.produced`.
- Non-owned planets do not produce.
- Production emits at most one economy summary event per tick.

Run:

```bash
swift run OGameCoreTests
```

Expected: tests fail because production is not implemented.

- [ ] **Step 2: Implement `EconomyEngine`**

Implement:

- `recomputeEnergy(for:ruleSet:)`
- `productionPerHour(for:ruleSet:)`
- `applyProduction(to:delta:ruleSet:)`
- `tick(universe:delta:)`

The formula for fast skirmish:

- Mine production scales as `baseProductionPerHour * level * pow(1.12, level - 1)`.
- Energy ratio is `min(1, produced / max(used, 1))`.
- Solar plant produces energy; mines consume energy.
- Resources are clamped to storage after production.

- [ ] **Step 3: Wire simulation tick**

Update `SimulationEngine.tick` so positive finite ticks:

1. Apply economy production.
2. Advance game time.
3. Complete queues in Task 4 once available.
4. Append deterministic events.

For this task, queue completion can remain a no-op hook.

- [ ] **Step 4: Run verification and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add resource production tick"
```

## Milestone 2 Task 4: Building And Research Queues

**Files:**
- Create: `Sources/OGameCore/QueueEngine.swift`
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing queue action tests**

Add tests that:

- Starting a building upgrade subtracts cost and creates one queue item.
- Starting an unaffordable upgrade fails without mutation.
- Tick completion raises building level, removes the item, recomputes energy, and records an event.
- Starting research subtracts cost and creates one faction research queue item.
- Tick completion raises technology level and records an event.
- Queue completion is deterministic for save/load equality.

Run:

```bash
swift run OGameCoreTests
```

Expected: build fails because `QueueEngine` is missing.

- [ ] **Step 2: Implement `QueueEngine`**

Add public methods:

- `startBuildingUpgrade(on:in:kind:) -> QueueResult`
- `startResearch(for:in:technology:) -> QueueResult`
- `completeDueItems(in:)`

`QueueResult` should be a small public `Equatable`, `Sendable` enum with success/failure cases such as `.queued`, `.insufficientResources`, `.missingPlanet`, `.missingFaction`, `.queueBusy`, `.missingRule`.

Use one active building queue per planet and one active research queue per faction for Milestone 2.

- [ ] **Step 3: Wire `SimulationEngine.tick`**

After advancing `gameTime`, complete due queue items and append economy events. Completion should use the advanced time.

- [ ] **Step 4: Run verification and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add construction and research queues"
```

## Milestone 2 Task 5: App Economy Controls

**Files:**
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`

- [ ] **Step 1: Add app model actions**

Expose:

- `startBuildingUpgrade(planetID:kind:)`
- `startResearch(_:)`
- `availableBuildingKinds`
- `availableResearchKinds`
- queue/status formatting helpers

All actions should call core engines, update status, and autosave after successful queueing.

- [ ] **Step 2: Add SwiftUI controls**

Update `ContentView` to show:

- Resource rates and energy ratio.
- Building levels with upgrade buttons.
- Planet build queue with remaining time.
- Research levels and research buttons.
- Research queue with remaining time.

Keep layout native macOS: sidebar/detail/activity panel, semantic colors, compact controls, no card nesting.

- [ ] **Step 3: Run verification and commit**

Run:

```bash
swift build
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Commit:

```bash
git add Sources/OGameMac
git commit -m "feat: add economy controls to mac app"
```

## Milestone 3 Task 1: Offline Catch-Up Engine

**Files:**
- Create: `Sources/OGameCore/OfflineSimulationEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing offline tests**

Add tests that:

- Offline elapsed time is split into bounded chunks using `RuleSet.offlineChunkInterval`.
- Resource production and queue completion progress during offline catch-up.
- Zero, negative, non-finite, and absurdly large elapsed values are bounded safely.
- Catch-up returns a summary with elapsed seconds, processed chunks, completed queue counts, and event counts.

Run:

```bash
swift run OGameCoreTests
```

Expected: build fails because offline catch-up is missing.

- [ ] **Step 2: Implement offline summary and engine**

Add `OfflineCatchUpSummary: Codable, Equatable, Sendable` and `OfflineSimulationEngine.catchUp(universe:elapsed:now:)`.

Rules:

- Ignore non-positive or non-finite elapsed time.
- Cap one catch-up pass to 24 hours of simulated time for Milestone 3.
- Use `ruleSet.offlineChunkInterval`, minimum 60 seconds.
- Call `SimulationEngine.tick` per chunk.
- Add one final summary event instead of flooding the feed.

- [ ] **Step 3: Run verification and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add offline catch-up engine"
```

## Milestone 3 Task 2: AI Economic Growth

**Files:**
- Create: `Sources/OGameCore/AIEconomyEngine.swift`
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Sources/OGameCore/OfflineSimulationEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing AI tests**

Add tests that:

- AI factions queue affordable upgrades over time.
- Strategy affects priority: miners prefer mines, technologists prefer research labs/research, expansionists prefer robotics/shipyard setup.
- Player state is not mutated by AI decision calls except shared universe time/events.
- AI decisions are deterministic for same universe seed/time.
- Offline catch-up triggers AI decisions at bounded intervals.

Run:

```bash
swift run OGameCoreTests
```

Expected: build fails because AI engine is missing.

- [ ] **Step 2: Implement AI economy**

Implement `AIEconomyEngine` with:

- `makeDecisions(in:)`
- deterministic score ordering from faction strategy, current levels, resources, queue busy state, and seeded tiebreakers.
- one queued action per AI faction per decision window.

Do not implement combat, spying, or fleets here.

- [ ] **Step 3: Wire AI into simulation**

Add an AI decision interval to `RuleSet` or reuse `offlineChunkInterval` for Milestone 3. `SimulationEngine.tick` should run AI decisions when enough game time has passed or when called by offline catch-up chunk boundaries.

- [ ] **Step 4: Run verification and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add AI economic growth"
```

## Milestone 3 Task 3: App Load-Time Catch-Up

**Files:**
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Sources/OGamePersistence/SaveEnvelope.swift`
- Modify: `Tests/OGamePersistenceTests/main.swift`

- [ ] **Step 1: Add persistence expectations**

Ensure saves preserve wall-clock date through `SaveEnvelope.lastSavedAt`. Add tests that a saved universe can be loaded and then catch-up can use `lastSavedAt` without schema drift.

- [ ] **Step 2: Implement load-time catch-up**

On app startup:

1. Load the save envelope.
2. Compute `Date().timeIntervalSince(envelope.lastSavedAt)`.
3. Run `OfflineSimulationEngine.catchUp`.
4. Save the caught-up universe with the current wall-clock date if catch-up mutated the universe and saving is safe.
5. Show a concise status summary.

Do not catch up after corrupt/unsupported saves; keep the existing protected load failure behavior.

- [ ] **Step 3: Add UI summary**

Show recent offline summary in the activity panel and event feed. Keep the first screen as the playable management shell.

- [ ] **Step 4: Run verification and commit**

Run:

```bash
swift build
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Commit:

```bash
git add Sources/OGameMac Sources/OGamePersistence Tests/OGamePersistenceTests/main.swift
git commit -m "feat: run offline catch-up on load"
```

## Milestone 3 Task 4: Verification Notes And Push

**Files:**
- Create: `docs/native-macos-ogame/milestone-2-3-verification.md`

- [ ] **Step 1: Write verification note**

Document:

- M2 economy loop.
- M3 offline catch-up and AI economic growth.
- Verification commands.
- Deferred Milestone 4/5 features.
- Known balancing limits.

- [ ] **Step 2: Final verification**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
python3 - <<'PY'
from pathlib import Path
patterns = ["XCT" + "est", "@test" + "able", ".test" + "Target", "swift " + "test"]
paths = [
    Path("Package.swift"),
    Path("Sources"),
    Path("Tests"),
    Path("docs/superpowers/plans/2026-05-07-native-macos-ogame-milestones-2-3.md"),
    Path("docs/native-macos-ogame/milestone-2-3-verification.md"),
]
for root in paths:
    files = [root] if root.is_file() else list(root.rglob("*"))
    for file in files:
        if file.is_file():
            text = file.read_text(errors="ignore")
            for pattern in patterns:
                if pattern in text:
                    raise SystemExit(f"Forbidden pattern {pattern!r} in {file}")
PY
git diff --name-status master...HEAD -- '*.php' '**/*.php' '*.tpl' '**/*.tpl'
git status --short --untracked-files=all
```

Expected:

- Both executable test runners pass.
- Build completes.
- Forbidden-pattern scan has no matches.
- PHP/template diff has no output.
- Worktree is clean.

- [ ] **Step 3: Commit and push**

Commit:

```bash
git add docs/native-macos-ogame/milestone-2-3-verification.md
git commit -m "docs: add milestone 2-3 verification notes"
git push -u origin feature/native-macos-ogame-m2-m3
```

## Final Integration

After all tasks pass review:

- Merge `feature/native-macos-ogame-m2-m3` into `master`.
- Run the full verification commands on `master`.
- Push `master` to `origin`.
- Remove the temporary worktree and merged feature branch.
