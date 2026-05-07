import Foundation
import OGameCore
import OGamePersistence

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var universe: Universe
    @Published var statusMessage: String

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

        if let envelope = try? resolvedRepository.load() {
            universe = envelope.universe
            statusMessage = "Loaded save from \(envelope.lastSavedAt.formatted(date: .abbreviated, time: .shortened))."
        } else {
            universe = StarterUniverseFactory.makeNewGame(seed: 1, playerName: "Commander")
            statusMessage = "New fast skirmish initialized."
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
        SimulationEngine.tick(universe: &universe, delta: 60)
        statusMessage = "Advanced to T+\(Self.formattedWholeSeconds(universe.gameTime))."
    }

    func save() {
        do {
            try repository.save(universe)
            statusMessage = "Saved universe."
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private static func formattedWholeSeconds(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else {
            return "unknown time"
        }

        return seconds.formatted(.number.precision(.fractionLength(0))) + " seconds"
    }
}
