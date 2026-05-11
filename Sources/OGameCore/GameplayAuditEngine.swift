import Foundation

public struct GameplayAuditNote: Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case organicPacing
        case earlyFleetBlocked
        case victoryRouteBlocked
        case aiPressure
        case advisorCoverage
    }

    public var kind: Kind
    public var title: String
    public var detail: String

    public var id: Kind { kind }

    public init(kind: Kind, title: String, detail: String) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

public struct GameplayAuditResult: Equatable, Sendable {
    public var usedGuidedFixtures: Bool
    public var balance: BalanceScenarioResult
    public var advisorRecommendationKinds: [StrategicAdvisorRecommendation.Kind]
    public var routePlans: [VictoryRoutePlan]
    public var aiIntents: [AIIntentSummary]
    public var auditNotes: [GameplayAuditNote]

    public init(
        usedGuidedFixtures: Bool,
        balance: BalanceScenarioResult,
        advisorRecommendationKinds: [StrategicAdvisorRecommendation.Kind],
        routePlans: [VictoryRoutePlan],
        aiIntents: [AIIntentSummary],
        auditNotes: [GameplayAuditNote]
    ) {
        self.usedGuidedFixtures = usedGuidedFixtures
        self.balance = balance
        self.advisorRecommendationKinds = advisorRecommendationKinds
        self.routePlans = routePlans
        self.aiIntents = aiIntents
        self.auditNotes = auditNotes
    }
}

public enum GameplayAuditEngine {
    public static func runAutoplayAudit(
        seed: UInt64,
        duration: TimeInterval,
        settings: GameSettings = GameSettings()
    ) -> GameplayAuditResult {
        var universe = StarterUniverseFactory.makeNewGame(seed: seed, playerName: "指挥官")
        var result = BalanceScenarioResult()
        var sampledRecommendationKinds: [StrategicAdvisorRecommendation.Kind] = []
        let tickSize: TimeInterval = 60
        let targetDuration = max(duration, 0)
        let policy = autoplayPolicy(from: settings)

        StrategicEngine.updateStrategicState(in: &universe)

        while universe.gameTime < targetDuration {
            _ = PlayerAutoUpgradeEngine.makeDecisions(in: &universe, policy: policy)
            performAdvisorDrivenFleetAction(in: &universe)
            sampledRecommendationKinds.append(
                contentsOf: StrategicAdvisorEngine.recommendations(in: universe, limit: 4).map(\.kind)
            )
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

        let plans = VictoryRoutePlanEngine.plans(for: universe.playerFactionID, in: universe)
        let aiIntents = AIIntentEngine.intentSummaries(in: universe)
        return GameplayAuditResult(
            usedGuidedFixtures: false,
            balance: result,
            advisorRecommendationKinds: sampledRecommendationKinds.uniqued(),
            routePlans: plans,
            aiIntents: aiIntents,
            auditNotes: notes(for: result, plans: plans, aiIntents: aiIntents, recommendationKinds: sampledRecommendationKinds.uniqued())
        )
    }

    private static func autoplayPolicy(from settings: GameSettings) -> AutoUpgradePolicy {
        var policy = settings.autoUpgradePolicy
        policy.strategy = .fleet
        policy.resourceReserveRatio = 0
        policy.maxBuildQueueDepthPerPlanet = max(1, min(policy.maxBuildQueueDepthPerPlanet, 2))
        policy.maxResearchQueueDepth = 1
        policy.allowShipConstruction = true
        policy.allowDefenseConstruction = false
        policy.allowMissileConstruction = settings.difficulty == .hard
        return policy
    }

    private static func performAdvisorDrivenFleetAction(in universe: inout Universe) {
        guard let origin = playerOrigin(in: universe),
              !universe.fleets.contains(where: { $0.ownerID == universe.playerFactionID && $0.phase != .completed })
        else {
            return
        }

        if (origin.shipInventory[.espionageProbe] ?? 0) > 0,
           !universe.reports.contains(where: { $0.kind == .espionage }),
           let target = firstAIPlanet(in: universe) {
            _ = FleetEngine.launchFleet(from: origin.id, to: target.id, in: &universe, mission: .espionage, ships: [.espionageProbe: 1])
            return
        }

        if (origin.shipInventory[.smallCargo] ?? 0) > 0,
           let target = firstNeutralPlanet(in: universe) {
            _ = FleetEngine.launchFleet(from: origin.id, to: target.id, in: &universe, mission: .explore, ships: [.smallCargo: 1])
            return
        }

        if (origin.shipInventory[.colonyShip] ?? 0) > 0,
           let target = firstNeutralPlanet(in: universe) {
            _ = FleetEngine.launchFleet(from: origin.id, to: target.id, in: &universe, mission: .colonize, ships: [.colonyShip: 1])
            return
        }

        if (origin.shipInventory[.lightFighter] ?? 0) >= 4,
           let target = firstAIPlanet(in: universe),
           !universe.reports.contains(where: { $0.kind == .battle }) {
            _ = FleetEngine.launchFleet(from: origin.id, to: target.id, in: &universe, mission: .attack, ships: [.lightFighter: 4])
        }
    }

    private static func notes(
        for result: BalanceScenarioResult,
        plans: [VictoryRoutePlan],
        aiIntents: [AIIntentSummary],
        recommendationKinds: [StrategicAdvisorRecommendation.Kind]
    ) -> [GameplayAuditNote] {
        var notes = [
            GameplayAuditNote(
                kind: .organicPacing,
                title: "真实推进",
                detail: "本审计只使用自动托管、顾问驱动舰队和常规模拟，不注入剧情舰船、月球或胜利。"
            )
        ]

        if result.firstFleetLaunchAt == nil {
            notes.append(
                GameplayAuditNote(kind: .earlyFleetBlocked, title: "舰队启动受阻", detail: "审计窗口内没有自然形成首次出航，需要检查开局资源、前置或顾问动作。")
            )
        }

        if plans.allSatisfy({ $0.progress < 1 }) {
            notes.append(
                GameplayAuditNote(kind: .victoryRouteBlocked, title: "胜利未闭环", detail: "没有路线在审计窗口内完成，后续调参应看最接近完成的检查点。")
            )
        }

        if aiIntents.contains(where: { $0.priority >= .warning }) {
            notes.append(
                GameplayAuditNote(kind: .aiPressure, title: "AI 压力可见", detail: "至少一个 AI 当前意图对玩家构成压力。")
            )
        }

        if recommendationKinds.count >= 3 {
            notes.append(
                GameplayAuditNote(kind: .advisorCoverage, title: "顾问覆盖良好", detail: "审计期间采样到 \(recommendationKinds.count) 类顾问建议。")
            )
        }

        return notes
    }

    private static func updateMilestones(from universe: Universe, result: inout BalanceScenarioResult) {
        let playerPlanets = universe.planets.filter { $0.ownerID == universe.playerFactionID }
        if result.firstShipAt == nil,
           playerPlanets.contains(where: { $0.shipInventory.values.reduce(0, +) > 0 }) {
            result.firstShipAt = universe.gameTime
        }
        if result.firstFleetLaunchAt == nil,
           let firstFleet = universe.fleets.filter({ $0.ownerID == universe.playerFactionID }).min(by: { $0.launchTime < $1.launchTime }) {
            result.firstFleetLaunchAt = firstFleet.launchTime
        }
        if result.firstEspionageAt == nil,
           let report = universe.reports.filter({ $0.kind == .espionage }).min(by: { $0.time < $1.time }) {
            result.firstEspionageAt = report.time
        }
        if result.firstExplorationEventAt == nil,
           let event = universe.events.filter({ $0.kind == .exploration }).min(by: { $0.time < $1.time }) {
            result.firstExplorationEventAt = event.time
        }
        if result.firstCombatAt == nil,
           let report = universe.reports.filter({ $0.kind == .battle || $0.kind == .missile }).min(by: { $0.time < $1.time }) {
            result.firstCombatAt = report.time
        }
        if result.firstColonizationAt == nil,
           let event = universe.events.first(where: { $0.title == "Colony Established" }) {
            result.firstColonizationAt = event.time
        }
        if result.victoryAt == nil, let victoryAt = universe.victoryState.achievedAt {
            result.victoryAt = victoryAt
        }
        result.aiAttackCount = universe.fleets.filter { $0.ownerID != universe.playerFactionID && $0.mission == .attack }.count
        result.automationQueuedActionCount = max(
            result.automationQueuedActionCount,
            playerPlanets.reduce(0) { total, planet in
                total + planet.buildQueue.count + planet.shipBuildQueue.count + planet.defenseBuildQueue.count
            } + (universe.factions.first { $0.id == universe.playerFactionID }?.researchQueue.count ?? 0)
        )
    }

    private static func playerOrigin(in universe: Universe) -> Planet? {
        universe.planets
            .filter { $0.ownerID == universe.playerFactionID }
            .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
            .first
    }

    private static func firstNeutralPlanet(in universe: Universe) -> Planet? {
        universe.planets
            .filter { $0.ownerID == nil }
            .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
            .first
    }

    private static func firstAIPlanet(in universe: Universe) -> Planet? {
        universe.planets
            .filter { planet in
                guard let ownerID = planet.ownerID else { return false }
                return ownerID != universe.playerFactionID
            }
            .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
            .first
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        var result: [Element] = []
        for element in self where !seen.contains(element) {
            seen.insert(element)
            result.append(element)
        }
        return result
    }
}
