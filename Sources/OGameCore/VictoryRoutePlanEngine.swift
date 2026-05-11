public struct VictoryRouteCheckpoint: Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case scoreThreshold
        case colonyNetwork
        case stableEnergy
        case specialization
        case researchDepth
        case combatTechnology
        case driveTechnology
        case moonInfrastructure
        case territoryShare
        case combatFleet
        case defensiveLine
        case battleExperience
        case surveyCoverage
        case expeditionLoop
        case debrisRecovery
    }

    public var kind: Kind
    public var title: String
    public var detail: String
    public var currentValue: Double
    public var targetValue: Double

    public var id: Kind { kind }

    public var progress: Double {
        guard targetValue.isFinite, targetValue > 0 else {
            return 0
        }
        return min(max(currentValue / targetValue, 0), 1)
    }

    public var isComplete: Bool {
        progress >= 1
    }

    public init(kind: Kind, title: String, detail: String, currentValue: Double, targetValue: Double) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.currentValue = currentValue.isFinite ? max(currentValue, 0) : 0
        self.targetValue = targetValue.isFinite ? max(targetValue, 1) : 1
    }
}

public struct VictoryRoutePlan: Equatable, Identifiable, Sendable {
    public var route: VictoryRoute
    public var title: String
    public var checkpoints: [VictoryRouteCheckpoint]

    public var id: VictoryRoute { route }

    public var completedCheckpointCount: Int {
        checkpoints.filter(\.isComplete).count
    }

    public var progress: Double {
        guard !checkpoints.isEmpty else {
            return 0
        }
        return Double(completedCheckpointCount) / Double(checkpoints.count)
    }

    public var nextCheckpoint: VictoryRouteCheckpoint? {
        checkpoints.first { !$0.isComplete }
    }

    public init(route: VictoryRoute, title: String, checkpoints: [VictoryRouteCheckpoint]) {
        self.route = route
        self.title = title
        self.checkpoints = checkpoints
    }
}

public enum VictoryRoutePlanEngine {
    public static func plans(for factionID: FactionID, in universe: Universe) -> [VictoryRoutePlan] {
        VictoryRoute.allCases.map { plan(for: $0, factionID: factionID, in: universe) }
    }

    public static func bestPlan(for factionID: FactionID, in universe: Universe) -> VictoryRoutePlan? {
        plans(for: factionID, in: universe)
            .sorted { lhs, rhs in
                if lhs.progress != rhs.progress {
                    return lhs.progress > rhs.progress
                }
                return routeOrder(lhs.route) < routeOrder(rhs.route)
            }
            .first
    }

    private static func plan(for route: VictoryRoute, factionID: FactionID, in universe: Universe) -> VictoryRoutePlan {
        let faction = universe.factions.first { $0.id == factionID }
        let ownedPlanets = universe.planets.filter { $0.ownerID == factionID }
        let neutralPlanets = universe.planets.filter { $0.ownerID == nil }
        let exploredNeutralCount = StrategicEngine.explorationRecords(for: factionID, in: universe)
            .filter { record in neutralPlanets.contains { $0.id == record.targetPlanetID } }
            .count

        switch route {
        case .economy:
            return VictoryRoutePlan(
                route: route,
                title: "经济路线",
                checkpoints: [
                    checkpoint(.scoreThreshold, "经济体量", "总经济分达到快节奏胜利门槛。", economyScore(ownedPlanets, ruleSet: universe.ruleSet), 20_000),
                    checkpoint(.colonyNetwork, "殖民网络", "至少拥有 3 个可分工星球。", Double(ownedPlanets.count), 3),
                    checkpoint(.stableEnergy, "能源稳定", "所有玩家星球能源不为负。", Double(stableEnergyPlanetCount(ownedPlanets, faction: faction, ruleSet: universe.ruleSet)), Double(max(ownedPlanets.count, 1))),
                    checkpoint(.specialization, "殖民分工", "至少 2 个星球形成明确专精。", Double(specializedPlanetCount(ownedPlanets)), 2)
                ]
            )
        case .technology:
            let technologyLevels = faction?.technology.levels ?? [:]
            return VictoryRoutePlan(
                route: route,
                title: "科技路线",
                checkpoints: [
                    checkpoint(.researchDepth, "科研总量", "累计科技等级达到 24。", Double(technologyLevels.values.reduce(0) { $0 + max($1, 0) }), 24),
                    checkpoint(.combatTechnology, "战斗科技", "武器、护盾、装甲合计达到 9。", Double(combatTechnologyLevel(technologyLevels)), 9),
                    checkpoint(.driveTechnology, "引擎体系", "三类引擎合计达到 6。", Double(driveTechnologyLevel(technologyLevels)), 6),
                    checkpoint(.moonInfrastructure, "月面设施", "拥有月球或月球设施，进入后期舰队体系。", Double(ownedPlanets.filter { $0.moon != nil }.count), 1)
                ]
            )
        case .domination:
            let inhabitedCount = max(universe.planets.filter { $0.ownerID != nil }.count, 1)
            return VictoryRoutePlan(
                route: route,
                title: "统治路线",
                checkpoints: [
                    checkpoint(.territoryShare, "星域占比", "拥有至少 75% 已居住星球。", Double(ownedPlanets.count) / Double(inhabitedCount), 0.75),
                    checkpoint(.combatFleet, "主力舰队", "至少 10 艘战斗舰可用于压制。", Double(combatShipCount(ownedPlanets)), 10),
                    checkpoint(.defensiveLine, "防线成型", "拥有至少 12 个防御单位。", Double(defenseCount(ownedPlanets)), 12),
                    checkpoint(.battleExperience, "战斗经验", "至少产生一份战斗报告。", Double(battleReportCount(for: factionID, in: universe)), 1)
                ]
            )
        case .exploration:
            return VictoryRoutePlan(
                route: route,
                title: "探索路线",
                checkpoints: [
                    checkpoint(.surveyCoverage, "星图覆盖", "探索全部已知中立目标。", Double(exploredNeutralCount), Double(max(neutralPlanets.count, 1))),
                    checkpoint(.expeditionLoop, "远征循环", "至少产生 3 条探索记录。", Double(StrategicEngine.explorationRecords(for: factionID, in: universe).count), 3),
                    checkpoint(.debrisRecovery, "残骸利用", "拥有回收船或完成残骸回收。", Double(hasRecyclerOrRecycleReport(factionID: factionID, ownedPlanets: ownedPlanets, universe: universe) ? 1 : 0), 1),
                    checkpoint(.colonyNetwork, "外域落点", "至少拥有 2 个星球。", Double(ownedPlanets.count), 2)
                ]
            )
        }
    }

    private static func checkpoint(
        _ kind: VictoryRouteCheckpoint.Kind,
        _ title: String,
        _ detail: String,
        _ current: Double,
        _ target: Double
    ) -> VictoryRouteCheckpoint {
        VictoryRouteCheckpoint(kind: kind, title: title, detail: detail, currentValue: current, targetValue: target)
    }

    private static func economyScore(_ planets: [Planet], ruleSet: RuleSet) -> Double {
        planets.reduce(0) { total, planet in
            let buildingScore = planet.buildingLevels.values.reduce(0) { $0 + (Double(max($1, 0)) * 100) }
            let stockpileScore = (planet.resources.metal + planet.resources.crystal + planet.resources.deuterium) * 0.1
            let production = EconomyEngine.productionPerHour(for: planet, ruleSet: ruleSet)
            let productionScore = production.metal + production.crystal + production.deuterium
            return total + buildingScore + max(stockpileScore, 0) + max(productionScore, 0)
        }
    }

    private static func stableEnergyPlanetCount(_ planets: [Planet], faction: Faction?, ruleSet: RuleSet) -> Int {
        planets.filter { planet in
            EconomyEngine.energyState(for: planet, ruleSet: ruleSet, research: faction?.technology ?? ResearchState()).available >= 0
        }.count
    }

    private static func specializedPlanetCount(_ planets: [Planet]) -> Int {
        planets.filter { planet in
            let role = ColonySpecializationEngine.specialization(for: planet).role
            return role != .marginalColony
        }.count
    }

    private static func combatTechnologyLevel(_ levels: [TechnologyKind: Int]) -> Int {
        [.weapons, .shielding, .armor].reduce(0) { $0 + max(levels[$1] ?? 0, 0) }
    }

    private static func driveTechnologyLevel(_ levels: [TechnologyKind: Int]) -> Int {
        [.combustionDrive, .impulseDrive, .hyperspaceDrive].reduce(0) { $0 + max(levels[$1] ?? 0, 0) }
    }

    private static func combatShipCount(_ planets: [Planet]) -> Int {
        planets.reduce(0) { total, planet in
            total + planet.shipInventory.reduce(0) { partial, element in
                partial + (isCombatShip(element.key) ? max(element.value, 0) : 0)
            }
        }
    }

    private static func defenseCount(_ planets: [Planet]) -> Int {
        planets.reduce(0) { $0 + $1.defenseInventory.values.reduce(0) { $0 + max($1, 0) } }
    }

    private static func battleReportCount(for factionID: FactionID, in universe: Universe) -> Int {
        universe.reports.filter { report in
            report.kind == .battle && report.participants.contains { $0.factionID == factionID }
        }.count
    }

    private static func hasRecyclerOrRecycleReport(factionID: FactionID, ownedPlanets: [Planet], universe: Universe) -> Bool {
        ownedPlanets.contains { ($0.shipInventory[.recycler] ?? 0) > 0 } ||
            universe.reports.contains { report in
                report.participants.contains { $0.factionID == factionID } && report.summary.localizedCaseInsensitiveContains("recycle")
            }
    }

    private static func isCombatShip(_ kind: ShipKind) -> Bool {
        switch kind {
        case .lightFighter, .heavyFighter, .cruiser, .battleship, .battlecruiser, .bomber, .destroyer, .deathstar:
            return true
        case .smallCargo, .largeCargo, .colonyShip, .recycler, .espionageProbe, .solarSatellite:
            return false
        }
    }

    private static func routeOrder(_ route: VictoryRoute) -> Int {
        VictoryRoute.allCases.firstIndex(of: route) ?? Int.max
    }
}
