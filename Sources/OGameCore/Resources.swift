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

    public func adding(_ other: ResourceBundle) -> ResourceBundle {
        ResourceBundle(
            metal: metal + other.metal,
            crystal: crystal + other.crystal,
            deuterium: deuterium + other.deuterium
        )
    }

    public func subtracting(_ other: ResourceBundle) -> ResourceBundle {
        ResourceBundle(
            metal: metal - other.metal,
            crystal: crystal - other.crystal,
            deuterium: deuterium - other.deuterium
        )
    }

    public func scaled(by multiplier: Double) -> ResourceBundle {
        ResourceBundle(
            metal: metal * multiplier,
            crystal: crystal * multiplier,
            deuterium: deuterium * multiplier
        )
    }

    public var nonnegative: ResourceBundle {
        ResourceBundle(
            metal: max(metal, 0),
            crystal: max(crystal, 0),
            deuterium: max(deuterium, 0)
        )
    }

    public func canAfford(_ cost: ResourceBundle) -> Bool {
        metal >= cost.metal &&
            crystal >= cost.crystal &&
            deuterium >= cost.deuterium
    }

    public func clamped(to storage: ResourceStorage) -> ResourceBundle {
        let metalLimit = max(storage.metal, 0)
        let crystalLimit = max(storage.crystal, 0)
        let deuteriumLimit = max(storage.deuterium, 0)

        return ResourceBundle(
            metal: min(max(metal, 0), metalLimit),
            crystal: min(max(crystal, 0), crystalLimit),
            deuterium: min(max(deuterium, 0), deuteriumLimit)
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

    public var asResourceBundle: ResourceBundle {
        ResourceBundle(metal: metal, crystal: crystal, deuterium: deuterium)
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
