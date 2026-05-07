# Native macOS OGame Milestones 4-6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the first playable native macOS OGame sandbox with fleets, conflict, strategic victory, and Mac app polish.

**Architecture:** Keep `OGameCore` as the deterministic simulation module and `OGameMac` as presentation/orchestration only. Milestone 4 adds ship/defense construction, fleet missions, combat, reports, and debris. Milestone 5 adds star map strategy, rankings, exploration, and victory progress. Milestone 6 adds settings, save management, onboarding, and final verification/polish.

**Tech Stack:** Swift 5.9+, SwiftPM, SwiftUI, Foundation, executable Swift validation runners, JSON persistence.

---

## Scope Check

This plan finishes the first single-player sandbox slice. It is still intentionally smaller than a full MMO-grade OGame clone:

- No multiplayer.
- No alliances, moons, jump gates, missiles, ACS, or moon destruction.
- No exact formula parity with the PHP source.
- No notarized app distribution unless local signing is already configured.

The playable target is: build economy, construct ships/defenses, send fleets, scout/attack/recycle/explore/colonize, watch AI factions grow, pursue victory conditions, and manage saves/settings from a native macOS shell.

## File Structure

- `Sources/OGameCore/BalanceRules.swift`: add ship, defense, fleet, combat, and victory rule tables.
- `Sources/OGameCore/DomainModels.swift`: add ship/defense queues, debris fields, reports, score/victory/settings state, and backwards-compatible decoding.
- `Sources/OGameCore/QueueEngine.swift`: add ship and defense construction.
- `Sources/OGameCore/FleetEngine.swift`: launch fleets, validate cargo/fuel, resolve non-combat missions.
- `Sources/OGameCore/CombatEngine.swift`: deterministic combat rounds, loot, debris, and reports.
- `Sources/OGameCore/StrategicEngine.swift`: score/rankings, victory progress, exploration/colonization helpers.
- `Sources/OGameCore/SimulationEngine.swift`: wire ship/defense queues, fleet arrivals/returns, combat, exploration, victory, and AI strategic hooks.
- `Sources/OGameCore/StarterUniverseFactory.swift`: add neutral planets/debris-ready map and richer AI starting state.
- `Sources/OGameMac/AppModel.swift`: expose shipbuilding, fleet launch, star map, victory, settings, and save-management actions.
- `Sources/OGameMac/ContentView.swift`: add fleet, star map, reports, victory, settings/onboarding/save-management views.
- `Sources/OGamePersistence/SaveEnvelope.swift`: persist user settings if needed.
- `Sources/OGamePersistence/JSONSaveRepository.swift`: save slot/list/backup helpers if needed.
- `Tests/OGameCoreTests/main.swift`: cover fleet, combat, strategic, victory, and settings-adjacent core behavior.
- `Tests/OGamePersistenceTests/main.swift`: cover save slots/settings/schema round trips.
- `docs/native-macos-ogame/milestone-4-6-verification.md`: final verification note.

## Milestone 4 Task 1: Ship, Defense, And Construction Rules

**Files:**
- Modify: `Sources/OGameCore/BalanceRules.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/QueueEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`
- Modify: `Tests/OGamePersistenceTests/main.swift`

- [ ] **Step 1: Add failing tests**

Add executable-runner tests proving:

- `RuleSet.fastSkirmish` has rules for all current `ShipKind` and `DefenseKind` cases.
- Ship and defense rules encode as raw-value keyed JSON objects.
- `Planet.shipBuildQueue` and `Planet.defenseBuildQueue` round-trip and decode missing old-save fields as empty arrays.
- Starting a ship build subtracts resources, creates a queue item, and completion increments `shipInventory`.
- Starting a defense build subtracts resources, creates a queue item, and completion increments `defenseInventory`.
- Invalid cost/duration rules do not mutate.

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Expected: fail before implementation because ship/defense build queues and rules are missing.

- [ ] **Step 2: Implement rules and queues**

Add:

- `ShipRule`
- `DefenseRule`
- `UnitBuildQueueItem`
- `Planet.shipBuildQueue`
- `Planet.defenseBuildQueue`
- `RuleSet.shipRules`
- `RuleSet.defenseRules`
- `QueueEngine.startShipBuild(on:in:kind:quantity:)`
- `QueueEngine.startDefenseBuild(on:in:kind:quantity:)`

Use one active ship queue and one active defense queue per planet for this first version.

- [ ] **Step 3: Wire completion**

Update `QueueEngine.completeDueItems(in:)` so due ship/defense queues update inventories, remove queue entries, and append deterministic economy events.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests
git commit -m "feat: add ship and defense construction"
```

## Milestone 4 Task 2: Fleet Launch, Travel, Cargo, And Non-Combat Missions

**Files:**
- Create: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/BalanceRules.swift`
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing tests**

Add tests proving:

- Launching a fleet removes ships and cargo from origin planet.
- Invalid launch fails without mutation when ships/cargo are unavailable.
- Travel time is deterministic from coordinates and fleet speed rules.
- Transport mission delivers cargo and returns ships.
- Recycling mission collects debris from target planet.
- Exploration mission creates a deterministic exploration event/reward.
- Colonization mission claims an unowned planet when a colony ship is present.
- Fleet returns restore ships/cargo to origin.

Run:

```bash
swift run OGameCoreTests
```

Expected: fail before implementation because `FleetEngine` is missing.

- [ ] **Step 2: Implement fleet rules and launch**

Add fleet rule data:

- speed
- cargo capacity
- fuel cost
- attack/shield/hull placeholders for combat task

Implement `FleetEngine.launchFleet(...) -> FleetLaunchResult` with explicit failure cases:

- missing origin
- missing target
- missing owner
- insufficient ships
- insufficient cargo
- insufficient fuel
- invalid mission

- [ ] **Step 3: Implement non-combat arrival and return**

Implement `FleetEngine.resolveDueFleets(in:)` for transport, recycle, explore, colonize, and returning phases. Keep attack/espionage placeholders returning deterministic events until Task 3/4.

- [ ] **Step 4: Wire simulation**

Update `SimulationEngine.tick` so due fleet arrivals and returns resolve after queue completion and before victory checks.

- [ ] **Step 5: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add fleet launch and missions"
```

## Milestone 4 Task 3: Espionage, Combat, Debris, And Battle Reports

**Files:**
- Create: `Sources/OGameCore/CombatEngine.swift`
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing tests**

Add tests proving:

- Espionage mission creates an intelligence event/report without mutating hidden player state incorrectly.
- Attack mission resolves deterministic combat from ship/defense stats.
- Winner receives bounded loot based on surviving cargo.
- Destroyed ships/defenses generate debris on the defending planet.
- Defense partially recovers deterministically.
- Battle report includes attacker, defender, before/after fleets/defenses, losses, loot, and debris.
- Same seed/state produces same combat result.

Run:

```bash
swift run OGameCoreTests
```

Expected: fail before implementation because combat reports are missing.

- [ ] **Step 2: Add report models**

Add `BattleReport`, `EspionageReport`, or compact report payload types stored on `GameEvent` or separate `Universe.reports`.

Prefer a small serializable `Report` model:

- id
- time
- kind
- title
- summary
- participants
- loot/debris/losses

- [ ] **Step 3: Implement deterministic combat**

Use a bounded first-version combat model:

- Calculate attack, shield, and hull totals from ship/defense rules and faction tech.
- Apply deterministic seeded variation from universe seed, fleet id, and battle time.
- Convert losses into proportional inventory reductions.
- Generate debris from destroyed metal/crystal value.
- Recover a portion of defenses.

- [ ] **Step 4: Wire attack and espionage missions**

Update `FleetEngine.resolveDueFleets(in:)` to call `CombatEngine` for attack and espionage.

- [ ] **Step 5: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add combat and reports"
```

## Milestone 4 Task 4: Fleet And Conflict UI

**Files:**
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`

- [ ] **Step 1: Add app actions**

Expose:

- ship/defense build actions
- fleet launch action
- selected origin/target helpers
- mission availability helpers
- recent report helpers

Actions should use core engines, update status, and save when safe.

- [ ] **Step 2: Add SwiftUI surfaces**

Add/extend views:

- Shipyard panel with ship and defense queues.
- Fleet dispatch panel with mission, origin, target, ships, cargo.
- Active fleets list.
- Reports panel for combat/espionage/exploration.

Keep the first screen a playable management shell with native macOS density.

- [ ] **Step 3: Verify and commit**

Run:

```bash
swift build
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Commit:

```bash
git add Sources/OGameMac
git commit -m "feat: add fleet and conflict UI"
```

## Milestone 5 Task 1: Star Map, Rankings, And Victory State

**Files:**
- Create: `Sources/OGameCore/StrategicEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/StarterUniverseFactory.swift`
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing tests**

Add tests proving:

- Starter universe includes player, AI, and neutral planets for colonization/exploration.
- `StrategicEngine.rankings(in:)` scores economy, fleet, research, planets, defenses, and victory progress.
- Victory status triggers economy, technology, domination, and exploration routes.
- Continuing after victory keeps simulation ticking.
- Rankings/victory round-trip through JSON.

Run:

```bash
swift run OGameCoreTests
```

Expected: fail before implementation because strategic state is missing.

- [ ] **Step 2: Add strategic models**

Add:

- `FactionScore`
- `VictoryRoute`
- `VictoryProgress`
- `VictoryState`
- exploration progress fields where needed

Use backwards-compatible defaults for old saves.

- [ ] **Step 3: Implement strategic engine**

Compute:

- economy score from building levels/resources/production
- fleet score from ship inventory/active fleets
- research score from technology levels
- domination progress from owned/neutral/enemy planets
- exploration progress from exploration events/progress
- victory state from fastest completed route

- [ ] **Step 4: Wire simulation**

Update `SimulationEngine.tick` to refresh victory/rankings after core resolution.

- [ ] **Step 5: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add strategic rankings and victory"
```

## Milestone 5 Task 2: Exploration And Diplomacy-Lite

**Files:**
- Modify: `Sources/OGameCore/StrategicEngine.swift`
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing tests**

Add tests proving:

- Exploration missions increment exploration progress and can discover resources/debris/neutral targets.
- Factions track simple relation posture: neutral, wary, hostile, pressured.
- Attacks shift relations toward hostile; transports/exploration do not.
- AI can use relation/threat memory later without reading hidden player state.

Run:

```bash
swift run OGameCoreTests
```

Expected: fail before implementation because relation/exploration state is missing.

- [ ] **Step 2: Implement exploration/relation models**

Add:

- `FactionRelation`
- `RelationPosture`
- `ExplorationRecord` or compact fields on `Faction`

Decode old saves with neutral/default values.

- [ ] **Step 3: Wire mission effects**

Update fleet mission resolution so exploration and attacks update the new strategic state and emit event summaries.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add exploration and faction relations"
```

## Milestone 5 Task 3: Strategic UI

**Files:**
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`

- [ ] **Step 1: Add app helpers**

Expose:

- star map planet sections
- faction rankings
- victory progress
- relation summaries
- exploration summaries

- [ ] **Step 2: Add SwiftUI strategic views**

Add:

- Star map view with owned, AI, neutral, debris, and active fleet indicators.
- Rankings view.
- Victory progress view.
- Faction relation summary.

Keep visuals 2D and inspectable; no 3D scene is required.

- [ ] **Step 3: Verify and commit**

Run:

```bash
swift build
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Commit:

```bash
git add Sources/OGameMac
git commit -m "feat: add strategic sandbox UI"
```

## Milestone 6 Task 1: Settings, Save Management, And Onboarding

**Files:**
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGamePersistence/JSONSaveRepository.swift`
- Modify: `Sources/OGamePersistence/SaveEnvelope.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Tests/OGamePersistenceTests/main.swift`

- [ ] **Step 1: Add failing persistence tests**

Add tests proving:

- Save slots can be listed.
- Save slots reject path traversal names.
- Creating backup files preserves current autosave.
- Settings round-trip with save envelope.

Run:

```bash
swift run OGamePersistenceTests
```

Expected: fail before implementation because save management/settings are missing.

- [ ] **Step 2: Implement settings and save slots**

Add:

- `GameSettings`
- offline intensity
- game speed
- autosave enabled flag
- difficulty
- save slot listing/backup/delete helpers

Maintain JSON schema compatibility.

- [ ] **Step 3: Add onboarding and settings UI**

Add:

- first-launch onboarding panel/section
- settings surface
- save management surface
- explicit backup/delete actions with safe status messages

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift build
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Commit:

```bash
git add Sources Tests
git commit -m "feat: add settings and save management"
```

## Milestone 6 Task 2: Final Polish, Performance Guardrails, And Documentation

**Files:**
- Modify: `Sources/OGameCore/OfflineSimulationEngine.swift`
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Create: `docs/native-macos-ogame/milestone-4-6-verification.md`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add final stress tests**

Add tests proving:

- 24-hour offline catch-up with AI/fleets completes within bounded chunks.
- Event feed is capped or summarized.
- Victory can trigger and simulation can continue.
- Save/load after fleets/reports/settings round-trips.

- [ ] **Step 2: Add UI polish**

Tighten:

- text fitting
- disabled states
- keyboard command labels
- empty states
- event/report grouping
- victory banner

- [ ] **Step 3: Write verification note**

Create `docs/native-macos-ogame/milestone-4-6-verification.md` covering:

- fleet/conflict
- strategic sandbox
- settings/save management
- verification commands
- known simplifications

- [ ] **Step 4: Final verification and commit**

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
    Path("docs/superpowers/plans/2026-05-07-native-macos-ogame-milestones-4-6.md"),
    Path("docs/native-macos-ogame/milestone-4-6-verification.md"),
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

Commit:

```bash
git add Sources Tests docs/native-macos-ogame/milestone-4-6-verification.md
git commit -m "docs: finish milestone 4-6 verification"
```

## Final Integration

After all tasks pass review:

- Push `feature/native-macos-ogame-m4-m6`.
- Merge into `master`.
- Run full verification on `master`.
- Push `master`.
- Remove the temporary worktree and merged local feature branch.
