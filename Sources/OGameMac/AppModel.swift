import Foundation
import OGameCore
import OGamePersistence

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var universe: Universe
    @Published var statusMessage: String
    @Published private(set) var canSave: Bool

    private let repository: JSONSaveRepository

    init(repository: JSONSaveRepository? = nil) {
        let resolvedRepository: JSONSaveRepository
        if let repository {
            resolvedRepository = repository
        } else {
            resolvedRepository = (try? JSONSaveRepository.defaultRepository())
                ?? JSONSaveRepository(
                    saveDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(
                        "NativeOGame",
                        isDirectory: true
                    )
                )
        }

        self.repository = resolvedRepository

        do {
            let envelope = try resolvedRepository.load()
            universe = envelope.universe
            statusMessage = "Loaded save from \(envelope.lastSavedAt.formatted(date: .abbreviated, time: .shortened))."
            canSave = true
        } catch JSONSaveRepository.RepositoryError.missingSave {
            universe = StarterUniverseFactory.makeNewGame(seed: 1, playerName: "Commander")
            statusMessage = "New fast skirmish initialized."
            canSave = true
        } catch {
            universe = StarterUniverseFactory.makeNewGame(seed: 1, playerName: "Commander")
            statusMessage = Self.loadFailureStatus(for: error)
            canSave = false
        }
    }

    var playerFaction: Faction? {
        universe.factions.first { faction in
            faction.id == universe.playerFactionID
        }
    }

    var playerPlanets: [Planet] {
        guard let playerFaction else {
            return []
        }

        return universe.planets.filter { planet in
            playerFaction.ownedPlanetIDs.contains(planet.id)
        }
    }

    func advanceOneMinute() {
        guard canSave else {
            statusMessage = "Loading autosave failed. Start a new game before advancing or saving."
            return
        }

        SimulationEngine.tick(universe: &universe, delta: 60)
        statusMessage = "Advanced to T+\(Self.formattedWholeSeconds(universe.gameTime))."
    }

    func save() {
        guard canSave else {
            statusMessage = "Save is disabled because autosave loading failed. Start a new game before saving."
            return
        }

        do {
            try repository.save(universe)
            statusMessage = "Saved universe."
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func startNewGame() {
        universe = StarterUniverseFactory.makeNewGame(seed: 1, playerName: "Commander")
        canSave = true
        statusMessage = "New game started. Saving will replace the current autosave."
    }

    private static func loadFailureStatus(for error: Error) -> String {
        "Loading autosave failed: \(loadFailureDescription(for: error)). Saving is disabled to protect the existing file."
    }

    private static func loadFailureDescription(for error: Error) -> String {
        if case JSONSaveRepository.RepositoryError.unsupportedSchema(let schemaVersion) = error {
            return "unsupported save schema \(schemaVersion)"
        }

        if case JSONSaveRepository.RepositoryError.invalidFileName(let fileName) = error {
            return "invalid save file name '\(fileName)'"
        }

        return error.localizedDescription
    }

    private static func formattedWholeSeconds(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else {
            return "unknown time"
        }

        return seconds.formatted(.number.precision(.fractionLength(0))) + " seconds"
    }
}
