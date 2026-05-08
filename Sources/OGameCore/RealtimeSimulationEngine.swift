import Foundation

public struct RealtimeSimulationState: Equatable, Sendable {
    public var lastFrameDate: Date?

    public init(lastFrameDate: Date? = nil) {
        self.lastFrameDate = lastFrameDate
    }
}

public struct RealtimeSimulationResult: Equatable, Sendable {
    public var didAdvance: Bool
    public var wallClockElapsed: TimeInterval
    public var appliedWallClockElapsed: TimeInterval
    public var simulatedDelta: TimeInterval

    public init(
        didAdvance: Bool,
        wallClockElapsed: TimeInterval,
        appliedWallClockElapsed: TimeInterval,
        simulatedDelta: TimeInterval
    ) {
        self.didAdvance = didAdvance
        self.wallClockElapsed = wallClockElapsed
        self.appliedWallClockElapsed = appliedWallClockElapsed
        self.simulatedDelta = simulatedDelta
    }
}

public enum RealtimeSimulationEngine {
    public static let defaultMaximumWallClockElapsed: TimeInterval = 30

    public static func advanceFrame(
        universe: inout Universe,
        state: inout RealtimeSimulationState,
        now: Date,
        settings: GameSettings,
        isPaused: Bool = false,
        maximumWallClockElapsed: TimeInterval = defaultMaximumWallClockElapsed
    ) -> RealtimeSimulationResult {
        guard let lastFrameDate = state.lastFrameDate else {
            state.lastFrameDate = now
            return noAdvanceResult(wallClockElapsed: 0)
        }

        let wallClockElapsed = now.timeIntervalSince(lastFrameDate)

        if isPaused {
            state.lastFrameDate = now
            return noAdvanceResult(wallClockElapsed: max(0, wallClockElapsed))
        }

        guard wallClockElapsed.isFinite, wallClockElapsed > 0 else {
            return noAdvanceResult(wallClockElapsed: wallClockElapsed)
        }

        guard maximumWallClockElapsed.isFinite, maximumWallClockElapsed > 0 else {
            state.lastFrameDate = now
            return noAdvanceResult(wallClockElapsed: wallClockElapsed)
        }

        let appliedWallClockElapsed = min(wallClockElapsed, maximumWallClockElapsed)
        let simulatedDelta = appliedWallClockElapsed * GameSettings.clampedGameSpeed(settings.gameSpeed)

        guard simulatedDelta.isFinite, simulatedDelta > 0 else {
            state.lastFrameDate = now
            return noAdvanceResult(wallClockElapsed: wallClockElapsed)
        }

        SimulationEngine.tick(
            universe: &universe,
            delta: simulatedDelta,
            aiDifficulty: settings.difficulty,
            eventPolicy: .domainOnly
        )
        state.lastFrameDate = now

        return RealtimeSimulationResult(
            didAdvance: true,
            wallClockElapsed: wallClockElapsed,
            appliedWallClockElapsed: appliedWallClockElapsed,
            simulatedDelta: simulatedDelta
        )
    }

    private static func noAdvanceResult(wallClockElapsed: TimeInterval) -> RealtimeSimulationResult {
        RealtimeSimulationResult(
            didAdvance: false,
            wallClockElapsed: wallClockElapsed,
            appliedWallClockElapsed: 0,
            simulatedDelta: 0
        )
    }
}
