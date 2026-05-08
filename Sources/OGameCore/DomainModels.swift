import Foundation

public struct GameSettings: Codable, Equatable, Sendable {
    public enum OfflineIntensity: String, Codable, CaseIterable, Sendable {
        case paused
        case reduced
        case normal
        case intense

        public var multiplier: Double {
            switch self {
            case .paused:
                return 0
            case .reduced:
                return 0.5
            case .normal:
                return 1
            case .intense:
                return 2
            }
        }
    }

    public enum Difficulty: String, Codable, CaseIterable, Sendable {
        case easy
        case standard
        case hard
    }

    public var offlineIntensity: OfflineIntensity
    public var gameSpeed: Double
    public var isAutosaveEnabled: Bool
    public var difficulty: Difficulty

    public init(
        offlineIntensity: OfflineIntensity = .normal,
        gameSpeed: Double = 1,
        isAutosaveEnabled: Bool = true,
        difficulty: Difficulty = .standard
    ) {
        self.offlineIntensity = offlineIntensity
        self.gameSpeed = Self.clampedGameSpeed(gameSpeed)
        self.isAutosaveEnabled = isAutosaveEnabled
        self.difficulty = difficulty
    }

    public static func clampedGameSpeed(_ value: Double) -> Double {
        guard value.isFinite else {
            return 1
        }

        return min(max(value, 0.25), 8)
    }

    private enum CodingKeys: String, CodingKey {
        case offlineIntensity
        case gameSpeed
        case isAutosaveEnabled
        case difficulty
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = GameSettings()
        let offlineIntensityValue = try? container.decodeIfPresent(String.self, forKey: .offlineIntensity)
        let difficultyValue = try? container.decodeIfPresent(String.self, forKey: .difficulty)
        let gameSpeedValue = try? container.decodeIfPresent(Double.self, forKey: .gameSpeed)
        let autosaveValue = try? container.decodeIfPresent(Bool.self, forKey: .isAutosaveEnabled)

        self.offlineIntensity = offlineIntensityValue
            .flatMap(OfflineIntensity.init(rawValue:)) ?? defaults.offlineIntensity
        self.gameSpeed = Self.clampedGameSpeed(gameSpeedValue ?? defaults.gameSpeed)
        self.isAutosaveEnabled = autosaveValue ?? defaults.isAutosaveEnabled
        self.difficulty = difficultyValue.flatMap(Difficulty.init(rawValue:)) ?? defaults.difficulty
    }
}

public struct AIDifficultyPolicy: Equatable, Sendable {
    public var difficulty: GameSettings.Difficulty
    public var allowsRankingBasedAttacks: Bool
    public var requiresReportBeforeAttack: Bool
    public var defensiveQuantityBonus: Int

    public init(difficulty: GameSettings.Difficulty = .standard) {
        self.difficulty = difficulty

        switch difficulty {
        case .easy:
            self.allowsRankingBasedAttacks = false
            self.requiresReportBeforeAttack = true
            self.defensiveQuantityBonus = 1
        case .standard:
            self.allowsRankingBasedAttacks = false
            self.requiresReportBeforeAttack = true
            self.defensiveQuantityBonus = 0
        case .hard:
            self.allowsRankingBasedAttacks = true
            self.requiresReportBeforeAttack = false
            self.defensiveQuantityBonus = 0
        }
    }

    public static let standard = AIDifficultyPolicy(difficulty: .standard)

    public func defenseBuildQuantity(forThreatScore threatScore: Int) -> Int {
        guard threatScore > 0 else {
            return 0
        }

        return max(1, min(3, 1 + defensiveQuantityBonus))
    }
}

public struct Universe: Codable, Equatable, Sendable, Identifiable {
    public var id: UniverseID
    public var name: String
    public var seed: UInt64
    public var gameTime: TimeInterval
    public var lastSimulatedWallClockTime: Date?
    public var playerFactionID: FactionID
    public var factions: [Faction]
    public var planets: [Planet]
    public var fleets: [Fleet]
    public var events: [GameEvent]
    public var reports: [Report]
    public var ruleSet: RuleSet
    public var rankings: [FactionScore]
    public var victoryState: VictoryState
    public var explorationRecords: [ExplorationRecord]

    public init(
        id: UniverseID = UniverseID(),
        name: String,
        seed: UInt64,
        gameTime: TimeInterval = 0,
        lastSimulatedWallClockTime: Date? = nil,
        playerFactionID: FactionID,
        factions: [Faction],
        planets: [Planet],
        fleets: [Fleet],
        events: [GameEvent],
        reports: [Report] = [],
        ruleSet: RuleSet,
        rankings: [FactionScore] = [],
        victoryState: VictoryState = VictoryState(),
        explorationRecords: [ExplorationRecord] = []
    ) {
        self.id = id
        self.name = name
        self.seed = seed
        self.gameTime = gameTime
        self.lastSimulatedWallClockTime = lastSimulatedWallClockTime
        self.playerFactionID = playerFactionID
        self.factions = factions
        self.planets = planets
        self.fleets = fleets
        self.events = events
        self.reports = reports
        self.ruleSet = ruleSet
        self.rankings = rankings
        self.victoryState = victoryState
        self.explorationRecords = explorationRecords
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case seed
        case gameTime
        case lastSimulatedWallClockTime
        case playerFactionID
        case factions
        case planets
        case fleets
        case events
        case reports
        case ruleSet
        case rankings
        case victoryState
        case explorationRecords
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(UniverseID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.seed = try container.decode(UInt64.self, forKey: .seed)
        self.gameTime = try container.decode(TimeInterval.self, forKey: .gameTime)
        self.lastSimulatedWallClockTime = try container.decodeIfPresent(Date.self, forKey: .lastSimulatedWallClockTime)
        self.playerFactionID = try container.decode(FactionID.self, forKey: .playerFactionID)
        self.factions = try container.decode([Faction].self, forKey: .factions)
        self.planets = try container.decode([Planet].self, forKey: .planets)
        self.fleets = try container.decode([Fleet].self, forKey: .fleets)
        self.events = try container.decode([GameEvent].self, forKey: .events)
        self.reports = try container.decodeIfPresentStrict([Report].self, forKey: .reports) ?? []
        self.ruleSet = try container.decode(RuleSet.self, forKey: .ruleSet)
        self.rankings = try container.decodeIfPresentStrict([FactionScore].self, forKey: .rankings) ?? []
        self.victoryState = try container.decodeIfPresentStrict(VictoryState.self, forKey: .victoryState) ?? VictoryState()
        self.explorationRecords = try container.decodeIfPresentStrict([ExplorationRecord].self, forKey: .explorationRecords) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(seed, forKey: .seed)
        try container.encode(gameTime, forKey: .gameTime)
        try container.encodeIfPresent(lastSimulatedWallClockTime, forKey: .lastSimulatedWallClockTime)
        try container.encode(playerFactionID, forKey: .playerFactionID)
        try container.encode(factions, forKey: .factions)
        try container.encode(planets, forKey: .planets)
        try container.encode(fleets, forKey: .fleets)
        try container.encode(events, forKey: .events)
        try container.encode(reports, forKey: .reports)
        try container.encode(ruleSet, forKey: .ruleSet)
        try container.encode(rankings, forKey: .rankings)
        try container.encode(victoryState, forKey: .victoryState)
        try container.encode(explorationRecords, forKey: .explorationRecords)
    }
}

public struct FactionScore: Codable, Equatable, Sendable, Identifiable {
    public var factionID: FactionID
    public var factionName: String
    public var rank: Int
    public var economyScore: Double
    public var fleetScore: Double
    public var researchScore: Double
    public var planetScore: Double
    public var defenseScore: Double
    public var victoryProgress: Double
    public var totalScore: Double

    public var id: FactionID { factionID }

    public init(
        factionID: FactionID,
        factionName: String,
        rank: Int = 0,
        economyScore: Double = 0,
        fleetScore: Double = 0,
        researchScore: Double = 0,
        planetScore: Double = 0,
        defenseScore: Double = 0,
        victoryProgress: Double = 0,
        totalScore: Double = 0
    ) {
        self.factionID = factionID
        self.factionName = factionName
        self.rank = rank
        self.economyScore = economyScore
        self.fleetScore = fleetScore
        self.researchScore = researchScore
        self.planetScore = planetScore
        self.defenseScore = defenseScore
        self.victoryProgress = victoryProgress
        self.totalScore = totalScore
    }
}

public struct ExplorationRecord: Codable, Equatable, Sendable {
    public var factionID: FactionID
    public var targetPlanetID: PlanetID
    public var exploredAt: TimeInterval
    public var reward: ResourceBundle
    public var discoveredResources: ResourceBundle
    public var discoveredDebris: ResourceBundle
    public var discoveredOwnerID: FactionID?
    public var discoveredNeutral: Bool

    public init(
        factionID: FactionID,
        targetPlanetID: PlanetID,
        exploredAt: TimeInterval,
        reward: ResourceBundle = .zero,
        discoveredResources: ResourceBundle = .zero,
        discoveredDebris: ResourceBundle = .zero,
        discoveredOwnerID: FactionID? = nil,
        discoveredNeutral: Bool = false
    ) {
        self.factionID = factionID
        self.targetPlanetID = targetPlanetID
        self.exploredAt = exploredAt.isFinite ? exploredAt : 0
        self.reward = reward.nonnegative
        self.discoveredResources = discoveredResources.nonnegative
        self.discoveredDebris = discoveredDebris.nonnegative
        self.discoveredOwnerID = discoveredOwnerID
        self.discoveredNeutral = discoveredNeutral
    }
}

public enum VictoryRoute: String, Codable, CaseIterable, Sendable {
    case economy
    case technology
    case domination
    case exploration
}

public struct VictoryProgress: Codable, Equatable, Sendable {
    public var factionID: FactionID
    public var route: VictoryRoute
    public var currentValue: Double
    public var targetValue: Double
    public var progress: Double

    public var isComplete: Bool {
        progress >= 1
    }

    public init(
        factionID: FactionID,
        route: VictoryRoute,
        currentValue: Double,
        targetValue: Double,
        progress: Double
    ) {
        self.factionID = factionID
        self.route = route
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.progress = progress
    }
}

public struct VictoryState: Codable, Equatable, Sendable {
    public var progress: [VictoryProgress]
    public var winningFactionID: FactionID?
    public var winningRoute: VictoryRoute?
    public var achievedAt: TimeInterval?
    public var didAnnounceVictory: Bool
    public var exploredPlanetIDs: [PlanetID]

    public init(
        progress: [VictoryProgress] = [],
        winningFactionID: FactionID? = nil,
        winningRoute: VictoryRoute? = nil,
        achievedAt: TimeInterval? = nil,
        didAnnounceVictory: Bool = false,
        exploredPlanetIDs: [PlanetID] = []
    ) {
        self.progress = progress
        self.winningFactionID = winningFactionID
        self.winningRoute = winningRoute
        self.achievedAt = achievedAt
        self.didAnnounceVictory = didAnnounceVictory
        self.exploredPlanetIDs = exploredPlanetIDs
    }
}

public struct BuildQueueItem: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var planetID: PlanetID
    public var buildingKind: BuildingKind
    public var targetLevel: Int
    public var startTime: TimeInterval
    public var finishTime: TimeInterval
    public var paidCost: ResourceBundle

    public init(
        id: UUID = UUID(),
        planetID: PlanetID,
        buildingKind: BuildingKind,
        targetLevel: Int,
        startTime: TimeInterval,
        finishTime: TimeInterval,
        paidCost: ResourceBundle
    ) {
        self.id = id
        self.planetID = planetID
        self.buildingKind = buildingKind
        self.targetLevel = targetLevel
        self.startTime = startTime
        self.finishTime = finishTime
        self.paidCost = paidCost
    }
}

public struct ResearchQueueItem: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var factionID: FactionID
    public var technologyKind: TechnologyKind
    public var targetLevel: Int
    public var startTime: TimeInterval
    public var finishTime: TimeInterval
    public var paidCost: ResourceBundle

    public init(
        id: UUID = UUID(),
        factionID: FactionID,
        technologyKind: TechnologyKind,
        targetLevel: Int,
        startTime: TimeInterval,
        finishTime: TimeInterval,
        paidCost: ResourceBundle
    ) {
        self.id = id
        self.factionID = factionID
        self.technologyKind = technologyKind
        self.targetLevel = targetLevel
        self.startTime = startTime
        self.finishTime = finishTime
        self.paidCost = paidCost
    }
}

public struct UnitBuildQueueItem: Codable, Equatable, Sendable, Identifiable {
    public enum UnitKind: Equatable, Sendable {
        case ship(ShipKind)
        case defense(DefenseKind)
        case missile(MissileKind)
    }

    public var id: UUID
    public var planetID: PlanetID
    public var unitKind: UnitKind
    public var quantity: Int
    public var startTime: TimeInterval
    public var finishTime: TimeInterval
    public var paidCost: ResourceBundle

    public init(
        id: UUID = UUID(),
        planetID: PlanetID,
        unitKind: UnitKind,
        quantity: Int,
        startTime: TimeInterval,
        finishTime: TimeInterval,
        paidCost: ResourceBundle
    ) {
        self.id = id
        self.planetID = planetID
        self.unitKind = unitKind
        self.quantity = quantity
        self.startTime = startTime
        self.finishTime = finishTime
        self.paidCost = paidCost
    }

    private enum UnitType: String, Codable {
        case ship
        case defense
        case missile
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case planetID
        case unitType
        case unitKind
        case quantity
        case startTime
        case finishTime
        case paidCost
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(UUID.self, forKey: .id)
        self.planetID = try container.decode(PlanetID.self, forKey: .planetID)
        self.quantity = try container.decode(Int.self, forKey: .quantity)
        self.startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        self.finishTime = try container.decode(TimeInterval.self, forKey: .finishTime)
        self.paidCost = try container.decode(ResourceBundle.self, forKey: .paidCost)

        switch try container.decode(UnitType.self, forKey: .unitType) {
        case .ship:
            self.unitKind = .ship(try container.decode(ShipKind.self, forKey: .unitKind))
        case .defense:
            self.unitKind = .defense(try container.decode(DefenseKind.self, forKey: .unitKind))
        case .missile:
            self.unitKind = .missile(try container.decode(MissileKind.self, forKey: .unitKind))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(planetID, forKey: .planetID)
        switch unitKind {
        case .ship(let shipKind):
            try container.encode(UnitType.ship, forKey: .unitType)
            try container.encode(shipKind, forKey: .unitKind)
        case .defense(let defenseKind):
            try container.encode(UnitType.defense, forKey: .unitType)
            try container.encode(defenseKind, forKey: .unitKind)
        case .missile(let missileKind):
            try container.encode(UnitType.missile, forKey: .unitType)
            try container.encode(missileKind, forKey: .unitKind)
        }
        try container.encode(quantity, forKey: .quantity)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(finishTime, forKey: .finishTime)
        try container.encode(paidCost, forKey: .paidCost)
    }
}

public enum RelationPosture: String, Codable, CaseIterable, Sendable {
    case neutral
    case wary
    case hostile
    case pressured
}

public struct FactionRelation: Codable, Equatable, Sendable {
    public static let memoryCap = 999

    public var factionID: FactionID
    public var posture: RelationPosture
    public var threatScore: Int
    public var lastInteractionTime: TimeInterval
    public var attackCount: Int

    public var summary: String {
        switch posture {
        case .neutral:
            return "未记录直接冲突。"
        case .wary:
            return "近期敌对压力使该势力保持警惕。"
        case .hostile:
            return "该势力的攻击已被记为当前威胁。"
        case .pressured:
            return "该势力已经施加军事压力。"
        }
    }

    public init(
        factionID: FactionID,
        posture: RelationPosture = .neutral,
        threatScore: Int = 0,
        lastInteractionTime: TimeInterval = 0,
        attackCount: Int = 0
    ) {
        self.factionID = factionID
        self.posture = posture
        self.threatScore = min(max(threatScore, 0), Self.memoryCap)
        self.lastInteractionTime = lastInteractionTime.isFinite ? max(lastInteractionTime, 0) : 0
        self.attackCount = min(max(attackCount, 0), Self.memoryCap)
    }

    public static func normalized(_ relations: [FactionRelation]) -> [FactionRelation] {
        var rowsByFaction: [FactionID: FactionRelation] = [:]
        var duplicateFactionIDs: Set<FactionID> = []

        for relation in relations {
            let sanitized = FactionRelation(
                factionID: relation.factionID,
                posture: relation.posture,
                threatScore: relation.threatScore,
                lastInteractionTime: relation.lastInteractionTime,
                attackCount: relation.attackCount
            )

            if let existing = rowsByFaction[sanitized.factionID] {
                duplicateFactionIDs.insert(sanitized.factionID)
                let threatScore = min(max(existing.threatScore, sanitized.threatScore), memoryCap)
                let attackCount = cappedSum(existing.attackCount, sanitized.attackCount)
                rowsByFaction[sanitized.factionID] = FactionRelation(
                    factionID: sanitized.factionID,
                    posture: posture(forThreatScore: threatScore),
                    threatScore: threatScore,
                    lastInteractionTime: max(existing.lastInteractionTime, sanitized.lastInteractionTime),
                    attackCount: attackCount
                )
            } else {
                rowsByFaction[sanitized.factionID] = sanitized
            }
        }

        return rowsByFaction.values
            .map { relation in
                guard duplicateFactionIDs.contains(relation.factionID) else {
                    return relation
                }

                return FactionRelation(
                    factionID: relation.factionID,
                    posture: posture(forThreatScore: relation.threatScore),
                    threatScore: relation.threatScore,
                    lastInteractionTime: relation.lastInteractionTime,
                    attackCount: relation.attackCount
                )
            }
            .sorted { $0.factionID.rawValue.uuidString < $1.factionID.rawValue.uuidString }
    }

    private static func posture(forThreatScore threatScore: Int) -> RelationPosture {
        switch min(max(threatScore, 0), memoryCap) {
        case 0:
            return .neutral
        case 1...2:
            return .wary
        default:
            return .hostile
        }
    }

    private static func cappedSum(_ lhs: Int, _ rhs: Int) -> Int {
        let safeLHS = min(max(lhs, 0), memoryCap)
        let safeRHS = min(max(rhs, 0), memoryCap)
        let result = safeLHS.addingReportingOverflow(safeRHS)
        return result.overflow ? memoryCap : min(result.partialValue, memoryCap)
    }

    private enum CodingKeys: String, CodingKey {
        case factionID
        case posture
        case threatScore
        case lastInteractionTime
        case attackCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            factionID: try container.decode(FactionID.self, forKey: .factionID),
            posture: try container.decodeIfPresentStrict(RelationPosture.self, forKey: .posture) ?? .neutral,
            threatScore: try container.decodeIfPresentStrict(Int.self, forKey: .threatScore) ?? 0,
            lastInteractionTime: try container.decodeIfPresentStrict(TimeInterval.self, forKey: .lastInteractionTime) ?? 0,
            attackCount: try container.decodeIfPresentStrict(Int.self, forKey: .attackCount) ?? 0
        )
    }
}

public struct Faction: Codable, Equatable, Sendable, Identifiable {
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
    public var researchQueue: [ResearchQueueItem]
    public var relations: [FactionRelation]

    public init(
        id: FactionID = FactionID(),
        name: String,
        kind: Kind,
        strategy: Strategy,
        technology: ResearchState = ResearchState(),
        ownedPlanetIDs: [PlanetID] = [],
        researchQueue: [ResearchQueueItem] = [],
        relations: [FactionRelation] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.strategy = strategy
        self.technology = technology
        self.ownedPlanetIDs = ownedPlanetIDs
        self.researchQueue = researchQueue
        self.relations = FactionRelation.normalized(relations)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case strategy
        case technology
        case ownedPlanetIDs
        case researchQueue
        case relations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(FactionID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.kind = try container.decode(Kind.self, forKey: .kind)
        self.strategy = try container.decode(Strategy.self, forKey: .strategy)
        self.technology = try container.decode(ResearchState.self, forKey: .technology)
        self.ownedPlanetIDs = try container.decode([PlanetID].self, forKey: .ownedPlanetIDs)
        self.researchQueue = try container.decodeIfPresentStrict([ResearchQueueItem].self, forKey: .researchQueue) ?? []
        self.relations = FactionRelation.normalized(
            try container.decodeIfPresentStrict([FactionRelation].self, forKey: .relations) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(strategy, forKey: .strategy)
        try container.encode(technology, forKey: .technology)
        try container.encode(ownedPlanetIDs, forKey: .ownedPlanetIDs)
        try container.encode(researchQueue, forKey: .researchQueue)
        try container.encode(relations, forKey: .relations)
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

public struct Moon: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var createdAt: TimeInterval
    public var buildingLevels: [BuildingKind: Int]
    public var debrisOriginReportID: UUID?

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: TimeInterval,
        buildingLevels: [BuildingKind: Int] = [:],
        debrisOriginReportID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt.isFinite ? max(createdAt, 0) : 0
        self.buildingLevels = Self.normalizedBuildingLevels(buildingLevels)
        self.debrisOriginReportID = debrisOriginReportID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case buildingLevels
        case debrisOriginReportID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            createdAt: try container.decode(TimeInterval.self, forKey: .createdAt),
            buildingLevels: try container.decodeRawValueDictionary(BuildingKind.self, forKey: .buildingLevels),
            debrisOriginReportID: try container.decodeIfPresent(UUID.self, forKey: .debrisOriginReportID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeRawValueDictionary(buildingLevels, forKey: .buildingLevels)
        try container.encodeIfPresent(debrisOriginReportID, forKey: .debrisOriginReportID)
    }

    private static func normalizedBuildingLevels(_ levels: [BuildingKind: Int]) -> [BuildingKind: Int] {
        levels.reduce(into: [:]) { result, element in
            guard element.value > 0 else {
                return
            }

            result[element.key] = element.value
        }
    }
}

public struct Planet: Codable, Equatable, Sendable, Identifiable {
    public var id: PlanetID
    public var name: String
    public var coordinate: Coordinate
    public var ownerID: FactionID?
    public var resources: ResourceBundle
    public var storage: ResourceStorage
    public var energy: EnergyState
    public var buildingLevels: [BuildingKind: Int]
    public var productionSettings: [BuildingKind: Double]
    public var buildQueue: [BuildQueueItem]
    public var shipBuildQueue: [UnitBuildQueueItem]
    public var defenseBuildQueue: [UnitBuildQueueItem]
    public var shipInventory: [ShipKind: Int]
    public var defenseInventory: [DefenseKind: Int]
    public var missileInventory: [MissileKind: Int]
    public var debrisField: ResourceBundle
    public var moon: Moon?

    public init(
        id: PlanetID = PlanetID(),
        name: String,
        coordinate: Coordinate,
        ownerID: FactionID?,
        resources: ResourceBundle = .zero,
        storage: ResourceStorage = ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        energy: EnergyState = EnergyState(),
        buildingLevels: [BuildingKind: Int] = [:],
        productionSettings: [BuildingKind: Double] = [:],
        buildQueue: [BuildQueueItem] = [],
        shipBuildQueue: [UnitBuildQueueItem] = [],
        defenseBuildQueue: [UnitBuildQueueItem] = [],
        shipInventory: [ShipKind: Int] = [:],
        defenseInventory: [DefenseKind: Int] = [:],
        missileInventory: [MissileKind: Int] = [:],
        debrisField: ResourceBundle = .zero,
        moon: Moon? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.ownerID = ownerID
        self.resources = resources
        self.storage = storage
        self.energy = energy
        self.buildingLevels = buildingLevels
        self.productionSettings = Self.normalizedProductionSettings(productionSettings)
        self.buildQueue = buildQueue
        self.shipBuildQueue = shipBuildQueue
        self.defenseBuildQueue = defenseBuildQueue
        self.shipInventory = shipInventory
        self.defenseInventory = defenseInventory
        self.missileInventory = Self.normalizedMissileInventory(missileInventory)
        self.debrisField = debrisField
        self.moon = moon
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case coordinate
        case ownerID
        case resources
        case storage
        case energy
        case buildingLevels
        case productionSettings
        case buildQueue
        case shipBuildQueue
        case defenseBuildQueue
        case shipInventory
        case defenseInventory
        case missileInventory
        case debrisField
        case moon
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(PlanetID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.coordinate = try container.decode(Coordinate.self, forKey: .coordinate)
        self.ownerID = try container.decodeIfPresent(FactionID.self, forKey: .ownerID)
        self.resources = try container.decode(ResourceBundle.self, forKey: .resources)
        self.storage = try container.decode(ResourceStorage.self, forKey: .storage)
        self.energy = try container.decode(EnergyState.self, forKey: .energy)
        self.buildingLevels = try container.decodeRawValueDictionary(BuildingKind.self, forKey: .buildingLevels)
        self.productionSettings = Self.normalizedProductionSettings(
            try container.decodeRawValueDictionaryIfPresent(BuildingKind.self, forKey: .productionSettings) ?? [:]
        )
        self.buildQueue = try container.decodeIfPresentStrict([BuildQueueItem].self, forKey: .buildQueue) ?? []
        self.shipBuildQueue = try container.decodeIfPresentStrict([UnitBuildQueueItem].self, forKey: .shipBuildQueue) ?? []
        self.defenseBuildQueue = try container.decodeIfPresentStrict([UnitBuildQueueItem].self, forKey: .defenseBuildQueue) ?? []
        self.shipInventory = try container.decodeRawValueDictionary(ShipKind.self, forKey: .shipInventory)
        self.defenseInventory = try container.decodeRawValueDictionary(DefenseKind.self, forKey: .defenseInventory)
        self.missileInventory = Self.normalizedMissileInventory(
            try container.decodeRawValueDictionaryIfPresent(MissileKind.self, forKey: .missileInventory) ?? [:]
        )
        self.debrisField = try container.decodeIfPresentStrict(ResourceBundle.self, forKey: .debrisField) ?? .zero
        self.moon = try container.decodeIfPresentStrict(Moon.self, forKey: .moon)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encodeIfPresent(ownerID, forKey: .ownerID)
        try container.encode(resources, forKey: .resources)
        try container.encode(storage, forKey: .storage)
        try container.encode(energy, forKey: .energy)
        try container.encodeRawValueDictionary(buildingLevels, forKey: .buildingLevels)
        try container.encodeRawValueDictionary(productionSettings, forKey: .productionSettings)
        try container.encode(buildQueue, forKey: .buildQueue)
        try container.encode(shipBuildQueue, forKey: .shipBuildQueue)
        try container.encode(defenseBuildQueue, forKey: .defenseBuildQueue)
        try container.encodeRawValueDictionary(shipInventory, forKey: .shipInventory)
        try container.encodeRawValueDictionary(defenseInventory, forKey: .defenseInventory)
        try container.encodeRawValueDictionary(missileInventory, forKey: .missileInventory)
        try container.encode(debrisField, forKey: .debrisField)
        try container.encodeIfPresent(moon, forKey: .moon)
    }

    private static func normalizedProductionSettings(_ settings: [BuildingKind: Double]) -> [BuildingKind: Double] {
        Dictionary(uniqueKeysWithValues: settings.map { kind, value in
            guard value.isFinite else {
                return (kind, 1)
            }

            return (kind, min(max(value, 0), 1))
        })
    }

    private static func normalizedMissileInventory(_ inventory: [MissileKind: Int]) -> [MissileKind: Int] {
        inventory.reduce(into: [:]) { result, element in
            guard element.value > 0 else {
                return
            }

            result[element.key] = max((result[element.key] ?? 0) + element.value, 0)
        }
    }
}

public struct Fleet: Codable, Equatable, Sendable, Identifiable {
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
    public var originPlanetID: PlanetID?
    public var targetPlanetID: PlanetID?

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
        phase: Phase = .outbound,
        originPlanetID: PlanetID? = nil,
        targetPlanetID: PlanetID? = nil
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
        self.originPlanetID = originPlanetID
        self.targetPlanetID = targetPlanetID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID
        case mission
        case origin
        case target
        case ships
        case cargo
        case launchTime
        case arrivalTime
        case returnTime
        case phase
        case originPlanetID
        case targetPlanetID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(FleetID.self, forKey: .id)
        self.ownerID = try container.decode(FactionID.self, forKey: .ownerID)
        self.mission = try container.decode(Mission.self, forKey: .mission)
        self.origin = try container.decode(Coordinate.self, forKey: .origin)
        self.target = try container.decode(Coordinate.self, forKey: .target)
        self.ships = try container.decodeRawValueDictionary(ShipKind.self, forKey: .ships)
        self.cargo = try container.decode(ResourceBundle.self, forKey: .cargo)
        self.launchTime = try container.decode(TimeInterval.self, forKey: .launchTime)
        self.arrivalTime = try container.decode(TimeInterval.self, forKey: .arrivalTime)
        self.returnTime = try container.decode(TimeInterval.self, forKey: .returnTime)
        self.phase = try container.decode(Phase.self, forKey: .phase)
        self.originPlanetID = try container.decodeIfPresent(PlanetID.self, forKey: .originPlanetID)
        self.targetPlanetID = try container.decodeIfPresent(PlanetID.self, forKey: .targetPlanetID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(mission, forKey: .mission)
        try container.encode(origin, forKey: .origin)
        try container.encode(target, forKey: .target)
        try container.encodeRawValueDictionary(ships, forKey: .ships)
        try container.encode(cargo, forKey: .cargo)
        try container.encode(launchTime, forKey: .launchTime)
        try container.encode(arrivalTime, forKey: .arrivalTime)
        try container.encode(returnTime, forKey: .returnTime)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(originPlanetID, forKey: .originPlanetID)
        try container.encodeIfPresent(targetPlanetID, forKey: .targetPlanetID)
    }
}

public struct ResearchState: Codable, Equatable, Sendable {
    public var levels: [TechnologyKind: Int]

    public init(levels: [TechnologyKind: Int] = [:]) {
        self.levels = levels
    }

    private enum CodingKeys: String, CodingKey {
        case levels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.levels = try container.decodeRawValueDictionary(TechnologyKind.self, forKey: .levels)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeRawValueDictionary(levels, forKey: .levels)
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

public struct ReportParticipant: Codable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable {
        case attacker
        case defender
        case observer
    }

    public var role: Role
    public var factionID: FactionID?
    public var planetID: PlanetID?
    public var name: String
    public var beforeShips: [ShipKind: Int]
    public var afterShips: [ShipKind: Int]
    public var beforeDefenses: [DefenseKind: Int]
    public var afterDefenses: [DefenseKind: Int]
    public var losses: ResourceBundle

    public init(
        role: Role,
        factionID: FactionID?,
        planetID: PlanetID?,
        name: String,
        beforeShips: [ShipKind: Int] = [:],
        afterShips: [ShipKind: Int] = [:],
        beforeDefenses: [DefenseKind: Int] = [:],
        afterDefenses: [DefenseKind: Int] = [:],
        losses: ResourceBundle = .zero
    ) {
        self.role = role
        self.factionID = factionID
        self.planetID = planetID
        self.name = name
        self.beforeShips = beforeShips
        self.afterShips = afterShips
        self.beforeDefenses = beforeDefenses
        self.afterDefenses = afterDefenses
        self.losses = losses
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case factionID
        case planetID
        case name
        case beforeShips
        case afterShips
        case beforeDefenses
        case afterDefenses
        case losses
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.role = try container.decode(Role.self, forKey: .role)
        self.factionID = try container.decodeIfPresent(FactionID.self, forKey: .factionID)
        self.planetID = try container.decodeIfPresent(PlanetID.self, forKey: .planetID)
        self.name = try container.decode(String.self, forKey: .name)
        self.beforeShips = try container.decodeRawValueDictionary(ShipKind.self, forKey: .beforeShips)
        self.afterShips = try container.decodeRawValueDictionary(ShipKind.self, forKey: .afterShips)
        self.beforeDefenses = try container.decodeRawValueDictionary(DefenseKind.self, forKey: .beforeDefenses)
        self.afterDefenses = try container.decodeRawValueDictionary(DefenseKind.self, forKey: .afterDefenses)
        self.losses = try container.decode(ResourceBundle.self, forKey: .losses)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(factionID, forKey: .factionID)
        try container.encodeIfPresent(planetID, forKey: .planetID)
        try container.encode(name, forKey: .name)
        try container.encodeRawValueDictionary(beforeShips, forKey: .beforeShips)
        try container.encodeRawValueDictionary(afterShips, forKey: .afterShips)
        try container.encodeRawValueDictionary(beforeDefenses, forKey: .beforeDefenses)
        try container.encodeRawValueDictionary(afterDefenses, forKey: .afterDefenses)
        try container.encode(losses, forKey: .losses)
    }
}

public struct Report: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case battle
        case espionage
        case exploration
        case missile
    }

    public var id: UUID
    public var time: TimeInterval
    public var kind: Kind
    public var title: String
    public var summary: String
    public var participants: [ReportParticipant]
    public var loot: ResourceBundle
    public var debris: ResourceBundle
    public var losses: ResourceBundle

    public init(
        id: UUID = UUID(),
        time: TimeInterval,
        kind: Kind,
        title: String,
        summary: String,
        participants: [ReportParticipant],
        loot: ResourceBundle = .zero,
        debris: ResourceBundle = .zero,
        losses: ResourceBundle = .zero
    ) {
        self.id = id
        self.time = time
        self.kind = kind
        self.title = title
        self.summary = summary
        self.participants = participants
        self.loot = loot
        self.debris = debris
        self.losses = losses
    }
}

public struct RuleSet: Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var baseTickInterval: TimeInterval
    public var offlineChunkInterval: TimeInterval
    public var buildingRules: [BuildingKind: BuildingRule]
    public var researchRules: [TechnologyKind: ResearchRule]
    public var shipRules: [ShipKind: ShipRule]
    public var defenseRules: [DefenseKind: DefenseRule]
    public var missileRules: [MissileKind: MissileRule]

    public init(
        id: String,
        displayName: String,
        baseTickInterval: TimeInterval,
        offlineChunkInterval: TimeInterval,
        buildingRules: [BuildingKind: BuildingRule] = RuleSet.fastSkirmishBuildingRules,
        researchRules: [TechnologyKind: ResearchRule] = RuleSet.fastSkirmishResearchRules,
        shipRules: [ShipKind: ShipRule] = RuleSet.fastSkirmishShipRules,
        defenseRules: [DefenseKind: DefenseRule] = RuleSet.fastSkirmishDefenseRules,
        missileRules: [MissileKind: MissileRule] = RuleSet.fastSkirmishMissileRules
    ) {
        self.id = id
        self.displayName = displayName
        self.baseTickInterval = baseTickInterval
        self.offlineChunkInterval = offlineChunkInterval
        self.buildingRules = buildingRules
        self.researchRules = researchRules
        self.shipRules = shipRules
        self.defenseRules = defenseRules
        self.missileRules = missileRules
    }

    public static let fastSkirmish = RuleSet(
        id: "fast-skirmish-v1",
        displayName: "Fast Skirmish",
        baseTickInterval: 1,
        offlineChunkInterval: 300
    )

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case baseTickInterval
        case offlineChunkInterval
        case buildingRules
        case researchRules
        case shipRules
        case defenseRules
        case missileRules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.baseTickInterval = try container.decode(TimeInterval.self, forKey: .baseTickInterval)
        self.offlineChunkInterval = try container.decode(TimeInterval.self, forKey: .offlineChunkInterval)
        let decodedBuildingRules = try container.decodeRawValueDictionaryIfPresent(BuildingKind.self, forKey: .buildingRules)
            ?? RuleSet.fastSkirmish.buildingRules
        self.buildingRules = RuleSet.migrateBuildingRulesForRequirements(decodedBuildingRules, ruleSetID: id)
        let decodedResearchRules = try container.decodeRawValueDictionaryIfPresent(TechnologyKind.self, forKey: .researchRules)
            ?? RuleSet.fastSkirmish.researchRules
        self.researchRules = RuleSet.migrateResearchRulesForRequirements(decodedResearchRules, ruleSetID: id)
        let decodedShipRules = try container.decodeRawValueDictionaryIfPresent(ShipKind.self, forKey: .shipRules)
            ?? RuleSet.fastSkirmish.shipRules
        self.shipRules = RuleSet.migrateShipRulesForRequirements(
            RuleSet.migrateShipRulesForFleetFields(decodedShipRules),
            ruleSetID: id
        )
        let decodedDefenseRules = try container.decodeRawValueDictionaryIfPresent(DefenseKind.self, forKey: .defenseRules)
            ?? RuleSet.fastSkirmish.defenseRules
        self.defenseRules = RuleSet.migrateDefenseRulesForRequirements(
            RuleSet.migrateDefenseRulesForCombatFields(decodedDefenseRules),
            ruleSetID: id
        )
        let decodedMissileRules = try container.decodeRawValueDictionaryIfPresent(MissileKind.self, forKey: .missileRules)
            ?? RuleSet.fastSkirmish.missileRules
        self.missileRules = RuleSet.migrateMissileRulesForRequirements(decodedMissileRules, ruleSetID: id)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(baseTickInterval, forKey: .baseTickInterval)
        try container.encode(offlineChunkInterval, forKey: .offlineChunkInterval)
        try container.encodeRawValueDictionary(buildingRules, forKey: .buildingRules)
        try container.encodeRawValueDictionary(researchRules, forKey: .researchRules)
        try container.encodeRawValueDictionary(shipRules, forKey: .shipRules)
        try container.encodeRawValueDictionary(defenseRules, forKey: .defenseRules)
        try container.encodeRawValueDictionary(missileRules, forKey: .missileRules)
    }
}

public enum RuleRequirement: Codable, Equatable, Sendable {
    private enum RequirementType: String, Codable {
        case building
        case technology
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case buildingKind
        case technologyKind
        case level
    }

    case building(BuildingKind, level: Int)
    case technology(TechnologyKind, level: Int)

    public var lockedReason: String {
        switch self {
        case let .building(kind, level):
            return "需要\(kind.localizedName)等级 \(Self.normalizedLevel(level))"
        case let .technology(kind, level):
            return "需要\(kind.localizedName)等级 \(Self.normalizedLevel(level))"
        }
    }

    public var requiredLevel: Int {
        switch self {
        case let .building(_, level), let .technology(_, level):
            return Self.normalizedLevel(level)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RequirementType.self, forKey: .type)
        let level = Self.normalizedLevel(try container.decodeIfPresent(Int.self, forKey: .level) ?? 1)

        switch type {
        case .building:
            self = .building(try container.decode(BuildingKind.self, forKey: .buildingKind), level: level)
        case .technology:
            self = .technology(try container.decode(TechnologyKind.self, forKey: .technologyKind), level: level)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .building(kind, level):
            try container.encode(RequirementType.building, forKey: .type)
            try container.encode(kind, forKey: .buildingKind)
            try container.encode(Self.normalizedLevel(level), forKey: .level)
        case let .technology(kind, level):
            try container.encode(RequirementType.technology, forKey: .type)
            try container.encode(kind, forKey: .technologyKind)
            try container.encode(Self.normalizedLevel(level), forKey: .level)
        }
    }

    private static func normalizedLevel(_ level: Int) -> Int {
        max(level, 1)
    }
}

public enum BuildingKind: String, Codable, CaseIterable, Sendable {
    case metalMine
    case crystalMine
    case deuteriumSynthesizer
    case solarPlant
    case roboticsFactory
    case shipyard
    case researchLab
    case metalStorage
    case crystalStorage
    case deuteriumTank
    case naniteFactory
    case missileSilo
    case lunarBase
    case sensorPhalanx
    case jumpGate
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
    case bomber
    case solarSatellite
    case destroyer
    case deathstar
    case battlecruiser
}

public enum DefenseKind: String, Codable, CaseIterable, Sendable {
    case rocketLauncher
    case lightLaser
    case heavyLaser
    case gaussCannon
    case ionCannon
    case plasmaTurret
}

public enum MissileKind: String, Codable, CaseIterable, Sendable {
    case antiBallisticMissile
    case interplanetaryMissile
}

public extension GameSettings.OfflineIntensity {
    var localizedName: String {
        switch self {
        case .paused:
            return "暂停"
        case .reduced:
            return "低强度"
        case .normal:
            return "标准"
        case .intense:
            return "高强度"
        }
    }
}

public extension GameSettings.Difficulty {
    var localizedName: String {
        switch self {
        case .easy:
            return "简单"
        case .standard:
            return "标准"
        case .hard:
            return "困难"
        }
    }
}

public extension VictoryRoute {
    var localizedName: String {
        switch self {
        case .economy:
            return "经济"
        case .technology:
            return "科技"
        case .domination:
            return "统治"
        case .exploration:
            return "探索"
        }
    }
}

public extension RelationPosture {
    var localizedName: String {
        switch self {
        case .neutral:
            return "中立"
        case .wary:
            return "警惕"
        case .hostile:
            return "敌对"
        case .pressured:
            return "受压"
        }
    }
}

public extension Faction.Kind {
    var localizedName: String {
        switch self {
        case .player:
            return "玩家"
        case .ai:
            return "AI"
        }
    }
}

public extension Faction.Strategy {
    var localizedName: String {
        switch self {
        case .miner:
            return "矿工"
        case .raider:
            return "掠袭者"
        case .technologist:
            return "科研派"
        case .expansionist:
            return "扩张者"
        case .balanced:
            return "均衡"
        }
    }
}

public extension Fleet.Mission {
    var localizedName: String {
        switch self {
        case .transport:
            return "运输"
        case .colonize:
            return "殖民"
        case .espionage:
            return "侦察"
        case .attack:
            return "攻击"
        case .recycle:
            return "回收"
        case .explore:
            return "探索"
        case .returning:
            return "返航"
        }
    }
}

public extension Fleet.Phase {
    var localizedName: String {
        switch self {
        case .outbound:
            return "出航"
        case .holding:
            return "驻留"
        case .returning:
            return "返航"
        case .completed:
            return "完成"
        }
    }
}

public extension BuildingKind {
    var localizedName: String {
        switch self {
        case .metalMine:
            return "金属矿"
        case .crystalMine:
            return "晶体矿"
        case .deuteriumSynthesizer:
            return "重氢合成厂"
        case .solarPlant:
            return "太阳能发电站"
        case .roboticsFactory:
            return "机器人工厂"
        case .shipyard:
            return "造船厂"
        case .researchLab:
            return "研究实验室"
        case .metalStorage:
            return "金属仓库"
        case .crystalStorage:
            return "晶体仓库"
        case .deuteriumTank:
            return "重氢储罐"
        case .naniteFactory:
            return "纳米工厂"
        case .missileSilo:
            return "导弹发射井"
        case .lunarBase:
            return "月球基地"
        case .sensorPhalanx:
            return "感应阵"
        case .jumpGate:
            return "跳跃门"
        }
    }

    var effectDescription: String {
        switch self {
        case .metalMine:
            return "提升金属产量，是早期建筑、舰船和防御扩张的基础资源来源。"
        case .crystalMine:
            return "提升晶体产量，支撑研究、电子设备和中后期舰船制造。"
        case .deuteriumSynthesizer:
            return "生产重氢，用于舰队燃料、高级研究和部分重型舰船。"
        case .solarPlant:
            return "提供能源，能源不足时矿场产出会下降，前期需要持续配套升级。"
        case .roboticsFactory:
            return "缩短建筑建造时间，并帮助更快解锁造船厂和生产节奏。"
        case .shipyard:
            return "解锁并建造舰船、防御和导弹，是侦察、运输、殖民与战斗的入口。"
        case .researchLab:
            return "开启科技研究，提高解锁速度，是舰队、导弹和后期设施的核心前置。"
        case .metalStorage:
            return "提高金属容量，避免离线或高产量时金属达到上限而停止增长。"
        case .crystalStorage:
            return "提高晶体容量，保障研究和高级舰船制造所需的晶体储备。"
        case .deuteriumTank:
            return "提高重氢容量，适合准备远航、殖民、攻击和高阶科技时升级。"
        case .naniteFactory:
            return "大幅加速建筑和造船效率，是中后期爆发生产与快速补舰的关键设施。"
        case .missileSilo:
            return "解锁拦截导弹和星际导弹，用于防御来袭导弹或削弱敌方防御。"
        case .lunarBase:
            return "扩展月球设施空间，是感应阵和跳跃门等月球系统的基础。"
        case .sensorPhalanx:
            return "侦测目标星球附近舰队动向，帮助判断敌军抵达和返航窗口。"
        case .jumpGate:
            return "连接月球之间的舰队调动，后期可快速转移主力舰队。"
        }
    }
}

public extension BuildingKind {
    var isMoonFacility: Bool {
        switch self {
        case .lunarBase, .sensorPhalanx, .jumpGate:
            return true
        case .metalMine, .crystalMine, .deuteriumSynthesizer, .solarPlant, .roboticsFactory, .shipyard,
             .researchLab, .metalStorage, .crystalStorage, .deuteriumTank, .naniteFactory, .missileSilo:
            return false
        }
    }
}

public extension TechnologyKind {
    var localizedName: String {
        switch self {
        case .espionage:
            return "间谍技术"
        case .computer:
            return "计算机技术"
        case .weapons:
            return "武器技术"
        case .shielding:
            return "防御盾技术"
        case .armor:
            return "装甲技术"
        case .energy:
            return "能量技术"
        case .combustionDrive:
            return "燃烧引擎"
        case .impulseDrive:
            return "脉冲引擎"
        case .hyperspaceDrive:
            return "超空间引擎"
        }
    }

    var effectDescription: String {
        switch self {
        case .espionage:
            return "提升侦察能力，解锁探测器并让你更清楚目标资源、舰队和防御。"
        case .computer:
            return "提升指挥与计算能力，是纳米工厂和高效舰队调度的重要前置。"
        case .weapons:
            return "提高舰船和防御的攻击表现，让突袭与正面战斗更有破坏力。"
        case .shielding:
            return "强化护盾承受能力，提高舰队和防御在交火中的生存时间。"
        case .armor:
            return "提升装甲结构，降低战损风险，适合长期冲突和防守路线。"
        case .energy:
            return "支撑高级设施、太阳能卫星和超空间科技，是后期科技树的能源基础。"
        case .combustionDrive:
            return "提升基础舰船航速，影响运输舰、回收船等早期舰队的行动效率。"
        case .impulseDrive:
            return "提升中型舰队航速，并解锁殖民船、巡洋舰等扩张与作战单位。"
        case .hyperspaceDrive:
            return "提升高级舰队航速，解锁战列舰、毁灭者、死星和月球后期设施。"
        }
    }
}

public extension ShipKind {
    var localizedName: String {
        switch self {
        case .smallCargo:
            return "小型运输舰"
        case .largeCargo:
            return "大型运输舰"
        case .lightFighter:
            return "轻型战斗机"
        case .heavyFighter:
            return "重型战斗机"
        case .cruiser:
            return "巡洋舰"
        case .battleship:
            return "战列舰"
        case .colonyShip:
            return "殖民船"
        case .recycler:
            return "回收船"
        case .espionageProbe:
            return "间谍探测器"
        case .bomber:
            return "轰炸机"
        case .solarSatellite:
            return "太阳能卫星"
        case .destroyer:
            return "毁灭者"
        case .deathstar:
            return "死星"
        case .battlecruiser:
            return "战斗巡洋舰"
        }
    }
}

public extension DefenseKind {
    var localizedName: String {
        switch self {
        case .rocketLauncher:
            return "火箭发射器"
        case .lightLaser:
            return "轻型激光炮"
        case .heavyLaser:
            return "重型激光炮"
        case .gaussCannon:
            return "高斯炮"
        case .ionCannon:
            return "离子炮"
        case .plasmaTurret:
            return "等离子炮塔"
        }
    }
}

public extension MissileKind {
    var localizedName: String {
        switch self {
        case .antiBallisticMissile:
            return "拦截导弹"
        case .interplanetaryMissile:
            return "星际导弹"
        }
    }
}

private struct RawValueCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        return nil
    }
}

private extension KeyedDecodingContainer {
    func decodeRawValueDictionary<EnumKey, Value>(
        _ enumKeyType: EnumKey.Type,
        forKey key: Key
    ) throws -> [EnumKey: Value] where EnumKey: Hashable & RawRepresentable, EnumKey.RawValue == String, Value: Decodable {
        let nestedContainer = try nestedContainer(keyedBy: RawValueCodingKey.self, forKey: key)
        var decoded: [EnumKey: Value] = [:]

        for rawKey in nestedContainer.allKeys {
            guard let enumKey = EnumKey(rawValue: rawKey.stringValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: rawKey,
                    in: nestedContainer,
                    debugDescription: "Unknown \(EnumKey.self) key '\(rawKey.stringValue)'"
                )
            }

            decoded[enumKey] = try nestedContainer.decode(Value.self, forKey: rawKey)
        }

        return decoded
    }

    func decodeRawValueDictionaryIfPresent<EnumKey, Value>(
        _ enumKeyType: EnumKey.Type,
        forKey key: Key
    ) throws -> [EnumKey: Value]? where EnumKey: Hashable & RawRepresentable, EnumKey.RawValue == String, Value: Decodable {
        guard contains(key), try !decodeNil(forKey: key) else {
            return nil
        }

        return try decodeRawValueDictionary(enumKeyType, forKey: key)
    }

    func decodeIfPresentStrict<Value>(
        _ type: Value.Type,
        forKey key: Key
    ) throws -> Value? where Value: Decodable {
        guard contains(key) else {
            return nil
        }

        return try decode(type, forKey: key)
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeRawValueDictionary<EnumKey, Value>(
        _ dictionary: [EnumKey: Value],
        forKey key: Key
    ) throws where EnumKey: Hashable & RawRepresentable, EnumKey.RawValue == String, Value: Encodable {
        var nestedContainer = nestedContainer(keyedBy: RawValueCodingKey.self, forKey: key)

        for enumKey in dictionary.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            if let value = dictionary[enumKey] {
                try nestedContainer.encode(value, forKey: RawValueCodingKey(enumKey.rawValue))
            }
        }
    }
}
