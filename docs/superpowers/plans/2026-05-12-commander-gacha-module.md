# Commander Gacha Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a single-player commander recruitment, growth, assignment, and fleet bonus system inspired by OGame officers and modern transparent gacha progression.

**Architecture:** Keep all gameplay truth in `OGameCore`: persistent commander roster state lives on `Universe`, recruitment and growth are deterministic engines, and fleet bonuses flow through `FleetEngine`, `BattleSimulationEngine`, `CombatEngine`, and exploration resolution. macOS UI exposes commanders through a new sidebar page and a fleet-dispatch picker; dashboard/advisor surfaces high-signal commander opportunities without making the feature mandatory.

**Tech Stack:** Swift 5.9, SwiftPM, `OGameCore`, `OGameMac`, executable test targets `OGameCoreTests` and `OGamePersistenceTests`.

---

## Design Snapshot

Reference model:
- OGame officers provide recognizable bonus archetypes: Commander, Fleet Admiral, Engineer, Geologist, Technocrat.
- Modern gacha systems should show public rarity rates and use pity/guarantee counters.
- Similar space strategy commander systems usually combine rarity, levels, combat experience, and fleet leadership bonuses.

Single-player adaptation:
- No real-money economy. Pull currency is `recruitmentTickets`, earned through gameplay and starter grants.
- Commanders are optional accelerators and strategy shapers. They should never be required for base progression.
- All random pulls are deterministic from `universe.seed` and recruitment counters so save/load and tests remain stable.

Initial balance:
- Rarities: common 70%, elite 24%, epic 5%, legendary 1%.
- Ten-pull guarantee: at least one elite or better.
- Soft pity: after 25 pulls without legendary, legendary chance increases by 3 percentage points per pull.
- Hard pity: pull 40 without legendary forces a legendary.
- Duplicate conversion: common 5 shards, elite 10, epic 25, legendary 50.
- Star costs: 20, 40, 80, 160, 320 shards for stars 1 through 5.
- Level caps: common 20, elite 30, epic 40, legendary 50.

Commander specialties:
- `fleetAdmiral`: attack, fleet speed, fleet slot advisor value.
- `engineer`: shield, hull durability, fuel efficiency.
- `geologist`: cargo efficiency, raid loot, recycle/transport value.
- `technocrat`: espionage power, research-themed advisor value, precision.
- `explorer`: expedition reward, expedition risk reduction, relic loop synergy.

## File Structure

Create:
- `Sources/OGameCore/CommanderCatalog.swift`: static commander definitions, rarity rates, readable names, base specialties.
- `Sources/OGameCore/CommanderRecruitmentEngine.swift`: deterministic single/ten pull, pity, duplicate conversion, ticket spending.
- `Sources/OGameCore/CommanderGrowthEngine.swift`: XP, levels, star promotion, shard spending.
- `Sources/OGameCore/CommanderBonusEngine.swift`: computed fleet/combat/exploration bonuses from owned commander state.
- `docs/native-macos-ogame/commander-system-2026-05-12.md`: player-facing system explanation and balance notes.

Modify:
- `Sources/OGameCore/Identifiers.swift`: add `CommanderID`.
- `Sources/OGameCore/DomainModels.swift`: add commander data models; add `commanderRoster` to `Universe`; add optional `commanderID` to `Fleet`; add default decoding for old saves.
- `Sources/OGameCore/StarterUniverseFactory.swift`: grant starter recruitment tickets.
- `Sources/OGameCore/FleetEngine.swift`: allow optional commander assignment, validate availability, apply travel/fuel bonuses, persist commander on launched fleet.
- `Sources/OGameCore/BattleSimulationEngine.swift`: accept commander combat bonuses and multiply ship attack/shield/hull.
- `Sources/OGameCore/CombatEngine.swift`: pass attacker commander bonus into battle simulation and award combat XP.
- `Sources/OGameCore/ExplorationEventEngine.swift` or `Sources/OGameCore/FleetEngine.swift`: apply exploration commander reward/risk modifiers and award exploration XP.
- `Sources/OGameCore/StrategicAdvisorEngine.swift`: add commander recruitment, training, assignment recommendations.
- `Sources/OGameCore/GameplayAuditEngine.swift`: count commander module signals in autoplay audit.
- `Sources/OGameBalanceTool/main.swift`: print commander count/tickets in audit CSV.
- `Sources/OGameMac/AppModel.swift`: add commander summaries and actions for recruit/train/promote/assign.
- `Sources/OGameMac/ContentView.swift`: add `.commanders` sidebar destination, `CommanderOverviewView`, recruitment controls, roster list, and fleet-dispatch commander picker.
- `Sources/OGameMac/Views/DashboardViews.swift`: add advisor icon/navigation for commander recommendations.
- `Tests/OGameCoreTests/main.swift`: add TDD coverage for persistence, deterministic pulls, growth, fleet bonuses, XP, advisor coverage, audit output.

## Task 1: Persistent Commander State

**Files:**
- Modify: `Sources/OGameCore/Identifiers.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] **Step 1: Write failing save migration tests**

Add tests:

```swift
func testCommanderStateDefaultsWhenDecodingOlderUniverseJSON() throws {
    let original = StarterUniverseFactory.makeNewGame(seed: 12, playerName: "Commander")
    let data = try JSONEncoder().encode(original)
    var json = try requireDictionary(JSONSerialization.jsonObject(with: data), "Universe should encode as a dictionary")
    json.removeValue(forKey: "commanderRoster")
    let legacyData = try JSONSerialization.data(withJSONObject: json)
    let decoded = try JSONDecoder().decode(Universe.self, from: legacyData)

    requireEqual(decoded.commanderRoster.ownedCommanders, [], "Older saves should default to no commanders")
    requireEqual(decoded.commanderRoster.recruitmentTickets, 0, "Older saves should default commander tickets to zero")
    requireEqual(decoded.commanderRoster.trainingData, 0, "Older saves should default training data to zero")
    requireEqual(decoded.commanderRoster.recruitmentState.totalPulls, 0, "Older saves should default pull counters to zero")
}

func testFleetCommanderIDDefaultsWhenDecodingOlderFleetJSON() throws {
    let fleet = Fleet(
        ownerID: FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000101")!),
        mission: .transport,
        origin: Coordinate(galaxy: 1, system: 1, position: 4),
        target: Coordinate(galaxy: 1, system: 2, position: 4),
        ships: [.smallCargo: 1],
        launchTime: 0,
        arrivalTime: 60,
        returnTime: 120
    )
    let data = try JSONEncoder().encode(fleet)
    var json = try requireDictionary(JSONSerialization.jsonObject(with: data), "Fleet should encode as a dictionary")
    json.removeValue(forKey: "commanderID")
    let legacyData = try JSONSerialization.data(withJSONObject: json)
    let decoded = try JSONDecoder().decode(Fleet.self, from: legacyData)

    requireEqual(decoded.commanderID, nil, "Older fleet JSON should default missing commander assignment to nil")
}
```

Use the existing `requireDictionary` helper already present in `Tests/OGameCoreTests/main.swift`.

- [x] **Step 2: Run red test**

Run:

```bash
swift run OGameCoreTests
```

Expected: compile failure because `Universe.commanderRoster`, `Fleet.commanderID`, and `CommanderRoster` do not exist.

- [x] **Step 3: Add identifier and models**

Add to `Sources/OGameCore/Identifiers.swift`:

```swift
public struct CommanderID: Codable, Hashable, Sendable {
    public var rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}
```

Add to `Sources/OGameCore/DomainModels.swift` near other gameplay state models:

```swift
public enum CommanderRarity: String, Codable, CaseIterable, Comparable, Sendable {
    case common
    case elite
    case epic
    case legendary

    public static func < (lhs: CommanderRarity, rhs: CommanderRarity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    public var sortOrder: Int {
        switch self {
        case .common: return 0
        case .elite: return 1
        case .epic: return 2
        case .legendary: return 3
        }
    }
}

public enum CommanderSpecialty: String, Codable, CaseIterable, Sendable {
    case fleetAdmiral
    case engineer
    case geologist
    case technocrat
    case explorer
}

public struct OwnedCommander: Codable, Equatable, Sendable, Identifiable {
    public var id: CommanderID
    public var definitionID: String
    public var rarity: CommanderRarity
    public var level: Int
    public var experience: Double
    public var stars: Int
    public var acquiredAt: TimeInterval

    public init(
        id: CommanderID = CommanderID(),
        definitionID: String,
        rarity: CommanderRarity,
        level: Int = 1,
        experience: Double = 0,
        stars: Int = 0,
        acquiredAt: TimeInterval
    ) {
        self.id = id
        self.definitionID = definitionID
        self.rarity = rarity
        self.level = max(level, 1)
        self.experience = experience.isFinite ? max(experience, 0) : 0
        self.stars = min(max(stars, 0), 5)
        self.acquiredAt = acquiredAt.isFinite ? max(acquiredAt, 0) : 0
    }
}

public struct CommanderRecruitmentState: Codable, Equatable, Sendable {
    public var totalPulls: Int
    public var pullsSinceEliteOrBetter: Int
    public var pullsSinceLegendary: Int

    public init(totalPulls: Int = 0, pullsSinceEliteOrBetter: Int = 0, pullsSinceLegendary: Int = 0) {
        self.totalPulls = max(totalPulls, 0)
        self.pullsSinceEliteOrBetter = max(pullsSinceEliteOrBetter, 0)
        self.pullsSinceLegendary = max(pullsSinceLegendary, 0)
    }
}

public struct CommanderRoster: Codable, Equatable, Sendable {
    public var ownedCommanders: [OwnedCommander]
    public var recruitmentTickets: Int
    public var trainingData: Int
    public var shardsByDefinitionID: [String: Int]
    public var recruitmentState: CommanderRecruitmentState

    public init(
        ownedCommanders: [OwnedCommander] = [],
        recruitmentTickets: Int = 0,
        trainingData: Int = 0,
        shardsByDefinitionID: [String: Int] = [:],
        recruitmentState: CommanderRecruitmentState = CommanderRecruitmentState()
    ) {
        self.ownedCommanders = ownedCommanders
        self.recruitmentTickets = max(recruitmentTickets, 0)
        self.trainingData = max(trainingData, 0)
        self.shardsByDefinitionID = shardsByDefinitionID.filter { !$0.key.isEmpty && $0.value > 0 }
        self.recruitmentState = recruitmentState
    }
}
```

- [x] **Step 4: Add state to `Universe` and `Fleet`**

Add `public var commanderRoster: CommanderRoster` to `Universe`, default it in `init`, decode with `decodeIfPresentStrict(CommanderRoster.self, forKey: .commanderRoster) ?? CommanderRoster()`, and encode it.

Add `public var commanderID: CommanderID?` to `Fleet`, default it to `nil`, decode with `decodeIfPresentStrict`, and encode with `encodeIfPresent`.

- [x] **Step 5: Run green test**

Run:

```bash
swift run OGameCoreTests
```

Expected: commander persistence tests pass.

## Task 2: Commander Catalog And Deterministic Recruitment

**Files:**
- Create: `Sources/OGameCore/CommanderCatalog.swift`
- Create: `Sources/OGameCore/CommanderRecruitmentEngine.swift`
- Modify: `Sources/OGameCore/StarterUniverseFactory.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] **Step 1: Write failing recruitment tests**

Add tests:

```swift
func testCommanderRecruitmentUsesTicketsAndTenPullGuarantee() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 42, playerName: "Commander")
    universe.commanderRoster.recruitmentTickets = 10

    let result = CommanderRecruitmentEngine.recruit(count: 10, in: &universe)

    requireEqual(result.pulls.count, 10, "Ten-pull should return ten results")
    requireEqual(universe.commanderRoster.recruitmentTickets, 0, "Recruitment should spend one ticket per pull")
    require(result.pulls.contains { $0.rarity >= .elite }, "Ten-pull should guarantee elite or better")
}

func testCommanderRecruitmentIsDeterministicForSameSeedAndState() {
    var first = StarterUniverseFactory.makeNewGame(seed: 99, playerName: "Commander")
    var second = StarterUniverseFactory.makeNewGame(seed: 99, playerName: "Commander")
    first.commanderRoster.recruitmentTickets = 10
    second.commanderRoster.recruitmentTickets = 10

    let firstResult = CommanderRecruitmentEngine.recruit(count: 10, in: &first)
    let secondResult = CommanderRecruitmentEngine.recruit(count: 10, in: &second)

    requireEqual(firstResult.pulls.map(\.definitionID), secondResult.pulls.map(\.definitionID), "Same seed and counters should pull the same commanders")
    requireEqual(first.commanderRoster, second.commanderRoster, "Same recruitment should produce same roster state")
}

func testCommanderRecruitmentConvertsDuplicatesToShards() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 7, playerName: "Commander")
    let definition = CommanderCatalog.definitions.first { $0.rarity == .epic }!
    universe.commanderRoster.ownedCommanders = [
        OwnedCommander(definitionID: definition.id, rarity: definition.rarity, acquiredAt: 0)
    ]

    CommanderRecruitmentEngine.applyPull(definitionID: definition.id, in: &universe)

    requireEqual(universe.commanderRoster.ownedCommanders.count, 1, "Duplicate commander should not create a second owned copy")
    requireEqual(universe.commanderRoster.shardsByDefinitionID[definition.id], 25, "Duplicate epic should convert to 25 shards")
}
```

- [x] **Step 2: Run red test**

Run:

```bash
swift run OGameCoreTests
```

Expected: compile failure because `CommanderCatalog` and `CommanderRecruitmentEngine` do not exist.

- [x] **Step 3: Add commander definitions**

Create `Sources/OGameCore/CommanderCatalog.swift` with:

```swift
public struct CommanderDefinition: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var title: String
    public var rarity: CommanderRarity
    public var specialty: CommanderSpecialty
    public var lore: String

    public init(id: String, name: String, title: String, rarity: CommanderRarity, specialty: CommanderSpecialty, lore: String) {
        self.id = id
        self.name = name
        self.title = title
        self.rarity = rarity
        self.specialty = specialty
        self.lore = lore
    }
}

public enum CommanderCatalog {
    public static let definitions: [CommanderDefinition] = [
        CommanderDefinition(id: "lin-vanguard", name: "林远航", title: "先锋舰队上将", rarity: .legendary, specialty: .fleetAdmiral, lore: "擅长高速突袭和多波舰队协同。"),
        CommanderDefinition(id: "qiao-reactor", name: "乔映辉", title: "反应堆工程师", rarity: .epic, specialty: .engineer, lore: "把舰队护盾和能源管理压到极限。"),
        CommanderDefinition(id: "shen-surveyor", name: "沈玄石", title: "深空地质专家", rarity: .epic, specialty: .geologist, lore: "能从残骸和贸易航线里榨出更多价值。"),
        CommanderDefinition(id: "xie-technocrat", name: "谢穹", title: "星链技术官", rarity: .epic, specialty: .technocrat, lore: "擅长探测窗口和火控校准。"),
        CommanderDefinition(id: "mira-pathfinder", name: "米拉", title: "远征领航员", rarity: .elite, specialty: .explorer, lore: "熟悉外太空异常和返航窗口。"),
        CommanderDefinition(id: "han-shield", name: "韩盾", title: "护航军官", rarity: .elite, specialty: .engineer, lore: "稳健的护航和损管专家。"),
        CommanderDefinition(id: "rao-raider", name: "饶锋", title: "掠袭队长", rarity: .elite, specialty: .fleetAdmiral, lore: "偏爱短航程打击和快速回收。"),
        CommanderDefinition(id: "xu-miner", name: "许砾", title: "矿务协调员", rarity: .common, specialty: .geologist, lore: "能稳定提升基础运输收益。"),
        CommanderDefinition(id: "lu-scout", name: "陆遥", title: "侦察军士", rarity: .common, specialty: .technocrat, lore: "给探测器分队提供简易校准。"),
        CommanderDefinition(id: "tang-pilot", name: "唐星", title: "航路飞行员", rarity: .common, specialty: .explorer, lore: "熟悉近地星系航线。")
    ]

    public static func definition(id: String) -> CommanderDefinition? {
        definitions.first { $0.id == id }
    }
}
```

- [x] **Step 4: Add recruitment engine**

Create `Sources/OGameCore/CommanderRecruitmentEngine.swift` with public API:

```swift
public struct CommanderPullResult: Equatable, Sendable {
    public var definitionID: String
    public var name: String
    public var rarity: CommanderRarity
    public var isDuplicate: Bool
    public var shardsGranted: Int
}

public struct CommanderRecruitmentResult: Equatable, Sendable {
    public var pulls: [CommanderPullResult]
    public var ticketsSpent: Int
}

public enum CommanderRecruitmentEngine {
    public static func recruit(count: Int, in universe: inout Universe) -> CommanderRecruitmentResult
    public static func applyPull(definitionID: String, in universe: inout Universe) -> CommanderPullResult?
}
```

Implementation rules:
- Clamp `count` to `1...10`.
- Require one `recruitmentTicket` per pull; if there are fewer tickets, pull only the available count.
- Generate deterministic rolls with `SeededGenerator(seed: stableHash("\(universe.seed)|\(totalPulls)|commander"))`.
- Use hard pity before random rarity selection when `pullsSinceLegendary >= 39`.
- Use soft pity by adding `0.03 * max(pullsSinceLegendary - 24, 0)` to legendary chance and subtracting the same amount from common chance.
- Force the last pull in a 10-pull to `.elite` if the first nine are all `.common`.
- Pick a definition from matching rarity deterministically.
- If definition already owned, grant shards instead of a duplicate.

- [x] **Step 5: Starter tickets**

Modify `StarterUniverseFactory.makeNewGame` so new games start with:

```swift
commanderRoster: CommanderRoster(recruitmentTickets: 10, trainingData: 500)
```

This gives the player one first-session ten-pull without introducing paid currency.

- [x] **Step 6: Run green test**

Run:

```bash
swift run OGameCoreTests
```

Expected: recruitment tests pass.

## Task 3: Commander Growth And Promotion

**Files:**
- Create: `Sources/OGameCore/CommanderGrowthEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] **Step 1: Write failing growth tests**

Add tests:

```swift
func testCommanderTrainingConsumesDataAndLevelsWithinCap() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 2, playerName: "Commander")
    let commander = OwnedCommander(definitionID: "mira-pathfinder", rarity: .elite, level: 1, acquiredAt: 0)
    universe.commanderRoster.ownedCommanders = [commander]
    universe.commanderRoster.trainingData = 1_000

    let didTrain = CommanderGrowthEngine.train(commander.id, usingTrainingData: 600, in: &universe)

    let updated = universe.commanderRoster.ownedCommanders.first { $0.id == commander.id }!
    require(didTrain, "Training should succeed when data is available")
    require(updated.level > 1, "Training should increase commander level")
    require(updated.level <= 30, "Elite commander should not exceed level 30")
    requireEqual(universe.commanderRoster.trainingData, 400, "Training should consume data")
}

func testCommanderPromotionConsumesShardsAndRaisesStars() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 3, playerName: "Commander")
    let commander = OwnedCommander(definitionID: "qiao-reactor", rarity: .epic, level: 10, stars: 0, acquiredAt: 0)
    universe.commanderRoster.ownedCommanders = [commander]
    universe.commanderRoster.shardsByDefinitionID["qiao-reactor"] = 20

    let didPromote = CommanderGrowthEngine.promote(commander.id, in: &universe)

    let updated = universe.commanderRoster.ownedCommanders.first { $0.id == commander.id }!
    require(didPromote, "Promotion should succeed with enough shards")
    requireEqual(updated.stars, 1, "Promotion should raise star level")
    requireEqual(universe.commanderRoster.shardsByDefinitionID["qiao-reactor"], nil, "Promotion should consume first-star shard cost")
}
```

- [x] **Step 2: Run red test**

Run:

```bash
swift run OGameCoreTests
```

Expected: compile failure because `CommanderGrowthEngine` does not exist.

- [x] **Step 3: Add growth engine**

Create `Sources/OGameCore/CommanderGrowthEngine.swift` with:

```swift
public enum CommanderGrowthEngine {
    public static func train(_ commanderID: CommanderID, usingTrainingData amount: Int, in universe: inout Universe) -> Bool
    public static func addExperience(_ amount: Double, to commanderID: CommanderID?, in universe: inout Universe)
    public static func promote(_ commanderID: CommanderID, in universe: inout Universe) -> Bool
    public static func levelCap(for rarity: CommanderRarity) -> Int
    public static func shardCostForNextStar(currentStars: Int) -> Int?
}
```

Rules:
- Training data and combat XP both feed `experience`.
- Every 100 XP grants the next level until cap. Keep overflow XP at cap as zero.
- Level caps: common 20, elite 30, epic 40, legendary 50.
- Promotion requires shard costs `[20, 40, 80, 160, 320]`.
- Star cap is 5.
- Invalid commander IDs return `false` for train/promote and no-op for XP.

- [x] **Step 4: Run green test**

Run:

```bash
swift run OGameCoreTests
```

Expected: growth tests pass.

## Task 4: Fleet Assignment And Travel Bonuses

**Files:**
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/DomainModels.swift`
- Create: `Sources/OGameCore/CommanderBonusEngine.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] **Step 1: Write failing fleet assignment tests**

Add tests:

```swift
func testFleetLaunchCanAssignAvailableCommanderAndPersistsID() {
    var setup = makeCommanderFleetTestUniverse()
    let commander = OwnedCommander(definitionID: "lin-vanguard", rarity: .legendary, level: 10, stars: 1, acquiredAt: 0)
    setup.universe.commanderRoster.ownedCommanders = [commander]

    let result = FleetEngine.launchFleet(
        from: setup.originID,
        to: setup.targetID,
        in: &setup.universe,
        mission: .attack,
        ships: [.lightFighter: 4],
        commanderID: commander.id
    )

    guard case .launched(let fleet) = result else {
        fatalError("Expected fleet launch with commander to succeed")
    }
    requireEqual(fleet.commanderID, commander.id, "Launched fleet should persist commander assignment")
}

func testAssignedCommanderCannotLeadTwoActiveFleets() {
    var setup = makeCommanderFleetTestUniverse()
    let commander = OwnedCommander(definitionID: "lin-vanguard", rarity: .legendary, acquiredAt: 0)
    setup.universe.commanderRoster.ownedCommanders = [commander]

    _ = FleetEngine.launchFleet(from: setup.originID, to: setup.targetID, in: &setup.universe, mission: .attack, ships: [.lightFighter: 1], commanderID: commander.id)
    let second = FleetEngine.launchFleet(from: setup.originID, to: setup.secondTargetID, in: &setup.universe, mission: .attack, ships: [.lightFighter: 1], commanderID: commander.id)

    requireEqual(second, .failure(.commanderUnavailable), "A commander already assigned to an active fleet should be unavailable")
}

func testFleetCommanderSpeedBonusShortensTravelTime() {
    var setup = makeCommanderFleetTestUniverse()
    let commander = OwnedCommander(definitionID: "lin-vanguard", rarity: .legendary, level: 20, stars: 2, acquiredAt: 0)
    setup.universe.commanderRoster.ownedCommanders = [commander]

    let base = FleetEngine.travelDuration(from: setup.originCoordinate, to: setup.targetCoordinate, ships: [.lightFighter: 4], ruleSet: setup.universe.ruleSet)
    let boosted = FleetEngine.travelDuration(from: setup.originCoordinate, to: setup.targetCoordinate, ships: [.lightFighter: 4], ruleSet: setup.universe.ruleSet, commanderBonus: CommanderBonusEngine.fleetBonus(for: commander, in: setup.universe))

    require(boosted < base, "Fleet admiral commander should shorten travel time")
}
```

Add this helper near other test helpers:

```swift
func makeCommanderFleetTestUniverse() -> (
    universe: Universe,
    originID: PlanetID,
    targetID: PlanetID,
    secondTargetID: PlanetID,
    originCoordinate: Coordinate,
    targetCoordinate: Coordinate
) {
    var universe = StarterUniverseFactory.makeNewGame(seed: 501, playerName: "Commander")
    let playerPlanets = PlayerVisibilityEngine.playerOwnedPlanets(in: universe).sorted {
        $0.coordinate.displayText < $1.coordinate.displayText
    }
    guard let origin = playerPlanets.first else {
        fatalError("Expected starter universe to contain a player planet")
    }
    guard let originIndex = universe.planets.firstIndex(where: { $0.id == origin.id }) else {
        fatalError("Expected origin planet index")
    }
    universe.planets[originIndex].shipInventory[.lightFighter] = 8
    universe.planets[originIndex].resources.deuterium = 100_000

    let targets = universe.planets
        .filter { $0.ownerID != universe.playerFactionID }
        .sorted { $0.coordinate.displayText < $1.coordinate.displayText }
    guard targets.count >= 2 else {
        fatalError("Expected at least two non-player targets")
    }

    return (
        universe,
        origin.id,
        targets[0].id,
        targets[1].id,
        origin.coordinate,
        targets[0].coordinate
    )
}
```

- [x] **Step 2: Run red test**

Run:

```bash
swift run OGameCoreTests
```

Expected: compile failure because `commanderID`, `.commanderUnavailable`, `CommanderBonusEngine`, and travel bonus overload do not exist.

- [x] **Step 3: Add bonus profile**

Create `Sources/OGameCore/CommanderBonusEngine.swift` with:

```swift
public struct CommanderFleetBonus: Equatable, Sendable {
    public var attackMultiplier: Double
    public var shieldMultiplier: Double
    public var hullMultiplier: Double
    public var speedMultiplier: Double
    public var fuelMultiplier: Double
    public var cargoMultiplier: Double
    public var lootMultiplier: Double
    public var expeditionRewardMultiplier: Double
    public var expeditionRiskModifier: Double

    public init(
        attackMultiplier: Double = 1,
        shieldMultiplier: Double = 1,
        hullMultiplier: Double = 1,
        speedMultiplier: Double = 1,
        fuelMultiplier: Double = 1,
        cargoMultiplier: Double = 1,
        lootMultiplier: Double = 1,
        expeditionRewardMultiplier: Double = 1,
        expeditionRiskModifier: Double = 0
    ) {
        self.attackMultiplier = attackMultiplier.isFinite ? max(attackMultiplier, 0) : 1
        self.shieldMultiplier = shieldMultiplier.isFinite ? max(shieldMultiplier, 0) : 1
        self.hullMultiplier = hullMultiplier.isFinite ? max(hullMultiplier, 0) : 1
        self.speedMultiplier = speedMultiplier.isFinite ? max(speedMultiplier, 0.1) : 1
        self.fuelMultiplier = fuelMultiplier.isFinite ? min(max(fuelMultiplier, 0.1), 2) : 1
        self.cargoMultiplier = cargoMultiplier.isFinite ? max(cargoMultiplier, 0) : 1
        self.lootMultiplier = lootMultiplier.isFinite ? max(lootMultiplier, 0) : 1
        self.expeditionRewardMultiplier = expeditionRewardMultiplier.isFinite ? max(expeditionRewardMultiplier, 0) : 1
        self.expeditionRiskModifier = expeditionRiskModifier.isFinite ? min(max(expeditionRiskModifier, -0.5), 0.5) : 0
    }

    public static let none = CommanderFleetBonus(
        attackMultiplier: 1,
        shieldMultiplier: 1,
        hullMultiplier: 1,
        speedMultiplier: 1,
        fuelMultiplier: 1,
        cargoMultiplier: 1,
        lootMultiplier: 1,
        expeditionRewardMultiplier: 1,
        expeditionRiskModifier: 0
    )
}

public enum CommanderBonusEngine {
    public static func fleetBonus(for commander: OwnedCommander?, in universe: Universe) -> CommanderFleetBonus
    public static func fleetBonus(for commanderID: CommanderID?, in universe: Universe) -> CommanderFleetBonus
    public static func summaryText(for commander: OwnedCommander, in universe: Universe) -> String
}
```

Formula:
- `power = rarityBase + level * 0.0025 + stars * 0.01`
- rarity base: common 0.01, elite 0.025, epic 0.04, legendary 0.06.
- `fleetAdmiral`: attack `1 + power`, speed `1 + power * 0.6`.
- `engineer`: shield `1 + power`, hull `1 + power * 0.8`, fuel `1 - min(power * 0.5, 0.15)`.
- `geologist`: cargo `1 + power`, loot `1 + power * 0.75`.
- `technocrat`: attack `1 + power * 0.5`, shield `1 + power * 0.35`.
- `explorer`: expedition reward `1 + power`, expedition risk modifier `-min(power * 0.5, 0.12)`.

- [x] **Step 4: Add assignment validation**

Modify `FleetLaunchFailure`:

```swift
case commanderUnavailable
```

Modify `FleetEngine.launchFleet` signature:

```swift
commanderID: CommanderID? = nil
```

Validation:
- If `commanderID == nil`, launch works exactly as before.
- If non-nil, commander must exist in `universe.commanderRoster.ownedCommanders`.
- Commander must not be assigned to any active fleet where `fleet.phase != .completed`.

- [x] **Step 5: Apply travel/fuel bonuses**

Modify `travelDuration` and `fuelCost` to accept:

```swift
commanderBonus: CommanderFleetBonus = .none
```

Travel:
- Multiply effective slowest speed by `commanderBonus.speedMultiplier`.

Fuel:
- Multiply final fuel by `commanderBonus.fuelMultiplier`.

Use the selected commander bonus when computing launch fuel and travel time.

- [x] **Step 6: Update AppModel launch API**

Modify `AppModel.launchFleet` and validation helpers to accept `commanderID: CommanderID?`.

Add:

```swift
var availableCommandersForFleet: [OwnedCommander] {
    let activeCommanderIDs = Set(universe.fleets.compactMap { $0.phase == .completed ? nil : $0.commanderID })
    return universe.commanderRoster.ownedCommanders.filter { !activeCommanderIDs.contains($0.id) }
}
```

- [x] **Step 7: Run green test**

Run:

```bash
swift run OGameCoreTests
```

Expected: assignment and travel bonus tests pass.

## Task 5: Combat, Exploration, And XP Rewards

**Files:**
- Modify: `Sources/OGameCore/BattleSimulationEngine.swift`
- Modify: `Sources/OGameCore/CombatEngine.swift`
- Modify: `Sources/OGameCore/FleetEngine.swift`
- Modify: `Sources/OGameCore/ExplorationEventEngine.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] **Step 1: Write failing combat bonus tests**

Add tests:

```swift
func testBattleSimulationAppliesCommanderAttackBonus() {
    let base = BattleSimulationEngine.resolve(
        BattleSimulationInput(
            attackerShips: [.lightFighter: 3],
            defenderShips: [.lightFighter: 3],
            defenderDefenses: [:],
            attackerResearch: ResearchState(),
            defenderResearch: ResearchState(),
            ruleSet: .fastSkirmish,
            seed: 11
        )
    )

    let boosted = BattleSimulationEngine.resolve(
        BattleSimulationInput(
            attackerShips: [.lightFighter: 3],
            defenderShips: [.lightFighter: 3],
            defenderDefenses: [:],
            attackerResearch: ResearchState(),
            defenderResearch: ResearchState(),
            ruleSet: .fastSkirmish,
            seed: 11,
            attackerCommanderBonus: CommanderFleetBonus(attackMultiplier: 1.25, shieldMultiplier: 1, hullMultiplier: 1, speedMultiplier: 1, fuelMultiplier: 1, cargoMultiplier: 1, lootMultiplier: 1, expeditionRewardMultiplier: 1, expeditionRiskModifier: 0)
        )
    )

    require((boosted.rounds.first?.attackerPower ?? 0) > (base.rounds.first?.attackerPower ?? 0), "Commander attack bonus should increase attacker round power")
}

func testAttackMissionGrantsCommanderExperience() {
    var setup = makeCommanderFleetTestUniverse()
    let commander = OwnedCommander(definitionID: "lin-vanguard", rarity: .legendary, acquiredAt: 0)
    setup.universe.commanderRoster.ownedCommanders = [commander]

    let launch = FleetEngine.launchFleet(from: setup.originID, to: setup.targetID, in: &setup.universe, mission: .attack, ships: [.lightFighter: 4], commanderID: commander.id)
    guard case .launched = launch else { fatalError("Expected launch") }
    setup.universe.gameTime = setup.universe.fleets.first!.arrivalTime
    FleetEngine.resolveDueFleets(in: &setup.universe)

    let updated = setup.universe.commanderRoster.ownedCommanders.first { $0.id == commander.id }!
    require(updated.experience > 0 || updated.level > commander.level, "Commander should gain XP from resolved combat")
}
```

- [x] **Step 2: Run red test**

Run:

```bash
swift run OGameCoreTests
```

Expected: compile failure for `attackerCommanderBonus`.

- [x] **Step 3: Extend battle simulation input**

Modify `BattleSimulationInput`:

```swift
public var attackerCommanderBonus: CommanderFleetBonus
public var defenderCommanderBonus: CommanderFleetBonus
```

Default both to `.none` in initializer.

Modify `appendShips` calls:
- Attacker ships use `attackerCommanderBonus`.
- Defender ships use `defenderCommanderBonus`.

Apply:
- attack = attack * `bonus.attackMultiplier`
- maxShield/shield = shield * `bonus.shieldMultiplier`
- hull = hull * `bonus.hullMultiplier`

Do not apply commander bonuses to static defenses in this task.

- [x] **Step 4: Pass commander bonus from combat engine**

In `CombatEngine.resolveAttack` and `previewAttack`, compute:

```swift
let attackerCommanderBonus = CommanderBonusEngine.fleetBonus(for: fleet.commanderID, in: universe)
```

Pass it into `BattleSimulationInput`.

After combat resolution, award XP:

```swift
let xp = max(25, shipCost(attackerLostShips, ruleSet: universe.ruleSet).totalAmount / 500 + defenderLosses.totalAmount / 500)
CommanderGrowthEngine.addExperience(xp, to: fleet.commanderID, in: &universe)
```

- [x] **Step 5: Apply exploration bonus and XP**

In `FleetEngine.resolveArrival` for `.explore`:
- Compute `let bonus = CommanderBonusEngine.fleetBonus(for: fleet.commanderID, in: universe)`.
- Multiply positive `outcome.reward` by `bonus.expeditionRewardMultiplier`.
- Apply risk modifier in `ExplorationEventEngine` by adding optional `riskModifier: Double = 0` to `resolve`.
- Award XP: 15 for normal exploration, 40 for risk events, 60 for hostile/black-hole survival if such event exists.

- [x] **Step 6: Run green test**

Run:

```bash
swift run OGameCoreTests
```

Expected: combat bonus and commander XP tests pass.

## Task 6: Strategic Advisor, Audit, And Balance Tool

**Files:**
- Modify: `Sources/OGameCore/StrategicAdvisorEngine.swift`
- Modify: `Sources/OGameCore/GameplayAuditEngine.swift`
- Modify: `Sources/OGameBalanceTool/main.swift`
- Modify: `Tests/OGameCoreTests/main.swift`

- [x] **Step 1: Write failing advisor/audit tests**

Add tests:

```swift
func testStrategicAdvisorSurfacesCommanderRecruitmentAndAssignment() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 5, playerName: "Commander")
    universe.commanderRoster.recruitmentTickets = 10
    StrategicEngine.updateStrategicState(in: &universe)

    let recommendations = StrategicAdvisorEngine.recommendations(in: universe, limit: 12)
    let kinds = Set(recommendations.map(\.kind))

    require(kinds.contains(.commanderRecruitment), "Advisor should surface available commander recruitment")
}

func testGameplayAuditCountsCommanderSignals() {
    let result = GameplayAuditEngine.runAutoplayAudit(seed: 1, duration: 14_400, settings: GameSettings(difficulty: .standard))

    require(result.commanderSignalCount > 0, "Gameplay audit should count commander module signals")
}
```

- [x] **Step 2: Run red test**

Run:

```bash
swift run OGameCoreTests
```

Expected: compile failure because `.commanderRecruitment` and `commanderSignalCount` do not exist.

- [x] **Step 3: Add advisor kinds**

Add to `StrategicAdvisorRecommendation.Kind`:

```swift
case commanderRecruitment
case commanderTraining
case commanderAssignment
```

Add recommendations:
- Recruitment: `recruitmentTickets >= 1`, priority `.opportunity`, action label `"招募"`.
- Training: any owned commander and `trainingData >= 100`, priority `.info`, action label `"训练"`.
- Assignment: active fleet page has launchable ships and at least one available commander, priority `.opportunity`, action label `"派驻"`.

- [x] **Step 4: Add audit counts**

Add `public var commanderSignalCount: Int` to `GameplayAuditResult`.

Count:

```swift
let commanderSignalCount = universe.commanderRoster.ownedCommanders.count +
    universe.commanderRoster.recruitmentTickets +
    universe.commanderRoster.trainingData / 100
```

Add `commander_signals` column to `OGameBalanceTool` autoplay audit CSV.

- [x] **Step 5: Run green test and balance tool**

Run:

```bash
swift run OGameCoreTests
swift run OGameBalanceTool
```

Expected: tests pass and audit CSV includes `commander_signals`.

## Task 7: macOS Commander UI

**Files:**
- Modify: `Sources/OGameMac/ContentView.swift`
- Modify: `Sources/OGameMac/AppModel.swift`
- Modify: `Sources/OGameMac/Views/DashboardViews.swift`

- [x] **Step 1: Add app model summaries/actions**

Add summary structs near existing UI summary structs:

```swift
struct CommanderSummary: Identifiable {
    let id: CommanderID
    let name: String
    let title: String
    let rarityText: String
    let specialtyText: String
    let levelText: String
    let starsText: String
    let bonusText: String
    let isAssigned: Bool
}

struct CommanderRecruitmentPreview {
    let ticketText: String
    let pityText: String
    let tenPullAvailable: Bool
}
```

Add `AppModel` APIs:

```swift
var commanderSummaries: [CommanderSummary]
var commanderRecruitmentPreview: CommanderRecruitmentPreview
func recruitCommanders(count: Int)
func trainCommander(_ commanderID: CommanderID)
func promoteCommander(_ commanderID: CommanderID)
func commanderName(for commanderID: CommanderID?) -> String
```

Behavior:
- `recruitCommanders(count:)` calls `CommanderRecruitmentEngine.recruit`.
- `trainCommander` spends up to 100 training data per click.
- `promoteCommander` calls `CommanderGrowthEngine.promote`.
- Each successful action updates `statusMessage` and autosaves via existing save pattern.

- [x] **Step 2: Add sidebar destination**

Modify `SidebarDestination`:

```swift
case commanders
```

Add in sidebar under `帝国`:

```swift
Label("指挥官", systemImage: "person.crop.rectangle.stack")
    .tag(SidebarDestination.commanders)
```

Add to `DetailView`:

```swift
case .commanders:
    CommanderOverviewView(model: model)
```

- [x] **Step 3: Add commander overview view**

Add `CommanderOverviewView` in `ContentView.swift`:

```swift
private struct CommanderOverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GamePage(title: "指挥官", model: model) {
            CommanderRecruitmentPanel(model: model)
            CommanderRosterPanel(model: model)
        }
        .navigationTitle("指挥官")
    }
}
```

Panels:
- Recruitment panel: ticket count, pity count, one-pull and ten-pull buttons.
- Roster panel: card/list rows with rarity, level, stars, specialty, current bonus, assigned state, train/promote buttons.
- Empty state: `"暂无指挥官"` with `person.crop.circle.badge.questionmark`.

- [x] **Step 4: Add fleet dispatch picker**

In `FleetOverviewView`, add state:

```swift
@State private var commanderID: CommanderID?
```

Pass binding into `FleetDispatchPanel`.

Inside `FleetDispatchPanel`, add picker after mission picker:

```swift
Picker("指挥官", selection: $commanderID) {
    Text("不派驻").tag(Optional<CommanderID>.none)
    ForEach(model.availableCommandersForFleet) { commander in
        Text(model.commanderName(for: commander.id)).tag(Optional(commander.id))
    }
}
```

Pass `commanderID` into `model.launchFleet`.

- [x] **Step 5: Add advisor navigation/icons**

In `DashboardViews.navigate(to:)`:
- `.commanderRecruitment`, `.commanderTraining`, `.commanderAssignment` navigate to `.commanders`.

In `StrategicAdvisorRecommendation.Kind.systemImage`:
- recruitment: `"person.crop.circle.badge.plus"`
- training: `"chart.line.uptrend.xyaxis"`
- assignment: `"person.fill.checkmark"`

- [x] **Step 6: Build**

Run:

```bash
swift build
```

Expected: `OGameMac` compiles.

## Task 8: Documentation And Verification

**Files:**
- Create: `docs/native-macos-ogame/commander-system-2026-05-12.md`
- Modify: `docs/native-macos-ogame/balance-playtest-guide.md`

- [x] **Step 1: Add player-facing documentation**

Create `docs/native-macos-ogame/commander-system-2026-05-12.md` with sections:
- What commanders are.
- How recruitment tickets work.
- Rarity rates and pity.
- Duplicate shards and promotion.
- Leveling and training data.
- Fleet assignment and bonus categories.
- Balance limits: optional, no paid currency, bonuses capped.

- [x] **Step 2: Update balance guide**

Add `commander_signals` to `docs/native-macos-ogame/balance-playtest-guide.md` audit field list.

- [x] **Step 3: Full verification**

Run:

```bash
swift run OGameCoreTests
swift run OGamePersistenceTests
swift build
swift run OGameBalanceTool
git diff --check
```

Expected:
- Core tests pass.
- Persistence tests pass.
- macOS executable builds.
- Balance tool prints `commander_signals`.
- `git diff --check` returns no output.

- [x] **Step 4: Commit**

Commit after all verification passes:

```bash
git add Sources/OGameCore Sources/OGameMac Sources/OGameBalanceTool Tests/OGameCoreTests docs/native-macos-ogame docs/superpowers/plans/2026-05-12-commander-gacha-module.md
git commit -m "feat: add commander recruitment and fleet bonuses"
```

## Out Of Scope For This Pass

- Real-money currency, paid shop, or limited-time monetization banners.
- Commander portraits generated as image assets.
- Prison/capture mechanics for enemy commanders.
- Full enemy AI commander recruitment.
- Multiple commanders per fleet.
- Commander equipment.

## Self-Review

- Spec coverage: recruitment, pity, commander ownership, duplicates, growth, promotion, fleet assignment, combat/travel bonuses, XP, UI, advisor, audit, docs, and verification are covered.
- Placeholder scan: no open requirement depends on unspecified rates, names, formulas, or file paths.
- Type consistency: `CommanderID`, `CommanderRoster`, `OwnedCommander`, `CommanderRecruitmentState`, `CommanderFleetBonus`, and advisor kind names are consistent across tasks.
