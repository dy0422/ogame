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
