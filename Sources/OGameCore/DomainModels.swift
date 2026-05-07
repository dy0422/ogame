import Foundation

public struct Universe: Codable, Equatable, Sendable, Identifiable {
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

public struct Planet: Codable, Equatable, Sendable, Identifiable {
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

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case coordinate
        case ownerID
        case resources
        case storage
        case energy
        case buildingLevels
        case shipInventory
        case defenseInventory
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
        self.shipInventory = try container.decodeRawValueDictionary(ShipKind.self, forKey: .shipInventory)
        self.defenseInventory = try container.decodeRawValueDictionary(DefenseKind.self, forKey: .defenseInventory)
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
        try container.encodeRawValueDictionary(shipInventory, forKey: .shipInventory)
        try container.encodeRawValueDictionary(defenseInventory, forKey: .defenseInventory)
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
    func decodeRawValueDictionary<EnumKey>(
        _ enumKeyType: EnumKey.Type,
        forKey key: Key
    ) throws -> [EnumKey: Int] where EnumKey: Hashable & RawRepresentable, EnumKey.RawValue == String {
        let nestedContainer = try nestedContainer(keyedBy: RawValueCodingKey.self, forKey: key)
        var decoded: [EnumKey: Int] = [:]

        for rawKey in nestedContainer.allKeys {
            guard let enumKey = EnumKey(rawValue: rawKey.stringValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: rawKey,
                    in: nestedContainer,
                    debugDescription: "Unknown \(EnumKey.self) key '\(rawKey.stringValue)'"
                )
            }

            decoded[enumKey] = try nestedContainer.decode(Int.self, forKey: rawKey)
        }

        return decoded
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeRawValueDictionary<EnumKey>(
        _ dictionary: [EnumKey: Int],
        forKey key: Key
    ) throws where EnumKey: Hashable & RawRepresentable, EnumKey.RawValue == String {
        var nestedContainer = nestedContainer(keyedBy: RawValueCodingKey.self, forKey: key)

        for enumKey in dictionary.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            if let value = dictionary[enumKey] {
                try nestedContainer.encode(value, forKey: RawValueCodingKey(enumKey.rawValue))
            }
        }
    }
}
