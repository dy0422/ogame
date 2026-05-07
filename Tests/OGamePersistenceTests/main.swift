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

func testRepositorySavesAndLoadsFleetsReportsAndSettings() throws {
    let directory = uniqueTemporaryDirectory()
    let repository = JSONSaveRepository(saveDirectory: directory)
    var universe = StarterUniverseFactory.makeNewGame(seed: 22, playerName: "Commander")
    let playerID = universe.playerFactionID
    let originID = universe.planets[0].id
    let targetID = universe.planets[1].id
    let fleet = Fleet(
        id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-0000000007b0")!),
        ownerID: playerID,
        mission: .espionage,
        origin: universe.planets[0].coordinate,
        target: universe.planets[1].coordinate,
        ships: [.espionageProbe: 1],
        launchTime: 100,
        arrivalTime: 140,
        returnTime: 180,
        originPlanetID: originID,
        targetPlanetID: targetID
    )
    let report = Report(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000007b1")!,
        time: 140,
        kind: .espionage,
        title: "Espionage at \(universe.planets[1].coordinate.displayText)",
        summary: "Probe returned scanner data.",
        participants: [
            ReportParticipant(
                role: .observer,
                factionID: playerID,
                planetID: targetID,
                name: "Commander",
                beforeShips: [.espionageProbe: 1],
                afterShips: [.espionageProbe: 1]
            )
        ]
    )
    let settings = GameSettings(
        offlineIntensity: .intense,
        gameSpeed: 2.5,
        isAutosaveEnabled: false,
        difficulty: .hard
    )

    universe.fleets = [fleet]
    universe.reports = [report]

    try repository.save(universe, wallClockDate: Date(timeIntervalSince1970: 8_000), settings: settings)
    let loaded = try repository.load()

    requireEqual(loaded.universe.fleets, [fleet], "Repository should preserve active fleets through save/load")
    requireEqual(loaded.universe.reports, [report], "Repository should preserve reports through save/load")
    requireEqual(loaded.settings, settings, "Repository should preserve settings with fleets and reports")
    requireEqual(loaded.universe, universe, "Repository should preserve the full universe with fleet/report state")
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

func testRepositoryListsSaveSlots() throws {
    let directory = uniqueTemporaryDirectory()
    let repository = JSONSaveRepository(saveDirectory: directory)
    let autosave = StarterUniverseFactory.makeNewGame(seed: 16, playerName: "Commander")
    let campaign = StarterUniverseFactory.makeNewGame(seed: 17, playerName: "Commander")

    try repository.save(autosave, wallClockDate: Date(timeIntervalSince1970: 7_000))
    try repository.saveSlot(named: "campaign-a.json", universe: campaign, wallClockDate: Date(timeIntervalSince1970: 7_100))
    try repository.saveSlot(named: "backup-19700101-020000.json", universe: campaign, wallClockDate: Date(timeIntervalSince1970: 7_200))

    let slots = try repository.listSaveSlots()

    requireEqual(
        slots.map(\.name),
        ["autosave.json", "backup-19700101-020000.json"],
        "Repository should only list autosave and backup save slots"
    )
    requireEqual(slots.map(\.isAutosave), [true, false], "Repository should identify the autosave slot")
}

func testRepositoryRejectsInvalidSaveSlotNames() throws {
    let directory = uniqueTemporaryDirectory()
    let repository = JSONSaveRepository(saveDirectory: directory)
    let universe = StarterUniverseFactory.makeNewGame(seed: 18, playerName: "Commander")

    for slotName in ["../escape.json", "nested/escape.json", "..", "."] {
        requireRepositoryError(.invalidFileName(slotName), "Repository should reject invalid save slot names") {
            try repository.saveSlot(named: slotName, universe: universe, wallClockDate: Date(timeIntervalSince1970: 7_200))
        }

        requireRepositoryError(.invalidFileName(slotName), "Repository should reject invalid load slot names") {
            _ = try repository.loadSlot(named: slotName)
        }

        requireRepositoryError(.invalidFileName(slotName), "Repository should reject invalid delete slot names") {
            try repository.deleteSlot(named: slotName)
        }
    }
}

func testRepositoryCreatesBackupWithoutReplacingAutosave() throws {
    let directory = uniqueTemporaryDirectory()
    let repository = JSONSaveRepository(saveDirectory: directory)
    let universe = StarterUniverseFactory.makeNewGame(seed: 19, playerName: "Commander")
    let savedAt = Date(timeIntervalSince1970: 7_300)

    try repository.save(universe, wallClockDate: savedAt)
    let backup = try repository.createBackup(wallClockDate: Date(timeIntervalSince1970: 7_400))
    let autosaveAfterBackup = try repository.load()
    let backupEnvelope = try repository.loadSlot(named: backup.name)

    require(backup.name != "autosave.json", "Backup should not use the autosave file name")
    requireEqual(autosaveAfterBackup.universe, universe, "Creating a backup should preserve the autosave universe")
    requireEqual(autosaveAfterBackup.lastSavedAt, savedAt, "Creating a backup should preserve the autosave timestamp")
    requireEqual(backupEnvelope.universe, universe, "Backup should contain the current autosave universe")
    requireEqual(backupEnvelope.lastSavedAt, savedAt, "Backup should contain the current autosave timestamp")
}

func testRepositoryDeleteBackupIgnoresNonBackupJSON() throws {
    let directory = uniqueTemporaryDirectory()
    let repository = JSONSaveRepository(saveDirectory: directory)
    let universe = StarterUniverseFactory.makeNewGame(seed: 21, playerName: "Commander")

    try repository.save(universe, wallClockDate: Date(timeIntervalSince1970: 7_600))
    try repository.saveSlot(named: "metadata.json", universe: universe, wallClockDate: Date(timeIntervalSince1970: 7_700))
    try repository.saveSlot(named: "backup-19700101-021000.json", universe: universe, wallClockDate: Date(timeIntervalSince1970: 7_800))

    requireRepositoryError(.invalidFileName("metadata.json"), "Repository should reject deleting non-backup JSON through backup deletion") {
        try repository.deleteBackup(named: "metadata.json")
    }

    try repository.deleteBackup(named: "backup-19700101-021000.json")
    let remainingSlots = try repository.listSaveSlots()

    require(
        FileManager.default.fileExists(atPath: directory.appendingPathComponent("metadata.json").path),
        "Backup deletion should not remove non-backup JSON files"
    )
    requireEqual(remainingSlots.map(\.name), ["autosave.json"], "Deleted backups should disappear from listed slots")
}

func testSaveEnvelopeRoundTripsSettingsAndDefaultsMissingSettings() throws {
    let universe = StarterUniverseFactory.makeNewGame(seed: 20, playerName: "Commander")
    let settings = GameSettings(
        offlineIntensity: .reduced,
        gameSpeed: 4,
        isAutosaveEnabled: false,
        difficulty: .hard
    )
    let envelope = SaveEnvelope(
        lastSavedAt: Date(timeIntervalSince1970: 7_500),
        universe: universe,
        settings: settings
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let encoded = try encoder.encode(envelope)
    let decoded = try decoder.decode(SaveEnvelope.self, from: encoded)
    let legacyJSON = """
    {
      "appVersion": "0.1.0",
      "lastSavedAt": "1970-01-01T02:05:00Z",
      "schemaVersion": \(SaveEnvelope.currentSchemaVersion),
      "universe": \(String(data: try encoder.encode(universe), encoding: .utf8)!)
    }
    """
    let legacyDecoded = try decoder.decode(SaveEnvelope.self, from: Data(legacyJSON.utf8))

    requireEqual(decoded.settings, settings, "Save envelope should preserve settings")
    requireEqual(legacyDecoded.settings, GameSettings(), "Save envelope should default missing settings from older saves")
}

func testGameSettingsDecodesPartialSettingsWithDefaults() throws {
    let decoder = JSONDecoder()
    let partialJSON = """
    {
      "gameSpeed": 2,
      "offlineIntensity": "not-a-mode"
    }
    """

    let settings = try decoder.decode(GameSettings.self, from: Data(partialJSON.utf8))

    requireEqual(settings.gameSpeed, 2, "Settings should preserve valid partial speed")
    requireEqual(settings.offlineIntensity, .normal, "Settings should default invalid offline intensity")
    requireEqual(settings.isAutosaveEnabled, true, "Settings should default missing autosave flag")
    requireEqual(settings.difficulty, .standard, "Settings should default missing difficulty")
}

func testGameSettingsClampsOutOfRangeSpeed() throws {
    let decoder = JSONDecoder()
    let fastJSON = """
    {
      "gameSpeed": 99,
      "offlineIntensity": "intense",
      "isAutosaveEnabled": false,
      "difficulty": "hard"
    }
    """
    let slowJSON = """
    {
      "gameSpeed": -4
    }
    """

    let fastSettings = try decoder.decode(GameSettings.self, from: Data(fastJSON.utf8))
    let slowSettings = try decoder.decode(GameSettings.self, from: Data(slowJSON.utf8))

    requireEqual(fastSettings.gameSpeed, 8, "Settings should clamp high game speed")
    requireEqual(fastSettings.offlineIntensity, .intense, "Settings should decode valid offline intensity")
    requireEqual(fastSettings.isAutosaveEnabled, false, "Settings should decode valid autosave flag")
    requireEqual(fastSettings.difficulty, .hard, "Settings should decode valid difficulty")
    requireEqual(slowSettings.gameSpeed, 0.25, "Settings should clamp low game speed")
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
try testRepositorySavesAndLoadsFleetsReportsAndSettings()
try testLoadedEnvelopePreparesOfflineCatchUpWithoutSavingUntilExplicitWrite()
testRepositoryReportsMissingSave()
try testRepositoryRejectsUnsupportedSchema()
try testRepositoryRejectsInvalidFileNamesBeforeSaving()
testRepositoryRejectsInvalidFileNamesBeforeLoading()
try testRepositoryListsSaveSlots()
try testRepositoryRejectsInvalidSaveSlotNames()
try testRepositoryCreatesBackupWithoutReplacingAutosave()
try testRepositoryDeleteBackupIgnoresNonBackupJSON()
try testSaveEnvelopeRoundTripsSettingsAndDefaultsMissingSettings()
try testGameSettingsDecodesPartialSettingsWithDefaults()
try testGameSettingsClampsOutOfRangeSpeed()
try testRepositoryRejectsUnsupportedSchemaBeforeFullEnvelopeDecode()
print("OGamePersistenceTests passed")
