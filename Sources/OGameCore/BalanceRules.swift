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
}
