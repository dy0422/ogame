import Foundation

public enum SaveMigrator {
    public static func migrate(_ data: Data) throws -> SaveEnvelope {
        let decoder = JSONSaveRepository.makePortableDecoder()
        let header = try decoder.decode(SaveHeader.self, from: data)

        guard header.schemaVersion <= SaveEnvelope.currentSchemaVersion else {
            throw JSONSaveRepository.RepositoryError.unsupportedSchema(header.schemaVersion)
        }

        var envelope = try decoder.decode(SaveEnvelope.self, from: data)
        envelope.schemaVersion = SaveEnvelope.currentSchemaVersion
        return envelope
    }

    private struct SaveHeader: Decodable {
        var schemaVersion: Int
    }
}
