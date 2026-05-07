import Foundation

public enum AIStrategyEngine {
    public static func makeStrategicDecisions(
        in universe: inout Universe,
        allowAggressiveMissions: Bool = true,
        policy: AIDifficultyPolicy = .standard
    ) {
        let aiFactions = universe.factions
            .filter { $0.kind == .ai && $0.id != universe.playerFactionID }
            .sorted(by: compareFactions)

        for faction in aiFactions {
            makeProductionDecisions(for: faction, policy: policy, in: &universe)
            if allowAggressiveMissions {
                launchStrategicFleetIfNeeded(for: faction, policy: policy, in: &universe)
            }
        }
    }

    private static func makeProductionDecisions(
        for faction: Faction,
        policy: AIDifficultyPolicy,
        in universe: inout Universe
    ) {
        let planets = ownedPlanets(for: faction, in: universe)
        guard !planets.isEmpty else {
            return
        }

        let threatScore = faction.relations.reduce(0) { $0 + max($1.threatScore, 0) }
        let knownNeutralTargetCount = StrategicEngine.explorationRecords(for: faction.id, in: universe)
            .filter(\.discoveredNeutral)
            .count

        for planet in planets {
            if threatScore > 0 {
                queueDefenseProduction(
                    for: faction,
                    planetID: planet.id,
                    threatScore: threatScore,
                    policy: policy,
                    in: &universe
                )
            }

            queueShipProduction(
                for: faction,
                planetID: planet.id,
                knownNeutralTargetCount: knownNeutralTargetCount,
                in: &universe
            )
        }
    }

    private static func queueShipProduction(
        for faction: Faction,
        planetID: PlanetID,
        knownNeutralTargetCount: Int,
        in universe: inout Universe
    ) {
        guard let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == faction.id }),
              planet.shipBuildQueue.isEmpty,
              normalizedLevel(planet.buildingLevels[.shipyard] ?? 0) > 0
        else {
            return
        }

        for kind in preferredShips(for: faction.strategy, knownNeutralTargetCount: knownNeutralTargetCount) {
            guard canAffordShip(kind, quantity: 1, on: planet, ruleSet: universe.ruleSet) else {
                continue
            }

            if QueueEngine.startShipBuild(on: planetID, in: &universe, kind: kind, quantity: 1) == .queued {
                return
            }
        }
    }

    private static func queueDefenseProduction(
        for faction: Faction,
        planetID: PlanetID,
        threatScore: Int,
        policy: AIDifficultyPolicy,
        in universe: inout Universe
    ) {
        guard threatScore > 0,
              let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == faction.id }),
              planet.defenseBuildQueue.isEmpty,
              normalizedLevel(planet.buildingLevels[.shipyard] ?? 0) > 0
        else {
            return
        }

        let quantity = policy.defenseBuildQuantity(forThreatScore: threatScore)
        for kind in preferredDefenses(for: faction.strategy, threatScore: threatScore) {
            guard canAffordDefense(kind, quantity: quantity, on: planet, ruleSet: universe.ruleSet) else {
                continue
            }

            if QueueEngine.startDefenseBuild(on: planetID, in: &universe, kind: kind, quantity: quantity) == .queued {
                return
            }
        }
    }

    private static func preferredShips(
        for strategy: Faction.Strategy,
        knownNeutralTargetCount: Int
    ) -> [ShipKind] {
        switch strategy {
        case .raider:
            return [.lightFighter, .smallCargo, .espionageProbe]
        case .expansionist:
            if knownNeutralTargetCount > 0 {
                return [.colonyShip, .smallCargo, .espionageProbe]
            }
            return [.smallCargo, .espionageProbe]
        case .technologist:
            return [.espionageProbe, .smallCargo]
        case .balanced:
            return [.smallCargo, .lightFighter, .espionageProbe]
        case .miner:
            return [.smallCargo, .espionageProbe]
        }
    }

    private static func preferredDefenses(
        for strategy: Faction.Strategy,
        threatScore: Int
    ) -> [DefenseKind] {
        switch strategy {
        case .miner:
            return threatScore > 3 ? [.rocketLauncher, .lightLaser] : [.rocketLauncher]
        case .balanced, .technologist, .expansionist:
            return [.rocketLauncher, .lightLaser]
        case .raider:
            return [.lightLaser, .rocketLauncher]
        }
    }

    private static func launchStrategicFleetIfNeeded(
        for faction: Faction,
        policy: AIDifficultyPolicy,
        in universe: inout Universe
    ) {
        guard !hasActiveFleet(for: faction.id, in: universe) else {
            return
        }

        if launchRecyclerFleet(for: faction, in: &universe) {
            return
        }

        if faction.strategy == .expansionist, launchColonizationFleet(for: faction, in: &universe) {
            return
        }

        if launchAttackFleet(for: faction, policy: policy, in: &universe) {
            return
        }

        if launchEspionageFleet(for: faction, in: &universe) {
            return
        }
    }

    private static func launchRecyclerFleet(for faction: Faction, in universe: inout Universe) -> Bool {
        let records = StrategicEngine.explorationRecords(for: faction.id, in: universe)
            .filter { resourceTotal($0.discoveredDebris) > 0 }
            .sorted(by: compareExplorationRecords)

        for record in records {
            guard let origin = firstOrigin(for: faction, requiring: [.recycler: 1], in: universe),
                  let target = universe.planets.first(where: { $0.id == record.targetPlanetID }),
                  resourceTotal(target.debrisField) > 0
            else {
                continue
            }

            if case .launched = FleetEngine.launchFleet(
                from: origin.id,
                to: target.id,
                in: &universe,
                mission: .recycle,
                ships: [.recycler: 1]
            ) {
                return true
            }
        }

        return false
    }

    private static func launchColonizationFleet(for faction: Faction, in universe: inout Universe) -> Bool {
        let records = StrategicEngine.explorationRecords(for: faction.id, in: universe)
            .filter(\.discoveredNeutral)
            .sorted(by: compareExplorationRecords)

        for record in records {
            guard let origin = firstOrigin(for: faction, requiring: [.colonyShip: 1], in: universe),
                  let target = universe.planets.first(where: { $0.id == record.targetPlanetID && $0.ownerID == nil })
            else {
                continue
            }

            if case .launched = FleetEngine.launchFleet(
                from: origin.id,
                to: target.id,
                in: &universe,
                mission: .colonize,
                ships: [.colonyShip: 1]
            ) {
                return true
            }
        }

        return false
    }

    private static func launchAttackFleet(
        for faction: Faction,
        policy: AIDifficultyPolicy,
        in universe: inout Universe
    ) -> Bool {
        let knownTargets = attackTargets(for: faction, policy: policy, in: universe)

        for target in knownTargets {
            guard let origin = attackOrigin(for: faction, in: universe) else {
                return false
            }

            let ships = attackShips(from: origin)
            guard !ships.isEmpty else {
                return false
            }

            if case .launched = FleetEngine.launchFleet(
                from: origin.id,
                to: target.id,
                in: &universe,
                mission: .attack,
                ships: ships
            ) {
                return true
            }
        }

        return false
    }

    private static func launchEspionageFleet(for faction: Faction, in universe: inout Universe) -> Bool {
        let targets = visibleRivalPlanets(for: faction, in: universe)

        for target in targets where latestEspionageReport(for: faction.id, targetPlanetID: target.id, in: universe) == nil {
            guard let origin = firstOrigin(for: faction, requiring: [.espionageProbe: 1], in: universe) else {
                return false
            }

            if case .launched = FleetEngine.launchFleet(
                from: origin.id,
                to: target.id,
                in: &universe,
                mission: .espionage,
                ships: [.espionageProbe: 1]
            ) {
                return true
            }
        }

        return false
    }

    private static func attackTargets(
        for faction: Faction,
        policy: AIDifficultyPolicy,
        in universe: Universe
    ) -> [Planet] {
        let knownTargetIDs = Set(
            StrategicEngine.explorationRecords(for: faction.id, in: universe)
                .filter { $0.discoveredOwnerID != nil && $0.discoveredOwnerID != faction.id }
                .map(\.targetPlanetID)
        )

        let reportTargets = visibleRivalPlanets(for: faction, in: universe)
            .filter { target in
                knownTargetIDs.contains(target.id) &&
                    isKnownWeakTarget(for: faction.id, targetPlanetID: target.id, in: universe)
            }
            .sorted(by: comparePlanets)

        guard reportTargets.isEmpty, policy.allowsRankingBasedAttacks else {
            return reportTargets
        }

        return rankedPressureTargets(for: faction, in: universe)
    }

    private static func rankedPressureTargets(for faction: Faction, in universe: Universe) -> [Planet] {
        guard let attackerScore = universe.rankings.first(where: { $0.factionID == faction.id }) else {
            return []
        }

        let scoreByFactionID = Dictionary(uniqueKeysWithValues: universe.rankings.map { ($0.factionID, $0) })

        return visibleRivalPlanets(for: faction, in: universe)
            .filter { target in
                guard let ownerID = target.ownerID,
                      let defenderScore = scoreByFactionID[ownerID]
                else {
                    return false
                }

                return attackerScore.rank > 0 &&
                    defenderScore.rank > attackerScore.rank &&
                    attackerScore.totalScore >= max(defenderScore.totalScore * 1.5, defenderScore.totalScore + 1_000)
            }
            .sorted(by: comparePlanets)
    }

    private static func visibleRivalPlanets(for faction: Faction, in universe: Universe) -> [Planet] {
        universe.planets
            .filter { planet in
                guard let ownerID = planet.ownerID else {
                    return false
                }

                return ownerID != faction.id
            }
            .sorted(by: comparePlanets)
    }

    private static func isKnownWeakTarget(
        for factionID: FactionID,
        targetPlanetID: PlanetID,
        in universe: Universe
    ) -> Bool {
        guard let report = latestEspionageReport(for: factionID, targetPlanetID: targetPlanetID, in: universe),
              let defender = report.participants.first(where: { $0.role == .defender && $0.planetID == targetPlanetID })
        else {
            return false
        }

        let survivingShips = defender.afterShips.reduce(0) { $0 + max($1.value, 0) }
        let survivingDefenses = defender.afterDefenses.reduce(0) { $0 + max($1.value, 0) }
        return survivingShips + survivingDefenses <= 2
    }

    private static func latestEspionageReport(
        for factionID: FactionID,
        targetPlanetID: PlanetID,
        in universe: Universe
    ) -> Report? {
        universe.reports
            .filter { report in
                report.kind == .espionage &&
                    report.participants.contains { $0.role == .attacker && $0.factionID == factionID } &&
                    report.participants.contains { $0.role == .defender && $0.planetID == targetPlanetID }
            }
            .sorted { lhs, rhs in
                if lhs.time != rhs.time {
                    return lhs.time > rhs.time
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
            .first
    }

    private static func attackOrigin(for faction: Faction, in universe: Universe) -> Planet? {
        ownedPlanets(for: faction, in: universe)
            .first { attackShips(from: $0).isEmpty == false }
    }

    private static func attackShips(from planet: Planet) -> [ShipKind: Int] {
        var ships: [ShipKind: Int] = [:]
        let fighterCount = min(max(planet.shipInventory[.lightFighter] ?? 0, 0), 8)
        let cargoCount = min(max(planet.shipInventory[.smallCargo] ?? 0, 0), 2)
        let heavyCount = fighterCount == 0 ? min(max(planet.shipInventory[.heavyFighter] ?? 0, 0), 4) : 0

        if fighterCount > 0 {
            ships[.lightFighter] = fighterCount
        }
        if cargoCount > 0 {
            ships[.smallCargo] = cargoCount
        }
        if heavyCount > 0 {
            ships[.heavyFighter] = heavyCount
        }

        return ships
    }

    private static func firstOrigin(
        for faction: Faction,
        requiring ships: [ShipKind: Int],
        in universe: Universe
    ) -> Planet? {
        ownedPlanets(for: faction, in: universe)
            .first { planet in
                ships.allSatisfy { kind, quantity in
                    (planet.shipInventory[kind] ?? 0) >= quantity
                }
            }
    }

    private static func hasActiveFleet(for factionID: FactionID, in universe: Universe) -> Bool {
        universe.fleets.contains { fleet in
            fleet.ownerID == factionID && fleet.phase != .completed
        }
    }

    private static func canAffordShip(
        _ kind: ShipKind,
        quantity: Int,
        on planet: Planet,
        ruleSet: RuleSet
    ) -> Bool {
        guard quantity > 0, let rule = ruleSet.shipRules[kind] else {
            return false
        }

        return planet.resources.canAfford(rule.baseCost.scaled(by: Double(quantity)))
    }

    private static func canAffordDefense(
        _ kind: DefenseKind,
        quantity: Int,
        on planet: Planet,
        ruleSet: RuleSet
    ) -> Bool {
        guard quantity > 0, let rule = ruleSet.defenseRules[kind] else {
            return false
        }

        return planet.resources.canAfford(rule.baseCost.scaled(by: Double(quantity)))
    }

    private static func ownedPlanets(for faction: Faction, in universe: Universe) -> [Planet] {
        let ownedIDs = Set(faction.ownedPlanetIDs)

        return universe.planets
            .filter { ownedIDs.contains($0.id) && $0.ownerID == faction.id }
            .sorted(by: comparePlanets)
    }

    private static func normalizedLevel(_ level: Int) -> Int {
        max(level, 0)
    }

    private static func resourceTotal(_ resources: ResourceBundle) -> Double {
        resources.metal + resources.crystal + resources.deuterium
    }

    private static func compareFactions(_ lhs: Faction, _ rhs: Faction) -> Bool {
        lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }

    private static func comparePlanets(_ lhs: Planet, _ rhs: Planet) -> Bool {
        lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }

    private static func compareExplorationRecords(_ lhs: ExplorationRecord, _ rhs: ExplorationRecord) -> Bool {
        if lhs.exploredAt != rhs.exploredAt {
            return lhs.exploredAt > rhs.exploredAt
        }

        return lhs.targetPlanetID.rawValue.uuidString < rhs.targetPlanetID.rawValue.uuidString
    }
}
