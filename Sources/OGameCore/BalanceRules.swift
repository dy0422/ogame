import Foundation

public struct BuildingRule: Codable, Equatable, Sendable {
    public var baseCost: ResourceBundle
    public var costMultiplier: Double
    public var baseDuration: TimeInterval
    public var durationMultiplier: Double
    public var productionPerHour: ResourceBundle
    public var energyProduced: Double
    public var energyUsed: Double
    public var storageBonus: ResourceStorage
    public var aiPriorityWeight: Double

    public init(
        baseCost: ResourceBundle,
        costMultiplier: Double,
        baseDuration: TimeInterval,
        durationMultiplier: Double,
        productionPerHour: ResourceBundle = .zero,
        energyProduced: Double = 0,
        energyUsed: Double = 0,
        storageBonus: ResourceStorage = ResourceStorage(),
        aiPriorityWeight: Double
    ) {
        self.baseCost = baseCost
        self.costMultiplier = costMultiplier
        self.baseDuration = baseDuration
        self.durationMultiplier = durationMultiplier
        self.productionPerHour = productionPerHour
        self.energyProduced = energyProduced
        self.energyUsed = energyUsed
        self.storageBonus = storageBonus
        self.aiPriorityWeight = aiPriorityWeight
    }
}

public struct ResearchRule: Codable, Equatable, Sendable {
    public var baseCost: ResourceBundle
    public var costMultiplier: Double
    public var baseDuration: TimeInterval
    public var durationMultiplier: Double
    public var aiPriorityWeight: Double

    public init(
        baseCost: ResourceBundle,
        costMultiplier: Double,
        baseDuration: TimeInterval,
        durationMultiplier: Double,
        aiPriorityWeight: Double
    ) {
        self.baseCost = baseCost
        self.costMultiplier = costMultiplier
        self.baseDuration = baseDuration
        self.durationMultiplier = durationMultiplier
        self.aiPriorityWeight = aiPriorityWeight
    }
}

public struct ShipRule: Codable, Equatable, Sendable {
    public var baseCost: ResourceBundle
    public var baseDuration: TimeInterval
    public var aiPriorityWeight: Double
    public var speed: Double
    public var cargoCapacity: Double
    public var fuelCost: Double
    public var attack: Double
    public var shield: Double
    public var hull: Double
    var decodedFleetFieldMask: UInt8

    public init(
        baseCost: ResourceBundle,
        baseDuration: TimeInterval,
        aiPriorityWeight: Double,
        speed: Double = 1,
        cargoCapacity: Double = 0,
        fuelCost: Double = 0,
        attack: Double = 0,
        shield: Double = 0,
        hull: Double = 0
    ) {
        self.baseCost = baseCost
        self.baseDuration = baseDuration
        self.aiPriorityWeight = aiPriorityWeight
        self.speed = speed
        self.cargoCapacity = cargoCapacity
        self.fuelCost = fuelCost
        self.attack = attack
        self.shield = shield
        self.hull = hull
        self.decodedFleetFieldMask = Self.allFleetFieldMask
    }

    private enum CodingKeys: String, CodingKey {
        case baseCost
        case baseDuration
        case aiPriorityWeight
        case speed
        case cargoCapacity
        case fuelCost
        case attack
        case shield
        case hull
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.baseCost = try container.decode(ResourceBundle.self, forKey: .baseCost)
        self.baseDuration = try container.decode(TimeInterval.self, forKey: .baseDuration)
        self.aiPriorityWeight = try container.decode(Double.self, forKey: .aiPriorityWeight)
        self.speed = try container.decodeIfPresent(Double.self, forKey: .speed) ?? 1
        self.cargoCapacity = try container.decodeIfPresent(Double.self, forKey: .cargoCapacity) ?? 0
        self.fuelCost = try container.decodeIfPresent(Double.self, forKey: .fuelCost) ?? 0
        self.attack = try container.decodeIfPresent(Double.self, forKey: .attack) ?? 0
        self.shield = try container.decodeIfPresent(Double.self, forKey: .shield) ?? 0
        self.hull = try container.decodeIfPresent(Double.self, forKey: .hull) ?? 0

        var fleetFieldMask: UInt8 = 0
        if container.contains(.speed) {
            fleetFieldMask |= Self.speedFleetField
        }
        if container.contains(.cargoCapacity) {
            fleetFieldMask |= Self.cargoCapacityFleetField
        }
        if container.contains(.fuelCost) {
            fleetFieldMask |= Self.fuelCostFleetField
        }
        if container.contains(.attack) {
            fleetFieldMask |= Self.attackFleetField
        }
        if container.contains(.shield) {
            fleetFieldMask |= Self.shieldFleetField
        }
        if container.contains(.hull) {
            fleetFieldMask |= Self.hullFleetField
        }
        self.decodedFleetFieldMask = fleetFieldMask
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(baseCost, forKey: .baseCost)
        try container.encode(baseDuration, forKey: .baseDuration)
        try container.encode(aiPriorityWeight, forKey: .aiPriorityWeight)
        try container.encode(speed, forKey: .speed)
        try container.encode(cargoCapacity, forKey: .cargoCapacity)
        try container.encode(fuelCost, forKey: .fuelCost)
        try container.encode(attack, forKey: .attack)
        try container.encode(shield, forKey: .shield)
        try container.encode(hull, forKey: .hull)
    }

    public static func == (lhs: ShipRule, rhs: ShipRule) -> Bool {
        lhs.baseCost == rhs.baseCost &&
            lhs.baseDuration == rhs.baseDuration &&
            lhs.aiPriorityWeight == rhs.aiPriorityWeight &&
            lhs.speed == rhs.speed &&
            lhs.cargoCapacity == rhs.cargoCapacity &&
            lhs.fuelCost == rhs.fuelCost &&
            lhs.attack == rhs.attack &&
            lhs.shield == rhs.shield &&
            lhs.hull == rhs.hull
    }

    func mergingMissingFleetFields(from defaultRule: ShipRule) -> ShipRule {
        var rule = self

        if decodedFleetFieldMask & Self.speedFleetField == 0 {
            rule.speed = defaultRule.speed
        }
        if decodedFleetFieldMask & Self.cargoCapacityFleetField == 0 {
            rule.cargoCapacity = defaultRule.cargoCapacity
        }
        if decodedFleetFieldMask & Self.fuelCostFleetField == 0 {
            rule.fuelCost = defaultRule.fuelCost
        }
        if decodedFleetFieldMask & Self.attackFleetField == 0 {
            rule.attack = defaultRule.attack
        }
        if decodedFleetFieldMask & Self.shieldFleetField == 0 {
            rule.shield = defaultRule.shield
        }
        if decodedFleetFieldMask & Self.hullFleetField == 0 {
            rule.hull = defaultRule.hull
        }

        rule.decodedFleetFieldMask = Self.allFleetFieldMask
        return rule
    }

    private static let speedFleetField: UInt8 = 1 << 0
    private static let cargoCapacityFleetField: UInt8 = 1 << 1
    private static let fuelCostFleetField: UInt8 = 1 << 2
    private static let attackFleetField: UInt8 = 1 << 3
    private static let shieldFleetField: UInt8 = 1 << 4
    private static let hullFleetField: UInt8 = 1 << 5
    private static let allFleetFieldMask: UInt8 =
        speedFleetField |
        cargoCapacityFleetField |
        fuelCostFleetField |
        attackFleetField |
        shieldFleetField |
        hullFleetField
}

public struct DefenseRule: Codable, Equatable, Sendable {
    public var baseCost: ResourceBundle
    public var baseDuration: TimeInterval
    public var aiPriorityWeight: Double

    public init(
        baseCost: ResourceBundle,
        baseDuration: TimeInterval,
        aiPriorityWeight: Double
    ) {
        self.baseCost = baseCost
        self.baseDuration = baseDuration
        self.aiPriorityWeight = aiPriorityWeight
    }
}

extension RuleSet {
    static func migrateShipRulesForFleetFields(_ shipRules: [ShipKind: ShipRule]) -> [ShipKind: ShipRule] {
        var migratedRules = shipRules

        for (shipKind, defaultRule) in RuleSet.fastSkirmishShipRules {
            if let decodedRule = migratedRules[shipKind] {
                migratedRules[shipKind] = decodedRule.mergingMissingFleetFields(from: defaultRule)
            } else {
                migratedRules[shipKind] = defaultRule
            }
        }

        return migratedRules
    }
}

public extension RuleSet {
    static var fastSkirmishBuildingRules: [BuildingKind: BuildingRule] {
        [
            .metalMine: BuildingRule(
                baseCost: ResourceBundle(metal: 60, crystal: 15),
                costMultiplier: 1.50,
                baseDuration: 20,
                durationMultiplier: 1.30,
                productionPerHour: ResourceBundle(metal: 180),
                energyUsed: 10,
                aiPriorityWeight: 1.00
            ),
            .crystalMine: BuildingRule(
                baseCost: ResourceBundle(metal: 48, crystal: 24),
                costMultiplier: 1.60,
                baseDuration: 24,
                durationMultiplier: 1.35,
                productionPerHour: ResourceBundle(crystal: 120),
                energyUsed: 10,
                aiPriorityWeight: 0.95
            ),
            .deuteriumSynthesizer: BuildingRule(
                baseCost: ResourceBundle(metal: 225, crystal: 75),
                costMultiplier: 1.50,
                baseDuration: 32,
                durationMultiplier: 1.35,
                productionPerHour: ResourceBundle(deuterium: 72),
                energyUsed: 16,
                aiPriorityWeight: 0.75
            ),
            .solarPlant: BuildingRule(
                baseCost: ResourceBundle(metal: 75, crystal: 30),
                costMultiplier: 1.50,
                baseDuration: 18,
                durationMultiplier: 1.25,
                energyProduced: 32,
                aiPriorityWeight: 0.85
            ),
            .roboticsFactory: BuildingRule(
                baseCost: ResourceBundle(metal: 400, crystal: 120, deuterium: 80),
                costMultiplier: 1.70,
                baseDuration: 60,
                durationMultiplier: 1.40,
                aiPriorityWeight: 0.55
            ),
            .shipyard: BuildingRule(
                baseCost: ResourceBundle(metal: 400, crystal: 200, deuterium: 100),
                costMultiplier: 1.70,
                baseDuration: 75,
                durationMultiplier: 1.40,
                aiPriorityWeight: 0.45
            ),
            .researchLab: BuildingRule(
                baseCost: ResourceBundle(metal: 200, crystal: 400, deuterium: 200),
                costMultiplier: 1.70,
                baseDuration: 70,
                durationMultiplier: 1.40,
                aiPriorityWeight: 0.60
            )
        ]
    }

    static var fastSkirmishResearchRules: [TechnologyKind: ResearchRule] {
        [
            .espionage: ResearchRule(
                baseCost: ResourceBundle(metal: 200, crystal: 1_000, deuterium: 200),
                costMultiplier: 2.00,
                baseDuration: 45,
                durationMultiplier: 1.50,
                aiPriorityWeight: 0.45
            ),
            .computer: ResearchRule(
                baseCost: ResourceBundle(crystal: 400, deuterium: 600),
                costMultiplier: 2.00,
                baseDuration: 50,
                durationMultiplier: 1.50,
                aiPriorityWeight: 0.65
            ),
            .weapons: ResearchRule(
                baseCost: ResourceBundle(metal: 800, crystal: 200),
                costMultiplier: 2.00,
                baseDuration: 60,
                durationMultiplier: 1.55,
                aiPriorityWeight: 0.40
            ),
            .shielding: ResearchRule(
                baseCost: ResourceBundle(metal: 200, crystal: 600),
                costMultiplier: 2.00,
                baseDuration: 60,
                durationMultiplier: 1.55,
                aiPriorityWeight: 0.35
            ),
            .armor: ResearchRule(
                baseCost: ResourceBundle(metal: 1_000),
                costMultiplier: 2.00,
                baseDuration: 55,
                durationMultiplier: 1.55,
                aiPriorityWeight: 0.35
            ),
            .energy: ResearchRule(
                baseCost: ResourceBundle(crystal: 800, deuterium: 400),
                costMultiplier: 2.00,
                baseDuration: 50,
                durationMultiplier: 1.50,
                aiPriorityWeight: 0.55
            ),
            .combustionDrive: ResearchRule(
                baseCost: ResourceBundle(metal: 400, deuterium: 600),
                costMultiplier: 2.00,
                baseDuration: 65,
                durationMultiplier: 1.55,
                aiPriorityWeight: 0.25
            ),
            .impulseDrive: ResearchRule(
                baseCost: ResourceBundle(metal: 2_000, crystal: 4_000, deuterium: 600),
                costMultiplier: 2.00,
                baseDuration: 90,
                durationMultiplier: 1.60,
                aiPriorityWeight: 0.20
            ),
            .hyperspaceDrive: ResearchRule(
                baseCost: ResourceBundle(metal: 10_000, crystal: 20_000, deuterium: 6_000),
                costMultiplier: 2.00,
                baseDuration: 120,
                durationMultiplier: 1.65,
                aiPriorityWeight: 0.10
            )
        ]
    }

    static var fastSkirmishShipRules: [ShipKind: ShipRule] {
        [
            .smallCargo: ShipRule(
                baseCost: ResourceBundle(metal: 2_000, crystal: 2_000),
                baseDuration: 10,
                aiPriorityWeight: 0.40,
                speed: 5_000,
                cargoCapacity: 5_000,
                fuelCost: 10,
                attack: 5,
                shield: 10,
                hull: 4_000
            ),
            .largeCargo: ShipRule(
                baseCost: ResourceBundle(metal: 6_000, crystal: 6_000),
                baseDuration: 18,
                aiPriorityWeight: 0.35,
                speed: 3_000,
                cargoCapacity: 25_000,
                fuelCost: 50,
                attack: 5,
                shield: 25,
                hull: 12_000
            ),
            .lightFighter: ShipRule(
                baseCost: ResourceBundle(metal: 3_000, crystal: 1_000),
                baseDuration: 20,
                aiPriorityWeight: 0.65,
                speed: 12_500,
                cargoCapacity: 50,
                fuelCost: 20,
                attack: 50,
                shield: 10,
                hull: 4_000
            ),
            .heavyFighter: ShipRule(
                baseCost: ResourceBundle(metal: 6_000, crystal: 4_000),
                baseDuration: 30,
                aiPriorityWeight: 0.55,
                speed: 10_000,
                cargoCapacity: 100,
                fuelCost: 75,
                attack: 150,
                shield: 25,
                hull: 10_000
            ),
            .cruiser: ShipRule(
                baseCost: ResourceBundle(metal: 20_000, crystal: 7_000, deuterium: 2_000),
                baseDuration: 45,
                aiPriorityWeight: 0.45,
                speed: 15_000,
                cargoCapacity: 800,
                fuelCost: 300,
                attack: 400,
                shield: 50,
                hull: 27_000
            ),
            .battleship: ShipRule(
                baseCost: ResourceBundle(metal: 45_000, crystal: 15_000),
                baseDuration: 65,
                aiPriorityWeight: 0.30,
                speed: 10_000,
                cargoCapacity: 1_500,
                fuelCost: 500,
                attack: 1_000,
                shield: 200,
                hull: 60_000
            ),
            .colonyShip: ShipRule(
                baseCost: ResourceBundle(metal: 10_000, crystal: 20_000, deuterium: 10_000),
                baseDuration: 75,
                aiPriorityWeight: 0.25,
                speed: 2_500,
                cargoCapacity: 7_500,
                fuelCost: 1_000,
                attack: 50,
                shield: 100,
                hull: 30_000
            ),
            .recycler: ShipRule(
                baseCost: ResourceBundle(metal: 10_000, crystal: 6_000, deuterium: 2_000),
                baseDuration: 40,
                aiPriorityWeight: 0.20,
                speed: 2_000,
                cargoCapacity: 20_000,
                fuelCost: 300,
                attack: 1,
                shield: 10,
                hull: 16_000
            ),
            .espionageProbe: ShipRule(
                baseCost: ResourceBundle(crystal: 1_000),
                baseDuration: 5,
                aiPriorityWeight: 0.50,
                speed: 100_000,
                cargoCapacity: 5,
                fuelCost: 1,
                attack: 0,
                shield: 0,
                hull: 1_000
            )
        ]
    }

    static var fastSkirmishDefenseRules: [DefenseKind: DefenseRule] {
        [
            .rocketLauncher: DefenseRule(
                baseCost: ResourceBundle(metal: 2_000),
                baseDuration: 6,
                aiPriorityWeight: 0.50
            ),
            .lightLaser: DefenseRule(
                baseCost: ResourceBundle(metal: 1_500, crystal: 500),
                baseDuration: 20,
                aiPriorityWeight: 0.45
            ),
            .heavyLaser: DefenseRule(
                baseCost: ResourceBundle(metal: 6_000, crystal: 2_000),
                baseDuration: 35,
                aiPriorityWeight: 0.35
            ),
            .gaussCannon: DefenseRule(
                baseCost: ResourceBundle(metal: 20_000, crystal: 15_000, deuterium: 2_000),
                baseDuration: 55,
                aiPriorityWeight: 0.25
            ),
            .ionCannon: DefenseRule(
                baseCost: ResourceBundle(metal: 2_000, crystal: 6_000),
                baseDuration: 40,
                aiPriorityWeight: 0.30
            ),
            .plasmaTurret: DefenseRule(
                baseCost: ResourceBundle(metal: 50_000, crystal: 50_000, deuterium: 30_000),
                baseDuration: 90,
                aiPriorityWeight: 0.15
            )
        ]
    }
}
