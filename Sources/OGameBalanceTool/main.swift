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
        print("seed,difficulty,minutes,first_ship,first_fleet,first_conflict,first_colony,victory_at,player_rank,leader,leader_score,player_score,player_victory,events,reports")

        for difficulty in GameSettings.Difficulty.allCases {
            for minutes in durations {
                let snapshot = run(seed: 1, difficulty: difficulty, minutes: minutes)
                print(csvLine(seed: 1, difficulty: difficulty, minutes: minutes, snapshot: snapshot))
            }
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
            whole(snapshot.result.firstCombatAt),
            whole(snapshot.result.firstColonizationAt),
            whole(snapshot.result.victoryAt),
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

    private static func whole(_ value: Double) -> String {
        guard value.isFinite else {
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
        guard value.isFinite else {
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
