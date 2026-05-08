import Foundation
import OGameCore

public enum SaveMigrator {
    private static let minimumStorageBaseline = ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000)

    public static func migrate(_ data: Data) throws -> SaveEnvelope {
        let decoder = JSONSaveRepository.makePortableDecoder()
        let header = try decoder.decode(SaveHeader.self, from: data)

        guard header.schemaVersion <= SaveEnvelope.currentSchemaVersion else {
            throw JSONSaveRepository.RepositoryError.unsupportedSchema(header.schemaVersion)
        }

        var envelope = try decoder.decode(SaveEnvelope.self, from: data)
        envelope.schemaVersion = SaveEnvelope.currentSchemaVersion
        migrateStorageBaselines(in: &envelope.universe)
        return envelope
    }

    private static func migrateStorageBaselines(in universe: inout Universe) {
        for index in universe.planets.indices {
            universe.planets[index].storage = ResourceStorage(
                metal: max(universe.planets[index].storage.metal, minimumStorageBaseline.metal),
                crystal: max(universe.planets[index].storage.crystal, minimumStorageBaseline.crystal),
                deuterium: max(universe.planets[index].storage.deuterium, minimumStorageBaseline.deuterium)
            )
        }
    }

    private struct SaveHeader: Decodable {
        var schemaVersion: Int
    }
}
