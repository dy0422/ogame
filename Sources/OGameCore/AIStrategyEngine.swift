import Foundation

public enum AIStrategyEngine {
    public static func makeStrategicDecisions(in universe: inout Universe) {
        let aiFactions = universe.factions
            .filter { $0.kind == .ai && $0.id != universe.playerFactionID }
            .sorted(by: compareFactions)

        for faction in aiFactions {
            makeProductionDecisions(for: faction, in: &universe)
        }
    }

    private static func makeProductionDecisions(for faction: Faction, in universe: inout Universe) {
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
        in universe: inout Universe
    ) {
        guard threatScore > 0,
              let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == faction.id }),
              planet.defenseBuildQueue.isEmpty,
              normalizedLevel(planet.buildingLevels[.shipyard] ?? 0) > 0
        else {
            return
        }

        for kind in preferredDefenses(for: faction.strategy, threatScore: threatScore) {
            guard canAffordDefense(kind, quantity: 1, on: planet, ruleSet: universe.ruleSet) else {
                continue
            }

            if QueueEngine.startDefenseBuild(on: planetID, in: &universe, kind: kind, quantity: 1) == .queued {
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

    private static func compareFactions(_ lhs: Faction, _ rhs: Faction) -> Bool {
        lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }

    private static func comparePlanets(_ lhs: Planet, _ rhs: Planet) -> Bool {
        lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }
}
