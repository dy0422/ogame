import Foundation

public enum SimulationEngine {
    private static let minimumAIDecisionInterval: TimeInterval = 60
    private static let minimumAIStrategyInterval: TimeInterval = 120

    public static func tick(
        universe: inout Universe,
        delta: TimeInterval,
        allowAggressiveAIStrategy: Bool = true,
        aiDifficulty: GameSettings.Difficulty = .standard
    ) {
        guard delta.isFinite, delta > 0 else {
            return
        }

        let initialGameTime = universe.gameTime

        QueueEngine.completeDueItems(in: &universe)
        EconomyEngine.tick(universe: &universe, delta: delta)

        universe.gameTime += delta
        QueueEngine.completeDueItems(in: &universe)
        FleetEngine.resolveDueFleets(in: &universe)
        runAIEconomyDecisionsIfNeeded(in: &universe, from: initialGameTime)
        runAIStrategyDecisionsIfNeeded(
            in: &universe,
            from: initialGameTime,
            allowAggressiveMissions: allowAggressiveAIStrategy,
            aiDifficulty: aiDifficulty
        )
        StrategicEngine.updateStrategicState(in: &universe)

        universe.events.append(
            GameEvent(
                id: simulationEventID(index: universe.events.count + 1),
                time: universe.gameTime,
                kind: .system,
                title: "Simulation Advanced",
                message: "Advanced the universe by \(delta) seconds."
            )
        )
    }

    private static func runAIEconomyDecisionsIfNeeded(in universe: inout Universe, from initialGameTime: TimeInterval) {
        guard shouldRunAIEconomyDecisions(from: initialGameTime, to: universe.gameTime, ruleSet: universe.ruleSet) else {
            return
        }

        AIEconomyEngine.makeDecisions(in: &universe)
    }

    private static func runAIStrategyDecisionsIfNeeded(
        in universe: inout Universe,
        from initialGameTime: TimeInterval,
        allowAggressiveMissions: Bool,
        aiDifficulty: GameSettings.Difficulty
    ) {
        guard shouldRunAIStrategyDecisions(from: initialGameTime, to: universe.gameTime, ruleSet: universe.ruleSet) else {
            return
        }

        AIStrategyEngine.makeStrategicDecisions(
            in: &universe,
            allowAggressiveMissions: allowAggressiveMissions,
            policy: AIDifficultyPolicy(difficulty: aiDifficulty)
        )
    }

    private static func shouldRunAIEconomyDecisions(
        from initialGameTime: TimeInterval,
        to currentGameTime: TimeInterval,
        ruleSet: RuleSet
    ) -> Bool {
        shouldRunAIDecisions(
            from: initialGameTime,
            to: currentGameTime,
            interval: aiEconomyDecisionInterval(from: ruleSet)
        )
    }

    private static func shouldRunAIStrategyDecisions(
        from initialGameTime: TimeInterval,
        to currentGameTime: TimeInterval,
        ruleSet: RuleSet
    ) -> Bool {
        shouldRunAIDecisions(
            from: initialGameTime,
            to: currentGameTime,
            interval: aiStrategyDecisionInterval(from: ruleSet)
        )
    }

    private static func shouldRunAIDecisions(
        from initialGameTime: TimeInterval,
        to currentGameTime: TimeInterval,
        interval: TimeInterval
    ) -> Bool {
        guard initialGameTime.isFinite, currentGameTime.isFinite else {
            return false
        }

        let initialWindow = floor(max(initialGameTime, 0) / interval)
        let currentWindow = floor(max(currentGameTime, 0) / interval)

        return currentWindow > initialWindow
    }

    private static func aiEconomyDecisionInterval(from ruleSet: RuleSet) -> TimeInterval {
        guard ruleSet.offlineChunkInterval.isFinite, ruleSet.offlineChunkInterval > 0 else {
            return minimumAIDecisionInterval
        }

        return max(ruleSet.offlineChunkInterval, minimumAIDecisionInterval)
    }

    private static func aiStrategyDecisionInterval(from ruleSet: RuleSet) -> TimeInterval {
        guard ruleSet.offlineChunkInterval.isFinite, ruleSet.offlineChunkInterval > 0 else {
            return minimumAIStrategyInterval
        }

        return max(ruleSet.offlineChunkInterval / 2, minimumAIStrategyInterval)
    }

    private static func simulationEventID(index: Int) -> EventID {
        EventID(UUID(uuidString: String(format: "00000000-0000-0000-0002-%012d", index))!)
    }
}
