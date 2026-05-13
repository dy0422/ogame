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

func requireRelation(
    from factionID: FactionID,
    toward otherFactionID: FactionID,
    in universe: Universe,
    _ message: String
) -> FactionRelation {
    let faction = requireFaction(factionID, in: universe, "\(message) source faction")
    guard let relation = faction.relations.first(where: { $0.factionID == otherFactionID }) else {
        fatalError(message)
    }

    return relation
}

func resourceTotal(_ resources: ResourceBundle) -> Double {
    resources.metal + resources.crystal + resources.deuterium
}

func testCargoCapacity(_ ships: [ShipKind: Int], ruleSet: RuleSet) -> Double {
    ships.reduce(0) { total, element in
        let rule = ruleSet.shipRules[element.key]
        return total + ((rule?.cargoCapacity ?? 0) * Double(max(element.value, 0)))
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
        require(rule.attack >= 0, "Defense \(defense.rawValue) should have nonnegative attack")
        require(rule.shield >= 0, "Defense \(defense.rawValue) should have nonnegative shield")
        require(rule.hull >= 0, "Defense \(defense.rawValue) should have nonnegative hull")
    }

    require((defenseRules[.rocketLauncher]?.attack ?? 0) > 0, "Rocket launcher should contribute attack to combat")
}

func testGameContentUsesChineseDisplayNames() {
    requireEqual(BuildingKind.metalMine.localizedName, "金属矿", "Building names should be shown in Chinese")
    requireEqual(TechnologyKind.hyperspaceDrive.localizedName, "超空间引擎", "Technology names should be shown in Chinese")
    requireEqual(ShipKind.smallCargo.localizedName, "小型运输舰", "Ship names should be shown in Chinese")
    requireEqual(DefenseKind.rocketLauncher.localizedName, "火箭发射器", "Defense names should be shown in Chinese")
    requireEqual(MissileKind.interplanetaryMissile.localizedName, "星际导弹", "Missile names should be shown in Chinese")
    requireEqual(Fleet.Mission.attack.localizedName, "攻击", "Mission names should be shown in Chinese")
    requireEqual(VictoryRoute.technology.localizedName, "科技", "Victory routes should be shown in Chinese")
    requireEqual(Faction.Strategy.raider.localizedName, "掠袭者", "Faction strategies should be shown in Chinese")
    requireEqual(RelationPosture.hostile.localizedName, "敌对", "Relation postures should be shown in Chinese")
}

func testGameContentExplainsBuildingAndTechnologyEffects() {
    for building in BuildingKind.allCases {
        require(
            building.effectDescription.count >= 8,
            "\(building.rawValue) should have a useful Chinese effect description"
        )
        require(
            !building.effectDescription.contains(building.rawValue),
            "\(building.rawValue) description should not fall back to raw values"
        )
    }

    for technology in TechnologyKind.allCases {
        require(
            technology.effectDescription.count >= 8,
            "\(technology.rawValue) should have a useful Chinese effect description"
        )
        require(
            !technology.effectDescription.contains(technology.rawValue),
            "\(technology.rawValue) description should not fall back to raw values"
        )
    }

    require(BuildingKind.metalMine.effectDescription.contains("金属"), "Metal mine should explain metal production")
    require(BuildingKind.shipyard.effectDescription.contains("舰船"), "Shipyard should explain ship construction")
    require(BuildingKind.researchLab.effectDescription.contains("研究"), "Research lab should explain research usage")
    require(TechnologyKind.espionage.effectDescription.contains("侦察"), "Espionage should explain scouting")
    require(TechnologyKind.combustionDrive.effectDescription.contains("航速"), "Drive tech should explain travel speed")
}

func testTechnologyEffectsExposeFleetSlotsAndDriveSpeed() {
    let research = ResearchState(levels: [.computer: 3, .combustionDrive: 4])
    requireEqual(TechnologyEffects.maxFleetSlots(for: research), 4, "Computer level 3 should allow four active fleet slots")

    let base = RuleSet.fastSkirmish.shipRules[.smallCargo]?.speed ?? 0
    let speed = TechnologyEffects.effectiveSpeed(for: .smallCargo, baseSpeed: base, research: research)
    require(speed > base, "Combustion drive should increase small cargo speed")
}

func testResearchLabSpeedsResearchDuration() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 101, playerName: "指挥官")
    universe.planets[0].resources = ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000)
    universe.planets[0].buildingLevels[.researchLab] = 4

    let result = QueueEngine.startResearch(for: universe.playerFactionID, in: &universe, technology: .energy)

    requireEqual(result, .queued, "Energy research should queue")
    let queued = universe.factions[0].researchQueue[0]
    let baseDuration = RuleSet.fastSkirmish.researchRules[.energy]?.baseDuration ?? 0
    require(queued.finishTime - queued.startTime < baseDuration, "Research lab should reduce research duration")
}

func testFleetDecodesMissingSpeedPercentAsFullSpeed() throws {
    let json = """
    {
      "id": { "rawValue": "00000000-0000-0000-0000-000000010001" },
      "ownerID": { "rawValue": "00000000-0000-0000-0000-000000010002" },
      "mission": "transport",
      "origin": { "galaxy": 1, "system": 1, "position": 4 },
      "target": { "galaxy": 1, "system": 2, "position": 4 },
      "ships": { "smallCargo": 1 },
      "cargo": { "metal": 0, "crystal": 0, "deuterium": 0 },
      "launchTime": 0,
      "arrivalTime": 10,
      "returnTime": 20,
      "phase": "outbound"
    }
    """.data(using: .utf8)!
    let fleet = try JSONDecoder().decode(Fleet.self, from: json)

    requireApproxEqual(fleet.speedPercent, 1, "Old fleets should default to full speed")
    requireEqual(fleet.recalledAt, nil, "Old fleets should default to unrecalled")
}

func testFleetCommanderIDDefaultsWhenDecodingOlderFleetJSON() throws {
    let fleet = Fleet(
        ownerID: FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000101")!),
        mission: .transport,
        origin: Coordinate(galaxy: 1, system: 1, position: 4),
        target: Coordinate(galaxy: 1, system: 2, position: 4),
        ships: [.smallCargo: 1],
        launchTime: 0,
        arrivalTime: 60,
        returnTime: 120
    )
    let data = try JSONEncoder().encode(fleet)
    var json = try requireDictionary(JSONSerialization.jsonObject(with: data), "Fleet should encode as a dictionary")
    json.removeValue(forKey: "commanderID")
    let legacyData = try JSONSerialization.data(withJSONObject: json)
    let decoded = try JSONDecoder().decode(Fleet.self, from: legacyData)

    requireEqual(decoded.commanderID, nil, "Older fleet JSON should default missing commander assignment to nil")
}

func testAutomationPolicyDefaultsToBalancedEconomySafeMode() {
    let policy = AutoUpgradePolicy()

    requireEqual(policy.strategy, .balanced, "Default automation should be balanced")
    requireApproxEqual(policy.resourceReserveRatio, 0.15, "Default automation should preserve a small reserve")
    requireEqual(policy.allowShipConstruction, false, "Default automation should not unexpectedly build fleets")
}

func testAutoUpgradeEconomyStrategyFillsMultipleBuildQueueItems() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 201, playerName: "指挥官")
    universe.planets[0].resources = ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000)
    let policy = AutoUpgradePolicy(strategy: .economy, maxBuildQueueDepthPerPlanet: 3)

    let result = PlayerAutoUpgradeEngine.makeDecisions(in: &universe, policy: policy)

    require(result.queuedBuildings >= 2, "Economy automation should fill more than one building queue slot")
    require(universe.planets[0].buildQueue.count <= 3, "Automation should respect build queue depth")
}

func testAutoUpgradeFleetStrategyCanBuildShipsWhenAllowed() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 202, playerName: "指挥官")
    universe.planets[0].resources = ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000)
    universe.planets[0].buildingLevels[.roboticsFactory] = 1
    universe.planets[0].buildingLevels[.shipyard] = 1
    let policy = AutoUpgradePolicy(strategy: .fleet, allowShipConstruction: true)

    _ = PlayerAutoUpgradeEngine.makeDecisions(in: &universe, policy: policy)

    require(universe.planets[0].shipBuildQueue.isEmpty == false, "Fleet automation should queue ships")
}

func testAutoUpgradeRespectsResourceReserveRatio() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 203, playerName: "指挥官")
    let startingResources = ResourceBundle(metal: 100, crystal: 100, deuterium: 100)
    universe.planets[0].resources = startingResources
    let policy = AutoUpgradePolicy(
        strategy: .economy,
        resourceReserveRatio: 0.8,
        maxBuildQueueDepthPerPlanet: 3,
        maxResearchQueueDepth: 3
    )

    let result = PlayerAutoUpgradeEngine.makeDecisions(in: &universe, policy: policy)

    requireEqual(result, PlayerAutoUpgradeResult(), "Automation should skip spending that would break the reserve")
    requireEqual(universe.planets[0].resources, startingResources, "Automation should preserve reserved resources")
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
    let missileItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000085")!,
        planetID: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-000000000083")!),
        unitKind: .missile(.interplanetaryMissile),
        quantity: 2,
        startTime: 170,
        finishTime: 200,
        paidCost: ResourceBundle(metal: 5_000, crystal: 2_000, deuterium: 4_000)
    )

    let shipData = try JSONEncoder().encode(shipItem)
    let defenseData = try JSONEncoder().encode(defenseItem)
    let missileData = try JSONEncoder().encode(missileItem)

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
    requireEqual(
        try JSONDecoder().decode(UnitBuildQueueItem.self, from: missileData),
        missileItem,
        "Missile unit queue item should round-trip through JSON"
    )

    let shipJSON = requireDictionary(try JSONSerialization.jsonObject(with: shipData), "Ship unit queue item should encode as an object")
    let defenseJSON = requireDictionary(try JSONSerialization.jsonObject(with: defenseData), "Defense unit queue item should encode as an object")
    let missileJSON = requireDictionary(try JSONSerialization.jsonObject(with: missileData), "Missile unit queue item should encode as an object")
    requireEqual(shipJSON["unitType"] as? String, "ship", "Ship queue unit type should encode by raw value")
    requireEqual(shipJSON["unitKind"] as? String, "smallCargo", "Ship queue unit kind should encode by raw value")
    requireEqual(defenseJSON["unitType"] as? String, "defense", "Defense queue unit type should encode by raw value")
    requireEqual(defenseJSON["unitKind"] as? String, "rocketLauncher", "Defense queue unit kind should encode by raw value")
    requireEqual(missileJSON["unitType"] as? String, "missile", "Missile queue unit type should encode by raw value")
    requireEqual(missileJSON["unitKind"] as? String, "interplanetaryMissile", "Missile queue unit kind should encode by raw value")
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
    requireEqual(decoded.reports, [], "Older universe JSON should default missing reports to empty")
    requireEqual(decoded.playerObjectiveRecords, [], "Older universe JSON should default missing player objective records to empty")
    requireEqual(decoded.sectorEvents, [], "Older universe JSON should default missing sector events to empty")
    requireEqual(decoded.hostileSites, [], "Older universe JSON should default missing hostile sites to empty")
    requireEqual(decoded.actionChains, [], "Older universe JSON should default missing action chains to empty")
    requireEqual(decoded.sectorControlSummaries, [], "Older universe JSON should default missing sector control summaries to empty")
    requireEqual(decoded.tradeRoutes, [], "Older universe JSON should default missing trade routes to empty")
    requireEqual(decoded.deepIntelOperations, [], "Older universe JSON should default missing deep intel operations to empty")
    requireEqual(decoded.fleetDoctrineSummaries, [], "Older universe JSON should default missing doctrine summaries to empty")
    requireEqual(decoded.artifacts, [], "Older universe JSON should default missing artifacts to empty")
    requireEqual(decoded.crisisState, nil, "Older universe JSON should default missing crisis state to nil")
    requireEqual(decoded.commanderRoster.ownedCommanders, [], "Older universe JSON should default missing commander roster to no commanders")
    requireEqual(decoded.commanderRoster.pendingRecruits, [], "Older universe JSON should default missing pending commander recruits to empty")
    requireEqual(decoded.commanderRoster.recruitmentTickets, 0, "Older universe JSON should default commander tickets to zero")
    requireEqual(decoded.commanderRoster.trainingData, 0, "Older universe JSON should default commander training data to zero")
    requireEqual(decoded.commanderRoster.recruitmentState.totalPulls, 0, "Older universe JSON should default commander pull counters to zero")
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

func testCommanderRecruitmentUsesTicketsAndTenPullGuarantee() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 42, playerName: "Commander")
    universe.commanderRoster.recruitmentTickets = 10

    let result = CommanderRecruitmentEngine.recruit(count: 10, in: &universe)

    requireEqual(result.pulls.count, 10, "Ten-pull should return ten results")
    requireEqual(universe.commanderRoster.recruitmentTickets, 0, "Recruitment should spend one ticket per pull")
    requireEqual(universe.commanderRoster.pendingRecruits.count, 10, "Recruitment should create pending candidates")
    requireEqual(universe.commanderRoster.ownedCommanders.count, 0, "Recruitment should not add commanders before player selection")
    require(result.pulls.contains { $0.rarity >= .elite }, "Ten-pull should guarantee elite or better")
}

func testCommanderRecruitmentIsDeterministicForSameSeedAndState() {
    var first = StarterUniverseFactory.makeNewGame(seed: 99, playerName: "Commander")
    var second = StarterUniverseFactory.makeNewGame(seed: 99, playerName: "Commander")
    first.commanderRoster.recruitmentTickets = 10
    second.commanderRoster.recruitmentTickets = 10

    let firstResult = CommanderRecruitmentEngine.recruit(count: 10, in: &first)
    let secondResult = CommanderRecruitmentEngine.recruit(count: 10, in: &second)

    requireEqual(firstResult.pulls.map(\.definitionID), secondResult.pulls.map(\.definitionID), "Same seed and counters should pull the same commanders")
    requireEqual(first.commanderRoster, second.commanderRoster, "Same recruitment should produce same roster state")
}

func testCommanderRecruitmentClaimsPendingCandidatesIntoRoster() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 6, playerName: "Commander")
    universe.commanderRoster.recruitmentTickets = 1

    let recruitment = CommanderRecruitmentEngine.recruit(count: 1, in: &universe)
    guard let candidateID = recruitment.pulls.first?.candidateID else {
        fatalError("Recruitment should return a selectable candidate id")
    }

    let claim = CommanderRecruitmentEngine.claimPendingRecruit(candidateID, in: &universe)

    requireEqual(claim?.candidateID, candidateID, "Claim should report the selected candidate id")
    requireEqual(universe.commanderRoster.pendingRecruits.count, 0, "Claiming should remove the pending candidate")
    requireEqual(universe.commanderRoster.ownedCommanders.count, 1, "Claiming should add the commander to the roster")
    requireEqual(
        universe.commanderRoster.ownedCommanders.first?.definitionID,
        recruitment.pulls.first?.definitionID,
        "Claiming should add the selected commander definition"
    )
}

func testCommanderRecruitmentConvertsClaimedDuplicatesToShards() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 7, playerName: "Commander")
    guard let definition = CommanderCatalog.definitions.first(where: { $0.rarity == .epic }) else {
        fatalError("Commander catalog should include an epic commander")
    }
    universe.commanderRoster.ownedCommanders = [
        OwnedCommander(definitionID: definition.id, rarity: definition.rarity, acquiredAt: 0)
    ]
    let candidate = PendingCommanderRecruit(definitionID: definition.id, rarity: definition.rarity, pulledAt: universe.gameTime)
    universe.commanderRoster.pendingRecruits = [candidate]

    let result = CommanderRecruitmentEngine.claimPendingRecruit(candidate.id, in: &universe)

    requireEqual(result?.isDuplicate, true, "Claiming an already-owned candidate should report a duplicate")
    requireEqual(universe.commanderRoster.ownedCommanders.count, 1, "Duplicate commander should not create a second owned copy")
    requireEqual(universe.commanderRoster.pendingRecruits.count, 0, "Duplicate claim should still clear the pending candidate")
    requireEqual(universe.commanderRoster.shardsByDefinitionID[definition.id], 25, "Duplicate epic should convert to 25 shards")
}

func testCommanderTrainingConsumesDataAndLevelsWithinCap() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 2, playerName: "Commander")
    let commander = OwnedCommander(definitionID: "mira-pathfinder", rarity: .elite, level: 1, acquiredAt: 0)
    universe.commanderRoster.ownedCommanders = [commander]
    universe.commanderRoster.trainingData = 1_000

    let didTrain = CommanderGrowthEngine.train(commander.id, usingTrainingData: 600, in: &universe)

    guard let updated = universe.commanderRoster.ownedCommanders.first(where: { $0.id == commander.id }) else {
        fatalError("Expected trained commander to remain in roster")
    }
    require(didTrain, "Training should succeed when data is available")
    require(updated.level > 1, "Training should increase commander level")
    require(updated.level <= 30, "Elite commander should not exceed level 30")
    requireEqual(universe.commanderRoster.trainingData, 400, "Training should consume data")
}

func testCommanderPromotionConsumesShardsAndRaisesStars() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 3, playerName: "Commander")
    let commander = OwnedCommander(definitionID: "qiao-reactor", rarity: .epic, level: 10, stars: 0, acquiredAt: 0)
    universe.commanderRoster.ownedCommanders = [commander]
    universe.commanderRoster.shardsByDefinitionID["qiao-reactor"] = 20

    let didPromote = CommanderGrowthEngine.promote(commander.id, in: &universe)

    guard let updated = universe.commanderRoster.ownedCommanders.first(where: { $0.id == commander.id }) else {
        fatalError("Expected promoted commander to remain in roster")
    }
    require(didPromote, "Promotion should succeed with enough shards")
    requireEqual(updated.stars, 1, "Promotion should raise star level")
    requireEqual(universe.commanderRoster.shardsByDefinitionID["qiao-reactor"], nil, "Promotion should consume first-star shard cost")
}

func testFleetLaunchCanAssignAvailableCommanderAndPersistsID() {
    var setup = makeCommanderFleetTestUniverse()
    let commander = OwnedCommander(definitionID: "lin-vanguard", rarity: .legendary, level: 10, stars: 1, acquiredAt: 0)
    setup.universe.commanderRoster.ownedCommanders = [commander]

    let result = FleetEngine.launchFleet(
        from: setup.originID,
        to: setup.targetID,
        in: &setup.universe,
        mission: .attack,
        ships: [.lightFighter: 4],
        commanderID: commander.id
    )

    guard case .launched(let fleet) = result else {
        fatalError("Expected fleet launch with commander to succeed")
    }
    requireEqual(fleet.commanderID, commander.id, "Launched fleet should persist commander assignment")
}

func testAssignedCommanderCannotLeadTwoActiveFleets() {
    var setup = makeCommanderFleetTestUniverse()
    let commander = OwnedCommander(definitionID: "lin-vanguard", rarity: .legendary, acquiredAt: 0)
    setup.universe.commanderRoster.ownedCommanders = [commander]

    _ = FleetEngine.launchFleet(from: setup.originID, to: setup.targetID, in: &setup.universe, mission: .attack, ships: [.lightFighter: 1], commanderID: commander.id)
    let second = FleetEngine.launchFleet(from: setup.originID, to: setup.secondTargetID, in: &setup.universe, mission: .attack, ships: [.lightFighter: 1], commanderID: commander.id)

    requireEqual(second, .failure(.commanderUnavailable), "A commander already assigned to an active fleet should be unavailable")
}

func testFleetCommanderSpeedBonusShortensTravelTime() {
    var setup = makeCommanderFleetTestUniverse()
    let commander = OwnedCommander(definitionID: "lin-vanguard", rarity: .legendary, level: 20, stars: 2, acquiredAt: 0)
    setup.universe.commanderRoster.ownedCommanders = [commander]

    let base = FleetEngine.travelDuration(from: setup.originCoordinate, to: setup.targetCoordinate, ships: [.lightFighter: 4], ruleSet: setup.universe.ruleSet)
    let boosted = FleetEngine.travelDuration(from: setup.originCoordinate, to: setup.targetCoordinate, ships: [.lightFighter: 4], ruleSet: setup.universe.ruleSet, commanderBonus: CommanderBonusEngine.fleetBonus(for: commander, in: setup.universe))

    require(boosted < base, "Fleet admiral commander should shorten travel time")
}

func testBattleSimulationAppliesCommanderAttackBonus() {
    let base = BattleSimulationEngine.resolve(
        BattleSimulationInput(
            attackerShips: [.lightFighter: 3],
            defenderShips: [.lightFighter: 3],
            defenderDefenses: [:],
            attackerResearch: ResearchState(),
            defenderResearch: ResearchState(),
            ruleSet: .fastSkirmish,
            seed: 11
        )
    )

    let boosted = BattleSimulationEngine.resolve(
        BattleSimulationInput(
            attackerShips: [.lightFighter: 3],
            defenderShips: [.lightFighter: 3],
            defenderDefenses: [:],
            attackerResearch: ResearchState(),
            defenderResearch: ResearchState(),
            ruleSet: .fastSkirmish,
            seed: 11,
            attackerCommanderBonus: CommanderFleetBonus(attackMultiplier: 1.25)
        )
    )

    require((boosted.rounds.first?.attackerPower ?? 0) > (base.rounds.first?.attackerPower ?? 0), "Commander attack bonus should increase attacker round power")
}

func testAttackMissionGrantsCommanderExperience() {
    var setup = makeCommanderFleetTestUniverse()
    let commander = OwnedCommander(definitionID: "lin-vanguard", rarity: .legendary, acquiredAt: 0)
    setup.universe.commanderRoster.ownedCommanders = [commander]

    let launch = FleetEngine.launchFleet(from: setup.originID, to: setup.targetID, in: &setup.universe, mission: .attack, ships: [.lightFighter: 4], commanderID: commander.id)
    guard case .launched = launch else {
        fatalError("Expected launch")
    }
    guard let fleet = setup.universe.fleets.first else {
        fatalError("Expected launched fleet")
    }
    setup.universe.gameTime = fleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &setup.universe)

    guard let updated = setup.universe.commanderRoster.ownedCommanders.first(where: { $0.id == commander.id }) else {
        fatalError("Expected commander to remain in roster")
    }
    require(updated.experience > 0 || updated.level > commander.level, "Commander should gain XP from resolved combat")
    require(
        setup.universe.events.contains { event in
            event.kind == .combat &&
                event.title == "指挥官实战经验" &&
                event.message.contains("林远航") &&
                event.message.contains("经验")
        },
        "Resolved commander-led combat should add a readable XP event"
    )
}

func testUniverseModelRoundTripsThroughJSON() throws {
    let player = FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000010")!)
    let homeworld = PlanetID(UUID(uuidString: "00000000-0000-0000-0000-000000000020")!)
    let fleetID = FleetID(UUID(uuidString: "00000000-0000-0000-0000-000000000040")!)
    let eventID = EventID(UUID(uuidString: "00000000-0000-0000-0000-000000000050")!)
    let reportID = UUID(uuidString: "00000000-0000-0000-0000-000000000055")!
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
        reports: [
            Report(
                id: reportID,
                time: 122,
                kind: .battle,
                title: "Battle at [1:2:8]",
                summary: "The attacker won.",
                participants: [
                    ReportParticipant(
                        role: .attacker,
                        factionID: player,
                        planetID: homeworld,
                        name: "Player",
                        beforeShips: [.smallCargo: 2],
                        afterShips: [.smallCargo: 1],
                        beforeDefenses: [:],
                        afterDefenses: [:],
                        losses: ResourceBundle(metal: 2_000, crystal: 2_000)
                    )
                ],
                loot: ResourceBundle(metal: 100),
                debris: ResourceBundle(metal: 600, crystal: 600),
                losses: ResourceBundle(metal: 2_000, crystal: 2_000)
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
    requireIdentifiable(universe.reports[0], id: reportID, "Report should be Identifiable by its id")
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

    let reportsJSON = requireArray(json["reports"], "Reports should encode as a JSON array")
    let reportJSON = requireDictionary(reportsJSON.first, "Report should encode as a JSON object")
    requireEqual(reportJSON["kind"] as? String, "battle", "Report kind should encode by raw value")
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
    requireEqual(first.planets.filter { $0.ownerID != nil }.count, 6, "Starter universe should create six owned planets")
    require(first.planets.contains { $0.ownerID == nil }, "Starter universe should include neutral planets")
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
    let aiPlanets = first.planets.filter { planet in
        planet.ownerID != nil && planet.ownerID != first.playerFactionID
    }
    let neutralPlanets = first.planets.filter { $0.ownerID == nil }
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
    require(neutralPlanets.count >= 24, "Neutral planets should provide a service-style regional colonization pool")
    require(neutralPlanets.allSatisfy { UniverseTopologyEngine.isValidPlanetCoordinate($0.coordinate) }, "Neutral planets should use valid colony slots")
    require(neutralPlanets.allSatisfy { resourceTotal($0.resources) > 0 }, "Neutral planets should carry small exploration resources")

    requireEqual(first.events.count, 1, "Starter universe should create one welcome event")
    requireEqual(first.events.first?.title, "Command Link Established", "Starter universe should record initial event")
    requireEqual(first.events.first?.kind, .system, "Welcome event should be a system event")
    requireEqual(first.events.first?.time, 0, "Welcome event should occur at game time zero")

    let data = try JSONEncoder().encode(first)
    let decoded = try JSONDecoder().decode(Universe.self, from: data)
    requireEqual(decoded, first, "Starter universe should preserve stable enum-map JSON behavior")
}

func testUniverseTopologyUsesServiceStyleCoordinateLimits() {
    requireEqual(UniverseTopologyEngine.defaultGalaxyCount, 9, "Service-style universe should expose nine galaxies")
    requireEqual(UniverseTopologyEngine.defaultSystemsPerGalaxy, 499, "Each galaxy should expose 499 solar systems")
    requireEqual(UniverseTopologyEngine.planetSlotsPerSystem, 15, "Each solar system should expose fifteen planet slots")
    requireEqual(UniverseTopologyEngine.expeditionPosition, 16, "Position 16 should be reserved for expedition space")
    requireEqual(UniverseTopologyEngine.defaultMaxPlayerPlanets, 8, "Default player colony cap should match the service baseline")

    require(UniverseTopologyEngine.isValidPlanetCoordinate(Coordinate(galaxy: 1, system: 1, position: 1)), "First planet slot should be valid")
    require(UniverseTopologyEngine.isValidPlanetCoordinate(Coordinate(galaxy: 9, system: 499, position: 15)), "Last planet slot should be valid")
    require(!UniverseTopologyEngine.isValidPlanetCoordinate(Coordinate(galaxy: 10, system: 1, position: 1)), "Galaxy beyond the universe limit should be invalid")
    require(!UniverseTopologyEngine.isValidPlanetCoordinate(Coordinate(galaxy: 1, system: 500, position: 1)), "System beyond the galaxy limit should be invalid")
    require(!UniverseTopologyEngine.isValidPlanetCoordinate(Coordinate(galaxy: 1, system: 1, position: 16)), "Expedition slot should not be a colony planet slot")
    require(UniverseTopologyEngine.isExpeditionCoordinate(Coordinate(galaxy: 1, system: 1, position: 16)), "Position 16 should be recognized as expedition space")
}

func testUniverseTopologyClassifiesStarMapSlotRolesForDetails() {
    requireEqual(
        UniverseTopologyEngine.starMapSlotRole(
            for: Coordinate(galaxy: 1, system: 1, position: UniverseTopologyEngine.expeditionPosition),
            hasPlanet: false,
            isVisible: true,
            isPlayerOwned: false,
            ownerKind: nil
        ),
        .expedition,
        "Expedition position should be identified for star map detail actions"
    )
    requireEqual(
        UniverseTopologyEngine.starMapSlotRole(
            for: Coordinate(galaxy: 1, system: 1, position: 8),
            hasPlanet: false,
            isVisible: true,
            isPlayerOwned: false,
            ownerKind: nil
        ),
        .empty,
        "Empty planet slots should be identified for colonization details"
    )
    requireEqual(
        UniverseTopologyEngine.starMapSlotRole(
            for: Coordinate(galaxy: 1, system: 1, position: 4),
            hasPlanet: true,
            isVisible: true,
            isPlayerOwned: true,
            ownerKind: .player
        ),
        .playerOwned,
        "Owned slots should stay distinct from neutral and AI worlds"
    )
    requireEqual(
        UniverseTopologyEngine.starMapSlotRole(
            for: Coordinate(galaxy: 1, system: 2, position: 5),
            hasPlanet: true,
            isVisible: true,
            isPlayerOwned: false,
            ownerKind: .ai
        ),
        .aiOwned,
        "Visible AI slots should support hostile detail actions"
    )
    requireEqual(
        UniverseTopologyEngine.starMapSlotRole(
            for: Coordinate(galaxy: 1, system: 3, position: 6),
            hasPlanet: true,
            isVisible: true,
            isPlayerOwned: false,
            ownerKind: nil
        ),
        .neutralOwned,
        "Visible unowned worlds should be shown as neutral targets"
    )
    requireEqual(
        UniverseTopologyEngine.starMapSlotRole(
            for: Coordinate(galaxy: 1, system: 4, position: 7),
            hasPlanet: true,
            isVisible: false,
            isPlayerOwned: false,
            ownerKind: .ai
        ),
        .unknown,
        "Hidden occupied slots should not reveal their faction role"
    )
}

func testUniverseTopologyPlanetProfilesVaryBySlot() {
    let inner = UniverseTopologyEngine.planetProfile(
        for: Coordinate(galaxy: 1, system: 8, position: 2),
        universeSeed: 42
    )
    let middle = UniverseTopologyEngine.planetProfile(
        for: Coordinate(galaxy: 1, system: 8, position: 5),
        universeSeed: 42
    )
    let outer = UniverseTopologyEngine.planetProfile(
        for: Coordinate(galaxy: 1, system: 8, position: 14),
        universeSeed: 42
    )

    require(inner.temperatureCelsius > outer.temperatureCelsius, "Inner slots should be hotter than outer slots")
    require(middle.maxFields > inner.maxFields, "Middle colony slots should generally offer more fields than inner slots")
    require(middle.maxFields > outer.maxFields, "Middle colony slots should generally offer more fields than cold outer slots")
    requireEqual(outer.habitat, .ice, "Outer slots should receive an ice habitat profile")
}

func testUniverseTopologyColonySlotProfilesExposeLongTermTradeoffs() {
    let inner = UniverseTopologyEngine.colonySlotProfile(forPosition: 2)
    let middle = UniverseTopologyEngine.colonySlotProfile(forPosition: 7)
    let outer = UniverseTopologyEngine.colonySlotProfile(forPosition: 14)

    require(inner.solarEnergyFactor > outer.solarEnergyFactor, "Inner slots should be better for solar energy")
    require(outer.deuteriumFactor > inner.deuteriumFactor, "Outer cold slots should be better for deuterium")
    require(middle.fieldFactor > inner.fieldFactor && middle.fieldFactor > outer.fieldFactor, "Middle slots should be strongest for planet fields")
    require(inner.strategyHint.contains("太阳能"), "Inner slot hint should explain solar value")
    require(outer.strategyHint.contains("重氢"), "Outer slot hint should explain deuterium value")
}

func testColonySpecializationClassifiesSlotTradeoffs() {
    let inner = ColonySpecializationEngine.preview(
        for: Coordinate(galaxy: 1, system: 42, position: 2),
        universeSeed: 88
    )
    let middle = ColonySpecializationEngine.preview(
        for: Coordinate(galaxy: 1, system: 42, position: 5),
        universeSeed: 88
    )
    let outer = ColonySpecializationEngine.preview(
        for: Coordinate(galaxy: 1, system: 42, position: 14),
        universeSeed: 88
    )

    requireEqual(inner.role, .solarOutpost, "Hot inner slots should be recommended as solar outposts")
    requireEqual(middle.role, .coreWorld, "Large middle slots should be recommended as core worlds")
    requireEqual(outer.role, .deuteriumWorld, "Cold outer slots should be recommended as deuterium worlds")
    require(inner.slotProfile.solarEnergyFactor > outer.slotProfile.solarEnergyFactor, "Inner specialization should preserve solar advantage")
    require(outer.slotProfile.deuteriumFactor > inner.slotProfile.deuteriumFactor, "Outer specialization should preserve deuterium advantage")
    require(inner.warnings.contains { $0.kind == .lowFields }, "Inner hot slots should warn about limited fields")
    require(outer.warnings.contains { $0.kind == .coldSolar }, "Outer cold slots should warn about weak solar energy")
    require(outer.recommendedBuildings.contains(.deuteriumSynthesizer), "Deuterium worlds should prioritize deuterium synthesizers")
}

func testColonySpecializationPromotesBuiltWorldRolesAndFieldWarnings() {
    let shipyardWorld = Planet(
        name: "Forge",
        coordinate: Coordinate(galaxy: 1, system: 9, position: 5),
        ownerID: FactionID(),
        temperatureCelsius: 38,
        buildingLevels: [
            .metalMine: 12,
            .crystalMine: 11,
            .deuteriumSynthesizer: 8,
            .solarPlant: 12,
            .roboticsFactory: 4,
            .shipyard: 7,
            .naniteFactory: 1
        ],
        maxFields: 7
    )

    let shipyardSpecialization = ColonySpecializationEngine.specialization(for: shipyardWorld)
    requireEqual(shipyardSpecialization.role, .shipyardHub, "Built-up shipyards should become shipyard hubs")
    require(
        shipyardSpecialization.warnings.contains { $0.kind == .crowdedFields },
        "Worlds near field cap should surface a crowded field warning"
    )
    require(
        shipyardSpecialization.recommendedBuildings.contains(.naniteFactory),
        "Shipyard hubs should recommend nanite factories"
    )

    let moonWorld = Planet(
        name: "Moon Gate",
        coordinate: Coordinate(galaxy: 1, system: 9, position: 8),
        ownerID: FactionID(),
        moon: Moon(
            name: "Luna",
            createdAt: 1_000,
            buildingLevels: [.lunarBase: 2, .sensorPhalanx: 2, .jumpGate: 1]
        )
    )

    let moonSpecialization = ColonySpecializationEngine.specialization(for: moonWorld)
    requireEqual(moonSpecialization.role, .moonBase, "Worlds with active moon facilities should surface moon base specialization")
    require(moonSpecialization.recommendedBuildings.contains(.sensorPhalanx), "Moon bases should recommend phalanx expansion")
}

func testGameplayAuditAutoplayDoesNotUseGuidedFixtures() {
    let result = GameplayAuditEngine.runAutoplayAudit(
        seed: 1,
        duration: 7_200,
        settings: GameSettings(difficulty: .standard)
    )

    requireEqual(result.usedGuidedFixtures, false, "Gameplay audit should not inject scripted ships, moons, or victory fixtures")
    require(result.auditNotes.contains { $0.kind == .organicPacing }, "Gameplay audit should label organic pacing evidence")
    require(result.advisorRecommendationKinds.isEmpty == false, "Gameplay audit should sample strategic advisor recommendations")
    require(result.routePlans.count == VictoryRoute.allCases.count, "Gameplay audit should expose all victory route plans")
    require(result.expansionSignalCount > 0, "Gameplay audit should count expansion gameplay signals")
}

func testGameplayAuditAutoplayReachesNaturalFleetLoop() {
    let result = GameplayAuditEngine.runAutoplayAudit(
        seed: 1,
        duration: 14_400,
        settings: GameSettings(difficulty: .standard)
    )
    require(result.balance.firstShipAt != nil, "Autoplay audit should naturally build a first ship in the fast-skirmish window")
    require(result.balance.firstFleetLaunchAt != nil, "Autoplay audit should naturally launch a first fleet in the fast-skirmish window")
    require(
        !result.auditNotes.contains { $0.kind == .earlyFleetBlocked },
        "A mature autoplay loop should not report the early fleet as blocked"
    )
}

func testVictoryRoutePlansExposeCompositeCheckpoints() {
    var universe = makeStrategicUniverse(playerResources: ResourceBundle(metal: 120_000, crystal: 80_000, deuterium: 40_000))
    StrategicEngine.updateStrategicState(in: &universe)

    let plans = VictoryRoutePlanEngine.plans(for: strategicPlayerID(), in: universe)
    guard let economyPlan = plans.first(where: { $0.route == .economy }) else {
        fatalError("Victory route plans should include economy route")
    }
    guard let technologyPlan = plans.first(where: { $0.route == .technology }) else {
        fatalError("Victory route plans should include technology route")
    }

    require(economyPlan.checkpoints.count >= 4, "Economy victory should be decomposed into multiple gameplay checkpoints")
    require(economyPlan.checkpoints.contains { $0.kind == .scoreThreshold && $0.isComplete }, "Economy route should still recognize raw economy strength")
    require(economyPlan.checkpoints.contains { $0.kind == .colonyNetwork && !$0.isComplete }, "Economy route should also require colony network depth")
    require(economyPlan.progress < 1, "Large stockpile alone should not make the composite economy plan complete")
    require(technologyPlan.checkpoints.contains { $0.kind == .moonInfrastructure }, "Technology route should include moon infrastructure as a late-game checkpoint")
}

func testAIIntentSummariesExposeActionPlans() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 9, playerName: "Commander")
    StrategicEngine.updateStrategicState(in: &universe)

    let intents = AIIntentEngine.intentSummaries(in: universe)

    require(intents.count >= 5, "AI intent summaries should cover each AI faction")
    require(intents.contains { $0.intent == .expand || $0.intent == .scout || $0.intent == .buildUp }, "AI should expose actionable non-idle intent")
    require(intents.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty }, "AI intent summaries should be readable in UI and advisor surfaces")
}

func testMidgamePlayerObjectivesExposeStrategyDepth() {
    let objectives = PlayerObjectiveEngine.states(in: StarterUniverseFactory.makeNewGame(seed: 4, playerName: "Commander"))
    let kinds = Set(objectives.map(\.kind))

    require(kinds.contains(.colonySpecialization), "Objectives should include colony specialization")
    require(kinds.contains(.combatReview), "Objectives should include combat review")
    require(kinds.contains(.fleetSaveDrill), "Objectives should include fleet save drill")
    require(kinds.contains(.jumpGateNetwork), "Objectives should include jump gate network")
}

func testStrategicAdvisorRecommendsVictoryRouteAndAIThreat() {
    var universe = makeStrategicUniverse(playerResources: ResourceBundle(metal: 8_000, crystal: 6_000, deuterium: 2_000))
    let aiID = strategicAIID()
    if let factionIndex = universe.factions.firstIndex(where: { $0.id == strategicPlayerID() }) {
        universe.factions[factionIndex].relations = [
            FactionRelation(factionID: aiID, posture: .hostile, threatScore: 4, lastInteractionTime: 600, attackCount: 2)
        ]
    }
    StrategicEngine.updateStrategicState(in: &universe)

    let recommendations = StrategicAdvisorEngine.recommendations(in: universe, limit: 12)

    require(recommendations.contains { $0.kind == .victoryRoute }, "Advisor should recommend a victory route focus")
    require(recommendations.contains { $0.kind == .aiThreat }, "Advisor should surface active AI threat")
}

func testGameplayExpansionRefreshCreatesThreePhaseGameplayLoops() {
    var universe = makeExpansionUniverse(gameTime: 9_000)

    GameplayExpansionEngine.refresh(in: &universe)

    require(universe.sectorEvents.contains { $0.kind == .pirateActivity || $0.kind == .ancientRelic }, "Expansion should create dynamic sector events")
    require(universe.hostileSites.contains { $0.kind == .pirateBase || $0.kind == .alienOutpost }, "Expansion should create PVE hostile targets")
    require(
        universe.actionChains.contains { chain in
            chain.steps.contains { $0.kind == .scoutTarget } &&
                chain.steps.contains { $0.kind == .strikeHostile } &&
                chain.steps.contains { $0.kind == .recoverSpoils }
        },
        "Expansion should create action chains that link scouting, fighting, and recovery"
    )
    require(universe.sectorControlSummaries.contains { $0.ownerID == universe.playerFactionID && $0.controlLevel >= 2 }, "Expansion should reward clustered colonies with sector control")
    require(universe.tradeRoutes.contains { $0.ownerID == universe.playerFactionID && $0.status == .profitable }, "Expansion should suggest useful trade routes")
    require(universe.deepIntelOperations.contains { $0.ownerID == universe.playerFactionID && $0.kind == .signalIntercept }, "Expansion should expose deep intel operations")
    require(universe.fleetDoctrineSummaries.contains { $0.doctrine == .raiding || $0.doctrine == .expeditionary }, "Expansion should expose fleet doctrine choices")
    require(universe.artifacts.contains { $0.kind == .ancientBlueprint || $0.kind == .logisticsRelic }, "Expansion should add discoverable artifacts")
    require(universe.crisisState?.kind == .pirateWarlord, "Late-game expansion should spawn a crisis once the universe matures")
}

func testGameplayExpansionRewardsCommanderRecruitmentMaterials() {
    var universe = makeExpansionUniverse(gameTime: 9_000)

    GameplayExpansionEngine.refresh(in: &universe)
    let hostileCommanderRewards = universe.hostileSites.compactMap(\.commanderReward)
    let actionChainCommanderRewards = universe.actionChains.compactMap(\.commanderReward)
    let hasHostileCommanderReward = hostileCommanderRewards.contains { reward in
        reward.recruitmentTickets > 0 && reward.trainingData > 0
    }
    let hasActionChainCommanderReward = actionChainCommanderRewards.contains { reward in
        reward.recruitmentTickets > 0 && reward.trainingData > 0
    }

    require(
        hasHostileCommanderReward,
        "PVE hostile sites should advertise commander recruitment and training rewards"
    )
    require(
        hasActionChainCommanderReward,
        "PVE action chains should carry commander reward payloads for future claim flows"
    )
}

func testGameplayExpansionSeedsHostileTargetsWithDefendersAndLoot() {
    var universe = makeExpansionUniverse(gameTime: 9_000)

    GameplayExpansionEngine.refresh(in: &universe)

    for site in universe.hostileSites {
        guard let targetID = site.targetPlanetID,
              let target = universe.planets.first(where: { $0.id == targetID })
        else {
            fatalError("Hostile site should point at a target planet")
        }
        let defenderShipCount = target.shipInventory.values.reduce(0) { $0 + max($1, 0) }
        let defenseCount = target.defenseInventory.values.reduce(0) { $0 + max($1, 0) }

        require(defenderShipCount + defenseCount > 0, "Hostile target should have ships or defenses to fight")
        require(resourceTotal(target.resources) > 0, "Hostile target should hold lootable resources")
        requireEqual(target.ownerID, nil, "PVE hostile targets should stay neutral so they do not become full AI colonies")
    }
}

func testGameplayExpansionDoesNotResetDamagedActiveHostileTarget() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    GameplayExpansionEngine.refresh(in: &universe)
    guard let site = universe.hostileSites.first,
          let targetID = site.targetPlanetID,
          let targetIndex = universe.planets.firstIndex(where: { $0.id == targetID })
    else {
        fatalError("Hostile site should have a target planet")
    }
    universe.planets[targetIndex].resources = .zero
    universe.planets[targetIndex].shipInventory = [:]
    universe.planets[targetIndex].defenseInventory = [:]

    GameplayExpansionEngine.refresh(in: &universe)

    requireEqual(universe.planets[targetIndex].resources, .zero, "Active hostile site refresh should not reset looted resources")
    requireEqual(universe.planets[targetIndex].shipInventory, [:], "Active hostile site refresh should not respawn defeated ships")
    requireEqual(universe.planets[targetIndex].defenseInventory, [:], "Active hostile site refresh should not respawn defeated defenses")
}

func testGameplayExpansionSkipsHostileSitesWhenNeutralTargetsAreBusy() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    guard let origin = universe.planets.first(where: { $0.ownerID == universe.playerFactionID }) else {
        fatalError("Expansion universe should include a player origin")
    }
    let neutralPlanets = universe.planets.filter { $0.ownerID == nil }
    require(neutralPlanets.count >= 2, "Expansion fixture should include neutral targets")
    universe.fleets = neutralPlanets.map { target in
        Fleet(
            ownerID: universe.playerFactionID,
            mission: .explore,
            origin: origin.coordinate,
            target: target.coordinate,
            ships: [.espionageProbe: 1],
            launchTime: universe.gameTime,
            arrivalTime: universe.gameTime + 600,
            returnTime: universe.gameTime + 1_200,
            originPlanetID: origin.id,
            targetPlanetID: target.id
        )
    }

    GameplayExpansionEngine.refresh(in: &universe)

    require(universe.hostileSites.isEmpty, "Expansion should not create targetless hostile sites when every neutral target is busy")
}

func testActionChainRewardClaimGrantsResourcesCommanderMaterialsAndPendingDrop() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    guard let receiverIndex = universe.planets.firstIndex(where: { $0.ownerID == universe.playerFactionID }) else {
        fatalError("Expansion universe should include a player planet")
    }

    let receiverID = universe.planets[receiverIndex].id
    let startingResources = universe.planets[receiverIndex].resources
    let reward = ResourceBundle(metal: 1_200, crystal: 800, deuterium: 300)
    let commanderReward = CommanderRewardBundle(recruitmentTickets: 2, trainingData: 180, commanderDropChance: 1)
    let chain = ActionChain(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000a701")!,
        kind: .hostileRaid,
        title: "清剿测试据点",
        detail: "验证 PVE 行动链奖励领取闭环。",
        steps: [
            ActionChain.Step(kind: .scoutTarget, title: "侦察目标", status: .complete),
            ActionChain.Step(kind: .strikeHostile, title: "打击据点", status: .complete),
            ActionChain.Step(kind: .recoverSpoils, title: "回收战利品", status: .complete)
        ],
        reward: reward,
        commanderReward: commanderReward,
        expiresAt: universe.gameTime + 600
    )
    universe.actionChains = [chain]

    let result = ActionChainRewardEngine.claim(chain.id, in: &universe)

    requireEqual(result.status, .claimed, "Ready action chain should be claimable")
    requireEqual(result.receivingPlanetID, receiverID, "Claim should report the planet receiving resources")
    requireEqual(result.resources, reward, "Claim result should expose granted resources")
    requireEqual(result.commanderReward, commanderReward, "Claim result should expose commander rewards")
    require(result.commanderDrop != nil, "Guaranteed commander drop should create a selectable pending candidate")
    requireEqual(universe.planets[receiverIndex].resources, startingResources.adding(reward).nonnegative, "Claim should grant resources to the first player planet")
    requireEqual(universe.commanderRoster.recruitmentTickets, commanderReward.recruitmentTickets, "Claim should grant recruitment tickets")
    requireEqual(universe.commanderRoster.trainingData, commanderReward.trainingData, "Claim should grant training data")
    requireEqual(universe.commanderRoster.pendingRecruits.count, 1, "Commander drops should wait for player selection")
    requireEqual(universe.commanderRoster.ownedCommanders.count, 0, "Commander drops should not bypass candidate selection")
    require(universe.actionChains.isEmpty, "Claimed action chain should be removed to prevent duplicate rewards")
    require(universe.events.contains { $0.kind == .system && $0.title == "行动链奖励领取" }, "Claim should add a readable system event")
}

func testActionChainRewardClaimRequiresCompletedSteps() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    guard let receiverIndex = universe.planets.firstIndex(where: { $0.ownerID == universe.playerFactionID }) else {
        fatalError("Expansion universe should include a player planet")
    }
    let startingResources = universe.planets[receiverIndex].resources
    let chain = ActionChain(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000a702")!,
        kind: .hostileRaid,
        title: "未完成测试据点",
        detail: "ready 步骤不能直接领奖。",
        steps: [
            ActionChain.Step(kind: .scoutTarget, title: "侦察目标", status: .complete),
            ActionChain.Step(kind: .strikeHostile, title: "打击据点", status: .ready),
            ActionChain.Step(kind: .recoverSpoils, title: "回收战利品", status: .complete)
        ],
        reward: ResourceBundle(metal: 900),
        commanderReward: CommanderRewardBundle(recruitmentTickets: 1, trainingData: 40),
        expiresAt: universe.gameTime + 600
    )
    universe.actionChains = [chain]

    let result = ActionChainRewardEngine.claim(chain.id, in: &universe)

    requireEqual(result.status, .locked, "Ready action chain steps should not be claimable until completed")
    requireEqual(universe.planets[receiverIndex].resources, startingResources, "Incomplete chain should not grant resources")
    requireEqual(universe.commanderRoster.recruitmentTickets, 0, "Incomplete chain should not grant commander tickets")
    requireEqual(universe.actionChains.count, 1, "Incomplete chain should remain available")
}

func testClaimedHostileActionChainClearsHostileSiteAndSuppressesRefresh() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    GameplayExpansionEngine.refresh(in: &universe)
    guard let chain = universe.actionChains.first(where: { $0.kind == .hostileRaid }),
          let site = universe.hostileSites.sorted(by: { $0.threatLevel < $1.threatLevel }).first
    else {
        fatalError("Expansion should create a hostile raid chain and site")
    }
    universe.hostileSites = [site]
    universe.actionChains = [
        ActionChain(
            id: chain.id,
            kind: chain.kind,
            title: chain.title,
            detail: chain.detail,
            steps: chain.steps.map { step in
                ActionChain.Step(kind: step.kind, title: step.title, status: .complete)
            },
            reward: chain.reward,
            commanderReward: chain.commanderReward,
            expiresAt: chain.expiresAt
        )
    ]

    let result = ActionChainRewardEngine.claim(chain.id, in: &universe)
    requireEqual(result.status, .claimed, "Completed hostile chain should claim")
    require(!universe.hostileSites.contains { $0.id == site.id }, "Claiming hostile chain should remove the cleared site")

    GameplayExpansionEngine.refresh(in: &universe)

    require(!universe.hostileSites.contains { $0.id == site.id }, "Cleared hostile site should not regenerate after refresh")
    require(!universe.actionChains.contains { $0.id == chain.id }, "Cleared hostile chain should not regenerate after refresh")
}

func testHostileActionChainProgressesFromReportsAndRecoveryEvents() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    universe.reports = []
    GameplayExpansionEngine.refresh(in: &universe)
    guard let site = universe.hostileSites.sorted(by: { $0.threatLevel < $1.threatLevel }).first,
          let targetID = site.targetPlanetID
    else {
        fatalError("Expansion should create a hostile site with a target")
    }

    var chain = requireHostileActionChain(in: universe)
    requireEqual(stepStatus(.scoutTarget, in: chain), .ready, "Hostile chain should start with scouting ready")
    requireEqual(stepStatus(.strikeHostile, in: chain), .locked, "Hostile strike should wait for scouting evidence")
    requireEqual(stepStatus(.recoverSpoils, in: chain), .locked, "Spoils recovery should wait for battle evidence")
    require(!ActionChainRewardEngine.canClaim(chain, at: universe.gameTime), "Unfinished hostile chain should not be claimable")

    universe.reports.append(
        Report(
            time: universe.gameTime - 60,
            kind: .espionage,
            title: "Espionage at \(site.coordinate.displayText)",
            summary: "Intel",
            participants: [
                ReportParticipant(role: .attacker, factionID: universe.playerFactionID, planetID: strategicPlanetID(1), name: "Scout"),
                ReportParticipant(role: .defender, factionID: nil, planetID: targetID, name: site.name)
            ]
        )
    )
    GameplayExpansionEngine.refresh(in: &universe)
    chain = requireHostileActionChain(in: universe)
    requireEqual(stepStatus(.scoutTarget, in: chain), .complete, "Recent espionage report should complete scouting")
    requireEqual(stepStatus(.strikeHostile, in: chain), .ready, "Strike should become ready after scouting and sufficient power")
    requireEqual(stepStatus(.recoverSpoils, in: chain), .locked, "Recovery should still wait for a battle report")

    universe.reports.append(
        Report(
            time: universe.gameTime - 30,
            kind: .battle,
            title: "Battle at \(site.coordinate.displayText)",
            summary: "Attacker wins.",
            participants: [
                ReportParticipant(role: .attacker, factionID: universe.playerFactionID, planetID: strategicPlanetID(1), name: "Raider"),
                ReportParticipant(role: .defender, factionID: nil, planetID: targetID, name: site.name)
            ],
            debris: ResourceBundle(metal: 2_000, crystal: 1_000)
        )
    )
    GameplayExpansionEngine.refresh(in: &universe)
    chain = requireHostileActionChain(in: universe)
    requireEqual(stepStatus(.strikeHostile, in: chain), .complete, "Recent battle report should complete the strike")
    requireEqual(stepStatus(.recoverSpoils, in: chain), .ready, "Recovery should become ready after battle when recycler exists")
    require(!ActionChainRewardEngine.canClaim(chain, at: universe.gameTime), "Chain should still require a recovery event before claiming")

    universe.events.append(
        GameEvent(
            time: universe.gameTime - 10,
            kind: .system,
            title: "Debris Recovered",
            message: "Recycle fleet resolved at \(site.coordinate.displayText)."
        )
    )
    GameplayExpansionEngine.refresh(in: &universe)
    chain = requireHostileActionChain(in: universe)
    requireEqual(stepStatus(.recoverSpoils, in: chain), .complete, "Recent recovery event should complete spoils recovery")
    require(ActionChainRewardEngine.canClaim(chain, at: universe.gameTime), "Fully evidenced hostile chain should become claimable")
}

func testActionChainFleetPlannerRecommendsNextHostileMission() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    universe.reports = []
    for index in universe.planets.indices where universe.planets[index].ownerID == universe.playerFactionID {
        universe.planets[index].resources.deuterium = 1_000_000
    }
    GameplayExpansionEngine.refresh(in: &universe)
    guard let site = universe.hostileSites.sorted(by: { $0.threatLevel < $1.threatLevel }).first,
          let targetID = site.targetPlanetID
    else {
        fatalError("Expansion should create a hostile site with a target")
    }

    var chain = requireHostileActionChain(in: universe)
    var plan = ActionChainFleetPlannerEngine.nextActionPlan(for: chain.id, in: universe)
    requireEqual(plan.status, .ready, "Scouting step should be immediately dispatchable")
    requireEqual(plan.stepKind, .scoutTarget, "Planner should start hostile chain with scouting")
    requireEqual(plan.mission, .espionage, "Scouting should use espionage mission")
    requireEqual(plan.targetID, targetID, "Planner should target the hostile site planet")
    requireEqual(plan.ships[.espionageProbe], 1, "Scouting should send one probe")
    require(plan.isLaunchable, "Scout plan should be launchable")

    universe.reports.append(
        Report(
            time: universe.gameTime - 60,
            kind: .espionage,
            title: "Espionage at \(site.coordinate.displayText)",
            summary: "Intel",
            participants: [
                ReportParticipant(role: .attacker, factionID: universe.playerFactionID, planetID: strategicPlanetID(1), name: "Scout"),
                ReportParticipant(role: .defender, factionID: nil, planetID: targetID, name: site.name)
            ]
        )
    )
    GameplayExpansionEngine.refresh(in: &universe)
    chain = requireHostileActionChain(in: universe)
    plan = ActionChainFleetPlannerEngine.nextActionPlan(for: chain.id, in: universe)
    requireEqual(plan.status, .ready, "Strike step should become dispatchable after scouting")
    requireEqual(plan.stepKind, .strikeHostile, "Planner should advance to the strike step")
    requireEqual(plan.mission, .attack, "Strike should use attack mission")
    require((plan.ships[.cruiser] ?? 0) > 0 || (plan.ships[.lightFighter] ?? 0) > 0, "Strike should select combat ships")
    require(plan.isLaunchable, "Strike plan should be launchable")

    universe.reports.append(
        Report(
            time: universe.gameTime - 30,
            kind: .battle,
            title: "Battle at \(site.coordinate.displayText)",
            summary: "Attacker wins.",
            participants: [
                ReportParticipant(role: .attacker, factionID: universe.playerFactionID, planetID: strategicPlanetID(1), name: "Raider"),
                ReportParticipant(role: .defender, factionID: nil, planetID: targetID, name: site.name)
            ],
            debris: ResourceBundle(metal: 2_000, crystal: 1_000)
        )
    )
    GameplayExpansionEngine.refresh(in: &universe)
    chain = requireHostileActionChain(in: universe)
    plan = ActionChainFleetPlannerEngine.nextActionPlan(for: chain.id, in: universe)
    requireEqual(plan.status, .ready, "Recovery step should become dispatchable after the strike")
    requireEqual(plan.stepKind, .recoverSpoils, "Planner should advance to recovery")
    requireEqual(plan.mission, .recycle, "Recovery should use recycle mission")
    requireEqual(plan.ships[.recycler], 1, "Recovery should send one recycler")
    require(plan.isLaunchable, "Recovery plan should be launchable")
}

func testActionChainFleetPlannerChoosesSufficientHostileStrikeOrigin() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    universe.reports = []
    let playerPlanetIDs = universe.planets.filter { $0.ownerID == universe.playerFactionID }.map(\.id)
    guard playerPlanetIDs.count >= 2,
          let weakIndex = universe.planets.firstIndex(where: { $0.id == playerPlanetIDs[0] }),
          let strongIndex = universe.planets.firstIndex(where: { $0.id == playerPlanetIDs[1] })
    else {
        fatalError("Expansion fixture should include at least two player planets")
    }
    universe.planets[weakIndex].resources.deuterium = 1_000_000
    universe.planets[strongIndex].resources.deuterium = 1_000_000
    universe.planets[weakIndex].shipInventory = [.lightFighter: 1, .espionageProbe: 1]
    universe.planets[strongIndex].shipInventory = [.cruiser: 8, .lightFighter: 12]

    GameplayExpansionEngine.refresh(in: &universe)
    guard let site = universe.hostileSites.sorted(by: { $0.threatLevel < $1.threatLevel }).first,
          let targetID = site.targetPlanetID
    else {
        fatalError("Expansion should create a hostile site")
    }
    universe.reports.append(
        Report(
            time: universe.gameTime - 60,
            kind: .espionage,
            title: "Espionage at \(site.coordinate.displayText)",
            summary: "Intel",
            participants: [
                ReportParticipant(role: .attacker, factionID: universe.playerFactionID, planetID: playerPlanetIDs[0], name: "Scout"),
                ReportParticipant(role: .defender, factionID: nil, planetID: targetID, name: site.name)
            ]
        )
    )
    GameplayExpansionEngine.refresh(in: &universe)
    let chain = requireHostileActionChain(in: universe)

    let plan = ActionChainFleetPlannerEngine.nextActionPlan(for: chain.id, in: universe)

    requireEqual(plan.stepKind, .strikeHostile, "Planner should advance to hostile strike")
    requireEqual(plan.originID, playerPlanetIDs[1], "Planner should choose the origin whose strike fleet covers required power")
    require(plan.selectedPower >= plan.requiredPower, "Strike plan should expose enough selected power for the target")
    require(plan.powerRatio >= 1, "Strike power ratio should show the selected fleet can handle the site")
    requireEqual(plan.riskLevel, .low, "Sufficient strike should be marked low risk")
}

func testActionChainFleetPlannerRecommendsAvailableCommanderForHostileStrike() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    universe.reports = []
    let commander = OwnedCommander(
        id: CommanderID(UUID(uuidString: "00000000-0000-0000-0000-00000000c701")!),
        definitionID: "lin-vanguard",
        rarity: .legendary,
        level: 12,
        acquiredAt: 0
    )
    universe.commanderRoster.ownedCommanders = [commander]
    for index in universe.planets.indices where universe.planets[index].ownerID == universe.playerFactionID {
        universe.planets[index].resources.deuterium = 1_000_000
    }

    GameplayExpansionEngine.refresh(in: &universe)
    guard let site = universe.hostileSites.sorted(by: { $0.threatLevel < $1.threatLevel }).first,
          let targetID = site.targetPlanetID
    else {
        fatalError("Expansion should create a hostile site")
    }
    universe.reports.append(
        Report(
            time: universe.gameTime - 60,
            kind: .espionage,
            title: "Espionage at \(site.coordinate.displayText)",
            summary: "Intel",
            participants: [
                ReportParticipant(role: .attacker, factionID: universe.playerFactionID, planetID: strategicPlanetID(1), name: "Scout"),
                ReportParticipant(role: .defender, factionID: nil, planetID: targetID, name: site.name)
            ]
        )
    )
    GameplayExpansionEngine.refresh(in: &universe)
    let chain = requireHostileActionChain(in: universe)

    let plan = ActionChainFleetPlannerEngine.nextActionPlan(for: chain.id, in: universe)

    requireEqual(plan.stepKind, .strikeHostile, "Planner should advance to hostile strike")
    requireEqual(plan.commanderID, commander.id, "Hostile quick strike should recommend an available commander")
    require(plan.selectedPower >= plan.requiredPower, "Commander-backed strike should still expose sufficient power")
}

func testActionChainFleetPlannerSizesRecyclerWaveForHostileDebris() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    universe.reports = []
    guard let originIndex = universe.planets.firstIndex(where: { $0.ownerID == universe.playerFactionID }) else {
        fatalError("Expansion fixture should include a player origin")
    }
    universe.planets[originIndex].resources.deuterium = 1_000_000
    universe.planets[originIndex].shipInventory[.recycler] = 5

    GameplayExpansionEngine.refresh(in: &universe)
    guard let site = universe.hostileSites.sorted(by: { $0.threatLevel < $1.threatLevel }).first,
          let targetID = site.targetPlanetID,
          let targetIndex = universe.planets.firstIndex(where: { $0.id == targetID })
    else {
        fatalError("Expansion should create a hostile site with a target")
    }
    let largeDebris = ResourceBundle(metal: 30_000, crystal: 15_000)
    universe.planets[targetIndex].debrisField = largeDebris
    universe.reports.append(
        Report(
            time: universe.gameTime - 60,
            kind: .espionage,
            title: "Espionage at \(site.coordinate.displayText)",
            summary: "Intel",
            participants: [
                ReportParticipant(role: .attacker, factionID: universe.playerFactionID, planetID: universe.planets[originIndex].id, name: "Scout"),
                ReportParticipant(role: .defender, factionID: nil, planetID: targetID, name: site.name)
            ]
        )
    )
    universe.reports.append(
        Report(
            time: universe.gameTime - 30,
            kind: .battle,
            title: "Battle at \(site.coordinate.displayText)",
            summary: "Attacker wins.",
            participants: [
                ReportParticipant(role: .attacker, factionID: universe.playerFactionID, planetID: universe.planets[originIndex].id, name: "Raider"),
                ReportParticipant(role: .defender, factionID: nil, planetID: targetID, name: site.name)
            ],
            debris: largeDebris
        )
    )
    GameplayExpansionEngine.refresh(in: &universe)
    let chain = requireHostileActionChain(in: universe)

    let plan = ActionChainFleetPlannerEngine.nextActionPlan(for: chain.id, in: universe)
    let recyclerCount = plan.ships[.recycler] ?? 0

    requireEqual(plan.stepKind, .recoverSpoils, "Planner should advance to debris recovery after the hostile strike")
    requireEqual(recyclerCount, 3, "Recovery quick plan should send enough recyclers for known hostile debris")
    require(
        testCargoCapacity(plan.ships, ruleSet: universe.ruleSet) >= resourceTotal(largeDebris),
        "Recovery quick plan should cover the known debris capacity when ships are available"
    )
}

func testActionChainFeedbackSummarizesLatestHostileBattleReport() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    universe.reports = []
    GameplayExpansionEngine.refresh(in: &universe)
    guard let site = universe.hostileSites.sorted(by: { $0.threatLevel < $1.threatLevel }).first,
          let targetID = site.targetPlanetID
    else {
        fatalError("Expansion should create a hostile site with a target")
    }
    let chain = requireHostileActionChain(in: universe)
    let matchedReportID = UUID(uuidString: "00000000-0000-0000-0000-00000000b701")!
    let unrelatedReportID = UUID(uuidString: "00000000-0000-0000-0000-00000000b702")!
    let battleReport = Report(
        id: matchedReportID,
        time: universe.gameTime - 20,
        kind: .battle,
        title: "Battle at \(site.coordinate.displayText)",
        summary: "Player raiders broke the hostile screen.",
        participants: [
            ReportParticipant(
                role: .attacker,
                factionID: universe.playerFactionID,
                planetID: strategicPlanetID(1),
                name: "Raider",
                beforeShips: [.cruiser: 4],
                afterShips: [.cruiser: 3]
            ),
            ReportParticipant(
                role: .defender,
                factionID: nil,
                planetID: targetID,
                name: site.name,
                beforeShips: [.lightFighter: 12],
                afterShips: [:],
                beforeDefenses: [.rocketLauncher: 10],
                afterDefenses: [.rocketLauncher: 2]
            )
        ],
        loot: ResourceBundle(metal: 1_500, crystal: 600, deuterium: 120),
        debris: ResourceBundle(metal: 200_000, crystal: 90_000),
        losses: ResourceBundle(metal: 10_000, crystal: 4_000, deuterium: 1_000),
        battleRounds: [
            BattleRoundSummary(
                round: 1,
                attackerPower: 2_400,
                defenderPower: 1_100,
                attackerLosses: [.lightFighter: 1],
                defenderShipLosses: [.lightFighter: 8],
                defenderDefenseLosses: [.rocketLauncher: 5],
                rapidFireShots: 3,
                shieldDamage: 900,
                hullDamage: 1_600,
                explodedUnits: 4
            )
        ]
    )
    universe.reports.append(
        Report(
            id: unrelatedReportID,
            time: universe.gameTime - 10,
            kind: .battle,
            title: "Battle elsewhere",
            summary: "This should not be attached to the hostile action chain.",
            participants: [
                ReportParticipant(role: .attacker, factionID: universe.playerFactionID, planetID: strategicPlanetID(1), name: "Raider"),
                ReportParticipant(role: .defender, factionID: nil, planetID: strategicPlanetID(99), name: "Wrong Target")
            ],
            loot: ResourceBundle(metal: 99_000),
            debris: ResourceBundle(metal: 99_000),
            losses: ResourceBundle(metal: 99_000)
        )
    )
    universe.reports.append(battleReport)

    guard let feedback = ActionChainFeedbackEngine.feedback(for: chain.id, in: universe) else {
        fatalError("Hostile action chain should expose battle feedback after a matching report")
    }

    requireEqual(feedback.kind, .battle, "Feedback should classify the attached report as battle feedback")
    requireEqual(feedback.reportID, matchedReportID, "Feedback should ignore newer unrelated battle reports")
    requireEqual(feedback.loot, battleReport.loot, "Feedback should expose looted resources")
    requireEqual(feedback.debris, battleReport.debris, "Feedback should expose generated debris")
    requireEqual(feedback.losses, battleReport.losses, "Feedback should expose resource losses")
    requireEqual(feedback.moonChancePercent, UniverseTopologyEngine.moonChancePercent(forDebris: battleReport.debris), "Feedback should expose service-style moon chance")
    requireEqual(feedback.commanderExperienceEstimate, 30, "Feedback should estimate commander experience from battle losses")
    require(feedback.detail.contains("掠夺"), "Feedback detail should mention loot for quick player reading")
    require(feedback.detail.contains("月球"), "Feedback detail should mention moon chance for follow-up decisions")
}

func testClaimedActionChainDoesNotRegenerateOnExpansionRefresh() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    GameplayExpansionEngine.refresh(in: &universe)
    guard let originalChain = universe.actionChains.first(where: { $0.kind == .sectorDevelopment }) else {
        fatalError("Expansion should create a claimable sector development chain")
    }
    require(ActionChainRewardEngine.canClaim(originalChain, at: universe.gameTime), "Sector chain should be claimable with an existing trade route")

    let result = ActionChainRewardEngine.claim(originalChain.id, in: &universe)
    requireEqual(result.status, .claimed, "Sector chain should claim successfully")

    GameplayExpansionEngine.refresh(in: &universe)

    require(!universe.actionChains.contains { $0.id == originalChain.id }, "Claimed action chain should not regenerate on refresh")
}

func testStrategicAdvisorSurfacesExpansionOpportunities() {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    GameplayExpansionEngine.refresh(in: &universe)

    let recommendations = StrategicAdvisorEngine.recommendations(in: universe, limit: 12)
    let kinds = Set(recommendations.map(\.kind))

    require(kinds.contains(.sectorEvent), "Advisor should surface active sector events")
    require(kinds.contains(.hostileSite), "Advisor should surface PVE hostile targets")
    require(kinds.contains(.actionChain), "Advisor should surface action chains")
    require(kinds.contains(.tradeRoute), "Advisor should surface profitable trade routes")
    require(kinds.contains(.deepIntel), "Advisor should surface deep intel opportunities")
    require(kinds.contains(.artifact), "Advisor should surface artifact choices")
    require(kinds.contains(.crisis), "Advisor should surface active crises")
}

func testStrategicAdvisorSurfacesCommanderRecruitmentAndAssignment() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 5, playerName: "Commander")
    universe.commanderRoster.recruitmentTickets = 10
    universe.commanderRoster.ownedCommanders = [
        OwnedCommander(definitionID: "lin-vanguard", rarity: .legendary, acquiredAt: 0)
    ]
    universe.commanderRoster.trainingData = 500
    if let originIndex = universe.planets.firstIndex(where: { $0.ownerID == universe.playerFactionID }) {
        universe.planets[originIndex].shipInventory[.lightFighter] = 2
    }
    StrategicEngine.updateStrategicState(in: &universe)

    let recommendations = StrategicAdvisorEngine.recommendations(in: universe, limit: 12)
    let kinds = Set(recommendations.map(\.kind))

    require(kinds.contains(.commanderRecruitment), "Advisor should surface available commander recruitment")
    require(kinds.contains(.commanderTraining), "Advisor should surface commander training")
    require(kinds.contains(.commanderAssignment), "Advisor should surface commander fleet assignment")
}

func testGameplayAuditCountsCommanderSignals() {
    let result = GameplayAuditEngine.runAutoplayAudit(
        seed: 1,
        duration: 14_400,
        settings: GameSettings(difficulty: .standard)
    )

    require(result.commanderSignalCount > 0, "Gameplay audit should count commander module signals")
}

func testGameplayExpansionStateRoundTripsThroughJSON() throws {
    var universe = makeExpansionUniverse(gameTime: 9_000)
    GameplayExpansionEngine.refresh(in: &universe)

    let data = try JSONEncoder().encode(universe)
    let decoded = try JSONDecoder().decode(Universe.self, from: data)

    requireEqual(decoded.sectorEvents, universe.sectorEvents, "Sector events should survive JSON round trip")
    requireEqual(decoded.hostileSites, universe.hostileSites, "Hostile sites should survive JSON round trip")
    requireEqual(decoded.actionChains, universe.actionChains, "Action chains should survive JSON round trip")
    requireEqual(decoded.sectorControlSummaries, universe.sectorControlSummaries, "Sector control should survive JSON round trip")
    requireEqual(decoded.tradeRoutes, universe.tradeRoutes, "Trade routes should survive JSON round trip")
    requireEqual(decoded.deepIntelOperations, universe.deepIntelOperations, "Deep intel operations should survive JSON round trip")
    requireEqual(decoded.fleetDoctrineSummaries, universe.fleetDoctrineSummaries, "Fleet doctrine summaries should survive JSON round trip")
    requireEqual(decoded.artifacts, universe.artifacts, "Artifacts should survive JSON round trip")
    requireEqual(decoded.crisisState, universe.crisisState, "Crisis state should survive JSON round trip")
}

func testStarterUniverseProvidesServiceStyleColonyPool() {
    let universe = StarterUniverseFactory.makeNewGame(seed: 23, playerName: "Commander")
    let neutralPlanets = universe.planets.filter { $0.ownerID == nil }
    let occupiedCoordinates = Set(universe.planets.map(\.coordinate))

    require(neutralPlanets.count >= 24, "Starter universe should expose a regional colony pool instead of only three neutral planets")
    requireEqual(occupiedCoordinates.count, universe.planets.count, "Starter universe should not duplicate coordinates")
    require(neutralPlanets.allSatisfy { UniverseTopologyEngine.isValidPlanetCoordinate($0.coordinate) }, "Neutral colony targets should be valid planet slots")
    require(neutralPlanets.contains { $0.coordinate.position >= 13 }, "Regional colony pool should include cold outer deuterium candidates")
    require(neutralPlanets.contains { $0.coordinate.position <= 3 }, "Regional colony pool should include hot inner solar candidates")
}

func testServiceStyleMoonChanceUsesDebrisThresholdAndCap() {
    requireEqual(
        UniverseTopologyEngine.moonChancePercent(forDebris: ResourceBundle(metal: 99_999, crystal: 0)),
        0,
        "Debris below 100,000 should not create a moon chance"
    )
    requireEqual(
        UniverseTopologyEngine.moonChancePercent(forDebris: ResourceBundle(metal: 100_000, crystal: 0)),
        1,
        "Every 100,000 debris should grant one percent moon chance"
    )
    requireEqual(
        UniverseTopologyEngine.moonChancePercent(forDebris: ResourceBundle(metal: 2_500_000, crystal: 0)),
        20,
        "Moon chance should cap at twenty percent"
    )
}

func testColonizationAppliesTopologyProfileAndExpeditionSlotCannotBeColonized() {
    var universe = makeFleetUniverse(originResources: ResourceBundle(metal: 20_000, crystal: 20_000, deuterium: 20_000))
    let expectedProfile = UniverseTopologyEngine.planetProfile(for: universe.planets[1].coordinate, universeSeed: universe.seed)
    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .colonize,
        ships: [.colonyShip: 1],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Colonization fleet should launch to a normal empty planet slot")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    let colony = requirePlanet(fleetPlanetID(2), in: universe, "Colonized planet should remain")
    requireEqual(colony.maxFields, expectedProfile.maxFields, "Colonized world should receive topology-derived fields")
    requireEqual(colony.temperatureCelsius, expectedProfile.temperatureCelsius, "Colonized world should receive topology-derived temperature")

    var expeditionUniverse = makeFleetUniverse(originResources: ResourceBundle(metal: 20_000, crystal: 20_000, deuterium: 20_000))
    expeditionUniverse.planets[1].coordinate = Coordinate(galaxy: 1, system: 1, position: UniverseTopologyEngine.expeditionPosition)
    let expeditionColonize = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &expeditionUniverse,
        mission: .colonize,
        ships: [.colonyShip: 1],
        cargo: .zero
    )
    requireEqual(expeditionColonize, .failure(.invalidMission), "Position 16 should not accept colonization")

    let expeditionExplore = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &expeditionUniverse,
        mission: .explore,
        ships: [.smallCargo: 1],
        cargo: .zero
    )
    guard case .launched = expeditionExplore else {
        fatalError("Position 16 should accept exploration")
    }

    var cappedUniverse = makeFleetUniverse(originResources: ResourceBundle(metal: 20_000, crystal: 20_000, deuterium: 20_000))
    let extraColonies = (3...(UniverseTopologyEngine.defaultMaxPlayerPlanets + 1)).map { index in
        Planet(
            id: fleetPlanetID(index),
            name: "Colony \(index)",
            coordinate: Coordinate(galaxy: 1, system: index + 1, position: 6),
            ownerID: fleetPlayerID()
        )
    }
    cappedUniverse.planets.append(contentsOf: extraColonies)
    cappedUniverse.factions[0].ownedPlanetIDs = [fleetPlanetID(1)] + extraColonies.map(\.id)
    let cappedColonize = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &cappedUniverse,
        mission: .colonize,
        ships: [.colonyShip: 1],
        cargo: .zero
    )
    requireEqual(cappedColonize, .failure(.invalidMission), "Faction at colony cap should not launch another colonization fleet")

    var astrophysicsUniverse = cappedUniverse
    astrophysicsUniverse.factions[0].technology.levels[.astrophysics] = 2
    let expandedCapColonize = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &astrophysicsUniverse,
        mission: .colonize,
        ships: [.colonyShip: 1],
        cargo: .zero
    )
    guard case .launched = expandedCapColonize else {
        fatalError("Astrophysics should raise the colony cap beyond the service baseline")
    }
}

func testColonizationTargetEngineSeedsVisibleEmptySlotForFleetPage() {
    var universe = makeFleetUniverse(originResources: ResourceBundle(metal: 20_000, crystal: 20_000, deuterium: 20_000))
    let coordinate = Coordinate(galaxy: 1, system: 3, position: 8)
    let originalPlanetCount = universe.planets.count

    guard let targetID = ColonizationTargetEngine.ensureNeutralTarget(
        at: coordinate,
        visibleTo: fleetPlayerID(),
        in: &universe
    ) else {
        fatalError("Empty valid planet slot should be seeded as a neutral colonization target")
    }

    requireEqual(universe.planets.count, originalPlanetCount + 1, "Seeding should append one neutral target planet")
    let target = requirePlanet(targetID, in: universe, "Seeded target should exist")
    requireEqual(target.coordinate, coordinate, "Seeded target should use the requested coordinate")
    requireEqual(target.ownerID, nil, "Seeded target should be unowned before colonization")
    require(
        universe.explorationRecords.contains { $0.factionID == fleetPlayerID() && $0.targetPlanetID == targetID && $0.discoveredNeutral },
        "Seeded target should be visible to the requesting faction"
    )

    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: targetID,
        in: &universe,
        mission: .colonize,
        ships: [.colonyShip: 1],
        cargo: .zero
    )
    guard case .launched = launch else {
        fatalError("Fleet page seeded target should be immediately launchable for colonization")
    }
}

func testFleetTargetSelectionSeedsEmptyAndExpeditionSlotsForFleetPage() {
    var universe = makeFleetUniverse(originResources: ResourceBundle(metal: 20_000, crystal: 20_000, deuterium: 20_000))
    let emptyCoordinate = Coordinate(galaxy: 1, system: 4, position: 9)
    let expeditionCoordinate = Coordinate(galaxy: 1, system: 4, position: UniverseTopologyEngine.expeditionPosition)

    guard let colonyTargetID = FleetTargetSelectionEngine.ensureTarget(
        at: emptyCoordinate,
        visibleTo: fleetPlayerID(),
        in: &universe
    ) else {
        fatalError("Fleet page should be able to select an empty planet slot")
    }
    let colonyTarget = requirePlanet(colonyTargetID, in: universe, "Selected empty planet slot should become a target")
    requireEqual(colonyTarget.coordinate, emptyCoordinate, "Empty slot target should preserve coordinate")
    require(UniverseTopologyEngine.isValidPlanetCoordinate(colonyTarget.coordinate), "Empty slot target should be a planet coordinate")

    guard let expeditionTargetID = FleetTargetSelectionEngine.ensureTarget(
        at: expeditionCoordinate,
        visibleTo: fleetPlayerID(),
        in: &universe
    ) else {
        fatalError("Fleet page should be able to select the expedition slot")
    }
    let expeditionTarget = requirePlanet(expeditionTargetID, in: universe, "Selected expedition slot should become a target")
    requireEqual(expeditionTarget.coordinate, expeditionCoordinate, "Expedition target should preserve coordinate")
    require(UniverseTopologyEngine.isExpeditionCoordinate(expeditionTarget.coordinate), "Expedition target should use position 16")

    let exploration = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: expeditionTargetID,
        in: &universe,
        mission: .explore,
        ships: [.smallCargo: 1],
        cargo: .zero
    )
    guard case .launched = exploration else {
        fatalError("Fleet page selected expedition target should be launchable for exploration")
    }
}

func testTestingResourceGrantSetsPlayerOwnedPlanetsToInfiniteResources() {
    var universe = makeStrategicUniverse(playerPlanetCount: 2, aiPlanetCount: 1, neutralPlanetCount: 1)
    let playerPlanetIDs = Set(universe.factions.first { $0.id == universe.playerFactionID }?.ownedPlanetIDs ?? [])
    let unchangedPlanets = universe.planets.filter { !playerPlanetIDs.contains($0.id) }

    let updatedCount = TestingResourceGrant.grantInfiniteResources(toPlayerIn: &universe)

    requireEqual(updatedCount, playerPlanetIDs.count, "Resource grant should report updated player planets")
    for planet in universe.planets where playerPlanetIDs.contains(planet.id) {
        requireEqual(planet.resources, TestingResourceGrant.infiniteResourceBundle, "Player planets should receive infinite test resources")
        requireEqual(planet.storage, TestingResourceGrant.infiniteStorage, "Player planets should receive infinite test storage")
    }
    for planet in unchangedPlanets {
        let updated = requirePlanet(planet.id, in: universe, "Non-player planet should remain after test resource grant")
        requireEqual(updated.resources, planet.resources, "Resource grant should not mutate non-player resources")
        requireEqual(updated.storage, planet.storage, "Resource grant should not mutate non-player storage")
    }
}

func testTestingResourceGrantIncludesCommanderRecruitmentAccess() {
    var universe = makeStrategicUniverse(playerPlanetCount: 1, aiPlanetCount: 1, neutralPlanetCount: 1)
    universe.commanderRoster.recruitmentTickets = 2
    universe.commanderRoster.trainingData = 50

    let result = TestingResourceGrant.grantInfiniteTestingAccess(toPlayerIn: &universe)

    requireEqual(result.updatedPlanetCount, 1, "Combined test grant should still update player planets")
    requireEqual(
        universe.commanderRoster.recruitmentTickets,
        TestingResourceGrant.infiniteCommanderAmount,
        "Combined test grant should make commander recruitment effectively unlimited"
    )
    requireEqual(
        universe.commanderRoster.trainingData,
        TestingResourceGrant.infiniteCommanderAmount,
        "Combined test grant should make commander training effectively unlimited"
    )

    let recruitment = CommanderRecruitmentEngine.recruit(count: 10, in: &universe)
    requireEqual(recruitment.pulls.count, 10, "Injected commander tickets should allow a ten-pull immediately")
    requireEqual(universe.commanderRoster.pendingRecruits.count, 10, "Injected commander tickets should still create selectable candidates")
    requireEqual(universe.commanderRoster.ownedCommanders.count, 0, "Injected commander tickets should not bypass candidate selection")
    requireEqual(
        universe.commanderRoster.recruitmentTickets,
        TestingResourceGrant.infiniteCommanderAmount - 10,
        "Commander recruitment should still spend tickets so normal rules stay intact"
    )
}

func testPlayerObjectivesAwardRewardsOnce() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 301, playerName: "Commander")
    universe.planets[0].buildingLevels[.solarPlant] = 4
    let startingResources = universe.planets[0].resources
    let startingEventCount = universe.events.count

    let completed = PlayerObjectiveEngine.updatePlayerObjectives(in: &universe)

    requireEqual(completed.map(\.kind), [.solarStability], "Solar stability should be the only newly completed starter objective")
    requireEqual(universe.playerObjectiveRecords.count, 1, "Completed objective should be recorded")
    requireEqual(universe.playerObjectiveRecords[0].kind, .solarStability, "Objective record should preserve objective kind")
    requireEqual(universe.playerObjectiveRecords[0].completedAt, universe.gameTime, "Objective record should preserve completion time")
    requireEqual(
        universe.planets[0].resources,
        startingResources.adding(completed[0].reward),
        "Objective reward should be added to the first player planet"
    )
    requireEqual(universe.events.count, startingEventCount + 1, "Objective completion should create one event")
    requireEqual(universe.events.last?.title, "阶段目标完成", "Objective completion event should be player-facing")

    let resourcesAfterFirstUpdate = universe.planets[0].resources
    let eventsAfterFirstUpdate = universe.events
    let repeated = PlayerObjectiveEngine.updatePlayerObjectives(in: &universe)

    requireEqual(repeated, [], "Completed objective rewards should not repeat")
    requireEqual(universe.planets[0].resources, resourcesAfterFirstUpdate, "Repeated objective update should not add more resources")
    requireEqual(universe.events, eventsAfterFirstUpdate, "Repeated objective update should not duplicate events")
}

func testPlayerObjectiveStatesExposeProgressAndCompletedRecords() {
    var universe = StarterUniverseFactory.makeNewGame(seed: 302, playerName: "Commander")
    universe.planets[0].buildingLevels[.solarPlant] = 2

    let earlyStates = PlayerObjectiveEngine.states(in: universe)
    guard let solarState = earlyStates.first(where: { $0.kind == .solarStability }) else {
        fatalError("Objective states should include solar stability")
    }
    requireEqual(solarState.progressValue, 2, "Objective progress should reflect current solar plant level")
    requireEqual(solarState.targetValue, 4, "Solar objective target should be level 4")
    requireEqual(solarState.isComplete, false, "Solar objective should not be complete below target")
    requireEqual(solarState.isClaimed, false, "Unawarded objective should not be claimed")

    universe.planets[0].buildingLevels[.solarPlant] = 4
    _ = PlayerObjectiveEngine.updatePlayerObjectives(in: &universe)
    let completedStates = PlayerObjectiveEngine.states(in: universe)
    let completedSolar = completedStates.first { $0.kind == .solarStability }
    requireEqual(completedSolar?.isComplete, true, "Completed objective should report complete")
    requireEqual(completedSolar?.isClaimed, true, "Awarded objective should report claimed")
}

func strategicPlayerID() -> FactionID {
    FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000501")!)
}

func strategicAIID() -> FactionID {
    FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000502")!)
}

func strategicPlanetID(_ index: Int) -> PlanetID {
    PlanetID(UUID(uuidString: String(format: "00000000-0000-0000-0005-%012d", index))!)
}

func makeStrategicUniverse(
    playerTechnology: [TechnologyKind: Int] = [.computer: 2, .energy: 2, .weapons: 1],
    playerPlanetCount: Int = 2,
    aiPlanetCount: Int = 1,
    neutralPlanetCount: Int = 3,
    exploredNeutralPlanetCount: Int = 0,
    playerResources: ResourceBundle = ResourceBundle(metal: 12_000, crystal: 8_000, deuterium: 4_000)
) -> Universe {
    let playerID = strategicPlayerID()
    let aiID = strategicAIID()
    var planets: [Planet] = []

    for index in 1...playerPlanetCount {
        planets.append(
            Planet(
                id: strategicPlanetID(index),
                name: "Player \(index)",
                coordinate: Coordinate(galaxy: 1, system: index, position: 4),
                ownerID: playerID,
                resources: playerResources,
                storage: ResourceStorage(metal: 200_000, crystal: 200_000, deuterium: 200_000),
                buildingLevels: [
                    .metalMine: 8 + index,
                    .crystalMine: 7,
                    .deuteriumSynthesizer: 5,
                    .solarPlant: 10,
                    .researchLab: 4,
                    .shipyard: 3
                ],
                shipInventory: [.smallCargo: 6, .lightFighter: 8, .colonyShip: 1],
                defenseInventory: [.rocketLauncher: 12, .lightLaser: 4]
            )
        )
    }

    for index in 1...aiPlanetCount {
        planets.append(
            Planet(
                id: strategicPlanetID(20 + index),
                name: "AI \(index)",
                coordinate: Coordinate(galaxy: 1, system: 20 + index, position: 5),
                ownerID: aiID,
                resources: ResourceBundle(metal: 600, crystal: 400, deuterium: 100),
                buildingLevels: [.metalMine: 1, .crystalMine: 1, .solarPlant: 1],
                shipInventory: [.espionageProbe: 1],
                defenseInventory: [:]
            )
        )
    }

    for index in 1...neutralPlanetCount {
        planets.append(
            Planet(
                id: strategicPlanetID(40 + index),
                name: "Neutral \(index)",
                coordinate: Coordinate(galaxy: 1, system: 40 + index, position: 8),
                ownerID: nil,
                resources: ResourceBundle(metal: 100, crystal: 50, deuterium: 20),
                debrisField: ResourceBundle(metal: 25)
            )
        )
    }

    let exploredIDs = Array(planets.filter { $0.ownerID == nil }.map(\.id).prefix(exploredNeutralPlanetCount))

    return Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000500")!),
        name: "Strategic Test",
        seed: 55,
        gameTime: 120,
        playerFactionID: playerID,
        factions: [
            Faction(
                id: playerID,
                name: "Strategist",
                kind: .player,
                strategy: .balanced,
                technology: ResearchState(levels: playerTechnology),
                ownedPlanetIDs: planets.filter { $0.ownerID == playerID }.map(\.id)
            ),
            Faction(
                id: aiID,
                name: "Rival",
                kind: .ai,
                strategy: .miner,
                technology: ResearchState(levels: [.energy: 1]),
                ownedPlanetIDs: planets.filter { $0.ownerID == aiID }.map(\.id)
            )
        ],
        planets: planets,
        fleets: [
            Fleet(
                id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-000000000503")!),
                ownerID: playerID,
                mission: .transport,
                origin: Coordinate(galaxy: 1, system: 1, position: 4),
                target: Coordinate(galaxy: 1, system: 2, position: 4),
                ships: [.smallCargo: 2, .lightFighter: 3],
                launchTime: 120,
                arrivalTime: 240,
                returnTime: 360
            )
        ],
        events: [],
        ruleSet: .fastSkirmish,
        victoryState: VictoryState(exploredPlanetIDs: exploredIDs)
    )
}

func makeExpansionUniverse(gameTime: TimeInterval = 9_000) -> Universe {
    var universe = makeStrategicUniverse(
        playerTechnology: [.computer: 4, .energy: 3, .espionage: 3, .weapons: 3, .shielding: 2, .armor: 2, .combustionDrive: 2, .impulseDrive: 2],
        playerPlanetCount: 3,
        aiPlanetCount: 2,
        neutralPlanetCount: 4,
        exploredNeutralPlanetCount: 2,
        playerResources: ResourceBundle(metal: 80_000, crystal: 50_000, deuterium: 20_000)
    )
    universe.gameTime = gameTime
    universe.planets[1].coordinate = Coordinate(galaxy: 1, system: 1, position: 6)
    universe.planets[2].coordinate = Coordinate(galaxy: 1, system: 1, position: 8)
    universe.planets[0].shipInventory[.recycler] = 2
    universe.planets[0].shipInventory[.cruiser] = 4
    universe.planets[0].shipInventory[.espionageProbe] = 3
    universe.planets[0].moon = Moon(
        name: "Luna",
        createdAt: 7_500,
        buildingLevels: [.lunarBase: 2, .sensorPhalanx: 1, .jumpGate: 1]
    )
    universe.reports.append(
        Report(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000005aa")!,
            time: 7_200,
            kind: .battle,
            title: "Skirmish",
            summary: "Player cleared a raider screen.",
            participants: [
                ReportParticipant(role: .attacker, factionID: universe.playerFactionID, planetID: strategicPlanetID(1), name: "Strategist", beforeShips: [.cruiser: 4], afterShips: [.cruiser: 3]),
                ReportParticipant(role: .defender, factionID: strategicAIID(), planetID: strategicPlanetID(21), name: "Rival", beforeShips: [.lightFighter: 4], afterShips: [:])
            ],
            loot: ResourceBundle(metal: 2_000, crystal: 1_000),
            debris: ResourceBundle(metal: 8_000, crystal: 4_000),
            battleRounds: [
                BattleRoundSummary(round: 1, attackerPower: 1_200, defenderPower: 400, rapidFireShots: 2, shieldDamage: 300, hullDamage: 600, explodedUnits: 2)
            ]
        )
    )
    StrategicEngine.updateStrategicState(in: &universe)
    return universe
}

func requireHostileActionChain(in universe: Universe) -> ActionChain {
    guard let chain = universe.actionChains.first(where: { $0.kind == .hostileRaid }) else {
        fatalError("Expected hostile raid action chain")
    }

    return chain
}

func stepStatus(_ kind: ActionChain.Step.Kind, in chain: ActionChain) -> ActionChain.Step.Status? {
    chain.steps.first { $0.kind == kind }?.status
}

func makeCommanderFleetTestUniverse() -> (
    universe: Universe,
    originID: PlanetID,
    targetID: PlanetID,
    secondTargetID: PlanetID,
    originCoordinate: Coordinate,
    targetCoordinate: Coordinate
) {
    var universe = StarterUniverseFactory.makeNewGame(seed: 501, playerName: "Commander")
    let playerPlanets = PlayerVisibilityEngine.playerOwnedPlanets(in: universe).sorted {
        $0.coordinate.displayText < $1.coordinate.displayText
    }
    guard let origin = playerPlanets.first else {
        fatalError("Expected starter universe to contain a player planet")
    }
    guard let originIndex = universe.planets.firstIndex(where: { $0.id == origin.id }) else {
        fatalError("Expected origin planet index")
    }
    universe.planets[originIndex].shipInventory[.lightFighter] = 8
    universe.planets[originIndex].resources.deuterium = 100_000
    if let playerIndex = universe.factions.firstIndex(where: { $0.id == universe.playerFactionID }) {
        universe.factions[playerIndex].technology.levels[.computer] = 3
    }

    let targets = universe.planets
        .filter { $0.ownerID != nil && $0.ownerID != universe.playerFactionID }
        .sorted { $0.coordinate.displayText < $1.coordinate.displayText }
    guard targets.count >= 2 else {
        fatalError("Expected at least two non-player targets")
    }

    return (
        universe,
        origin.id,
        targets[0].id,
        targets[1].id,
        origin.coordinate,
        targets[0].coordinate
    )
}

func requireStrategicScore(_ rankings: [FactionScore], for factionID: FactionID) -> FactionScore {
    guard let score = rankings.first(where: { $0.factionID == factionID }) else {
        fatalError("Expected rankings to contain faction \(factionID)")
    }

    return score
}

func requireVictoryProgress(_ state: VictoryState, factionID: FactionID, route: VictoryRoute) -> VictoryProgress {
    guard let progress = state.progress.first(where: { $0.factionID == factionID && $0.route == route }) else {
        fatalError("Expected victory progress for \(route.rawValue)")
    }

    return progress
}

func testPlayerVisibilityUsesPlanetOwnerAsSourceOfTruth() {
    var universe = makeStrategicUniverse(playerPlanetCount: 2, aiPlanetCount: 1, neutralPlanetCount: 1)
    let missingIndexedPlanetID = strategicPlanetID(2)
    let aiPlanetID = strategicPlanetID(21)

    guard let playerIndex = universe.factions.firstIndex(where: { $0.id == universe.playerFactionID }) else {
        fatalError("Player faction should exist")
    }

    universe.factions[playerIndex].ownedPlanetIDs = [strategicPlanetID(1), aiPlanetID]

    let visiblePlanets = PlayerVisibilityEngine.playerOwnedPlanets(in: universe)
    let visibleIDs = Set(visiblePlanets.map(\.id))

    requireEqual(visiblePlanets.count, 2, "Player-owned planet visibility should follow planet ownerID")
    require(visibleIDs.contains(missingIndexedPlanetID), "A player-owned colony should stay visible even when the faction index is stale")
    require(!visibleIDs.contains(aiPlanetID), "A stale faction index should not expose a rival planet as player-owned")

    PlayerVisibilityEngine.normalizeFactionPlanetIndexes(in: &universe)
    requireEqual(
        universe.factions[playerIndex].ownedPlanetIDs,
        [strategicPlanetID(1), missingIndexedPlanetID],
        "Ownership index normalization should remove stale rival IDs and append missing player colonies"
    )

    let secondColonyState = PlayerObjectiveEngine.states(in: universe).first { $0.kind == .secondColony }
    requireEqual(secondColonyState?.progressValue, 2, "Player objectives should also count ownerID-backed colonies")
}

func testStrategicRankingsScoreFactionStrengthsAndVictoryProgress() {
    let universe = makeStrategicUniverse()
    let rankings = StrategicEngine.rankings(in: universe)
    let playerScore = requireStrategicScore(rankings, for: strategicPlayerID())
    let aiScore = requireStrategicScore(rankings, for: strategicAIID())

    requireEqual(rankings.count, 2, "Strategic rankings should include every faction")
    requireEqual(playerScore.rank, 1, "Stronger player should lead strategic rankings")
    require(playerScore.economyScore > 0, "Economy score should account for buildings, production, and stockpiles")
    require(playerScore.fleetScore > 0, "Fleet score should account for docked and active ships")
    require(playerScore.researchScore > 0, "Research score should account for completed technologies")
    require(playerScore.planetScore > 0, "Planet score should account for owned planets")
    require(playerScore.defenseScore > 0, "Defense score should account for built defenses")
    require(playerScore.victoryProgress > aiScore.victoryProgress, "Victory progress should contribute to strategic comparison")
    require(
        playerScore.totalScore > aiScore.totalScore,
        "Strategic total should combine category strength and victory progress"
    )
}

func testStrategicVictoryRoutesTriggerForEconomyTechnologyDominationAndExploration() {
    var economyUniverse = makeStrategicUniverse(playerResources: ResourceBundle(metal: 120_000, crystal: 80_000, deuterium: 40_000))
    StrategicEngine.updateStrategicState(in: &economyUniverse)
    requireEqual(economyUniverse.victoryState.winningRoute, .economy, "Large resource economy should trigger economy victory")

    var technologyUniverse = makeStrategicUniverse(
        playerTechnology: Dictionary(uniqueKeysWithValues: TechnologyKind.allCases.map { ($0, 3) }),
        playerResources: ResourceBundle(metal: 1_000, crystal: 1_000, deuterium: 1_000)
    )
    StrategicEngine.updateStrategicState(in: &technologyUniverse)
    requireEqual(technologyUniverse.victoryState.winningRoute, .technology, "Broad research levels should trigger technology victory")

    var dominationUniverse = makeStrategicUniverse(
        playerTechnology: [.energy: 1],
        playerPlanetCount: 5,
        aiPlanetCount: 1,
        neutralPlanetCount: 2,
        playerResources: ResourceBundle(metal: 1_000, crystal: 1_000, deuterium: 1_000)
    )
    for index in dominationUniverse.planets.indices where dominationUniverse.planets[index].ownerID == strategicPlayerID() {
        dominationUniverse.planets[index].resources = .zero
        dominationUniverse.planets[index].buildingLevels = [:]
        dominationUniverse.planets[index].shipInventory = [:]
        dominationUniverse.planets[index].defenseInventory = [:]
    }
    StrategicEngine.updateStrategicState(in: &dominationUniverse)
    requireEqual(dominationUniverse.victoryState.winningRoute, .domination, "Owning most inhabited planets should trigger domination victory")

    var explorationUniverse = makeStrategicUniverse(
        playerTechnology: [.energy: 1],
        neutralPlanetCount: 3,
        exploredNeutralPlanetCount: 3,
        playerResources: ResourceBundle(metal: 1_000, crystal: 1_000, deuterium: 1_000)
    )
    for index in explorationUniverse.planets.indices where explorationUniverse.planets[index].ownerID == strategicPlayerID() {
        explorationUniverse.planets[index].resources = .zero
        explorationUniverse.planets[index].buildingLevels = [:]
        explorationUniverse.planets[index].shipInventory = [:]
        explorationUniverse.planets[index].defenseInventory = [:]
    }
    StrategicEngine.updateStrategicState(in: &explorationUniverse)
    requireEqual(explorationUniverse.victoryState.winningRoute, .exploration, "Exploring every neutral planet should trigger exploration victory")

    for universe in [economyUniverse, technologyUniverse, dominationUniverse, explorationUniverse] {
        requireEqual(universe.victoryState.winningFactionID, strategicPlayerID(), "Victory should record the winning faction")
        requireEqual(universe.events.filter { $0.kind == .victory }.count, 1, "Victory should record a single strategic event")
    }
}

func testLateGameObjectiveContributesToTechnologyVictory() {
    var universe = makeStrategicUniverse(
        playerTechnology: [
            .espionage: 3,
            .computer: 3,
            .weapons: 3,
            .shielding: 3,
            .armor: 3,
            .energy: 3,
            .combustionDrive: 2,
            .impulseDrive: 2,
            .hyperspaceDrive: 1
        ],
        playerResources: ResourceBundle(metal: 1_000, crystal: 1_000, deuterium: 1_000)
    )
    universe.planets[0].moon = Moon(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000005f0")!,
        name: "Luna",
        createdAt: universe.gameTime,
        buildingLevels: [:],
        debrisOriginReportID: UUID(uuidString: "00000000-0000-0000-0000-0000000005f1")!
    )

    StrategicEngine.updateStrategicState(in: &universe)

    let technologyProgress = requireVictoryProgress(
        universe.victoryState,
        factionID: strategicPlayerID(),
        route: .technology
    )
    requireEqual(technologyProgress.currentValue, 24, "Moon infrastructure should count as a late-game technology objective")
    requireEqual(universe.victoryState.winningRoute, .technology, "Late-game objective should complete technology victory")
}

func testSimulationContinuesTickingAfterVictoryWithoutRepeatingVictoryEvent() {
    var universe = makeStrategicUniverse(playerResources: ResourceBundle(metal: 120_000, crystal: 80_000, deuterium: 40_000))

    SimulationEngine.tick(universe: &universe, delta: 60)
    let firstVictoryEventCount = universe.events.filter { $0.kind == .victory }.count
    let firstGameTime = universe.gameTime

    SimulationEngine.tick(universe: &universe, delta: 60)

    requireEqual(firstVictoryEventCount, 1, "First victorious tick should record one victory event")
    requireEqual(universe.events.filter { $0.kind == .victory }.count, 1, "Later victorious ticks should not repeat the victory event")
    requireEqual(universe.gameTime, firstGameTime + 60, "Simulation should keep advancing after victory")
    requireEqual(universe.events.last?.title, "Simulation Advanced", "Simulation should still record normal tick events after victory")
    require(!universe.rankings.isEmpty, "Simulation tick should refresh strategic rankings")
}

func testStrategicStateRoundTripsThroughJSONAndDefaultsWhenMissing() throws {
    var universe = makeStrategicUniverse(neutralPlanetCount: 3, exploredNeutralPlanetCount: 2)
    StrategicEngine.updateStrategicState(in: &universe)

    let data = try JSONEncoder().encode(universe)
    let decoded = try JSONDecoder().decode(Universe.self, from: data)
    requireEqual(decoded.rankings, universe.rankings, "Rankings should round-trip through JSON")
    requireEqual(decoded.victoryState, universe.victoryState, "Victory state should round-trip through JSON")
    requireEqual(
        requireVictoryProgress(decoded.victoryState, factionID: strategicPlayerID(), route: .exploration).currentValue,
        2,
        "Exploration progress should round-trip with victory state"
    )

    let olderUniverseJSON = """
    {
      "id": { "rawValue": "00000000-0000-0000-0000-0000000005a0" },
      "name": "Older Strategic Universe",
      "seed": 21,
      "gameTime": 45,
      "playerFactionID": { "rawValue": "00000000-0000-0000-0000-0000000005a1" },
      "factions": [
        {
          "id": { "rawValue": "00000000-0000-0000-0000-0000000005a1" },
          "name": "Player",
          "kind": "player",
          "strategy": "balanced",
          "technology": { "levels": {} },
          "ownedPlanetIDs": [
            { "rawValue": "00000000-0000-0000-0000-0000000005a2" }
          ]
        }
      ],
      "planets": [
        {
          "id": { "rawValue": "00000000-0000-0000-0000-0000000005a2" },
          "name": "Homeworld",
          "coordinate": { "galaxy": 1, "system": 1, "position": 4 },
          "ownerID": { "rawValue": "00000000-0000-0000-0000-0000000005a1" },
          "resources": { "metal": 100, "crystal": 50, "deuterium": 25 },
          "storage": { "metal": 10000, "crystal": 10000, "deuterium": 10000 },
          "energy": { "produced": 20, "used": 8 },
          "buildingLevels": {},
          "shipInventory": {},
          "defenseInventory": {}
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

    let olderDecoded = try JSONDecoder().decode(Universe.self, from: Data(olderUniverseJSON.utf8))
    requireEqual(olderDecoded.rankings, [], "Older universe JSON should default missing rankings to empty")
    requireEqual(olderDecoded.victoryState, VictoryState(), "Older universe JSON should default missing victory state")
}

func testExplorationAndRelationStateRoundTripsAndDefaultsWhenMissing() throws {
    let playerID = strategicPlayerID()
    let rivalID = strategicAIID()
    let targetID = strategicPlanetID(91)
    let postures = RelationPosture.allCases
    var universe = makeStrategicUniverse()
    universe.explorationRecords = [
        ExplorationRecord(
            factionID: playerID,
            targetPlanetID: targetID,
            exploredAt: 240,
            reward: ResourceBundle(metal: 75, crystal: 20, deuterium: 5),
            discoveredResources: ResourceBundle(metal: 900, crystal: 100, deuterium: 40),
            discoveredDebris: ResourceBundle(metal: 25, crystal: 10),
            discoveredOwnerID: nil,
            discoveredNeutral: true
        )
    ]
    universe.factions[0].relations = [
        FactionRelation(factionID: rivalID, posture: .wary, threatScore: 1, lastInteractionTime: 120, attackCount: 1)
    ]

    let data = try JSONEncoder().encode(universe)
    let decoded = try JSONDecoder().decode(Universe.self, from: data)
    let decodedPostures = try JSONDecoder().decode([RelationPosture].self, from: try JSONEncoder().encode(postures))
    let sparseRelationJSON = """
    {
      "factionID": { "rawValue": "00000000-0000-0000-0000-0000000006af" },
      "threatScore": -4,
      "lastInteractionTime": -30,
      "attackCount": -2
    }
    """
    let sparseRelation = try JSONDecoder().decode(FactionRelation.self, from: Data(sparseRelationJSON.utf8))

    requireEqual(decoded.explorationRecords, universe.explorationRecords, "Exploration records should round-trip through JSON")
    requireEqual(decoded.factions[0].relations, universe.factions[0].relations, "Faction relation memory should round-trip through JSON")
    require(decoded.factions[0].relations.allSatisfy { $0.threatScore >= 0 }, "Relation threat scores should remain nonnegative")
    requireEqual(decodedPostures, [.neutral, .wary, .hostile, .pressured], "Relation postures should expose neutral, wary, hostile, and pressured")
    requireEqual(sparseRelation.posture, .neutral, "Sparse relation JSON should default posture to neutral")
    requireEqual(sparseRelation.threatScore, 0, "Sparse relation JSON should clamp negative threat")
    requireEqual(sparseRelation.lastInteractionTime, 0, "Sparse relation JSON should clamp negative interaction time")
    requireEqual(sparseRelation.attackCount, 0, "Sparse relation JSON should clamp negative attack count")

    let olderUniverseJSON = """
    {
      "id": { "rawValue": "00000000-0000-0000-0000-0000000006a0" },
      "name": "Older Relations Universe",
      "seed": 21,
      "gameTime": 45,
      "playerFactionID": { "rawValue": "00000000-0000-0000-0000-0000000006a1" },
      "factions": [
        {
          "id": { "rawValue": "00000000-0000-0000-0000-0000000006a1" },
          "name": "Player",
          "kind": "player",
          "strategy": "balanced",
          "technology": { "levels": {} },
          "ownedPlanetIDs": [
            { "rawValue": "00000000-0000-0000-0000-0000000006a2" }
          ]
        }
      ],
      "planets": [
        {
          "id": { "rawValue": "00000000-0000-0000-0000-0000000006a2" },
          "name": "Homeworld",
          "coordinate": { "galaxy": 1, "system": 1, "position": 4 },
          "ownerID": { "rawValue": "00000000-0000-0000-0000-0000000006a1" },
          "resources": { "metal": 100, "crystal": 50, "deuterium": 25 },
          "storage": { "metal": 10000, "crystal": 10000, "deuterium": 10000 },
          "energy": { "produced": 20, "used": 8 },
          "buildingLevels": {},
          "shipInventory": {},
          "defenseInventory": {}
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

    let olderDecoded = try JSONDecoder().decode(Universe.self, from: Data(olderUniverseJSON.utf8))
    requireEqual(olderDecoded.explorationRecords, [], "Older universe JSON should default missing exploration records to empty")
    requireEqual(olderDecoded.factions[0].relations, [], "Older faction JSON should default missing relations to empty")
}

func testStrategicExplorationRecordsAreFilteredByFaction() {
    let playerID = strategicPlayerID()
    let aiID = strategicAIID()
    let playerTargetID = strategicPlanetID(41)
    let aiTargetID = strategicPlanetID(42)
    var universe = makeStrategicUniverse()
    universe.explorationRecords = [
        ExplorationRecord(
            factionID: playerID,
            targetPlanetID: playerTargetID,
            exploredAt: 180,
            reward: ResourceBundle(metal: 30),
            discoveredResources: ResourceBundle(metal: 100, crystal: 50, deuterium: 20),
            discoveredDebris: ResourceBundle(metal: 25),
            discoveredNeutral: true
        ),
        ExplorationRecord(
            factionID: aiID,
            targetPlanetID: aiTargetID,
            exploredAt: 240,
            reward: ResourceBundle(crystal: 45),
            discoveredResources: ResourceBundle(metal: 777, crystal: 333, deuterium: 111),
            discoveredDebris: ResourceBundle(crystal: 99),
            discoveredNeutral: true
        )
    ]

    let playerRecords = StrategicEngine.explorationRecords(for: playerID, in: universe)
    let aiRecords = StrategicEngine.explorationRecords(for: aiID, in: universe)
    StrategicEngine.updateStrategicState(in: &universe)

    requireEqual(playerRecords.map(\.targetPlanetID), [playerTargetID], "Player exploration accessor should return only player records")
    requireEqual(aiRecords.map(\.targetPlanetID), [aiTargetID], "AI exploration accessor should return only AI records")
    requireEqual(playerRecords[0].discoveredResources, ResourceBundle(metal: 100, crystal: 50, deuterium: 20), "Player filtered records should preserve own discoveries")
    require(playerRecords.allSatisfy { $0.discoveredResources.metal != 777 }, "Player filtered records should not reveal rival discoveries")
    requireEqual(
        requireVictoryProgress(universe.victoryState, factionID: playerID, route: .exploration).currentValue,
        1,
        "Player exploration progress should use player records"
    )
    requireEqual(
        requireVictoryProgress(universe.victoryState, factionID: aiID, route: .exploration).currentValue,
        1,
        "AI exploration progress should use AI records"
    )
}

func testStrategicRankingsClampInvalidNumericInputs() {
    let playerID = strategicPlayerID()
    let planetID = strategicPlanetID(70)
    var ruleSet = RuleSet.fastSkirmish
    ruleSet.buildingRules[.metalMine]?.productionPerHour = ResourceBundle(metal: .nan, crystal: .infinity, deuterium: -500)
    ruleSet.shipRules[.smallCargo]?.baseCost = ResourceBundle(metal: .infinity, crystal: -200, deuterium: .nan)
    ruleSet.shipRules[.smallCargo]?.cargoCapacity = .infinity
    ruleSet.defenseRules[.rocketLauncher]?.baseCost = ResourceBundle(metal: .nan, crystal: -50, deuterium: .infinity)
    ruleSet.defenseRules[.rocketLauncher]?.attack = .nan

    var universe = Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000570")!),
        name: "Invalid Strategic Values",
        seed: 570,
        gameTime: 0,
        playerFactionID: playerID,
        factions: [
            Faction(
                id: playerID,
                name: "Invalid Player",
                kind: .player,
                strategy: .balanced,
                technology: ResearchState(levels: [.energy: Int.max, .computer: -3]),
                ownedPlanetIDs: [planetID]
            )
        ],
        planets: [
            Planet(
                id: planetID,
                name: "Invalid World",
                coordinate: Coordinate(galaxy: 1, system: 70, position: 4),
                ownerID: playerID,
                resources: ResourceBundle(metal: .nan, crystal: .infinity, deuterium: -1_000),
                buildingLevels: [.metalMine: Int.max, .crystalMine: -4],
                shipInventory: [.smallCargo: Int.max],
                defenseInventory: [.rocketLauncher: Int.max]
            )
        ],
        fleets: [
            Fleet(
                id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-000000000571")!),
                ownerID: playerID,
                mission: .transport,
                origin: Coordinate(galaxy: 1, system: 70, position: 4),
                target: Coordinate(galaxy: 1, system: 71, position: 4),
                ships: [.smallCargo: Int.max],
                launchTime: 0,
                arrivalTime: 10,
                returnTime: 20
            )
        ],
        events: [],
        ruleSet: ruleSet
    )

    StrategicEngine.updateStrategicState(in: &universe)
    guard let score = universe.rankings.first else {
        fatalError("Invalid strategic universe should still produce a ranking")
    }

    let scoreValues = [
        score.economyScore,
        score.fleetScore,
        score.researchScore,
        score.planetScore,
        score.defenseScore,
        score.victoryProgress,
        score.totalScore
    ]
    require(scoreValues.allSatisfy { $0.isFinite && $0 >= 0 }, "Strategic scores should clamp invalid values to finite nonnegative totals")
    require(
        universe.victoryState.progress.allSatisfy {
            $0.currentValue.isFinite &&
                $0.targetValue.isFinite &&
                $0.progress.isFinite &&
                $0.currentValue >= 0 &&
                $0.targetValue >= 0 &&
                $0.progress >= 0
        },
        "Victory progress should not contain invalid numbers"
    )
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
    storage: ResourceStorage = ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
    buildingLevels: [BuildingKind: Int] = [:],
    productionSettings: [BuildingKind: Double] = [:],
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
                storage: storage,
                buildingLevels: buildingLevels,
                productionSettings: productionSettings,
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

func fleetEnemyID() -> FactionID {
    FactionID(UUID(uuidString: "00000000-0000-0000-0000-000000000302")!)
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
                technology: ResearchState(levels: [.computer: 3]),
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

func makeCombatUniverse(seed: UInt64 = 77) -> Universe {
    let attackerID = fleetPlayerID()
    let defenderID = fleetEnemyID()
    let originID = fleetPlanetID(1)
    let targetID = fleetPlanetID(2)

    return Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-000000000333")!),
        name: "Combat Test",
        seed: seed,
        gameTime: 10,
        playerFactionID: attackerID,
        factions: [
            Faction(
                id: attackerID,
                name: "Attacker",
                kind: .player,
                strategy: .raider,
                technology: ResearchState(levels: [.weapons: 2, .shielding: 1, .armor: 1]),
                ownedPlanetIDs: [originID]
            ),
            Faction(
                id: defenderID,
                name: "Defender",
                kind: .ai,
                strategy: .miner,
                technology: ResearchState(levels: [.weapons: 1, .shielding: 1, .armor: 2]),
                ownedPlanetIDs: [targetID]
            )
        ],
        planets: [
            Planet(
                id: originID,
                name: "Sword",
                coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
                ownerID: attackerID,
                resources: ResourceBundle(metal: 25_000, crystal: 12_000, deuterium: 8_000),
                storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
                shipInventory: [.lightFighter: 8, .smallCargo: 2, .espionageProbe: 1]
            ),
            Planet(
                id: targetID,
                name: "Shield",
                coordinate: Coordinate(galaxy: 1, system: 2, position: 6),
                ownerID: defenderID,
                resources: ResourceBundle(metal: 8_000, crystal: 4_000, deuterium: 1_000),
                storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
                shipInventory: [.lightFighter: 2],
                defenseInventory: [.rocketLauncher: 3],
                debrisField: ResourceBundle(metal: 200, crystal: 50)
            )
        ],
        fleets: [],
        events: [],
        ruleSet: .fastSkirmish
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
    researchQueue: [ResearchQueueItem] = [],
    relations: [FactionRelation] = []
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
        researchQueue: researchQueue,
        relations: relations
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
    buildQueue: [BuildQueueItem] = [],
    shipBuildQueue: [UnitBuildQueueItem] = [],
    defenseBuildQueue: [UnitBuildQueueItem] = [],
    shipInventory: [ShipKind: Int] = [:],
    defenseInventory: [DefenseKind: Int] = [:],
    debrisField: ResourceBundle = .zero
) -> Planet {
    Planet(
        id: index == 0 ? aiTestPlanetID(0) : aiTestPlanetID(index),
        name: index == 0 ? "Player World" : "AI World \(index)",
        coordinate: Coordinate(galaxy: 1, system: 10 + index, position: 4),
        ownerID: ownerID,
        resources: resources,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: buildingLevels,
        buildQueue: buildQueue,
        shipBuildQueue: shipBuildQueue,
        defenseBuildQueue: defenseBuildQueue,
        shipInventory: shipInventory,
        defenseInventory: defenseInventory,
        debrisField: debrisField
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

func testFastSkirmishLateGameRulesIncludeExpandedShipsAndInterceptors() {
    let rules = RuleSet.fastSkirmish

    for ship in [ShipKind.bomber, .destroyer, .deathstar, .battlecruiser, .solarSatellite] {
        guard let rule = rules.shipRules[ship] else {
            fatalError("Fast skirmish should define \(ship.rawValue)")
        }

        require(resourceTotal(rule.baseCost) > 0, "\(ship.rawValue) should have a positive cost")
        require(rule.requirements.isEmpty == false, "\(ship.rawValue) should expose visible requirements")
    }

    require(
        rules.missileRules[.antiBallisticMissile] != nil,
        "Fast skirmish should define anti-ballistic missiles"
    )
}

func testFastSkirmishMoonFacilityRulesExposeLateGameRequirements() {
    let rules = RuleSet.fastSkirmish

    for building in [BuildingKind.missileSilo, .lunarBase, .sensorPhalanx, .jumpGate] {
        guard let rule = rules.buildingRules[building] else {
            fatalError("Fast skirmish should define \(building.rawValue)")
        }

        require(resourceTotal(rule.baseCost) > 0, "\(building.rawValue) should have a positive cost")
        require(rule.requirements.isEmpty == false, "\(building.rawValue) should expose late-game requirements")
    }
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

func testSlowerFleetTakesLongerAndUsesLessFuel() {
    let origin = Coordinate(galaxy: 1, system: 1, position: 4)
    let target = Coordinate(galaxy: 1, system: 2, position: 4)
    let ships: [ShipKind: Int] = [.smallCargo: 1]

    let fullDuration = FleetEngine.travelDuration(from: origin, to: target, ships: ships, ruleSet: .fastSkirmish, speedPercent: 1)
    let halfDuration = FleetEngine.travelDuration(from: origin, to: target, ships: ships, ruleSet: .fastSkirmish, speedPercent: 0.5)
    let fullFuel = FleetEngine.fuelCost(from: origin, to: target, ships: ships, ruleSet: .fastSkirmish, speedPercent: 1)
    let halfFuel = FleetEngine.fuelCost(from: origin, to: target, ships: ships, ruleSet: .fastSkirmish, speedPercent: 0.5)

    require(halfDuration > fullDuration, "Half speed should take longer")
    require(halfFuel < fullFuel, "Half speed should spend less fuel")
}

func testBattleSimulationProducesAtMostSixRounds() {
    let input = BattleSimulationInput(
        attackerShips: [.lightFighter: 24, .smallCargo: 2],
        defenderShips: [.lightFighter: 8],
        defenderDefenses: [.rocketLauncher: 18, .lightLaser: 4],
        attackerResearch: ResearchState(levels: [.weapons: 2, .shielding: 1, .armor: 1]),
        defenderResearch: ResearchState(levels: [.weapons: 1, .shielding: 1, .armor: 1]),
        ruleSet: .fastSkirmish,
        seed: 404
    )

    let result = BattleSimulationEngine.resolve(input)

    require(result.rounds.count >= 1, "Battle should produce at least one round")
    require(result.rounds.count <= 6, "Battle should stop after six rounds")
    requireEqual(result.rounds.map(\.round), Array(1...result.rounds.count), "Battle rounds should be sequential")
    require(result.rounds.contains { $0.attackerLosses.isEmpty == false || $0.defenderShipLosses.isEmpty == false || $0.defenderDefenseLosses.isEmpty == false }, "Battle rounds should record losses")
}

func testBattleSimulationRecordsRapidFireShieldHullAndExplosions() {
    let input = BattleSimulationInput(
        attackerShips: [.cruiser: 8],
        defenderShips: [.lightFighter: 48],
        defenderDefenses: [:],
        attackerResearch: ResearchState(levels: [.weapons: 3, .shielding: 2, .armor: 2]),
        defenderResearch: ResearchState(levels: [.weapons: 1, .shielding: 1, .armor: 1]),
        ruleSet: .fastSkirmish,
        seed: 9_901
    )

    let result = BattleSimulationEngine.resolve(input)

    require(result.rounds.count >= 1 && result.rounds.count <= 6, "Battle V2 should still stay inside the OGame-style six-round cap")
    require(result.rounds.contains { $0.rapidFireShots > 0 }, "Cruisers should trigger rapid fire against light fighters")
    require(result.rounds.contains { $0.shieldDamage > 0 && $0.hullDamage > 0 }, "Battle report rounds should expose shield and hull damage")
    require(result.rounds.contains { $0.explodedUnits > 0 }, "Damaged units should be able to explode after hull integrity drops")
    require(result.rounds.contains { ($0.defenderShipLosses[.lightFighter] ?? 0) > 0 }, "Rapid fire battle should destroy some light fighters")
}

func testFleetLaunchRespectsComputerFleetSlots() {
    var universe = makeFleetUniverse(originShips: [.smallCargo: 3])
    universe.factions[0].technology = ResearchState()

    let first = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .transport,
        ships: [.smallCargo: 1]
    )
    let second = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .transport,
        ships: [.smallCargo: 1]
    )

    guard case .launched = first else {
        fatalError("First fleet should launch")
    }
    requireEqual(second, .failure(.fleetSlotLimit), "Second fleet should fail at computer level 0")
}

func testOutboundFleetCanBeRecalled() {
    var universe = makeFleetUniverse(originShips: [.smallCargo: 1])
    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .transport,
        ships: [.smallCargo: 1]
    )
    guard case .launched(let fleet) = launch else {
        fatalError("Fleet should launch")
    }
    universe.gameTime = fleet.launchTime + 10

    let recalled = FleetEngine.recallFleet(fleet.id, ownerID: universe.playerFactionID, in: &universe)

    requireEqual(recalled, true, "Recall should succeed")
    requireEqual(universe.fleets[0].phase, .returning, "Recalled fleet should return")
    require(universe.fleets[0].returnTime < fleet.returnTime, "Recall should shorten return time")
}

func testSensorPhalanxHidesRecalledAndMoonOriginFleets() {
    let playerID = fleetPlayerID()
    let rivalID = fleetEnemyID()
    let moonPlanetID = fleetPlanetID(1)
    let targetPlanetID = fleetPlanetID(2)
    let raidTargetID = fleetPlanetID(3)
    let visibleFleetID = FleetID(UUID(uuidString: "00000000-0000-0000-0000-00000000f101")!)
    let recalledFleetID = FleetID(UUID(uuidString: "00000000-0000-0000-0000-00000000f102")!)
    let moonOriginFleetID = FleetID(UUID(uuidString: "00000000-0000-0000-0000-00000000f103")!)
    let scanMoon = Moon(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000f201")!,
        name: "Scanner",
        createdAt: 0,
        buildingLevels: [.sensorPhalanx: 3]
    )
    let targetMoon = Moon(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000f202")!,
        name: "Hidden Yard",
        createdAt: 0,
        buildingLevels: [.lunarBase: 1]
    )
    let visibleFleet = Fleet(
        id: visibleFleetID,
        ownerID: rivalID,
        mission: .attack,
        origin: Coordinate(galaxy: 1, system: 2, position: 6),
        target: Coordinate(galaxy: 1, system: 3, position: 6),
        ships: [.lightFighter: 1],
        launchTime: 10,
        arrivalTime: 120,
        returnTime: 240,
        originPlanetID: targetPlanetID,
        targetPlanetID: raidTargetID
    )
    let recalledFleet = Fleet(
        id: recalledFleetID,
        ownerID: rivalID,
        mission: .attack,
        origin: Coordinate(galaxy: 1, system: 2, position: 6),
        target: Coordinate(galaxy: 1, system: 3, position: 6),
        ships: [.lightFighter: 1],
        launchTime: 10,
        arrivalTime: 120,
        returnTime: 80,
        phase: .returning,
        originPlanetID: targetPlanetID,
        targetPlanetID: raidTargetID,
        recalledAt: 40
    )
    let moonOriginFleet = Fleet(
        id: moonOriginFleetID,
        ownerID: rivalID,
        mission: .transport,
        origin: Coordinate(galaxy: 1, system: 2, position: 6),
        target: Coordinate(galaxy: 1, system: 3, position: 6),
        ships: [.smallCargo: 1],
        launchTime: 20,
        arrivalTime: 150,
        returnTime: 280,
        originPlanetID: targetPlanetID,
        targetPlanetID: raidTargetID,
        originSite: .moon
    )
    let universe = Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-00000000f300")!),
        name: "Phalanx Test",
        seed: 91,
        gameTime: 50,
        playerFactionID: playerID,
        factions: [
            Faction(id: playerID, name: "Player", kind: .player, strategy: .balanced, ownedPlanetIDs: [moonPlanetID]),
            Faction(id: rivalID, name: "Rival", kind: .ai, strategy: .raider, ownedPlanetIDs: [targetPlanetID, raidTargetID])
        ],
        planets: [
            Planet(id: moonPlanetID, name: "Moon Base", coordinate: Coordinate(galaxy: 1, system: 1, position: 4), ownerID: playerID, moon: scanMoon),
            Planet(id: targetPlanetID, name: "Target", coordinate: Coordinate(galaxy: 1, system: 2, position: 6), ownerID: rivalID, moon: targetMoon),
            Planet(id: raidTargetID, name: "Raid Target", coordinate: Coordinate(galaxy: 1, system: 3, position: 6), ownerID: rivalID)
        ],
        fleets: [visibleFleet, recalledFleet, moonOriginFleet],
        events: [],
        ruleSet: .fastSkirmish
    )

    let scans = MoonEngine.sensorScan(from: moonPlanetID, targetPlanetID: targetPlanetID, ownerID: playerID, in: universe)

    require(scans.contains { $0.id == visibleFleetID }, "Phalanx should still show normal planet-origin movement")
    require(!scans.contains { $0.id == recalledFleetID }, "Phalanx should hide recalled fleets")
    require(!scans.contains { $0.id == moonOriginFleetID }, "Phalanx should hide fleets launched from a moon")
}

func testJointAttackCombinesSameOwnerFleetsArrivingTogether() {
    var universe = makeCombatUniverse()
    let secondOriginID = fleetPlanetID(3)
    universe.factions[0].ownedPlanetIDs.append(secondOriginID)
    universe.planets.append(
        Planet(
            id: secondOriginID,
            name: "Second Sword",
            coordinate: Coordinate(galaxy: 1, system: 1, position: 5),
            ownerID: fleetPlayerID(),
            resources: ResourceBundle(metal: 25_000, crystal: 12_000, deuterium: 8_000),
            storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000)
        )
    )
    universe.planets[1].shipInventory = [.lightFighter: 16]
    universe.planets[1].defenseInventory = [.rocketLauncher: 16, .lightLaser: 6]
    let arrival: TimeInterval = 180
    let firstFleet = Fleet(
        id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-00000000a101")!),
        ownerID: fleetPlayerID(),
        mission: .attack,
        origin: universe.planets[0].coordinate,
        target: universe.planets[1].coordinate,
        ships: [.cruiser: 4, .smallCargo: 1],
        launchTime: 10,
        arrivalTime: arrival,
        returnTime: 350,
        originPlanetID: fleetPlanetID(1),
        targetPlanetID: fleetPlanetID(2)
    )
    let secondFleet = Fleet(
        id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-00000000a102")!),
        ownerID: fleetPlayerID(),
        mission: .attack,
        origin: universe.planets[2].coordinate,
        target: universe.planets[1].coordinate,
        ships: [.cruiser: 4, .smallCargo: 1],
        launchTime: 10,
        arrivalTime: arrival,
        returnTime: 350,
        originPlanetID: secondOriginID,
        targetPlanetID: fleetPlanetID(2)
    )
    universe.fleets = [firstFleet, secondFleet]
    universe.gameTime = arrival

    FleetEngine.resolveDueFleets(in: &universe)

    let battleReports = universe.reports.filter { $0.kind == .battle }
    requireEqual(battleReports.count, 1, "Joint attack should resolve as one combined battle report")
    requireEqual(battleReports[0].participants[0].beforeShips[.cruiser], 8, "Joint attack report should combine attacker ships")
    require(universe.events.contains { $0.title == "Joint Combat Resolved" }, "Joint attack should record a joint combat event")
    require(universe.fleets.allSatisfy { $0.phase == .returning }, "Surviving joint attack groups should return to their own origins")
    require(Set(universe.fleets.compactMap(\.originPlanetID)).isSubset(of: [fleetPlanetID(1), secondOriginID]), "Joint attack survivors should preserve original origins")
}

func testSensorPhalanxExposesChaseWindowAndDebrisFleetSaveRisk() {
    let playerID = fleetPlayerID()
    let rivalID = fleetEnemyID()
    let moonPlanetID = fleetPlanetID(1)
    let targetPlanetID = fleetPlanetID(2)
    let scanMoon = Moon(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000f401")!,
        name: "Scanner",
        createdAt: 0,
        buildingLevels: [.sensorPhalanx: 3]
    )
    let recycleFleet = Fleet(
        id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-00000000f402")!),
        ownerID: rivalID,
        mission: .recycle,
        origin: Coordinate(galaxy: 1, system: 2, position: 6),
        target: Coordinate(galaxy: 1, system: 3, position: 6),
        ships: [.recycler: 2],
        launchTime: 20,
        arrivalTime: 180,
        returnTime: 340,
        originPlanetID: targetPlanetID,
        targetPlanetID: targetPlanetID
    )
    let universe = Universe(
        id: UniverseID(UUID(uuidString: "00000000-0000-0000-0000-00000000f400")!),
        name: "Trace Test",
        seed: 92,
        gameTime: 100,
        playerFactionID: playerID,
        factions: [
            Faction(id: playerID, name: "Player", kind: .player, strategy: .balanced, ownedPlanetIDs: [moonPlanetID]),
            Faction(id: rivalID, name: "Rival", kind: .ai, strategy: .raider, ownedPlanetIDs: [targetPlanetID])
        ],
        planets: [
            Planet(id: moonPlanetID, name: "Moon Base", coordinate: Coordinate(galaxy: 1, system: 1, position: 4), ownerID: playerID, moon: scanMoon),
            Planet(id: targetPlanetID, name: "Target", coordinate: Coordinate(galaxy: 1, system: 2, position: 6), ownerID: rivalID, debrisField: ResourceBundle(metal: 4_000, crystal: 1_500))
        ],
        fleets: [recycleFleet],
        events: [],
        ruleSet: .fastSkirmish
    )

    let traces = MoonEngine.sensorTrace(from: moonPlanetID, targetPlanetID: targetPlanetID, ownerID: playerID, in: universe)

    requireEqual(traces.count, 1, "Phalanx trace should include the visible recycle fleet")
    requireEqual(traces[0].fleet.id, recycleFleet.id, "Trace should keep the scanned fleet")
    requireEqual(traces[0].interceptTime, recycleFleet.arrivalTime, "Outbound visible fleets should expose an arrival chase window")
    requireEqual(traces[0].risk, .debrisFleetSave, "Recycle flights toward debris should be marked as debris FS risk")
    require(traces[0].tacticalNote.contains("废墟"), "Trace should explain the debris fleet-save risk")
}

func testDefendMissionHoldsAtFriendlyPlanetAndJoinsDefense() {
    var universe = makeCombatUniverse()
    let defenderColonyID = fleetPlanetID(3)
    universe.factions[0].ownedPlanetIDs.append(defenderColonyID)
    universe.planets.append(
        Planet(
            id: defenderColonyID,
            name: "Forward Shield",
            coordinate: Coordinate(galaxy: 1, system: 1, position: 5),
            ownerID: fleetPlayerID(),
            resources: ResourceBundle(metal: 20_000, crystal: 12_000, deuterium: 8_000),
            storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
            shipInventory: [.cruiser: 4]
        )
    )
    universe.planets[0].shipInventory[.cruiser] = 6
    universe.planets[1].ownerID = fleetPlayerID()
    universe.planets[1].shipInventory = [:]
    universe.planets[1].defenseInventory = [.rocketLauncher: 4]
    let defendLaunch = FleetEngine.launchFleet(
        from: defenderColonyID,
        to: fleetPlanetID(2),
        in: &universe,
        mission: .defend,
        ships: [.cruiser: 4],
        holdDuration: 600
    )
    guard case .launched(let defendFleet) = defendLaunch else {
        fatalError("Defend fleet should launch to a friendly planet")
    }
    universe.gameTime = defendFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    guard let holdingFleet = universe.fleets.first(where: { $0.id == defendFleet.id }) else {
        fatalError("Defend fleet should remain active while holding")
    }
    requireEqual(holdingFleet.phase, .holding, "Defend fleet should enter a holding phase at the friendly target")
    requireEqual(holdingFleet.targetPlanetID, fleetPlanetID(2), "Defend fleet should hold at the protected planet")

    let attackerFleet = Fleet(
        id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-00000000d101")!),
        ownerID: fleetEnemyID(),
        mission: .attack,
        origin: universe.planets[1].coordinate,
        target: universe.planets[1].coordinate,
        ships: [.lightFighter: 16],
        launchTime: universe.gameTime,
        arrivalTime: universe.gameTime + 30,
        returnTime: universe.gameTime + 60,
        originPlanetID: fleetPlanetID(2),
        targetPlanetID: fleetPlanetID(2)
    )
    universe.fleets.append(attackerFleet)
    universe.gameTime = attackerFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    guard let report = universe.reports.last(where: { $0.kind == .battle }) else {
        fatalError("Attack against defended planet should create a battle report")
    }
    requireEqual(report.participants[1].beforeShips[.cruiser], 4, "Holding defend fleet should join the defender side")
    require(universe.fleets.contains { $0.id == defendFleet.id && $0.phase == .holding }, "Surviving defenders should continue holding after the battle")
    requireEqual(requirePlanet(fleetPlanetID(2), in: universe, "Protected planet should remain").shipInventory[.cruiser] ?? 0, 0, "Defending fleet ships should not become permanent planet inventory")
}

func testACSGatheringCanDelayAttackFleetsIntoJointWindow() {
    var universe = makeCombatUniverse()
    universe.planets[0].shipInventory = [.cruiser: 8, .smallCargo: 2]
    universe.planets[1].shipInventory = [.lightFighter: 12]
    universe.planets[1].defenseInventory = [.rocketLauncher: 10]
    let firstFleet = Fleet(
        id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-00000000a201")!),
        ownerID: fleetPlayerID(),
        mission: .attack,
        origin: universe.planets[0].coordinate,
        target: universe.planets[1].coordinate,
        ships: [.cruiser: 4, .smallCargo: 1],
        launchTime: 10,
        arrivalTime: 180,
        returnTime: 340,
        originPlanetID: fleetPlanetID(1),
        targetPlanetID: fleetPlanetID(2)
    )
    let secondFleet = Fleet(
        id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-00000000a202")!),
        ownerID: fleetPlayerID(),
        mission: .attack,
        origin: universe.planets[0].coordinate,
        target: universe.planets[1].coordinate,
        ships: [.cruiser: 4, .smallCargo: 1],
        launchTime: 10,
        arrivalTime: 220,
        returnTime: 380,
        originPlanetID: fleetPlanetID(1),
        targetPlanetID: fleetPlanetID(2)
    )
    universe.fleets = [firstFleet, secondFleet]

    let adjusted = FleetEngine.setJointAttackGatherTime(
        [firstFleet.id, secondFleet.id],
        ownerID: fleetPlayerID(),
        gatherUntil: 220,
        in: &universe
    )

    requireEqual(adjusted, true, "ACS gathering should accept compatible attack fleets")
    requireEqual(universe.fleets.map(\.arrivalTime), [220, 220], "ACS gathering should align selected fleets to the shared window")
    requireEqual(universe.fleets[0].returnTime, 380, "ACS gathering should extend earlier fleet return time by the same delay")
    requireEqual(universe.events.last?.title, "ACS Gathering Adjusted", "ACS gathering should record a tactical event")

    universe.gameTime = 220
    FleetEngine.resolveDueFleets(in: &universe)

    requireEqual(universe.reports.filter { $0.kind == .battle }.count, 1, "Gathered ACS fleets should resolve as one joint attack")
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

func testExplorationEventPoolIncludesOGameStyleFindsRisksAndTimingEvents() {
    let kinds = Set(ExplorationOutcomeKind.allCases)

    for expected in [
        ExplorationOutcomeKind.resourceCache,
        .debrisField,
        .derelictShips,
        .largeDerelictFleet,
        .darkMatter,
        .pirateAmbush,
        .alienEncounter,
        .earlyReturn,
        .delayedReturn,
        .blackHole,
        .emptySignal
    ] {
        require(kinds.contains(expected), "Exploration event pool should include \(expected.rawValue)")
    }

    let delay = ExplorationOutcome(kind: .delayedReturn, timeShift: 300, messageKey: "delay")
    let early = ExplorationOutcome(kind: .earlyReturn, timeShift: -120, messageKey: "early")
    require(delay.timeShift > 0, "Delayed expedition events should be able to extend return timing")
    require(early.timeShift < 0, "Early expedition events should be able to shorten return timing")
}

func testExploreMissionAdvancesStrategicExplorationVictoryThroughSimulationTick() {
    var universe = makeFleetUniverse()
    let targetID = fleetPlanetID(2)

    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: targetID,
        in: &universe,
        mission: .explore,
        ships: [.espionageProbe: 1],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Exploration fleet should launch through the real fleet path")
    }

    SimulationEngine.tick(universe: &universe, delta: launchedFleet.arrivalTime - universe.gameTime)

    let explorationProgress = requireVictoryProgress(
        universe.victoryState,
        factionID: fleetPlayerID(),
        route: .exploration
    )
    requireEqual(
        universe.victoryState.exploredPlanetIDs,
        [targetID],
        "Exploration arrival should record the explored target planet"
    )
    requireEqual(explorationProgress.currentValue, 1, "Strategic exploration progress should include real explored targets")
    requireEqual(universe.victoryState.winningRoute, .exploration, "Exploring the only neutral target should trigger exploration victory")
    requireEqual(universe.events.filter { $0.kind == .victory }.count, 1, "Exploration victory should announce once through simulation tick")
}

func testExplorationMissionRecordsBoundedDiscoveriesAndFeedsProgress() {
    var universe = makeFleetUniverse(
        targetResources: ResourceBundle(metal: 900, crystal: 300, deuterium: 75),
        targetDebris: ResourceBundle(metal: 120, crystal: 40)
    )
    let targetID = fleetPlanetID(2)
    universe.victoryState.exploredPlanetIDs = [targetID, targetID]

    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: targetID,
        in: &universe,
        mission: .explore,
        ships: [.espionageProbe: 1],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Exploration fleet should launch for discovery recording")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)
    StrategicEngine.updateStrategicState(in: &universe)

    requireEqual(universe.explorationRecords.count, 1, "Exploration should keep one record per faction and target")
    let record = universe.explorationRecords[0]
    requireEqual(record.factionID, fleetPlayerID(), "Exploration record should identify the exploring faction")
    requireEqual(record.targetPlanetID, targetID, "Exploration record should identify the explored planet")
    requireEqual(record.exploredAt, launchedFleet.arrivalTime, "Exploration record should preserve arrival time")
    require(record.reward != .zero, "Exploration record should summarize the resource reward")
    requireEqual(record.reward, universe.fleets[0].cargo, "Exploration record reward should match returning cargo")
    requireEqual(record.discoveredResources, ResourceBundle(metal: 900, crystal: 300, deuterium: 75), "Exploration should discover visible target resources")
    requireEqual(record.discoveredDebris, ResourceBundle(metal: 120, crystal: 40), "Exploration should discover target debris")
    requireEqual(record.discoveredOwnerID, nil, "Neutral exploration should not invent an owner")
    requireEqual(record.discoveredNeutral, true, "Exploration should mark neutral targets")
    requireEqual(universe.victoryState.exploredPlanetIDs, [targetID], "Strategic state should dedupe explored target IDs")
    requireEqual(
        requireVictoryProgress(universe.victoryState, factionID: fleetPlayerID(), route: .exploration).currentValue,
        1,
        "Exploration records should feed exploration progress"
    )
}

func testExploreMissionCreatesExplorationReport() {
    var universe = makeFleetUniverse(
        targetResources: ResourceBundle(metal: 900, crystal: 300, deuterium: 75),
        targetDebris: ResourceBundle(metal: 120, crystal: 40)
    )
    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .explore,
        ships: [.espionageProbe: 1],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Exploration fleet should launch for report creation")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    guard let report = universe.reports.last else {
        fatalError("Exploration should create a report")
    }

    requireEqual(report.kind, .exploration, "Exploration should create an exploration report")
    requireEqual(report.time, launchedFleet.arrivalTime, "Exploration report should use arrival time")
    require(report.title.contains("[1:2:6]"), "Exploration report title should identify the target coordinate")
    require(report.summary.contains("reward"), "Exploration report should summarize the reward")
    require(report.summary.contains("neutral"), "Exploration report should summarize neutral status")
    requireEqual(report.participants.count, 1, "Exploration report should include the explorer")
    requireEqual(report.participants[0].role, .observer, "Exploration report participant should be an observer")
    requireEqual(report.participants[0].factionID, fleetPlayerID(), "Exploration report should expose the exploring faction")
    requireEqual(report.participants[0].planetID, fleetPlanetID(2), "Exploration report should expose the explored target")
    requireEqual(report.loot, universe.fleets[0].cargo, "Exploration report loot should match returning reward cargo")
    requireEqual(report.debris, ResourceBundle(metal: 120, crystal: 40), "Exploration report should include discovered debris")
}

func testEspionageMissionCreatesStableReportWithoutChangingTargetState() throws {
    var first = makeCombatUniverse()
    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &first,
        mission: .espionage,
        ships: [.espionageProbe: 1],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Espionage probe should launch")
    }

    let targetBefore = requirePlanet(fleetPlanetID(2), in: first, "Espionage target should exist before arrival")
    let defenderBefore = requireFaction(fleetEnemyID(), in: first, "Espionage defender should exist before arrival")
    let encoded = try JSONEncoder().encode(first)
    var second = try JSONDecoder().decode(Universe.self, from: encoded)

    first.gameTime = launchedFleet.arrivalTime
    second.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &first)
    FleetEngine.resolveDueFleets(in: &second)

    let targetAfter = requirePlanet(fleetPlanetID(2), in: first, "Espionage target should exist after arrival")
    let defenderAfter = requireFaction(fleetEnemyID(), in: first, "Espionage defender should exist after arrival")
    requireEqual(first, second, "Espionage result should be deterministic across save/load equality")
    requireEqual(targetAfter.resources, targetBefore.resources, "Espionage should not steal target resources")
    requireEqual(targetAfter.shipInventory, targetBefore.shipInventory, "Espionage should not mutate target ships")
    requireEqual(targetAfter.defenseInventory, targetBefore.defenseInventory, "Espionage should not mutate target defenses")
    requireEqual(defenderAfter, defenderBefore, "Espionage should not mutate defender faction state")
    requireEqual(first.reports.count, 1, "Espionage should create one report")
    requireEqual(first.reports[0].kind, .espionage, "Espionage report should use intelligence kind")
    requireEqual(first.reports[0].participants.map(\.role), [.attacker, .defender], "Espionage report should identify both sides")
    requireEqual(first.events.last?.kind, .intelligence, "Espionage should record an intelligence event")
    requireEqual(first.fleets.first?.phase, .returning, "Espionage probe should deterministically return")
    requireEqual(first.fleets.first?.ships[.espionageProbe], 1, "Returning espionage fleet should preserve the probe")
}

func testTransportAndExplorationDoNotShiftFactionRelations() {
    var transportUniverse = makeCombatUniverse()
    let transport = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &transportUniverse,
        mission: .transport,
        ships: [.smallCargo: 1],
        cargo: ResourceBundle(metal: 100)
    )
    guard case .launched(let transportFleet) = transport else {
        fatalError("Transport fleet should launch toward rival planet")
    }
    transportUniverse.gameTime = transportFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &transportUniverse)
    requireEqual(transportUniverse.factions.flatMap(\.relations), [], "Transport should not create relation memory")

    var explorationUniverse = makeCombatUniverse()
    let exploration = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &explorationUniverse,
        mission: .explore,
        ships: [.espionageProbe: 1],
        cargo: .zero
    )
    guard case .launched(let explorationFleet) = exploration else {
        fatalError("Exploration fleet should launch toward rival planet")
    }
    explorationUniverse.gameTime = explorationFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &explorationUniverse)
    requireEqual(explorationUniverse.factions.flatMap(\.relations), [], "Exploration should not create hostility memory")
}

func testAttackShiftsFactionRelationsWithoutHiddenTargetDetails() {
    var universe = makeCombatUniverse()
    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .attack,
        ships: [.lightFighter: 8, .smallCargo: 2],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Attack fleet should launch for relation update")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    let attackerView = requireRelation(from: fleetPlayerID(), toward: fleetEnemyID(), in: universe, "Attacker should remember pressure on defender")
    let defenderView = requireRelation(from: fleetEnemyID(), toward: fleetPlayerID(), in: universe, "Defender should remember hostile attacker")
    requireEqual(attackerView.posture, .pressured, "Attacker relation should record applied pressure")
    requireEqual(defenderView.posture, .hostile, "Defender relation should move toward hostile after attack")
    requireEqual(attackerView.threatScore, 1, "Attacker pressure score should increment once")
    requireEqual(defenderView.threatScore, 1, "Defender threat score should increment once")
    requireEqual(attackerView.attackCount, 1, "Attacker relation should summarize attack count")
    requireEqual(defenderView.attackCount, 1, "Defender relation should summarize attack count")
    requireEqual(attackerView.lastInteractionTime, launchedFleet.arrivalTime, "Attacker relation should expose interaction time")
    requireEqual(defenderView.lastInteractionTime, launchedFleet.arrivalTime, "Defender relation should expose interaction time")
    require(!attackerView.summary.contains(fleetPlanetID(2).rawValue.uuidString), "Relation summaries should not expose target planet details")
    require(!defenderView.summary.contains(fleetPlanetID(2).rawValue.uuidString), "Threat summaries should not expose target planet details")
}

func testRepeatedAttacksIncrementThreatWithoutDuplicateRelations() {
    var universe = makeCombatUniverse()

    for _ in 0..<2 {
        universe.fleets = []
        universe.planets[0].shipInventory[.lightFighter] = 8
        universe.planets[0].shipInventory[.smallCargo] = 2
        let launch = FleetEngine.launchFleet(
            from: fleetPlanetID(1),
            to: fleetPlanetID(2),
            in: &universe,
            mission: .attack,
            ships: [.lightFighter: 8, .smallCargo: 2],
            cargo: .zero
        )
        guard case .launched(let launchedFleet) = launch else {
            fatalError("Repeated attack fleet should launch")
        }
        universe.gameTime = launchedFleet.arrivalTime
        FleetEngine.resolveDueFleets(in: &universe)
    }

    let attackerRelations = requireFaction(fleetPlayerID(), in: universe, "Attacker should remain").relations
    let defenderRelations = requireFaction(fleetEnemyID(), in: universe, "Defender should remain").relations
    requireEqual(attackerRelations.filter { $0.factionID == fleetEnemyID() }.count, 1, "Repeated attacks should not duplicate attacker relation rows")
    requireEqual(defenderRelations.filter { $0.factionID == fleetPlayerID() }.count, 1, "Repeated attacks should not duplicate defender relation rows")
    requireEqual(attackerRelations[0].threatScore, 2, "Repeated attacks should increment attacker pressure score")
    requireEqual(defenderRelations[0].threatScore, 2, "Repeated attacks should increment defender threat score")
    requireEqual(attackerRelations[0].attackCount, 2, "Repeated attacks should increment attacker attack summary")
    requireEqual(defenderRelations[0].attackCount, 2, "Repeated attacks should increment defender attack summary")
}

func testFactionRelationsNormalizeDuplicatesOnDecodeAndAttackUpdate() throws {
    let factionJSON = """
    {
      "id": { "rawValue": "00000000-0000-0000-0000-000000000301" },
      "name": "Duplicate Relations",
      "kind": "player",
      "strategy": "balanced",
      "technology": { "levels": {} },
      "ownedPlanetIDs": [],
      "relations": [
        {
          "factionID": { "rawValue": "00000000-0000-0000-0000-000000000302" },
          "posture": "wary",
          "threatScore": 2,
          "lastInteractionTime": 50,
          "attackCount": 1
        },
        {
          "factionID": { "rawValue": "00000000-0000-0000-0000-000000000302" },
          "posture": "neutral",
          "threatScore": 4,
          "lastInteractionTime": 40,
          "attackCount": 3
        },
        {
          "factionID": { "rawValue": "00000000-0000-0000-0000-000000000333" },
          "posture": "hostile",
          "threatScore": 5000,
          "lastInteractionTime": 60,
          "attackCount": 5000
        }
      ]
    }
    """
    let decoded = try JSONDecoder().decode(Faction.self, from: Data(factionJSON.utf8))

    requireEqual(decoded.relations.count, 2, "Decoded faction relations should merge duplicate rows")
    requireEqual(decoded.relations[0].factionID, fleetEnemyID(), "Merged relation rows should sort deterministically by faction ID")
    requireEqual(decoded.relations[0].posture, .hostile, "Merged relation posture should be derived from threat")
    requireEqual(decoded.relations[0].threatScore, 4, "Merged relation should keep the highest threat")
    requireEqual(decoded.relations[0].lastInteractionTime, 50, "Merged relation should keep latest interaction time")
    requireEqual(decoded.relations[0].attackCount, 4, "Merged relation should sum attack counts")
    requireEqual(decoded.relations[1].threatScore, 999, "Merged relation threat should be capped")
    requireEqual(decoded.relations[1].attackCount, 999, "Merged relation attack count should be capped")

    var universe = makeCombatUniverse()
    universe.factions[1].relations = [
        FactionRelation(factionID: fleetPlayerID(), posture: .wary, threatScore: 1, lastInteractionTime: 20, attackCount: 1),
        FactionRelation(factionID: fleetPlayerID(), posture: .neutral, threatScore: 2, lastInteractionTime: 25, attackCount: 2)
    ]
    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .attack,
        ships: [.lightFighter: 8, .smallCargo: 2],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Attack fleet should launch for duplicate relation update")
    }
    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    let defenderRelations = requireFaction(fleetEnemyID(), in: universe, "Defender should remain after relation update").relations
    requireEqual(defenderRelations.filter { $0.factionID == fleetPlayerID() }.count, 1, "Attack update should normalize duplicate relation rows")
    requireEqual(defenderRelations[0].posture, .hostile, "Attack update should keep defender hostile toward attacker")
    requireEqual(defenderRelations[0].threatScore, 3, "Attack update should increment merged threat once")
    requireEqual(defenderRelations[0].lastInteractionTime, launchedFleet.arrivalTime, "Attack update should keep latest interaction time")
    requireEqual(defenderRelations[0].attackCount, 4, "Attack update should increment merged attack count once")
}

func testAttackMissionCreatesCombatReportLootDebrisAndRecoveredDefense() {
    var universe = makeCombatUniverse()
    let defenderBefore = requirePlanet(fleetPlanetID(2), in: universe, "Combat target should exist before launch")
    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .attack,
        ships: [.lightFighter: 8, .smallCargo: 2],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Attack fleet should launch")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    guard let returningFleet = universe.fleets.first else {
        fatalError("Winning attack should return surviving ships")
    }
    let defenderAfter = requirePlanet(fleetPlanetID(2), in: universe, "Combat target should exist after battle")
    guard let report = universe.reports.last else {
        fatalError("Attack should create a battle report")
    }

    requireEqual(report.kind, .battle, "Attack should create a battle report")
    require(report.battleRounds.count >= 1 && report.battleRounds.count <= 6, "Battle report should include bounded combat rounds")
    requireEqual(report.participants.count, 2, "Battle report should include attacker and defender")
    requireEqual(report.participants[0].role, .attacker, "Battle report should list attacker first")
    requireEqual(report.participants[1].role, .defender, "Battle report should list defender second")
    requireEqual(report.participants[0].factionID, fleetPlayerID(), "Battle report should include attacker faction")
    requireEqual(report.participants[1].factionID, fleetEnemyID(), "Battle report should include defender faction")
    requireEqual(report.participants[0].beforeShips, [.lightFighter: 8, .smallCargo: 2], "Battle report should include attacker starting fleet")
    requireEqual(report.participants[0].afterShips, returningFleet.ships, "Battle report should include attacker surviving fleet")
    requireEqual(report.participants[1].beforeShips, defenderBefore.shipInventory, "Battle report should include defender starting ships")
    requireEqual(report.participants[1].afterShips, defenderAfter.shipInventory, "Battle report should include defender remaining ships")
    requireEqual(report.participants[1].beforeDefenses, defenderBefore.defenseInventory, "Battle report should include defender starting defenses")
    requireEqual(report.participants[1].afterDefenses, defenderAfter.defenseInventory, "Battle report should include defender recovered defenses")
    require(resourceTotal(report.participants[0].losses) > 0, "Battle report should include attacker losses")
    require(resourceTotal(report.participants[1].losses) > 0, "Battle report should include defender losses")
    requireEqual(report.losses, report.participants[0].losses.adding(report.participants[1].losses), "Battle report should include total losses")
    requireEqual(returningFleet.cargo, report.loot, "Surviving attackers should return with reported loot")
    require(resourceTotal(returningFleet.cargo) <= testCargoCapacity(returningFleet.ships, ruleSet: universe.ruleSet), "Loot should be bounded by surviving cargo")
    require(defenderAfter.resources.canAfford(.zero), "Defender resources should remain nonnegative")
    require(defenderBefore.resources.subtracting(defenderAfter.resources).nonnegative == report.loot, "Reported loot should match removed defender resources")
    require(resourceTotal(defenderAfter.debrisField) > resourceTotal(defenderBefore.debrisField), "Destroyed units should add debris to the defending planet")
    requireEqual(report.debris, defenderAfter.debrisField.subtracting(defenderBefore.debrisField).nonnegative, "Battle report should include newly created debris")
    require((defenderAfter.defenseInventory[.rocketLauncher] ?? 0) > 0, "Some destroyed defenses should recover deterministically")
    require((defenderAfter.defenseInventory[.rocketLauncher] ?? 0) < (defenderBefore.defenseInventory[.rocketLauncher] ?? 0), "Recovered defenses should still reflect combat damage")
    requireEqual(universe.events.last?.kind, .combat, "Attack should record a combat event")
}

func testCombatReviewAggregatesBattleRoundsAndInsights() {
    let report = Report(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000c0a1")!,
        time: 120,
        kind: .battle,
        title: "Battle at [1:2:6]",
        summary: "Attacker wins.",
        participants: [
            ReportParticipant(
                role: .attacker,
                factionID: fleetPlayerID(),
                planetID: fleetPlanetID(1),
                name: "Raider",
                beforeShips: [.cruiser: 3, .smallCargo: 2],
                afterShips: [.cruiser: 2, .smallCargo: 1],
                losses: ResourceBundle(metal: 22_000, crystal: 8_000)
            ),
            ReportParticipant(
                role: .defender,
                factionID: fleetEnemyID(),
                planetID: fleetPlanetID(2),
                name: "Defender",
                beforeShips: [.lightFighter: 6],
                afterShips: [:],
                beforeDefenses: [.rocketLauncher: 3],
                afterDefenses: [:],
                losses: ResourceBundle(metal: 50_000, crystal: 20_000)
            )
        ],
        loot: ResourceBundle(metal: 1_200, crystal: 800, deuterium: 200),
        debris: ResourceBundle(metal: 240_000, crystal: 60_000),
        losses: ResourceBundle(metal: 72_000, crystal: 28_000),
        battleRounds: [
            BattleRoundSummary(
                round: 1,
                attackerPower: 1_200,
                defenderPower: 800,
                defenderShipLosses: [.lightFighter: 4],
                defenderDefenseLosses: [.rocketLauncher: 1],
                attackerShots: 5,
                defenderShots: 9,
                rapidFireShots: 3,
                shieldDamage: 400,
                hullDamage: 900,
                explodedUnits: 2
            ),
            BattleRoundSummary(
                round: 2,
                attackerPower: 850,
                defenderPower: 220,
                attackerLosses: [.smallCargo: 1],
                defenderShipLosses: [.lightFighter: 2],
                defenderDefenseLosses: [.rocketLauncher: 1],
                attackerShots: 3,
                defenderShots: 3,
                shieldDamage: 120,
                hullDamage: 500,
                explodedUnits: 1
            )
        ]
    )

    guard let review = CombatReviewEngine.review(for: report) else {
        fatalError("Battle report should produce a combat review")
    }

    requireEqual(review.outcome, .attackerVictory, "Review should identify attacker victory")
    requireEqual(review.rounds.count, 2, "Review should keep per-round rows")
    requireEqual(review.totalRapidFireShots, 3, "Review should aggregate rapid fire")
    requireEqual(review.totalExplodedUnits, 3, "Review should aggregate explosions")
    requireEqual(review.moonChancePercent, 3, "Review should calculate moon chance from debris")
    require(review.insights.contains { $0.kind == .rapidFire }, "Review should highlight rapid fire")
    require(review.insights.contains { $0.kind == .debrisRecovery }, "Review should highlight debris recovery")
    require(review.insights.contains { $0.kind == .moonChance }, "Review should highlight moon chance")
}

func testCombatReviewExplainsDefenderHoldAndIgnoresNonBattleReports() {
    let battle = Report(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000c0a2")!,
        time: 240,
        kind: .battle,
        title: "Battle at [1:2:7]",
        summary: "Defender holds.",
        participants: [
            ReportParticipant(
                role: .attacker,
                factionID: fleetPlayerID(),
                planetID: fleetPlanetID(1),
                name: "Attacker",
                beforeShips: [.lightFighter: 3],
                afterShips: [:],
                losses: ResourceBundle(metal: 9_000, crystal: 3_000)
            ),
            ReportParticipant(
                role: .defender,
                factionID: fleetEnemyID(),
                planetID: fleetPlanetID(2),
                name: "Defender",
                beforeDefenses: [.rocketLauncher: 2],
                afterDefenses: [.rocketLauncher: 1],
                losses: ResourceBundle(metal: 2_000)
            )
        ],
        loot: .zero,
        debris: ResourceBundle(metal: 30_000),
        losses: ResourceBundle(metal: 11_000, crystal: 3_000),
        battleRounds: [
            BattleRoundSummary(
                round: 1,
                attackerPower: 300,
                defenderPower: 450,
                attackerLosses: [.lightFighter: 3],
                defenderDefenseLosses: [.rocketLauncher: 1],
                attackerShots: 3,
                defenderShots: 2,
                shieldDamage: 40,
                hullDamage: 500,
                explodedUnits: 3
            )
        ]
    )
    let espionage = Report(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000c0a3")!,
        time: 300,
        kind: .espionage,
        title: "Espionage",
        summary: "Intel",
        participants: []
    )

    guard let review = CombatReviewEngine.review(for: battle) else {
        fatalError("Battle report should produce review")
    }

    requireEqual(review.outcome, .defenderHeld, "Review should identify defender hold")
    require(review.insights.contains { $0.kind == .fleetComposition }, "Review should explain attacking fleet wipe")
    require(CombatReviewEngine.review(for: espionage) == nil, "Non-battle reports should not produce combat review")
}

func testStrongAttackAgainstWeakTargetHasReducedLootAndProtectionSummary() {
    var universe = makeCombatUniverse()
    universe.planets[0].resources = ResourceBundle(metal: 250_000, crystal: 120_000, deuterium: 120_000)
    universe.planets[0].shipInventory = [.cruiser: 12, .smallCargo: 4]
    universe.planets[1].shipInventory = [:]
    universe.planets[1].defenseInventory = [.rocketLauncher: 1]
    universe.planets[1].resources = ResourceBundle(metal: 20_000, crystal: 10_000, deuterium: 4_000)
    universe.rankings = [
        FactionScore(factionID: fleetPlayerID(), factionName: "Attacker", totalScore: 250_000),
        FactionScore(factionID: fleetEnemyID(), factionName: "Defender", totalScore: 8_000)
    ]
    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .attack,
        ships: [.cruiser: 12, .smallCargo: 4],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Strong attack fleet should launch")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    guard let report = universe.reports.last else {
        fatalError("Attack should create a battle report")
    }

    let baselineHalfLoot = ResourceBundle(metal: 10_000, crystal: 5_000, deuterium: 2_000)
    require(resourceTotal(report.loot) < resourceTotal(baselineHalfLoot), "Strong-vs-weak attacks should loot less than the standard fifty percent")
    require(report.summary.contains("非荣誉"), "Battle report should flag non-honorable attacks for review")
}

func testMoonChanceCanCreateMoonFromLargeDebrisBattle() {
    var universe = makeCombatUniverse()
    universe.planets[0].shipInventory = [.deathstar: 2, .battleship: 80]
    universe.planets[1].shipInventory = [.battleship: 80, .cruiser: 40, .lightFighter: 160]
    universe.planets[1].defenseInventory = [.rocketLauncher: 120, .lightLaser: 60, .heavyLaser: 20]
    let fleet = Fleet(
        id: FleetID(UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
        ownerID: fleetPlayerID(),
        mission: .attack,
        origin: universe.planets[0].coordinate,
        target: universe.planets[1].coordinate,
        ships: [.deathstar: 2, .battleship: 80],
        launchTime: universe.gameTime,
        arrivalTime: 120,
        returnTime: 240,
        originPlanetID: fleetPlanetID(1),
        targetPlanetID: fleetPlanetID(2)
    )

    _ = CombatEngine.resolveAttack(fleet, in: &universe)
    guard let report = universe.reports.last else {
        fatalError("Large debris battle should create a report")
    }
    let defenderAfter = requirePlanet(fleetPlanetID(2), in: universe, "Combat target should exist after moon chance battle")
    guard let moon = defenderAfter.moon else {
        fatalError("Large debris battle should create a moon")
    }
    require(resourceTotal(report.debris) >= 50_000, "Moon fixture should generate enough new debris")
    requireEqual(moon.name, "Shield Moon", "Generated moon should inherit a readable target name")
    requireEqual(moon.createdAt, fleet.arrivalTime, "Generated moon should preserve battle time")
    requireEqual(moon.buildingLevels, [BuildingKind: Int](), "Generated moon should start without moon buildings")
    requireEqual(moon.debrisOriginReportID, report.id, "Generated moon should link back to the battle report")
}

func testMissileStrikeDamagesDefensesWithoutLoot() {
    var universe = makeCombatUniverse()
    universe.planets[0].missileInventory = [.interplanetaryMissile: 3]
    universe.planets[1].resources = ResourceBundle(metal: 9_000, crystal: 4_500, deuterium: 1_500)
    universe.planets[1].defenseInventory = [.rocketLauncher: 8, .lightLaser: 4, .heavyLaser: 2]
    let targetBefore = requirePlanet(fleetPlanetID(2), in: universe, "Missile target should exist before strike")

    let result = CombatEngine.launchMissileStrike(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        missileCount: 2
    )

    guard case .resolved(let report) = result else {
        fatalError("Missile strike should resolve")
    }
    let originAfter = requirePlanet(fleetPlanetID(1), in: universe, "Missile origin should exist after strike")
    let targetAfter = requirePlanet(fleetPlanetID(2), in: universe, "Missile target should exist after strike")

    requireEqual(originAfter.missileInventory[.interplanetaryMissile], 1, "Missile strike should consume launched missiles")
    require(targetBefore.defenseInventory.values.reduce(0, +) > targetAfter.defenseInventory.values.reduce(0, +),
        "Missile strike should damage target defenses")
    requireEqual(targetAfter.resources, targetBefore.resources, "Missile strike should not loot target resources")
    requireEqual(report.kind, .missile, "Missile strike should create a missile report")
    requireEqual(report.loot, .zero, "Missile report should never include loot")
    requireEqual(report.debris, .zero, "Missile strike should not create recoverable debris")
    requireEqual(report.participants[1].beforeDefenses, targetBefore.defenseInventory, "Missile report should include starting defenses")
    requireEqual(report.participants[1].afterDefenses, targetAfter.defenseInventory, "Missile report should include damaged defenses")
    requireEqual(universe.events.last?.kind, .combat, "Missile strike should record a combat event")
}

func testAntiBallisticMissilesInterceptIncomingMissiles() {
    var universe = makeCombatUniverse()
    universe.planets[0].missileInventory = [.interplanetaryMissile: 3]
    universe.planets[1].missileInventory = [.antiBallisticMissile: 2]
    universe.planets[1].defenseInventory = [.rocketLauncher: 8]

    let result = CombatEngine.launchMissileStrike(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        missileCount: 3
    )

    guard case .resolved(let report) = result else {
        fatalError("Missile strike with interceptors should resolve")
    }

    requireEqual(universe.planets[0].missileInventory[.interplanetaryMissile], nil, "Launched missiles should be consumed")
    requireEqual(universe.planets[1].missileInventory[.antiBallisticMissile], nil, "Interceptors should be consumed first")
    requireEqual(universe.planets[1].defenseInventory[.rocketLauncher], 4, "Only one missile should pass through two interceptors")
    require(report.summary.contains("2 intercepted"), "Missile report should mention intercepted missiles")
}

func testMissileStrikeRejectsInvalidCoreTargets() {
    var samePlanetUniverse = makeCombatUniverse()
    samePlanetUniverse.planets[0].missileInventory = [.interplanetaryMissile: 1]
    samePlanetUniverse.planets[0].defenseInventory = [.rocketLauncher: 1]
    requireEqual(
        CombatEngine.launchMissileStrike(
            from: fleetPlanetID(1),
            to: fleetPlanetID(1),
            in: &samePlanetUniverse,
            missileCount: 1
        ),
        .failed(.samePlanet),
        "Core missile strikes should reject same-planet targets"
    )

    var friendlyUniverse = makeCombatUniverse()
    friendlyUniverse.planets[0].missileInventory = [.interplanetaryMissile: 1]
    friendlyUniverse.planets[1].ownerID = fleetPlayerID()
    requireEqual(
        CombatEngine.launchMissileStrike(
            from: fleetPlanetID(1),
            to: fleetPlanetID(2),
            in: &friendlyUniverse,
            missileCount: 1
        ),
        .failed(.invalidTarget),
        "Core missile strikes should reject friendly targets"
    )

    var neutralUniverse = makeCombatUniverse()
    neutralUniverse.planets[0].missileInventory = [.interplanetaryMissile: 1]
    neutralUniverse.planets[1].ownerID = nil
    requireEqual(
        CombatEngine.launchMissileStrike(
            from: fleetPlanetID(1),
            to: fleetPlanetID(2),
            in: &neutralUniverse,
            missileCount: 1
        ),
        .failed(.invalidTarget),
        "Core missile strikes should reject neutral targets"
    )

    var unownedOriginUniverse = makeCombatUniverse()
    unownedOriginUniverse.planets[0].ownerID = nil
    unownedOriginUniverse.planets[0].missileInventory = [.interplanetaryMissile: 1]
    requireEqual(
        CombatEngine.launchMissileStrike(
            from: fleetPlanetID(1),
            to: fleetPlanetID(2),
            in: &unownedOriginUniverse,
            missileCount: 1
        ),
        .failed(.missingOriginOwner),
        "Core missile strikes should require an owned origin"
    )
}

func testAttackReturnCargoIsCappedAfterCargoShipLosses() {
    var universe = makeCombatUniverse()
    universe.planets[0].shipInventory[.battleship] = 2
    universe.planets[1].defenseInventory = [.rocketLauncher: 10, .lightLaser: 4]
    let launchCargo = ResourceBundle(metal: 8_000)
    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .attack,
        ships: [.battleship: 2, .lightFighter: 8, .smallCargo: 2],
        cargo: launchCargo
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Cargo attack fleet should launch")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    guard let returningFleet = universe.fleets.first else {
        fatalError("Cargo attack should leave surviving ships returning")
    }
    let survivingCapacity = testCargoCapacity(returningFleet.ships, ruleSet: universe.ruleSet)

    require((returningFleet.ships[.smallCargo] ?? 0) < 2, "Combat fixture should destroy at least one cargo ship")
    require(resourceTotal(returningFleet.cargo) <= survivingCapacity, "Returning cargo should be capped to surviving fleet capacity")
    require(resourceTotal(returningFleet.cargo) < resourceTotal(launchCargo), "Cargo above surviving capacity should not remain on the returning fleet")
}

func testAttackWithMissingCombatRulesDoesNotMutateTargetOrCreateUnbalancedReport() {
    var ruleSet = RuleSet.fastSkirmish
    ruleSet.shipRules[.lightFighter] = nil
    ruleSet.defenseRules[.rocketLauncher] = nil
    var universe = makeCombatUniverse()
    universe.ruleSet = ruleSet
    let targetBefore = requirePlanet(fleetPlanetID(2), in: universe, "Target should exist before missing-rule combat")
    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .attack,
        ships: [.smallCargo: 2],
        cargo: .zero
    )
    guard case .launched(let launchedFleet) = launch else {
        fatalError("Attack with valid attacker rules should launch")
    }

    universe.gameTime = launchedFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &universe)

    let targetAfter = requirePlanet(fleetPlanetID(2), in: universe, "Target should exist after missing-rule combat")
    guard let report = universe.reports.last else {
        fatalError("Missing-rule combat should create a report")
    }

    requireEqual(targetAfter.resources, targetBefore.resources, "Missing combat rules should not mutate defender resources")
    requireEqual(targetAfter.shipInventory, targetBefore.shipInventory, "Missing combat rules should not delete defender ships")
    requireEqual(targetAfter.defenseInventory, targetBefore.defenseInventory, "Missing combat rules should not delete defender defenses")
    requireEqual(targetAfter.debrisField, targetBefore.debrisField, "Missing combat rules should not create debris")
    requireEqual(report.loot, .zero, "Missing combat rules should not report loot")
    requireEqual(report.debris, .zero, "Missing combat rules should not report debris")
    requireEqual(report.losses, .zero, "Missing combat rules should not report uncosted losses")
    require(report.summary.contains("deferred"), "Missing combat rules should produce a deferred report")
    requireEqual(universe.fleets.first?.ships, [.smallCargo: 2], "Missing combat rules should send the attack fleet home unchanged")
}

func testAttackMissionIsDeterministicAcrossSaveLoadAndUsesDistinctReportIDs() throws {
    var first = makeCombatUniverse()
    let firstLaunch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &first,
        mission: .attack,
        ships: [.lightFighter: 8, .smallCargo: 2],
        cargo: .zero
    )
    guard case .launched(let firstFleet) = firstLaunch else {
        fatalError("Attack fleet should launch for determinism check")
    }
    let encoded = try JSONEncoder().encode(first)
    var second = try JSONDecoder().decode(Universe.self, from: encoded)

    first.gameTime = firstFleet.arrivalTime
    second.gameTime = firstFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &first)
    FleetEngine.resolveDueFleets(in: &second)

    var differentBattle = makeCombatUniverse(seed: 78)
    let differentLaunch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &differentBattle,
        mission: .attack,
        ships: [.lightFighter: 8, .smallCargo: 2],
        cargo: .zero
    )
    guard case .launched(let differentFleet) = differentLaunch else {
        fatalError("Second attack fleet should launch")
    }
    differentBattle.gameTime = differentFleet.arrivalTime
    FleetEngine.resolveDueFleets(in: &differentBattle)

    requireEqual(first, second, "Attack resolution should be deterministic across save/load equality")
    require(first.reports[0].id != differentBattle.reports[0].id, "Different battles should not collide on report IDs")
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

func testPlayerAutoUpgradeQueuesBuildingAndResearchWhenEnabledDuringTick() {
    let player = makeAIEconomyFaction(
        index: 0,
        kind: .player,
        strategy: .balanced,
        researchLevels: [.energy: 3]
    )
    let playerPlanet = makeAIEconomyPlanet(
        index: 0,
        ownerID: player.id,
        resources: ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.metalMine: 2, .crystalMine: 2, .solarPlant: 4, .researchLab: 1]
    )
    var universe = makeAIEconomyUniverse(factions: [player], planets: [playerPlanet])

    SimulationEngine.tick(universe: &universe, delta: 60, isPlayerAutoUpgradeEnabled: true, eventPolicy: .domainOnly)

    let updatedPlanet = requirePlanet(playerPlanet.id, in: universe, "Player planet should remain")
    let updatedPlayer = requireFaction(player.id, in: universe, "Player faction should remain")
    requireEqual(updatedPlanet.buildQueue.count, 1, "Auto upgrade should queue one player building when enabled")
    requireEqual(updatedPlayer.researchQueue.count, 1, "Auto upgrade should queue one player research when enabled")
    requireEqual(universe.fleets, [], "Auto upgrade should not launch fleets")
}

func testPlayerAutoUpgradeDoesNotQueueWhenDisabled() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let playerPlanet = makeAIEconomyPlanet(
        index: 0,
        ownerID: player.id,
        resources: ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.metalMine: 2, .crystalMine: 2, .solarPlant: 4, .researchLab: 1]
    )
    var universe = makeAIEconomyUniverse(factions: [player], planets: [playerPlanet])

    SimulationEngine.tick(universe: &universe, delta: 60, eventPolicy: .domainOnly)

    let updatedPlanet = requirePlanet(playerPlanet.id, in: universe, "Player planet should remain")
    let updatedPlayer = requireFaction(player.id, in: universe, "Player faction should remain")
    requireEqual(updatedPlanet.buildQueue, [], "Disabled auto upgrade should leave player building queue unchanged")
    requireEqual(updatedPlayer.researchQueue, [], "Disabled auto upgrade should leave player research queue unchanged")
}

func testStrategicAdvisorHighlightsEnergyDeficitAndStoragePressure() {
    let planetID = queuePlanetID()
    let universe = makeQueueUniverse(
        resources: ResourceBundle(metal: 96_000, crystal: 10_000, deuterium: 8_000),
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.metalMine: 8, .crystalMine: 6, .deuteriumSynthesizer: 4, .solarPlant: 1]
    )

    let recommendations = StrategicAdvisorEngine.recommendations(in: universe)

    requireEqual(recommendations.first?.kind, .energyDeficit, "Advisor should lead with critical energy deficits")
    require(recommendations.contains { $0.kind == .storagePressure && $0.planetID == planetID }, "Advisor should surface near-full storage")
    require(recommendations.contains { $0.detail.contains("金属") }, "Storage pressure should name the constrained resource")
}

func testStrategicAdvisorRecommendsDebrisColonyAndExpeditionLoops() {
    var universe = makeFleetUniverse(
        originShips: [.recycler: 1, .colonyShip: 1, .smallCargo: 2, .espionageProbe: 1],
        targetDebris: ResourceBundle(metal: 900, crystal: 450),
        targetOwnerID: nil
    )
    universe.planets.append(
        Planet(
            id: fleetPlanetID(3),
            name: "Open Slot",
            coordinate: Coordinate(galaxy: 1, system: 1, position: 8),
            ownerID: nil
        )
    )

    let recommendations = StrategicAdvisorEngine.recommendations(in: universe, limit: 8)

    require(recommendations.contains { $0.kind == .debrisRecovery && $0.actionLabel == "派回收船" }, "Advisor should recommend recycler use when debris is visible")
    require(recommendations.contains { $0.kind == .colonyWindow && $0.actionLabel == "派殖民船" }, "Advisor should recommend colonization when a colony ship and open slot exist")
    require(recommendations.contains { $0.kind == .colonyWindow && $0.targetCoordinate != nil }, "Advisor should include the colony coordinate")
    require(recommendations.contains { $0.kind == .expeditionWindow }, "Advisor should recommend expeditions when cargo or probes are idle")
}

func testFleetMissionPlannerSummarizesRecycleValueAndTiming() {
    let universe = makeFleetUniverse(
        originResources: ResourceBundle(metal: 5_000, crystal: 3_000, deuterium: 20_000),
        originShips: [.recycler: 1],
        targetDebris: ResourceBundle(metal: 900, crystal: 450),
        targetOwnerID: nil
    )

    let plan = FleetMissionPlannerEngine.plan(
        originID: fleetPlanetID(1),
        targetID: fleetPlanetID(2),
        in: universe,
        mission: .recycle,
        ships: [.recycler: 1]
    )

    require(plan.isLaunchable, "Planner should mark an affordable recycler mission as launchable")
    require(plan.fuelCost > 0, "Planner should calculate fuel cost")
    require(plan.travelDuration > 0, "Planner should calculate travel duration")
    requireApproxEqual(plan.roundTripDuration, plan.travelDuration * 2, "Round trip should be outbound plus return")
    requireApproxEqual(plan.expectedValue, ResourceBundle(metal: 900, crystal: 450), "Recycler expected value should use visible debris")
    require(plan.notes.contains { $0.title == "残骸收益" }, "Planner should explain debris value")
}

func testFleetMissionPlannerBlocksMissingRequiredShipsAndFuel() {
    let universe = makeFleetUniverse(
        originResources: ResourceBundle(metal: 5_000, crystal: 3_000, deuterium: 0),
        originShips: [.smallCargo: 1],
        targetDebris: ResourceBundle(metal: 900, crystal: 450),
        targetOwnerID: nil
    )

    let plan = FleetMissionPlannerEngine.plan(
        originID: fleetPlanetID(1),
        targetID: fleetPlanetID(2),
        in: universe,
        mission: .recycle,
        ships: [.smallCargo: 1]
    )

    require(!plan.isLaunchable, "Planner should block impossible recycler missions")
    require(plan.blockers.contains(.missingRequiredShip), "Planner should identify the missing recycler")
    require(plan.blockers.contains(.insufficientFuel), "Planner should identify unavailable deuterium")
    require(plan.notes.contains { $0.kind == .requirement }, "Planner should produce a requirement note")
}

func testFleetMissionPlannerDoesNotRevealHiddenTargetResources() {
    let universe = makeFleetUniverse(
        originResources: ResourceBundle(metal: 5_000, crystal: 3_000, deuterium: 20_000),
        originShips: [.lightFighter: 4, .smallCargo: 1],
        targetResources: ResourceBundle(metal: 9_000, crystal: 4_000, deuterium: 1_000),
        targetOwnerID: fleetEnemyID()
    )

    let plan = FleetMissionPlannerEngine.plan(
        originID: fleetPlanetID(1),
        targetID: fleetPlanetID(2),
        targetIsVisible: false,
        in: universe,
        mission: .attack,
        ships: [.lightFighter: 4, .smallCargo: 1]
    )

    require(plan.blockers.contains(.targetNotVisible), "Planner should block attack planning for hidden targets")
    requireApproxEqual(plan.expectedValue, .zero, "Planner should not reveal hidden target resources")
    require(!plan.notes.contains { $0.title == "掠夺预估" }, "Planner should not render hidden loot notes")
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

func testAIStrategyBuildsShipsForRaiderFactions() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let raider = makeAIEconomyFaction(index: 1, strategy: .raider)
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let raiderPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: raider.id,
        resources: ResourceBundle(metal: 20_000, crystal: 20_000, deuterium: 4_000),
        buildingLevels: [.shipyard: 1, .roboticsFactory: 1, .solarPlant: 2]
    )
    var universe = makeAIEconomyUniverse(factions: [player, raider], planets: [playerPlanet, raiderPlanet])

    AIStrategyEngine.makeStrategicDecisions(in: &universe)

    let updatedRaiderPlanet = requirePlanet(raiderPlanet.id, in: universe, "Raider planet should remain")
    requireEqual(updatedRaiderPlanet.shipBuildQueue.count, 1, "Raider should queue one ship production order")
    guard case .ship(let queuedShip)? = updatedRaiderPlanet.shipBuildQueue.first?.unitKind else {
        fatalError("Raider queue item should build ships")
    }
    require(
        [.lightFighter, .smallCargo, .espionageProbe].contains(queuedShip),
        "Raider should prefer combat, cargo, or probe production"
    )
}

func testAIStrategyBuildsDefensesForThreatenedFactions() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let miner = makeAIEconomyFaction(
        index: 1,
        strategy: .miner,
        relations: [
            FactionRelation(
                factionID: player.id,
                posture: .hostile,
                threatScore: 4,
                lastInteractionTime: 120,
                attackCount: 2
            )
        ]
    )
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let minerPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: miner.id,
        resources: ResourceBundle(metal: 12_000, crystal: 4_000, deuterium: 1_000),
        buildingLevels: [.shipyard: 1, .metalMine: 2, .solarPlant: 2]
    )
    var universe = makeAIEconomyUniverse(factions: [player, miner], planets: [playerPlanet, minerPlanet])

    AIStrategyEngine.makeStrategicDecisions(in: &universe)

    let updatedMinerPlanet = requirePlanet(minerPlanet.id, in: universe, "Miner planet should remain")
    requireEqual(updatedMinerPlanet.defenseBuildQueue.count, 1, "Threatened miner should queue one defense order")
    guard case .defense(let queuedDefense)? = updatedMinerPlanet.defenseBuildQueue.first?.unitKind else {
        fatalError("Miner queue item should build defenses")
    }
    require(
        [.rocketLauncher, .lightLaser].contains(queuedDefense),
        "Threatened miner should prefer early defensive units"
    )
}

func testAIStrategyDoesNotReadHiddenPlayerFleetState() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let raider = makeAIEconomyFaction(index: 1, strategy: .raider)
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let hiddenClonePlayerPlanet = makeAIEconomyPlanet(
        index: 0,
        ownerID: player.id,
        shipInventory: [.battleship: 500, .cruiser: 500],
        defenseInventory: [.plasmaTurret: 100]
    )
    let raiderPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: raider.id,
        resources: ResourceBundle(metal: 20_000, crystal: 20_000, deuterium: 4_000),
        buildingLevels: [.shipyard: 1, .roboticsFactory: 1, .solarPlant: 2]
    )
    let original = makeAIEconomyUniverse(factions: [player, raider], planets: [playerPlanet, raiderPlanet])
    let hiddenFleetChanged = makeAIEconomyUniverse(factions: [player, raider], planets: [hiddenClonePlayerPlanet, raiderPlanet])
    var first = original
    var second = hiddenFleetChanged

    AIStrategyEngine.makeStrategicDecisions(in: &first)
    AIStrategyEngine.makeStrategicDecisions(in: &second)

    requireEqual(
        requirePlanet(raiderPlanet.id, in: first, "First raider planet should remain").shipBuildQueue,
        requirePlanet(raiderPlanet.id, in: second, "Second raider planet should remain").shipBuildQueue,
        "AI strategic production should not change after hidden player fleet or defense inventory changes"
    )
}

func testAIRaiderLaunchesEspionageBeforeAttack() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let raider = makeAIEconomyFaction(index: 1, strategy: .raider)
    let playerPlanet = makeAIEconomyPlanet(
        index: 0,
        ownerID: player.id,
        resources: ResourceBundle(metal: 8_000, crystal: 4_000, deuterium: 1_000)
    )
    let raiderPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: raider.id,
        resources: ResourceBundle(metal: 20_000, crystal: 20_000, deuterium: 8_000),
        buildingLevels: [.shipyard: 1, .roboticsFactory: 1, .solarPlant: 2],
        shipInventory: [.espionageProbe: 2, .lightFighter: 5, .smallCargo: 1]
    )
    var universe = makeAIEconomyUniverse(factions: [player, raider], planets: [playerPlanet, raiderPlanet])

    AIStrategyEngine.makeStrategicDecisions(in: &universe)

    requireEqual(universe.fleets.count, 1, "Raider should launch one strategic fleet")
    requireEqual(universe.fleets[0].mission, .espionage, "Raider should scout before attacking without a report")
    requireEqual(universe.fleets[0].targetPlanetID, playerPlanet.id, "Raider should scout the visible rival planet")
}

func testAIExpansionistColonizesKnownNeutralWorld() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let expansionist = makeAIEconomyFaction(index: 1, strategy: .expansionist)
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let expansionistPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: expansionist.id,
        resources: ResourceBundle(metal: 30_000, crystal: 30_000, deuterium: 20_000),
        buildingLevels: [.shipyard: 1, .roboticsFactory: 1, .solarPlant: 2],
        shipInventory: [.colonyShip: 1, .smallCargo: 1]
    )
    let neutralPlanet = makeAIEconomyPlanet(index: 2, ownerID: expansionist.id)
    var unclaimed = neutralPlanet
    unclaimed.ownerID = nil
    unclaimed.name = "Known Empty"
    var universe = makeAIEconomyUniverse(
        factions: [player, expansionist],
        planets: [playerPlanet, expansionistPlanet, unclaimed]
    )
    universe.explorationRecords = [
        ExplorationRecord(
            factionID: expansionist.id,
            targetPlanetID: unclaimed.id,
            exploredAt: 60,
            discoveredNeutral: true
        )
    ]

    AIStrategyEngine.makeStrategicDecisions(in: &universe)

    requireEqual(universe.fleets.count, 1, "Expansionist should launch one strategic fleet")
    requireEqual(universe.fleets[0].mission, .colonize, "Expansionist should colonize known neutral worlds")
    requireEqual(universe.fleets[0].targetPlanetID, unclaimed.id, "Expansionist should target the known neutral world")
}

func testAIExpansionistSeedsServiceStyleColonizationTargetWhenNoneKnown() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let expansionist = makeAIEconomyFaction(index: 1, strategy: .expansionist)
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let expansionistPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: expansionist.id,
        resources: ResourceBundle(metal: 30_000, crystal: 30_000, deuterium: 20_000),
        buildingLevels: [.shipyard: 1, .roboticsFactory: 1, .solarPlant: 2],
        shipInventory: [.colonyShip: 1, .smallCargo: 1]
    )
    var universe = makeAIEconomyUniverse(factions: [player, expansionist], planets: [playerPlanet, expansionistPlanet])

    AIStrategyEngine.makeStrategicDecisions(in: &universe)

    requireEqual(universe.fleets.count, 1, "Expansionist should launch one strategic fleet")
    requireEqual(universe.fleets[0].mission, .colonize, "Expansionist should seed and colonize a topology-backed empty world")
    guard let targetPlanetID = universe.fleets[0].targetPlanetID else {
        fatalError("Seeded colonization fleet should remember its target planet")
    }
    let target = requirePlanet(targetPlanetID, in: universe, "Seeded expansion target should exist")
    requireEqual(target.ownerID, nil, "Seeded expansion target should be neutral before arrival")
    require(UniverseTopologyEngine.isValidPlanetCoordinate(target.coordinate), "Seeded expansion target should be a valid planet slot")
}

func testAIRecyclerCollectsKnownDebris() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let miner = makeAIEconomyFaction(index: 1, strategy: .miner)
    let playerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let minerPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: miner.id,
        resources: ResourceBundle(metal: 20_000, crystal: 20_000, deuterium: 8_000),
        buildingLevels: [.shipyard: 1, .roboticsFactory: 1, .solarPlant: 2],
        shipInventory: [.recycler: 1]
    )
    let debrisPlanet = makeAIEconomyPlanet(
        index: 2,
        ownerID: player.id,
        debrisField: ResourceBundle(metal: 4_000, crystal: 2_000)
    )
    var universe = makeAIEconomyUniverse(factions: [player, miner], planets: [playerPlanet, minerPlanet, debrisPlanet])
    universe.explorationRecords = [
        ExplorationRecord(
            factionID: miner.id,
            targetPlanetID: debrisPlanet.id,
            exploredAt: 80,
            discoveredDebris: ResourceBundle(metal: 4_000, crystal: 2_000),
            discoveredOwnerID: player.id
        )
    ]

    AIStrategyEngine.makeStrategicDecisions(in: &universe)

    requireEqual(universe.fleets.count, 1, "Recycler should launch one strategic fleet")
    requireEqual(universe.fleets[0].mission, .recycle, "AI should recycle known debris")
    requireEqual(universe.fleets[0].targetPlanetID, debrisPlanet.id, "AI should target the known debris field")
}

func testAIAttackUsesKnownWeakTargetOnly() {
    let player = Faction(
        id: aiTestPlayerID(),
        name: "Player",
        kind: .player,
        strategy: .balanced,
        ownedPlanetIDs: [aiTestPlanetID(0), aiTestPlanetID(2)]
    )
    let raider = makeAIEconomyFaction(index: 1, strategy: .raider)
    let knownWeak = makeAIEconomyPlanet(
        index: 0,
        ownerID: player.id,
        resources: ResourceBundle(metal: 6_000, crystal: 2_000, deuterium: 500)
    )
    let raiderPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: raider.id,
        resources: ResourceBundle(metal: 30_000, crystal: 20_000, deuterium: 10_000),
        buildingLevels: [.shipyard: 1, .roboticsFactory: 1, .solarPlant: 2],
        shipInventory: [.lightFighter: 6, .smallCargo: 1, .espionageProbe: 1]
    )
    let unknownRich = makeAIEconomyPlanet(
        index: 2,
        ownerID: player.id,
        resources: ResourceBundle(metal: 90_000, crystal: 50_000, deuterium: 20_000),
        shipInventory: [.battleship: 20],
        defenseInventory: [.plasmaTurret: 20]
    )
    var universe = makeAIEconomyUniverse(factions: [player, raider], planets: [knownWeak, raiderPlanet, unknownRich])
    universe.explorationRecords = [
        ExplorationRecord(
            factionID: raider.id,
            targetPlanetID: knownWeak.id,
            exploredAt: 90,
            discoveredResources: knownWeak.resources,
            discoveredOwnerID: player.id
        )
    ]
    universe.reports = [
        Report(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000aa01")!,
            time: 95,
            kind: .espionage,
            title: "Known weak scan",
            summary: "Known weak target.",
            participants: [
                ReportParticipant(role: .attacker, factionID: raider.id, planetID: raiderPlanet.id, name: "Scout"),
                ReportParticipant(
                    role: .defender,
                    factionID: player.id,
                    planetID: knownWeak.id,
                    name: "Known Weak",
                    beforeShips: [:],
                    afterShips: [:],
                    beforeDefenses: [:],
                    afterDefenses: [:]
                )
            ]
        )
    ]

    AIStrategyEngine.makeStrategicDecisions(in: &universe)

    requireEqual(universe.fleets.count, 1, "Raider should launch one strategic fleet")
    requireEqual(universe.fleets[0].mission, .attack, "Raider should attack after a weak target report")
    requireEqual(universe.fleets[0].targetPlanetID, knownWeak.id, "Raider should attack the known weak target only")
}

func testOfflineCatchUpCapsAIAggressiveFleetLaunchesByChunkPressure() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let raider = makeAIEconomyFaction(index: 1, strategy: .raider)
    let knownWeak = Planet(
        id: aiTestPlanetID(0),
        name: "Close Weak",
        coordinate: Coordinate(galaxy: 1, system: 10, position: 4),
        ownerID: player.id,
        resources: ResourceBundle(metal: 90_000, crystal: 30_000, deuterium: 10_000),
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000)
    )
    let raiderPlanet = Planet(
        id: aiTestPlanetID(1),
        name: "Close Raider",
        coordinate: Coordinate(galaxy: 1, system: 10, position: 5),
        ownerID: raider.id,
        resources: ResourceBundle(metal: 90_000, crystal: 90_000, deuterium: 90_000),
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.shipyard: 1, .roboticsFactory: 1, .solarPlant: 2],
        shipInventory: [.lightFighter: 80, .smallCargo: 10]
    )
    var universe = makeAIEconomyUniverse(
        factions: [player, raider],
        planets: [knownWeak, raiderPlanet],
        ruleSet: fastSkirmishRules(offlineChunkInterval: 120)
    )
    universe.explorationRecords = [
        ExplorationRecord(
            factionID: raider.id,
            targetPlanetID: knownWeak.id,
            exploredAt: 90,
            discoveredResources: knownWeak.resources,
            discoveredOwnerID: player.id
        )
    ]
    universe.reports = [
        Report(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000aa02")!,
            time: 95,
            kind: .espionage,
            title: "Close weak scan",
            summary: "Known weak target.",
            participants: [
                ReportParticipant(role: .attacker, factionID: raider.id, planetID: raiderPlanet.id, name: "Scout"),
                ReportParticipant(role: .defender, factionID: player.id, planetID: knownWeak.id, name: "Close Weak")
            ]
        )
    ]

    let summary = OfflineSimulationEngine.catchUp(universe: &universe, elapsed: 7_200, now: Date(timeIntervalSince1970: 7_200))
    let battleReports = universe.reports.filter { $0.kind == .battle }

    requireEqual(summary.processedChunks, 60, "Offline catch-up should still process the requested chunk window")
    require(
        battleReports.count <= 1,
        "Offline catch-up should cap aggressive AI battle chains under chunk pressure"
    )
    requireEqual(universe.events.last?.title, "Offline Catch-Up Complete", "Offline catch-up should keep the summary event")
}

func testEasyAIDoesNotAttackWithoutReport() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let raider = makeAIEconomyFaction(index: 1, strategy: .raider)
    let playerPlanet = makeAIEconomyPlanet(
        index: 0,
        ownerID: player.id,
        resources: ResourceBundle(metal: 20_000, crystal: 10_000, deuterium: 5_000)
    )
    let raiderPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: raider.id,
        resources: ResourceBundle(metal: 30_000, crystal: 30_000, deuterium: 10_000),
        buildingLevels: [.shipyard: 1, .roboticsFactory: 1, .solarPlant: 2],
        shipInventory: [.lightFighter: 10, .smallCargo: 2, .espionageProbe: 1]
    )
    var universe = makeAIEconomyUniverse(factions: [player, raider], planets: [playerPlanet, raiderPlanet])

    AIStrategyEngine.makeStrategicDecisions(
        in: &universe,
        policy: AIDifficultyPolicy(difficulty: .easy)
    )

    requireEqual(universe.fleets.count, 1, "Easy AI should launch at most one cautious fleet")
    requireEqual(universe.fleets[0].mission, .espionage, "Easy AI should scout instead of attacking without a report")
}

func testHardAICanUseRankingsButNotHiddenInventory() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let raider = makeAIEconomyFaction(index: 1, strategy: .raider)
    let exposedPlayerPlanet = makeAIEconomyPlanet(index: 0, ownerID: player.id)
    let hiddenStrongPlayerPlanet = makeAIEconomyPlanet(
        index: 0,
        ownerID: player.id,
        shipInventory: [.battleship: 300],
        defenseInventory: [.plasmaTurret: 100]
    )
    let raiderPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: raider.id,
        resources: ResourceBundle(metal: 30_000, crystal: 30_000, deuterium: 10_000),
        buildingLevels: [.shipyard: 1, .roboticsFactory: 1, .solarPlant: 2],
        shipInventory: [.lightFighter: 10, .smallCargo: 2, .espionageProbe: 1]
    )
    var first = makeAIEconomyUniverse(factions: [player, raider], planets: [exposedPlayerPlanet, raiderPlanet])
    var second = makeAIEconomyUniverse(factions: [player, raider], planets: [hiddenStrongPlayerPlanet, raiderPlanet])
    let rankings = [
        FactionScore(factionID: raider.id, factionName: "AI 1", rank: 1, totalScore: 30_000),
        FactionScore(factionID: player.id, factionName: "Player", rank: 2, totalScore: 2_000)
    ]
    first.rankings = rankings
    second.rankings = rankings

    AIStrategyEngine.makeStrategicDecisions(
        in: &first,
        policy: AIDifficultyPolicy(difficulty: .hard)
    )
    AIStrategyEngine.makeStrategicDecisions(
        in: &second,
        policy: AIDifficultyPolicy(difficulty: .hard)
    )

    requireEqual(first.fleets.count, 1, "Hard AI should launch one ranked-pressure fleet")
    requireEqual(second.fleets.count, 1, "Hard AI should launch one ranked-pressure fleet in the hidden clone")
    requireEqual(first.fleets[0].mission, .attack, "Hard AI may attack from ranking pressure")
    requireEqual(second.fleets[0].mission, .attack, "Hard AI should not switch away because hidden inventories changed")
    requireEqual(first.fleets[0].targetPlanetID, second.fleets[0].targetPlanetID, "Hard AI ranked attack target should not depend on hidden inventory")
    requireEqual(first.fleets[0].ships, second.fleets[0].ships, "Hard AI ranked attack fleet should not depend on hidden inventory")
}

func testThreatMemoryChangesDefensivePosture() {
    let player = makeAIEconomyFaction(index: 0, kind: .player, strategy: .balanced)
    let threatenedMiner = makeAIEconomyFaction(
        index: 1,
        strategy: .miner,
        relations: [FactionRelation(factionID: player.id, posture: .hostile, threatScore: 5)]
    )
    let cautiousMinerPlanet = makeAIEconomyPlanet(
        index: 1,
        ownerID: threatenedMiner.id,
        resources: ResourceBundle(metal: 12_000, crystal: 4_000, deuterium: 1_000),
        buildingLevels: [.shipyard: 1, .solarPlant: 2]
    )
    var easyUniverse = makeAIEconomyUniverse(
        factions: [player, threatenedMiner],
        planets: [makeAIEconomyPlanet(index: 0, ownerID: player.id), cautiousMinerPlanet]
    )
    var hardUniverse = easyUniverse

    AIStrategyEngine.makeStrategicDecisions(
        in: &easyUniverse,
        policy: AIDifficultyPolicy(difficulty: .easy)
    )
    AIStrategyEngine.makeStrategicDecisions(
        in: &hardUniverse,
        policy: AIDifficultyPolicy(difficulty: .hard)
    )

    let easyDefense = requirePlanet(cautiousMinerPlanet.id, in: easyUniverse, "Easy miner planet should remain")
        .defenseBuildQueue
        .first
    let hardDefense = requirePlanet(cautiousMinerPlanet.id, in: hardUniverse, "Hard miner planet should remain")
        .defenseBuildQueue
        .first

    require(easyDefense?.quantity ?? 0 > hardDefense?.quantity ?? 0, "Easy threat memory should produce a heavier defensive posture")
}

func testShipBuildRequiresConfiguredTechnologyGate() {
    var ruleSet = RuleSet.fastSkirmish
    var cruiserRule = ruleSet.shipRules[.cruiser]!
    cruiserRule.requirements = [.technology(.impulseDrive, level: 2)]
    ruleSet.shipRules[.cruiser] = cruiserRule
    var lockedUniverse = makeQueueUniverse(
        resources: ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.shipyard: 4],
        ruleSet: ruleSet
    )

    let lockedResult = QueueEngine.startShipBuild(on: queuePlanetID(), in: &lockedUniverse, kind: .cruiser, quantity: 1)

    requireEqual(
        lockedResult,
        .missingRequirement(.technology(.impulseDrive, level: 2)),
        "Ship build should fail when a configured technology gate is missing"
    )
    requireEqual(lockedUniverse.planets[0].shipBuildQueue, [], "Locked ship build should not mutate the ship queue")

    var unlockedUniverse = makeQueueUniverse(
        resources: ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.shipyard: 4],
        researchLevels: [.impulseDrive: 2],
        ruleSet: ruleSet
    )
    requireEqual(
        QueueEngine.startShipBuild(on: queuePlanetID(), in: &unlockedUniverse, kind: .cruiser, quantity: 1),
        .queued,
        "Ship build should queue once the configured technology gate is met"
    )
}

func testDefenseBuildRequiresConfiguredBuildingGate() {
    var ruleSet = RuleSet.fastSkirmish
    var plasmaRule = ruleSet.defenseRules[.plasmaTurret]!
    plasmaRule.requirements = [.building(.shipyard, level: 6)]
    ruleSet.defenseRules[.plasmaTurret] = plasmaRule
    var lockedUniverse = makeQueueUniverse(
        resources: ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.shipyard: 5],
        ruleSet: ruleSet
    )

    let lockedResult = QueueEngine.startDefenseBuild(on: queuePlanetID(), in: &lockedUniverse, kind: .plasmaTurret, quantity: 1)

    requireEqual(
        lockedResult,
        .missingRequirement(.building(.shipyard, level: 6)),
        "Defense build should fail when a configured building gate is missing"
    )
    requireEqual(lockedUniverse.planets[0].defenseBuildQueue, [], "Locked defense build should not mutate the defense queue")

    var unlockedUniverse = makeQueueUniverse(
        resources: ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.shipyard: 6],
        ruleSet: ruleSet
    )
    requireEqual(
        QueueEngine.startDefenseBuild(on: queuePlanetID(), in: &unlockedUniverse, kind: .plasmaTurret, quantity: 1),
        .queued,
        "Defense build should queue once the configured building gate is met"
    )
}

func testUIHelpersExposeLockedReason() {
    let technologyGate = RuleRequirement.technology(.impulseDrive, level: 2)
    let buildingGate = RuleRequirement.building(.shipyard, level: 6)

    requireEqual(
        technologyGate.lockedReason,
        "需要脉冲引擎等级 2",
        "Technology requirements should expose compact locked reason text"
    )
    requireEqual(
        buildingGate.lockedReason,
        "需要造船厂等级 6",
        "Building requirements should expose compact locked reason text"
    )
}

func testFastSkirmishRuleSetBackfillsRequirementsWhenDecodingOlderJSON() throws {
    let json = """
    {
      "id": "fast-skirmish-v1",
      "displayName": "Fast Skirmish",
      "baseTickInterval": 1,
      "offlineChunkInterval": 300,
      "buildingRules": {},
      "researchRules": {},
      "shipRules": {
        "cruiser": {
          "baseCost": { "metal": 20000, "crystal": 7000, "deuterium": 2000 },
          "baseDuration": 45,
          "aiPriorityWeight": 0.45,
          "speed": 15000,
          "cargoCapacity": 800,
          "fuelCost": 300,
          "attack": 400,
          "shield": 50,
          "hull": 27000
        }
      },
      "defenseRules": {}
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(RuleSet.self, from: json)

    requireEqual(
        decoded.buildingRules[.shipyard]?.requirements,
        RuleSet.fastSkirmish.buildingRules[.shipyard]?.requirements,
        "Older fast-skirmish building rules should regain default requirements"
    )
    requireEqual(
        decoded.researchRules[.hyperspaceDrive]?.requirements,
        RuleSet.fastSkirmish.researchRules[.hyperspaceDrive]?.requirements,
        "Older fast-skirmish research rules should regain default requirements"
    )
    requireEqual(
        decoded.shipRules[.cruiser]?.requirements,
        RuleSet.fastSkirmish.shipRules[.cruiser]?.requirements,
        "Older fast-skirmish ship rules should regain default requirements"
    )
    requireEqual(
        decoded.defenseRules[.plasmaTurret]?.requirements,
        RuleSet.fastSkirmish.defenseRules[.plasmaTurret]?.requirements,
        "Older fast-skirmish defense rules should regain default requirements"
    )
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

func testQueueEngineAppendsBuildingAndResearchQueues() {
    let buildItem = BuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000c3")!,
        planetID: queuePlanetID(),
        buildingKind: .metalMine,
        targetLevel: 2,
        startTime: 0,
        finishTime: 26,
        paidCost: ResourceBundle(metal: 90, crystal: 22.5)
    )
    var buildingUniverse = makeQueueUniverse(
        resources: ResourceBundle(metal: 10_000, crystal: 10_000, deuterium: 10_000),
        buildingLevels: [.metalMine: 1],
        buildQueue: [buildItem]
    )

    let buildingResult = QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &buildingUniverse, kind: .metalMine)

    requireEqual(buildingResult, QueueResult.queued, "Planet with an active building queue should append another building")
    requireEqual(buildingUniverse.planets[0].buildQueue.count, 2, "Building queue should keep the existing item and append the new item")
    let appendedBuilding = buildingUniverse.planets[0].buildQueue[1]
    requireEqual(appendedBuilding.buildingKind, .metalMine, "Appended building should keep the requested kind")
    requireEqual(appendedBuilding.targetLevel, 3, "Appended building should target the next queued level")
    requireEqual(appendedBuilding.startTime, 26, "Appended building should start after the current queue tail")
    requireEqual(appendedBuilding.finishTime, 60, "Appended building should finish after its own level-scaled duration")
    requireEqual(
        buildingUniverse.planets[0].resources,
        ResourceBundle(metal: 9_865, crystal: 9_966.25, deuterium: 10_000),
        "Appending a building should pay only the newly queued level cost"
    )

    let researchItem = ResearchQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000c4")!,
        factionID: queuePlayerID(),
        technologyKind: .computer,
        targetLevel: 2,
        startTime: 0,
        finishTime: 75,
        paidCost: ResourceBundle(crystal: 800, deuterium: 1_200)
    )
    var researchUniverse = makeQueueUniverse(
        resources: ResourceBundle(metal: 10_000, crystal: 10_000, deuterium: 10_000),
        researchLevels: [.computer: 1],
        researchQueue: [researchItem]
    )

    let researchResult = QueueEngine.startResearch(for: queuePlayerID(), in: &researchUniverse, technology: .computer)

    requireEqual(researchResult, QueueResult.queued, "Faction with an active research queue should append another research")
    requireEqual(researchUniverse.factions[0].researchQueue.count, 2, "Research queue should keep the existing item and append the new item")
    let appendedResearch = researchUniverse.factions[0].researchQueue[1]
    requireEqual(appendedResearch.technologyKind, .computer, "Appended research should keep the requested technology")
    requireEqual(appendedResearch.targetLevel, 3, "Appended research should target the next queued level")
    requireEqual(appendedResearch.startTime, 75, "Appended research should start after the current queue tail")
    requireEqual(appendedResearch.finishTime, 187.5, "Appended research should finish after its own level-scaled duration")
    requireEqual(
        researchUniverse.planets[0].resources,
        ResourceBundle(metal: 10_000, crystal: 8_400, deuterium: 7_600),
        "Appending research should pay only the newly queued level cost"
    )
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
        productionPerHour: ResourceBundle(metal: 120),
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
        productionPerHour: ResourceBundle(metal: 120),
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
    requireApproxEqual(universe.planets[0].energy.produced, 22, "Completed building queue should recompute produced energy")
    requireApproxEqual(universe.planets[0].energy.used, 0, "Completed building queue should recompute used energy")

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
    requireApproxEqual(universe.planets[0].energy.produced, 22, "Already-due solar completion should update produced energy before production")
    requireApproxEqual(universe.planets[0].energy.used, 11, "Already-due solar completion should update used energy before production")
    requireApproxEqual(universe.planets[0].resources.metal, 212, "Solar completion should power existing mine production during the same tick")
    requireApproxEqual(universe.planets[1].resources.metal, 212, "Mine completion should produce during the same tick")

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

func testQueueEngineStartsMissileBuildAndCompletesIntoInventory() {
    var universe = makeQueueUniverse(
        resources: ResourceBundle(metal: 40_000, crystal: 20_000, deuterium: 20_000),
        buildingLevels: [.shipyard: 4],
        researchLevels: [.impulseDrive: 2]
    )

    let result = QueueEngine.startMissileBuild(
        on: queuePlanetID(),
        in: &universe,
        kind: .interplanetaryMissile,
        quantity: 2
    )

    requireEqual(result, QueueResult.queued, "Missile build should queue when requirements and resources are met")
    requireEqual(universe.planets[0].defenseBuildQueue.count, 1, "Missile build should use the defensive production queue")

    let item = universe.planets[0].defenseBuildQueue[0]
    let expectedCost = ResourceBundle(metal: 5_000, crystal: 2_000, deuterium: 4_000)
    requireEqual(item.planetID, queuePlanetID(), "Missile queue item should target the requested planet")
    requireEqual(item.unitKind, .missile(.interplanetaryMissile), "Missile queue item should store the missile kind")
    requireEqual(item.quantity, 2, "Missile queue item should store the requested quantity")
    requireEqual(item.startTime, 0, "Missile queue item should start at current game time")
    requireEqual(item.finishTime, 60, "Missile queue item should finish after quantity-scaled duration")
    requireEqual(item.paidCost, expectedCost, "Missile queue item should store the paid cost")

    SimulationEngine.tick(universe: &universe, delta: 60)

    requireEqual(universe.planets[0].missileInventory[.interplanetaryMissile], 2, "Completed missile build should increment missile inventory")
    requireEqual(universe.planets[0].defenseBuildQueue, [], "Completed missile build should leave the defensive production queue")
    requireEqual(universe.events.filter { $0.title == "Missile Construction Complete" }.count, 1, "Completing a missile build should record an event")
}

func testQueueEngineAppendsUnitQueues() {
    let shipItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000d3")!,
        planetID: queuePlanetID(),
        unitKind: .ship(.smallCargo),
        quantity: 1,
        startTime: 0,
        finishTime: 10,
        paidCost: ResourceBundle(metal: 2_000, crystal: 2_000)
    )
    var shipUniverse = makeQueueUniverse(
        resources: ResourceBundle(metal: 10_000, crystal: 10_000, deuterium: 10_000),
        shipBuildQueue: [shipItem]
    )

    let shipResult = QueueEngine.startShipBuild(on: queuePlanetID(), in: &shipUniverse, kind: .smallCargo, quantity: 1)

    requireEqual(shipResult, QueueResult.queued, "Planet with an active ship queue should append another ship build")
    requireEqual(shipUniverse.planets[0].shipBuildQueue.count, 2, "Ship queue should keep the existing item and append the new item")
    let appendedShip = shipUniverse.planets[0].shipBuildQueue[1]
    requireEqual(appendedShip.unitKind, .ship(.smallCargo), "Appended ship order should keep the requested ship kind")
    requireEqual(appendedShip.startTime, 10, "Appended ship order should start after the ship queue tail")
    requireEqual(appendedShip.finishTime, 20, "Appended ship order should finish after its own duration")
    requireEqual(
        shipUniverse.planets[0].resources,
        ResourceBundle(metal: 8_000, crystal: 8_000, deuterium: 10_000),
        "Appending a ship order should pay only the newly queued order cost"
    )

    let defenseItem = UnitBuildQueueItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000d4")!,
        planetID: queuePlanetID(),
        unitKind: .defense(.rocketLauncher),
        quantity: 1,
        startTime: 0,
        finishTime: 6,
        paidCost: ResourceBundle(metal: 2_000)
    )
    var defenseUniverse = makeQueueUniverse(
        resources: ResourceBundle(metal: 40_000, crystal: 20_000, deuterium: 20_000),
        buildingLevels: [.shipyard: 4],
        researchLevels: [.impulseDrive: 2],
        defenseBuildQueue: [defenseItem]
    )

    let defenseResult = QueueEngine.startDefenseBuild(
        on: queuePlanetID(),
        in: &defenseUniverse,
        kind: .rocketLauncher,
        quantity: 1
    )

    requireEqual(defenseResult, QueueResult.queued, "Planet with an active defense queue should append another defense build")
    requireEqual(defenseUniverse.planets[0].defenseBuildQueue.count, 2, "Defense queue should keep the existing item and append the new item")
    let appendedDefense = defenseUniverse.planets[0].defenseBuildQueue[1]
    requireEqual(appendedDefense.unitKind, .defense(.rocketLauncher), "Appended defense order should keep the requested defense kind")
    requireEqual(appendedDefense.startTime, 6, "Appended defense order should start after the defensive queue tail")
    requireEqual(appendedDefense.finishTime, 12, "Appended defense order should finish after its own duration")

    let missileResult = QueueEngine.startMissileBuild(
        on: queuePlanetID(),
        in: &defenseUniverse,
        kind: .interplanetaryMissile,
        quantity: 1
    )

    requireEqual(missileResult, QueueResult.queued, "Planet with an active defensive queue should append missile builds too")
    requireEqual(defenseUniverse.planets[0].defenseBuildQueue.count, 3, "Missile build should append to the defensive production queue")
    let appendedMissile = defenseUniverse.planets[0].defenseBuildQueue[2]
    requireEqual(appendedMissile.unitKind, .missile(.interplanetaryMissile), "Appended missile order should keep the requested missile kind")
    requireEqual(appendedMissile.startTime, 12, "Appended missile order should start after the defensive queue tail")
    requireEqual(appendedMissile.finishTime, 42, "Appended missile order should finish after its own duration")
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
        ResourceBundle(metal: 370.4, crystal: 128, deuterium: 52.8),
        "Economy production should use server-shaped mine curves with single-player base income"
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
        ResourceBundle(metal: 470.4, crystal: 328, deuterium: 352.8),
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
        ResourceBundle(metal: 212, crystal: 128, deuterium: 0),
        "Energy shortage should reduce mine output while preserving base income"
    )
}

func testPlanetProductionSettingsScaleMineOutputAndEnergyUse() {
    var planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000ba")!),
        name: "Throttled Mines",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 11),
        ownerID: queuePlayerID(),
        resources: .zero,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [
            .metalMine: 2,
            .crystalMine: 1,
            .deuteriumSynthesizer: 1,
            .solarPlant: 4
        ],
        productionSettings: [
            .metalMine: 0.5,
            .crystalMine: 0,
            .deuteriumSynthesizer: 0.25
        ]
    )

    EconomyEngine.recomputeEnergy(for: &planet, ruleSet: .fastSkirmish)
    let production = EconomyEngine.productionPerHour(for: planet, ruleSet: .fastSkirmish)

    requireApproxEqual(planet.energy.produced, 117.128, "Production settings should preserve solar energy output")
    requireApproxEqual(planet.energy.used, 20.35, "Production settings should scale mine energy usage")
    requireApproxEqual(
        production,
        ResourceBundle(metal: 225.2, crystal: 40, deuterium: 13.2),
        "Production settings should scale each mine output independently while preserving base income"
    )
}

func testStorageBuildingsIncreaseStorageCaps() {
    let planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000bb")!),
        name: "Expanded Vaults",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 12),
        ownerID: queuePlayerID(),
        resources: .zero,
        storage: ResourceStorage(metal: 500, crystal: 600, deuterium: 700),
        buildingLevels: [
            .metalStorage: 2,
            .crystalStorage: 1,
            .deuteriumTank: 1
        ]
    )

    let storage = EconomyEngine.storageCapacity(for: planet, ruleSet: .fastSkirmish)

    requireEqual(
        storage,
        ResourceStorage(metal: 1_125, crystal: 900, deuterium: 1_050),
        "Storage buildings should use server-shaped lane-specific storage caps"
    )
}

func testRoboticsAndNaniteStyleAccelerationShortensBuildDurations() {
    var unaccelerated = makeQueueUniverse(
        resources: ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.shipyard: 1],
        researchLevels: [.espionage: 1]
    )
    var accelerated = makeQueueUniverse(
        resources: ResourceBundle(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.roboticsFactory: 2, .naniteFactory: 1, .shipyard: 1],
        researchLevels: [.espionage: 1]
    )

    requireEqual(
        QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &unaccelerated, kind: .solarPlant),
        .queued,
        "Unaccelerated building should queue"
    )
    requireEqual(
        QueueEngine.startShipBuild(on: queuePlanetID(), in: &unaccelerated, kind: .espionageProbe, quantity: 4),
        .queued,
        "Unaccelerated ship build should queue"
    )
    requireEqual(
        QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &accelerated, kind: .solarPlant),
        .queued,
        "Accelerated building should queue"
    )
    requireEqual(
        QueueEngine.startShipBuild(on: queuePlanetID(), in: &accelerated, kind: .espionageProbe, quantity: 4),
        .queued,
        "Accelerated ship build should queue"
    )

    let baseBuildingDuration = unaccelerated.planets[0].buildQueue[0].finishTime -
        unaccelerated.planets[0].buildQueue[0].startTime
    let acceleratedBuildingDuration = accelerated.planets[0].buildQueue[0].finishTime -
        accelerated.planets[0].buildQueue[0].startTime
    let baseShipDuration = unaccelerated.planets[0].shipBuildQueue[0].finishTime -
        unaccelerated.planets[0].shipBuildQueue[0].startTime
    let acceleratedShipDuration = accelerated.planets[0].shipBuildQueue[0].finishTime -
        accelerated.planets[0].shipBuildQueue[0].startTime

    require(acceleratedBuildingDuration < baseBuildingDuration, "Robotics and nanite should shorten building durations")
    require(acceleratedShipDuration < baseShipDuration, "Robotics and nanite should shorten shipyard durations")
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

    requireApproxEqual(planet.energy.produced, 79.86, "Economy energy recomputation should derive produced energy from current building levels")
    requireApproxEqual(planet.energy.used, 68.2, "Economy energy recomputation should derive used energy from current building levels")
}

func testDeuteriumProductionUsesPlanetTemperature() {
    let playerID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c1")!)
    let warmPlanet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c2")!),
        name: "Warm Deuterium",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
        ownerID: playerID,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        temperatureCelsius: 40,
        buildingLevels: [.deuteriumSynthesizer: 1, .solarPlant: 8]
    )
    let coldPlanet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c3")!),
        name: "Cold Deuterium",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 12),
        ownerID: playerID,
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        temperatureCelsius: -40,
        buildingLevels: [.deuteriumSynthesizer: 1, .solarPlant: 8]
    )

    let warmProduction = EconomyEngine.productionPerHour(for: warmPlanet, ruleSet: .fastSkirmish)
    let coldProduction = EconomyEngine.productionPerHour(for: coldPlanet, ruleSet: .fastSkirmish)

    requireApproxEqual(warmProduction.deuterium, 52.8, "Warm baseline should preserve the current fast deuterium curve")
    requireApproxEqual(coldProduction.deuterium, 59.84, "Colder planets should produce more deuterium")
    require(coldProduction.deuterium > warmProduction.deuterium, "Cold planet deuterium should exceed warm planet deuterium")
}

func testSolarSatellitesProduceTemperatureBasedEnergy() {
    var planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c4")!),
        name: "Orbital Solar",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 4),
        ownerID: queuePlayerID(),
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        temperatureCelsius: 40,
        shipInventory: [.solarSatellite: 3]
    )

    EconomyEngine.recomputeEnergy(for: &planet, ruleSet: .fastSkirmish)

    requireApproxEqual(planet.energy.produced, 90, "Solar satellites should produce server-shaped temperature-based energy")
    requireApproxEqual(planet.energy.used, 0, "Solar satellites should not consume energy")
}

func testFusionReactorProducesEnergyAndConsumesDeuteriumWithEnergyTechnology() {
    var planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000c5")!),
        name: "Fusion Core",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 8),
        ownerID: queuePlayerID(),
        resources: ResourceBundle(deuterium: 1_000),
        storage: ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000),
        buildingLevels: [.fusionReactor: 2]
    )
    let research = ResearchState(levels: [.energy: 5])

    EconomyEngine.recomputeEnergy(for: &planet, ruleSet: .fastSkirmish, research: research)
    let production = EconomyEngine.productionPerHour(for: planet, ruleSet: .fastSkirmish, research: research)

    requireApproxEqual(planet.energy.produced, 69.4575, "Fusion reactor should scale with energy technology")
    requireApproxEqual(planet.energy.used, 0, "Fusion reactor should not use mine energy")
    requireApproxEqual(production.deuterium, -96.8, "Fusion reactor should consume deuterium as fuel")
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

    requireApproxEqual(universe.planets[0].resources, ResourceBundle(metal: 212, crystal: 40, deuterium: 0), "Owned planet should produce resources")
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

func testSimulationDomainOnlyPolicySuppressesRoutineTickEvents() {
    let playerID = FactionID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!)
    let planet = Planet(
        id: PlanetID(UUID(uuidString: "00000000-0000-0000-0000-0000000000b9")!),
        name: "Realtime Mine",
        coordinate: Coordinate(galaxy: 1, system: 1, position: 12),
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

    SimulationEngine.tick(universe: &universe, delta: 60, eventPolicy: .domainOnly)

    requireEqual(universe.gameTime, 60, "Domain-only tick should still advance game time")
    requireApproxEqual(universe.planets[0].resources.metal, 212 / 60, "Domain-only tick should still produce resources")
    requireEqual(universe.events, [], "Domain-only tick should suppress routine economy and system events")
}

func testSimulationDomainOnlyPolicyPreservesCompletionEvents() {
    var universe = makeQueueUniverse(resources: ResourceBundle(metal: 10_000, crystal: 10_000, deuterium: 10_000))
    requireEqual(
        QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &universe, kind: .metalMine),
        .queued,
        "Building queue should start before domain-only completion test"
    )

    let finishTime = universe.planets[0].buildQueue[0].finishTime
    SimulationEngine.tick(universe: &universe, delta: finishTime, eventPolicy: .domainOnly)

    requireEqual(universe.planets[0].buildingLevels[.metalMine], 1, "Domain-only tick should still complete queued buildings")
    requireEqual(universe.events.map(\.title), ["Construction Complete"], "Domain-only tick should preserve meaningful domain events")
}

func testSimulationSilentPolicySuppressesGeneratedEventsButKeepsStateChanges() {
    var universe = makeQueueUniverse(resources: ResourceBundle(metal: 10_000, crystal: 10_000, deuterium: 10_000))
    requireEqual(
        QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &universe, kind: .metalMine),
        .queued,
        "Building queue should start before silent policy test"
    )

    let finishTime = universe.planets[0].buildQueue[0].finishTime
    SimulationEngine.tick(universe: &universe, delta: finishTime, eventPolicy: .silent)

    requireEqual(universe.planets[0].buildingLevels[.metalMine], 1, "Silent tick should still mutate simulation state")
    requireEqual(universe.events, [], "Silent tick should suppress all generated events")
}

func testRealtimeFrameInitializesClockWithoutAdvancing() {
    var universe = makeQueueUniverse()
    var state = RealtimeSimulationState()
    let now = Date(timeIntervalSince1970: 1_000)

    let result = RealtimeSimulationEngine.advanceFrame(
        universe: &universe,
        state: &state,
        now: now,
        settings: GameSettings()
    )

    requireEqual(result.didAdvance, false, "First realtime frame should not advance the simulation")
    requireEqual(result.simulatedDelta, 0, "First realtime frame should report zero simulated delta")
    requireEqual(state.lastFrameDate, now, "First realtime frame should store the wall-clock timestamp")
    requireEqual(universe.gameTime, 0, "First realtime frame should leave game time unchanged")
}

func testRealtimeFrameAdvancesByElapsedWallClockAtOneX() {
    var universe = makeQueueUniverse()
    var state = RealtimeSimulationState(lastFrameDate: Date(timeIntervalSince1970: 1_000))

    let result = RealtimeSimulationEngine.advanceFrame(
        universe: &universe,
        state: &state,
        now: Date(timeIntervalSince1970: 1_012),
        settings: GameSettings(gameSpeed: 1)
    )

    requireEqual(result.didAdvance, true, "Realtime frame should report advancement")
    requireEqual(result.wallClockElapsed, 12, "Realtime frame should expose raw wall-clock elapsed time")
    requireEqual(result.appliedWallClockElapsed, 12, "Realtime frame should apply unclamped short elapsed time")
    requireEqual(result.simulatedDelta, 12, "1x realtime frame should apply elapsed seconds directly")
    requireEqual(universe.gameTime, 12, "1x realtime frame should advance game time by elapsed seconds")
}

func testRealtimeFrameAppliesGameSpeedMultiplier() {
    var universe = makeQueueUniverse()
    var state = RealtimeSimulationState(lastFrameDate: Date(timeIntervalSince1970: 1_000))

    let result = RealtimeSimulationEngine.advanceFrame(
        universe: &universe,
        state: &state,
        now: Date(timeIntervalSince1970: 1_010),
        settings: GameSettings(gameSpeed: 4)
    )

    requireEqual(result.simulatedDelta, 40, "Realtime frame should multiply elapsed time by game speed")
    requireEqual(universe.gameTime, 40, "Realtime frame should advance by speed-adjusted delta")
}

func testRealtimeFrameDoesNotAdvanceWhilePaused() {
    var universe = makeQueueUniverse()
    let now = Date(timeIntervalSince1970: 1_025)
    var state = RealtimeSimulationState(lastFrameDate: Date(timeIntervalSince1970: 1_000))

    let result = RealtimeSimulationEngine.advanceFrame(
        universe: &universe,
        state: &state,
        now: now,
        settings: GameSettings(gameSpeed: 8),
        isPaused: true
    )

    requireEqual(result.didAdvance, false, "Paused realtime frame should not advance")
    requireEqual(result.simulatedDelta, 0, "Paused realtime frame should report zero simulated delta")
    requireEqual(state.lastFrameDate, now, "Paused realtime frame should refresh last frame time to avoid catch-up on resume")
    requireEqual(universe.gameTime, 0, "Paused realtime frame should leave game time unchanged")
}

func testRealtimeFrameIgnoresBackwardWallClockTime() {
    let lastDate = Date(timeIntervalSince1970: 1_000)
    var universe = makeQueueUniverse()
    var state = RealtimeSimulationState(lastFrameDate: lastDate)

    let result = RealtimeSimulationEngine.advanceFrame(
        universe: &universe,
        state: &state,
        now: Date(timeIntervalSince1970: 990),
        settings: GameSettings()
    )

    requireEqual(result.didAdvance, false, "Backward realtime frame should not advance")
    requireEqual(state.lastFrameDate, lastDate, "Backward realtime frame should keep the previous valid timestamp")
    requireEqual(universe.gameTime, 0, "Backward realtime frame should leave game time unchanged")
}

func testRealtimeFrameClampsLargeWallClockElapsedBeforeSpeedMultiplier() {
    var universe = makeQueueUniverse()
    var state = RealtimeSimulationState(lastFrameDate: Date(timeIntervalSince1970: 1_000))

    let result = RealtimeSimulationEngine.advanceFrame(
        universe: &universe,
        state: &state,
        now: Date(timeIntervalSince1970: 1_120),
        settings: GameSettings(gameSpeed: 2),
        maximumWallClockElapsed: 30
    )

    requireEqual(result.wallClockElapsed, 120, "Realtime frame should expose raw large elapsed time")
    requireEqual(result.appliedWallClockElapsed, 30, "Realtime frame should clamp large wall-clock elapsed time")
    requireEqual(result.simulatedDelta, 60, "Realtime frame should apply speed after wall-clock clamp")
    requireEqual(universe.gameTime, 60, "Realtime frame should advance by clamped speed-adjusted delta")
}

func testRealtimeFrameUsesDomainOnlyEventPolicy() {
    var universe = makeQueueUniverse(resources: ResourceBundle(metal: 10_000, crystal: 10_000, deuterium: 10_000))
    requireEqual(
        QueueEngine.startBuildingUpgrade(on: queuePlanetID(), in: &universe, kind: .metalMine),
        .queued,
        "Building queue should start before realtime event-policy test"
    )
    let finishTime = universe.planets[0].buildQueue[0].finishTime
    var state = RealtimeSimulationState(lastFrameDate: Date(timeIntervalSince1970: 1_000))

    let result = RealtimeSimulationEngine.advanceFrame(
        universe: &universe,
        state: &state,
        now: Date(timeIntervalSince1970: 1_000 + finishTime),
        settings: GameSettings()
    )

    requireEqual(result.simulatedDelta, finishTime, "Realtime frame should advance to the queued finish time")
    requireEqual(universe.events.map(\.title), ["Construction Complete"], "Realtime frame should preserve domain events without routine tick spam")
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

    requireApproxEqual(universe.planets[0].resources.metal, 212, "Offline catch-up should produce owned-planet resources")
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

func testOfflineCatchUpPreservesVictoryEventAndDoesNotRepeatIt() {
    var universe = makeStrategicUniverse(
        neutralPlanetCount: 3,
        playerResources: ResourceBundle(metal: 120_000, crystal: 80_000, deuterium: 40_000)
    )
    let firstSummary = OfflineSimulationEngine.catchUp(
        universe: &universe,
        elapsed: 60,
        now: Date(timeIntervalSince1970: 7_000)
    )

    requireEqual(firstSummary.recordedEventCount, 2, "Offline catch-up should retain victory event plus summary")
    requireEqual(universe.events.filter { $0.kind == .victory }.count, 1, "Offline catch-up should preserve victory event")
    requireEqual(universe.events.last?.title, "Offline Catch-Up Complete", "Offline catch-up should still append final summary")
    requireEqual(universe.victoryState.didAnnounceVictory, true, "Preserved victory event should match announced state")

    _ = OfflineSimulationEngine.catchUp(
        universe: &universe,
        elapsed: 60,
        now: Date(timeIntervalSince1970: 7_060)
    )
    SimulationEngine.tick(universe: &universe, delta: 60)

    requireEqual(universe.events.filter { $0.kind == .victory }.count, 1, "Later catch-up and ticks should not repeat preserved victory event")
}

func testOfflineCatchUpOneDayWithAIAndFleetsUsesBoundedChunksAndSummarizedFeed() {
    var universe = makeCombatUniverse()
    universe.ruleSet = fastSkirmishRules(offlineChunkInterval: 300)
    universe.planets[0].resources = ResourceBundle(metal: 150_000, crystal: 100_000, deuterium: 80_000)
    universe.planets[0].shipInventory = [.lightFighter: 8, .smallCargo: 2]
    universe.planets[1].resources = ResourceBundle(metal: 20_000, crystal: 10_000, deuterium: 4_000)
    universe.planets[1].buildingLevels = [.metalMine: 1, .crystalMine: 1, .solarPlant: 2]

    let launch = FleetEngine.launchFleet(
        from: fleetPlanetID(1),
        to: fleetPlanetID(2),
        in: &universe,
        mission: .attack,
        ships: [.lightFighter: 8, .smallCargo: 2],
        cargo: .zero
    )
    guard case .launched = launch else {
        fatalError("Stress fixture should launch an attack fleet before offline catch-up")
    }

    let preCatchUpEventCount = universe.events.count
    let summary = OfflineSimulationEngine.catchUp(
        universe: &universe,
        elapsed: 86_400,
        now: Date(timeIntervalSince1970: 86_400)
    )

    requireEqual(summary.elapsedSeconds, 86_400, "One-day catch-up should process exactly twenty-four hours")
    requireEqual(summary.processedChunks, 288, "One-day catch-up should stay bounded to five-minute chunks")
    requireEqual(universe.gameTime, 86_410, "One-day catch-up should preserve initial game time and advance by the capped day")
    requireEqual(universe.fleets, [], "One-day catch-up should resolve outbound combat and returning fleet phases")
    require(universe.reports.contains { $0.kind == .battle }, "One-day fleet catch-up should preserve generated battle reports")
    let aiPlanet = requirePlanet(fleetPlanetID(2), in: universe, "AI planet should remain after one-day catch-up")
    require(
        aiPlanet.buildingLevels.values.reduce(0, +) > 4,
        "One-day catch-up should run AI economy decisions through completed upgrades"
    )
    requireEqual(universe.victoryState.winningFactionID, fleetPlayerID(), "One-day catch-up should allow victory to trigger")
    requireEqual(universe.events.filter { $0.kind == .victory }.count, 1, "One-day catch-up should preserve one victory event")
    requireEqual(universe.events.last?.title, "Offline Catch-Up Complete", "One-day catch-up should append one summary event")
    require(
        universe.events.count <= preCatchUpEventCount + 2,
        "One-day catch-up should summarize generated feed events instead of retaining every chunk"
    )
    require(
        summary.generatedEventCount > summary.recordedEventCount,
        "One-day catch-up summary should expose that generated events were squashed"
    )

    SimulationEngine.tick(universe: &universe, delta: 60)
    requireEqual(universe.gameTime, 86_470, "Simulation should continue after one-day offline victory")
    requireEqual(universe.events.filter { $0.kind == .victory }.count, 1, "Post-victory simulation should not repeat victory events")
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

func testBalanceScenarioReachesFirstFleetWithinTargetWindow() {
    let result = BalanceScenarioRunner.run(
        seed: 1,
        duration: 14_400,
        settings: GameSettings(difficulty: .standard)
    )

    guard let firstShipAt = result.firstShipAt,
          let firstFleetLaunchAt = result.firstFleetLaunchAt
    else {
        fatalError("Balance scenario should record first ship and first fleet launch")
    }

    require(firstShipAt >= 600 && firstShipAt <= 1_500, "First ship should land in the 10-25 minute target window")
    require(firstFleetLaunchAt >= 1_200 && firstFleetLaunchAt <= 2_700, "First fleet launch should land in the 20-45 minute target window")
}

func testBalanceScenarioReachesFirstConflictWithinTargetWindow() {
    let result = BalanceScenarioRunner.run(
        seed: 1,
        duration: 14_400,
        settings: GameSettings(difficulty: .standard)
    )

    guard let firstCombatAt = result.firstCombatAt else {
        fatalError("Balance scenario should record first combat")
    }

    require(firstCombatAt >= 2_700 && firstCombatAt <= 5_400, "First conflict should land in the 45-90 minute target window")
}

func testBalanceScenarioVictoryOccursWithinFastRunWindow() {
    let result = BalanceScenarioRunner.run(
        seed: 1,
        duration: 14_400,
        settings: GameSettings(difficulty: .standard)
    )

    guard let victoryAt = result.victoryAt else {
        fatalError("Balance scenario should record a fast-skirmish victory")
    }

    require(victoryAt >= 7_200 && victoryAt <= 14_400, "Fast skirmish victory should occur in 2-4 hours")
    require(result.finalRankings.isEmpty == false, "Balance scenario should return final rankings")
}

func testBalanceScenarioIncludesEspionageAndAIPressure() {
    let standard = BalanceScenarioRunner.run(
        seed: 1,
        duration: 14_400,
        settings: GameSettings(difficulty: .standard)
    )
    let hard = BalanceScenarioRunner.run(
        seed: 1,
        duration: 14_400,
        settings: GameSettings(difficulty: .hard)
    )

    guard let firstEspionageAt = standard.firstEspionageAt else {
        fatalError("Balance scenario should record first espionage")
    }

    require(firstEspionageAt >= 1_800 && firstEspionageAt <= 4_500, "First espionage should become a natural 30-75 minute action")
    require(hard.aiAttackCount > 0, "Hard balance scenario should include at least one AI pressure attack")
    if let hardVictoryAt = hard.victoryAt {
        require(hardVictoryAt >= 7_200, "Hard AI pressure should not end the fast session before the two-hour victory window")
    }
}

func testBalanceScenarioTouchesMoonLoopWithinFastRunWindow() {
    let result = BalanceScenarioRunner.run(
        seed: 1,
        duration: 14_400,
        settings: GameSettings(difficulty: .standard)
    )

    guard let firstMoonAt = result.firstMoonAt,
          let firstMoonActionAt = result.firstMoonActionAt
    else {
        fatalError("Balance scenario should record moon creation and a moon action")
    }

    require(firstMoonAt >= 6_000 && firstMoonAt <= 12_000, "Fast run should surface a moon before the late victory stretch")
    require(firstMoonActionAt >= firstMoonAt && firstMoonActionAt <= 14_400, "Fast run should use the moon after it appears")
}

try testEntityIDsAreCodableAndEquatable()
testResourceBundleClampsToStorageLimits()
testResourceBundleDoesNotClampBelowZeroWhenStorageIsInvalid()
testResourceBundleArithmeticAndAffordabilityHelpers()
testResourceStorageConvertsToResourceDisplayBundle()
testFastSkirmishBuildingRulesCoverEarlyEconomy()
testFastSkirmishResearchRulesCoverEarlyTechnologies()
testFastSkirmishUnitRulesCoverShipsAndDefenses()
testFastSkirmishLateGameRulesIncludeExpandedShipsAndInterceptors()
testFastSkirmishMoonFacilityRulesExposeLateGameRequirements()
testGameContentUsesChineseDisplayNames()
testGameContentExplainsBuildingAndTechnologyEffects()
testTechnologyEffectsExposeFleetSlotsAndDriveSpeed()
testResearchLabSpeedsResearchDuration()
try testFleetDecodesMissingSpeedPercentAsFullSpeed()
try testFleetCommanderIDDefaultsWhenDecodingOlderFleetJSON()
testAutomationPolicyDefaultsToBalancedEconomySafeMode()
testAutoUpgradeEconomyStrategyFillsMultipleBuildQueueItems()
testAutoUpgradeFleetStrategyCanBuildShipsWhenAllowed()
testAutoUpgradeRespectsResourceReserveRatio()
try testRuleSetBalanceRulesUseRawValueKeyedJSONObjects()
try testRuleSetDecodesOlderJSONWithFastSkirmishBalanceDefaults()
try testBuildQueueItemRoundTripsThroughJSON()
try testResearchQueueItemRoundTripsThroughJSON()
try testUnitBuildQueueItemRoundTripsThroughJSON()
try testPlanetFactionAndUniverseQueuesRoundTripThroughJSON()
try testQueueFieldsDefaultWhenDecodingOlderUniverseJSON()
testQueueFieldsRejectExplicitNullWhenDecodingJSON()
testCommanderRecruitmentUsesTicketsAndTenPullGuarantee()
testCommanderRecruitmentIsDeterministicForSameSeedAndState()
testCommanderRecruitmentClaimsPendingCandidatesIntoRoster()
testCommanderRecruitmentConvertsClaimedDuplicatesToShards()
testCommanderTrainingConsumesDataAndLevelsWithinCap()
testCommanderPromotionConsumesShardsAndRaisesStars()
testFleetLaunchCanAssignAvailableCommanderAndPersistsID()
testAssignedCommanderCannotLeadTwoActiveFleets()
testFleetCommanderSpeedBonusShortensTravelTime()
testBattleSimulationAppliesCommanderAttackBonus()
testAttackMissionGrantsCommanderExperience()
try testUniverseModelRoundTripsThroughJSON()
try testPlanetEnumDictionaryDecodesRawValueKeysAndRejectsUnknownKeys()
testSeededGeneratorProducesDeterministicDistinctSequences()
testSeededGeneratorEqualityTracksSeedAndState()
testSeededGeneratorNextIntRespectsClosedRanges()
try testStarterUniverseIsDeterministicForSeed()
testUniverseTopologyUsesServiceStyleCoordinateLimits()
testUniverseTopologyClassifiesStarMapSlotRolesForDetails()
testUniverseTopologyPlanetProfilesVaryBySlot()
testUniverseTopologyColonySlotProfilesExposeLongTermTradeoffs()
testColonySpecializationClassifiesSlotTradeoffs()
testColonySpecializationPromotesBuiltWorldRolesAndFieldWarnings()
testGameplayAuditAutoplayDoesNotUseGuidedFixtures()
testGameplayAuditAutoplayReachesNaturalFleetLoop()
testVictoryRoutePlansExposeCompositeCheckpoints()
testAIIntentSummariesExposeActionPlans()
testMidgamePlayerObjectivesExposeStrategyDepth()
testStrategicAdvisorRecommendsVictoryRouteAndAIThreat()
testGameplayExpansionRefreshCreatesThreePhaseGameplayLoops()
testGameplayExpansionRewardsCommanderRecruitmentMaterials()
testGameplayExpansionSeedsHostileTargetsWithDefendersAndLoot()
testGameplayExpansionDoesNotResetDamagedActiveHostileTarget()
testGameplayExpansionSkipsHostileSitesWhenNeutralTargetsAreBusy()
testActionChainRewardClaimGrantsResourcesCommanderMaterialsAndPendingDrop()
testActionChainRewardClaimRequiresCompletedSteps()
testClaimedHostileActionChainClearsHostileSiteAndSuppressesRefresh()
testHostileActionChainProgressesFromReportsAndRecoveryEvents()
testActionChainFleetPlannerRecommendsNextHostileMission()
testActionChainFleetPlannerChoosesSufficientHostileStrikeOrigin()
testActionChainFleetPlannerRecommendsAvailableCommanderForHostileStrike()
testActionChainFleetPlannerSizesRecyclerWaveForHostileDebris()
testActionChainFeedbackSummarizesLatestHostileBattleReport()
testClaimedActionChainDoesNotRegenerateOnExpansionRefresh()
testStrategicAdvisorSurfacesExpansionOpportunities()
testStrategicAdvisorSurfacesCommanderRecruitmentAndAssignment()
testGameplayAuditCountsCommanderSignals()
try testGameplayExpansionStateRoundTripsThroughJSON()
testStarterUniverseProvidesServiceStyleColonyPool()
testServiceStyleMoonChanceUsesDebrisThresholdAndCap()
testColonizationAppliesTopologyProfileAndExpeditionSlotCannotBeColonized()
testColonizationTargetEngineSeedsVisibleEmptySlotForFleetPage()
testFleetTargetSelectionSeedsEmptyAndExpeditionSlotsForFleetPage()
testTestingResourceGrantSetsPlayerOwnedPlanetsToInfiniteResources()
testTestingResourceGrantIncludesCommanderRecruitmentAccess()
testPlayerObjectivesAwardRewardsOnce()
testPlayerObjectiveStatesExposeProgressAndCompletedRecords()
testStrategicRankingsScoreFactionStrengthsAndVictoryProgress()
testStrategicVictoryRoutesTriggerForEconomyTechnologyDominationAndExploration()
testLateGameObjectiveContributesToTechnologyVictory()
testSimulationContinuesTickingAfterVictoryWithoutRepeatingVictoryEvent()
try testStrategicStateRoundTripsThroughJSONAndDefaultsWhenMissing()
try testExplorationAndRelationStateRoundTripsAndDefaultsWhenMissing()
testStrategicExplorationRecordsAreFilteredByFaction()
testStrategicRankingsClampInvalidNumericInputs()
testPlayerVisibilityUsesPlanetOwnerAsSourceOfTruth()
testEconomyProductionPerHourUsesMineLevelsAndEnergyRatio()
testEconomyOneHourTickIncreasesOwnedPlanetResources()
testEconomyProductionClampsToStorageCaps()
testEconomyEnergyShortageReducesMineOutput()
testPlanetProductionSettingsScaleMineOutputAndEnergyUse()
testStorageBuildingsIncreaseStorageCaps()
testRoboticsAndNaniteStyleAccelerationShortensBuildDurations()
testEconomyRecomputesSolarEnergyProducedAndMineEnergyUsed()
testDeuteriumProductionUsesPlanetTemperature()
testSolarSatellitesProduceTemperatureBasedEnergy()
testFusionReactorProducesEnergyAndConsumesDeuteriumWithEnergyTechnology()
testEconomyUniverseTickDoesNotProduceOnNonOwnedPlanets()
testQueueEngineStartsBuildingUpgradeAndPaysCost()
testQueueEngineRejectsUnaffordableBuildingAndResearchWithoutMutation()
testQueueEngineAppendsBuildingAndResearchQueues()
testQueueEngineReportsMissingEntitiesAndRulesWithoutMutation()
testQueueEngineRejectsInvalidBuildingRuleValuesWithoutMutation()
testQueueEngineRejectsInvalidResearchDurationWithoutMutation()
testAIEconomyQueuesOneAffordableUpgradePerAIFaction()
testAIEconomyStrategyPrioritiesChooseDistinctEarlyGrowthPaths()
testAIEconomyResearchPreviewUsesQueueEnginePaymentPlanetOrder()
testAIEconomyDoesNotMutatePlayerState()
testPlayerAutoUpgradeQueuesBuildingAndResearchWhenEnabledDuringTick()
testPlayerAutoUpgradeDoesNotQueueWhenDisabled()
testStrategicAdvisorHighlightsEnergyDeficitAndStoragePressure()
testStrategicAdvisorRecommendsDebrisColonyAndExpeditionLoops()
testFleetMissionPlannerSummarizesRecycleValueAndTiming()
testFleetMissionPlannerBlocksMissingRequiredShipsAndFuel()
testFleetMissionPlannerDoesNotRevealHiddenTargetResources()
try testAIEconomyDecisionsAreDeterministicForSameSeedTimeAndState()
testAIStrategyBuildsShipsForRaiderFactions()
testAIStrategyBuildsDefensesForThreatenedFactions()
testAIStrategyDoesNotReadHiddenPlayerFleetState()
testAIRaiderLaunchesEspionageBeforeAttack()
testAIExpansionistColonizesKnownNeutralWorld()
testAIExpansionistSeedsServiceStyleColonizationTargetWhenNoneKnown()
testAIRecyclerCollectsKnownDebris()
testAIAttackUsesKnownWeakTargetOnly()
testOfflineCatchUpCapsAIAggressiveFleetLaunchesByChunkPressure()
testEasyAIDoesNotAttackWithoutReport()
testHardAICanUseRankingsButNotHiddenInventory()
testThreatMemoryChangesDefensivePosture()
testShipBuildRequiresConfiguredTechnologyGate()
testDefenseBuildRequiresConfiguredBuildingGate()
testUIHelpersExposeLockedReason()
try testFastSkirmishRuleSetBackfillsRequirementsWhenDecodingOlderJSON()
testOfflineCatchUpTriggersAIEconomyDecisionsAtBoundedIntervals()
testSimulationTickCompletesBuildingQueueRecomputesEnergyAndRecordsEvent()
testSimulationTickCompletesAlreadyDueConstructionBeforeProduction()
testQueueEngineStartsResearchAndPaysFromOwnedPlanet()
testQueueEngineStartsShipBuildAndCompletesIntoInventory()
testQueueEngineStartsDefenseBuildAndCompletesIntoInventory()
testQueueEngineStartsMissileBuildAndCompletesIntoInventory()
testQueueEngineAppendsUnitQueues()
testQueueEngineRejectsInvalidUnitRulesWithoutMutation()
testQueueCompletionPreservesMismatchedUnitQueueItemsWithoutMutation()
testQueueCompletionPreservesInvalidUnitQuantitiesWithoutMutation()
testFastSkirmishFleetRulesCoverAllShips()
try testLegacyFullShipRulesDecodeWithFleetDefaultsByShipKind()
testFleetLaunchRemovesShipsCargoAndFuelFromOrigin()
testIdenticalFleetLaunchesInSameTickUseDistinctIDs()
testInvalidFleetLaunchFailsWithoutMutation()
testFleetTravelTimeIsDeterministicFromCoordinatesAndSpeedRules()
testSlowerFleetTakesLongerAndUsesLessFuel()
testBattleSimulationProducesAtMostSixRounds()
testBattleSimulationRecordsRapidFireShieldHullAndExplosions()
testFleetLaunchRespectsComputerFleetSlots()
testOutboundFleetCanBeRecalled()
testSensorPhalanxHidesRecalledAndMoonOriginFleets()
testJointAttackCombinesSameOwnerFleetsArrivingTogether()
testSensorPhalanxExposesChaseWindowAndDebrisFleetSaveRisk()
testDefendMissionHoldsAtFriendlyPlanetAndJoinsDefense()
testACSGatheringCanDelayAttackFleetsIntoJointWindow()
testTransportMissionDeliversCargoAndReturnsShips()
testLargeSimulationTickCompletesOutboundArrivalAndReturnTogether()
testTransportOverflowCargoStaysWithReturningFleet()
testReturningFleetDoesNotLoseCargoWhenOriginStorageIsFull()
testRecycleMissionCollectsDebrisFromTargetPlanet()
try testExploreMissionCreatesDeterministicEventAndReward()
testExplorationEventPoolIncludesOGameStyleFindsRisksAndTimingEvents()
testExploreMissionAdvancesStrategicExplorationVictoryThroughSimulationTick()
testExplorationMissionRecordsBoundedDiscoveriesAndFeedsProgress()
testExploreMissionCreatesExplorationReport()
try testEspionageMissionCreatesStableReportWithoutChangingTargetState()
testTransportAndExplorationDoNotShiftFactionRelations()
testAttackShiftsFactionRelationsWithoutHiddenTargetDetails()
testRepeatedAttacksIncrementThreatWithoutDuplicateRelations()
try testFactionRelationsNormalizeDuplicatesOnDecodeAndAttackUpdate()
testAttackMissionCreatesCombatReportLootDebrisAndRecoveredDefense()
testCombatReviewAggregatesBattleRoundsAndInsights()
testCombatReviewExplainsDefenderHoldAndIgnoresNonBattleReports()
testStrongAttackAgainstWeakTargetHasReducedLootAndProtectionSummary()
testMoonChanceCanCreateMoonFromLargeDebrisBattle()
testMissileStrikeDamagesDefensesWithoutLoot()
testAntiBallisticMissilesInterceptIncomingMissiles()
testMissileStrikeRejectsInvalidCoreTargets()
testAttackReturnCargoIsCappedAfterCargoShipLosses()
testAttackWithMissingCombatRulesDoesNotMutateTargetOrCreateUnbalancedReport()
try testAttackMissionIsDeterministicAcrossSaveLoadAndUsesDistinctReportIDs()
testColonizeMissionClaimsUnownedPlanetWhenColonyShipIsPresent()
testFleetReturnsRestoreShipsAndCargoToOrigin()
testSimulationTickResolvesDueFleetArrivalsBeforeSystemEvent()
testSimulationTickCompletesResearchQueueAndRecordsEvent()
try testQueueCompletionIsDeterministicAcrossSaveLoadEquality()
testSimulationTickEmitsAtMostOneEconomySummaryEventPerTick()
testSimulationDomainOnlyPolicySuppressesRoutineTickEvents()
testSimulationDomainOnlyPolicyPreservesCompletionEvents()
testSimulationSilentPolicySuppressesGeneratedEventsButKeepsStateChanges()
testRealtimeFrameInitializesClockWithoutAdvancing()
testRealtimeFrameAdvancesByElapsedWallClockAtOneX()
testRealtimeFrameAppliesGameSpeedMultiplier()
testRealtimeFrameDoesNotAdvanceWhilePaused()
testRealtimeFrameIgnoresBackwardWallClockTime()
testRealtimeFrameClampsLargeWallClockElapsedBeforeSpeedMultiplier()
testRealtimeFrameUsesDomainOnlyEventPolicy()
testSimulationTickAdvancesGameTimeAndRecordsEvent()
testSimulationTickIgnoresNonPositiveDeltas()
testSimulationTickIgnoresNonFiniteDeltas()
testSimulationTickAcceptsHugeFinitePositiveDeltas()
testOfflineCatchUpUsesBoundedChunksAndMinimumChunkInterval()
testOfflineCatchUpProducesResourcesWithoutFloodingEvents()
testOfflineCatchUpCompletesQueuesAndSummarizesCompletionCounts()
testOfflineCatchUpCompletesUnitQueuesAndSummarizesConstructionCounts()
testOfflineCatchUpPreservesVictoryEventAndDoesNotRepeatIt()
testOfflineCatchUpOneDayWithAIAndFleetsUsesBoundedChunksAndSummarizedFeed()
testOfflineCatchUpIgnoresInvalidElapsedValues()
testOfflineCatchUpCapsHugeElapsedValuesToOneDay()
try testOfflineCatchUpSummaryIsCodableEquatableAndDeterministic()
testBalanceScenarioReachesFirstFleetWithinTargetWindow()
testBalanceScenarioReachesFirstConflictWithinTargetWindow()
testBalanceScenarioVictoryOccursWithinFastRunWindow()
testBalanceScenarioIncludesEspionageAndAIPressure()
testBalanceScenarioTouchesMoonLoopWithinFastRunWindow()
print("OGameCoreTests passed")
