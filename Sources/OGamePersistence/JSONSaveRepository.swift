import Foundation
import OGameCore

public struct JSONSaveRepository: Sendable {
    public enum RepositoryError: Error, Equatable, Sendable {
        case missingSave
        case unsupportedSchema(Int)
    }

    public var saveDirectory: URL
    public var fileName: String

    public init(saveDirectory: URL, fileName: String = "autosave.json") {
        self.saveDirectory = saveDirectory
        self.fileName = fileName
    }

    public static func defaultRepository() throws -> JSONSaveRepository {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("NativeOGame", isDirectory: true)
        return JSONSaveRepository(saveDirectory: directory)
    }

    public func save(_ universe: Universe, wallClockDate: Date = Date()) throws {
        try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)

        let envelope = SaveEnvelope(lastSavedAt: wallClockDate, universe: universe)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(envelope)
        try data.write(to: saveURL, options: [.atomic])
    }

    public func load() throws -> SaveEnvelope {
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            throw RepositoryError.missingSave
        }

        let data = try Data(contentsOf: saveURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope = try decoder.decode(SaveEnvelope.self, from: data)
        guard envelope.schemaVersion == SaveEnvelope.currentSchemaVersion else {
            throw RepositoryError.unsupportedSchema(envelope.schemaVersion)
        }
        return envelope
    }

    private var saveURL: URL {
        saveDirectory.appendingPathComponent(fileName, isDirectory: false)
    }
}
