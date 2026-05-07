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
    let universe = Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000030")!),
        name: "Test Universe",
        seed: 42,
        gameTime: 120,
        playerFactionID: player,
        factions: [
            Faction(id: player, name: "Player", kind: .player, strategy: .balanced, technology: ResearchState(), ownedPlanetIDs: [homeworld])
        ],
        planets: [
            Planet(
                id: homeworld,
                name: "Homeworld",
                coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
                ownerID: player,
                resources: ResourceBundle(metal: 500, crystal: 500, deuterium: 100),
                storage: ResourceStorage(metal: 10_000, crystal: 10_000, deuterium: 10_000),
                energy: EnergyState(produced: 20, used: 10)
            )
        ],
        fleets: [],
        events: [],
        ruleSet: RuleSet.fastSkirmish
    )

    let data = try JSONEncoder().encode(universe)
    let decoded = try JSONDecoder().decode(Universe.self, from: data)

    requireEqual(decoded.name, "Test Universe", "Universe name should round-trip")
    requireEqual(decoded.planets.first?.coordinate, Coordinate(galaxy: 1, system: 1, position: 4), "Homeworld coordinate should round-trip")
    requireEqual(decoded.ruleSet.id, "fast-skirmish-v1", "Rule set should round-trip")
}

try testEntityIDsAreCodableAndEquatable()
testResourceBundleClampsToStorageLimits()
testResourceBundleDoesNotClampBelowZeroWhenStorageIsInvalid()
try testUniverseModelRoundTripsThroughJSON()
print("OGameCoreTests passed")
