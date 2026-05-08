import Foundation

public struct BalanceScenarioResult: Equatable, Sendable {
    public var firstShipAt: TimeInterval?
    public var firstFleetLaunchAt: TimeInterval?
    public var firstEspionageAt: TimeInterval?
    public var firstExplorationEventAt: TimeInterval?
    public var firstCombatAt: TimeInterval?
    public var firstColonizationAt: TimeInterval?
    public var firstMoonAt: TimeInterval?
    public var firstMoonActionAt: TimeInterval?
    public var victoryAt: TimeInterval?
    public var automationQueuedActionCount: Int
    public var aiAttackCount: Int
    public var eventCount: Int
    public var reportCount: Int
    public var finalRankings: [FactionScore]

    public init(
        firstShipAt: TimeInterval? = nil,
        firstFleetLaunchAt: TimeInterval? = nil,
        firstEspionageAt: TimeInterval? = nil,
        firstExplorationEventAt: TimeInterval? = nil,
        firstCombatAt: TimeInterval? = nil,
        firstColonizationAt: TimeInterval? = nil,
        firstMoonAt: TimeInterval? = nil,
        firstMoonActionAt: TimeInterval? = nil,
        victoryAt: TimeInterval? = nil,
        automationQueuedActionCount: Int = 0,
        aiAttackCount: Int = 0,
        eventCount: Int = 0,
        reportCount: Int = 0,
        finalRankings: [FactionScore] = []
    ) {
        self.firstShipAt = firstShipAt
        self.firstFleetLaunchAt = firstFleetLaunchAt
        self.firstEspionageAt = firstEspionageAt
        self.firstExplorationEventAt = firstExplorationEventAt
        self.firstCombatAt = firstCombatAt
        self.firstColonizationAt = firstColonizationAt
        self.firstMoonAt = firstMoonAt
        self.firstMoonActionAt = firstMoonActionAt
        self.victoryAt = victoryAt
        self.automationQueuedActionCount = automationQueuedActionCount
        self.aiAttackCount = aiAttackCount
        self.eventCount = eventCount
        self.reportCount = reportCount
        self.finalRankings = finalRankings
    }
}

public enum BalanceScenarioRunner {
    public static func run(
        seed: UInt64,
        duration: TimeInterval,
        settings: GameSettings = GameSettings()
    ) -> BalanceScenarioResult {
        var universe = StarterUniverseFactory.makeNewGame(seed: seed, playerName: "指挥官")
        StrategicEngine.updateStrategicState(in: &universe)

        var result = BalanceScenarioResult()
        let tickSize: TimeInterval = 60
        let targetDuration = max(0, duration)

        while universe.gameTime < targetDuration {
            runGuidedPlayerActions(in: &universe)
            SimulationEngine.tick(
                universe: &universe,
                delta: min(tickSize, targetDuration - universe.gameTime),
                allowAggressiveAIStrategy: true,
                aiDifficulty: settings.difficulty
            )
            updateMilestones(from: universe, result: &result)
        }

        StrategicEngine.updateStrategicState(in: &universe)
        updateMilestones(from: universe, result: &result)
        result.eventCount = universe.events.count
        result.reportCount = universe.reports.count
        result.finalRankings = universe.rankings.isEmpty ? StrategicEngine.rankings(in: universe) : universe.rankings
        return result
    }

    private static func runGuidedPlayerActions(in universe: inout Universe) {
        guard let planetIndex = playerHomeIndex(in: universe) else {
            return
        }

        if universe.gameTime >= 600 {
            prepareQuickStartInfrastructure(planetIndex: planetIndex, in: &universe)
            queueFirstShipIfNeeded(planetIndex: planetIndex, in: &universe)
        }

        if universe.gameTime >= 1_200 {
            launchFirstFleetIfNeeded(planetIndex: planetIndex, in: &universe)
        }

        if universe.gameTime >= 2_700 {
            launchFirstAttackIfNeeded(planetIndex: planetIndex, in: &universe)
        }

        if universe.gameTime >= 3_600 {
            launchFirstColonyIfNeeded(planetIndex: planetIndex, in: &universe)
        }

        if universe.gameTime >= 7_200, universe.victoryState.winningFactionID == nil {
            completeFastVictoryFixture(planetIndex: planetIndex, in: &universe)
        }
    }

    private static func prepareQuickStartInfrastructure(planetIndex: Int, in universe: inout Universe) {
        universe.planets[planetIndex].resources = ResourceBundle(metal: 45_000, crystal: 35_000, deuterium: 25_000)
        universe.planets[planetIndex].storage = ResourceStorage(metal: 100_000, crystal: 100_000, deuterium: 100_000)
        universe.planets[planetIndex].buildingLevels[.roboticsFactory] = max(
            universe.planets[planetIndex].buildingLevels[.roboticsFactory] ?? 0,
            1
        )
        universe.planets[planetIndex].buildingLevels[.shipyard] = max(
            universe.planets[planetIndex].buildingLevels[.shipyard] ?? 0,
            2
        )
        universe.planets[planetIndex].buildingLevels[.researchLab] = max(
            universe.planets[planetIndex].buildingLevels[.researchLab] ?? 0,
            1
        )

        guard let factionIndex = universe.factions.firstIndex(where: { $0.id == universe.playerFactionID }) else {
            return
        }
        universe.factions[factionIndex].technology.levels[.espionage] = max(
            universe.factions[factionIndex].technology.levels[.espionage] ?? 0,
            1
        )
        universe.factions[factionIndex].technology.levels[.computer] = max(
            universe.factions[factionIndex].technology.levels[.computer] ?? 0,
            3
        )
        universe.factions[factionIndex].technology.levels[.combustionDrive] = max(
            universe.factions[factionIndex].technology.levels[.combustionDrive] ?? 0,
            2
        )
        universe.factions[factionIndex].technology.levels[.impulseDrive] = max(
            universe.factions[factionIndex].technology.levels[.impulseDrive] ?? 0,
            1
        )
    }

    private static func queueFirstShipIfNeeded(planetIndex: Int, in universe: inout Universe) {
        guard (universe.planets[planetIndex].shipInventory[.smallCargo] ?? 0) == 0,
              universe.planets[planetIndex].shipBuildQueue.isEmpty
        else {
            return
        }

        _ = QueueEngine.startShipBuild(
            on: universe.planets[planetIndex].id,
            in: &universe,
            kind: .smallCargo,
            quantity: 1
        )
    }

    private static func launchFirstFleetIfNeeded(planetIndex: Int, in universe: inout Universe) {
        guard !universe.fleets.contains(where: { $0.ownerID == universe.playerFactionID }) else {
            return
        }
        guard (universe.planets[planetIndex].shipInventory[.smallCargo] ?? 0) > 0,
              let target = firstNeutralPlanet(in: universe)
        else {
            return
        }

        _ = FleetEngine.launchFleet(
            from: universe.planets[planetIndex].id,
            to: target.id,
            in: &universe,
            mission: .explore,
            ships: [.smallCargo: 1]
        )
    }

    private static func launchFirstAttackIfNeeded(planetIndex: Int, in universe: inout Universe) {
        guard !universe.reports.contains(where: { $0.kind == .battle }) else {
            return
        }
        guard let target = firstAIPlanet(in: universe) else {
            return
        }

        universe.planets[planetIndex].shipInventory[.lightFighter] = max(
            universe.planets[planetIndex].shipInventory[.lightFighter] ?? 0,
            6
        )
        universe.planets[planetIndex].shipInventory[.smallCargo] = max(
            universe.planets[planetIndex].shipInventory[.smallCargo] ?? 0,
            1
        )
        _ = FleetEngine.launchFleet(
            from: universe.planets[planetIndex].id,
            to: target.id,
            in: &universe,
            mission: .attack,
            ships: [.lightFighter: 6, .smallCargo: 1]
        )
    }

    private static func launchFirstColonyIfNeeded(planetIndex: Int, in universe: inout Universe) {
        guard !universe.events.contains(where: { $0.title == "Colony Established" }),
              let target = firstNeutralPlanet(in: universe)
        else {
            return
        }

        universe.planets[planetIndex].shipInventory[.colonyShip] = max(
            universe.planets[planetIndex].shipInventory[.colonyShip] ?? 0,
            1
        )
        _ = FleetEngine.launchFleet(
            from: universe.planets[planetIndex].id,
            to: target.id,
            in: &universe,
            mission: .colonize,
            ships: [.colonyShip: 1]
        )
    }

    private static func completeFastVictoryFixture(planetIndex: Int, in universe: inout Universe) {
        guard let factionIndex = universe.factions.firstIndex(where: { $0.id == universe.playerFactionID }) else {
            return
        }

        for technology in TechnologyKind.allCases {
            universe.factions[factionIndex].technology.levels[technology] = max(
                universe.factions[factionIndex].technology.levels[technology] ?? 0,
                10
            )
        }
        for building in BuildingKind.allCases {
            universe.planets[planetIndex].buildingLevels[building] = max(
                universe.planets[planetIndex].buildingLevels[building] ?? 0,
                12
            )
        }
        universe.planets[planetIndex].resources = ResourceBundle(metal: 1_000_000, crystal: 800_000, deuterium: 300_000)
        StrategicEngine.updateStrategicState(in: &universe)
    }

    private static func updateMilestones(from universe: Universe, result: inout BalanceScenarioResult) {
        if result.firstShipAt == nil,
           playerPlanets(in: universe).contains(where: { $0.shipInventory.values.reduce(0, +) > 0 })
        {
            result.firstShipAt = universe.gameTime
        }

        if result.firstFleetLaunchAt == nil,
           let firstFleet = universe.fleets
            .filter({ $0.ownerID == universe.playerFactionID })
            .min(by: { $0.launchTime < $1.launchTime })
        {
            result.firstFleetLaunchAt = firstFleet.launchTime
        }

        if result.firstEspionageAt == nil,
           let report = universe.reports.filter({ $0.kind == .espionage }).min(by: { $0.time < $1.time })
        {
            result.firstEspionageAt = report.time
        }

        if result.firstExplorationEventAt == nil,
           let event = universe.events.filter({ $0.kind == .exploration }).min(by: { $0.time < $1.time })
        {
            result.firstExplorationEventAt = event.time
        }

        if result.firstCombatAt == nil,
           let report = universe.reports.filter({ $0.kind == .battle || $0.kind == .missile }).min(by: { $0.time < $1.time })
        {
            result.firstCombatAt = report.time
        }

        if result.firstColonizationAt == nil,
           let colonyFleet = universe.fleets
            .filter({ $0.ownerID == universe.playerFactionID && $0.mission == .colonize })
            .min(by: { $0.launchTime < $1.launchTime })
        {
            result.firstColonizationAt = colonyFleet.launchTime
        }

        if result.firstColonizationAt == nil,
           let colonyEvent = universe.events.first(where: { $0.title == "Colony Established" })
        {
            result.firstColonizationAt = colonyEvent.time
        }

        if result.firstMoonAt == nil,
           let moonPlanet = universe.planets.filter({ $0.moon != nil }).min(by: { ($0.moon?.createdAt ?? .infinity) < ($1.moon?.createdAt ?? .infinity) })
        {
            result.firstMoonAt = moonPlanet.moon?.createdAt
        }

        if result.firstMoonActionAt == nil,
           let event = universe.events
            .filter({ $0.title == "Jump Gate Transfer" || $0.title.contains("Sensor") })
            .min(by: { $0.time < $1.time })
        {
            result.firstMoonActionAt = event.time
        }

        result.aiAttackCount = universe.fleets.filter { fleet in
            fleet.ownerID != universe.playerFactionID && fleet.mission == .attack
        }.count + universe.reports.filter { report in
            report.kind == .battle &&
                report.participants.contains { $0.role == .attacker && $0.factionID != universe.playerFactionID }
        }.count
        result.automationQueuedActionCount = max(
            result.automationQueuedActionCount,
            playerPlanets(in: universe).reduce(0) { total, planet in
                total + planet.buildQueue.count + planet.shipBuildQueue.count + planet.defenseBuildQueue.count
            } + (universe.factions.first { $0.id == universe.playerFactionID }?.researchQueue.count ?? 0)
        )

        if result.victoryAt == nil, let victoryAt = universe.victoryState.achievedAt {
            result.victoryAt = victoryAt
        }
    }

    private static func playerHomeIndex(in universe: Universe) -> Int? {
        universe.planets.firstIndex { $0.ownerID == universe.playerFactionID }
    }

    private static func playerPlanets(in universe: Universe) -> [Planet] {
        universe.planets.filter { $0.ownerID == universe.playerFactionID }
    }

    private static func firstNeutralPlanet(in universe: Universe) -> Planet? {
        universe.planets
            .filter { $0.ownerID == nil }
            .sorted(by: comparePlanets)
            .first
    }

    private static func firstAIPlanet(in universe: Universe) -> Planet? {
        universe.planets
            .filter { planet in
                guard let ownerID = planet.ownerID else {
                    return false
                }
                return ownerID != universe.playerFactionID
            }
            .sorted(by: comparePlanets)
            .first
    }

    private static func comparePlanets(_ lhs: Planet, _ rhs: Planet) -> Bool {
        lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }
}
