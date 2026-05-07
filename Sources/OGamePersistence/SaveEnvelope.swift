import Foundation
import OGameCore

public struct SaveEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var appVersion: String
    public var lastSavedAt: Date
    public var universe: Universe
    public var settings: GameSettings

    public init(
        schemaVersion: Int = SaveEnvelope.currentSchemaVersion,
        appVersion: String = "0.1.0",
        lastSavedAt: Date,
        universe: Universe,
        settings: GameSettings = GameSettings()
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.lastSavedAt = lastSavedAt
        self.universe = universe
        self.settings = settings
    }

    public func elapsedSinceLastSave(until currentDate: Date) -> TimeInterval {
        currentDate.timeIntervalSince(lastSavedAt) * settings.offlineIntensity.multiplier
    }

    public func offlineCatchUp(until currentDate: Date) -> (
        universe: Universe,
        summary: OfflineCatchUpSummary
    ) {
        var caughtUpUniverse = universe
        let summary = OfflineSimulationEngine.catchUp(
            universe: &caughtUpUniverse,
            elapsed: elapsedSinceLastSave(until: currentDate),
            now: currentDate
        )
        return (caughtUpUniverse, summary)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appVersion
        case lastSavedAt
        case universe
        case settings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        lastSavedAt = try container.decode(Date.self, forKey: .lastSavedAt)
        universe = try container.decode(Universe.self, forKey: .universe)
        settings = try container.decodeIfPresent(GameSettings.self, forKey: .settings) ?? GameSettings()
    }
}
