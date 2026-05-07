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

try testEntityIDsAreCodableAndEquatable()
testResourceBundleClampsToStorageLimits()
testResourceBundleDoesNotClampBelowZeroWhenStorageIsInvalid()
try testUniverseModelRoundTripsThroughJSON()
try testPlanetEnumDictionaryDecodesRawValueKeysAndRejectsUnknownKeys()
print("OGameCoreTests passed")
