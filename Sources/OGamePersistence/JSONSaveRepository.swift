import Foundation
import OGameCore

public struct JSONSaveRepository: Sendable {
    public enum RepositoryError: Error, Equatable, Sendable {
        case missingSave
        case unsupportedSchema(Int)
        case invalidFileName(String)
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
        let saveURL = try validatedSaveURL()
        try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)

        let envelope = SaveEnvelope(lastSavedAt: wallClockDate, universe: universe)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(envelope)
        try data.write(to: saveURL, options: [.atomic])
    }

    public func load() throws -> SaveEnvelope {
        let saveURL = try validatedSaveURL()
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            throw RepositoryError.missingSave
        }

        let data = try Data(contentsOf: saveURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let header = try decoder.decode(SaveHeader.self, from: data)
        guard header.schemaVersion == SaveEnvelope.currentSchemaVersion else {
            throw RepositoryError.unsupportedSchema(header.schemaVersion)
        }

        let envelope = try decoder.decode(SaveEnvelope.self, from: data)
        return envelope
    }

    private func validatedSaveURL() throws -> URL {
        guard Self.isValidFileName(fileName) else {
            throw RepositoryError.invalidFileName(fileName)
        }
        return saveDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    private static func isValidFileName(_ fileName: String) -> Bool {
        guard !fileName.isEmpty, fileName != ".", fileName != ".." else {
            return false
        }
        guard !fileName.contains("/"), !fileName.contains("\\") else {
            return false
        }
        return URL(fileURLWithPath: fileName).lastPathComponent == fileName
    }

    private struct SaveHeader: Decodable {
        var schemaVersion: Int
    }
}
