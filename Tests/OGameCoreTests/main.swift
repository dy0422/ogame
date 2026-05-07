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

func requireApproxEqual(_ actual: Double, _ expected: Double, _ message: String, accuracy: Double = 0.000_001) {
    if abs(actual - expected) > accuracy {
        fatalError("\(message): \(actual) != \(expected)")
    }
}

func requireApproxEqual(_ actual: ResourceBundle, _ expected: ResourceBundle, _ message: String, accuracy: Double = 0.000_001) {
    requireApproxEqual(actual.metal, expected.metal, "\(message) metal", accuracy: accuracy)
    requireApproxEqual(actual.crystal, expected.crystal, "\(message) crystal", accuracy: accuracy)
    requireApproxEqual(actual.deuterium, expected.deuterium, "\(message) deuterium", accuracy: accuracy)
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

func testResourceBundleArithmeticAndAffordabilityHelpers() {
    let stockpile = ResourceBundle(metal: 120, crystal: 80, deuterium: 40)
    let cost = ResourceBundle(metal: 100, crystal: 25, deuterium: 50)

    requireEqual(
        stockpile.adding(cost),
        ResourceBundle(metal: 220, crystal: 105, deuterium: 90),
        "ResourceBundle addition should add each resource lane"
    )
    requireEqual(
        stockpile.subtracting(cost),
        ResourceBundle(metal: 20, crystal: 55, deuterium: -10),
        "ResourceBundle subtraction should preserve finite negative resource lanes"
    )
    requireEqual(
        cost.scaled(by: 1.5),
        ResourceBundle(metal: 150, crystal: 37.5, deuterium: 75),
        "ResourceBundle scalar multiplication should scale each resource lane"
    )
    requireEqual(
        stockpile.subtracting(cost).nonnegative,
        ResourceBundle(metal: 20, crystal: 55, deuterium: 0),
        "ResourceBundle nonnegative should clamp only negative lanes"
    )
    require(!stockpile.canAfford(cost), "ResourceBundle affordability should fail when any lane is short")
    require(
        stockpile.canAfford(ResourceBundle(metal: 100, crystal: 25, deuterium: 30)),
        "ResourceBundle affordability should pass when every lane covers the cost"
    )
}

func testResourceStorageConvertsToResourceDisplayBundle() {
    let storage = ResourceStorage(metal: 10_000, crystal: 8_000, deuterium: 6_000)

    requireEqual(
        storage.asResourceBundle,
        ResourceBundle(metal: 10_000, crystal: 8_000, deuterium: 6_000),
        "ResourceStorage display conversion should preserve storage lanes as resources"
    )
}

func testFastSkirmishBuildingRulesCoverEarlyEconomy() {
    let rules = RuleSet.fastSkirmish.buildingRules

    for building in BuildingKind.allCases {
        require(rules[building] != nil, "Fast skirmish should define a rule for \(building.rawValue)")
    }

    require(
        rules[.metalMine]?.productionPerHour.metal ?? 0 > 0,
        "Fast skirmish metal mine should produce metal"
    )
    require(
        rules[.crystalMine]?.productionPerHour.crystal ?? 0 > 0,
        "Fast skirmish crystal mine should produce crystal"
    )
    require(
        rules[.deuteriumSynthesizer]?.productionPerHour.deuterium ?? 0 > 0,
        "Fast skirmish deuterium synthesizer should produce deuterium"
    )
    require(
        rules[.solarPlant]?.energyProduced ?? 0 > 0,
        "Fast skirmish solar plant should produce energy"
    )
    require(
        (rules[.metalMine]?.energyUsed ?? 0) > 0 &&
            (rules[.crystalMine]?.energyUsed ?? 0) > 0 &&
            (rules[.deuteriumSynthesizer]?.energyUsed ?? 0) > 0,
        "Fast skirmish mines should consume energy"
    )
    require(
        (rules[.roboticsFactory]?.baseCost.metal ?? 0) > 0 &&
            (rules[.shipyard]?.baseDuration ?? 0) > 0 &&
            (rules[.researchLab]?.aiPriorityWeight ?? 0) > 0,
        "Fast skirmish should include useful support building costs, durations, and AI weights"
    )
}

func testFastSkirmishResearchRulesCoverEarlyTechnologies() {
    let rules = RuleSet.fastSkirmish.researchRules
    let earlyTechnologies: [TechnologyKind] = [.energy, .computer, .espionage, .weapons, .shielding, .armor]

    for technology in earlyTechnologies {
        guard let rule = rules[technology] else {
            fatalError("Fast skirmish should define a research rule for \(technology.rawValue)")
        }

        require(rule.baseCost != .zero, "Research \(technology.rawValue) should have a nonzero cost")
        require(rule.baseDuration > 0, "Research \(technology.rawValue) should have a positive duration")
        require(rule.aiPriorityWeight > 0, "Research \(technology.rawValue) should have a positive AI weight")
    }
}

func testFastSkirmishUnitRulesCoverShipsAndDefenses() {
    let shipRules = RuleSet.fastSkirmish.shipRules
    let defenseRules = RuleSet.fastSkirmish.defenseRules

    for ship in ShipKind.allCases {
        guard let rule = shipRules[ship] else {
            fatalError("Fast skirmish should define a ship rule for \(ship.rawValue)")
        }

        require(rule.baseCost != .zero, "Ship \(ship.rawValue) should have a nonzero cost")
        require(rule.baseDuration > 0, "Ship \(ship.rawValue) should have a positive duration")
        require(rule.aiPriorityWeight > 0, "Ship \(ship.rawValue) should have a positive AI weight")
    }

    for defense in DefenseKind.allCases {
        guard let rule = defenseRules[defense] else {
            fatalError("Fast skirmish should define a defense rule for \(defense.rawValue)")
        }

        require(rule.baseCost != .zero, "Defense \(defense.rawValue) should have a nonzero cost")
        require(rule.baseDuration > 0, "Defense \(defense.rawValue) should have a positive duration")
        require(rule.aiPriorityWeight > 0, "Defense \(defense.rawValue) should have a positive AI weight")
    }
}

func testRuleSetBalanceRulesUseRawValueKeyedJSONObjects() throws {
    let data = try JSONEncoder().encode(RuleSet.fastSkirmish)
    let json = requireDictionary(try JSONSerialization.jsonObject(with: data), "RuleSet should encode as a JSON object")
    let buildingRulesJSON = requireDictionary(json["buildingRules"], "Building rules should encode as a JSON object")
    let researchRulesJSON = requireDictionary(json["researchRules"], "Research rules should encode as a JSON object")
    let shipRulesJSON = requireDictionary(json["shipRules"], "Ship rules should encode as a JSON object")
    let defenseRulesJSON = requireDictionary(json["defenseRules"], "Defense rules should encode as a JSON object")

    require(
        buildingRulesJSON.keys.contains("metalMine") &&
            buildingRulesJSON.keys.contains("solarPlant") &&
            buildingRulesJSON.keys.contains("researchLab"),
        "Building rule keys should be building raw values"
    )
    require(
        researchRulesJSON.keys.contains("energy") &&
            researchRulesJSON.keys.contains("computer") &&
            researchRulesJSON.keys.contains("armor"),
        "Research rule keys should be technology raw values"
    )
    require(
        shipRulesJSON.keys.contains("smallCargo") &&
            shipRulesJSON.keys.contains("lightFighter") &&
            shipRulesJSON.keys.contains("espionageProbe"),
        "Ship rule keys should be ship raw values"
    )
    require(
        defenseRulesJSON.keys.contains("rocketLauncher") &&
            defenseRulesJSON.keys.contains("lightLaser") &&
            defenseRulesJSON.keys.contains("plasmaTurret"),
        "Defense rule keys should be defense raw values"
    )
    require(
        buildingRulesJSON["metalMine"] is [String: Any],
        "Building rules should encode values under raw-value keys, not alternating arrays"
    )
    require(
        researchRulesJSON["energy"] is [String: Any],
        "Research rules should encode values under raw-value keys, not alternating arrays"
    )
    require(
        shipRulesJSON["smallCargo"] is [String: Any],
        "Ship rules should encode values under raw-value keys, not alternating arrays"
    )
    require(
        defenseRulesJSON["rocketLauncher"] is [String: Any],
        "Defense rules should encode values under raw-value keys, not alternating arrays"
    )
}

func testRuleSetDecodesOlderJSONWithFastSkirmishBalanceDefaults() throws {
    let olderRuleSetJSON = """
    {
      "id": "fast-skirmish-v1",
      "displayName": "Fast Skirmish",
      "baseTickInterval": 1,
      "offlineChunkInterval": 300
    }
    """

    let decoded = try JSONDecoder().decode(RuleSet.self, from: Data(olderRuleSetJSON.utf8))

    requireEqual(
        decoded.buildingRules,
        RuleSet.fastSkirmish.buildingRules,
        "RuleSet should default missing building rules to fast skirmish rules"
    )
    requireEqual(
        decoded.researchRules,
        RuleSet.fastSkirmish.researchRules,
        "RuleSet should default missing research rules to fast skirmish rules"
    )
    requireEqual(
        decoded.shipRules,
        RuleSet.fastSkirmish.shipRules,
        "RuleSet should default missing ship rules to fast skirmish rules"
    )
    requireEqual(
        decoded.defenseRules,
        RuleSet.fastSkirmish.defenseRules,
        "RuleSet should default missing defense rules to fast skirmish rules"
    )
}

func testBuildQueueItemRoundTripsThroughJSON() throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000070")!
    let planetID = PlanetID(UUID(uuidString: "00000000-0000-0000-0000-000000000071")!)
    let item = BuildQueueItem(
        id: id,
        planetID: planetID,
        buildingKind: .metalMine,
        targetLevel: 13,
        startTime: 120,
        finishTime: 360,
        paidCost: ResourceBundle(metal: 1_200, crystal: 400, deuterium: 50)
    )

    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(BuildQueueItem.self, from: data)

    requireIdentifiable(item, id: id, "BuildQueueItem should be Identifiable by its id")
    requireEqual(decoded, item, "BuildQueueItem should round-trip through JSON")

    let json = requireDictionary(try JSONSerialization.jsonObject(with: data), "BuildQueueItem should encode as a JSON object")
    requireEqual(json["buildingKind"] as? String, "metalMine", "Build queue building kind should encode by raw value")
}

func testResearchQueueItemRoundTripsThroughJSON() throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000080")!
    let factionID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000081")!)
    let item = ResearchQueueItem(
        id: id,
        factionID: factionID,
        technologyKind: .computer,
        targetLevel: 4,
        startTime: 480,
        finishTime: 960,
        paidCost: ResourceBundle(metal: 600, crystal: 1_200, deuterium: 200)
    )

    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(ResearchQueueItem.self, from: data)

    requireIdentifiable(item, id: id, "ResearchQueueItem should be Identifiable by its id")
    requireEqual(decoded, item, "ResearchQueueItem should round-trip through JSON")

    let json = requireDictionary(try JSONSerialization.jsonObject(with: data), "ResearchQueueItem should encode as a JSON object")
    requireEqual(json["technologyKind"] as? String, "computer", "Research queue technology kind should encode by raw value")
}

func testUnitBuildQueueItemRoundTripsThroughJSON() throws {
    let shipItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000082")!,
        planetID: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-000000000083")!),
        unitKind: .ship(.smallCargo),
        quantity: 3,
        startTime: 120,
        finishTime: 150,
        paidCost: ResourceBundle(metal: 6_000, crystal: 6_000)
    )
    let defenseItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000084")!,
        planetID: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-000000000083")!),
        unitKind: .defense(.rocketLauncher),
        quantity: 4,
        startTime: 160,
        finishTime: 184,
        paidCost: ResourceBundle(metal: 8_000)
    )

    let shipData = try JSONEncoder().encode(shipItem)
    let defenseData = try JSONEncoder().encode(defenseItem)

    requireEqual(
        try JSONDecoder().decode(UnitBuildQueueItem.self, from: shipData),
        shipItem,
        "Ship unit queue item should round-trip through JSON"
    )
    requireEqual(
        try JSONDecoder().decode(UnitBuildQueueItem.self, from: defenseData),
        defenseItem,
        "Defense unit queue item should round-trip through JSON"
    )

    let shipJSON = requireDictionary(try JSONSerialization.jsonObject(with: shipData), "Ship unit queue item should encode as an object")
    let defenseJSON = requireDictionary(try JSONSerialization.jsonObject(with: defenseData), "Defense unit queue item should encode as an object")
    requireEqual(shipJSON["unitType"] as? String, "ship", "Ship queue unit type should encode by raw value")
    requireEqual(shipJSON["unitKind"] as? String, "smallCargo", "Ship queue unit kind should encode by raw value")
    requireEqual(defenseJSON["unitType"] as? String, "defense", "Defense queue unit type should encode by raw value")
    requireEqual(defenseJSON["unitKind"] as? String, "rocketLauncher", "Defense queue unit kind should encode by raw value")
}

func testPlanetFactionAndUniverseQueuesRoundTripThroughJSON() throws {
    let player = FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000090")!)
    let homeworld = PlanetID(UUID(uuidString: "00000000-0000-0000-0000-000000000091")!)
    let buildQueueItem = BuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000092")!,
        planetID: homeworld,
        buildingKind: .solarPlant,
        targetLevel: 11,
        startTime: 30,
        finishTime: 90,
        paidCost: ResourceBundle(metal: 800, crystal: 300)
    )
    let researchQueueItem = ResearchQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000093")!,
        factionID: player,
        technologyKind: .energy,
        targetLevel: 3,
        startTime: 95,
        finishTime: 250,
        paidCost: ResourceBundle(crystal: 1_000, deuterium: 300)
    )
    let shipQueueItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000095")!,
        planetID: homeworld,
        unitKind: .ship(.lightFighter),
        quantity: 2,
        startTime: 100,
        finishTime: 140,
        paidCost: ResourceBundle(metal: 6_000, crystal: 2_000)
    )
    let defenseQueueItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000096")!,
        planetID: homeworld,
        unitKind: .defense(.lightLaser),
        quantity: 1,
        startTime: 105,
        finishTime: 125,
        paidCost: ResourceBundle(metal: 1_500, crystal: 500)
    )
    let simulatedAt = Date(timeIntervalSince1970: 4_000)
    let universe = Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000094")!),
        name: "Queued Universe",
        seed: 84,
        gameTime: 95,
        lastSimulatedWallClockTime: simulatedAt,
        playerFactionID: player,
        factions: [
            Faction(
                id: player,
                name: "Player",
                kind: .player,
                strategy: .balanced,
                technology: ResearchState(levels: [.energy: 2]),
                ownedPlanetIDs: [homeworld],
                researchQueue: [researchQueueItem]
            )
        ],
        planets: [
            Planet(
                id: homeworld,
                name: "Homeworld",
                coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
                ownerID: player,
                resources: ResourceBundle(metal: 500, crystal: 500, deuterium: 100),
                buildingLevels: [.solarPlant: 10],
                buildQueue: [buildQueueItem],
                shipBuildQueue: [shipQueueItem],
                defenseBuildQueue: [defenseQueueItem]
            )
        ],
        fleets: [],
        events: [],
        ruleSet: RuleSet.fastSkirmish
    )

    let data = try JSONEncoder().encode(universe)
    let decoded = try JSONDecoder().decode(Universe.self, from: data)

    requireEqual(decoded, universe, "Universe should round-trip queued economy metadata through JSON")

    let json = requireDictionary(try JSONSerialization.jsonObject(with: data), "Universe should encode as a JSON object")
    require(json["lastSimulatedWallClockTime"] != nil, "Universe should encode non-nil last simulation wall-clock metadata")

    let factionsJSON = requireArray(json["factions"], "Factions should encode as a JSON array")
    let factionJSON = requireDictionary(factionsJSON.first, "Faction should encode as a JSON object")
    let researchQueueJSON = requireArray(factionJSON["researchQueue"], "Faction research queue should encode as a JSON array")
    requireEqual(researchQueueJSON.count, 1, "Faction research queue should preserve queued items")

    let planetsJSON = requireArray(json["planets"], "Planets should encode as a JSON array")
    let planetJSON = requireDictionary(planetsJSON.first, "Planet should encode as a JSON object")
    let buildQueueJSON = requireArray(planetJSON["buildQueue"], "Planet build queue should encode as a JSON array")
    let shipBuildQueueJSON = requireArray(planetJSON["shipBuildQueue"], "Planet ship build queue should encode as a JSON array")
    let defenseBuildQueueJSON = requireArray(planetJSON["defenseBuildQueue"], "Planet defense build queue should encode as a JSON array")
    requireEqual(buildQueueJSON.count, 1, "Planet build queue should preserve queued items")
    requireEqual(shipBuildQueueJSON.count, 1, "Planet ship build queue should preserve queued items")
    requireEqual(defenseBuildQueueJSON.count, 1, "Planet defense build queue should preserve queued items")
}

func testQueueFieldsDefaultWhenDecodingOlderUniverseJSON() throws {
    let olderUniverseJSON = """
    {
      "id": { "rawValue": "00000000-0000-0000-0000-0000000000a0" },
      "name": "Older Universe",
      "seed": 21,
      "gameTime": 45,
      "playerFactionID": { "rawValue": "00000000-0000-0000-0000-0000000000a1" },
      "factions": [
        {
          "id": { "rawValue": "00000000-0000-0000-0000-0000000000a1" },
          "name": "Player",
          "kind": "player",
          "strategy": "balanced",
          "technology": { "levels": { "computer": 1 } },
          "ownedPlanetIDs": [
            { "rawValue": "00000000-0000-0000-0000-0000000000a2" }
          ]
        }
      ],
      "planets": [
        {
          "id": { "rawValue": "00000000-0000-0000-0000-0000000000a2" },
          "name": "Homeworld",
          "coordinate": { "galaxy": 1, "system": 1, "position": 4 },
          "ownerID": { "rawValue": "00000000-0000-0000-0000-0000000000a1" },
          "resources": { "metal": 100, "crystal": 50, "deuterium": 25 },
          "storage": { "metal": 10000, "crystal": 10000, "deuterium": 10000 },
          "energy": { "produced": 20, "used": 8 },
          "buildingLevels": { "metalMine": 2 },
          "shipInventory": { "smallCargo": 1 },
          "defenseInventory": { "rocketLauncher": 3 }
        }
      ],
      "fleets": [],
      "events": [],
      "ruleSet": {
        "id": "fast-skirmish-v1",
        "displayName": "Fast Skirmish",
        "baseTickInterval": 1,
        "offlineChunkInterval": 300
      }
    }
    """

    let decoded = try JSONDecoder().decode(Universe.self, from: Data(olderUniverseJSON.utf8))

    requireEqual(decoded.lastSimulatedWallClockTime, nil, "Older universe JSON should default missing simulation metadata to nil")
    requireEqual(decoded.factions[0].researchQueue, [], "Older faction JSON should default missing research queue to empty")
    requireEqual(decoded.planets[0].buildQueue, [], "Older planet JSON should default missing build queue to empty")
    requireEqual(decoded.planets[0].shipBuildQueue, [], "Older planet JSON should default missing ship build queue to empty")
    requireEqual(decoded.planets[0].defenseBuildQueue, [], "Older planet JSON should default missing defense build queue to empty")
    requireEqual(decoded.planets[0].debrisField, .zero, "Older planet JSON should default missing debris field to zero")
    requireEqual(decoded.planets[0].buildingLevels, [.metalMine: 2], "Older planet JSON should keep raw-value building map behavior")
    requireEqual(decoded.ruleSet.buildingRules, RuleSet.fastSkirmish.buildingRules, "Older universe JSON should keep RuleSet defaults")
}

func testQueueFieldsRejectExplicitNullWhenDecodingJSON() {
    let factionWithNullResearchQueueJSON = """
    {
      "id": { "rawValue": "00000000-0000-0000-0000-0000000000a3" },
      "name": "Null Queue Player",
      "kind": "player",
      "strategy": "balanced",
      "technology": { "levels": {} },
      "ownedPlanetIDs": [],
      "researchQueue": null
    }
    """
    let planetWithNullBuildQueueJSON = """
    {
      "id": { "rawValue": "00000000-0000-0000-0000-0000000000a4" },
      "name": "Null Queue Planet",
      "coordinate": { "galaxy": 1, "system": 1, "position": 4 },
      "ownerID": null,
      "resources": { "metal": 100, "crystal": 50, "deuterium": 25 },
      "storage": { "metal": 10000, "crystal": 10000, "deuterium": 10000 },
      "energy": { "produced": 20, "used": 8 },
      "buildingLevels": { "metalMine": 2 },
      "buildQueue": null,
      "shipBuildQueue": null,
      "defenseBuildQueue": [],
      "shipInventory": { "smallCargo": 1 },
      "defenseInventory": { "rocketLauncher": 3 }
    }
    """

    requireThrowsDecodingError("Explicit null researchQueue should fail decoding") {
        _ = try JSONDecoder().decode(Faction.self, from: Data(factionWithNullResearchQueueJSON.utf8))
    }
    requireThrowsDecodingError("Explicit null buildQueue should fail decoding") {
        _ = try JSONDecoder().decode(Planet.self, from: Data(planetWithNullBuildQueueJSON.utf8))
    }

    let planetWithNullShipQueueJSON = planetWithNullBuildQueueJSON
        .replacingOccurrences(of: "\"buildQueue\": null,", with: "\"buildQueue\": [],")
    requireThrowsDecodingError("Explicit null shipBuildQueue should fail decoding") {
        _ = try JSONDecoder().decode(Planet.self, from: Data(planetWithNullShipQueueJSON.utf8))
    }
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

func testSeededGeneratorEqualityTracksSeedAndState() {
    let first = SeededGenerator(seed: 21)
    let second = SeededGenerator(seed: 21)
    let different = SeededGenerator(seed: 22)

    requireEqual(first, second, "Generators with the same seed should compare equal before advancing")
    require(first != different, "Generators with different seeds should not compare equal")

    var advanced = first
    var advancedSame = second
    _ = advanced.next()

    require(first != advanced, "Advanced generator state should not compare equal to its initial state")

    _ = advancedSame.next()
    requireEqual(advanced, advancedSame, "Generators advanced the same number of steps should compare equal")
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

func makeEconomyUniverse(planets: [Planet], factions: [Faction]? = nil) -> Universe {
    let playerID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!)
    let resolvedFactions = factions ?? [
        Faction(
            id: playerID,
            name: "Player",
            kind: .player,
            strategy: .balanced,
            ownedPlanetIDs: planets.filter { $0.ownerID == playerID }.map(\.id)
        )
    ]

    return Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b0")!),
        name: "Economy Test",
        seed: 1,
        gameTime: 0,
        playerFactionID: playerID,
        factions: resolvedFactions,
        planets: planets,
        fleets: [],
        events: [],
        ruleSet: .fastSkirmish
    )
}

func queuePlayerID() -> FactionID {
    FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c1")!)
}

func queuePlanetID() -> PlanetID {
    PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c2")!)
}

func makeQueueUniverse(
    gameTime: TimeInterval = 0,
    resources: ResourceBundle = ResourceBundle(metal: 10_000, crystal: 10_000, deuterium: 10_000),
    buildingLevels: [BuildingKind: Int] = [:],
    researchLevels: [TechnologyKind: Int] = [:],
    buildQueue: [BuildQueueItem] = [],
    researchQueue: [ResearchQueueItem] = [],
    shipBuildQueue: [UnitBuildQueueItem] = [],
    defenseBuildQueue: [UnitBuildQueueItem] = [],
    shipInventory: [ShipKind: Int] = [:],
    defenseInventory: [DefenseKind: Int] = [:],
    ruleSet: RuleSet = .fastSkirmish
) -> Universe {
    let playerID = queuePlayerID()
    let planetID = queuePlanetID()

    return Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c0")!),
        name: "Queue Test",
        seed: 2,
        gameTime: gameTime,
        playerFactionID: playerID,
        factions: [
            Faction(
                id: playerID,
                name: "Player",
                kind: .player,
                strategy: .balanced,
                technology: ResearchState(levels: researchLevels),
                ownedPlanetIDs: [planetID],
                researchQueue: researchQueue
            )
        ],
        planets: [
            Planet(
                id: planetID,
                name: "Queue World",
                coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
                ownerID: playerID,
                resources: resources,
                storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
                buildingLevels: buildingLevels,
                buildQueue: buildQueue,
                shipBuildQueue: shipBuildQueue,
                defenseBuildQueue: defenseBuildQueue,
                shipInventory: shipInventory,
                defenseInventory: defenseInventory
            )
        ],
        fleets: [],
        events: [],
        ruleSet: ruleSet
    )
}

func fleetPlayerID() -> FactionID {
    FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000301")!)
}

func fleetPlanetID(_ index: Int) -> PlanetID {
    PlanetID(UUID(uuidString: String(format: "00000000-0000-0000-0003-%012d", index))!)
}

func makeFleetUniverse(
    gameTime: TimeInterval = 0,
    originResources: ResourceBundle = ResourceBundle(metal: 5_000, crystal: 3_000, deuterium: 1_000),
    originShips: [ShipKind: Int] = [.smallCargo: 3, .recycler: 1, .colonyShip: 1, .espionageProbe: 2],
    targetResources: ResourceBundle = ResourceBundle(metal: 200, crystal: 100, deuterium: 50),
    targetDebris: ResourceBundle = .zero,
    targetOwnerID: FactionID? = nil,
    fleets: [Fleet] = [],
    ruleSet: RuleSet = .fastSkirmish
) -> Universe {
    let playerID = fleetPlayerID()
    let originID = fleetPlanetID(1)
    let targetID = fleetPlanetID(2)

    return Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000300")!),
        name: "Fleet Test",
        seed: 33,
        gameTime: gameTime,
        playerFactionID: playerID,
        factions: [
            Faction(
                id: playerID,
                name: "Fleet Player",
                kind: .player,
                strategy: .balanced,
                ownedPlanetIDs: [originID]
            )
        ],
        planets: [
            Planet(
                id: originID,
                name: "Origin",
                coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
                ownerID: playerID,
                resources: originResources,
                storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
                shipInventory: originShips
            ),
            Planet(
                id: targetID,
                name: "Target",
                coordinate: Coordinate(galaxy: 1, system: 2, position: 6),
                ownerID: targetOwnerID,
                resources: targetResources,
                storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
                debrisField: targetDebris
            )
        ],
        fleets: fleets,
        events: [],
        ruleSet: ruleSet
    )
}

func fastSkirmishRules(offlineChunkInterval: TimeInterval) -> RuleSet {
    var ruleSet = RuleSet.fastSkirmish
    ruleSet.offlineChunkInterval = offlineChunkInterval
    return ruleSet
}

func aiTestPlayerID() -> FactionID {
    FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000e0")!)
}

func aiTestFactionID(_ index: Int) -> FactionID {
    FactionID(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 0x0e0 + index))!)
}

func aiTestPlanetID(_ index: Int) -> PlanetID {
    PlanetID(UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", 0x0e0 + index))!)
}

func makeAIEconomyFaction(
    index: Int,
    kind: Faction.Kind = .ai,
    strategy: Faction.Strategy,
    researchLevels: [TechnologyKind: Int] = [:],
    researchQueue: [ResearchQueueItem] = []
) -> Faction {
    let factionID = kind == .player ? aiTestPlayerID() : aiTestFactionID(index)
    let planetID = kind == .player ? aiTestPlanetID(0) : aiTestPlanetID(index)

    return Faction(
        id: factionID,
        name: kind == .player ? "Player" : "AI \(index)",
        kind: kind,
        strategy: strategy,
        technology: ResearchState(levels: researchLevels),
        ownedPlanetIDs: [planetID],
        researchQueue: researchQueue
    )
}

func makeAIEconomyPlanet(
    index: Int,
    ownerID: FactionID,
    resources: ResourceBundle = ResourceBundle(metal: 10_000, crystal: 10_000, deuterium: 10_000),
    buildingLevels: [BuildingKind: Int] = [
        .metalMine: 1,
        .crystalMine: 1,
        .solarPlant: 1
    ],
    buildQueue: [BuildQueueItem] = []
) -> Planet {
    Planet(
        id: index == 0 ? aiTestPlanetID(0) : aiTestPlanetID(index),
        name: index == 0 ? "Player World" : "AI World \(index)",
        coordinate: Coordinate(galaxy: 1, system: 10 + index, position: 4),
        ownerID: ownerID,
        resources: resources,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: buildingLevels,
        buildQueue: buildQueue
    )
}

func makeAIEconomyUniverse(
    seed: UInt64 = 24,
    gameTime: TimeInterval = 0,
    factions: [Faction],
    planets: [Planet],
    ruleSet: RuleSet = .fastSkirmish
) -> Universe {
    Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-0000000000ef")!),
        name: "AI Economy Test",
        seed: seed,
        gameTime: gameTime,
        playerFactionID: aiTestPlayerID(),
        factions: factions,
        planets: planets,
        fleets: [],
        events: [],
        ruleSet: ruleSet
    )
}

func requireFaction(_ factionID: FactionID, in universe: Universe, _ message: String) -> Faction {
    guard let faction = universe.factions.first(where: { $0.id == factionID }) else {
        fatalError(message)
    }

    return faction
}

func requirePlanet(_ planetID: PlanetID, in universe: Universe, _ message: String) -> Planet {
    guard let planet = universe.planets.first(where: { $0.id == planetID }) else {
        fatalError(message)
    }

    return planet
}

func queuedAIActionCount(for factionID: FactionID, in universe: Universe) -> Int {
    let researchCount = universe.factions.first(where: { $0.id == factionID })?.researchQueue.count ?? 0
    let buildCount = universe.planets
        .filter { $0.ownerID == factionID }
        .reduce(0) { count, planet in count + planet.buildQueue.count }

    return researchCount + buildCount
}

func testFastSkirmishFleetRulesCoverAllShips() {
    let shipRules = RuleSet.fastSkirmish.shipRules

    for ship in ShipKind.allCases {
        guard let rule = shipRules[ship] else {
            fatalError("Fast skirmish should define fleet data for \(ship.rawValue)")
        }

        require(rule.speed > 0, "Ship \(ship.rawValue) should have a positive fleet speed")
        require(rule.cargoCapacity >= 0, "Ship \(ship.rawValue) should have nonnegative cargo capacity")
        require(rule.fuelCost >= 0, "Ship \(ship.rawValue) should have nonnegative fuel cost")
        require(rule.attack >= 0, "Ship \(ship.rawValue) should have nonnegative attack placeholder")
        require(rule.shield >= 0, "Ship \(ship.rawValue) should have nonnegative shield placeholder")
        require(rule.hull >= 0, "Ship \(ship.rawValue) should have nonnegative hull placeholder")
    }

    require((shipRules[.smallCargo]?.cargoCapacity ?? 0) > 0, "Small cargo should carry resources")
    require((shipRules[.recycler]?.cargoCapacity ?? 0) > 0, "Recycler should carry debris")
    require((shipRules[.colonyShip]?.cargoCapacity ?? 0) > 0, "Colony ship should carry settlement supplies")
}

func testLegacyFullShipRulesDecodeWithFleetDefaultsByShipKind() throws {
    let legacyRuleSetJSON = """
    {
      "id": "fast-skirmish-v1",
      "displayName": "Fast Skirmish",
      "baseTickInterval": 1,
      "offlineChunkInterval": 300,
      "shipRules": {
        "battleship": {
          "baseCost": { "metal": 45000, "crystal": 15000, "deuterium": 0 },
          "baseDuration": 65,
          "aiPriorityWeight": 0.30
        },
        "colonyShip": {
          "baseCost": { "metal": 10000, "crystal": 20000, "deuterium": 10000 },
          "baseDuration": 75,
          "aiPriorityWeight": 0.25
        },
        "cruiser": {
          "baseCost": { "metal": 20000, "crystal": 7000, "deuterium": 2000 },
          "baseDuration": 45,
          "aiPriorityWeight": 0.45
        },
        "espionageProbe": {
          "baseCost": { "metal": 0, "crystal": 1000, "deuterium": 0 },
          "baseDuration": 5,
          "aiPriorityWeight": 0.50
        },
        "heavyFighter": {
          "baseCost": { "metal": 6000, "crystal": 4000, "deuterium": 0 },
          "baseDuration": 30,
          "aiPriorityWeight": 0.55
        },
        "largeCargo": {
          "baseCost": { "metal": 6000, "crystal": 6000, "deuterium": 0 },
          "baseDuration": 18,
          "aiPriorityWeight": 0.35
        },
        "lightFighter": {
          "baseCost": { "metal": 3000, "crystal": 1000, "deuterium": 0 },
          "baseDuration": 20,
          "aiPriorityWeight": 0.65
        },
        "recycler": {
          "baseCost": { "metal": 10000, "crystal": 6000, "deuterium": 2000 },
          "baseDuration": 40,
          "aiPriorityWeight": 0.20
        },
        "smallCargo": {
          "baseCost": { "metal": 2000, "crystal": 2000, "deuterium": 0 },
          "baseDuration": 10,
          "aiPriorityWeight": 0.40
        }
      }
    }
    """

    let decoded = try JSONDecoder().decode(RuleSet.self, from: Data(legacyRuleSetJSON.utf8))

    for ship in ShipKind.allCases {
        guard let decodedRule = decoded.shipRules[ship],
              let defaultRule = RuleSet.fastSkirmish.shipRules[ship]
        else {
            fatalError("Decoded legacy rules should cover \(ship.rawValue)")
        }

        requireEqual(decodedRule.speed, defaultRule.speed, "Legacy \(ship.rawValue) should inherit default speed")
        requireEqual(decodedRule.cargoCapacity, defaultRule.cargoCapacity, "Legacy \(ship.rawValue) should inherit default cargo capacity")
        requireEqual(decodedRule.fuelCost, defaultRule.fuelCost, "Legacy \(ship.rawValue) should inherit default fuel cost")
        requireEqual(decodedRule.attack, defaultRule.attack, "Legacy \(ship.rawValue) should inherit default attack placeholder")
        requireEqual(decodedRule.shield, defaultRule.shield, "Legacy \(ship.rawValue) should inherit default shield placeholder")
        requireEqual(decodedRule.hull, defaultRule.hull, "Legacy \(ship.rawValue) should inherit default hull placeholder")
    }
}

func testFleetLaunchRemovesShipsCargoAndFuelFromOrigin() {
    var universe = makeFleetUniverse()
    let cargo = ResourceBundle(metal: 300, crystal: 150, deuterium: 20)
    let expectedTravelTime = FleetEngine.travelDuration(
        from: universe.planets[0].coordinate,
        to: universe.planets[1].coordinate,
        ships: [.smallCargo: 2],
        ruleSet: universe.ruleSet
    )
    let expectedFuel = FleetEngine.fuelCost(
        from: universe.planets[0].coordinate,
        to: universe.planets[1].coordinate,
        ships: [.smallCargo: 2],
        ruleSet: universe.ruleSet
    )

    let result = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .transport,
        ships: [.smallCargo: 2],
        cargo: cargo
    )

    guard case .launched(let fleet) = result else {
        fatalError("Fleet launch should succeed with available ships, cargo, and fuel")
    }

    requireEqual(universe.planets[0].shipInventory[.smallCargo], 1, "Launching should remove ships from origin inventory")
    requireApproxEqual(
        universe.planets[0].resources,
        ResourceBundle(metal: 4_700, crystal: 2_850, deuterium: 980 - expectedFuel),
        "Launching should remove cargo and fuel from origin resources"
    )
    requireEqual(universe.fleets, [fleet], "Launching should add the outbound fleet to the universe")
    requireEqual(fleet.originPlanetID, fleetPlanetID(1), "Fleet should remember its origin planet")
    requireEqual(fleet.targetPlanetID, fleetPlanetID(2), "Fleet should remember its target planet")
    requireEqual(fleet.phase, .outbound, "New fleets should begin outbound")
    requireEqual(fleet.arrivalTime, universe.gameTime + expectedTravelTime, "Arrival time should use deterministic travel duration")
    requireEqual(fleet.returnTime, universe.gameTime + expectedTravelTime * 2, "Return time should mirror outbound travel duration")
}

func testIdenticalFleetLaunchesInSameTickUseDistinctIDs() {
    var universe = makeFleetUniverse()
    let firstResult = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .transport,
        ships: [.smallCargo: 1],
        cargo: .zero
    )
    let secondResult = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .transport,
        ships: [.smallCargo: 1],
        cargo: .zero
    )

    guard case .launched(let firstFleet) = firstResult,
          case .launched(let secondFleet) = secondResult
    else {
        fatalError("Repeated same-tick launches should both succeed")
    }

    require(firstFleet.id != secondFleet.id, "Same-tick identical launches should have distinct fleet IDs")
    requireEqual(Set(universe.fleets.map(\.id)).count, 2, "Universe should store both same-tick fleet IDs distinctly")
    requireEqual(Set(universe.events.map(\.id)).count, universe.events.count, "Launch events should have distinct IDs")
}

func testInvalidFleetLaunchFailsWithoutMutation() {
    let invalidLaunches: [(FleetLaunchFailure, () -> Universe, (inout Universe) -> FleetLaunchResult)] = [
        (.missingOrigin, { makeFleetUniverse() }, { universe in
            FleetEngine.launchFleet(
                from: fleetPlanetID(90),
                to: fleetPlanetID(2),
                in: &universe,
                mission: .transport,
                ships: [.smallCargo: 1],
                cargo: .zero
            )
        }),
        (.missingTarget, { makeFleetUniverse() }, { universe in
            FleetEngine.launchFleet(
                from: fleetPlanetID(1),
                to: fleetPlanetID(91),
                in: &universe,
                mission: .transport,
                ships: [.smallCargo: 1],
                cargo: .zero
            )
        }),
        (.missingOwner, {
            var universe = makeFleetUniverse()
            universe.planets[0].ownerID = nil
            return universe
        }, { universe in
            FleetEngine.launchFleet(
                from: fleetPlanetID(1),
                to: fleetPlanetID(2),
                in: &universe,
                mission: .transport,
                ships: [.smallCargo: 1],
                cargo: .zero
            )
        }),
        (.insufficientShips, { makeFleetUniverse() }, { universe in
            FleetEngine.launchFleet(
                from: fleetPlanetID(1),
                to: fleetPlanetID(2),
                in: &universe,
                mission: .transport,
                ships: [.smallCargo: 4],
                cargo: .zero
            )
        }),
        (.insufficientCargo, { makeFleetUniverse() }, { universe in
            FleetEngine.launchFleet(
                from: fleetPlanetID(1),
                to: fleetPlanetID(2),
                in: &universe,
                mission: .transport,
                ships: [.smallCargo: 1],
                cargo: ResourceBundle(metal: 10_001)
            )
        }),
        (.insufficientFuel, {
            makeFleetUniverse(originResources: ResourceBundle(metal: 5_000, crystal: 3_000, deuterium: 0))
        }, { universe in
            FleetEngine.launchFleet(
                from: fleetPlanetID(1),
                to: fleetPlanetID(2),
                in: &universe,
                mission: .transport,
                ships: [.smallCargo: 1],
                cargo: .zero
            )
        }),
        (.invalidMission, { makeFleetUniverse() }, { universe in
            FleetEngine.launchFleet(
                from: fleetPlanetID(1),
                to: fleetPlanetID(2),
                in: &universe,
                mission: .colonize,
                ships: [.smallCargo: 1],
                cargo: .zero
            )
        })
    ]

    for (expectedFailure, makeUniverse, launch) in invalidLaunches {
        var universe = makeUniverse()
        let originalUniverse = universe
        let result = launch(&universe)

        requireEqual(result, .failure(expectedFailure), "Invalid fleet launch should report \(expectedFailure)")
        requireEqual(universe, originalUniverse, "Invalid fleet launch \(expectedFailure) should not mutate the universe")
    }
}

func testFleetTravelTimeIsDeterministicFromCoordinatesAndSpeedRules() {
    let origin = Coordinate(galaxy: 1, system: 1, position: 4)
    let target = Coordinate(galaxy: 1, system: 2, position: 6)
    let sameRoute = FleetEngine.travelDuration(
        from: origin,
        to: target,
        ships: [.smallCargo: 1, .recycler: 1],
        ruleSet: .fastSkirmish
    )
    let repeatedRoute = FleetEngine.travelDuration(
        from: origin,
        to: target,
        ships: [.smallCargo: 1, .recycler: 1],
        ruleSet: .fastSkirmish
    )
    let nearerRoute = FleetEngine.travelDuration(
        from: origin,
        to: Coordinate(galaxy: 1, system: 1, position: 5),
        ships: [.smallCargo: 1, .recycler: 1],
        ruleSet: .fastSkirmish
    )
    let fasterFleet = FleetEngine.travelDuration(
        from: origin,
        to: target,
        ships: [.smallCargo: 1],
        ruleSet: .fastSkirmish
    )

    requireEqual(sameRoute, repeatedRoute, "Travel time should be deterministic for the same route and ships")
    require(sameRoute > nearerRoute, "Longer coordinate distances should take longer")
    require(sameRoute > fasterFleet, "Fleet travel should be limited by the slowest selected ship")
}

func testTransportMissionDeliversCargoAndReturnsShips() {
    var universe = makeFleetUniverse()
    let cargo = ResourceBundle(metal: 300, crystal: 150, deuterium: 20)
    let result = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .transport,
        ships: [.smallCargo: 1],
        cargo: cargo
    )
    guard case .launched(let launchedFleet) = result else {
        fatalError("Transport fleet should launch")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    requireApproxEqual(
        requirePlanet(fleetPlanetID(2), in: universe, "Transport target should remain").resources,
        ResourceBundle(metal: 500, crystal: 250, deuterium: 70),
        "Transport should deliver cargo to the target planet"
    )
    requireEqual(universe.fleets[0].phase, .returning, "Transport fleet should return after delivery")
    requireEqual(universe.fleets[0].cargo, .zero, "Delivered transport fleets should return without cargo")

    universe.gameTime = launchedFleet.returnTime
    FleetEngine.resolveDueFleets(in: &universe)

    requireEqual(universe.fleets, [], "Returned transport fleet should be removed")
    requireEqual(universe.planets[0].shipInventory[.smallCargo], 3, "Transport return should restore ships to origin")
}

func testLargeSimulationTickCompletesOutboundArrivalAndReturnTogether() {
    var universe = makeFleetUniverse()
    let result = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .transport,
        ships: [.smallCargo: 1],
        cargo: ResourceBundle(metal: 100)
    )
    guard case .launched(let launchedFleet) = result else {
        fatalError("Transport fleet should launch before large tick")
    }

    SimulationEngine.tick(universe: &universe, delta: launchedFleet.returnTime - universe.gameTime)

    requireEqual(universe.fleets, [], "Large tick should complete due outbound and return phases")
    requireEqual(universe.planets[0].shipInventory[.smallCargo], 3, "Large tick should restore returned ships")
    requireApproxEqual(
        requirePlanet(fleetPlanetID(2), in: universe, "Large tick target should remain").resources,
        ResourceBundle(metal: 300, crystal: 100, deuterium: 50),
        "Large tick should deliver transport cargo"
    )
    require(universe.events.map(\.title).contains("Fleet Returned"), "Large tick should record the return event")
}

func testTransportOverflowCargoStaysWithReturningFleet() {
    var universe = makeFleetUniverse(targetResources: ResourceBundle(metal: 95, crystal: 100, deuterium: 50))
    universe.planets[1].storage = ResourceStorage(metal: 100, crystal: 100, deuterium: 100)
    let result = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .transport,
        ships: [.smallCargo: 1],
        cargo: ResourceBundle(metal: 100)
    )
    guard case .launched(let launchedFleet) = result else {
        fatalError("Transport fleet should launch for overflow delivery")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    requireApproxEqual(
        requirePlanet(fleetPlanetID(2), in: universe, "Overflow target should remain").resources,
        ResourceBundle(metal: 100, crystal: 100, deuterium: 50),
        "Transport should fill only available target storage"
    )
    requireApproxEqual(
        universe.fleets[0].cargo,
        ResourceBundle(metal: 95),
        "Transport overflow should remain on the returning fleet"
    )
}

func testReturningFleetDoesNotLoseCargoWhenOriginStorageIsFull() {
    let returningFleet = Fleet(
        id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-000000000398")!),
        ownerID: fleetPlayerID(),
        mission: .recycle,
        origin: Coordinate(galaxy: 1, system: 1, position: 4),
        target: Coordinate(galaxy: 1, system: 2, position: 6),
        ships: [.recycler: 1],
        cargo: ResourceBundle(metal: 100),
        launchTime: 10,
        arrivalTime: 20,
        returnTime: 30,
        phase: .returning,
        originPlanetID: fleetPlanetID(1),
        targetPlanetID: fleetPlanetID(2)
    )
    var universe = makeFleetUniverse(
        gameTime: 30,
        originResources: ResourceBundle(metal: 95, crystal: 3_000, deuterium: 1_000),
        originShips: [:],
        fleets: [returningFleet]
    )
    universe.planets[0].storage = ResourceStorage(metal: 100, crystal: 100_000, deuterium: 100_000)

    FleetEngine.resolveDueFleets(in: &universe)

    requireEqual(universe.fleets, [], "Returned fleet should complete even when origin storage is full")
    requireApproxEqual(
        universe.planets[0].resources,
        ResourceBundle(metal: 195, crystal: 3_000, deuterium: 1_000),
        "Return should not silently discard cargo above origin storage"
    )
}

func testRecycleMissionCollectsDebrisFromTargetPlanet() {
    var universe = makeFleetUniverse(targetDebris: ResourceBundle(metal: 600, crystal: 300))
    let result = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .recycle,
        ships: [.recycler: 1],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = result else {
        fatalError("Recycler fleet should launch")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    requireEqual(requirePlanet(fleetPlanetID(2), in: universe, "Debris target should remain").debrisField, .zero, "Recycle mission should clear collected debris")
    requireApproxEqual(universe.fleets[0].cargo, ResourceBundle(metal: 600, crystal: 300), "Recycle mission should carry collected debris home")

    universe.gameTime = launchedFleet.returnTime
    FleetEngine.resolveDueFleets(in: &universe)

    requireApproxEqual(
        requirePlanet(fleetPlanetID(1), in: universe, "Recycler origin should remain").resources,
        ResourceBundle(metal: 5_600, crystal: 3_300, deuterium: 1_000 - FleetEngine.fuelCost(
            from: Coordinate(galaxy: 1, system: 1, position: 4),
            to: Coordinate(galaxy: 1, system: 2, position: 6),
            ships: [.recycler: 1],
            ruleSet: universe.ruleSet
        )),
        "Recycle return should add collected debris to origin resources"
    )
    requireEqual(universe.planets[0].shipInventory[.recycler], 1, "Recycle return should restore recycler ship")
}

func testExploreMissionCreatesDeterministicEventAndReward() throws {
    var first = makeFleetUniverse()
    let encoded = try JSONEncoder().encode(first)
    var second = try JSONDecoder().decode(Universe.self, from: encoded)

    let firstLaunch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &first,
        mission: .explore,
        ships: [.espionageProbe: 1],
        cargo: .zero
    )
    let secondLaunch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &second,
        mission: .explore,
        ships: [.espionageProbe: 1],
        cargo: .zero
    )
    guard case .launched(let firstFleet) = firstLaunch, case .launched(let secondFleet) = secondLaunch else {
        fatalError("Exploration fleets should launch")
    }

    first.gameTime = firstFleet.arrivalTime
    second.gameTime = secondFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &first)
    FleetEngine.resolveDueFleets(in: &second)

    requireEqual(first, second, "Exploration arrival should be deterministic across save/load equality")
    requireEqual(first.events.last?.kind, .exploration, "Exploration should record an exploration event")
    require(first.fleets[0].cargo != .zero, "Exploration should generate a resource reward to return")
}

func testColonizeMissionClaimsUnownedPlanetWhenColonyShipIsPresent() {
    var universe = makeFleetUniverse(originResources: ResourceBundle(metal: 5_000, crystal: 3_000, deuterium: 5_000))
    let result = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .colonize,
        ships: [.colonyShip: 1, .smallCargo: 1],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = result else {
        fatalError("Colonization fleet should launch")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    let target = requirePlanet(fleetPlanetID(2), in: universe, "Colonized target should remain")
    let faction = requireFaction(fleetPlayerID(), in: universe, "Colonizing faction should remain")
    requireEqual(target.ownerID, fleetPlayerID(), "Colonization should claim an unowned target")
    require(faction.ownedPlanetIDs.contains(fleetPlanetID(2)), "Colonization should add the target to faction ownership")
    requireEqual(universe.fleets[0].ships[.colonyShip], nil, "Colonization should consume the colony ship")
    requireEqual(universe.fleets[0].ships[.smallCargo], 1, "Colonization should return escort ships")
}

func testFleetReturnsRestoreShipsAndCargoToOrigin() {
    let returningFleet = Fleet(
        id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-000000000399")!),
        ownerID: fleetPlayerID(),
        mission: .transport,
        origin: Coordinate(galaxy: 1, system: 1, position: 4),
        target: Coordinate(galaxy: 1, system: 2, position: 6),
        ships: [.smallCargo: 1, .recycler: 1],
        cargo: ResourceBundle(metal: 100, crystal: 50, deuterium: 25),
        launchTime: 10,
        arrivalTime: 20,
        returnTime: 30,
        phase: .returning,
        originPlanetID: fleetPlanetID(1),
        targetPlanetID: fleetPlanetID(2)
    )
    var universe = makeFleetUniverse(
        gameTime: 30,
        originShips: [.smallCargo: 2],
        fleets: [returningFleet]
    )

    FleetEngine.resolveDueFleets(in: &universe)

    requireEqual(universe.fleets, [], "Due returning fleet should complete")
    requireEqual(universe.planets[0].shipInventory[.smallCargo], 3, "Return should restore cargo ship")
    requireEqual(universe.planets[0].shipInventory[.recycler], 1, "Return should restore recycler")
    requireApproxEqual(
        universe.planets[0].resources,
        ResourceBundle(metal: 5_100, crystal: 3_050, deuterium: 1_025),
        "Return should restore cargo to origin"
    )
}

func testSimulationTickResolvesDueFleetArrivalsBeforeSystemEvent() {
    var universe = makeFleetUniverse()
    let result = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .transport,
        ships: [.smallCargo: 1],
        cargo: ResourceBundle(metal: 100)
    )
    guard case .launched(let launchedFleet) = result else {
        fatalError("Transport fleet should launch before simulation tick")
    }

    SimulationEngine.tick(universe: &universe, delta: launchedFleet.arrivalTime - universe.gameTime)

    requireEqual(universe.fleets.first?.phase, .returning, "Simulation tick should resolve due fleet arrival")
    requireApproxEqual(
        requirePlanet(fleetPlanetID(2), in: universe, "Tick target should remain").resources,
        ResourceBundle(metal: 300, crystal: 100, deuterium: 50),
        "Simulation tick should deliver transport cargo"
    )
    requireEqual(
        universe.events.suffix(2).map(\.title),
        ["Transport Delivered", "Simulation Advanced"],
        "Fleet arrival events should be recorded before the tick system event"
    )
}

func testAIEconomyQueuesOneAffordableUpgradePerAIFaction() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let miner = makeAIEconomyFaction(index: 1, strategy: .miner)
    let poorRaider = makeAIEconomyFaction(index: 2, strategy: .raider)
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let minerPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: miner.id,
        resources: ResourceBundle(metal: 500, crystal: 500, deuterium: 100)
    )
    let poorPlanet = makeAIEconomyPlanet(
        index: 2,
        ownerID: poorRaider.id,
        resources: ResourceBundle(metal: 10, crystal: 10, deuterium: 0)
    )
    var universe = makeAIEconomyUniverse(
        factions: [player, miner, poorRaider],
        planets: [playerPlanet, minerPlanet, poorPlanet]
    )

    AIEconomyEngine.makeDecisions(in: &universe)

    let updatedMinerPlanet = requirePlanet(minerPlanet.id, in: universe, "Miner planet should remain in the universe")
    let updatedPoorPlanet = requirePlanet(poorPlanet.id, in: universe, "Poor AI planet should remain in the universe")

    requireEqual(updatedMinerPlanet.buildQueue.count, 1, "Affordable AI faction should queue exactly one upgrade")
    requireEqual(updatedMinerPlanet.buildQueue[0].buildingKind, .metalMine, "Miner should choose an affordable mine upgrade first")
    requireEqual(updatedPoorPlanet.buildQueue, [], "AI faction without affordable options should not queue an upgrade")
    requireEqual(queuedAIActionCount(for: miner.id, in: universe), 1, "AI should queue only one action for a faction in a decision window")
}

func testAIEconomyStrategyPrioritiesChooseDistinctEarlyGrowthPaths() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let miner = makeAIEconomyFaction(index: 1, strategy: .miner)
    let technologist = makeAIEconomyFaction(index: 2, strategy: .technologist)
    let expansionist = makeAIEconomyFaction(index: 3, strategy: .expansionist)
    let balanced = makeAIEconomyFaction(index: 4, strategy: .balanced)
    let raider = makeAIEconomyFaction(index: 5, strategy: .raider)
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let minerPlanet = makeAIEconomyPlanet(index: 1, ownerID: miner.id)
    let technologistPlanet = makeAIEconomyPlanet(
        index: 2,
        ownerID: technologist.id,
        buildingLevels: [.metalMine: 1, .crystalMine: 1, .solarPlant: 1, .researchLab: 1]
    )
    let expansionistPlanet = makeAIEconomyPlanet(index: 3, ownerID: expansionist.id)
    let balancedPlanet = makeAIEconomyPlanet(
        index: 4,
        ownerID: balanced.id,
        buildingLevels: [
            .metalMine: 2,
            .crystalMine: 2,
            .deuteriumSynthesizer: 1
        ]
    )
    let raiderPlanet = makeAIEconomyPlanet(
        index: 5,
        ownerID: raider.id,
        buildingLevels: [
            .metalMine: 1,
            .crystalMine: 1,
            .solarPlant: 1,
            .roboticsFactory: 1
        ]
    )
    var universe = makeAIEconomyUniverse(
        factions: [player, miner, technologist, expansionist, balanced, raider],
        planets: [playerPlanet, minerPlanet, technologistPlanet, expansionistPlanet, balancedPlanet, raiderPlanet]
    )

    AIEconomyEngine.makeDecisions(in: &universe)

    let updatedMinerPlanet = requirePlanet(minerPlanet.id, in: universe, "Miner planet should remain in the universe")
    let updatedTechnologist = requireFaction(technologist.id, in: universe, "Technologist faction should remain in the universe")
    let updatedExpansionistPlanet = requirePlanet(expansionistPlanet.id, in: universe, "Expansionist planet should remain in the universe")
    let updatedBalancedPlanet = requirePlanet(balancedPlanet.id, in: universe, "Balanced planet should remain in the universe")
    let updatedRaiderPlanet = requirePlanet(raiderPlanet.id, in: universe, "Raider planet should remain in the universe")

    requireEqual(updatedMinerPlanet.buildQueue.first?.buildingKind, .metalMine, "Miner strategy should prioritize mine growth")
    requireEqual(updatedTechnologist.researchQueue.first?.technologyKind, .computer, "Technologist strategy should prioritize research when a lab exists")
    requireEqual(updatedExpansionistPlanet.buildQueue.first?.buildingKind, .roboticsFactory, "Expansionist strategy should prioritize robotics setup")
    requireEqual(updatedBalancedPlanet.buildQueue.first?.buildingKind, .solarPlant, "Balanced strategy should address early energy deficits")
    requireEqual(updatedRaiderPlanet.buildQueue.first?.buildingKind, .shipyard, "Raider strategy should prioritize combat-adjacent shipyard setup")
    requireEqual(universe.fleets, [], "AI economic growth should not create fleets")
}

func testAIEconomyResearchPreviewUsesQueueEnginePaymentPlanetOrder() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let technologistID = aiTestFactionID(6)
    let poorPlanetID = aiTestPlanetID(6)
    let richPaymentPlanetID = aiTestPlanetID(7)
    let technologist = Faction(
        id: technologistID,
        name: "Multi-Planet Technologist",
        kind: .ai,
        strategy: .technologist,
        ownedPlanetIDs: [richPaymentPlanetID, poorPlanetID]
    )
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let poorPlanet = Planet(
        id: poorPlanetID,
        name: "Poor Sorted First",
        coordinate: Coordinate(galaxy: 1, system: 16, position: 4),
        ownerID: technologistID,
        resources: ResourceBundle(metal: 100, crystal: 100, deuterium: 100),
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.metalMine: 1, .crystalMine: 1, .solarPlant: 1]
    )
    let richPaymentPlanet = Planet(
        id: richPaymentPlanetID,
        name: "Rich Payment First",
        coordinate: Coordinate(galaxy: 1, system: 17, position: 4),
        ownerID: technologistID,
        resources: ResourceBundle(metal: 1_000, crystal: 1_000, deuterium: 1_000),
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.metalMine: 1, .crystalMine: 1, .solarPlant: 1, .researchLab: 1]
    )
    var universe = makeAIEconomyUniverse(
        factions: [player, technologist],
        planets: [playerPlanet, poorPlanet, richPaymentPlanet]
    )

    AIEconomyEngine.makeDecisions(in: &universe)

    let updatedTechnologist = requireFaction(technologistID, in: universe, "Technologist faction should remain in the universe")
    let updatedPoorPlanet = requirePlanet(poorPlanetID, in: universe, "Poor AI planet should remain in the universe")
    let updatedRichPaymentPlanet = requirePlanet(richPaymentPlanetID, in: universe, "Rich AI payment planet should remain in the universe")

    requireEqual(
        updatedTechnologist.researchQueue.first?.technologyKind,
        .computer,
        "AI should preview research affordability from QueueEngine's first owned payment planet"
    )
    requireEqual(
        updatedPoorPlanet.resources,
        poorPlanet.resources,
        "AI research should not deduct from UUID-sorted planets that are later in QueueEngine payment order"
    )
    requireEqual(
        updatedRichPaymentPlanet.resources,
        ResourceBundle(metal: 1_000, crystal: 600, deuterium: 400),
        "AI research should be charged to the first planet in faction ownedPlanetIDs order"
    )
}

func testAIEconomyDoesNotMutatePlayerState() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let ai = makeAIEconomyFaction(index: 1, strategy: .miner)
    let playerPlanet = makeAIEconomyPlanet(
        index: 0,
        ownerID: player.id,
        resources: ResourceBundle(metal: 9_000, crystal: 9_000, deuterium: 9_000),
        buildingLevels: [.metalMine: 4, .crystalMine: 4, .solarPlant: 6]
    )
    let aiPlanet = makeAIEconomyPlanet(index: 1, ownerID: ai.id)
    var universe = makeAIEconomyUniverse(factions: [player, ai], planets: [playerPlanet, aiPlanet])
    let originalPlayer = player
    let originalPlayerPlanet = playerPlanet
    let originalGameTime = universe.gameTime
    let originalEvents = universe.events

    AIEconomyEngine.makeDecisions(in: &universe)

    requireEqual(
        requireFaction(player.id, in: universe, "Player faction should remain in the universe"),
        originalPlayer,
        "AI decision calls should not mutate the player faction"
    )
    requireEqual(
        requirePlanet(playerPlanet.id, in: universe, "Player planet should remain in the universe"),
        originalPlayerPlanet,
        "AI decision calls should not mutate the player's planet"
    )
    requireEqual(universe.gameTime, originalGameTime, "AI decision calls should not advance shared universe time")
    requireEqual(universe.events, originalEvents, "AI decision calls should not append feed events")
    requireEqual(queuedAIActionCount(for: ai.id, in: universe), 1, "AI decision call should still act for AI factions")
}

func testAIEconomyDecisionsAreDeterministicForSameSeedTimeAndState() throws {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let miner = makeAIEconomyFaction(index: 1, strategy: .miner)
    let technologist = makeAIEconomyFaction(index: 2, strategy: .technologist)
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let minerPlanet = makeAIEconomyPlanet(index: 1, ownerID: miner.id)
    let technologistPlanet = makeAIEconomyPlanet(
        index: 2,
        ownerID: technologist.id,
        buildingLevels: [.metalMine: 1, .crystalMine: 1, .solarPlant: 1, .researchLab: 1]
    )
    let original = makeAIEconomyUniverse(
        seed: 77,
        gameTime: 900,
        factions: [player, miner, technologist],
        planets: [playerPlanet, minerPlanet, technologistPlanet]
    )
    let data = try JSONEncoder().encode(original)
    var first = try JSONDecoder().decode(Universe.self, from: data)
    var second = try JSONDecoder().decode(Universe.self, from: data)

    AIEconomyEngine.makeDecisions(in: &first)
    AIEconomyEngine.makeDecisions(in: &second)

    requireEqual(first, second, "AI decisions should be deterministic for the same seed, game time, and state")
}

func testOfflineCatchUpTriggersAIEconomyDecisionsAtBoundedIntervals() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let ai = makeAIEconomyFaction(index: 1, strategy: .miner)
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let aiPlanet = makeAIEconomyPlanet(index: 1, ownerID: ai.id)
    let ruleSet = fastSkirmishRules(offlineChunkInterval: 300)
    let original = makeAIEconomyUniverse(
        factions: [player, ai],
        planets: [playerPlanet, aiPlanet],
        ruleSet: ruleSet
    )
    var belowInterval = original
    var atInterval = original

    let belowSummary = OfflineSimulationEngine.catchUp(
        universe: &belowInterval,
        elapsed: 299,
        now: Date(timeIntervalSince1970: 7_000)
    )
    let atSummary = OfflineSimulationEngine.catchUp(
        universe: &atInterval,
        elapsed: 300,
        now: Date(timeIntervalSince1970: 7_300)
    )

    requireEqual(belowSummary.processedChunks, 1, "Offline catch-up should process sub-interval elapsed time in one bounded chunk")
    requireEqual(atSummary.processedChunks, 1, "Offline catch-up should process one AI decision interval in one bounded chunk")
    requireEqual(queuedAIActionCount(for: ai.id, in: belowInterval), 0, "Offline catch-up should not run AI before the decision interval boundary")
    requireEqual(queuedAIActionCount(for: ai.id, in: atInterval), 1, "Offline catch-up should run one AI decision at the decision interval boundary")
    requireEqual(queuedAIActionCount(for: player.id, in: atInterval), 0, "Offline-triggered AI decisions should not queue player actions")
}

func testQueueEngineStartsBuildingUpgradeAndPaysCost() {
    var universe = makeQueueUniverse(
        resources: ResourceBundle(metal: 1_000, crystal: 1_000, deuterium: 1_000),
        buildingLevels: [.metalMine: 1]
    )

    let result = QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &universe, kind: .metalMine)

    requireEqual(result, QueueResult.queued, "Affordable building upgrade should be queued")
    requireEqual(universe.planets[0].buildQueue.count, 1, "Building queue should contain the started upgrade")

    let item = universe.planets[0].buildQueue[0]
    let expectedCost = ResourceBundle(metal: 90, crystal: 22.5, deuterium: 0)
    requireEqual(item.planetID, queuePlanetID(), "Build queue item should target the requested planet")
    requireEqual(item.buildingKind, .metalMine, "Build queue item should store the building kind")
    requireEqual(item.targetLevel, 2, "Build queue item should target the next building level")
    requireEqual(item.startTime, 0, "Build queue item should start at current game time")
    requireEqual(item.finishTime, 26, "Build queue item should finish after the level-scaled duration")
    requireEqual(item.paidCost, expectedCost, "Build queue item should store the paid cost")
    requireEqual(
        universe.planets[0].resources,
        ResourceBundle(metal: 910, crystal: 977.5, deuterium: 1_000),
        "Starting a building upgrade should deduct the paid cost immediately"
    )
}

func testQueueEngineRejectsUnaffordableBuildingAndResearchWithoutMutation() {
    var buildingUniverse = makeQueueUniverse(resources: ResourceBundle(metal: 59, crystal: 15, deuterium: 0))
    let originalBuildingUniverse = buildingUniverse

    let buildingResult = QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &buildingUniverse, kind: .metalMine)

    requireEqual(buildingResult, QueueResult.insufficientResources, "Unaffordable building upgrade should fail")
    requireEqual(buildingUniverse, originalBuildingUniverse, "Unaffordable building upgrade should not mutate the universe")

    var researchUniverse = makeQueueUniverse(resources: ResourceBundle(metal: 10_000, crystal: 399, deuterium: 600))
    let originalResearchUniverse = researchUniverse

    let researchResult = QueueEngine.startResearch(for: queuePlayerID(), in: &researchUniverse, technology: .computer)

    requireEqual(researchResult, QueueResult.insufficientResources, "Unaffordable research should fail")
    requireEqual(researchUniverse, originalResearchUniverse, "Unaffordable research should not mutate the universe")
}

func testQueueEngineRejectsBusyBuildingAndResearchQueuesWithoutMutation() {
    let buildItem = BuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000c3")!,
        planetID: queuePlanetID(),
        buildingKind: .solarPlant,
        targetLevel: 1,
        startTime: 0,
        finishTime: 18,
        paidCost: ResourceBundle(metal: 75, crystal: 30)
    )
    var buildingUniverse = makeQueueUniverse(buildQueue: [buildItem])
    let originalBuildingUniverse = buildingUniverse

    let buildingResult = QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &buildingUniverse, kind: .metalMine)

    requireEqual(buildingResult, QueueResult.queueBusy, "Planet with an active building queue should reject another building")
    requireEqual(buildingUniverse, originalBuildingUniverse, "Busy building queue rejection should not mutate the universe")

    let researchItem = ResearchQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000c4")!,
        factionID: queuePlayerID(),
        technologyKind: .energy,
        targetLevel: 1,
        startTime: 0,
        finishTime: 50,
        paidCost: ResourceBundle(crystal: 800, deuterium: 400)
    )
    var researchUniverse = makeQueueUniverse(researchQueue: [researchItem])
    let originalResearchUniverse = researchUniverse

    let researchResult = QueueEngine.startResearch(for: queuePlayerID(), in: &researchUniverse, technology: .computer)

    requireEqual(researchResult, QueueResult.queueBusy, "Faction with an active research queue should reject another research")
    requireEqual(researchUniverse, originalResearchUniverse, "Busy research queue rejection should not mutate the universe")
}

func testQueueEngineReportsMissingEntitiesAndRulesWithoutMutation() {
    let missingPlanetID = PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c5")!)
    let missingFactionID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c6")!)

    var missingEntityUniverse = makeQueueUniverse()
    let originalMissingEntityUniverse = missingEntityUniverse

    let missingPlanetResult = QueueEngine.startBuildingUpgrade(on: missingPlanetID, in: &missingEntityUniverse, kind: .metalMine)
    let missingFactionResult = QueueEngine.startResearch(for: missingFactionID, in: &missingEntityUniverse, technology: .computer)

    requireEqual(missingPlanetResult, QueueResult.missingPlanet, "Building upgrade should report a missing planet")
    requireEqual(missingFactionResult, QueueResult.missingFaction, "Research should report a missing faction")
    requireEqual(missingEntityUniverse, originalMissingEntityUniverse, "Missing entity failures should not mutate the universe")

    var missingBuildingRuleSet = RuleSet.fastSkirmish
    missingBuildingRuleSet.buildingRules[.metalMine] = nil
    var missingBuildingRuleUniverse = makeQueueUniverse(ruleSet: missingBuildingRuleSet)
    let originalMissingBuildingRuleUniverse = missingBuildingRuleUniverse

    let missingBuildingRuleResult = QueueEngine.startBuildingUpgrade(
        on: queuePlanetID(),
        in: &missingBuildingRuleUniverse,
        kind: .metalMine
    )

    requireEqual(missingBuildingRuleResult, QueueResult.missingRule, "Building upgrade should report a missing rule")
    requireEqual(missingBuildingRuleUniverse, originalMissingBuildingRuleUniverse, "Missing building rule should not mutate the universe")

    var missingResearchRuleSet = RuleSet.fastSkirmish
    missingResearchRuleSet.researchRules[.computer] = nil
    var missingResearchRuleUniverse = makeQueueUniverse(ruleSet: missingResearchRuleSet)
    let originalMissingResearchRuleUniverse = missingResearchRuleUniverse

    let missingResearchRuleResult = QueueEngine.startResearch(
        for: queuePlayerID(),
        in: &missingResearchRuleUniverse,
        technology: .computer
    )

    requireEqual(missingResearchRuleResult, QueueResult.missingRule, "Research should report a missing rule")
    requireEqual(missingResearchRuleUniverse, originalMissingResearchRuleUniverse, "Missing research rule should not mutate the universe")
}

func testQueueEngineRejectsInvalidBuildingRuleValuesWithoutMutation() {
    var negativeCostRuleSet = RuleSet.fastSkirmish
    negativeCostRuleSet.buildingRules[.metalMine] = BuildingRule(
        baseCost: ResourceBundle(metal: -60, crystal: 15),
        costMultiplier: 1.5,
        baseDuration: 20,
        durationMultiplier: 1.3,
        productionPerHour: ResourceBundle(metal: 180),
        energyUsed: 10,
        aiPriorityWeight: 1
    )
    var negativeCostUniverse = makeQueueUniverse(
        resources: ResourceBundle(metal: 10, crystal: 100, deuterium: 10),
        ruleSet: negativeCostRuleSet
    )
    let originalNegativeCostUniverse = negativeCostUniverse

    let negativeCostResult = QueueEngine.startBuildingUpgrade(
        on: queuePlanetID(),
        in: &negativeCostUniverse,
        kind: .metalMine
    )

    requireEqual(negativeCostResult, QueueResult.missingRule, "Negative building costs should be rejected as invalid rules")
    requireEqual(negativeCostUniverse, originalNegativeCostUniverse, "Invalid negative building costs should not mutate the universe")

    var negativeMultiplierRuleSet = RuleSet.fastSkirmish
    negativeMultiplierRuleSet.buildingRules[.metalMine] = BuildingRule(
        baseCost: ResourceBundle(metal: 60, crystal: 15),
        costMultiplier: -1.5,
        baseDuration: 20,
        durationMultiplier: 1.3,
        productionPerHour: ResourceBundle(metal: 180),
        energyUsed: 10,
        aiPriorityWeight: 1
    )
    var negativeMultiplierUniverse = makeQueueUniverse(ruleSet: negativeMultiplierRuleSet)
    let originalNegativeMultiplierUniverse = negativeMultiplierUniverse

    let negativeMultiplierResult = QueueEngine.startBuildingUpgrade(
        on: queuePlanetID(),
        in: &negativeMultiplierUniverse,
        kind: .metalMine
    )

    requireEqual(negativeMultiplierResult, QueueResult.missingRule, "Negative building cost multipliers should be rejected as invalid rules")
    requireEqual(negativeMultiplierUniverse, originalNegativeMultiplierUniverse, "Invalid negative building multipliers should not mutate the universe")
}

func testQueueEngineRejectsInvalidResearchDurationWithoutMutation() {
    var invalidDurationRuleSet = RuleSet.fastSkirmish
    invalidDurationRuleSet.researchRules[.computer] = ResearchRule(
        baseCost: ResourceBundle(crystal: 400, deuterium: 600),
        costMultiplier: 2,
        baseDuration: 50,
        durationMultiplier: -.infinity,
        aiPriorityWeight: 0.65
    )
    var invalidDurationUniverse = makeQueueUniverse(ruleSet: invalidDurationRuleSet)
    let originalInvalidDurationUniverse = invalidDurationUniverse

    let invalidDurationResult = QueueEngine.startResearch(
        for: queuePlayerID(),
        in: &invalidDurationUniverse,
        technology: .computer
    )

    requireEqual(invalidDurationResult, QueueResult.missingRule, "Non-finite research duration multipliers should be rejected as invalid rules")
    requireEqual(invalidDurationUniverse, originalInvalidDurationUniverse, "Invalid research durations should not mutate the universe")
}

func testSimulationTickCompletesBuildingQueueRecomputesEnergyAndRecordsEvent() {
    var universe = makeQueueUniverse()

    requireEqual(
        QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &universe, kind: .solarPlant),
        QueueResult.queued,
        "Solar plant upgrade should queue before completion test"
    )

    SimulationEngine.tick(universe: &universe, delta: 18)

    requireEqual(universe.gameTime, 18, "Simulation tick should advance to the building finish time")
    requireEqual(universe.planets[0].buildQueue, [], "Completed building queue item should be removed")
    requireEqual(universe.planets[0].buildingLevels[.solarPlant], 1, "Completed building queue should raise the building level")
    requireEqual(
        universe.planets[0].energy,
        EnergyState(produced: 32, used: 0),
        "Completed building queue should recompute planet energy"
    )

    guard let completionEvent = universe.events.first(where: { $0.title == "Construction Complete" }) else {
        fatalError("Completing a building queue should record a construction event")
    }

    requireEqual(completionEvent.kind, .economy, "Construction completion event should be an economy event")
    requireEqual(completionEvent.time, 18, "Construction completion event should use the advanced game time")
    requireEqual(
        completionEvent.message,
        "Queue World completed solarPlant level 1.",
        "Construction completion event should describe the completed building deterministically"
    )
    requireEqual(universe.events.last?.title, "Simulation Advanced", "Simulation advanced event should remain the final tick event")
}

func testSimulationTickCompletesAlreadyDueConstructionBeforeProduction() {
    let playerID = queuePlayerID()
    let solarPlanetID = PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c7")!)
    let minePlanetID = PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c8")!)
    let solarCompletion = BuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000c9")!,
        planetID: solarPlanetID,
        buildingKind: .solarPlant,
        targetLevel: 1,
        startTime: 40,
        finishTime: 90,
        paidCost: ResourceBundle(metal: 75, crystal: 30)
    )
    let mineCompletion = BuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000ca")!,
        planetID: minePlanetID,
        buildingKind: .metalMine,
        targetLevel: 1,
        startTime: 50,
        finishTime: 100,
        paidCost: ResourceBundle(metal: 60, crystal: 15)
    )
    var universe = Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-0000000000cb")!),
        name: "Already Due Queue Test",
        seed: 3,
        gameTime: 120,
        playerFactionID: playerID,
        factions: [
            Faction(
                id: playerID,
                name: "Player",
                kind: .player,
                strategy: .balanced,
                ownedPlanetIDs: [solarPlanetID, minePlanetID]
            )
        ],
        planets: [
            Planet(
                id: solarPlanetID,
                name: "Solar Due",
                coordinate: Coordinate(galaxy: 1, system: 1, position: 5),
                ownerID: playerID,
                resources: .zero,
                storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
                buildingLevels: [.metalMine: 1],
                buildQueue: [solarCompletion]
            ),
            Planet(
                id: minePlanetID,
                name: "Mine Due",
                coordinate: Coordinate(galaxy: 1, system: 1, position: 6),
                ownerID: playerID,
                resources: .zero,
                storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
                buildingLevels: [.solarPlant: 1],
                buildQueue: [mineCompletion]
            )
        ],
        fleets: [],
        events: [],
        ruleSet: .fastSkirmish
    )

    SimulationEngine.tick(universe: &universe, delta: 3_600)

    requireEqual(universe.gameTime, 3_720, "Simulation tick should advance from the loaded game time")
    requireEqual(universe.planets[0].buildQueue, [], "Already-due solar completion should be removed before production")
    requireEqual(universe.planets[1].buildQueue, [], "Already-due mine completion should be removed before production")
    requireEqual(universe.planets[0].buildingLevels[.solarPlant], 1, "Already-due solar queue should raise solar level")
    requireEqual(universe.planets[1].buildingLevels[.metalMine], 1, "Already-due mine queue should raise mine level")
    requireEqual(universe.planets[0].energy, EnergyState(produced: 32, used: 10), "Already-due solar completion should update energy before production")
    requireApproxEqual(universe.planets[0].resources.metal, 180, "Solar completion should power existing mine production during the same tick")
    requireApproxEqual(universe.planets[1].resources.metal, 180, "Mine completion should produce during the same tick")

    let completionEvents = universe.events.filter { $0.title == "Construction Complete" }
    requireEqual(completionEvents.count, 2, "Already-due construction queues should record deterministic completion events")
    requireEqual(completionEvents.map(\.time), [90, 100], "Construction completion events should use queue finish times when possible")
    requireEqual(universe.events.last?.title, "Simulation Advanced", "Simulation advanced event should remain the final tick event")
}

func testQueueEngineStartsResearchAndPaysFromOwnedPlanet() {
    var universe = makeQueueUniverse(
        resources: ResourceBundle(metal: 1_000, crystal: 2_000, deuterium: 2_000),
        researchLevels: [.computer: 1]
    )

    let result = QueueEngine.startResearch(for: queuePlayerID(), in: &universe, technology: .computer)

    requireEqual(result, QueueResult.queued, "Affordable research should be queued")
    requireEqual(universe.factions[0].researchQueue.count, 1, "Research queue should contain the started research")

    let item = universe.factions[0].researchQueue[0]
    let expectedCost = ResourceBundle(metal: 0, crystal: 800, deuterium: 1_200)
    requireEqual(item.factionID, queuePlayerID(), "Research queue item should target the requested faction")
    requireEqual(item.technologyKind, .computer, "Research queue item should store the technology kind")
    requireEqual(item.targetLevel, 2, "Research queue item should target the next technology level")
    requireEqual(item.startTime, 0, "Research queue item should start at current game time")
    requireEqual(item.finishTime, 75, "Research queue item should finish after the level-scaled duration")
    requireEqual(item.paidCost, expectedCost, "Research queue item should store the paid cost")
    requireEqual(
        universe.planets[0].resources,
        ResourceBundle(metal: 1_000, crystal: 1_200, deuterium: 800),
        "Starting research should deduct the paid cost from the faction's owned planet"
    )
}

func testQueueEngineStartsShipBuildAndCompletesIntoInventory() {
    var universe = makeQueueUniverse(
        resources: ResourceBundle(metal: 10_000, crystal: 10_000, deuterium: 1_000),
        shipInventory: [.smallCargo: 1]
    )

    let result = QueueEngine.startShipBuild(on: queuePlanetID(), in: &universe, kind: .smallCargo, quantity: 3)

    requireEqual(result, QueueResult.queued, "Affordable ship build should be queued")
    requireEqual(universe.planets[0].shipBuildQueue.count, 1, "Ship build queue should contain the started order")

    let item = universe.planets[0].shipBuildQueue[0]
    let expectedCost = ResourceBundle(metal: 6_000, crystal: 6_000)
    requireEqual(item.planetID, queuePlanetID(), "Ship queue item should target the requested planet")
    requireEqual(item.unitKind, .ship(.smallCargo), "Ship queue item should store the ship kind")
    requireEqual(item.quantity, 3, "Ship queue item should store the requested quantity")
    requireEqual(item.startTime, 0, "Ship queue item should start at current game time")
    requireEqual(item.finishTime, 30, "Ship queue item should finish after quantity-scaled duration")
    requireEqual(item.paidCost, expectedCost, "Ship queue item should store the paid cost")
    requireEqual(
        universe.planets[0].resources,
        ResourceBundle(metal: 4_000, crystal: 4_000, deuterium: 1_000),
        "Starting a ship build should deduct the paid cost immediately"
    )

    SimulationEngine.tick(universe: &universe, delta: 30)

    requireEqual(universe.planets[0].shipBuildQueue, [], "Completed ship build queue item should be removed")
    requireEqual(universe.planets[0].shipInventory[.smallCargo], 4, "Completed ship build should increment ship inventory")

    guard let completionEvent = universe.events.first(where: { $0.title == "Ship Construction Complete" }) else {
        fatalError("Completing a ship build should record a ship construction event")
    }

    requireEqual(completionEvent.kind, .economy, "Ship construction completion event should be an economy event")
    requireEqual(completionEvent.time, 30, "Ship construction completion event should use the queue finish time")
    requireEqual(
        completionEvent.message,
        "Queue World completed 3 smallCargo.",
        "Ship construction completion event should describe the completed order deterministically"
    )
}

func testQueueEngineStartsDefenseBuildAndCompletesIntoInventory() {
    var universe = makeQueueUniverse(
        resources: ResourceBundle(metal: 10_000, crystal: 2_000, deuterium: 500),
        defenseInventory: [.rocketLauncher: 1]
    )

    let result = QueueEngine.startDefenseBuild(on: queuePlanetID(), in: &universe, kind: .rocketLauncher, quantity: 4)

    requireEqual(result, QueueResult.queued, "Affordable defense build should be queued")
    requireEqual(universe.planets[0].defenseBuildQueue.count, 1, "Defense build queue should contain the started order")

    let item = universe.planets[0].defenseBuildQueue[0]
    let expectedCost = ResourceBundle(metal: 8_000)
    requireEqual(item.planetID, queuePlanetID(), "Defense queue item should target the requested planet")
    requireEqual(item.unitKind, .defense(.rocketLauncher), "Defense queue item should store the defense kind")
    requireEqual(item.quantity, 4, "Defense queue item should store the requested quantity")
    requireEqual(item.startTime, 0, "Defense queue item should start at current game time")
    requireEqual(item.finishTime, 24, "Defense queue item should finish after quantity-scaled duration")
    requireEqual(item.paidCost, expectedCost, "Defense queue item should store the paid cost")
    requireEqual(
        universe.planets[0].resources,
        ResourceBundle(metal: 2_000, crystal: 2_000, deuterium: 500),
        "Starting a defense build should deduct the paid cost immediately"
    )

    SimulationEngine.tick(universe: &universe, delta: 24)

    requireEqual(universe.planets[0].defenseBuildQueue, [], "Completed defense build queue item should be removed")
    requireEqual(universe.planets[0].defenseInventory[.rocketLauncher], 5, "Completed defense build should increment defense inventory")

    guard let completionEvent = universe.events.first(where: { $0.title == "Defense Construction Complete" }) else {
        fatalError("Completing a defense build should record a defense construction event")
    }

    requireEqual(completionEvent.kind, .economy, "Defense construction completion event should be an economy event")
    requireEqual(completionEvent.time, 24, "Defense construction completion event should use the queue finish time")
    requireEqual(
        completionEvent.message,
        "Queue World completed 4 rocketLauncher.",
        "Defense construction completion event should describe the completed order deterministically"
    )
}

func testQueueEngineRejectsBusyUnitQueuesWithoutMutation() {
    let shipItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000d3")!,
        planetID: queuePlanetID(),
        unitKind: .ship(.smallCargo),
        quantity: 1,
        startTime: 0,
        finishTime: 10,
        paidCost: ResourceBundle(metal: 2_000, crystal: 2_000)
    )
    var shipUniverse = makeQueueUniverse(shipBuildQueue: [shipItem])
    let originalShipUniverse = shipUniverse

    let shipResult = QueueEngine.startShipBuild(on: queuePlanetID(), in: &shipUniverse, kind: .lightFighter, quantity: 1)

    requireEqual(shipResult, QueueResult.queueBusy, "Planet with an active ship queue should reject another ship build")
    requireEqual(shipUniverse, originalShipUniverse, "Busy ship queue rejection should not mutate the universe")

    let defenseItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000d4")!,
        planetID: queuePlanetID(),
        unitKind: .defense(.rocketLauncher),
        quantity: 1,
        startTime: 0,
        finishTime: 6,
        paidCost: ResourceBundle(metal: 2_000)
    )
    var defenseUniverse = makeQueueUniverse(defenseBuildQueue: [defenseItem])
    let originalDefenseUniverse = defenseUniverse

    let defenseResult = QueueEngine.startDefenseBuild(
        on: queuePlanetID(),
        in: &defenseUniverse,
        kind: .lightLaser,
        quantity: 1
    )

    requireEqual(defenseResult, QueueResult.queueBusy, "Planet with an active defense queue should reject another defense build")
    requireEqual(defenseUniverse, originalDefenseUniverse, "Busy defense queue rejection should not mutate the universe")
}

func testQueueEngineRejectsInvalidUnitRulesWithoutMutation() {
    var invalidShipRuleSet = RuleSet.fastSkirmish
    invalidShipRuleSet.shipRules[.smallCargo] = ShipRule(
        baseCost: ResourceBundle(metal: -2_000, crystal: 2_000),
        baseDuration: 10,
        aiPriorityWeight: 0.40
    )
    var invalidShipUniverse = makeQueueUniverse(ruleSet: invalidShipRuleSet)
    let originalInvalidShipUniverse = invalidShipUniverse

    let shipResult = QueueEngine.startShipBuild(on: queuePlanetID(), in: &invalidShipUniverse, kind: .smallCargo, quantity: 1)

    requireEqual(shipResult, QueueResult.missingRule, "Negative ship costs should be rejected as invalid rules")
    requireEqual(invalidShipUniverse, originalInvalidShipUniverse, "Invalid ship costs should not mutate the universe")

    var invalidDefenseRuleSet = RuleSet.fastSkirmish
    invalidDefenseRuleSet.defenseRules[.rocketLauncher] = DefenseRule(
        baseCost: ResourceBundle(metal: 2_000),
        baseDuration: .nan,
        aiPriorityWeight: 0.50
    )
    var invalidDefenseUniverse = makeQueueUniverse(ruleSet: invalidDefenseRuleSet)
    let originalInvalidDefenseUniverse = invalidDefenseUniverse

    let defenseResult = QueueEngine.startDefenseBuild(
        on: queuePlanetID(),
        in: &invalidDefenseUniverse,
        kind: .rocketLauncher,
        quantity: 1
    )

    requireEqual(defenseResult, QueueResult.missingRule, "Non-finite defense durations should be rejected as invalid rules")
    requireEqual(invalidDefenseUniverse, originalInvalidDefenseUniverse, "Invalid defense durations should not mutate the universe")
}

func testQueueCompletionPreservesMismatchedUnitQueueItemsWithoutMutation() {
    let mismatchedShipQueueItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000d5")!,
        planetID: queuePlanetID(),
        unitKind: .defense(.rocketLauncher),
        quantity: 1,
        startTime: 0,
        finishTime: 10,
        paidCost: ResourceBundle(metal: 2_000)
    )
    let mismatchedDefenseQueueItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000d6")!,
        planetID: queuePlanetID(),
        unitKind: .ship(.smallCargo),
        quantity: 1,
        startTime: 0,
        finishTime: 10,
        paidCost: ResourceBundle(metal: 2_000, crystal: 2_000)
    )
    var universe = makeQueueUniverse(
        gameTime: 10,
        shipBuildQueue: [mismatchedShipQueueItem],
        defenseBuildQueue: [mismatchedDefenseQueueItem]
    )

    QueueEngine.completeDueItems(in: &universe)

    requireEqual(
        universe.planets[0].shipBuildQueue,
        [mismatchedShipQueueItem],
        "Mismatched ship queue items should remain queued for inspection"
    )
    requireEqual(
        universe.planets[0].defenseBuildQueue,
        [mismatchedDefenseQueueItem],
        "Mismatched defense queue items should remain queued for inspection"
    )
    requireEqual(universe.planets[0].shipInventory, [:], "Mismatched unit items should not mutate ship inventory")
    requireEqual(universe.planets[0].defenseInventory, [:], "Mismatched unit items should not mutate defense inventory")
    requireEqual(universe.events, [], "Mismatched unit items should not emit completion events")
}

func testQueueCompletionPreservesInvalidUnitQuantitiesWithoutMutation() {
    let negativeShipQueueItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000d7")!,
        planetID: queuePlanetID(),
        unitKind: .ship(.smallCargo),
        quantity: -2,
        startTime: 0,
        finishTime: 10,
        paidCost: ResourceBundle(metal: 2_000, crystal: 2_000)
    )
    let overflowingDefenseQueueItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000d8")!,
        planetID: queuePlanetID(),
        unitKind: .defense(.rocketLauncher),
        quantity: 1,
        startTime: 0,
        finishTime: 10,
        paidCost: ResourceBundle(metal: 2_000)
    )
    var universe = makeQueueUniverse(
        gameTime: 10,
        shipBuildQueue: [negativeShipQueueItem],
        defenseBuildQueue: [overflowingDefenseQueueItem],
        shipInventory: [.smallCargo: 3],
        defenseInventory: [.rocketLauncher: Int.max]
    )

    QueueEngine.completeDueItems(in: &universe)

    requireEqual(
        universe.planets[0].shipBuildQueue,
        [negativeShipQueueItem],
        "Negative ship queue quantities should remain queued for inspection"
    )
    requireEqual(
        universe.planets[0].defenseBuildQueue,
        [overflowingDefenseQueueItem],
        "Overflowing defense queue quantities should remain queued for inspection"
    )
    requireEqual(
        universe.planets[0].shipInventory[.smallCargo],
        3,
        "Negative ship queue quantities should not reduce ship inventory"
    )
    requireEqual(
        universe.planets[0].defenseInventory[.rocketLauncher],
        Int.max,
        "Overflowing defense queue quantities should not mutate defense inventory"
    )
    requireEqual(universe.events, [], "Invalid unit quantities should not emit completion events")
}

func testSimulationTickCompletesResearchQueueAndRecordsEvent() {
    var universe = makeQueueUniverse()

    requireEqual(
        QueueEngine.startResearch(for: queuePlayerID(), in: &universe, technology: .computer),
        QueueResult.queued,
        "Computer research should queue before completion test"
    )

    SimulationEngine.tick(universe: &universe, delta: 50)

    requireEqual(universe.gameTime, 50, "Simulation tick should advance to the research finish time")
    requireEqual(universe.factions[0].researchQueue, [], "Completed research queue item should be removed")
    requireEqual(universe.factions[0].technology.levels[.computer], 1, "Completed research queue should raise the technology level")

    guard let completionEvent = universe.events.first(where: { $0.title == "Research Complete" }) else {
        fatalError("Completing a research queue should record a research event")
    }

    requireEqual(completionEvent.kind, .economy, "Research completion event should be an economy event")
    requireEqual(completionEvent.time, 50, "Research completion event should use the advanced game time")
    requireEqual(
        completionEvent.message,
        "Player completed computer level 1.",
        "Research completion event should describe the completed technology deterministically"
    )
    requireEqual(universe.events.last?.title, "Simulation Advanced", "Simulation advanced event should remain the final tick event")
}

func testQueueCompletionIsDeterministicAcrossSaveLoadEquality() throws {
    var original = makeQueueUniverse()
    requireEqual(
        QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &original, kind: .solarPlant),
        QueueResult.queued,
        "Building queue should start before deterministic completion test"
    )
    requireEqual(
        QueueEngine.startResearch(for: queuePlayerID(), in: &original, technology: .computer),
        QueueResult.queued,
        "Research queue should start before deterministic completion test"
    )

    let data = try JSONEncoder().encode(original)
    var decoded = try JSONDecoder().decode(Universe.self, from: data)

    SimulationEngine.tick(universe: &original, delta: 60)
    SimulationEngine.tick(universe: &decoded, delta: 60)

    requireEqual(decoded, original, "Queue completion should be deterministic across save/load boundaries")
    requireEqual(
        original.events.filter { $0.title == "Construction Complete" }.count,
        1,
        "Deterministic completion tick should record one construction completion"
    )
    requireEqual(
        original.events.filter { $0.title == "Research Complete" }.count,
        1,
        "Deterministic completion tick should record one research completion"
    )
}

func testEconomyProductionPerHourUsesMineLevelsAndEnergyRatio() {
    let playerID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!)
    let planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b2")!),
        name: "Balanced Mines",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
        ownerID: playerID,
        resources: .zero,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [
            .metalMine: 2,
            .crystalMine: 1,
            .deuteriumSynthesizer: 1,
            .solarPlant: 4
        ]
    )

    let production = EconomyEngine.productionPerHour(for: planet, ruleSet: .fastSkirmish)

    requireApproxEqual(
        production,
        ResourceBundle(metal: 180 * 2 * pow(1.12, 1), crystal: 120, deuterium: 72),
        "Economy production should scale base mine output by level and exponential growth"
    )
}

func testEconomyOneHourTickIncreasesOwnedPlanetResources() {
    let playerID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!)
    var planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b3")!),
        name: "Productive",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 5),
        ownerID: playerID,
        resources: ResourceBundle(metal: 100, crystal: 200, deuterium: 300),
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [
            .metalMine: 2,
            .crystalMine: 1,
            .deuteriumSynthesizer: 1,
            .solarPlant: 4
        ]
    )

    EconomyEngine.applyProduction(to: &planet, delta: 3_600, ruleSet: .fastSkirmish)

    requireApproxEqual(
        planet.resources,
        ResourceBundle(metal: 503.2, crystal: 320, deuterium: 372),
        "One-hour economy tick should add mine production to resources"
    )
}

func testEconomyProductionClampsToStorageCaps() {
    let playerID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!)
    var planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b4")!),
        name: "Capped",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 6),
        ownerID: playerID,
        resources: ResourceBundle(metal: 490, crystal: 490, deuterium: 490),
        storage: ResourceStorage(metal: 500, crystal: 510, deuterium: 520),
        buildingLevels: [
            .metalMine: 3,
            .crystalMine: 3,
            .deuteriumSynthesizer: 3,
            .solarPlant: 8
        ]
    )

    EconomyEngine.applyProduction(to: &planet, delta: 3_600, ruleSet: .fastSkirmish)

    requireEqual(
        planet.resources,
        ResourceBundle(metal: 500, crystal: 510, deuterium: 520),
        "Economy production should clamp resources to storage caps"
    )
}

func testEconomyEnergyShortageReducesMineOutput() {
    let playerID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!)
    let planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b5")!),
        name: "Power Starved",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 7),
        ownerID: playerID,
        resources: .zero,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [
            .metalMine: 2,
            .crystalMine: 2,
            .solarPlant: 1
        ]
    )

    let production = EconomyEngine.productionPerHour(for: planet, ruleSet: .fastSkirmish)

    requireApproxEqual(
        production,
        ResourceBundle(metal: 322.56, crystal: 215.04, deuterium: 0),
        "Energy shortage should reduce mine output by the produced-over-used energy ratio"
    )
}

func testEconomyRecomputesSolarEnergyProducedAndMineEnergyUsed() {
    let playerID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!)
    var planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b6")!),
        name: "Solar Refit",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 8),
        ownerID: playerID,
        resources: .zero,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        energy: EnergyState(produced: 1, used: 1),
        buildingLevels: [
            .metalMine: 2,
            .crystalMine: 1,
            .deuteriumSynthesizer: 1,
            .solarPlant: 3
        ]
    )

    EconomyEngine.recomputeEnergy(for: &planet, ruleSet: .fastSkirmish)

    requireEqual(
        planet.energy,
        EnergyState(produced: 96, used: 46),
        "Economy energy recomputation should derive produced and used energy from current building levels"
    )
}

func testEconomyUniverseTickDoesNotProduceOnNonOwnedPlanets() {
    let playerID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!)
    let ownedPlanet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b7")!),
        name: "Owned",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 9),
        ownerID: playerID,
        resources: .zero,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.metalMine: 1, .solarPlant: 1]
    )
    let unownedPlanet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b8")!),
        name: "Unowned",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 10),
        ownerID: nil,
        resources: .zero,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.metalMine: 5, .solarPlant: 5]
    )
    var universe = makeEconomyUniverse(planets: [ownedPlanet, unownedPlanet])

    EconomyEngine.tick(universe: &universe, delta: 3_600)

    requireApproxEqual(universe.planets[0].resources.metal, 180, "Owned planet should produce resources")
    requireEqual(universe.planets[1].resources, .zero, "Non-owned planet should not produce resources")
}

func testSimulationTickEmitsAtMostOneEconomySummaryEventPerTick() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 14, playerName: "Commander")

    SimulationEngine.tick(universe: &universe, delta: 60)

    let economyEvents = universe.events.filter { $0.kind == .economy }
    requireEqual(economyEvents.count, 1, "Simulation tick should emit at most one economy summary event")
    requireEqual(economyEvents[0].title, "Economy Updated", "Economy summary should have a deterministic title")
    requireEqual(economyEvents[0].time, universe.gameTime, "Economy summary event should use advanced game time")
    requireEqual(universe.events.last?.title, "Simulation Advanced", "Simulation advanced event should remain the final tick event")
}

func testSimulationTickAdvancesGameTimeAndRecordsEvent() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 9, playerName: "Commander")
    let previousEventCount = universe.events.count

    SimulationEngine.tick(universe: &universe, delta: 60)

    requireEqual(universe.gameTime, 60, "Simulation tick should advance game time")
    requireEqual(universe.events.count, previousEventCount + 2, "Simulation tick should append economy and system events")
    requireEqual(universe.events.last?.kind, .system, "Simulation tick should record a system event")
    requireEqual(universe.events.last?.title, "Simulation Advanced", "Simulation tick should record an event")
    requireEqual(universe.events.last?.time, universe.gameTime, "Simulation tick event should use advanced time")
}

func testSimulationTickIgnoresNonPositiveDeltas() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 10, playerName: "Commander")
    let originalGameTime = universe.gameTime
    let originalEvents = universe.events

    SimulationEngine.tick(universe: &universe, delta: 0)
    SimulationEngine.tick(universe: &universe, delta: -30)

    requireEqual(universe.gameTime, originalGameTime, "Simulation tick should ignore non-positive deltas")
    requireEqual(universe.events, originalEvents, "Simulation tick should not record events for non-positive deltas")
}

func testSimulationTickIgnoresNonFiniteDeltas() {
    var infiniteUniverse = StarterUniverseFactory.makeNewGame(seed: 11, playerName: "Commander")
    let originalInfiniteGameTime = infiniteUniverse.gameTime
    let originalInfiniteEvents = infiniteUniverse.events

    SimulationEngine.tick(universe: &infiniteUniverse, delta: .infinity)

    requireEqual(infiniteUniverse.gameTime, originalInfiniteGameTime, "Simulation tick should ignore infinite deltas")
    requireEqual(infiniteUniverse.events, originalInfiniteEvents, "Simulation tick should not record events for infinite deltas")

    var nanUniverse = StarterUniverseFactory.makeNewGame(seed: 12, playerName: "Commander")
    let originalNaNGameTime = nanUniverse.gameTime
    let originalNaNEvents = nanUniverse.events

    SimulationEngine.tick(universe: &nanUniverse, delta: .nan)

    requireEqual(nanUniverse.gameTime, originalNaNGameTime, "Simulation tick should ignore NaN deltas")
    requireEqual(nanUniverse.events, originalNaNEvents, "Simulation tick should not record events for NaN deltas")
}

func testSimulationTickAcceptsHugeFinitePositiveDeltas() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 13, playerName: "Commander")
    let previousEventCount = universe.events.count
    let delta = TimeInterval.greatestFiniteMagnitude

    SimulationEngine.tick(universe: &universe, delta: delta)

    requireEqual(universe.gameTime, delta, "Simulation tick should advance by huge finite positive deltas")
    requireEqual(universe.events.count, previousEventCount + 2, "Simulation tick should append economy and system events for huge finite deltas")
    requireEqual(universe.events.last?.title, "Simulation Advanced", "Simulation tick should record huge finite delta advancement")
    requireEqual(universe.events.last?.time, universe.gameTime, "Simulation tick event should use advanced huge finite time")
    requireEqual(
        universe.events.last?.message,
        "Advanced the universe by \(delta) seconds.",
        "Simulation tick should format huge finite delta messages without integer conversion"
    )
}

func testOfflineCatchUpUsesBoundedChunksAndMinimumChunkInterval() {
    let now = Date(timeIntervalSince1970: 1_000)
    var boundedUniverse = makeQueueUniverse(ruleSet: fastSkirmishRules(offlineChunkInterval: 120))

    let boundedSummary = OfflineSimulationEngine.catchUp(
        universe: &boundedUniverse,
        elapsed: 500,
        now: now
    )

    requireEqual(boundedSummary.elapsedSeconds, 500, "Offline catch-up should process the requested elapsed time")
    requireEqual(boundedSummary.processedChunks, 5, "Offline catch-up should split elapsed time into bounded chunks and one remainder")
    requireEqual(boundedUniverse.gameTime, 500, "Offline catch-up chunks should advance the universe by the full capped elapsed time")
    requireEqual(boundedUniverse.lastSimulatedWallClockTime, now, "Offline catch-up should store the wall-clock time it caught up to")

    var minimumUniverse = makeQueueUniverse(ruleSet: fastSkirmishRules(offlineChunkInterval: 10))
    let minimumSummary = OfflineSimulationEngine.catchUp(
        universe: &minimumUniverse,
        elapsed: 150,
        now: now
    )

    requireEqual(minimumSummary.processedChunks, 3, "Offline catch-up should clamp chunk interval to at least sixty seconds")
    requireEqual(minimumUniverse.gameTime, 150, "Minimum chunk interval should still process the exact elapsed time")
}

func testOfflineCatchUpProducesResourcesWithoutFloodingEvents() {
    let playerID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000d1")!)
    let planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000d2")!),
        name: "Offline Mine",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 11),
        ownerID: playerID,
        resources: .zero,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.metalMine: 1, .solarPlant: 1]
    )
    var universe = makeEconomyUniverse(
        planets: [planet],
        factions: [
            Faction(
                id: playerID,
                name: "Player",
                kind: .player,
                strategy: .balanced,
                ownedPlanetIDs: [planet.id]
            )
        ]
    )
    universe.ruleSet = fastSkirmishRules(offlineChunkInterval: 300)

    let summary = OfflineSimulationEngine.catchUp(
        universe: &universe,
        elapsed: 3_600,
        now: Date(timeIntervalSince1970: 2_000)
    )

    requireApproxEqual(universe.planets[0].resources.metal, 180, "Offline catch-up should produce owned-planet resources")
    requireEqual(summary.processedChunks, 12, "One hour at five-minute offline chunks should process twelve chunks")
    requireEqual(summary.completedConstructionCount, 0, "Resource-only catch-up should not report construction completions")
    requireEqual(summary.completedResearchCount, 0, "Resource-only catch-up should not report research completions")
    requireEqual(summary.generatedEventCount, 24, "Offline catch-up should count per-chunk economy and simulation events")
    requireEqual(summary.recordedEventCount, 1, "Offline catch-up should record one final summary event")
    requireEqual(universe.events.count, 1, "Offline catch-up should squash per-chunk events into one feed item")
    requireEqual(universe.events[0].title, "Offline Catch-Up Complete", "Offline catch-up should record a deterministic summary title")
}

func testOfflineCatchUpCompletesQueuesAndSummarizesCompletionCounts() {
    var universe = makeQueueUniverse(ruleSet: fastSkirmishRules(offlineChunkInterval: 300))
    requireEqual(
        QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &universe, kind: .solarPlant),
        QueueResult.queued,
        "Building queue should start before offline completion test"
    )
    requireEqual(
        QueueEngine.startResearch(for: queuePlayerID(), in: &universe, technology: .computer),
        QueueResult.queued,
        "Research queue should start before offline completion test"
    )

    let summary = OfflineSimulationEngine.catchUp(
        universe: &universe,
        elapsed: 60,
        now: Date(timeIntervalSince1970: 3_000)
    )

    requireEqual(universe.planets[0].buildQueue, [], "Offline catch-up should remove completed construction queue items")
    requireEqual(universe.factions[0].researchQueue, [], "Offline catch-up should remove completed research queue items")
    requireEqual(universe.planets[0].buildingLevels[.solarPlant], 1, "Offline catch-up should apply completed construction levels")
    requireEqual(universe.factions[0].technology.levels[.computer], 1, "Offline catch-up should apply completed research levels")
    requireEqual(summary.completedConstructionCount, 1, "Offline catch-up summary should count completed construction")
    requireEqual(summary.completedResearchCount, 1, "Offline catch-up summary should count completed research")
    requireEqual(summary.generatedEventCount, 4, "Offline catch-up should count completion, economy, and simulation events generated by ticks")
    requireEqual(universe.events.map(\.title), ["Offline Catch-Up Complete"], "Offline catch-up should leave only the final summary event")
    require(universe.events[0].message.contains("1 construction"), "Offline summary event should describe construction completions")
    require(universe.events[0].message.contains("1 research"), "Offline summary event should describe research completions")
}

func testOfflineCatchUpCompletesUnitQueuesAndSummarizesConstructionCounts() {
    var universe = makeQueueUniverse(ruleSet: fastSkirmishRules(offlineChunkInterval: 300))
    requireEqual(
        QueueEngine.startShipBuild(on: queuePlanetID(), in: &universe, kind: .smallCargo, quantity: 1),
        QueueResult.queued,
        "Ship queue should start before offline unit completion test"
    )
    requireEqual(
        QueueEngine.startDefenseBuild(on: queuePlanetID(), in: &universe, kind: .rocketLauncher, quantity: 1),
        QueueResult.queued,
        "Defense queue should start before offline unit completion test"
    )

    let summary = OfflineSimulationEngine.catchUp(
        universe: &universe,
        elapsed: 60,
        now: Date(timeIntervalSince1970: 3_600)
    )

    requireEqual(universe.planets[0].shipBuildQueue, [], "Offline catch-up should remove completed ship queue items")
    requireEqual(universe.planets[0].defenseBuildQueue, [], "Offline catch-up should remove completed defense queue items")
    requireEqual(universe.planets[0].shipInventory[.smallCargo], 1, "Offline catch-up should apply completed ship inventory")
    requireEqual(universe.planets[0].defenseInventory[.rocketLauncher], 1, "Offline catch-up should apply completed defense inventory")
    requireEqual(summary.completedConstructionCount, 2, "Offline catch-up summary should count completed ship and defense construction")
    requireEqual(summary.completedResearchCount, 0, "Offline unit completion should not report research completions")
    requireEqual(summary.generatedEventCount, 4, "Offline unit catch-up should count unit completions, economy, and simulation events")
    requireEqual(universe.events.map(\.title), ["Offline Catch-Up Complete"], "Offline unit catch-up should squash generated events")
    require(universe.events[0].message.contains("2 construction"), "Offline summary event should describe unit construction completions")
}

func testOfflineCatchUpIgnoresInvalidElapsedValues() {
    let invalidElapsedValues: [TimeInterval] = [0, -1, .infinity, -.infinity, .nan]

    for elapsed in invalidElapsedValues {
        var universe = StarterUniverseFactory.makeNewGame(seed: 15, playerName: "Commander")
        let originalUniverse = universe

        let summary = OfflineSimulationEngine.catchUp(
            universe: &universe,
            elapsed: elapsed,
            now: Date(timeIntervalSince1970: 4_000)
        )

        requireEqual(universe, originalUniverse, "Offline catch-up should ignore invalid elapsed value \(elapsed)")
        requireEqual(summary.elapsedSeconds, 0, "Invalid elapsed values should return a zero elapsed summary")
        requireEqual(summary.processedChunks, 0, "Invalid elapsed values should not process chunks")
        requireEqual(summary.generatedEventCount, 0, "Invalid elapsed values should not generate events")
        requireEqual(summary.recordedEventCount, 0, "Invalid elapsed values should not record summary events")
        requireEqual(summary.didMutate, false, "Invalid elapsed values should report no mutation")
    }
}

func testOfflineCatchUpCapsHugeElapsedValuesToOneDay() {
    var universe = makeQueueUniverse(ruleSet: fastSkirmishRules(offlineChunkInterval: 3_600))

    let summary = OfflineSimulationEngine.catchUp(
        universe: &universe,
        elapsed: TimeInterval.greatestFiniteMagnitude,
        now: Date(timeIntervalSince1970: 5_000)
    )

    requireEqual(summary.elapsedSeconds, 86_400, "Offline catch-up should cap huge elapsed values to twenty-four hours")
    requireEqual(summary.processedChunks, 24, "Offline catch-up should process the capped day in hourly chunks")
    requireEqual(universe.gameTime, 86_400, "Offline catch-up should advance only the capped elapsed time")
    requireEqual(summary.didMutate, true, "Capped positive elapsed catch-up should report mutation")
}

func testOfflineCatchUpSummaryIsCodableEquatableAndDeterministic() throws {
    var first = makeQueueUniverse(ruleSet: fastSkirmishRules(offlineChunkInterval: 60))
    requireEqual(
        QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &first, kind: .solarPlant),
        QueueResult.queued,
        "Building queue should start before summary determinism test"
    )
    let data = try JSONEncoder().encode(first)
    var second = try JSONDecoder().decode(Universe.self, from: data)
    let now = Date(timeIntervalSince1970: 6_000)

    let firstSummary = OfflineSimulationEngine.catchUp(universe: &first, elapsed: 60, now: now)
    let secondSummary = OfflineSimulationEngine.catchUp(universe: &second, elapsed: 60, now: now)
    let summaryData = try JSONEncoder().encode(firstSummary)
    let decodedSummary = try JSONDecoder().decode(OfflineCatchUpSummary.self, from: summaryData)

    requireEqual(firstSummary, secondSummary, "Offline catch-up summaries should be deterministic across save/load equality")
    requireEqual(decodedSummary, firstSummary, "Offline catch-up summary should round-trip through JSON")
    requireEqual(first, second, "Offline catch-up events should be deterministic across save/load equality")
    requireEqual(firstSummary.elapsedSeconds, 60, "Offline catch-up summary should expose elapsed seconds")
    requireEqual(firstSummary.processedChunks, 1, "Offline catch-up summary should expose processed chunks")
    requireEqual(firstSummary.completedConstructionCount, 1, "Offline catch-up summary should expose completed construction count")
    requireEqual(firstSummary.completedResearchCount, 0, "Offline catch-up summary should expose completed research count")
    require(firstSummary.generatedEventCount > firstSummary.recordedEventCount, "Offline catch-up summary should expose squashed event counts")
    requireEqual(firstSummary.didMutate, true, "Offline catch-up summary should expose whether catch-up mutated the universe")
}

try testEntityIDsAreCodableAndEquatable()
testResourceBundleClampsToStorageLimits()
testResourceBundleDoesNotClampBelowZeroWhenStorageIsInvalid()
testResourceBundleArithmeticAndAffordabilityHelpers()
testResourceStorageConvertsToResourceDisplayBundle()
testFastSkirmishBuildingRulesCoverEarlyEconomy()
testFastSkirmishResearchRulesCoverEarlyTechnologies()
testFastSkirmishUnitRulesCoverShipsAndDefenses()
try testRuleSetBalanceRulesUseRawValueKeyedJSONObjects()
try testRuleSetDecodesOlderJSONWithFastSkirmishBalanceDefaults()
try testBuildQueueItemRoundTripsThroughJSON()
try testResearchQueueItemRoundTripsThroughJSON()
try testUnitBuildQueueItemRoundTripsThroughJSON()
try testPlanetFactionAndUniverseQueuesRoundTripThroughJSON()
try testQueueFieldsDefaultWhenDecodingOlderUniverseJSON()
testQueueFieldsRejectExplicitNullWhenDecodingJSON()
try testUniverseModelRoundTripsThroughJSON()
try testPlanetEnumDictionaryDecodesRawValueKeysAndRejectsUnknownKeys()
testSeededGeneratorProducesDeterministicDistinctSequences()
testSeededGeneratorEqualityTracksSeedAndState()
testSeededGeneratorNextIntRespectsClosedRanges()
try testStarterUniverseIsDeterministicForSeed()
testEconomyProductionPerHourUsesMineLevelsAndEnergyRatio()
testEconomyOneHourTickIncreasesOwnedPlanetResources()
testEconomyProductionClampsToStorageCaps()
testEconomyEnergyShortageReducesMineOutput()
testEconomyRecomputesSolarEnergyProducedAndMineEnergyUsed()
testEconomyUniverseTickDoesNotProduceOnNonOwnedPlanets()
testQueueEngineStartsBuildingUpgradeAndPaysCost()
testQueueEngineRejectsUnaffordableBuildingAndResearchWithoutMutation()
testQueueEngineRejectsBusyBuildingAndResearchQueuesWithoutMutation()
testQueueEngineReportsMissingEntitiesAndRulesWithoutMutation()
testQueueEngineRejectsInvalidBuildingRuleValuesWithoutMutation()
testQueueEngineRejectsInvalidResearchDurationWithoutMutation()
testAIEconomyQueuesOneAffordableUpgradePerAIFaction()
testAIEconomyStrategyPrioritiesChooseDistinctEarlyGrowthPaths()
testAIEconomyResearchPreviewUsesQueueEnginePaymentPlanetOrder()
testAIEconomyDoesNotMutatePlayerState()
try testAIEconomyDecisionsAreDeterministicForSameSeedTimeAndState()
testOfflineCatchUpTriggersAIEconomyDecisionsAtBoundedIntervals()
testSimulationTickCompletesBuildingQueueRecomputesEnergyAndRecordsEvent()
testSimulationTickCompletesAlreadyDueConstructionBeforeProduction()
testQueueEngineStartsResearchAndPaysFromOwnedPlanet()
testQueueEngineStartsShipBuildAndCompletesIntoInventory()
testQueueEngineStartsDefenseBuildAndCompletesIntoInventory()
testQueueEngineRejectsBusyUnitQueuesWithoutMutation()
testQueueEngineRejectsInvalidUnitRulesWithoutMutation()
testQueueCompletionPreservesMismatchedUnitQueueItemsWithoutMutation()
testQueueCompletionPreservesInvalidUnitQuantitiesWithoutMutation()
testFastSkirmishFleetRulesCoverAllShips()
try testLegacyFullShipRulesDecodeWithFleetDefaultsByShipKind()
testFleetLaunchRemovesShipsCargoAndFuelFromOrigin()
testIdenticalFleetLaunchesInSameTickUseDistinctIDs()
testInvalidFleetLaunchFailsWithoutMutation()
testFleetTravelTimeIsDeterministicFromCoordinatesAndSpeedRules()
testTransportMissionDeliversCargoAndReturnsShips()
testLargeSimulationTickCompletesOutboundArrivalAndReturnTogether()
testTransportOverflowCargoStaysWithReturningFleet()
testReturningFleetDoesNotLoseCargoWhenOriginStorageIsFull()
testRecycleMissionCollectsDebrisFromTargetPlanet()
try testExploreMissionCreatesDeterministicEventAndReward()
testColonizeMissionClaimsUnownedPlanetWhenColonyShipIsPresent()
testFleetReturnsRestoreShipsAndCargoToOrigin()
testSimulationTickResolvesDueFleetArrivalsBeforeSystemEvent()
testSimulationTickCompletesResearchQueueAndRecordsEvent()
try testQueueCompletionIsDeterministicAcrossSaveLoadEquality()
testSimulationTickEmitsAtMostOneEconomySummaryEventPerTick()
testSimulationTickAdvancesGameTimeAndRecordsEvent()
testSimulationTickIgnoresNonPositiveDeltas()
testSimulationTickIgnoresNonFiniteDeltas()
testSimulationTickAcceptsHugeFinitePositiveDeltas()
testOfflineCatchUpUsesBoundedChunksAndMinimumChunkInterval()
testOfflineCatchUpProducesResourcesWithoutFloodingEvents()
testOfflineCatchUpCompletesQueuesAndSummarizesCompletionCounts()
testOfflineCatchUpCompletesUnitQueuesAndSummarizesConstructionCounts()
testOfflineCatchUpIgnoresInvalidElapsedValues()
testOfflineCatchUpCapsHugeElapsedValuesToOneDay()
try testOfflineCatchUpSummaryIsCodableEquatableAndDeterministic()
print("OGameCoreTests passed")
