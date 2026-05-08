import Foundation

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
        self.resourceReserveRatio = Self.normalizedReserveRatio(resourceReserveRatio)
        self.maxBuildQueueDepthPerPlanet = Self.normalizedQueueDepth(maxBuildQueueDepthPerPlanet)
        self.maxResearchQueueDepth = Self.normalizedQueueDepth(maxResearchQueueDepth)
        self.allowShipConstruction = allowShipConstruction
        self.allowDefenseConstruction = allowDefenseConstruction
        self.allowMissileConstruction = allowMissileConstruction
    }

    private enum CodingKeys: String, CodingKey {
        case strategy
        case resourceReserveRatio
        case maxBuildQueueDepthPerPlanet
        case maxResearchQueueDepth
        case allowShipConstruction
        case allowDefenseConstruction
        case allowMissileConstruction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AutoUpgradePolicy()

        self.init(
            strategy: try container.decodeIfPresent(AutoUpgradeStrategy.self, forKey: .strategy) ?? defaults.strategy,
            resourceReserveRatio: try container.decodeIfPresent(Double.self, forKey: .resourceReserveRatio) ?? defaults.resourceReserveRatio,
            maxBuildQueueDepthPerPlanet: try container.decodeIfPresent(Int.self, forKey: .maxBuildQueueDepthPerPlanet) ?? defaults.maxBuildQueueDepthPerPlanet,
            maxResearchQueueDepth: try container.decodeIfPresent(Int.self, forKey: .maxResearchQueueDepth) ?? defaults.maxResearchQueueDepth,
            allowShipConstruction: try container.decodeIfPresent(Bool.self, forKey: .allowShipConstruction) ?? defaults.allowShipConstruction,
            allowDefenseConstruction: try container.decodeIfPresent(Bool.self, forKey: .allowDefenseConstruction) ?? defaults.allowDefenseConstruction,
            allowMissileConstruction: try container.decodeIfPresent(Bool.self, forKey: .allowMissileConstruction) ?? defaults.allowMissileConstruction
        )
    }

    private static func normalizedReserveRatio(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0.15
        }

        return min(max(value, 0), 0.80)
    }

    private static func normalizedQueueDepth(_ value: Int) -> Int {
        max(1, min(value, 20))
    }
}
