import Foundation

public enum StarterUniverseFactory {
    public static func makeNewGame(seed: UInt64, playerName: String) -> Universe {
        var generator = SeededGenerator(seed: seed)

        let playerID = stableFactionID(index: 0)
        let playerHomeID = stablePlanetID(index: 0)
        let playerHome = Planet(
            id: playerHomeID,
            name: "Homeworld",
            coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
            ownerID: playerID,
            resources: startingResources,
            storage: startingStorage,
            energy: startingEnergy,
            buildingLevels: startingBuildingLevels
        )

        let aiStrategies: [Faction.Strategy] = [.miner, .raider, .technologist, .expansionist, .balanced]
        var factions: [Faction] = [
            Faction(
                id: playerID,
                name: playerName,
                kind: .player,
                strategy: .balanced,
                technology: ResearchState(),
                ownedPlanetIDs: [playerHomeID]
            )
        ]
        var planets: [Planet] = [playerHome]

        for index in 1...5 {
            let factionID = stableFactionID(index: index)
            let planetID = stablePlanetID(index: index)
            let strategy = aiStrategies[index - 1]

            factions.append(
                Faction(
                    id: factionID,
                    name: "AI \(index)",
                    kind: .ai,
                    strategy: strategy,
                    technology: ResearchState(),
                    ownedPlanetIDs: [planetID]
                )
            )
            planets.append(
                Planet(
                    id: planetID,
                    name: "\(strategy.rawValue.capitalized) Prime",
                    coordinate: Coordinate(
                        galaxy: 1,
                        system: index + 1,
                        position: generator.nextInt(in: 4...12)
                    ),
                    ownerID: factionID,
                    resources: startingResources,
                    storage: startingStorage,
                    energy: startingEnergy,
                    buildingLevels: startingBuildingLevels
                )
            )
        }

        let welcome = GameEvent(
            id: EventID(UUID(uuidString: "00000000-0000-0000-0000-000000000100")!),
            time: 0,
            kind: .system,
            title: "Command Link Established",
            message: "Your first colony is online. Rival factions are already moving."
        )

        return Universe(
            id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000200")!),
            name: "Fast Skirmish",
            seed: seed,
            gameTime: 0,
            playerFactionID: playerID,
            factions: factions,
            planets: planets,
            fleets: [],
            events: [welcome],
            ruleSet: .fastSkirmish
        )
    }

    private static let startingResources = ResourceBundle(metal: 500, crystal: 500, deuterium: 100)
    private static let startingStorage = ResourceStorage(metal: 10_000, crystal: 10_000, deuterium: 10_000)
    private static let startingEnergy = EnergyState(produced: 20, used: 8)
    private static let startingBuildingLevels: [BuildingKind: Int] = [
        .crystalMine: 1,
        .metalMine: 1,
        .solarPlant: 1
    ]

    private static func stableFactionID(index: Int) -> FactionID {
        FactionID(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!)
    }

    private static func stablePlanetID(index: Int) -> PlanetID {
        PlanetID(UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", index + 1))!)
    }
}
