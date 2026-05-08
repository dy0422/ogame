import Foundation
import OGameCore

public struct JSONSaveRepository: Sendable {
    public enum RepositoryError: Error, Equatable, Sendable {
        case missingSave
        case unsupportedSchema(Int)
        case invalidFileName(String)
    }

    public struct SaveSlot: Equatable, Identifiable, Sendable {
        public var id: String { name }

        public var name: String
        public var isAutosave: Bool
        public var lastModifiedAt: Date?
        public var byteCount: Int64

        public init(name: String, isAutosave: Bool, lastModifiedAt: Date?, byteCount: Int64) {
            self.name = name
            self.isAutosave = isAutosave
            self.lastModifiedAt = lastModifiedAt
            self.byteCount = byteCount
        }
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

    public func save(
        _ universe: Universe,
        wallClockDate: Date = Date(),
        settings: GameSettings = GameSettings()
    ) throws {
        let saveURL = try validatedSaveURL(fileName)
        try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)

        let envelope = SaveEnvelope(lastSavedAt: wallClockDate, universe: universe, settings: settings)
        let data = try Self.makeEncoder().encode(envelope)
        try data.write(to: saveURL, options: [.atomic])
    }

    public func load() throws -> SaveEnvelope {
        try loadSlot(named: fileName)
    }

    public func saveSlot(
        named slotName: String,
        universe: Universe,
        wallClockDate: Date = Date(),
        settings: GameSettings = GameSettings()
    ) throws {
        let saveURL = try validatedSaveURL(slotName)
        try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)

        let envelope = SaveEnvelope(lastSavedAt: wallClockDate, universe: universe, settings: settings)
        let data = try Self.makeEncoder().encode(envelope)
        try data.write(to: saveURL, options: [.atomic])
    }

    public func loadSlot(named slotName: String) throws -> SaveEnvelope {
        let saveURL = try validatedSaveURL(slotName)
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            throw RepositoryError.missingSave
        }

        let data = try Data(contentsOf: saveURL)

        return try SaveMigrator.migrate(data)
    }

    public func listSaveSlots() throws -> [SaveSlot] {
        guard Self.isValidFileName(fileName) else {
            throw RepositoryError.invalidFileName(fileName)
        }

        guard FileManager.default.fileExists(atPath: saveDirectory.path) else {
            return []
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: saveDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return try fileURLs.compactMap { url in
            let resourceValues = try url.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .isRegularFileKey
            ])
            let name = url.lastPathComponent
            guard
                resourceValues.isRegularFile == true,
                name.hasSuffix(".json"),
                Self.isListableSaveSlotName(name)
            else {
                return nil
            }

            return SaveSlot(
                name: name,
                isAutosave: name == Self.autosaveSlotName,
                lastModifiedAt: resourceValues.contentModificationDate,
                byteCount: Int64(resourceValues.fileSize ?? 0)
            )
        }
        .sorted { lhs, rhs in
            if lhs.isAutosave != rhs.isAutosave {
                return lhs.isAutosave
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public func createBackup(wallClockDate: Date = Date()) throws -> SaveSlot {
        let autosaveURL = try validatedSaveURL(fileName)
        guard FileManager.default.fileExists(atPath: autosaveURL.path) else {
            throw RepositoryError.missingSave
        }

        let backupName = try nextBackupFileName(wallClockDate: wallClockDate)
        let backupURL = try validatedSaveURL(backupName)
        try FileManager.default.copyItem(at: autosaveURL, to: backupURL)
        let attributes = try FileManager.default.attributesOfItem(atPath: backupURL.path)

        return SaveSlot(
            name: backupName,
            isAutosave: false,
            lastModifiedAt: attributes[.modificationDate] as? Date,
            byteCount: attributes[.size] as? Int64 ?? 0
        )
    }

    public func deleteSlot(named slotName: String) throws {
        guard Self.isListableSaveSlotName(slotName) else {
            throw RepositoryError.invalidFileName(slotName)
        }

        let saveURL = try validatedSaveURL(slotName)
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            throw RepositoryError.missingSave
        }

        try FileManager.default.removeItem(at: saveURL)
    }

    public func deleteBackup(named backupName: String) throws {
        guard Self.isBackupFileName(backupName) else {
            throw RepositoryError.invalidFileName(backupName)
        }

        try deleteSlot(named: backupName)
    }

    public func exportCurrentSave(to destinationURL: URL) throws {
        let envelope = try load()
        let data = try Self.makePortableEncoder().encode(envelope)
        let parent = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try data.write(to: destinationURL, options: [.atomic])
    }

    public func importSave(from sourceURL: URL, as slotName: String? = nil) throws {
        let resolvedSlotName = slotName ?? fileName
        let saveURL = try validatedSaveURL(resolvedSlotName)
        let data = try Data(contentsOf: sourceURL)
        let envelope = try SaveMigrator.migrate(data)
        let portableData = try Self.makePortableEncoder().encode(envelope)

        try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
        try portableData.write(to: saveURL, options: [.atomic])
    }

    public func validateBackup(named backupName: String) throws -> SaveSlot {
        guard Self.isBackupFileName(backupName) else {
            throw RepositoryError.invalidFileName(backupName)
        }

        _ = try loadSlot(named: backupName)
        let backupURL = try validatedSaveURL(backupName)
        let attributes = try FileManager.default.attributesOfItem(atPath: backupURL.path)
        return SaveSlot(
            name: backupName,
            isAutosave: false,
            lastModifiedAt: attributes[.modificationDate] as? Date,
            byteCount: attributes[.size] as? Int64 ?? 0
        )
    }

    private func validatedSaveURL(_ slotName: String) throws -> URL {
        guard Self.isValidFileName(slotName) else {
            throw RepositoryError.invalidFileName(slotName)
        }

        return saveDirectory.appendingPathComponent(slotName, isDirectory: false)
    }

    private func nextBackupFileName(wallClockDate: Date) throws -> String {
        let baseName = "backup-\(Self.backupDateStamp(for: wallClockDate))"
        var candidate = "\(baseName).json"
        var suffix = 2

        while FileManager.default.fileExists(atPath: try validatedSaveURL(candidate).path) {
            candidate = "\(baseName)-\(suffix).json"
            suffix += 1
        }

        return candidate
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

    private static func isListableSaveSlotName(_ fileName: String) -> Bool {
        guard isValidFileName(fileName) else {
            return false
        }

        return fileName == autosaveSlotName || isBackupFileName(fileName)
    }

    private static func isBackupFileName(_ fileName: String) -> Bool {
        isValidFileName(fileName) && fileName.hasPrefix("backup-") && fileName.hasSuffix(".json")
    }

    private static let autosaveSlotName = "autosave.json"

    public static func makePortableEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makePortableDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        makePortableEncoder()
    }

    private static func backupDateStamp(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d%02d%02d-%02d%02d%02d",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }
}
