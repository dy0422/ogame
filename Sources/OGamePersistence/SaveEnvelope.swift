import Foundation
import OGameCore

public struct SaveEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var appVersion: String
    public var lastSavedAt: Date
    public var universe: Universe

    public init(
        schemaVersion: Int = SaveEnvelope.currentSchemaVersion,
        appVersion: String = "0.1.0",
        lastSavedAt: Date,
        universe: Universe
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.lastSavedAt = lastSavedAt
        self.universe = universe
    }
}
