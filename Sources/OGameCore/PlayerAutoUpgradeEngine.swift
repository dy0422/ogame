import Foundation

public struct PlayerAutoUpgradeResult: Equatable, Sendable {
    public var queuedBuildings: Int
    public var queuedResearch: Int
    public var queuedShips: Int
    public var queuedDefenses: Int
    public var queuedMissiles: Int

    public var didQueue: Bool {
        queuedBuildings > 0 || queuedResearch > 0 || queuedShips > 0 || queuedDefenses > 0 || queuedMissiles > 0
    }

    public init(
        queuedBuildings: Int = 0,
        queuedResearch: Int = 0,
        queuedShips: Int = 0,
        queuedDefenses: Int = 0,
        queuedMissiles: Int = 0
    ) {
        self.queuedBuildings = queuedBuildings
        self.queuedResearch = queuedResearch
        self.queuedShips = queuedShips
        self.queuedDefenses = queuedDefenses
        self.queuedMissiles = queuedMissiles
    }
}

public enum PlayerAutoUpgradeEngine {
    @discardableResult
    public static func makeDecisions(
        in universe: inout Universe,
        policy: AutoUpgradePolicy = AutoUpgradePolicy()
    ) -> PlayerAutoUpgradeResult {
        guard let player = universe.factions.first(where: { $0.id == universe.playerFactionID }) else {
            return PlayerAutoUpgradeResult()
        }

        var result = PlayerAutoUpgradeResult()
        let shouldQueueShipsFirst = policy.allowShipConstruction && shouldQueueShipsBeforeInfrastructure(
            for: player,
            policy: policy,
            in: universe
        )
        if shouldQueueShipsFirst {
            result.queuedShips += queueShips(for: player, policy: policy, in: &universe)
        }

        result.queuedBuildings += queueBuildings(for: player, policy: policy, in: &universe)
        result.queuedResearch += queueResearch(for: player, policy: policy, in: &universe)
        if policy.allowShipConstruction && !shouldQueueShipsFirst {
            result.queuedShips += queueShips(for: player, policy: policy, in: &universe)
        }
        if policy.allowDefenseConstruction {
            result.queuedDefenses += queueDefenses(for: player, policy: policy, in: &universe)
        }
        if policy.allowMissileConstruction {
            result.queuedMissiles += queueMissiles(for: player, policy: policy, in: &universe)
        }

        return result
    }

    private static func queueBuildings(
        for player: Faction,
        policy: AutoUpgradePolicy,
        in universe: inout Universe
    ) -> Int {
        var queued = 0
        for planetID in player.ownedPlanetIDs {
            guard let planetIndex = universe.planets.firstIndex(where: { $0.id == planetID && $0.ownerID == player.id }),
                  universe.planets[planetIndex].buildQueue.count < policy.maxBuildQueueDepthPerPlanet
            else {
                continue
            }

            let priorities = buildingPriorities(
                for: universe.planets[planetIndex],
                player: player,
                ruleSet: universe.ruleSet,
                strategy: policy.strategy
            )
            let reserveForFirstShip = shouldReserveForFirstShip(
                for: player,
                policy: policy,
                in: universe
            )
            while universe.planets[planetIndex].buildQueue.count < policy.maxBuildQueueDepthPerPlanet {
                var didQueue = false
                for kind in priorities where universe.ruleSet.buildingRules[kind] != nil && !kind.isMoonFacility {
                    guard shouldQueueBuilding(
                        kind,
                        on: universe.planets[planetIndex],
                        player: player,
                        ruleSet: universe.ruleSet,
                        strategy: policy.strategy,
                        reserveForFirstShip: reserveForFirstShip
                    ) else {
                        continue
                    }

                    guard let cost = QueueEngine.buildingUpgradeCost(on: planetID, in: universe, kind: kind),
                          canSpend(
                            cost,
                            from: universe.planets[planetIndex].resources,
                            reserveRatio: policy.resourceReserveRatio
                          )
                    else {
                        continue
                    }

                    if QueueEngine.startBuildingUpgrade(on: planetID, in: &universe, kind: kind) == .queued {
                        queued += 1
                        didQueue = true
                        break
                    }
                }

                if !didQueue {
                    break
                }
            }
        }

        return queued
    }

    private static func shouldQueueShipsBeforeInfrastructure(
        for player: Faction,
        policy: AutoUpgradePolicy,
        in universe: Universe
    ) -> Bool {
        switch policy.strategy {
        case .fleet:
            return true
        case .balanced:
            return ownedShipCount(for: player, in: universe) == 0
        case .economy, .research, .defense, .lowRiskOffline:
            return false
        }
    }

    private static func shouldReserveForFirstShip(
        for player: Faction,
        policy: AutoUpgradePolicy,
        in universe: Universe
    ) -> Bool {
        policy.allowShipConstruction &&
            shouldQueueShipsBeforeInfrastructure(for: player, policy: policy, in: universe) &&
            ownedShipCount(for: player, in: universe) == 0
    }

    private static func ownedShipCount(for player: Faction, in universe: Universe) -> Int {
        player.ownedPlanetIDs.reduce(0) { total, planetID in
            guard let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == player.id }) else {
                return total
            }

            let inventoryCount = planet.shipInventory.values.reduce(0) { $0 + max($1, 0) }
            let queuedCount = planet.shipBuildQueue.reduce(0) { $0 + max($1.quantity, 0) }
            return total + inventoryCount + queuedCount
        }
    }

    private static func shouldQueueBuilding(
        _ kind: BuildingKind,
        on planet: Planet,
        player: Faction,
        ruleSet: RuleSet,
        strategy: AutoUpgradeStrategy,
        reserveForFirstShip: Bool
    ) -> Bool {
        let energy = EconomyEngine.energyState(for: planet, ruleSet: ruleSet, research: player.technology)
        if energy.available < 0 && (kind == .solarPlant || kind == .fusionReactor) {
            return true
        }

        if reserveForFirstShip && firstShipReserveFoundationMet(on: planet) {
            return false
        }

        let targets = foundationTargets(for: strategy)
        guard !targets.isEmpty else {
            return true
        }

        if let target = targets[kind], projectedBuildingLevel(kind, on: planet) < target {
            return true
        }

        return foundationTargetsMet(targets, on: planet)
    }

    private static func foundationTargetsMet(_ targets: [BuildingKind: Int], on planet: Planet) -> Bool {
        targets.allSatisfy { kind, target in
            projectedBuildingLevel(kind, on: planet) >= max(target, 0)
        }
    }

    private static func firstShipReserveFoundationMet(on planet: Planet) -> Bool {
        let targets: [BuildingKind: Int] = [.metalMine: 2, .crystalMine: 2, .solarPlant: 3]
        return foundationTargetsMet(targets, on: planet)
    }

    private static func foundationTargets(for strategy: AutoUpgradeStrategy) -> [BuildingKind: Int] {
        switch strategy {
        case .balanced:
            return [.metalMine: 4, .crystalMine: 4, .deuteriumSynthesizer: 2, .solarPlant: 5, .roboticsFactory: 1, .shipyard: 1, .researchLab: 1]
        case .economy:
            return [.metalMine: 6, .crystalMine: 5, .deuteriumSynthesizer: 3, .solarPlant: 6, .roboticsFactory: 1, .shipyard: 1, .researchLab: 1]
        case .research:
            return [.metalMine: 4, .crystalMine: 4, .deuteriumSynthesizer: 2, .solarPlant: 5, .roboticsFactory: 1, .shipyard: 1, .researchLab: 2]
        case .fleet:
            return [.metalMine: 4, .crystalMine: 4, .deuteriumSynthesizer: 2, .solarPlant: 5, .roboticsFactory: 1, .shipyard: 2, .researchLab: 1]
        case .defense:
            return [.metalMine: 4, .crystalMine: 3, .deuteriumSynthesizer: 2, .solarPlant: 5, .roboticsFactory: 1, .shipyard: 2]
        case .lowRiskOffline:
            return [.metalMine: 4, .crystalMine: 3, .deuteriumSynthesizer: 2, .solarPlant: 5, .roboticsFactory: 1, .shipyard: 1]
        }
    }

    private static func projectedBuildingLevel(_ kind: BuildingKind, on planet: Planet) -> Int {
        let currentLevel = kind.isMoonFacility
            ? normalizedLevel(planet.moon?.buildingLevels[kind] ?? 0)
            : normalizedLevel(planet.buildingLevels[kind] ?? 0)
        let queuedLevel = planet.buildQueue
            .filter { $0.buildingKind == kind }
            .map { normalizedLevel($0.targetLevel) }
            .max() ?? currentLevel

        return max(currentLevel, queuedLevel)
    }

    private static func queueResearch(for player: Faction, policy: AutoUpgradePolicy, in universe: inout Universe) -> Int {
        guard hasResearchLab(for: player, in: universe) else {
            return 0
        }

        var queued = 0
        while researchQueueDepth(for: player.id, in: universe) < policy.maxResearchQueueDepth {
            var didQueue = false
            for technology in researchPriorities(for: policy.strategy) where universe.ruleSet.researchRules[technology] != nil {
                guard let cost = QueueEngine.researchCost(for: player.id, in: universe, technology: technology),
                      let resources = researchPaymentResources(for: player, in: universe),
                      canSpend(cost, from: resources, reserveRatio: policy.resourceReserveRatio)
                else {
                    continue
                }

                if QueueEngine.startResearch(for: player.id, in: &universe, technology: technology) == .queued {
                    queued += 1
                    didQueue = true
                    break
                }
            }

            if !didQueue {
                break
            }
        }

        return queued
    }

    private static func buildingPriorities(
        for planet: Planet,
        player: Faction,
        ruleSet: RuleSet,
        strategy: AutoUpgradeStrategy
    ) -> [BuildingKind] {
        let energy = EconomyEngine.energyState(for: planet, ruleSet: ruleSet, research: player.technology)
        if energy.available < 0 {
            return [
                .solarPlant,
                .fusionReactor,
                .metalMine,
                .crystalMine,
                .deuteriumSynthesizer,
                .roboticsFactory,
                .researchLab,
                .shipyard,
                .metalStorage,
                .crystalStorage,
                .deuteriumTank,
                .naniteFactory,
                .missileSilo
            ]
        }

        switch strategy {
        case .economy:
            return [.metalMine, .crystalMine, .deuteriumSynthesizer, .solarPlant, .fusionReactor, .metalStorage, .crystalStorage, .deuteriumTank, .roboticsFactory, .researchLab, .shipyard, .naniteFactory, .missileSilo]
        case .research:
            return [.researchLab, .solarPlant, .fusionReactor, .crystalMine, .deuteriumSynthesizer, .metalMine, .roboticsFactory, .naniteFactory, .shipyard, .metalStorage, .crystalStorage, .deuteriumTank, .missileSilo]
        case .fleet:
            return [.shipyard, .roboticsFactory, .solarPlant, .fusionReactor, .metalMine, .crystalMine, .deuteriumSynthesizer, .researchLab, .naniteFactory, .metalStorage, .crystalStorage, .deuteriumTank, .missileSilo]
        case .defense, .lowRiskOffline:
            return [.solarPlant, .metalMine, .crystalMine, .deuteriumSynthesizer, .shipyard, .missileSilo, .metalStorage, .crystalStorage, .deuteriumTank, .roboticsFactory, .researchLab, .fusionReactor, .naniteFactory]
        case .balanced:
            return [.metalMine, .crystalMine, .solarPlant, .deuteriumSynthesizer, .researchLab, .roboticsFactory, .shipyard, .fusionReactor, .metalStorage, .crystalStorage, .deuteriumTank, .naniteFactory, .missileSilo]
        }
    }

    private static func queueShips(for player: Faction, policy: AutoUpgradePolicy, in universe: inout Universe) -> Int {
        var queued = 0
        for planetID in player.ownedPlanetIDs {
            guard let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == player.id }),
                  planet.shipBuildQueue.isEmpty
            else {
                continue
            }

            for ship in shipPriorities(for: policy.strategy) {
                guard let cost = QueueEngine.shipBuildCost(on: planetID, in: universe, kind: ship, quantity: 1),
                      canSpend(cost, from: planet.resources, reserveRatio: policy.resourceReserveRatio)
                else {
                    continue
                }

                if QueueEngine.startShipBuild(on: planetID, in: &universe, kind: ship, quantity: 1) == .queued {
                    queued += 1
                    break
                }
            }
        }

        return queued
    }

    private static func queueDefenses(for player: Faction, policy: AutoUpgradePolicy, in universe: inout Universe) -> Int {
        var queued = 0
        for planetID in player.ownedPlanetIDs {
            guard let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == player.id }),
                  planet.defenseBuildQueue.isEmpty
            else {
                continue
            }

            for defense in defensePriorities(for: policy.strategy) {
                guard let cost = QueueEngine.defenseBuildCost(on: planetID, in: universe, kind: defense, quantity: 1),
                      canSpend(cost, from: planet.resources, reserveRatio: policy.resourceReserveRatio)
                else {
                    continue
                }

                if QueueEngine.startDefenseBuild(on: planetID, in: &universe, kind: defense, quantity: 1) == .queued {
                    queued += 1
                    break
                }
            }
        }

        return queued
    }

    private static func queueMissiles(for player: Faction, policy: AutoUpgradePolicy, in universe: inout Universe) -> Int {
        var queued = 0
        for planetID in player.ownedPlanetIDs {
            guard let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == player.id }),
                  planet.defenseBuildQueue.isEmpty
            else {
                continue
            }

            for missile in missilePriorities(for: policy.strategy) {
                guard let cost = QueueEngine.missileBuildCost(on: planetID, in: universe, kind: missile, quantity: 1),
                      canSpend(cost, from: planet.resources, reserveRatio: policy.resourceReserveRatio)
                else {
                    continue
                }

                if QueueEngine.startMissileBuild(on: planetID, in: &universe, kind: missile, quantity: 1) == .queued {
                    queued += 1
                    break
                }
            }
        }

        return queued
    }

    private static func hasResearchLab(for player: Faction, in universe: Universe) -> Bool {
        player.ownedPlanetIDs.contains { planetID in
            guard let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == player.id }) else {
                return false
            }

            return max(planet.buildingLevels[.researchLab] ?? 0, 0) > 0
        }
    }

    private static func researchQueueDepth(for playerID: FactionID, in universe: Universe) -> Int {
        universe.factions.first { $0.id == playerID }?.researchQueue.count ?? 0
    }

    private static func researchPaymentResources(for player: Faction, in universe: Universe) -> ResourceBundle? {
        for planetID in player.ownedPlanetIDs {
            if let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == player.id }) {
                return planet.resources
            }
        }

        return nil
    }

    private static func canSpend(_ cost: ResourceBundle, from resources: ResourceBundle, reserveRatio: Double) -> Bool {
        let reserve = resources.scaled(by: min(max(reserveRatio, 0), 0.8))
        return resources.subtracting(reserve).canAfford(cost)
    }

    private static func normalizedLevel(_ level: Int) -> Int {
        max(level, 0)
    }

    private static func researchPriorities(for strategy: AutoUpgradeStrategy) -> [TechnologyKind] {
        switch strategy {
        case .research:
            return [.computer, .energy, .espionage, .astrophysics, .impulseDrive, .hyperspaceDrive, .weapons, .shielding, .armor, .combustionDrive]
        case .fleet:
            return [.combustionDrive, .impulseDrive, .weapons, .armor, .shielding, .computer, .espionage, .astrophysics, .energy, .hyperspaceDrive]
        case .defense, .lowRiskOffline:
            return [.energy, .weapons, .shielding, .armor, .computer, .espionage, .astrophysics, .combustionDrive, .impulseDrive, .hyperspaceDrive]
        case .economy, .balanced:
            return [.energy, .computer, .espionage, .astrophysics, .combustionDrive, .impulseDrive, .weapons, .shielding, .armor, .hyperspaceDrive]
        }
    }

    private static func shipPriorities(for strategy: AutoUpgradeStrategy) -> [ShipKind] {
        switch strategy {
        case .fleet:
            return [.smallCargo, .lightFighter, .espionageProbe, .recycler, .colonyShip, .heavyFighter, .cruiser]
        case .lowRiskOffline:
            return [.smallCargo, .recycler, .espionageProbe]
        default:
            return [.smallCargo, .espionageProbe, .lightFighter, .recycler, .colonyShip]
        }
    }

    private static func defensePriorities(for strategy: AutoUpgradeStrategy) -> [DefenseKind] {
        switch strategy {
        case .defense, .lowRiskOffline:
            return [.rocketLauncher, .lightLaser, .heavyLaser, .ionCannon, .gaussCannon, .plasmaTurret]
        default:
            return [.rocketLauncher, .lightLaser, .heavyLaser]
        }
    }

    private static func missilePriorities(for strategy: AutoUpgradeStrategy) -> [MissileKind] {
        strategy == .defense || strategy == .lowRiskOffline
            ? [.antiBallisticMissile, .interplanetaryMissile]
            : [.antiBallisticMissile]
    }
}
