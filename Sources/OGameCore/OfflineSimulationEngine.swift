import Foundation

public struct OfflineCatchUpSummary: Codable, Equatable, Sendable {
    public var elapsedSeconds: TimeInterval
    public var processedChunks: Int
    public var completedConstructionCount: Int
    public var completedResearchCount: Int
    public var generatedEventCount: Int
    public var recordedEventCount: Int
    public var didMutate: Bool

    public init(
        elapsedSeconds: TimeInterval,
        processedChunks: Int,
        completedConstructionCount: Int,
        completedResearchCount: Int,
        generatedEventCount: Int,
        recordedEventCount: Int,
        didMutate: Bool
    ) {
        self.elapsedSeconds = elapsedSeconds
        self.processedChunks = processedChunks
        self.completedConstructionCount = completedConstructionCount
        self.completedResearchCount = completedResearchCount
        self.generatedEventCount = generatedEventCount
        self.recordedEventCount = recordedEventCount
        self.didMutate = didMutate
    }
}

public enum OfflineSimulationEngine {
    private static let maximumElapsedSeconds: TimeInterval = 86_400
    private static let minimumChunkInterval: TimeInterval = 60

    public static func catchUp(
        universe: inout Universe,
        elapsed: TimeInterval,
        now: Date
    ) -> OfflineCatchUpSummary {
        guard elapsed.isFinite, elapsed > 0 else {
            return emptySummary()
        }

        let elapsedSeconds = min(elapsed, maximumElapsedSeconds)
        let chunkInterval = resolvedChunkInterval(from: universe.ruleSet)
        let initialGameTime = universe.gameTime
        var remaining = elapsedSeconds
        var summary = OfflineCatchUpSummary(
            elapsedSeconds: elapsedSeconds,
            processedChunks: 0,
            completedConstructionCount: 0,
            completedResearchCount: 0,
            generatedEventCount: 0,
            recordedEventCount: 0,
            didMutate: false
        )

        while remaining > 0 {
            let delta = min(chunkInterval, remaining)
            let eventStartCount = universe.events.count

            SimulationEngine.tick(universe: &universe, delta: delta)

            let generatedEvents = Array(universe.events[eventStartCount..<universe.events.count])
            summary.completedConstructionCount += generatedEvents.filter { $0.title == "Construction Complete" }.count
            summary.completedResearchCount += generatedEvents.filter { $0.title == "Research Complete" }.count
            summary.generatedEventCount += generatedEvents.count
            if universe.events.count > eventStartCount {
                universe.events.removeSubrange(eventStartCount..<universe.events.count)
            }

            summary.processedChunks += 1
            remaining = max(0, remaining - delta)
        }

        summary.didMutate = true
        summary.recordedEventCount = 1
        universe.lastSimulatedWallClockTime = now
        universe.events.append(summaryEvent(for: summary, in: universe, initialGameTime: initialGameTime))

        return summary
    }

    private static func emptySummary() -> OfflineCatchUpSummary {
        OfflineCatchUpSummary(
            elapsedSeconds: 0,
            processedChunks: 0,
            completedConstructionCount: 0,
            completedResearchCount: 0,
            generatedEventCount: 0,
            recordedEventCount: 0,
            didMutate: false
        )
    }

    private static func resolvedChunkInterval(from ruleSet: RuleSet) -> TimeInterval {
        guard ruleSet.offlineChunkInterval.isFinite else {
            return minimumChunkInterval
        }

        return max(ruleSet.offlineChunkInterval, minimumChunkInterval)
    }

    private static func summaryEvent(
        for summary: OfflineCatchUpSummary,
        in universe: Universe,
        initialGameTime: TimeInterval
    ) -> GameEvent {
        GameEvent(
            id: summaryEventID(for: summary, in: universe, initialGameTime: initialGameTime),
            time: universe.gameTime,
            kind: .system,
            title: "Offline Catch-Up Complete",
            message: "Caught up \(summary.elapsedSeconds) seconds offline in \(summary.processedChunks) chunks. Completed \(summary.completedConstructionCount) construction and \(summary.completedResearchCount) research items; summarized \(summary.generatedEventCount) generated events."
        )
    }

    private static func summaryEventID(
        for summary: OfflineCatchUpSummary,
        in universe: Universe,
        initialGameTime: TimeInterval
    ) -> EventID {
        EventID(
            deterministicUUID(
                namespace: "0008",
                payload: [
                    "offline-catch-up",
                    universe.id.rawValue.uuidString,
                    String(initialGameTime),
                    String(universe.gameTime),
                    String(summary.elapsedSeconds),
                    String(summary.processedChunks),
                    String(summary.completedConstructionCount),
                    String(summary.completedResearchCount),
                    String(summary.generatedEventCount),
                    String(summary.recordedEventCount)
                ].joined(separator: "|")
            )
        )
    }

    private static func deterministicUUID(namespace: String, payload: String) -> UUID {
        let tail = String(format: "%012llx", stableHash(payload) & 0x0000_FFFF_FFFF_FFFF)
        return UUID(uuidString: "00000000-0000-0000-\(namespace)-\(tail)")!
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037

        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return hash
    }
}
