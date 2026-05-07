# Native macOS OGame Milestone 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first native SwiftUI macOS foundation: Swift package structure, pure Swift simulation core, JSON persistence, a minimal macOS app shell, and passing tests.

**Architecture:** This is the first executable slice of the larger native OGame sandbox. It creates `OGameCore` without SwiftUI dependencies, `OGamePersistence` for save/load, and `OGameMac` as a SwiftUI executable target that displays a live starter universe. Later plans build economy, AI, fleets, combat, and victory systems on this foundation.

**Tech Stack:** Swift 5.9+, Swift Package Manager, SwiftUI, Foundation, XCTest, JSON `Codable` persistence.

**Environment amendment:** The local Command Line Tools Swift toolchain lacks XCTest and Swift Testing modules, so this milestone uses executable test runners instead of SwiftPM `.testTarget` entries. Verify with `swift run OGameCoreTests`, `swift run OGamePersistenceTests`, and `swift build`.

---

## Scope Check

The approved design covers several independent subsystems: economy, AI, fleet missions, combat, offline simulation, victory conditions, persistence, and SwiftUI. A single implementation plan for the whole sandbox would be too large to execute safely.

This plan implements Milestone 1 only:

- Native SwiftPM macOS project skeleton.
- Core serializable model types.
- Deterministic random source.
- Empty but real `SimulationEngine.tick` entry point.
- Starter universe factory.
- JSON save/load repository.
- Basic SwiftUI app shell.
- Unit tests for model identity, ticking, and persistence round trip.

Follow-up plans should cover:

- Milestone 2: resources, buildings, research, queues, and online ticking.
- Milestone 3: offline catch-up and AI economic growth.
- Milestone 4: fleets, scouting, combat, debris, and reports.
- Milestone 5: star map, victory conditions, rankings, exploration, and balancing.
- Milestone 6: app polish, packaging, settings, onboarding, and performance.

## File Structure

Create this Swift project alongside the existing PHP source. Do not remove or rewrite the PHP files.

- `Package.swift`: SwiftPM package definition with three targets and one test target.
- `Sources/OGameCore/Identifiers.swift`: stable id wrappers for universe entities.
- `Sources/OGameCore/Resources.swift`: resource and storage value types.
- `Sources/OGameCore/DomainModels.swift`: `Universe`, `Faction`, `Planet`, `Fleet`, `ResearchState`, `GameEvent`, `RuleSet`, and supporting enums.
- `Sources/OGameCore/SeededGenerator.swift`: deterministic pseudo-random generator.
- `Sources/OGameCore/SimulationEngine.swift`: single simulation entry point.
- `Sources/OGameCore/StarterUniverseFactory.swift`: deterministic new-game universe creation.
- `Sources/OGamePersistence/SaveEnvelope.swift`: versioned save wrapper.
- `Sources/OGamePersistence/JSONSaveRepository.swift`: local JSON save/load implementation.
- `Sources/OGameMac/OGameMacApp.swift`: SwiftUI executable app entry.
- `Sources/OGameMac/AppModel.swift`: observable app state and save/load/tick orchestration.
- `Sources/OGameMac/ContentView.swift`: basic modern management shell.
- `Tests/OGameCoreTests/SimulationFoundationTests.swift`: core unit tests.
- `Tests/OGamePersistenceTests/PersistenceTests.swift`: persistence unit tests.

## Task 1: Create Swift Package Skeleton

**Files:**
- Create: `Package.swift`
- Create: `Sources/OGameCore/PackageAnchor.swift`
- Create: `Sources/OGamePersistence/PackageAnchor.swift`
- Create: `Sources/OGameMac/main.swift`
- Create: `Tests/OGameCoreTests/PackageAnchorTests.swift`
- Create: `Tests/OGamePersistenceTests/PackageAnchorTests.swift`
- Create directories: `Sources/OGameCore`, `Sources/OGamePersistence`, `Sources/OGameMac`, `Tests/OGameCoreTests`, `Tests/OGamePersistenceTests`

- [ ] **Step 1: Create SwiftPM directories**

Run:

```bash
mkdir -p Sources/OGameCore Sources/OGamePersistence Sources/OGameMac Tests/OGameCoreTests Tests/OGamePersistenceTests
```

Expected: command exits with code 0.

- [ ] **Step 2: Create `Package.swift`**

Write this exact file:

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NativeOGame",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "OGameCore", targets: ["OGameCore"]),
        .library(name: "OGamePersistence", targets: ["OGamePersistence"]),
        .executable(name: "OGameMac", targets: ["OGameMac"])
    ],
    targets: [
        .target(
            name: "OGameCore"
        ),
        .target(
            name: "OGamePersistence",
            dependencies: ["OGameCore"]
        ),
        .executableTarget(
            name: "OGameMac",
            dependencies: ["OGameCore", "OGamePersistence"]
        ),
        .testTarget(
            name: "OGameCoreTests",
            dependencies: ["OGameCore"]
        ),
        .testTarget(
            name: "OGamePersistenceTests",
            dependencies: ["OGameCore", "OGamePersistence"]
        )
    ]
)
```

- [ ] **Step 3: Add minimal target anchors**

Create minimal target anchor files so SwiftPM can describe the package before real source files are added.

Create `Sources/OGameCore/PackageAnchor.swift` with:

```swift
public enum OGameCorePackageAnchor {}
```

Create `Sources/OGamePersistence/PackageAnchor.swift` with:

```swift
public enum OGamePersistencePackageAnchor {}
```

Create `Sources/OGameMac/main.swift` with:

```swift
print("NativeOGame skeleton")
```

Create `Tests/OGameCoreTests/PackageAnchorTests.swift` with:

```swift
import XCTest
@testable import OGameCore

final class OGameCorePackageAnchorTests: XCTestCase {
    func testPackageAnchorExists() {
        XCTAssertNotNil(OGameCorePackageAnchor.self)
    }
}
```

Create `Tests/OGamePersistenceTests/PackageAnchorTests.swift` with:

```swift
import XCTest
@testable import OGamePersistence

final class OGamePersistencePackageAnchorTests: XCTestCase {
    func testPackageAnchorExists() {
        XCTAssertNotNil(OGamePersistencePackageAnchor.self)
    }
}
```

- [ ] **Step 4: Run package description check**

Run:

```bash
swift package describe
```

Expected: output includes these target names:

```text
OGameCore
OGamePersistence
OGameMac
OGameCoreTests
OGamePersistenceTests
```

- [ ] **Step 5: Run skeleton tests**

Run:

```bash
swift test
```

Expected: output includes:

```text
Test Suite 'All tests' passed
```

- [ ] **Step 6: Commit**

Run:

```bash
git add Package.swift Sources Tests
git commit -m "chore: add native Swift package skeleton"
```

Expected: commit succeeds.

## Task 2: Add Core Identifiers And Resources

**Files:**
- Create: `Sources/OGameCore/Identifiers.swift`
- Create: `Sources/OGameCore/Resources.swift`
- Test: `Tests/OGameCoreTests/SimulationFoundationTests.swift`

- [ ] **Step 1: Write failing identifier and resource tests**

Create `Tests/OGameCoreTests/SimulationFoundationTests.swift` with:

```swift
import XCTest
@testable import OGameCore

final class SimulationFoundationTests: XCTestCase {
    func testEntityIDsAreCodableAndEquatable() throws {
        let id = FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(FactionID.self, from: data)

        XCTAssertEqual(decoded, id)
    }

    func testResourceBundleClampsToStorageLimits() {
        let resources = ResourceBundle(metal: 120, crystal: 80, deuterium: 40)
        let storage = ResourceStorage(metal: 100, crystal: 100, deuterium: 20)

        XCTAssertEqual(resources.clamped(to: storage), ResourceBundle(metal: 100, crystal: 80, deuterium: 20))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter SimulationFoundationTests
```

Expected: build fails with errors mentioning missing `FactionID`, `ResourceBundle`, or `ResourceStorage`.

- [ ] **Step 3: Add identifier wrappers**

Create `Sources/OGameCore/Identifiers.swift` with:

```swift
import Foundation

public struct UniverseID: Codable, Hashable, Sendable {
    public var rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct FactionID: Codable, Hashable, Sendable {
    public var rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct PlanetID: Codable, Hashable, Sendable {
    public var rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct FleetID: Codable, Hashable, Sendable {
    public var rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct EventID: Codable, Hashable, Sendable {
    public var rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}
```

- [ ] **Step 4: Add resource value types**

Create `Sources/OGameCore/Resources.swift` with:

```swift
import Foundation

public struct ResourceBundle: Codable, Equatable, Sendable {
    public var metal: Double
    public var crystal: Double
    public var deuterium: Double

    public init(metal: Double = 0, crystal: Double = 0, deuterium: Double = 0) {
        self.metal = metal
        self.crystal = crystal
        self.deuterium = deuterium
    }

    public static let zero = ResourceBundle()

    public func clamped(to storage: ResourceStorage) -> ResourceBundle {
        ResourceBundle(
            metal: min(max(metal, 0), storage.metal),
            crystal: min(max(crystal, 0), storage.crystal),
            deuterium: min(max(deuterium, 0), storage.deuterium)
        )
    }
}

public struct ResourceStorage: Codable, Equatable, Sendable {
    public var metal: Double
    public var crystal: Double
    public var deuterium: Double

    public init(metal: Double = 0, crystal: Double = 0, deuterium: Double = 0) {
        self.metal = metal
        self.crystal = crystal
        self.deuterium = deuterium
    }
}

public struct EnergyState: Codable, Equatable, Sendable {
    public var produced: Double
    public var used: Double

    public init(produced: Double = 0, used: Double = 0) {
        self.produced = produced
        self.used = used
    }

    public var available: Double {
        produced - used
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
swift test --filter SimulationFoundationTests
```

Expected: output includes:

```text
Test Suite 'SimulationFoundationTests' passed
```

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/OGameCore/Identifiers.swift Sources/OGameCore/Resources.swift Tests/OGameCoreTests/SimulationFoundationTests.swift
git commit -m "feat: add core identifiers and resources"
```

Expected: commit succeeds.

## Task 3: Add Serializable Domain Models

**Files:**
- Create: `Sources/OGameCore/DomainModels.swift`
- Modify: `Tests/OGameCoreTests/SimulationFoundationTests.swift`

- [ ] **Step 1: Add failing starter universe model test**

Append this test method inside `SimulationFoundationTests`:

```swift
func testUniverseModelRoundTripsThroughJSON() throws {
    let player = FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000010")!)
    let homeworld = PlanetID(UUID(uuidString: "00000000-0000-0000-0000-000000000020")!)
    let universe = Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000030")!),
        name: "Test Universe",
        seed: 42,
        gameTime: 120,
        playerFactionID: player,
        factions: [
            Faction(id: player, name: "Player", kind: .player, strategy: .balanced, technology: ResearchState(), ownedPlanetIDs: [homeworld])
        ],
        planets: [
            Planet(
                id: homeworld,
                name: "Homeworld",
                coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
                ownerID: player,
                resources: ResourceBundle(metal: 500, crystal: 500, deuterium: 100),
                storage: ResourceStorage(metal: 10_000, crystal: 10_000, deuterium: 10_000),
                energy: EnergyState(produced: 20, used: 10)
            )
        ],
        fleets: [],
        events: [],
        ruleSet: RuleSet.fastSkirmish
    )

    let data = try JSONEncoder().encode(universe)
    let decoded = try JSONDecoder().decode(Universe.self, from: data)

    XCTAssertEqual(decoded.name, "Test Universe")
    XCTAssertEqual(decoded.planets.first?.coordinate, Coordinate(galaxy: 1, system: 1, position: 4))
    XCTAssertEqual(decoded.ruleSet.id, "fast-skirmish-v1")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter SimulationFoundationTests/testUniverseModelRoundTripsThroughJSON
```

Expected: build fails with errors mentioning missing `Universe`, `Faction`, `Planet`, `Coordinate`, or `RuleSet`.

- [ ] **Step 3: Create domain models**

Create `Sources/OGameCore/DomainModels.swift` with:

```swift
import Foundation

public struct Universe: Codable, Equatable, Sendable {
    public var id: UniverseID
    public var name: String
    public var seed: UInt64
    public var gameTime: TimeInterval
    public var playerFactionID: FactionID
    public var factions: [Faction]
    public var planets: [Planet]
    public var fleets: [Fleet]
    public var events: [GameEvent]
    public var ruleSet: RuleSet

    public init(
        id: UniverseID = UniverseID(),
        name: String,
        seed: UInt64,
        gameTime: TimeInterval = 0,
        playerFactionID: FactionID,
        factions: [Faction],
        planets: [Planet],
        fleets: [Fleet],
        events: [GameEvent],
        ruleSet: RuleSet
    ) {
        self.id = id
        self.name = name
        self.seed = seed
        self.gameTime = gameTime
        self.playerFactionID = playerFactionID
        self.factions = factions
        self.planets = planets
        self.fleets = fleets
        self.events = events
        self.ruleSet = ruleSet
    }
}

public struct Faction: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case player
        case ai
    }

    public enum Strategy: String, Codable, Sendable {
        case miner
        case raider
        case technologist
        case expansionist
        case balanced
    }

    public var id: FactionID
    public var name: String
    public var kind: Kind
    public var strategy: Strategy
    public var technology: ResearchState
    public var ownedPlanetIDs: [PlanetID]

    public init(
        id: FactionID = FactionID(),
        name: String,
        kind: Kind,
        strategy: Strategy,
        technology: ResearchState = ResearchState(),
        ownedPlanetIDs: [PlanetID] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.strategy = strategy
        self.technology = technology
        self.ownedPlanetIDs = ownedPlanetIDs
    }
}

public struct Coordinate: Codable, Equatable, Hashable, Sendable {
    public var galaxy: Int
    public var system: Int
    public var position: Int

    public init(galaxy: Int, system: Int, position: Int) {
        self.galaxy = galaxy
        self.system = system
        self.position = position
    }

    public var displayText: String {
        "[\(galaxy):\(system):\(position)]"
    }
}

public struct Planet: Codable, Equatable, Sendable {
    public var id: PlanetID
    public var name: String
    public var coordinate: Coordinate
    public var ownerID: FactionID?
    public var resources: ResourceBundle
    public var storage: ResourceStorage
    public var energy: EnergyState
    public var buildingLevels: [BuildingKind: Int]
    public var shipInventory: [ShipKind: Int]
    public var defenseInventory: [DefenseKind: Int]

    public init(
        id: PlanetID = PlanetID(),
        name: String,
        coordinate: Coordinate,
        ownerID: FactionID?,
        resources: ResourceBundle = .zero,
        storage: ResourceStorage = ResourceStorage(metal: 10_000, crystal: 10_000, deuterium: 10_000),
        energy: EnergyState = EnergyState(),
        buildingLevels: [BuildingKind: Int] = [:],
        shipInventory: [ShipKind: Int] = [:],
        defenseInventory: [DefenseKind: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.ownerID = ownerID
        self.resources = resources
        self.storage = storage
        self.energy = energy
        self.buildingLevels = buildingLevels
        self.shipInventory = shipInventory
        self.defenseInventory = defenseInventory
    }
}

public struct Fleet: Codable, Equatable, Sendable {
    public enum Mission: String, Codable, Sendable {
        case transport
        case colonize
        case espionage
        case attack
        case recycle
        case explore
        case returning
    }

    public enum Phase: String, Codable, Sendable {
        case outbound
        case holding
        case returning
        case completed
    }

    public var id: FleetID
    public var ownerID: FactionID
    public var mission: Mission
    public var origin: Coordinate
    public var target: Coordinate
    public var ships: [ShipKind: Int]
    public var cargo: ResourceBundle
    public var launchTime: TimeInterval
    public var arrivalTime: TimeInterval
    public var returnTime: TimeInterval
    public var phase: Phase

    public init(
        id: FleetID = FleetID(),
        ownerID: FactionID,
        mission: Mission,
        origin: Coordinate,
        target: Coordinate,
        ships: [ShipKind: Int],
        cargo: ResourceBundle = .zero,
        launchTime: TimeInterval,
        arrivalTime: TimeInterval,
        returnTime: TimeInterval,
        phase: Phase = .outbound
    ) {
        self.id = id
        self.ownerID = ownerID
        self.mission = mission
        self.origin = origin
        self.target = target
        self.ships = ships
        self.cargo = cargo
        self.launchTime = launchTime
        self.arrivalTime = arrivalTime
        self.returnTime = returnTime
        self.phase = phase
    }
}

public struct ResearchState: Codable, Equatable, Sendable {
    public var levels: [TechnologyKind: Int]

    public init(levels: [TechnologyKind: Int] = [:]) {
        self.levels = levels
    }
}

public struct GameEvent: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case system
        case economy
        case intelligence
        case combat
        case exploration
        case victory
    }

    public var id: EventID
    public var time: TimeInterval
    public var kind: Kind
    public var title: String
    public var message: String

    public init(id: EventID = EventID(), time: TimeInterval, kind: Kind, title: String, message: String) {
        self.id = id
        self.time = time
        self.kind = kind
        self.title = title
        self.message = message
    }
}

public struct RuleSet: Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var baseTickInterval: TimeInterval
    public var offlineChunkInterval: TimeInterval

    public init(id: String, displayName: String, baseTickInterval: TimeInterval, offlineChunkInterval: TimeInterval) {
        self.id = id
        self.displayName = displayName
        self.baseTickInterval = baseTickInterval
        self.offlineChunkInterval = offlineChunkInterval
    }

    public static let fastSkirmish = RuleSet(
        id: "fast-skirmish-v1",
        displayName: "Fast Skirmish",
        baseTickInterval: 1,
        offlineChunkInterval: 300
    )
}

public enum BuildingKind: String, Codable, CaseIterable, Sendable {
    case metalMine
    case crystalMine
    case deuteriumSynthesizer
    case solarPlant
    case roboticsFactory
    case shipyard
    case researchLab
}

public enum TechnologyKind: String, Codable, CaseIterable, Sendable {
    case espionage
    case computer
    case weapons
    case shielding
    case armor
    case energy
    case combustionDrive
    case impulseDrive
    case hyperspaceDrive
}

public enum ShipKind: String, Codable, CaseIterable, Sendable {
    case smallCargo
    case largeCargo
    case lightFighter
    case heavyFighter
    case cruiser
    case battleship
    case colonyShip
    case recycler
    case espionageProbe
}

public enum DefenseKind: String, Codable, CaseIterable, Sendable {
    case rocketLauncher
    case lightLaser
    case heavyLaser
    case gaussCannon
    case ionCannon
    case plasmaTurret
}
```

- [ ] **Step 4: Run model round-trip test**

Run:

```bash
swift test --filter SimulationFoundationTests/testUniverseModelRoundTripsThroughJSON
```

Expected: output includes:

```text
Test Suite 'SimulationFoundationTests' passed
```

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/OGameCore/DomainModels.swift Tests/OGameCoreTests/SimulationFoundationTests.swift
git commit -m "feat: add serializable universe model"
```

Expected: commit succeeds.

## Task 4: Add Deterministic Generator And Starter Universe

**Files:**
- Create: `Sources/OGameCore/SeededGenerator.swift`
- Create: `Sources/OGameCore/StarterUniverseFactory.swift`
- Modify: `Tests/OGameCoreTests/SimulationFoundationTests.swift`

- [ ] **Step 1: Add failing deterministic starter universe test**

Append this test method inside `SimulationFoundationTests`:

```swift
func testStarterUniverseIsDeterministicForSeed() {
    let first = StarterUniverseFactory.makeNewGame(seed: 7, playerName: "Commander")
    let second = StarterUniverseFactory.makeNewGame(seed: 7, playerName: "Commander")

    XCTAssertEqual(first.seed, 7)
    XCTAssertEqual(first, second)
    XCTAssertEqual(first.factions.count, 6)
    XCTAssertEqual(first.planets.count, 6)
    XCTAssertEqual(first.events.first?.title, "Command Link Established")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter SimulationFoundationTests/testStarterUniverseIsDeterministicForSeed
```

Expected: build fails with missing `StarterUniverseFactory`.

- [ ] **Step 3: Add deterministic generator**

Create `Sources/OGameCore/SeededGenerator.swift` with:

```swift
import Foundation

public struct SeededGenerator: RandomNumberGenerator, Codable, Equatable, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0xA0761D6478BD642F : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
}
```

- [ ] **Step 4: Add starter universe factory**

Create `Sources/OGameCore/StarterUniverseFactory.swift` with:

```swift
import Foundation

public enum StarterUniverseFactory {
    public static func makeNewGame(seed: UInt64, playerName: String) -> Universe {
        var generator = SeededGenerator(seed: seed)

        let playerID = stableFactionID(index: 0)
        let playerHomeID = stablePlanetID(index: 0)
        let playerHome = Planet(
            id: playerHomeID,
            name: "Homeworld",
            coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
            ownerID: playerID,
            resources: ResourceBundle(metal: 500, crystal: 500, deuterium: 100),
            storage: ResourceStorage(metal: 10_000, crystal: 10_000, deuterium: 10_000),
            energy: EnergyState(produced: 20, used: 8),
            buildingLevels: [.metalMine: 1, .crystalMine: 1, .solarPlant: 1]
        )

        let aiStrategies: [Faction.Strategy] = [.miner, .raider, .technologist, .expansionist, .balanced]
        var factions: [Faction] = [
            Faction(
                id: playerID,
                name: playerName,
                kind: .player,
                strategy: .balanced,
                technology: ResearchState(),
                ownedPlanetIDs: [playerHomeID]
            )
        ]
        var planets: [Planet] = [playerHome]

        for index in 1...5 {
            let factionID = stableFactionID(index: index)
            let planetID = stablePlanetID(index: index)
            let strategy = aiStrategies[index - 1]
            let coordinate = Coordinate(
                galaxy: 1,
                system: index + 1,
                position: generator.nextInt(in: 4...12)
            )
            factions.append(
                Faction(
                    id: factionID,
                    name: "AI \(index)",
                    kind: .ai,
                    strategy: strategy,
                    technology: ResearchState(),
                    ownedPlanetIDs: [planetID]
                )
            )
            planets.append(
                Planet(
                    id: planetID,
                    name: "\(strategy.rawValue.capitalized) Prime",
                    coordinate: coordinate,
                    ownerID: factionID,
                    resources: ResourceBundle(metal: 500, crystal: 500, deuterium: 100),
                    storage: ResourceStorage(metal: 10_000, crystal: 10_000, deuterium: 10_000),
                    energy: EnergyState(produced: 20, used: 8),
                    buildingLevels: [.metalMine: 1, .crystalMine: 1, .solarPlant: 1]
                )
            )
        }

        let welcome = GameEvent(
            id: EventID(UUID(uuidString: "00000000-0000-0000-0000-000000000100")!),
            time: 0,
            kind: .system,
            title: "Command Link Established",
            message: "Your first colony is online. Rival factions are already moving."
        )

        return Universe(
            id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000200")!),
            name: "Fast Skirmish",
            seed: seed,
            gameTime: 0,
            playerFactionID: playerID,
            factions: factions,
            planets: planets,
            fleets: [],
            events: [welcome],
            ruleSet: .fastSkirmish
        )
    }

    private static func stableFactionID(index: Int) -> FactionID {
        FactionID(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!)
    }

    private static func stablePlanetID(index: Int) -> PlanetID {
        PlanetID(UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", index + 1))!)
    }
}
```

- [ ] **Step 5: Run deterministic starter test**

Run:

```bash
swift test --filter SimulationFoundationTests/testStarterUniverseIsDeterministicForSeed
```

Expected: output includes:

```text
Test Suite 'SimulationFoundationTests' passed
```

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/OGameCore/SeededGenerator.swift Sources/OGameCore/StarterUniverseFactory.swift Tests/OGameCoreTests/SimulationFoundationTests.swift
git commit -m "feat: add deterministic starter universe"
```

Expected: commit succeeds.

## Task 5: Add Simulation Engine Entry Point

**Files:**
- Create: `Sources/OGameCore/SimulationEngine.swift`
- Modify: `Tests/OGameCoreTests/SimulationFoundationTests.swift`

- [ ] **Step 1: Add failing tick test**

Append this test method inside `SimulationFoundationTests`:

```swift
func testSimulationTickAdvancesGameTimeAndRecordsEvent() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 9, playerName: "Commander")

    SimulationEngine.tick(universe: &universe, delta: 60)

    XCTAssertEqual(universe.gameTime, 60)
    XCTAssertEqual(universe.events.last?.title, "Simulation Advanced")
    XCTAssertEqual(universe.events.last?.time, 60)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter SimulationFoundationTests/testSimulationTickAdvancesGameTimeAndRecordsEvent
```

Expected: build fails with missing `SimulationEngine`.

- [ ] **Step 3: Add simulation engine**

Create `Sources/OGameCore/SimulationEngine.swift` with:

```swift
import Foundation

public enum SimulationEngine {
    public static func tick(universe: inout Universe, delta: TimeInterval) {
        guard delta > 0 else {
            return
        }

        universe.gameTime += delta
        universe.events.append(
            GameEvent(
                time: universe.gameTime,
                kind: .system,
                title: "Simulation Advanced",
                message: "Advanced the universe by \(Int(delta)) seconds."
            )
        )
    }
}
```

- [ ] **Step 4: Run core tests**

Run:

```bash
swift test --filter SimulationFoundationTests
```

Expected: output includes:

```text
Test Suite 'SimulationFoundationTests' passed
```

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/OGameCore/SimulationEngine.swift Tests/OGameCoreTests/SimulationFoundationTests.swift
git commit -m "feat: add simulation engine entry point"
```

Expected: commit succeeds.

## Task 6: Add Versioned JSON Persistence

**Files:**
- Create: `Sources/OGamePersistence/SaveEnvelope.swift`
- Create: `Sources/OGamePersistence/JSONSaveRepository.swift`
- Create: `Tests/OGamePersistenceTests/PersistenceTests.swift`

- [ ] **Step 1: Write failing persistence round-trip test**

Create `Tests/OGamePersistenceTests/PersistenceTests.swift` with:

```swift
import Foundation
import XCTest
@testable import OGameCore
@testable import OGamePersistence

final class PersistenceTests: XCTestCase {
    func testRepositorySavesAndLoadsUniverse() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NativeOGamePersistenceTests-\(UUID().uuidString)", isDirectory: true)
        let repository = JSONSaveRepository(saveDirectory: directory)
        let universe = StarterUniverseFactory.makeNewGame(seed: 11, playerName: "Commander")

        try repository.save(universe, wallClockDate: Date(timeIntervalSince1970: 1_000))
        let loaded = try repository.load()

        XCTAssertEqual(loaded.universe, universe)
        XCTAssertEqual(loaded.lastSavedAt, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(loaded.schemaVersion, SaveEnvelope.currentSchemaVersion)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter PersistenceTests/testRepositorySavesAndLoadsUniverse
```

Expected: build fails with missing `JSONSaveRepository` or `SaveEnvelope`.

- [ ] **Step 3: Add save envelope**

Create `Sources/OGamePersistence/SaveEnvelope.swift` with:

```swift
import Foundation
import OGameCore

public struct SaveEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var appVersion: String
    public var lastSavedAt: Date
    public var universe: Universe

    public init(
        schemaVersion: Int = SaveEnvelope.currentSchemaVersion,
        appVersion: String = "0.1.0",
        lastSavedAt: Date,
        universe: Universe
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.lastSavedAt = lastSavedAt
        self.universe = universe
    }
}
```

- [ ] **Step 4: Add JSON repository**

Create `Sources/OGamePersistence/JSONSaveRepository.swift` with:

```swift
import Foundation
import OGameCore

public struct JSONSaveRepository: Sendable {
    public enum RepositoryError: Error, Equatable {
        case missingSave
        case unsupportedSchema(Int)
    }

    public var saveDirectory: URL
    public var fileName: String

    public init(saveDirectory: URL, fileName: String = "autosave.json") {
        self.saveDirectory = saveDirectory
        self.fileName = fileName
    }

    public static func defaultRepository() throws -> JSONSaveRepository {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("NativeOGame", isDirectory: true)
        return JSONSaveRepository(saveDirectory: directory)
    }

    public func save(_ universe: Universe, wallClockDate: Date = Date()) throws {
        try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
        let envelope = SaveEnvelope(lastSavedAt: wallClockDate, universe: universe)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        try data.write(to: saveURL, options: [.atomic])
    }

    public func load() throws -> SaveEnvelope {
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            throw RepositoryError.missingSave
        }

        let data = try Data(contentsOf: saveURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(SaveEnvelope.self, from: data)
        guard envelope.schemaVersion == SaveEnvelope.currentSchemaVersion else {
            throw RepositoryError.unsupportedSchema(envelope.schemaVersion)
        }
        return envelope
    }

    private var saveURL: URL {
        saveDirectory.appendingPathComponent(fileName, isDirectory: false)
    }
}
```

- [ ] **Step 5: Run persistence tests**

Run:

```bash
swift test --filter PersistenceTests
```

Expected: output includes:

```text
Test Suite 'PersistenceTests' passed
```

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/OGamePersistence Tests/OGamePersistenceTests
git commit -m "feat: add JSON save repository"
```

Expected: commit succeeds.

## Task 7: Add SwiftUI App Model And Shell

**Files:**
- Create: `Sources/OGameMac/OGameMacApp.swift`
- Create: `Sources/OGameMac/AppModel.swift`
- Create: `Sources/OGameMac/ContentView.swift`

- [ ] **Step 1: Add app model**

Create `Sources/OGameMac/AppModel.swift` with:

```swift
import Foundation
import OGameCore
import OGamePersistence

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var universe: Universe
    @Published var statusMessage: String

    private let repository: JSONSaveRepository

    init(repository: JSONSaveRepository? = nil) {
        let resolvedRepository: JSONSaveRepository
        if let repository {
            resolvedRepository = repository
        } else {
            resolvedRepository = (try? JSONSaveRepository.defaultRepository())
                ?? JSONSaveRepository(saveDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("NativeOGame", isDirectory: true))
        }
        self.repository = resolvedRepository

        if let envelope = try? resolvedRepository.load() {
            self.universe = envelope.universe
            self.statusMessage = "Loaded save from \(envelope.lastSavedAt.formatted(date: .abbreviated, time: .shortened))."
        } else {
            self.universe = StarterUniverseFactory.makeNewGame(seed: 1, playerName: "Commander")
            self.statusMessage = "New fast skirmish initialized."
        }
    }

    var playerFaction: Faction? {
        universe.factions.first { $0.id == universe.playerFactionID }
    }

    var playerPlanets: [Planet] {
        guard let playerFaction else {
            return []
        }
        return universe.planets.filter { planet in
            playerFaction.ownedPlanetIDs.contains(planet.id)
        }
    }

    func advanceOneMinute() {
        SimulationEngine.tick(universe: &universe, delta: 60)
        statusMessage = "Advanced to T+\(Int(universe.gameTime)) seconds."
    }

    func save() {
        do {
            try repository.save(universe)
            statusMessage = "Saved universe."
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 2: Add SwiftUI content view**

Create `Sources/OGameMac/ContentView.swift` with:

```swift
import SwiftUI
import OGameCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: .constant("dashboard")) {
                Section("Empire") {
                    Label("Dashboard", systemImage: "chart.bar")
                        .tag("dashboard")
                    Label("Star Map", systemImage: "sparkles")
                        .tag("star-map")
                    Label("Research", systemImage: "atom")
                        .tag("research")
                    Label("Fleets", systemImage: "paperplane")
                        .tag("fleets")
                }

                Section("Planets") {
                    ForEach(model.playerPlanets, id: \.id) { planet in
                        Label(planet.name, systemImage: "circle.grid.cross")
                    }
                }
            }
            .navigationTitle("OGame")
        } detail: {
            DashboardView()
        }
        .frame(minWidth: 980, minHeight: 640)
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    planetSummary
                    eventSummary
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("Activity")
                    .font(.headline)

                Text(model.statusMessage)
                    .foregroundStyle(.secondary)

                Button {
                    model.advanceOneMinute()
                } label: {
                    Label("Advance 1 Minute", systemImage: "clock.arrow.circlepath")
                }

                Button {
                    model.save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }

                Spacer()
            }
            .padding(20)
            .frame(width: 280, alignment: .topLeading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.universe.name)
                .font(.largeTitle.bold())

            Text("Simulation time: T+\(Int(model.universe.gameTime)) seconds")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var planetSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Planets")
                .font(.title2.bold())

            ForEach(model.playerPlanets, id: \.id) { planet in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(planet.name) \(planet.coordinate.displayText)")
                        .font(.headline)
                    Text("Metal \(Int(planet.resources.metal))  Crystal \(Int(planet.resources.crystal))  Deuterium \(Int(planet.resources.deuterium))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text("Energy \(Int(planet.energy.produced - planet.energy.used)) available")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var eventSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Events")
                .font(.title2.bold())

            ForEach(model.universe.events.suffix(6), id: \.id) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                    Text(event.message)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
    }
}
```

- [ ] **Step 3: Add app entry**

Create `Sources/OGameMac/OGameMacApp.swift` with:

```swift
import SwiftUI

@main
struct OGameMacApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Button("Advance 1 Minute") {
                    model.advanceOneMinute()
                }
                .keyboardShortcut("t", modifiers: [.command])
            }
        }
    }
}
```

- [ ] **Step 4: Build executable**

Run:

```bash
swift build
```

Expected: output includes:

```text
Build complete!
```

- [ ] **Step 5: Run tests after adding app shell**

Run:

```bash
swift test
```

Expected: output includes:

```text
Test Suite 'All tests' passed
```

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/OGameMac
git commit -m "feat: add SwiftUI app shell"
```

Expected: commit succeeds.

## Task 8: Add Milestone 1 Verification Notes

**Files:**
- Create: `docs/native-macos-ogame/milestone-1-verification.md`

- [ ] **Step 1: Create verification directory**

Run:

```bash
mkdir -p docs/native-macos-ogame
```

Expected: command exits with code 0.

- [ ] **Step 2: Write verification notes**

Create `docs/native-macos-ogame/milestone-1-verification.md` with:

````markdown
# Milestone 1 Verification

Milestone 1 creates the native macOS Swift foundation for the OGame sandbox.

## Expected Commands

```bash
swift test
swift build
```

Both commands should complete successfully.

## Implemented Capabilities

- SwiftPM package with `OGameCore`, `OGamePersistence`, and `OGameMac`.
- Codable core model for universes, factions, planets, fleets, events, and rulesets.
- Deterministic starter universe factory.
- Simulation entry point that advances game time.
- JSON save/load repository with schema versioning.
- SwiftUI app shell with dashboard, planet summary, event feed, tick command, and save command.

## Deferred To Later Milestones

- Resource production formulas.
- Building and research queues.
- AI decisions.
- Fleet mission resolution.
- Combat.
- Offline catch-up.
- Victory conditions.
- Star map interactions.
````

- [ ] **Step 3: Run final verification commands**

Run:

```bash
swift test
```

Expected: output includes:

```text
Test Suite 'All tests' passed
```

Run:

```bash
swift build
```

Expected: output includes:

```text
Build complete!
```

- [ ] **Step 4: Commit**

Run:

```bash
git add docs/native-macos-ogame/milestone-1-verification.md
git commit -m "docs: add milestone 1 verification notes"
```

Expected: commit succeeds.

## Execution Notes

- Keep every commit small and aligned with a task.
- Do not modify the old PHP game files during this milestone.
- If a Swift compiler version requires minor syntax changes, make the smallest change that preserves the public names in this plan.
- If `swift build` cannot build a SwiftUI executable target on the local machine, verify Xcode Command Line Tools or full Xcode is installed before changing package structure.
- After each task, run `git status --short` and confirm only intended files are staged or committed.

## Plan Self-Review

Spec coverage for Milestone 1:

- Architecture modules: covered by Tasks 1, 6, and 7.
- Serializable core data model: covered by Tasks 2 and 3.
- Deterministic starter state: covered by Task 4.
- Single simulation entry point: covered by Task 5.
- JSON persistence and schema versioning: covered by Task 6.
- Minimal SwiftUI app shell: covered by Task 7.
- Tests and verification: covered by Tasks 2 through 8.

Intentional gaps for later plans:

- Real production formulas.
- Building and research queues.
- AI simulation.
- Fleet mission resolution.
- Combat reports.
- Offline chunk catch-up.
- Victory progress.
- 2D star map.
