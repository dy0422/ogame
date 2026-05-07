import Foundation

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
        ruleSet: RuleSet
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
        }
        try container.encode(quantity, forKey: .quantity)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(finishTime, forKey: .finishTime)
        try container.encode(paidCost, forKey: .paidCost)
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

    public init(
        id: FactionID = FactionID(),
        name: String,
        kind: Kind,
        strategy: Strategy,
        technology: ResearchState = ResearchState(),
        ownedPlanetIDs: [PlanetID] = [],
        researchQueue: [ResearchQueueItem] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.strategy = strategy
        self.technology = technology
        self.ownedPlanetIDs = ownedPlanetIDs
        self.researchQueue = researchQueue
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case strategy
        case technology
        case ownedPlanetIDs
        case researchQueue
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

public struct Planet: Codable, Equatable, Sendable, Identifiable {
    public var id: PlanetID
    public var name: String
    public var coordinate: Coordinate
    public var ownerID: FactionID?
    public var resources: ResourceBundle
    public var storage: ResourceStorage
    public var energy: EnergyState
    public var buildingLevels: [BuildingKind: Int]
    public var buildQueue: [BuildQueueItem]
    public var shipBuildQueue: [UnitBuildQueueItem]
    public var defenseBuildQueue: [UnitBuildQueueItem]
    public var shipInventory: [ShipKind: Int]
    public var defenseInventory: [DefenseKind: Int]
    public var debrisField: ResourceBundle

    public init(
        id: PlanetID = PlanetID(),
        name: String,
        coordinate: Coordinate,
        ownerID: FactionID?,
        resources: ResourceBundle = .zero,
        storage: ResourceStorage = ResourceStorage(metal: 10_000, crystal: 10_000, deuterium: 10_000),
        energy: EnergyState = EnergyState(),
        buildingLevels: [BuildingKind: Int] = [:],
        buildQueue: [BuildQueueItem] = [],
        shipBuildQueue: [UnitBuildQueueItem] = [],
        defenseBuildQueue: [UnitBuildQueueItem] = [],
        shipInventory: [ShipKind: Int] = [:],
        defenseInventory: [DefenseKind: Int] = [:],
        debrisField: ResourceBundle = .zero
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.ownerID = ownerID
        self.resources = resources
        self.storage = storage
        self.energy = energy
        self.buildingLevels = buildingLevels
        self.buildQueue = buildQueue
        self.shipBuildQueue = shipBuildQueue
        self.defenseBuildQueue = defenseBuildQueue
        self.shipInventory = shipInventory
        self.defenseInventory = defenseInventory
        self.debrisField = debrisField
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
        case buildQueue
        case shipBuildQueue
        case defenseBuildQueue
        case shipInventory
        case defenseInventory
        case debrisField
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
        self.buildQueue = try container.decodeIfPresentStrict([BuildQueueItem].self, forKey: .buildQueue) ?? []
        self.shipBuildQueue = try container.decodeIfPresentStrict([UnitBuildQueueItem].self, forKey: .shipBuildQueue) ?? []
        self.defenseBuildQueue = try container.decodeIfPresentStrict([UnitBuildQueueItem].self, forKey: .defenseBuildQueue) ?? []
        self.shipInventory = try container.decodeRawValueDictionary(ShipKind.self, forKey: .shipInventory)
        self.defenseInventory = try container.decodeRawValueDictionary(DefenseKind.self, forKey: .defenseInventory)
        self.debrisField = try container.decodeIfPresentStrict(ResourceBundle.self, forKey: .debrisField) ?? .zero
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
        try container.encode(buildQueue, forKey: .buildQueue)
        try container.encode(shipBuildQueue, forKey: .shipBuildQueue)
        try container.encode(defenseBuildQueue, forKey: .defenseBuildQueue)
        try container.encodeRawValueDictionary(shipInventory, forKey: .shipInventory)
        try container.encodeRawValueDictionary(defenseInventory, forKey: .defenseInventory)
        try container.encode(debrisField, forKey: .debrisField)
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

    public init(
        id: String,
        displayName: String,
        baseTickInterval: TimeInterval,
        offlineChunkInterval: TimeInterval,
        buildingRules: [BuildingKind: BuildingRule] = RuleSet.fastSkirmishBuildingRules,
        researchRules: [TechnologyKind: ResearchRule] = RuleSet.fastSkirmishResearchRules,
        shipRules: [ShipKind: ShipRule] = RuleSet.fastSkirmishShipRules,
        defenseRules: [DefenseKind: DefenseRule] = RuleSet.fastSkirmishDefenseRules
    ) {
        self.id = id
        self.displayName = displayName
        self.baseTickInterval = baseTickInterval
        self.offlineChunkInterval = offlineChunkInterval
        self.buildingRules = buildingRules
        self.researchRules = researchRules
        self.shipRules = shipRules
        self.defenseRules = defenseRules
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
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.baseTickInterval = try container.decode(TimeInterval.self, forKey: .baseTickInterval)
        self.offlineChunkInterval = try container.decode(TimeInterval.self, forKey: .offlineChunkInterval)
        self.buildingRules = try container.decodeRawValueDictionaryIfPresent(BuildingKind.self, forKey: .buildingRules)
            ?? RuleSet.fastSkirmish.buildingRules
        self.researchRules = try container.decodeRawValueDictionaryIfPresent(TechnologyKind.self, forKey: .researchRules)
            ?? RuleSet.fastSkirmish.researchRules
        let decodedShipRules = try container.decodeRawValueDictionaryIfPresent(ShipKind.self, forKey: .shipRules)
            ?? RuleSet.fastSkirmish.shipRules
        self.shipRules = RuleSet.migrateShipRulesForFleetFields(decodedShipRules)
        let decodedDefenseRules = try container.decodeRawValueDictionaryIfPresent(DefenseKind.self, forKey: .defenseRules)
            ?? RuleSet.fastSkirmish.defenseRules
        self.defenseRules = RuleSet.migrateDefenseRulesForCombatFields(decodedDefenseRules)
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
