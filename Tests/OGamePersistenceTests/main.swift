import Foundation
import OGameCore
import OGamePersistence

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

func requireEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual != expected {
        fatalError("\(message): \(actual) != \(expected)")
    }
}

func requireRepositoryError(
    _ expected: JSONSaveRepository.RepositoryError,
    _ message: String,
    operation: () throws -> Void
) {
    do {
        try operation()
        fatalError(message)
    } catch let error as JSONSaveRepository.RepositoryError {
        requireEqual(error, expected, message)
    } catch {
        fatalError("\(message): \(error)")
    }
}

func uniqueTemporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("NativeOGamePersistenceTests-\(UUID().uuidString)", isDirectory: true)
}

func testRepositorySavesAndLoadsUniverse() throws {
    let directory = uniqueTemporaryDirectory()
    let repository = JSONSaveRepository(saveDirectory: directory)
    let universe = StarterUniverseFactory.makeNewGame(seed: 11, playerName: "Commander")
    let wallClockDate = Date(timeIntervalSince1970: 1_000)

    try repository.save(universe, wallClockDate: wallClockDate)
    let loaded = try repository.load()

    requireEqual(loaded.universe, universe, "Repository should load the saved universe")
    requireEqual(loaded.lastSavedAt, wallClockDate, "Repository should preserve save date")
    requireEqual(loaded.schemaVersion, SaveEnvelope.currentSchemaVersion, "Repository should preserve schema version")
}

func testRepositoryReportsMissingSave() {
    let repository = JSONSaveRepository(saveDirectory: uniqueTemporaryDirectory())

    requireRepositoryError(.missingSave, "Repository should report missing save files") {
        _ = try repository.load()
    }
}

func testRepositoryRejectsUnsupportedSchema() throws {
    let directory = uniqueTemporaryDirectory()
    let repository = JSONSaveRepository(saveDirectory: directory)
    let universe = StarterUniverseFactory.makeNewGame(seed: 12, playerName: "Commander")
    let envelope = SaveEnvelope(
        schemaVersion: SaveEnvelope.currentSchemaVersion + 1,
        lastSavedAt: Date(timeIntervalSince1970: 2_000),
        universe: universe
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try encoder.encode(envelope).write(to: directory.appendingPathComponent("autosave.json"), options: [.atomic])

    requireRepositoryError(
        .unsupportedSchema(SaveEnvelope.currentSchemaVersion + 1),
        "Repository should reject unsupported schema versions"
    ) {
        _ = try repository.load()
    }
}

func testRepositoryRejectsInvalidFileNamesBeforeSaving() throws {
    let directory = uniqueTemporaryDirectory()
    let escapedFileName = "NativeOGamePersistenceTests-\(UUID().uuidString)-escape.json"
    let outsideURL = directory.deletingLastPathComponent().appendingPathComponent(escapedFileName)
    let universe = StarterUniverseFactory.makeNewGame(seed: 13, playerName: "Commander")

    for fileName in ["../\(escapedFileName)", "nested/escape.json"] {
        let repository = JSONSaveRepository(saveDirectory: directory, fileName: fileName)

        requireRepositoryError(.invalidFileName(fileName), "Repository should reject invalid save file names") {
            try repository.save(universe, wallClockDate: Date(timeIntervalSince1970: 3_000))
        }

        require(!FileManager.default.fileExists(atPath: outsideURL.path), "Repository should not write outside save directory")
        require(
            !FileManager.default.fileExists(atPath: directory.appendingPathComponent("nested/escape.json").path),
            "Repository should not write nested save paths"
        )
    }
}

func testRepositoryRejectsInvalidFileNamesBeforeLoading() {
    let fileName = "../escape.json"
    let repository = JSONSaveRepository(saveDirectory: uniqueTemporaryDirectory(), fileName: fileName)

    requireRepositoryError(.invalidFileName(fileName), "Repository should reject invalid load file names") {
        _ = try repository.load()
    }
}

func testRepositoryRejectsUnsupportedSchemaBeforeFullEnvelopeDecode() throws {
    let directory = uniqueTemporaryDirectory()
    let repository = JSONSaveRepository(saveDirectory: directory)
    let unsupportedVersion = SaveEnvelope.currentSchemaVersion + 1
    let futureSchemaJSON = """
    {
      "schemaVersion": \(unsupportedVersion),
      "payload": {
        "futureOnlyField": true
      }
    }
    """

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(futureSchemaJSON.utf8).write(to: directory.appendingPathComponent("autosave.json"), options: [.atomic])

    requireRepositoryError(.unsupportedSchema(unsupportedVersion), "Repository should reject unsupported schema before full decode") {
        _ = try repository.load()
    }
}

try testRepositorySavesAndLoadsUniverse()
testRepositoryReportsMissingSave()
try testRepositoryRejectsUnsupportedSchema()
try testRepositoryRejectsInvalidFileNamesBeforeSaving()
testRepositoryRejectsInvalidFileNamesBeforeLoading()
try testRepositoryRejectsUnsupportedSchemaBeforeFullEnvelopeDecode()
print("OGamePersistenceTests passed")
