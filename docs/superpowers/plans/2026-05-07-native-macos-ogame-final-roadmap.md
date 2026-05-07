# Native macOS OGame Final Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current playable native macOS sandbox into a polished, release-ready fast single-player OGame-inspired strategy game.

**Architecture:** Keep `OGameCore` as the deterministic simulation module, `OGamePersistence` as the local save/migration boundary, and `OGameMac` as presentation and app orchestration. The remaining work should improve depth, AI agency, balance, UI maintainability, and Mac release readiness without importing or wrapping the legacy PHP app.

**Tech Stack:** Swift 5.9+, SwiftPM, SwiftUI for macOS, Foundation, JSON persistence, executable validation runners, local shell-based release tooling.

---

## Current Distance To Final

The project is now a strong playable vertical slice, not yet a polished final release.

- If the target is a private playable prototype: about 80% complete.
- If the target is a shippable single-player macOS v1: about 60% complete.
- If the target is a broad OGame-like endgame with moons, missiles, late-game economy, polished assets, packaging, and balance passes: about 45% complete.

## Already Complete

- Native SwiftPM structure with `OGameCore`, `OGamePersistence`, and `OGameMac`.
- Resources, energy, buildings, research, queues, offline catch-up, AI economic growth, and local saves.
- Ship and defense construction, fleet launch, transport, recycle, explore, colonize, attack, espionage, returns, reports, debris, and relation memory.
- Star map, rankings, victory routes, exploration records, diplomacy-lite UI, settings, autosave controls, backups, onboarding, and verification docs.
- Core and persistence executable validation runners.

## Main Remaining Gaps

- AI factions still mostly build economy and research; they do not yet behave like active strategic rivals with shipbuilding, scouting, attacks, colonization, recycling, and threat-aware decisions.
- The rule set is compact; it lacks a fuller progression curve, tech gates, storage upgrades as first-class buildings, production controls, nanite-style acceleration, missiles, moons, and late-game objectives.
- Balance is not playtest-calibrated. There is no scenario runner that measures time-to-first-fleet, time-to-first-conflict, victory timing, AI aggression, or resource inflation.
- The macOS UI is feature-complete enough for a sandbox, but large view/model files need refactoring before sustained development.
- Persistence supports current JSON saves and backups, but release-grade migrations, export/import, and corruption recovery are still thin.
- The app is not packaged, signed, notarized, iconed, or distributed as a polished macOS app.
- Accessibility, localization, sound, visual identity, help, and player-facing documentation are minimal.

## Final Scope Definition

The recommended final v1 should remain single-player and deterministic. Multiplayer, exact PHP formula parity, public server deployment, and old browser UI recreation stay out of scope.

Final v1 should include:

- Active AI rivals that scout, colonize, build fleets, attack weak targets, recycle debris, and react to player aggression.
- A larger but still curated fast-skirmish ruleset with visible tech gates and a smoother early/mid/late pacing curve.
- Release-grade saves and migrations.
- A maintainable SwiftUI codebase split into smaller view files.
- A packaged macOS app with icon, signing guidance, release notes, and a repeatable verification script.
- A documented playtest and balance process.

## File Structure

- `Sources/OGameCore/AIStrategyEngine.swift`: new strategic AI decision engine for shipbuilding, defense, scouting, fleet missions, colonization, and threat response.
- `Sources/OGameCore/AIEconomyEngine.swift`: keep economy/research decision logic; call from or be called by `AIStrategyEngine`.
- `Sources/OGameCore/BalanceRules.swift`: expand rules, tech gates, storage/nanite/missile/moon-adjacent values, and balance constants.
- `Sources/OGameCore/DomainModels.swift`: add tech gates, production settings, AI memory, migration-safe late-game fields, scenario metrics, and release save metadata.
- `Sources/OGameCore/StrategicEngine.swift`: add balance metrics, richer victory progress, and AI-visible intelligence helpers.
- `Sources/OGameCore/SimulationEngine.swift`: coordinate AI economy and AI strategic decisions on predictable intervals.
- `Sources/OGameCore/OfflineSimulationEngine.swift`: apply offline intensity to strategic AI and cap destructive chains.
- `Sources/OGamePersistence/JSONSaveRepository.swift`: add export/import, backup verification, save integrity checks, and migration entry points.
- `Sources/OGamePersistence/SaveEnvelope.swift`: add migration metadata and release version handling.
- `Sources/OGameMac/AppModel.swift`: refactor into smaller presentation models and add release-grade actions.
- `Sources/OGameMac/ContentView.swift`: split into focused SwiftUI view files.
- `Sources/OGameMac/Views/*.swift`: new focused view files for dashboard, planet, fleet, strategy, reports, settings, onboarding, and shared components.
- `Sources/OGameMac/Assets.xcassets` or SwiftPM resource folder: app icon and lightweight visual assets if the project switches to an app bundle workflow.
- `Tests/OGameCoreTests/main.swift`: add AI strategy, balance, migration, late-game, and scenario tests.
- `Tests/OGamePersistenceTests/main.swift`: add migration, export/import, corruption, backup, and settings tests.
- `scripts/verify-release.sh`: run all release checks with allowed validation commands.
- `docs/native-macos-ogame/final-release-checklist.md`: user-facing and developer-facing release checklist.
- `docs/native-macos-ogame/balance-playtest-guide.md`: repeatable playtest scenarios and target pacing.

## Milestone 7: Active AI Rivals

### Task 1: AI Ship, Defense, And Fleet Production

**Files:**
- Create: `Sources/OGameCore/AIStrategyEngine.swift`
- Modify: `Sources/OGameCore/AIEconomyEngine.swift`
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing AI production tests**

Add executable-runner tests named:

- `testAIStrategyBuildsShipsForRaiderFactions`
- `testAIStrategyBuildsDefensesForThreatenedFactions`
- `testAIStrategyDoesNotReadHiddenPlayerFleetState`

Expected first run:

```bash
swift run OGameCoreTests
```

The new tests should fail because `AIStrategyEngine` does not exist.

- [ ] **Step 2: Implement AI production candidates**

Create `AIStrategyEngine.makeStrategicDecisions(in:)` with:

- Raider factions prefer `lightFighter`, `smallCargo`, and `espionageProbe` when shipyard exists.
- Miner factions prefer `rocketLauncher` and `lightLaser` when threat memory is nonzero.
- Expansionist factions prefer `colonyShip` when there are known neutral targets.
- Decisions use only owned planets, public rankings, relation memory, and faction-scoped exploration records.

- [ ] **Step 3: Wire strategic AI into simulation**

Update `SimulationEngine.tick` so AI economic and AI strategic decisions run at separate deterministic intervals. Keep economic decisions first, then strategic decisions, then strategic state refresh.

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
git commit -m "feat: add AI strategic production"
```

### Task 2: AI Scouting, Expansion, Attack, And Recycling

**Files:**
- Modify: `Sources/OGameCore/AIStrategyEngine.swift`
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/StrategicEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing AI fleet mission tests**

Add tests named:

- `testAIRaiderLaunchesEspionageBeforeAttack`
- `testAIExpansionistColonizesKnownNeutralWorld`
- `testAIRecyclerCollectsKnownDebris`
- `testAIAttackUsesKnownWeakTargetOnly`

Expected first run:

```bash
swift run OGameCoreTests
```

The tests should fail until AI fleet mission decisions exist.

- [ ] **Step 2: Implement mission scoring**

Add mission scoring that:

- Uses `StrategicEngine.explorationRecords(for:in:)` for known targets.
- Uses relation posture and report history for aggression.
- Avoids attacks against unknown targets unless difficulty permits.
- Launches fleets through `FleetEngine.launchFleet` so core validation remains shared.

- [ ] **Step 3: Add offline caps**

Update `OfflineSimulationEngine` so aggressive AI actions during catch-up are capped by chunk count and event pressure. Preserve victory events and summary behavior.

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
git commit -m "feat: add AI fleet missions"
```

### Task 3: AI Difficulty And Imperfect Intelligence

**Files:**
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/AIStrategyEngine.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing difficulty tests**

Add tests named:

- `testEasyAIDoesNotAttackWithoutReport`
- `testHardAICanUseRankingsButNotHiddenInventory`
- `testThreatMemoryChangesDefensivePosture`

- [ ] **Step 2: Implement difficulty policy**

Add a `AIDifficultyPolicy` derived from `GameSettings.Difficulty`:

- Easy: scout before attack, lower attack frequency, higher defense weight.
- Standard: scout before major attacks, moderate expansion.
- Hard: uses rankings and relation memory more aggressively, but still avoids exact hidden inventories.

- [ ] **Step 3: Surface difficulty behavior in settings**

Update Settings copy so difficulty describes AI behavior, not raw stat bonuses.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources Tests
git commit -m "feat: add AI difficulty policy"
```

## Milestone 8: OGame Depth And Pacing

### Task 4: Tech Gates And Expanded Progression

**Files:**
- Modify: `Sources/OGameCore/BalanceRules.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/QueueEngine.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing tech gate tests**

Add tests named:

- `testShipBuildRequiresConfiguredTechnologyGate`
- `testDefenseBuildRequiresConfiguredBuildingGate`
- `testUIHelpersExposeLockedReason`

- [ ] **Step 2: Add rule gate models**

Add:

- `RuleRequirement`
- `ShipRule.requirements`
- `DefenseRule.requirements`
- `BuildingRule.requirements`
- `ResearchRule.requirements`

Decode missing requirements as empty arrays.

- [ ] **Step 3: Enforce gates in queue engine**

Extend `QueueResult` with `missingRequirement` and keep old cases stable where possible. Reject locked builds without resource mutation.

- [ ] **Step 4: Show locked reasons in UI**

Show compact locked rows in planet and research views. Keep disabled buttons and concise reason text.

- [ ] **Step 5: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources Tests
git commit -m "feat: add tech gates"
```

### Task 5: Production Controls, Storage, And Acceleration

**Files:**
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/EconomyEngine.swift`
- Modify: `Sources/OGameCore/QueueEngine.swift`
- Modify: `Sources/OGameCore/BalanceRules.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing production and acceleration tests**

Add tests named:

- `testPlanetProductionSettingsScaleMineOutputAndEnergyUse`
- `testStorageBuildingsIncreaseStorageCaps`
- `testRoboticsAndNaniteStyleAccelerationShortensBuildDurations`

- [ ] **Step 2: Add production settings**

Add `Planet.productionSettings: [BuildingKind: Double]` with missing values defaulting to `1.0`. Clamp decoded values to `0.0...1.0`.

- [ ] **Step 3: Add storage and acceleration rules**

Expand building rules with storage and acceleration effects. Keep values fast-session friendly.

- [ ] **Step 4: Add UI controls**

Add compact steppers or sliders for mine production percentages in the planet economy panel. Show energy impact before saving.

- [ ] **Step 5: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources Tests
git commit -m "feat: add production controls"
```

### Task 6: Late-Game Strategic Systems

**Files:**
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/BalanceRules.swift`
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/CombatEngine.swift`
- Modify: `Sources/OGameCore/StrategicEngine.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Add failing late-game tests**

Add tests named:

- `testMoonChanceCanCreateMoonFromLargeDebrisBattle`
- `testMissileStrikeDamagesDefensesWithoutLoot`
- `testLateGameObjectiveContributesToTechnologyVictory`

- [ ] **Step 2: Add compact moon model**

Add `Moon` as an optional planet satellite with fields:

- id
- name
- createdAt
- buildingLevels
- debrisOriginReportID

Decode missing moon as nil.

- [ ] **Step 3: Add missile mission**

Add a compact missile strike action as a core action rather than a fleet mission if that keeps the model simpler. It should consume missiles, damage defenses, emit a report, and never loot resources.

- [ ] **Step 4: Update UI**

Show moon presence and missile controls only when unlocked. Keep empty states explicit.

- [ ] **Step 5: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources Tests
git commit -m "feat: add late-game systems"
```

## Milestone 9: Balance Lab And Playtest Loop

### Task 7: Scenario Runner And Balance Metrics

**Files:**
- Create: `Sources/OGameCore/BalanceScenarioRunner.swift`
- Modify: `Sources/OGameCore/StrategicEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`
- Create: `docs/native-macos-ogame/balance-playtest-guide.md`

- [ ] **Step 1: Add failing scenario tests**

Add tests named:

- `testBalanceScenarioReachesFirstFleetWithinTargetWindow`
- `testBalanceScenarioReachesFirstConflictWithinTargetWindow`
- `testBalanceScenarioVictoryOccursWithinFastRunWindow`

- [ ] **Step 2: Implement scenario runner**

Create `BalanceScenarioRunner.run(seed:duration:settings:)` returning:

- firstShipAt
- firstFleetLaunchAt
- firstCombatAt
- firstColonizationAt
- victoryAt
- eventCount
- reportCount
- finalRankings

- [ ] **Step 3: Add balance guide**

Write target windows:

- First ship: 10 to 25 minutes simulated.
- First fleet launch: 20 to 45 minutes simulated.
- First combat or espionage: 45 to 90 minutes simulated.
- First victory: 2 to 4 hours simulated for fast-skirmish.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources Tests docs/native-macos-ogame/balance-playtest-guide.md
git commit -m "test: add balance scenario runner"
```

### Task 8: Balance Tuning Pass

**Files:**
- Modify: `Sources/OGameCore/BalanceRules.swift`
- Modify: `Sources/OGameCore/AIStrategyEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`
- Modify: `docs/native-macos-ogame/balance-playtest-guide.md`

- [ ] **Step 1: Run scenario baselines**

Run:

```bash
swift run OGameCoreTests
```

Record scenario outputs in `balance-playtest-guide.md`.

- [ ] **Step 2: Adjust fast-skirmish pacing**

Tune:

- early mine income
- ship costs
- fuel costs
- AI strategic intervals
- victory thresholds
- offline event caps

- [ ] **Step 3: Add regression assertions**

Make scenario tests assert target windows with tolerances, not exact timestamps.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources Tests docs/native-macos-ogame/balance-playtest-guide.md
git commit -m "balance: tune fast skirmish pacing"
```

## Milestone 10: SwiftUI Refactor And Product Polish

### Task 9: Split Large UI Files

**Files:**
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Create: `Sources/OGameMac/Views/DashboardViews.swift`
- Create: `Sources/OGameMac/Views/PlanetViews.swift`
- Create: `Sources/OGameMac/Views/FleetViews.swift`
- Create: `Sources/OGameMac/Views/StrategyViews.swift`
- Create: `Sources/OGameMac/Views/ResearchViews.swift`
- Create: `Sources/OGameMac/Views/SettingsViews.swift`
- Create: `Sources/OGameMac/Views/SharedViews.swift`

- [ ] **Step 1: Move views without behavior changes**

Move existing private SwiftUI view structs into focused files. Keep names and body output stable.

- [ ] **Step 2: Split presentation summaries**

Move summary structs from `AppModel.swift` into `PresentationModels.swift` if they are pure UI data.

- [ ] **Step 3: Verify after each moved section**

Run after each file extraction:

```bash
swift build
```

- [ ] **Step 4: Commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameMac
git commit -m "refactor: split macOS views"
```

### Task 10: UX, Accessibility, And Help

**Files:**
- Modify: `Sources/OGameMac/Views/*.swift`
- Modify: `Sources/OGameMac/OGameMacApp.swift`
- Create: `docs/native-macos-ogame/player-guide.md`

- [ ] **Step 1: Add navigation and command review**

Add command menu entries for:

- Save
- New Game
- Advance time
- Open Settings
- Open Fleets
- Open Star Map

- [ ] **Step 2: Improve accessibility labels**

Add labels for icon-only or compact controls in shipyard, fleet dispatch, star map, and save management.

- [ ] **Step 3: Write player guide**

Create `player-guide.md` with:

- first 15 minutes
- how saves work
- how exploration and visibility work
- how victory routes work
- how to continue after victory

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift build
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Commit:

```bash
git add Sources/OGameMac docs/native-macos-ogame/player-guide.md
git commit -m "docs: add player guide and app commands"
```

## Milestone 11: Save Migrations And Release Hardening

### Task 11: Save Migration And Integrity

**Files:**
- Modify: `Sources/OGamePersistence/SaveEnvelope.swift`
- Modify: `Sources/OGamePersistence/JSONSaveRepository.swift`
- Create: `Sources/OGamePersistence/SaveMigrator.swift`
- Modify: `Tests/OGamePersistenceTests/main.swift`

- [ ] **Step 1: Add migration tests**

Add tests named:

- `testMigratesSchemaOneToCurrentSchema`
- `testCorruptSaveDoesNotOverwriteAutosave`
- `testExportImportPreservesEnvelopeAndSettings`
- `testBackupIntegrityCheckRejectsWrongSchema`

- [ ] **Step 2: Implement migrator**

Create `SaveMigrator.migrate(_:)` with deterministic migrations from schema 1 to current schema. Keep unknown future schema rejection.

- [ ] **Step 3: Add export/import helpers**

Add repository methods:

- `exportCurrentSave(to:)`
- `importSave(from:as:)`
- `validateBackup(named:)`

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGamePersistenceTests
swift run OGameCoreTests
swift build
```

Commit:

```bash
git add Sources/OGamePersistence Tests/OGamePersistenceTests/main.swift
git commit -m "feat: add save migrations"
```

### Task 12: Release Packaging

**Files:**
- Create: `scripts/verify-release.sh`
- Create: `scripts/package-macos.sh`
- Create: `docs/native-macos-ogame/final-release-checklist.md`
- Modify: `Package.swift` if resources are added.

- [ ] **Step 1: Add release verification script**

Create `scripts/verify-release.sh` that runs:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Then run the split-string forbidden pattern check and PHP/TPL diff check.

- [ ] **Step 2: Add packaging script**

Create `scripts/package-macos.sh` that:

- builds `OGameMac`
- copies the executable into a staging folder
- includes release docs
- prints signing and notarization instructions when local identities are unavailable

- [ ] **Step 3: Add final checklist**

Write `final-release-checklist.md` with:

- verification commands
- manual playtest path
- save migration check
- offline catch-up check
- packaging check
- known simplifications

- [ ] **Step 4: Verify and commit**

Run:

```bash
bash scripts/verify-release.sh
```

Commit:

```bash
git add scripts docs/native-macos-ogame/final-release-checklist.md Package.swift
git commit -m "build: add release packaging scripts"
```

## Milestone 12: Release Candidate And Playtest Fixes

### Task 13: Manual Playtest Pass

**Files:**
- Modify: `docs/native-macos-ogame/balance-playtest-guide.md`
- Modify: `docs/native-macos-ogame/final-release-checklist.md`
- Modify: source files only for playtest fixes.

- [ ] **Step 1: Run the release playtest**

Play one fresh run and record:

- first mine upgrade time
- first ship time
- first scout time
- first combat time
- first colony time
- first victory route
- confusing UI moments
- save/load observations

- [ ] **Step 2: Fix release-blocking issues**

For each bug, add a focused regression test before changing code.

- [ ] **Step 3: Verify**

Run:

```bash
bash scripts/verify-release.sh
```

- [ ] **Step 4: Commit**

Commit each fix separately with messages such as:

```bash
git commit -m "fix: preserve fleet cargo during playtest scenario"
```

### Task 14: Release Candidate Tag

**Files:**
- Modify: `docs/native-macos-ogame/final-release-checklist.md`

- [ ] **Step 1: Run final verification**

Run:

```bash
bash scripts/verify-release.sh
```

- [ ] **Step 2: Update release checklist**

Mark each completed release check with date and commit SHA.

- [ ] **Step 3: Create release commit**

Commit:

```bash
git add docs/native-macos-ogame/final-release-checklist.md
git commit -m "docs: mark release candidate verification"
```

- [ ] **Step 4: Tag release candidate**

Create:

```bash
git tag native-ogame-v1-rc1
```

Push:

```bash
git push origin master native-ogame-v1-rc1
```

## Execution Order

Recommended order:

1. Milestone 7: Active AI Rivals
2. Milestone 9: Balance Lab And Playtest Loop
3. Milestone 8: OGame Depth And Pacing
4. Milestone 10: SwiftUI Refactor And Product Polish
5. Milestone 11: Save Migrations And Release Hardening
6. Milestone 12: Release Candidate And Playtest Fixes

The balance lab should move before deep late-game work if AI behavior feels unstable.

## Final Acceptance Criteria

Final v1 is ready when:

- A fresh run reaches scouting, fleet conflict, expansion, and one victory route without manual state editing.
- AI factions build ships, scout, attack, expand, and recycle through public or faction-known information.
- A 4-hour fast-skirmish scenario remains deterministic and finishes within bounded event/report limits.
- Saves migrate, export, import, backup, delete, and recover without data loss in tested paths.
- The app can be built, verified, packaged, and handed to a user with clear docs.
- The macOS UI is split into maintainable files and has no known hidden-intel leaks.
- `bash scripts/verify-release.sh` passes on `master`.

