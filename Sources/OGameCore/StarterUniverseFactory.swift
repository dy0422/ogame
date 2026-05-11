import Foundation

public enum StarterUniverseFactory {
    public static func makeNewGame(seed: UInt64, playerName: String) -> Universe {
        var generator = SeededGenerator(seed: seed)

        let playerID = stableFactionID(index: 0)
        let playerHomeID = stablePlanetID(index: 0)
        let playerHomeCoordinate = Coordinate(galaxy: 1, system: 1, position: 4)
        let playerHomeProfile = UniverseTopologyEngine.planetProfile(
            for: playerHomeCoordinate,
            universeSeed: seed
        )
        let playerHome = Planet(
            id: playerHomeID,
            name: "Homeworld",
            coordinate: playerHomeCoordinate,
            ownerID: playerID,
            resources: startingResources,
            storage: startingStorage,
            temperatureCelsius: playerHomeProfile.temperatureCelsius,
            energy: startingEnergy,
            buildingLevels: startingBuildingLevels,
            maxFields: playerHomeProfile.maxFields
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
            let coordinate = Coordinate(
                galaxy: 1,
                system: index + 1,
                position: generator.nextInt(in: 4...12)
            )
            let profile = UniverseTopologyEngine.planetProfile(for: coordinate, universeSeed: seed)
            planets.append(
                Planet(
                    id: planetID,
                    name: "\(strategy.rawValue.capitalized) Prime",
                    coordinate: coordinate,
                    ownerID: factionID,
                    resources: startingResources,
                    storage: startingStorage,
                    temperatureCelsius: profile.temperatureCelsius,
                    energy: startingEnergy,
                    buildingLevels: startingBuildingLevels,
                    maxFields: profile.maxFields
                )
            )
        }

        let neutralCoordinates = UniverseTopologyEngine.regionalColonyCoordinates(
            around: playerHomeCoordinate,
            occupied: Set(planets.map(\.coordinate)),
            limit: 30
        )
        for (offset, coordinate) in neutralCoordinates.enumerated() {
            let profile = UniverseTopologyEngine.planetProfile(for: coordinate, universeSeed: seed)
            planets.append(
                Planet(
                    id: stablePlanetID(index: 6 + offset),
                    name: "未占领 \(offset + 1)",
                    coordinate: coordinate,
                    ownerID: nil,
                    resources: ResourceBundle(metal: 100 + Double(offset * 50), crystal: 50, deuterium: 20),
                    storage: startingStorage,
                    temperatureCelsius: profile.temperatureCelsius,
                    debrisField: ResourceBundle(metal: 25 + Double(offset * 10), crystal: 10),
                    maxFields: profile.maxFields
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

    private static let startingResources = ResourceBundle(metal: 2_000, crystal: 2_000, deuterium: 500)
    private static let startingStorage = ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000)
    private static let startingEnergy = EnergyState(produced: 22, used: 22)
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
