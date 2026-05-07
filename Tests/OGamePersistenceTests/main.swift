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

func testRepositorySavesAndLoadsQueueMetadata() throws {
    let directory = uniqueTemporaryDirectory()
    let repository = JSONSaveRepository(saveDirectory: directory)
    var universe = StarterUniverseFactory.makeNewGame(seed: 14, playerName: "Commander")
    let factionID = universe.playerFactionID
    let planetID = universe.planets[0].id
    let buildQueueItem = BuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b0")!,
        planetID: planetID,
        buildingKind: .metalMine,
        targetLevel: 2,
        startTime: 10,
        finishTime: 70,
        paidCost: ResourceBundle(metal: 60, crystal: 15)
    )
    let researchQueueItem = ResearchQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!,
        factionID: factionID,
        technologyKind: .computer,
        targetLevel: 1,
        startTime: 75,
        finishTime: 180,
        paidCost: ResourceBundle(crystal: 400, deuterium: 600)
    )
    let shipQueueItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b2")!,
        planetID: planetID,
        unitKind: .ship(.smallCargo),
        quantity: 2,
        startTime: 185,
        finishTime: 205,
        paidCost: ResourceBundle(metal: 4_000, crystal: 4_000)
    )
    let defenseQueueItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b3")!,
        planetID: planetID,
        unitKind: .defense(.rocketLauncher),
        quantity: 3,
        startTime: 210,
        finishTime: 228,
        paidCost: ResourceBundle(metal: 6_000)
    )

    universe.lastSimulatedWallClockTime = Date(timeIntervalSince1970: 5_000)
    universe.planets[0].buildQueue = [buildQueueItem]
    universe.planets[0].shipBuildQueue = [shipQueueItem]
    universe.planets[0].defenseBuildQueue = [defenseQueueItem]
    universe.factions[0].researchQueue = [researchQueueItem]

    try repository.save(universe, wallClockDate: Date(timeIntervalSince1970: 6_000))
    let loaded = try repository.load()

    requireEqual(loaded.universe, universe, "Repository should preserve queue metadata through save/load")
    requireEqual(loaded.universe.planets[0].buildQueue, [buildQueueItem], "Repository should preserve planet build queue")
    requireEqual(loaded.universe.planets[0].shipBuildQueue, [shipQueueItem], "Repository should preserve planet ship build queue")
    requireEqual(loaded.universe.planets[0].defenseBuildQueue, [defenseQueueItem], "Repository should preserve planet defense build queue")
    requireEqual(loaded.universe.factions[0].researchQueue, [researchQueueItem], "Repository should preserve faction research queue")
    requireEqual(
        loaded.universe.lastSimulatedWallClockTime,
        Date(timeIntervalSince1970: 5_000),
        "Repository should preserve simulation wall-clock metadata"
    )
}

func testLoadedEnvelopePreparesOfflineCatchUpWithoutSavingUntilExplicitWrite() throws {
    let directory = uniqueTemporaryDirectory()
    let repository = JSONSaveRepository(saveDirectory: directory)
    let universe = StarterUniverseFactory.makeNewGame(seed: 15, playerName: "Commander")
    let savedAt = Date(timeIntervalSince1970: 10_000)
    let currentDate = Date(timeIntervalSince1970: 10_600)

    try repository.save(universe, wallClockDate: savedAt)
    let loaded = try repository.load()
    let elapsed = loaded.elapsedSinceLastSave(until: currentDate)
    let catchUpResult = loaded.offlineCatchUp(until: currentDate)
    let unchangedAfterCatchUp = try repository.load()

    try repository.save(catchUpResult.universe, wallClockDate: currentDate)
    let reloaded = try repository.load()

    requireEqual(elapsed, 600, "Loaded envelope should compute elapsed seconds from its wall-clock save date")
    requireEqual(catchUpResult.summary.elapsedSeconds, 600, "Offline catch-up should use the loaded wall-clock elapsed time")
    requireEqual(catchUpResult.summary.didMutate, true, "Positive loaded elapsed time should mutate during offline catch-up")
    requireEqual(unchangedAfterCatchUp.lastSavedAt, savedAt, "Prepared catch-up should not rewrite the save date before explicit save")
    requireEqual(unchangedAfterCatchUp.universe, universe, "Prepared catch-up should not rewrite the saved universe before explicit save")
    requireEqual(catchUpResult.universe.lastSimulatedWallClockTime, currentDate, "Catch-up should store the current wall-clock date")
    requireEqual(catchUpResult.universe.events.last?.title, "Offline Catch-Up Complete", "Catch-up should record a summary event")
    requireEqual(reloaded.schemaVersion, SaveEnvelope.currentSchemaVersion, "Resaved catch-up should preserve schema version")
    requireEqual(reloaded.lastSavedAt, currentDate, "Resaved catch-up should preserve the current wall-clock date")
    requireEqual(reloaded.universe, catchUpResult.universe, "Resaved catch-up universe should round-trip without schema drift")
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
try testRepositorySavesAndLoadsQueueMetadata()
try testLoadedEnvelopePreparesOfflineCatchUpWithoutSavingUntilExplicitWrite()
testRepositoryReportsMissingSave()
try testRepositoryRejectsUnsupportedSchema()
try testRepositoryRejectsInvalidFileNamesBeforeSaving()
testRepositoryRejectsInvalidFileNamesBeforeLoading()
try testRepositoryRejectsUnsupportedSchemaBeforeFullEnvelopeDecode()
print("OGamePersistenceTests passed")
