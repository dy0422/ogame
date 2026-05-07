import Foundation
import OGameCore

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

func requireIdentifiable<Entity: Identifiable, ID: Equatable>(_ entity: Entity, id expected: ID, _ message: String) where Entity.ID == ID {
    requireEqual(entity.id, expected, message)
}

func requireDictionary(_ value: Any?, _ message: String) -> [String: Any] {
    guard let dictionary = value as? [String: Any] else {
        fatalError(message)
    }

    return dictionary
}

func requireArray(_ value: Any?, _ message: String) -> [Any] {
    guard let array = value as? [Any] else {
        fatalError(message)
    }

    return array
}

func requireInt(_ value: Any?, _ expected: Int, _ message: String) {
    guard let number = value as? NSNumber, number.intValue == expected else {
        fatalError(message)
    }
}

func requireThrowsDecodingError(_ message: String, _ operation: () throws -> Void) {
    do {
        try operation()
        fatalError(message)
    } catch is DecodingError {
    } catch {
        fatalError("\(message): \(error)")
    }
}

func testEntityIDsAreCodableAndEquatable() throws {
    let id = FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    let data = try JSONEncoder().encode(id)
    let decoded = try JSONDecoder().decode(FactionID.self, from: data)

    requireEqual(decoded, id, "FactionID should round-trip through JSON")
}

func testResourceBundleClampsToStorageLimits() {
    let resources = ResourceBundle(metal: 120, crystal: 80, deuterium: 40)
    let storage = ResourceStorage(metal: 100, crystal: 100, deuterium: 20)

    requireEqual(
        resources.clamped(to: storage),
        ResourceBundle(metal: 100, crystal: 80, deuterium: 20),
        "ResourceBundle should clamp to storage limits"
    )
}

func testResourceBundleDoesNotClampBelowZeroWhenStorageIsInvalid() {
    let resources = ResourceBundle(metal: -5, crystal: 5, deuterium: 40)
    let storage = ResourceStorage(metal: -1, crystal: -10, deuterium: 20)

    requireEqual(
        resources.clamped(to: storage),
        ResourceBundle(metal: 0, crystal: 0, deuterium: 20),
        "ResourceBundle should never clamp below zero"
    )
}

func testUniverseModelRoundTripsThroughJSON() throws {
    let player = FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000010")!)
    let homeworld = PlanetID(UUID(uuidString: "00000000-0000-0000-0000-000000000020")!)
    let fleetID = FleetID(UUID(uuidString: "00000000-0000-0000-0000-000000000040")!)
    let eventID = EventID(UUID(uuidString: "00000000-0000-0000-0000-000000000050")!)
    let universe = Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000030")!),
        name: "Test Universe",
        seed: 42,
        gameTime: 120,
        playerFactionID: player,
        factions: [
            Faction(
                id: player,
                name: "Player",
                kind: .player,
                strategy: .balanced,
                technology: ResearchState(levels: [.computer: 2, .weapons: 3]),
                ownedPlanetIDs: [homeworld]
            )
        ],
        planets: [
            Planet(
                id: homeworld,
                name: "Homeworld",
                coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
                ownerID: player,
                resources: ResourceBundle(metal: 500, crystal: 500, deuterium: 100),
                storage: ResourceStorage(metal: 10_000, crystal: 10_000, deuterium: 10_000),
                energy: EnergyState(produced: 20, used: 10),
                buildingLevels: [.metalMine: 12, .solarPlant: 10],
                shipInventory: [.smallCargo: 4, .lightFighter: 6],
                defenseInventory: [.rocketLauncher: 8, .lightLaser: 3]
            )
        ],
        fleets: [
            Fleet(
                id: fleetID,
                ownerID: player,
                mission: .transport,
                origin: Coordinate(galaxy: 1, system: 1, position: 4),
                target: Coordinate(galaxy: 1, system: 2, position: 8),
                ships: [.smallCargo: 2, .espionageProbe: 1],
                cargo: ResourceBundle(metal: 150, crystal: 75, deuterium: 25),
                launchTime: 120,
                arrivalTime: 180,
                returnTime: 240
            )
        ],
        events: [
            GameEvent(
                id: eventID,
                time: 121,
                kind: .system,
                title: "Command Online",
                message: "The first command loop is running."
            )
        ],
        ruleSet: RuleSet.fastSkirmish
    )

    let data = try JSONEncoder().encode(universe)
    let decoded = try JSONDecoder().decode(Universe.self, from: data)

    requireIdentifiable(universe, id: universe.id, "Universe should be Identifiable by its id")
    requireIdentifiable(universe.factions[0], id: player, "Faction should be Identifiable by its id")
    requireIdentifiable(universe.planets[0], id: homeworld, "Planet should be Identifiable by its id")
    requireIdentifiable(universe.fleets[0], id: fleetID, "Fleet should be Identifiable by its id")
    requireEqual(decoded, universe, "Universe should round-trip through JSON")

    let json = requireDictionary(try JSONSerialization.jsonObject(with: data), "Universe should encode as a JSON object")
    let factionsJSON = requireArray(json["factions"], "Factions should encode as a JSON array")
    let factionJSON = requireDictionary(factionsJSON.first, "Faction should encode as a JSON object")
    let technologyJSON = requireDictionary(factionJSON["technology"], "Research state should encode as a JSON object")
    let researchLevelsJSON = requireDictionary(technologyJSON["levels"], "Research levels should encode as raw-value keyed JSON object")
    requireEqual(Array(researchLevelsJSON.keys).sorted(), ["computer", "weapons"], "Research level keys should be technology raw values")
    requireInt(researchLevelsJSON["computer"], 2, "Computer research level should encode by raw value")

    let planetsJSON = requireArray(json["planets"], "Planets should encode as a JSON array")
    let planetJSON = requireDictionary(planetsJSON.first, "Planet should encode as a JSON object")
    let buildingLevelsJSON = requireDictionary(planetJSON["buildingLevels"], "Building levels should encode as raw-value keyed JSON object")
    let shipInventoryJSON = requireDictionary(planetJSON["shipInventory"], "Ship inventory should encode as raw-value keyed JSON object")
    let defenseInventoryJSON = requireDictionary(planetJSON["defenseInventory"], "Defense inventory should encode as raw-value keyed JSON object")
    requireEqual(Array(buildingLevelsJSON.keys).sorted(), ["metalMine", "solarPlant"], "Building level keys should be building raw values")
    requireEqual(Array(shipInventoryJSON.keys).sorted(), ["lightFighter", "smallCargo"], "Ship inventory keys should be ship raw values")
    requireEqual(Array(defenseInventoryJSON.keys).sorted(), ["lightLaser", "rocketLauncher"], "Defense inventory keys should be defense raw values")
    requireInt(buildingLevelsJSON["metalMine"], 12, "Metal mine level should encode by raw value")
    requireInt(shipInventoryJSON["smallCargo"], 4, "Small cargo inventory should encode by raw value")
    requireInt(defenseInventoryJSON["rocketLauncher"], 8, "Rocket launcher inventory should encode by raw value")

    let fleetsJSON = requireArray(json["fleets"], "Fleets should encode as a JSON array")
    let fleetJSON = requireDictionary(fleetsJSON.first, "Fleet should encode as a JSON object")
    let fleetShipsJSON = requireDictionary(fleetJSON["ships"], "Fleet ships should encode as raw-value keyed JSON object")
    requireEqual(Array(fleetShipsJSON.keys).sorted(), ["espionageProbe", "smallCargo"], "Fleet ship keys should be ship raw values")
    requireInt(fleetShipsJSON["espionageProbe"], 1, "Espionage probe count should encode by raw value")
}

func testPlanetEnumDictionaryDecodesRawValueKeysAndRejectsUnknownKeys() throws {
    let planetJSON = """
    {
      "id": { "rawValue": "00000000-0000-0000-0000-000000000060" },
      "name": "Raw Object Planet",
      "coordinate": { "galaxy": 2, "system": 3, "position": 4 },
      "ownerID": null,
      "resources": { "metal": 1, "crystal": 2, "deuterium": 3 },
      "storage": { "metal": 100, "crystal": 100, "deuterium": 100 },
      "energy": { "produced": 10, "used": 4 },
      "buildingLevels": { "metalMine": 5 },
      "shipInventory": { "smallCargo": 2 },
      "defenseInventory": { "rocketLauncher": 7 }
    }
    """

    let planet = try JSONDecoder().decode(Planet.self, from: Data(planetJSON.utf8))

    requireEqual(planet.buildingLevels, [.metalMine: 5], "Planet should decode building levels from raw-value keys")
    requireEqual(planet.shipInventory, [.smallCargo: 2], "Planet should decode ship inventory from raw-value keys")
    requireEqual(planet.defenseInventory, [.rocketLauncher: 7], "Planet should decode defense inventory from raw-value keys")

    let unknownBuildingJSON = planetJSON.replacingOccurrences(of: "\"metalMine\"", with: "\"unknownBuilding\"")
    requireThrowsDecodingError("Unknown building keys should fail decoding") {
        _ = try JSONDecoder().decode(Planet.self, from: Data(unknownBuildingJSON.utf8))
    }
}

func testSeededGeneratorProducesDeterministicDistinctSequences() {
    var first = SeededGenerator(seed: 0)
    var second = SeededGenerator(seed: 0)
    var different = SeededGenerator(seed: 0xA0761D6478BD642F)

    let firstSequence = (0..<8).map { _ in first.next() }
    let secondSequence = (0..<8).map { _ in second.next() }
    let differentSequence = (0..<8).map { _ in different.next() }

    requireEqual(firstSequence, secondSequence, "Same seed should produce the same generator sequence")
    require(firstSequence != differentSequence, "Different seeds should produce different generator sequences")
}

func testSeededGeneratorNextIntRespectsClosedRanges() {
    var generator = SeededGenerator(seed: 42)

    requireEqual(generator.nextInt(in: 9...9), 9, "Single-value closed range should always return its only value")

    let values = (0..<32).map { _ in generator.nextInt(in: 4...12) }
    require(values.allSatisfy { (4...12).contains($0) }, "Generated integers should stay inside the requested closed range")
    require(values.contains { $0 != 4 }, "Normal closed range should not collapse to the lower bound")
}

func testStarterUniverseIsDeterministicForSeed() throws {
    let first: Universe = StarterUniverseFactory.makeNewGame(seed: 7, playerName: "Commander")
    let second: Universe = StarterUniverseFactory.makeNewGame(seed: 7, playerName: "Commander")
    let differentSeed: Universe = StarterUniverseFactory.makeNewGame(seed: 8, playerName: "Commander")

    requireEqual(first.seed, 7, "Starter universe seed should be preserved")
    requireEqual(first, second, "Starter universe should be deterministic for a seed and player name")
    require(first != differentSeed, "Starter universe should vary generated state for different seeds")
    requireEqual(first.id, UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000200")!), "Starter universe should use a stable id")
    requireEqual(first.name, "Fast Skirmish", "Starter universe should use the fast skirmish universe name")
    requireEqual(first.ruleSet, RuleSet.fastSkirmish, "Starter universe should use fast skirmish rules")
    requireEqual(first.gameTime, 0, "Starter universe should start at game time zero")
    requireEqual(first.fleets, [], "Starter universe should begin without fleets")

    requireEqual(first.factions.count, 6, "Starter universe should create six factions")
    requireEqual(first.planets.count, 6, "Starter universe should create six planets")
    requireEqual(first.playerFactionID, FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!), "Player faction should use a stable id")
    requireEqual(Set(first.factions.map(\.id)).count, first.factions.count, "Starter universe faction IDs should be unique")
    requireEqual(Set(first.planets.map(\.id)).count, first.planets.count, "Starter universe planet IDs should be unique")

    let playerFaction = first.factions[0]
    let homeworld = first.planets[0]
    requireEqual(playerFaction.id, first.playerFactionID, "First starter faction should be the player")
    requireEqual(playerFaction.name, "Commander", "Player faction name should come from the requested player name")
    requireEqual(playerFaction.kind, Faction.Kind.player, "Player faction should be marked as player-controlled")
    requireEqual(playerFaction.strategy, Faction.Strategy.balanced, "Player faction should use the balanced strategy")
    requireEqual(playerFaction.ownedPlanetIDs, [homeworld.id], "Player faction should own the homeworld")
    requireEqual(homeworld.id, PlanetID(UUID(uuidString: "00000000-0000-0000-0001-000000000001")!), "Homeworld should use a stable id")
    requireEqual(homeworld.name, "Homeworld", "Player planet should be named Homeworld")
    requireEqual(homeworld.coordinate, Coordinate(galaxy: 1, system: 1, position: 4), "Homeworld should use the canonical starter coordinate")
    requireEqual(homeworld.ownerID, playerFaction.id, "Homeworld should be owned by the player")

    let aiFactions = Array(first.factions.dropFirst())
    let aiPlanets = Array(first.planets.dropFirst())
    let planetsByID = Dictionary(uniqueKeysWithValues: first.planets.map { ($0.id, $0) })
    require(aiFactions.allSatisfy { $0.kind == Faction.Kind.ai }, "Rival factions should all be AI-controlled")
    requireEqual(aiFactions.map(\.strategy), [Faction.Strategy.miner, .raider, .technologist, .expansionist, .balanced], "Rival factions should use the planned strategies")
    requireEqual(aiFactions.map(\.ownedPlanetIDs), aiPlanets.map { [$0.id] }, "Each rival should own its matching starter planet")
    for faction in first.factions {
        for planetID in faction.ownedPlanetIDs {
            guard let planet = planetsByID[planetID] else {
                fatalError("Faction \(faction.id) should only reference existing starter planets")
            }

            requireEqual(planet.ownerID, faction.id, "Owned starter planet should point back to its faction owner")
        }
    }
    require(aiPlanets.allSatisfy { (4...12).contains($0.coordinate.position) }, "Rival planet positions should be generated inside the starter range")
    requireEqual(
        aiPlanets.map(\.coordinate.galaxy),
        Array(repeating: 1, count: 5),
        "Rival planets should start in galaxy one"
    )
    requireEqual(
        aiPlanets.map(\.coordinate.system),
        [2, 3, 4, 5, 6],
        "Rival planets should start in stable adjacent systems"
    )
    require(
        first.planets.map(\.coordinate) != differentSeed.planets.map(\.coordinate),
        "Different seeds should produce meaningfully different generated coordinates"
    )

    requireEqual(first.events.count, 1, "Starter universe should create one welcome event")
    requireEqual(first.events.first?.title, "Command Link Established", "Starter universe should record initial event")
    requireEqual(first.events.first?.kind, .system, "Welcome event should be a system event")
    requireEqual(first.events.first?.time, 0, "Welcome event should occur at game time zero")

    let data = try JSONEncoder().encode(first)
    let decoded = try JSONDecoder().decode(Universe.self, from: data)
    requireEqual(decoded, first, "Starter universe should preserve stable enum-map JSON behavior")
}

try testEntityIDsAreCodableAndEquatable()
testResourceBundleClampsToStorageLimits()
testResourceBundleDoesNotClampBelowZeroWhenStorageIsInvalid()
try testUniverseModelRoundTripsThroughJSON()
try testPlanetEnumDictionaryDecodesRawValueKeysAndRejectsUnknownKeys()
testSeededGeneratorProducesDeterministicDistinctSequences()
testSeededGeneratorNextIntRespectsClosedRanges()
try testStarterUniverseIsDeterministicForSeed()
print("OGameCoreTests passed")
