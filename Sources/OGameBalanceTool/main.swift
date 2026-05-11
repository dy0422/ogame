import Foundation
import OGameCore

private struct BalanceSnapshot {
    let label: String
    let duration: TimeInterval
    let result: BalanceScenarioResult
    let playerRank: FactionScore?
    let leader: FactionScore?
}

@main
struct OGameBalanceTool {
    static func main() {
        let durations = parseDurations() ?? [30, 60, 120, 240]
        print("Native OGame balance probe")
        print("seed,difficulty,minutes,first_ship,first_fleet,first_espionage,first_exploration,first_conflict,first_colony,first_moon,first_moon_action,victory_at,ai_attacks,automation_actions,player_rank,leader,leader_score,player_score,player_victory,events,reports")

        for difficulty in GameSettings.Difficulty.allCases {
            for minutes in durations {
                let snapshot = run(seed: 1, difficulty: difficulty, minutes: minutes)
                print(csvLine(seed: 1, difficulty: difficulty, minutes: minutes, snapshot: snapshot))
            }
        }

        let auditMinutes = durations.max() ?? 240
        print("")
        print("Autoplay gameplay audit")
        print("seed,difficulty,minutes,used_guided_fixtures,first_ship,first_fleet,first_espionage,first_exploration,first_conflict,first_colony,victory_at,expansion_signals,advisor_kinds,route_progress,route_next,ai_intents,notes")
        for difficulty in GameSettings.Difficulty.allCases {
            let audit = GameplayAuditEngine.runAutoplayAudit(
                seed: 1,
                duration: TimeInterval(auditMinutes * 60),
                settings: GameSettings(difficulty: difficulty)
            )
            print(auditCSVLine(seed: 1, difficulty: difficulty, minutes: auditMinutes, audit: audit))
        }
    }

    private static func parseDurations() -> [Int]? {
        let values = CommandLine.arguments.dropFirst().compactMap(Int.init)
        guard !values.isEmpty else {
            return nil
        }

        return values.filter { $0 > 0 }
    }

    private static func run(seed: UInt64, difficulty: GameSettings.Difficulty, minutes: Int) -> BalanceSnapshot {
        let duration = TimeInterval(minutes * 60)
        let result = BalanceScenarioRunner.run(
            seed: seed,
            duration: duration,
            settings: GameSettings(difficulty: difficulty)
        )
        let playerRank = result.finalRankings.first { $0.factionName == "指挥官" }

        return BalanceSnapshot(
            label: "\(difficulty.localizedName)-\(minutes)m",
            duration: duration,
            result: result,
            playerRank: playerRank,
            leader: result.finalRankings.first
        )
    }

    private static func csvLine(
        seed: UInt64,
        difficulty: GameSettings.Difficulty,
        minutes: Int,
        snapshot: BalanceSnapshot
    ) -> String {
        var fields: [String] = [
            String(seed),
            difficulty.localizedName,
            String(minutes),
            whole(snapshot.result.firstShipAt),
            whole(snapshot.result.firstFleetLaunchAt),
            whole(snapshot.result.firstEspionageAt),
            whole(snapshot.result.firstExplorationEventAt),
            whole(snapshot.result.firstCombatAt),
            whole(snapshot.result.firstColonizationAt),
            whole(snapshot.result.firstMoonAt),
            whole(snapshot.result.firstMoonActionAt),
            whole(snapshot.result.victoryAt),
            String(snapshot.result.aiAttackCount),
            String(snapshot.result.automationQueuedActionCount),
            snapshot.playerRank.map { String($0.rank) } ?? "NA",
            snapshot.leader?.factionName ?? "NA",
            whole(snapshot.leader?.totalScore ?? 0),
            whole(snapshot.playerRank?.totalScore ?? 0),
            percent(snapshot.playerRank?.victoryProgress ?? 0),
            String(snapshot.result.eventCount),
            String(snapshot.result.reportCount)
        ]

        fields = fields.map(escapeCSV)
        return fields.joined(separator: ",")
    }

    private static func auditCSVLine(
        seed: UInt64,
        difficulty: GameSettings.Difficulty,
        minutes: Int,
        audit: GameplayAuditResult
    ) -> String {
        let routeProgress = audit.routePlans
            .map { "\($0.title)=\(percent($0.progress))%" }
            .joined(separator: " | ")
        let routeNext = audit.routePlans
            .compactMap { plan in
                plan.nextCheckpoint.map { "\(plan.title):\($0.title)" }
            }
            .joined(separator: " | ")
        let aiIntents = audit.aiIntents
            .map { "\($0.factionName):\($0.intent.rawValue)" }
            .joined(separator: " | ")
        let notes = audit.auditNotes
            .map(\.title)
            .joined(separator: " | ")
        let advisorKinds = audit.advisorRecommendationKinds
            .map(\.rawValue)
            .joined(separator: " | ")

        let fields = [
            String(seed),
            difficulty.localizedName,
            String(minutes),
            audit.usedGuidedFixtures ? "true" : "false",
            whole(audit.balance.firstShipAt),
            whole(audit.balance.firstFleetLaunchAt),
            whole(audit.balance.firstEspionageAt),
            whole(audit.balance.firstExplorationEventAt),
            whole(audit.balance.firstCombatAt),
            whole(audit.balance.firstColonizationAt),
            whole(audit.balance.victoryAt),
            String(audit.expansionSignalCount),
            advisorKinds,
            routeProgress,
            routeNext,
            aiIntents,
            notes
        ]

        return fields.map(escapeCSV).joined(separator: ",")
    }

    private static func whole(_ value: Double) -> String {
        guard value.isFinite, abs(value) <= Double(Int.max) else {
            return "NA"
        }

        return String(Int(value.rounded()))
    }

    private static func whole(_ value: Double?) -> String {
        guard let value else {
            return "NA"
        }

        return whole(value)
    }

    private static func percent(_ value: Double) -> String {
        guard value.isFinite, abs(value * 100) <= Double(Int.max) else {
            return "NA"
        }

        return String(Int((value * 100).rounded()))
    }

    private static func escapeCSV(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
