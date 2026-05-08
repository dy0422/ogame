# OGame Mechanics Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deepen the current native macOS single-player OGame into a more strategic, better balanced, fast-paced offline universe simulation while keeping the existing SwiftUI app and deterministic core architecture.

**Architecture:** Keep `OGameCore` as the deterministic rules and simulation layer, `OGamePersistence` as the save/migration boundary, and `OGameMac` as the presentation layer. Add small focused core helpers for technology effects, automation policy, intel, exploration events, battle simulation, moon actions, and balance metrics instead of expanding one large engine file.

**Tech Stack:** Swift 5.9, SwiftPM, SwiftUI for macOS, Foundation JSON persistence, executable test runners (`OGameCoreTests`, `OGamePersistenceTests`, `OGameBalanceTool`), local `.app` verification script.

---

## Scope

This plan is for the next full mechanics pass, not a final distribution release. It should preserve existing saves through migration-safe defaults and should not remove any current playable systems.

Out of scope for this pass:

- Multiplayer or server hosting.
- Exact PHP/browser UI recreation.
- Paid store, online accounts, or network services.
- Replacing SwiftPM with an Xcode-only project.

## Current Baseline

Already present in the project:

- Real-time and offline simulation.
- Resources, energy, storage, temperature, solar satellites, fusion reactor.
- Buildings, research, ships, defense, missiles, queues.
- Player auto-upgrade toggle.
- Fleet missions: transport, recycle, explore, colonize, attack, espionage.
- Combat reports, debris, defense recovery, moon creation, missile interception.
- AI economy and strategic fleets.
- Rankings and economy/technology/domination/exploration victory routes.
- Balance scenario runner and tests for first ship, first combat, and fast victory.

Primary gaps this plan addresses:

- Several technologies have weak or missing gameplay effects.
- Auto-upgrade is a fixed helper instead of a configurable strategy system.
- Fleet play lacks slot pressure, recall, speed choice, and richer risk feedback.
- Espionage and exploration need information tiers and event variety.
- Combat needs a reusable preview/simulation model and closer OGame-like rounds.
- Moon facilities exist as content but need actual sensor/jump gameplay.
- AI and balance tests need to understand the new mechanics.

---

## File Map

- Create: `Sources/OGameCore/TechnologyEffects.swift`
  - Centralizes fleet slots, drive speed multipliers, research speed factors, espionage tiers, and energy tech helpers.
- Create: `Sources/OGameCore/AutomationPolicy.swift`
  - Defines player automation strategy, reserve rules, queue-depth limits, and unit-build permissions.
- Create: `Sources/OGameCore/IntelEngine.swift`
  - Resolves espionage report visibility, probe loss chance, and intel freshness.
- Create: `Sources/OGameCore/ExplorationEventEngine.swift`
  - Produces deterministic exploration outcomes: resource cache, debris, pirates, derelicts, and empty anomalies.
- Create: `Sources/OGameCore/BattleSimulationEngine.swift`
  - Runs battle previews and the authoritative round-based resolver used by `CombatEngine`.
- Create: `Sources/OGameCore/MoonEngine.swift`
  - Handles moon facility upgrades, sensor scans, and jump-gate transfers.
- Modify: `Sources/OGameCore/DomainModels.swift`
  - Adds migration-safe fields/enums for automation settings, fleet speed, intel tiers, exploration outcomes, battle rounds, and moon cooldowns.
- Modify: `Sources/OGameCore/BalanceRules.swift`
  - Adds drive mapping, rapid-fire metadata, moon facility limits, and adjusted fast-skirmish values.
- Modify: `Sources/OGameCore/QueueEngine.swift`
  - Applies research lab speed, automation queue-depth helpers, and moon facility queues.
- Modify: `Sources/OGameCore/FleetEngine.swift`
  - Adds fleet slot limits, speed percent, recall, fuel/ETA previews, and technology speed effects.
- Modify: `Sources/OGameCore/CombatEngine.swift`
  - Delegates attack resolution and preview math to `BattleSimulationEngine`.
- Modify: `Sources/OGameCore/AIStrategyEngine.swift`
  - Makes AI respect fleet slots, intel tiers, exploration events, battle previews, and moon systems.
- Modify: `Sources/OGameCore/AIEconomyEngine.swift`
  - Adjusts AI economy scoring for automation-style priorities and new technology effects.
- Modify: `Sources/OGameCore/StrategicEngine.swift`
  - Adds richer victory milestones and balance metric summaries.
- Modify: `Sources/OGameCore/BalanceScenarioRunner.swift`
  - Captures first espionage, first exploration event, first moon use, automation impact, and AI pressure.
- Modify: `Sources/OGameCore/SimulationEngine.swift`
  - Wires automation, AI, and strategic updates in a deterministic order.
- Modify: `Sources/OGameMac/AppModel.swift`
  - Exposes automation policy, fleet previews, battle previews, intel summaries, moon actions, and balance summaries.
- Modify: `Sources/OGameMac/ContentView.swift`
  - Adds settings controls and player-facing panels. Keep edits scoped; split views only when a touched section becomes hard to reason about.
- Modify: `Sources/OGameMac/Views/*.swift`
  - Add or extend focused SwiftUI surfaces where they already exist.
- Test: `Tests/OGameCoreTests/main.swift`
  - Main mechanics coverage.
- Test: `Tests/OGamePersistenceTests/main.swift`
  - Save/load and migration coverage.
- Update: `docs/native-macos-ogame/player-guide.md`
  - Player-facing rules guide.
- Update: `docs/native-macos-ogame/balance-playtest-guide.md`
  - Balance targets and scenario output interpretation.

---

## Phase 1: Core Rule Contracts And Technology Effects

### Task 1.1: Add Central Technology Effects

**Files:**
- Create: `Sources/OGameCore/TechnologyEffects.swift`
- Modify: `Sources/OGameCore/BalanceRules.swift`
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/QueueEngine.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

Add these test functions to `Tests/OGameCoreTests/main.swift`:

```swift
func testComputerTechnologyIncreasesFleetSlots() {
    let research = ResearchState(levels: [.computer: 3])
    requireEqual(TechnologyEffects.maxFleetSlots(for: research), 4, "Computer level 3 should allow four active fleet slots")
}

func testDriveTechnologyIncreasesMatchingShipSpeed() {
    let research = ResearchState(levels: [.combustionDrive: 4])
    let base = RuleSet.fastSkirmish.shipRules[.smallCargo]?.speed ?? 0
    let speed = TechnologyEffects.effectiveSpeed(for: .smallCargo, baseSpeed: base, research: research)
    require(speed > base, "Combustion drive should increase small cargo speed")
}

func testResearchLabSpeedsResearchDuration() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 101, playerName: "指挥官")
    universe.planets[0].resources = ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000)
    universe.planets[0].buildingLevels[.researchLab] = 4

    let result = QueueEngine.startResearch(for: universe.playerFactionID, in: &universe, technology: .energy)
    requireEqual(result, .queued, "Energy research should queue")
    let queued = universe.factions[0].researchQueue[0]
    let baseDuration = RuleSet.fastSkirmish.researchRules[.energy]?.baseDuration ?? 0
    require(queued.finishTime - queued.startTime < baseDuration, "Research lab should reduce research duration")
}
```

Run:

```bash
swift run OGameCoreTests
```

Expected: fail because `TechnologyEffects` does not exist and research duration is not lab-scaled.

- [ ] **Step 2: Implement `TechnologyEffects`**

Create `Sources/OGameCore/TechnologyEffects.swift`:

```swift
import Foundation

public enum TechnologyEffects {
    public static func level(_ kind: TechnologyKind, in research: ResearchState) -> Int {
        max(research.levels[kind] ?? 0, 0)
    }

    public static func maxFleetSlots(for research: ResearchState) -> Int {
        max(1, 1 + level(.computer, in: research))
    }

    public static func driveTechnology(for ship: ShipKind) -> TechnologyKind? {
        switch ship {
        case .smallCargo, .largeCargo, .recycler:
            return .combustionDrive
        case .lightFighter, .heavyFighter, .cruiser, .colonyShip, .bomber:
            return .impulseDrive
        case .battleship, .destroyer, .deathstar, .battlecruiser:
            return .hyperspaceDrive
        case .espionageProbe, .solarSatellite:
            return nil
        }
    }

    public static func effectiveSpeed(for ship: ShipKind, baseSpeed: Double, research: ResearchState) -> Double {
        guard baseSpeed.isFinite, baseSpeed > 0 else { return 0 }
        guard let drive = driveTechnology(for: ship) else { return baseSpeed }
        let bonusPerLevel: Double = drive == .hyperspaceDrive ? 0.30 : 0.20
        return baseSpeed * (1 + Double(level(drive, in: research)) * bonusPerLevel)
    }

    public static func researchSpeedFactor(for labLevel: Int) -> Double {
        max(1, 1 + Double(max(labLevel, 0)) * 0.10)
    }

    public static func espionageIntelTier(attacker: ResearchState, defender: ResearchState, probeCount: Int) -> Int {
        let techDelta = level(.espionage, in: attacker) - level(.espionage, in: defender)
        return min(max(1 + techDelta + max(probeCount, 0) / 2, 1), 5)
    }
}
```

- [ ] **Step 3: Wire speed and research duration**

Update `FleetEngine.travelDuration` to use owner research. Add a private overload that receives `ResearchState`, then make `launchFleet` pass the origin owner research. Keep the current public `travelDuration(from:to:ships:ruleSet:)` as a base-speed compatibility helper for UI previews that do not have a faction.

Update `QueueEngine.startResearch` and `researchTerms` so the payment planet's research lab level shortens duration:

```swift
let labLevel = normalizedLevel(universe.planets[planetIndex].buildingLevels[.researchLab] ?? 0)
guard let terms = researchTerms(rule: rule, targetLevel: targetLevel, labLevel: labLevel) else {
    return .missingRule
}
```

- [ ] **Step 4: Verify**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add technology effect contracts"
```

### Task 1.2: Migration-Safe Domain Additions

**Files:**
- Modify: `Sources/OGameCore/DomainModels.swift`
- Test: `Tests/OGameCoreTests/main.swift`
- Test: `Tests/OGamePersistenceTests/main.swift`

- [ ] **Step 1: Write migration tests**

Add tests that decode older JSON without the new fields:

```swift
func testFleetDecodesMissingSpeedPercentAsFullSpeed() throws {
    let json = """
    {
      "id": "00000000-0000-0000-0000-000000010001",
      "ownerID": "00000000-0000-0000-0000-000000010002",
      "mission": "transport",
      "origin": { "galaxy": 1, "system": 1, "position": 4 },
      "target": { "galaxy": 1, "system": 2, "position": 4 },
      "ships": { "smallCargo": 1 },
      "cargo": { "metal": 0, "crystal": 0, "deuterium": 0 },
      "launchTime": 0,
      "arrivalTime": 10,
      "returnTime": 20,
      "phase": "outbound"
    }
    """.data(using: .utf8)!
    let fleet = try JSONDecoder().decode(Fleet.self, from: json)
    requireApproxEqual(fleet.speedPercent, 1, "Old fleets should default to full speed")
}
```

- [ ] **Step 2: Add fields with defaults**

Add fields in `DomainModels.swift`:

- `Fleet.speedPercent: Double = 1`
- `Fleet.recalledAt: TimeInterval? = nil`
- `Report.intelTier: Int = 5`
- `Report.battleRounds: [BattleRoundSummary] = []`
- `GameSettings.autoUpgradePolicy: AutoUpgradePolicy = AutoUpgradePolicy()`
- `Moon.jumpGateReadyAt: TimeInterval = 0`

Clamp `speedPercent` to `0.1...1.0`; default invalid values to `1`.

- [ ] **Step 3: Verify**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Expected: all pass and old-save tests prove defaults.

- [ ] **Step 4: Commit**

```bash
git add Sources/OGameCore/DomainModels.swift Tests/OGameCoreTests/main.swift Tests/OGamePersistenceTests/main.swift
git commit -m "feat: add migration-safe mechanics fields"
```

---

## Phase 2: Player Automation And Queue Control

### Task 2.1: Add Automation Policy Model

**Files:**
- Create: `Sources/OGameCore/AutomationPolicy.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Test: `Tests/OGameCoreTests/main.swift`
- Test: `Tests/OGamePersistenceTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testAutomationPolicyDefaultsToBalancedEconomySafeMode() {
    let policy = AutoUpgradePolicy()
    requireEqual(policy.strategy, .balanced, "Default automation should be balanced")
    requireEqual(policy.resourceReserveRatio, 0.15, "Default automation should preserve a small reserve")
    requireEqual(policy.allowShipConstruction, false, "Default automation should not unexpectedly build fleets")
}

func testGameSettingsRoundTripsAutomationPolicy() throws {
    let settings = GameSettings(
        offlineIntensity: .normal,
        gameSpeed: 2,
        isAutosaveEnabled: true,
        difficulty: .standard,
        isAutoUpgradeEnabled: true,
        autoUpgradePolicy: AutoUpgradePolicy(strategy: .economy, resourceReserveRatio: 0.25)
    )
    let decoded = try JSONDecoder().decode(GameSettings.self, from: try JSONEncoder().encode(settings))
    requireEqual(decoded.autoUpgradePolicy.strategy, .economy, "Automation strategy should round-trip")
    requireApproxEqual(decoded.autoUpgradePolicy.resourceReserveRatio, 0.25, "Reserve ratio should round-trip")
}
```

- [ ] **Step 2: Implement policy**

Create `AutomationPolicy.swift`:

```swift
public enum AutoUpgradeStrategy: String, Codable, CaseIterable, Sendable {
    case balanced
    case economy
    case research
    case fleet
    case defense
    case lowRiskOffline
}

public struct AutoUpgradePolicy: Codable, Equatable, Sendable {
    public var strategy: AutoUpgradeStrategy
    public var resourceReserveRatio: Double
    public var maxBuildQueueDepthPerPlanet: Int
    public var maxResearchQueueDepth: Int
    public var allowShipConstruction: Bool
    public var allowDefenseConstruction: Bool
    public var allowMissileConstruction: Bool

    public init(
        strategy: AutoUpgradeStrategy = .balanced,
        resourceReserveRatio: Double = 0.15,
        maxBuildQueueDepthPerPlanet: Int = 3,
        maxResearchQueueDepth: Int = 3,
        allowShipConstruction: Bool = false,
        allowDefenseConstruction: Bool = false,
        allowMissileConstruction: Bool = false
    ) {
        self.strategy = strategy
        self.resourceReserveRatio = min(max(resourceReserveRatio.isFinite ? resourceReserveRatio : 0.15, 0), 0.80)
        self.maxBuildQueueDepthPerPlanet = max(1, min(maxBuildQueueDepthPerPlanet, 20))
        self.maxResearchQueueDepth = max(1, min(maxResearchQueueDepth, 20))
        self.allowShipConstruction = allowShipConstruction
        self.allowDefenseConstruction = allowDefenseConstruction
        self.allowMissileConstruction = allowMissileConstruction
    }
}
```

Add `autoUpgradePolicy` to `GameSettings` with old-save default.

- [ ] **Step 3: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Commit:

```bash
git add Sources/OGameCore Tests
git commit -m "feat: add automation policy model"
```

### Task 2.2: Upgrade Player Auto-Upgrade Engine

**Files:**
- Modify: `Sources/OGameCore/PlayerAutoUpgradeEngine.swift`
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testAutoUpgradeEconomyStrategyFillsMultipleBuildQueueItems() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 201, playerName: "指挥官")
    universe.planets[0].resources = ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000)
    let policy = AutoUpgradePolicy(strategy: .economy, maxBuildQueueDepthPerPlanet: 3)

    let result = PlayerAutoUpgradeEngine.makeDecisions(in: &universe, policy: policy)

    require(result.queuedBuildings >= 2, "Economy automation should fill more than one building queue slot")
    require(universe.planets[0].buildQueue.count <= 3, "Automation should respect build queue depth")
}

func testAutoUpgradeFleetStrategyCanBuildShipsWhenAllowed() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 202, playerName: "指挥官")
    universe.planets[0].resources = ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000)
    universe.planets[0].buildingLevels[.roboticsFactory] = 1
    universe.planets[0].buildingLevels[.shipyard] = 1
    let policy = AutoUpgradePolicy(strategy: .fleet, allowShipConstruction: true)

    _ = PlayerAutoUpgradeEngine.makeDecisions(in: &universe, policy: policy)

    require(universe.planets[0].shipBuildQueue.isEmpty == false, "Fleet automation should queue ships")
}
```

- [ ] **Step 2: Implement policy-aware decisions**

Change the public API to:

```swift
@discardableResult
public static func makeDecisions(
    in universe: inout Universe,
    policy: AutoUpgradePolicy = AutoUpgradePolicy()
) -> PlayerAutoUpgradeResult
```

Add result counters for ships, defenses, and missiles. Keep existing callers working through the default argument.

Decision rules:

- `.economy`: mines, solar/fusion, storage, robotics.
- `.research`: research lab, energy/computer/espionage, drives, combat tech.
- `.fleet`: shipyard, drives, small cargo, light fighter, probe, recycler, colony ship.
- `.defense`: shipyard, missile silo, rocket launcher, light laser, interceptors.
- `.lowRiskOffline`: energy, storage, defenses, no aggressive ships.
- `.balanced`: existing broad ordering with queue-depth support.

Resource reserve rule:

```swift
private static func canSpend(_ cost: ResourceBundle, from resources: ResourceBundle, reserveRatio: Double) -> Bool {
    let reserve = resources.scaled(by: min(max(reserveRatio, 0), 0.8))
    return resources.subtracting(reserve).canAfford(cost)
}
```

- [ ] **Step 3: Wire simulation settings**

Update `SimulationEngine.tick` so auto-upgrade receives `settings.autoUpgradePolicy` through a new parameter:

```swift
autoUpgradePolicy: AutoUpgradePolicy = AutoUpgradePolicy()
```

Update the macOS model tick call to pass `settings.autoUpgradePolicy`.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Sources/OGameMac/AppModel.swift Tests/OGameCoreTests/main.swift
git commit -m "feat: make player automation strategy aware"
```

### Task 2.3: Add Settings UI For Automation

**Files:**
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ChineseDisplay.swift`

- [ ] **Step 1: Add localized names**

Add `localizedName` and short descriptions for `AutoUpgradeStrategy`:

- 均衡
- 经济优先
- 科研优先
- 舰队优先
- 防御优先
- 离线低风险

- [ ] **Step 2: Add settings controls**

In the existing Settings panel, add:

- Toggle: 自动升级
- Picker: 自动策略
- Slider: 资源保留比例 `0%...80%`
- Stepper: 建筑队列深度 `1...20`
- Stepper: 科研队列深度 `1...20`
- Toggles: 允许自动造舰、允许自动造防御、允许自动造导弹

- [ ] **Step 3: Verify UI build**

Run:

```bash
swift build
./script/build_and_run.sh --verify
```

Expected: app launches and Settings displays automation controls.

- [ ] **Step 4: Commit**

```bash
git add Sources/OGameMac Sources/OGameCore/DomainModels.swift
git commit -m "feat: add automation settings controls"
```

---

## Phase 3: Fleet Command, Slots, Recall, And Speed

### Task 3.1: Enforce Fleet Slots

**Files:**
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testFleetLaunchRespectsComputerFleetSlots() {
    var universe = fleetFixtureWithShips(shipCount: 3)
    universe.factions[0].technology.levels[.computer] = 0

    let first = FleetEngine.launchFleet(from: universe.planets[0].id, to: universe.planets[1].id, in: &universe, mission: .transport, ships: [.smallCargo: 1])
    let second = FleetEngine.launchFleet(from: universe.planets[0].id, to: universe.planets[1].id, in: &universe, mission: .transport, ships: [.smallCargo: 1])

    requireLaunched(first, "First fleet should launch")
    requireEqual(second, .failure(.fleetSlotLimit), "Second fleet should fail at computer level 0")
}
```

- [ ] **Step 2: Add failure case**

Add:

```swift
case fleetSlotLimit
```

to `FleetLaunchFailure`.

- [ ] **Step 3: Enforce slots**

Before removing ships, count active fleets for owner:

```swift
let activeFleetCount = universe.fleets.filter { $0.ownerID == ownerID && $0.phase != .completed }.count
let maxSlots = TechnologyEffects.maxFleetSlots(for: owningFaction.technology)
guard activeFleetCount < maxSlots else {
    return .failure(.fleetSlotLimit)
}
```

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: enforce fleet slots"
```

### Task 3.2: Add Fleet Speed Percent And Fuel Preview

**Files:**
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testSlowerFleetTakesLongerAndUsesLessFuel() {
    let origin = Coordinate(galaxy: 1, system: 1, position: 4)
    let target = Coordinate(galaxy: 1, system: 2, position: 4)
    let ships: [ShipKind: Int] = [.smallCargo: 1]

    let fullDuration = FleetEngine.travelDuration(from: origin, to: target, ships: ships, ruleSet: .fastSkirmish, speedPercent: 1)
    let halfDuration = FleetEngine.travelDuration(from: origin, to: target, ships: ships, ruleSet: .fastSkirmish, speedPercent: 0.5)
    let fullFuel = FleetEngine.fuelCost(from: origin, to: target, ships: ships, ruleSet: .fastSkirmish, speedPercent: 1)
    let halfFuel = FleetEngine.fuelCost(from: origin, to: target, ships: ships, ruleSet: .fastSkirmish, speedPercent: 0.5)

    require(halfDuration > fullDuration, "Half speed should take longer")
    require(halfFuel < fullFuel, "Half speed should spend less fuel")
}
```

- [ ] **Step 2: Add speed parameters**

Add `speedPercent: Double = 1` to launch and preview methods. Clamp to `0.1...1`.

Fuel formula for fast single-player:

```swift
let clampedSpeed = min(max(speedPercent, 0.1), 1)
let speedFuelMultiplier = 0.35 + pow(clampedSpeed, 2) * 0.65
return ceil((distance / 1_000) * baseCost * speedFuelMultiplier)
```

Duration formula:

```swift
return ceil((distance / slowestSpeed) * 3_600 / clampedSpeed)
```

- [ ] **Step 3: Add UI speed selector**

In fleet dispatch UI, add segmented values:

- 10%
- 25%
- 50%
- 75%
- 100%

Show ETA and fuel cost immediately from `AppModel`.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift build
./script/build_and_run.sh --verify
```

Commit:

```bash
git add Sources/OGameCore Sources/OGameMac Tests/OGameCoreTests/main.swift
git commit -m "feat: add fleet speed controls"
```

### Task 3.3: Add Fleet Recall

**Files:**
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testOutboundFleetCanBeRecalled() {
    var universe = fleetFixtureWithShips(shipCount: 1)
    let launch = FleetEngine.launchFleet(from: universe.planets[0].id, to: universe.planets[1].id, in: &universe, mission: .transport, ships: [.smallCargo: 1])
    let fleet = requireLaunched(launch, "Fleet should launch")
    universe.gameTime = fleet.launchTime + 10

    let recalled = FleetEngine.recallFleet(fleet.id, ownerID: universe.playerFactionID, in: &universe)

    requireEqual(recalled, true, "Recall should succeed")
    requireEqual(universe.fleets[0].phase, .returning, "Recalled fleet should return")
    require(universe.fleets[0].returnTime < fleet.returnTime, "Recall should shorten return time")
}
```

- [ ] **Step 2: Implement recall**

Add:

```swift
public static func recallFleet(_ fleetID: FleetID, ownerID: FactionID, in universe: inout Universe) -> Bool
```

Rules:

- Only owner can recall.
- Only `.outbound` and `.holding` can recall.
- Attack/espionage/recycle/explore/colonize can recall before arrival.
- Set `phase = .returning`.
- Set `recalledAt = universe.gameTime`.
- Calculate elapsed outbound fraction and return duration based on distance already traveled.

- [ ] **Step 3: Add UI action**

Add Recall button for active player fleets. Disable it for returning fleets.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Sources/OGameMac Tests/OGameCoreTests/main.swift
git commit -m "feat: add fleet recall"
```

---

## Phase 4: Espionage, Exploration, And Colonization Depth

### Task 4.1: Add Intel Tiers And Probe Loss

**Files:**
- Create: `Sources/OGameCore/IntelEngine.swift`
- Modify: `Sources/OGameCore/CombatEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testEspionageTierHidesDefensesWhenAttackerIsWeak() {
    var universe = espionageFixture(attackerEspionage: 0, defenderEspionage: 4, probes: 1)
    let fleet = universe.fleets[0]

    _ = CombatEngine.resolveEspionage(fleet, in: &universe)
    let report = universe.reports.last!

    require(report.intelTier <= 1, "Weak espionage should produce low tier intel")
    require(report.participants[1].afterDefenses.isEmpty, "Low tier intel should hide defenses")
}

func testEspionageTierRevealsFullStateWithEnoughAdvantage() {
    var universe = espionageFixture(attackerEspionage: 6, defenderEspionage: 0, probes: 4)
    let fleet = universe.fleets[0]

    _ = CombatEngine.resolveEspionage(fleet, in: &universe)
    let report = universe.reports.last!

    requireEqual(report.intelTier, 5, "Strong espionage should reach full intel")
    require(report.participants[1].afterShips.isEmpty == false, "Full intel should reveal ships")
}
```

- [ ] **Step 2: Implement intel tiers**

Create `IntelEngine`:

- Tier 1: resources only.
- Tier 2: resources + fleet count.
- Tier 3: resources + ships + defenses.
- Tier 4: resources + ships + defenses + buildings.
- Tier 5: full report with technology summary.

Probe loss chance:

```swift
let defenderAdvantage = max(0, defenderEspionage - attackerEspionage)
let baseChance = min(0.75, Double(defenderAdvantage) * 0.08 + Double(defenderCombatUnits) * 0.005)
```

Use deterministic seed payload from universe seed, fleet id, and arrival time.

- [ ] **Step 3: Update report UI**

Show intel tier as:

- 侦察等级 1/5
- 信息不足
- 探测器损失 if probes are destroyed

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Sources/OGameMac Tests/OGameCoreTests/main.swift
git commit -m "feat: add espionage intel tiers"
```

### Task 4.2: Add Exploration Event Table

**Files:**
- Create: `Sources/OGameCore/ExplorationEventEngine.swift`
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/StrategicEngine.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testExplorationEventIsDeterministicForSameSeedAndFleet() {
    let universe = StarterUniverseFactory.makeNewGame(seed: 301, playerName: "指挥官")
    let fleet = sampleExplorationFleet(idSeed: 1)

    let first = ExplorationEventEngine.resolve(fleet: fleet, universe: universe)
    let second = ExplorationEventEngine.resolve(fleet: fleet, universe: universe)

    requireEqual(first, second, "Exploration events should be deterministic")
}

func testExplorationEventRewardFitsCargoCapacity() {
    let universe = StarterUniverseFactory.makeNewGame(seed: 302, playerName: "指挥官")
    let fleet = sampleExplorationFleet(idSeed: 2, ships: [.smallCargo: 1])

    let outcome = ExplorationEventEngine.resolve(fleet: fleet, universe: universe)

    require(outcome.reward.totalAmount <= 5_000, "Small cargo exploration reward should fit cargo capacity")
}
```

- [ ] **Step 2: Add outcome model**

Add:

```swift
public enum ExplorationOutcomeKind: String, Codable, CaseIterable, Sendable {
    case resourceCache
    case debrisField
    case derelictShips
    case pirateAmbush
    case emptySignal
}

public struct ExplorationOutcome: Codable, Equatable, Sendable {
    public var kind: ExplorationOutcomeKind
    public var reward: ResourceBundle
    public var foundShips: [ShipKind: Int]
    public var lostShips: [ShipKind: Int]
    public var messageKey: String
}
```

- [ ] **Step 3: Integrate fleet exploration**

Replace the fixed `explorationReward(for:universe:)` with `ExplorationEventEngine.resolve`. Keep exploration records compatible by recording reward, discovered resources, debris, owner, and neutral status.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Sources/OGameMac Tests/OGameCoreTests/main.swift
git commit -m "feat: add exploration event outcomes"
```

### Task 4.3: Add Planet Field And Colonization Variety

**Files:**
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/StarterUniverseFactory.swift`
- Modify: `Sources/OGameCore/QueueEngine.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testPlanetFieldsLimitBuildingUpgrades() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 401, playerName: "指挥官")
    universe.planets[0].maxFields = 3
    universe.planets[0].buildingLevels = [.metalMine: 1, .crystalMine: 1, .solarPlant: 1]
    universe.planets[0].resources = ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000)

    let result = QueueEngine.startBuildingUpgrade(on: universe.planets[0].id, in: &universe, kind: .deuteriumSynthesizer)

    requireEqual(result, .noAvailableFields, "Full planet should block new building type")
}
```

- [ ] **Step 2: Add fields**

Add `Planet.maxFields: Int = 180`. Compute used fields as the count of building kinds with level above zero, not the sum of levels, for this fast single-player version.

Add `QueueResult.noAvailableFields`.

- [ ] **Step 3: Make colonized planets varied**

When a colony is established, derive:

- `maxFields` from position and seed.
- Temperature from coordinate position.
- Starting storage from fast-skirmish defaults.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
```

Commit:

```bash
git add Sources/OGameCore Sources/OGameMac Tests/OGameCoreTests/main.swift
git commit -m "feat: add colony field variety"
```

---

## Phase 5: Battle Simulation And Moon Gameplay

### Task 5.1: Add Round-Based Battle Simulation

**Files:**
- Create: `Sources/OGameCore/BattleSimulationEngine.swift`
- Modify: `Sources/OGameCore/CombatEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameCore/BalanceRules.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testBattleSimulationProducesAtMostSixRounds() {
    let input = BattleSimulationInput(
        attackerShips: [.lightFighter: 10],
        defenderShips: [:],
        defenderDefenses: [.rocketLauncher: 5],
        attackerResearch: ResearchState(),
        defenderResearch: ResearchState(),
        ruleSet: .fastSkirmish,
        seed: 501
    )

    let result = BattleSimulationEngine.resolve(input)

    require(result.rounds.count >= 1, "Battle should produce at least one round")
    require(result.rounds.count <= 6, "Battle should stop after six rounds")
}

func testBattlePreviewDoesNotMutateUniverse() {
    var universe = combatFixture()
    let original = universe
    _ = CombatEngine.previewAttack(universe.fleets[0], in: universe)
    requireEqual(universe, original, "Preview should not mutate universe")
}
```

- [ ] **Step 2: Implement input and result models**

Add:

```swift
public struct BattleSimulationInput: Equatable, Sendable {
    public var attackerShips: [ShipKind: Int]
    public var defenderShips: [ShipKind: Int]
    public var defenderDefenses: [DefenseKind: Int]
    public var attackerResearch: ResearchState
    public var defenderResearch: ResearchState
    public var ruleSet: RuleSet
    public var seed: UInt64
}

public struct BattleRoundSummary: Codable, Equatable, Sendable {
    public var round: Int
    public var attackerPower: Double
    public var defenderPower: Double
    public var attackerLosses: [ShipKind: Int]
    public var defenderShipLosses: [ShipKind: Int]
    public var defenderDefenseLosses: [DefenseKind: Int]
}
```

- [ ] **Step 3: Resolve combat through simulation**

Use six rounds. Each round:

- Apply weapons/shields/armor multipliers.
- Apply deterministic variation from seed.
- Apply rapid-fire bonus as extra effective attack against preferred targets.
- Remove destroyed ships/defenses after each round.
- End early when one side has no combat power.

Keep existing debris, loot, moon creation, and defense recovery behavior, but source losses from simulation result.

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: add round based battle simulation"
```

### Task 5.2: Add Battle Preview UI

**Files:**
- Modify: `Sources/OGameCore/CombatEngine.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`

- [ ] **Step 1: Add preview API**

Add:

```swift
public static func previewAttack(_ fleet: Fleet, in universe: Universe) -> BattleSimulationResult?
```

It should return nil when target or rules are missing.

- [ ] **Step 2: Add dispatch preview**

In fleet dispatch:

- Show predicted winner.
- Show estimated losses.
- Show estimated loot capacity.
- Show expected debris.
- Show moon chance when debris crosses threshold.

- [ ] **Step 3: Verify and commit**

Run:

```bash
swift build
./script/build_and_run.sh --verify
```

Commit:

```bash
git add Sources/OGameCore/CombatEngine.swift Sources/OGameMac
git commit -m "feat: show battle previews"
```

### Task 5.3: Implement Moon Facilities

**Files:**
- Create: `Sources/OGameCore/MoonEngine.swift`
- Modify: `Sources/OGameCore/QueueEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testMoonFacilityUpgradeUpdatesMoonInsteadOfPlanetBuildings() {
    var universe = moonFixture()
    universe.planets[0].resources = ResourceBundle(metal: 500_000, crystal: 500_000, deuterium: 500_000)

    let result = MoonEngine.startFacilityUpgrade(on: universe.planets[0].id, in: &universe, kind: .lunarBase)
    requireEqual(result, .queued, "Lunar base should queue")

    universe.gameTime = universe.planets[0].buildQueue[0].finishTime
    QueueEngine.completeDueItems(in: &universe)

    requireEqual(universe.planets[0].moon?.buildingLevels[.lunarBase], 1, "Moon facility should complete on moon")
    requireEqual(universe.planets[0].buildingLevels[.lunarBase], nil, "Moon facility should not become planet building")
}

func testJumpGateMovesShipsBetweenMoonsAndStartsCooldown() {
    var universe = twoMoonFixtureWithJumpGates()
    let moved = MoonEngine.jumpShips(from: universe.planets[0].id, to: universe.planets[1].id, ownerID: universe.playerFactionID, ships: [.battlecruiser: 2], in: &universe)
    requireEqual(moved, true, "Jump gate should move ships")
    requireEqual(universe.planets[1].shipInventory[.battlecruiser], 2, "Target moon planet should receive ships")
    require((universe.planets[0].moon?.jumpGateReadyAt ?? 0) > universe.gameTime, "Jump gate should enter cooldown")
}
```

- [ ] **Step 2: Implement moon queues**

Implement `MoonEngine.startFacilityUpgrade` by creating normal `BuildQueueItem`s with moon facility kinds. Update `QueueEngine.completeDueItems` so if `item.buildingKind.isMoonFacility` then it updates `planet.moon?.buildingLevels` and does not touch `planet.buildingLevels`.

- [ ] **Step 3: Implement sensor scan**

Add:

```swift
public static func sensorScan(from moonPlanetID: PlanetID, targetPlanetID: PlanetID, ownerID: FactionID, in universe: Universe) -> [Fleet]
```

Rules:

- Requires moon.
- Requires sensor phalanx level > 0.
- Range is `level * level * 5` systems.
- Returns fleets targeting or originating from target planet.

- [ ] **Step 4: Implement jump gate**

Add:

```swift
public static func jumpShips(from originPlanetID: PlanetID, to targetPlanetID: PlanetID, ownerID: FactionID, ships: [ShipKind: Int], in universe: inout Universe) -> Bool
```

Rules:

- Both planets must be owned by owner.
- Both must have moons with jump gate level > 0.
- Origin cooldown must be ready.
- Move ships instantly, no resources.
- Cooldown: 3_600 seconds in fast-skirmish.

- [ ] **Step 5: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Sources/OGameMac Tests/OGameCoreTests/main.swift
git commit -m "feat: implement moon facilities"
```

---

## Phase 6: AI, Balance Lab, UI Polish, And Documentation

### Task 6.1: Teach AI The New Mechanics

**Files:**
- Modify: `Sources/OGameCore/AIStrategyEngine.swift`
- Modify: `Sources/OGameCore/AIEconomyEngine.swift`
- Modify: `Sources/OGameCore/SimulationEngine.swift`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testAIRespectsFleetSlotLimit() {
    var universe = aiFleetSlotFixture()
    AIStrategyEngine.makeStrategicDecisions(in: &universe, allowAggressiveMissions: true, policy: .standard)
    let active = universe.fleets.filter { $0.ownerID == universe.factions[1].id }
    let maxSlots = TechnologyEffects.maxFleetSlots(for: universe.factions[1].technology)
    require(active.count <= maxSlots, "AI should respect fleet slot limits")
}

func testAIDoesNotAttackWithoutUsefulIntelOnStandardDifficulty() {
    var universe = aiUnknownTargetFixture()
    AIStrategyEngine.makeStrategicDecisions(in: &universe, allowAggressiveMissions: true, policy: .standard)
    require(universe.fleets.contains(where: { $0.mission == .espionage }), "Standard AI should scout before attacking")
    require(universe.fleets.contains(where: { $0.mission == .attack }) == false, "Standard AI should not blind attack")
}
```

- [ ] **Step 2: Update AI decisions**

AI rules:

- Economy AI values research lab more because it now reduces research time.
- Raider AI uses battle preview and known intel before attack.
- Expansionist AI values high-field neutral worlds.
- Miner AI builds storage and defenses under pressure.
- AI never uses hidden exact player inventory unless it has a sufficient espionage report.
- AI respects fleet slots and does not launch destructive chains during offline catch-up.

- [ ] **Step 3: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
```

Commit:

```bash
git add Sources/OGameCore Tests/OGameCoreTests/main.swift
git commit -m "feat: teach AI updated mechanics"
```

### Task 6.2: Expand Balance Scenario Metrics

**Files:**
- Modify: `Sources/OGameCore/BalanceScenarioRunner.swift`
- Modify: `Sources/OGameCore/StrategicEngine.swift`
- Modify: `Sources/OGameBalanceTool/main.swift`
- Modify: `docs/native-macos-ogame/balance-playtest-guide.md`
- Test: `Tests/OGameCoreTests/main.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testBalanceScenarioRecordsExpandedMilestones() {
    let result = BalanceScenarioRunner.run(seed: 1, duration: 14_400, settings: GameSettings(difficulty: .standard))

    require(result.firstEspionageAt != nil, "Balance scenario should record first espionage")
    require(result.firstExplorationEventAt != nil, "Balance scenario should record first exploration event")
    require(result.automationQueuedActionCount >= 0, "Balance scenario should expose automation action count")
}
```

- [ ] **Step 2: Add metrics**

Extend `BalanceScenarioResult` with:

- `firstEspionageAt`
- `firstExplorationEventAt`
- `firstRecallAt`
- `firstMoonAt`
- `firstMoonActionAt`
- `automationQueuedActionCount`
- `aiAttackCount`
- `playerLossValue`
- `resourceInflationRatio`

- [ ] **Step 3: Update balance tool output**

Print a compact Chinese summary:

```text
首舰: T+...
首侦察: T+...
首战斗: T+...
首殖民: T+...
胜利: T+...
AI 攻击: ...
自动管家队列: ...
资源膨胀: ...
```

- [ ] **Step 4: Verify and commit**

Run:

```bash
swift run OGameCoreTests
swift run OGameBalanceTool
```

Commit:

```bash
git add Sources/OGameCore Sources/OGameBalanceTool docs/native-macos-ogame/balance-playtest-guide.md Tests/OGameCoreTests/main.swift
git commit -m "feat: expand balance scenario metrics"
```

### Task 6.3: UI Polish For Mechanics Clarity

**Files:**
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Sources/OGameMac/Views/DashboardViews.swift`
- Modify: `Sources/OGameMac/Views/PlanetHeaderViews.swift`
- Modify: `Sources/OGameMac/Views/SimulationChrome.swift`
- Modify: `Sources/OGameMac/ChineseDisplay.swift`

- [ ] **Step 1: Add mechanics summary cards**

Add compact cards for:

- 自动管家状态 and next action.
- 舰队槽 `used/max`.
- 当前侦察等级 explanation.
- 战斗预估.
- 月球设施 status.
- 平衡 milestone summary in debug/balance view if present.

- [ ] **Step 2: Improve labels**

All player-facing new strings must be Chinese:

- 舰队槽
- 召回
- 航速
- 预计燃料
- 侦察等级
- 探索事件
- 战斗预估
- 感应阵扫描
- 跳跃门冷却

- [ ] **Step 3: Verify**

Run:

```bash
swift build
./script/build_and_run.sh --verify
```

Expected: app launches, no obvious empty states in the main navigation, Settings and Fleet screens render.

- [ ] **Step 4: Commit**

```bash
git add Sources/OGameMac
git commit -m "feat: clarify mechanics UI"
```

### Task 6.4: Documentation And Final Verification

**Files:**
- Modify: `docs/native-macos-ogame/player-guide.md`
- Modify: `docs/native-macos-ogame/balance-playtest-guide.md`
- Modify: `docs/native-macos-ogame/final-release-checklist.md`

- [ ] **Step 1: Update player guide**

Document:

- Automation strategies.
- Fleet slots and computer tech.
- Drive tech and speed.
- Espionage tiers.
- Exploration outcomes.
- Battle previews.
- Moon facilities.
- Victory routes.

- [ ] **Step 2: Run full verification**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
swift run OGameBalanceTool
./script/build_and_run.sh --verify
```

Expected: all commands pass.

- [ ] **Step 3: Commit**

```bash
git add docs
git commit -m "docs: update mechanics guide"
```

---

## Execution Order

Recommended order:

1. Phase 1: core technology contracts and migration fields.
2. Phase 2: automation policy and Settings UI.
3. Phase 3: fleet slots, speed, and recall.
4. Phase 4: intel, exploration, and colonization variety.
5. Phase 5: battle simulation and moon gameplay.
6. Phase 6: AI integration, balance metrics, UI clarity, and docs.

Do not begin Phase 5 before Phase 3 is stable. Battle previews depend on accurate fleet speed, slots, and research effects.

Do not tune final balance before Phase 6.1. AI behavior changes will move pacing targets.

---

## Acceptance Criteria

The project is considered complete for this mechanics pass when:

- `swift run OGameCoreTests` passes.
- `swift run OGamePersistenceTests` passes.
- `swift build` passes.
- `swift run OGameBalanceTool` prints expanded milestones.
- `./script/build_and_run.sh --verify` launches the current app.
- Existing saves decode with defaults for every new field.
- A new player can leave automation on and still progress through economy, research, fleet construction, exploration, combat, and victory.
- Fleet slots, recall, speed, fuel, and battle previews are visible before dispatch.
- Espionage reports have clear information tiers.
- Exploration has at least five deterministic outcome kinds.
- Moon facilities have at least two working actions: sensor scan and jump gate.
- AI uses the same public mechanics and respects imperfect intelligence.
- Main new UI strings are Chinese.

## Regression Risks

- Save schema drift: every new model field needs old-save default tests.
- Offline catch-up: aggressive AI and automation can create too many events; cap offline destructive actions.
- UI file size: avoid making `ContentView.swift` harder to maintain; split touched sections when needed.
- Balance target drift: after fleet slots and tech speed effects, revisit first ship, first combat, colonization, and victory windows.
- Auto-upgrade runaway queues: always enforce queue depth and resource reserve.

## Self-Review

- Spec coverage: all audited gaps are covered by one or more phases.
- Placeholder scan: no task relies on unspecified "later" work; each task has concrete files, tests, commands, and commit scope.
- Type consistency: new domain names are introduced before later tasks use them.
- Scope check: the plan is large but phase-split. Each phase can ship independently and keep the game runnable.
