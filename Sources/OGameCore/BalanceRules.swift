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
    public var constructionSpeedBonus: Double
    public var shipyardSpeedBonus: Double
    public var aiPriorityWeight: Double
    public var requirements: [RuleRequirement]

    public init(
        baseCost: ResourceBundle,
        costMultiplier: Double,
        baseDuration: TimeInterval,
        durationMultiplier: Double,
        productionPerHour: ResourceBundle = .zero,
        energyProduced: Double = 0,
        energyUsed: Double = 0,
        storageBonus: ResourceStorage = ResourceStorage(),
        constructionSpeedBonus: Double = 0,
        shipyardSpeedBonus: Double = 0,
        aiPriorityWeight: Double,
        requirements: [RuleRequirement] = []
    ) {
        self.baseCost = baseCost
        self.costMultiplier = costMultiplier
        self.baseDuration = baseDuration
        self.durationMultiplier = durationMultiplier
        self.productionPerHour = productionPerHour
        self.energyProduced = energyProduced
        self.energyUsed = energyUsed
        self.storageBonus = storageBonus
        self.constructionSpeedBonus = constructionSpeedBonus
        self.shipyardSpeedBonus = shipyardSpeedBonus
        self.aiPriorityWeight = aiPriorityWeight
        self.requirements = requirements
    }

    private enum CodingKeys: String, CodingKey {
        case baseCost
        case costMultiplier
        case baseDuration
        case durationMultiplier
        case productionPerHour
        case energyProduced
        case energyUsed
        case storageBonus
        case constructionSpeedBonus
        case shipyardSpeedBonus
        case aiPriorityWeight
        case requirements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            baseCost: try container.decode(ResourceBundle.self, forKey: .baseCost),
            costMultiplier: try container.decode(Double.self, forKey: .costMultiplier),
            baseDuration: try container.decode(TimeInterval.self, forKey: .baseDuration),
            durationMultiplier: try container.decode(Double.self, forKey: .durationMultiplier),
            productionPerHour: try container.decodeIfPresent(ResourceBundle.self, forKey: .productionPerHour) ?? .zero,
            energyProduced: try container.decodeIfPresent(Double.self, forKey: .energyProduced) ?? 0,
            energyUsed: try container.decodeIfPresent(Double.self, forKey: .energyUsed) ?? 0,
            storageBonus: try container.decodeIfPresent(ResourceStorage.self, forKey: .storageBonus) ?? ResourceStorage(),
            constructionSpeedBonus: try container.decodeIfPresent(Double.self, forKey: .constructionSpeedBonus) ?? 0,
            shipyardSpeedBonus: try container.decodeIfPresent(Double.self, forKey: .shipyardSpeedBonus) ?? 0,
            aiPriorityWeight: try container.decode(Double.self, forKey: .aiPriorityWeight),
            requirements: try container.decodeIfPresent([RuleRequirement].self, forKey: .requirements) ?? []
        )
    }
}

public struct ResearchRule: Codable, Equatable, Sendable {
    public var baseCost: ResourceBundle
    public var costMultiplier: Double
    public var baseDuration: TimeInterval
    public var durationMultiplier: Double
    public var aiPriorityWeight: Double
    public var requirements: [RuleRequirement]

    public init(
        baseCost: ResourceBundle,
        costMultiplier: Double,
        baseDuration: TimeInterval,
        durationMultiplier: Double,
        aiPriorityWeight: Double,
        requirements: [RuleRequirement] = []
    ) {
        self.baseCost = baseCost
        self.costMultiplier = costMultiplier
        self.baseDuration = baseDuration
        self.durationMultiplier = durationMultiplier
        self.aiPriorityWeight = aiPriorityWeight
        self.requirements = requirements
    }

    private enum CodingKeys: String, CodingKey {
        case baseCost
        case costMultiplier
        case baseDuration
        case durationMultiplier
        case aiPriorityWeight
        case requirements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            baseCost: try container.decode(ResourceBundle.self, forKey: .baseCost),
            costMultiplier: try container.decode(Double.self, forKey: .costMultiplier),
            baseDuration: try container.decode(TimeInterval.self, forKey: .baseDuration),
            durationMultiplier: try container.decode(Double.self, forKey: .durationMultiplier),
            aiPriorityWeight: try container.decode(Double.self, forKey: .aiPriorityWeight),
            requirements: try container.decodeIfPresent([RuleRequirement].self, forKey: .requirements) ?? []
        )
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
    public var requirements: [RuleRequirement]
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
        hull: Double = 0,
        requirements: [RuleRequirement] = []
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
        self.requirements = requirements
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
        case requirements
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
        self.requirements = try container.decodeIfPresent([RuleRequirement].self, forKey: .requirements) ?? []

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
        try container.encode(requirements, forKey: .requirements)
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
            lhs.hull == rhs.hull &&
            lhs.requirements == rhs.requirements
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
    public var attack: Double
    public var shield: Double
    public var hull: Double
    public var requirements: [RuleRequirement]
    var decodedCombatFieldMask: UInt8

    public init(
        baseCost: ResourceBundle,
        baseDuration: TimeInterval,
        aiPriorityWeight: Double,
        attack: Double = 0,
        shield: Double = 0,
        hull: Double = 0,
        requirements: [RuleRequirement] = []
    ) {
        self.baseCost = baseCost
        self.baseDuration = baseDuration
        self.aiPriorityWeight = aiPriorityWeight
        self.attack = attack
        self.shield = shield
        self.hull = hull
        self.requirements = requirements
        self.decodedCombatFieldMask = Self.allCombatFieldMask
    }

    private enum CodingKeys: String, CodingKey {
        case baseCost
        case baseDuration
        case aiPriorityWeight
        case attack
        case shield
        case hull
        case requirements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.baseCost = try container.decode(ResourceBundle.self, forKey: .baseCost)
        self.baseDuration = try container.decode(TimeInterval.self, forKey: .baseDuration)
        self.aiPriorityWeight = try container.decode(Double.self, forKey: .aiPriorityWeight)
        self.attack = try container.decodeIfPresent(Double.self, forKey: .attack) ?? 0
        self.shield = try container.decodeIfPresent(Double.self, forKey: .shield) ?? 0
        self.hull = try container.decodeIfPresent(Double.self, forKey: .hull) ?? 0
        self.requirements = try container.decodeIfPresent([RuleRequirement].self, forKey: .requirements) ?? []

        var combatFieldMask: UInt8 = 0
        if container.contains(.attack) {
            combatFieldMask |= Self.attackCombatField
        }
        if container.contains(.shield) {
            combatFieldMask |= Self.shieldCombatField
        }
        if container.contains(.hull) {
            combatFieldMask |= Self.hullCombatField
        }
        self.decodedCombatFieldMask = combatFieldMask
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(baseCost, forKey: .baseCost)
        try container.encode(baseDuration, forKey: .baseDuration)
        try container.encode(aiPriorityWeight, forKey: .aiPriorityWeight)
        try container.encode(attack, forKey: .attack)
        try container.encode(shield, forKey: .shield)
        try container.encode(hull, forKey: .hull)
        try container.encode(requirements, forKey: .requirements)
    }

    public static func == (lhs: DefenseRule, rhs: DefenseRule) -> Bool {
        lhs.baseCost == rhs.baseCost &&
            lhs.baseDuration == rhs.baseDuration &&
            lhs.aiPriorityWeight == rhs.aiPriorityWeight &&
            lhs.attack == rhs.attack &&
            lhs.shield == rhs.shield &&
            lhs.hull == rhs.hull &&
            lhs.requirements == rhs.requirements
    }

    func mergingMissingCombatFields(from defaultRule: DefenseRule) -> DefenseRule {
        var rule = self

        if decodedCombatFieldMask & Self.attackCombatField == 0 {
            rule.attack = defaultRule.attack
        }
        if decodedCombatFieldMask & Self.shieldCombatField == 0 {
            rule.shield = defaultRule.shield
        }
        if decodedCombatFieldMask & Self.hullCombatField == 0 {
            rule.hull = defaultRule.hull
        }

        rule.decodedCombatFieldMask = Self.allCombatFieldMask
        return rule
    }

    private static let attackCombatField: UInt8 = 1 << 0
    private static let shieldCombatField: UInt8 = 1 << 1
    private static let hullCombatField: UInt8 = 1 << 2
    private static let allCombatFieldMask: UInt8 =
        attackCombatField |
        shieldCombatField |
        hullCombatField
}

public struct MissileRule: Codable, Equatable, Sendable {
    public var baseCost: ResourceBundle
    public var baseDuration: TimeInterval
    public var requirements: [RuleRequirement]

    public init(
        baseCost: ResourceBundle,
        baseDuration: TimeInterval,
        requirements: [RuleRequirement] = []
    ) {
        self.baseCost = baseCost
        self.baseDuration = baseDuration
        self.requirements = requirements
    }

    private enum CodingKeys: String, CodingKey {
        case baseCost
        case baseDuration
        case requirements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            baseCost: try container.decode(ResourceBundle.self, forKey: .baseCost),
            baseDuration: try container.decode(TimeInterval.self, forKey: .baseDuration),
            requirements: try container.decodeIfPresent([RuleRequirement].self, forKey: .requirements) ?? []
        )
    }
}

extension RuleSet {
    static func migrateBuildingRulesForRequirements(
        _ buildingRules: [BuildingKind: BuildingRule],
        ruleSetID: String
    ) -> [BuildingKind: BuildingRule] {
        guard ruleSetID == RuleSet.fastSkirmish.id else {
            return buildingRules
        }

        var migratedRules = buildingRules

        for (buildingKind, defaultRule) in RuleSet.fastSkirmishBuildingRules {
            if var decodedRule = migratedRules[buildingKind] {
                if decodedRule.requirements.isEmpty, !defaultRule.requirements.isEmpty {
                    decodedRule.requirements = defaultRule.requirements
                    migratedRules[buildingKind] = decodedRule
                }
            } else {
                migratedRules[buildingKind] = defaultRule
            }
        }

        return migratedRules
    }

    static func migrateResearchRulesForRequirements(
        _ researchRules: [TechnologyKind: ResearchRule],
        ruleSetID: String
    ) -> [TechnologyKind: ResearchRule] {
        guard ruleSetID == RuleSet.fastSkirmish.id else {
            return researchRules
        }

        var migratedRules = researchRules

        for (technologyKind, defaultRule) in RuleSet.fastSkirmishResearchRules {
            if var decodedRule = migratedRules[technologyKind] {
                if decodedRule.requirements.isEmpty, !defaultRule.requirements.isEmpty {
                    decodedRule.requirements = defaultRule.requirements
                    migratedRules[technologyKind] = decodedRule
                }
            } else {
                migratedRules[technologyKind] = defaultRule
            }
        }

        return migratedRules
    }

    static func migrateShipRulesForRequirements(
        _ shipRules: [ShipKind: ShipRule],
        ruleSetID: String
    ) -> [ShipKind: ShipRule] {
        guard ruleSetID == RuleSet.fastSkirmish.id else {
            return shipRules
        }

        var migratedRules = shipRules

        for (shipKind, defaultRule) in RuleSet.fastSkirmishShipRules {
            if var decodedRule = migratedRules[shipKind] {
                if decodedRule.requirements.isEmpty, !defaultRule.requirements.isEmpty {
                    decodedRule.requirements = defaultRule.requirements
                    migratedRules[shipKind] = decodedRule
                }
            } else {
                migratedRules[shipKind] = defaultRule
            }
        }

        return migratedRules
    }

    static func migrateDefenseRulesForRequirements(
        _ defenseRules: [DefenseKind: DefenseRule],
        ruleSetID: String
    ) -> [DefenseKind: DefenseRule] {
        guard ruleSetID == RuleSet.fastSkirmish.id else {
            return defenseRules
        }

        var migratedRules = defenseRules

        for (defenseKind, defaultRule) in RuleSet.fastSkirmishDefenseRules {
            if var decodedRule = migratedRules[defenseKind] {
                if decodedRule.requirements.isEmpty, !defaultRule.requirements.isEmpty {
                    decodedRule.requirements = defaultRule.requirements
                    migratedRules[defenseKind] = decodedRule
                }
            } else {
                migratedRules[defenseKind] = defaultRule
            }
        }

        return migratedRules
    }

    static func migrateMissileRulesForRequirements(
        _ missileRules: [MissileKind: MissileRule],
        ruleSetID: String
    ) -> [MissileKind: MissileRule] {
        guard ruleSetID == RuleSet.fastSkirmish.id else {
            return missileRules
        }

        var migratedRules = missileRules

        for (missileKind, defaultRule) in RuleSet.fastSkirmishMissileRules {
            if var decodedRule = migratedRules[missileKind] {
                if decodedRule.requirements.isEmpty, !defaultRule.requirements.isEmpty {
                    decodedRule.requirements = defaultRule.requirements
                    migratedRules[missileKind] = decodedRule
                }
            } else {
                migratedRules[missileKind] = defaultRule
            }
        }

        return migratedRules
    }

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

    static func migrateDefenseRulesForCombatFields(_ defenseRules: [DefenseKind: DefenseRule]) -> [DefenseKind: DefenseRule] {
        var migratedRules = defenseRules

        for (defenseKind, defaultRule) in RuleSet.fastSkirmishDefenseRules {
            if let decodedRule = migratedRules[defenseKind] {
                migratedRules[defenseKind] = decodedRule.mergingMissingCombatFields(from: defaultRule)
            } else {
                migratedRules[defenseKind] = defaultRule
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
                productionPerHour: ResourceBundle(metal: 120),
                energyUsed: 10,
                aiPriorityWeight: 1.00
            ),
            .crystalMine: BuildingRule(
                baseCost: ResourceBundle(metal: 48, crystal: 24),
                costMultiplier: 1.60,
                baseDuration: 24,
                durationMultiplier: 1.35,
                productionPerHour: ResourceBundle(crystal: 80),
                energyUsed: 10,
                aiPriorityWeight: 0.95
            ),
            .deuteriumSynthesizer: BuildingRule(
                baseCost: ResourceBundle(metal: 225, crystal: 75),
                costMultiplier: 1.50,
                baseDuration: 32,
                durationMultiplier: 1.35,
                productionPerHour: ResourceBundle(deuterium: 48),
                energyUsed: 30,
                aiPriorityWeight: 0.75
            ),
            .solarPlant: BuildingRule(
                baseCost: ResourceBundle(metal: 75, crystal: 30),
                costMultiplier: 1.50,
                baseDuration: 18,
                durationMultiplier: 1.25,
                energyProduced: 20,
                aiPriorityWeight: 0.85
            ),
            .roboticsFactory: BuildingRule(
                baseCost: ResourceBundle(metal: 400, crystal: 120, deuterium: 80),
                costMultiplier: 1.70,
                baseDuration: 60,
                durationMultiplier: 1.40,
                constructionSpeedBonus: 0.20,
                shipyardSpeedBonus: 0.10,
                aiPriorityWeight: 0.55
            ),
            .shipyard: BuildingRule(
                baseCost: ResourceBundle(metal: 400, crystal: 200, deuterium: 100),
                costMultiplier: 1.70,
                baseDuration: 75,
                durationMultiplier: 1.40,
                aiPriorityWeight: 0.45,
                requirements: [.building(.roboticsFactory, level: 1)]
            ),
            .researchLab: BuildingRule(
                baseCost: ResourceBundle(metal: 200, crystal: 400, deuterium: 200),
                costMultiplier: 1.70,
                baseDuration: 70,
                durationMultiplier: 1.40,
                aiPriorityWeight: 0.60
            ),
            .metalStorage: BuildingRule(
                baseCost: ResourceBundle(metal: 1_000),
                costMultiplier: 1.65,
                baseDuration: 35,
                durationMultiplier: 1.35,
                aiPriorityWeight: 0.18
            ),
            .crystalStorage: BuildingRule(
                baseCost: ResourceBundle(metal: 1_000, crystal: 500),
                costMultiplier: 1.65,
                baseDuration: 35,
                durationMultiplier: 1.35,
                aiPriorityWeight: 0.18
            ),
            .deuteriumTank: BuildingRule(
                baseCost: ResourceBundle(metal: 1_000, crystal: 1_000),
                costMultiplier: 1.65,
                baseDuration: 35,
                durationMultiplier: 1.35,
                aiPriorityWeight: 0.16
            ),
            .naniteFactory: BuildingRule(
                baseCost: ResourceBundle(metal: 30_000, crystal: 15_000, deuterium: 5_000),
                costMultiplier: 2.00,
                baseDuration: 120,
                durationMultiplier: 1.55,
                constructionSpeedBonus: 1.00,
                shipyardSpeedBonus: 1.00,
                aiPriorityWeight: 0.12,
                requirements: [.building(.roboticsFactory, level: 2), .technology(.computer, level: 2)]
            ),
            .missileSilo: BuildingRule(
                baseCost: ResourceBundle(metal: 20_000, crystal: 20_000, deuterium: 1_000),
                costMultiplier: 1.70,
                baseDuration: 80,
                durationMultiplier: 1.45,
                aiPriorityWeight: 0.10,
                requirements: [.building(.shipyard, level: 2)]
            ),
            .lunarBase: BuildingRule(
                baseCost: ResourceBundle(metal: 20_000, crystal: 40_000, deuterium: 20_000),
                costMultiplier: 1.80,
                baseDuration: 100,
                durationMultiplier: 1.45,
                aiPriorityWeight: 0.04,
                requirements: [.technology(.hyperspaceDrive, level: 1)]
            ),
            .sensorPhalanx: BuildingRule(
                baseCost: ResourceBundle(metal: 20_000, crystal: 40_000, deuterium: 20_000),
                costMultiplier: 1.80,
                baseDuration: 90,
                durationMultiplier: 1.45,
                aiPriorityWeight: 0.03,
                requirements: [.building(.lunarBase, level: 1), .technology(.espionage, level: 2)]
            ),
            .jumpGate: BuildingRule(
                baseCost: ResourceBundle(metal: 200_000, crystal: 400_000, deuterium: 200_000),
                costMultiplier: 2.00,
                baseDuration: 160,
                durationMultiplier: 1.55,
                aiPriorityWeight: 0.02,
                requirements: [.building(.lunarBase, level: 2), .technology(.hyperspaceDrive, level: 3)]
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
                aiPriorityWeight: 0.20,
                requirements: [.technology(.energy, level: 1)]
            ),
            .hyperspaceDrive: ResearchRule(
                baseCost: ResourceBundle(metal: 10_000, crystal: 20_000, deuterium: 6_000),
                costMultiplier: 2.00,
                baseDuration: 120,
                durationMultiplier: 1.65,
                aiPriorityWeight: 0.10,
                requirements: [.technology(.energy, level: 3), .technology(.impulseDrive, level: 2)]
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
                hull: 12_000,
                requirements: [.technology(.combustionDrive, level: 2)]
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
                hull: 10_000,
                requirements: [.technology(.weapons, level: 1)]
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
                hull: 27_000,
                requirements: [.technology(.impulseDrive, level: 2)]
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
                hull: 60_000,
                requirements: [.technology(.hyperspaceDrive, level: 1)]
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
                hull: 30_000,
                requirements: [.building(.shipyard, level: 2), .technology(.impulseDrive, level: 1)]
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
                hull: 16_000,
                requirements: [.building(.shipyard, level: 2), .technology(.combustionDrive, level: 2)]
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
                hull: 1_000,
                requirements: [.technology(.espionage, level: 1)]
            ),
            .bomber: ShipRule(
                baseCost: ResourceBundle(metal: 50_000, crystal: 25_000, deuterium: 15_000),
                baseDuration: 90,
                aiPriorityWeight: 0.22,
                speed: 6_000,
                cargoCapacity: 500,
                fuelCost: 700,
                attack: 1_000,
                shield: 500,
                hull: 75_000,
                requirements: [.building(.shipyard, level: 5), .technology(.impulseDrive, level: 3), .technology(.weapons, level: 3)]
            ),
            .solarSatellite: ShipRule(
                baseCost: ResourceBundle(crystal: 2_000, deuterium: 500),
                baseDuration: 12,
                aiPriorityWeight: 0.08,
                speed: 1,
                cargoCapacity: 0,
                fuelCost: 0,
                attack: 1,
                shield: 1,
                hull: 2_000,
                requirements: [.building(.shipyard, level: 1), .technology(.energy, level: 1)]
            ),
            .destroyer: ShipRule(
                baseCost: ResourceBundle(metal: 60_000, crystal: 50_000, deuterium: 15_000),
                baseDuration: 110,
                aiPriorityWeight: 0.18,
                speed: 5_000,
                cargoCapacity: 2_000,
                fuelCost: 1_000,
                attack: 2_000,
                shield: 500,
                hull: 110_000,
                requirements: [.building(.shipyard, level: 7), .technology(.hyperspaceDrive, level: 3), .technology(.weapons, level: 4)]
            ),
            .deathstar: ShipRule(
                baseCost: ResourceBundle(metal: 1_000_000, crystal: 800_000, deuterium: 200_000),
                baseDuration: 600,
                aiPriorityWeight: 0.04,
                speed: 100,
                cargoCapacity: 1_000_000,
                fuelCost: 1,
                attack: 200_000,
                shield: 50_000,
                hull: 9_000_000,
                requirements: [.building(.shipyard, level: 8), .building(.naniteFactory, level: 2), .technology(.hyperspaceDrive, level: 5), .technology(.energy, level: 6)]
            ),
            .battlecruiser: ShipRule(
                baseCost: ResourceBundle(metal: 30_000, crystal: 40_000, deuterium: 15_000),
                baseDuration: 85,
                aiPriorityWeight: 0.24,
                speed: 10_000,
                cargoCapacity: 750,
                fuelCost: 250,
                attack: 700,
                shield: 400,
                hull: 70_000,
                requirements: [.building(.shipyard, level: 6), .technology(.hyperspaceDrive, level: 4), .technology(.computer, level: 4)]
            )
        ]
    }

    static var fastSkirmishDefenseRules: [DefenseKind: DefenseRule] {
        [
            .rocketLauncher: DefenseRule(
                baseCost: ResourceBundle(metal: 2_000),
                baseDuration: 6,
                aiPriorityWeight: 0.50,
                attack: 80,
                shield: 20,
                hull: 2_000
            ),
            .lightLaser: DefenseRule(
                baseCost: ResourceBundle(metal: 1_500, crystal: 500),
                baseDuration: 20,
                aiPriorityWeight: 0.45,
                attack: 100,
                shield: 25,
                hull: 2_000,
                requirements: [.building(.shipyard, level: 1)]
            ),
            .heavyLaser: DefenseRule(
                baseCost: ResourceBundle(metal: 6_000, crystal: 2_000),
                baseDuration: 35,
                aiPriorityWeight: 0.35,
                attack: 250,
                shield: 100,
                hull: 8_000,
                requirements: [.building(.shipyard, level: 2), .technology(.energy, level: 1)]
            ),
            .gaussCannon: DefenseRule(
                baseCost: ResourceBundle(metal: 20_000, crystal: 15_000, deuterium: 2_000),
                baseDuration: 55,
                aiPriorityWeight: 0.25,
                attack: 1_100,
                shield: 200,
                hull: 35_000,
                requirements: [.building(.shipyard, level: 4), .technology(.weapons, level: 3)]
            ),
            .ionCannon: DefenseRule(
                baseCost: ResourceBundle(metal: 2_000, crystal: 6_000),
                baseDuration: 40,
                aiPriorityWeight: 0.30,
                attack: 150,
                shield: 500,
                hull: 8_000,
                requirements: [.building(.shipyard, level: 3), .technology(.shielding, level: 2)]
            ),
            .plasmaTurret: DefenseRule(
                baseCost: ResourceBundle(metal: 50_000, crystal: 50_000, deuterium: 30_000),
                baseDuration: 90,
                aiPriorityWeight: 0.15,
                attack: 3_000,
                shield: 300,
                hull: 100_000,
                requirements: [.building(.shipyard, level: 6), .technology(.energy, level: 4)]
            )
        ]
    }

    static var fastSkirmishMissileRules: [MissileKind: MissileRule] {
        [
            .antiBallisticMissile: MissileRule(
                baseCost: ResourceBundle(metal: 800, crystal: 200),
                baseDuration: 12,
                requirements: [.building(.shipyard, level: 2)]
            ),
            .interplanetaryMissile: MissileRule(
                baseCost: ResourceBundle(metal: 2_500, crystal: 1_000, deuterium: 2_000),
                baseDuration: 30,
                requirements: [.building(.shipyard, level: 4), .technology(.impulseDrive, level: 2)]
            )
        ]
    }
}
