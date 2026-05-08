import Foundation
import OGameCore

private struct BalanceSnapshot {
    let label: String
    let gameTime: TimeInterval
    let playerRank: FactionScore?
    let leader: FactionScore?
    let playerPlanets: Int
    let playerFleetUnits: Int
    let playerDefenseUnits: Int
    let activeFleets: Int
    let reportCount: Int
    let leadingRoute: VictoryProgress?
}

@main
struct OGameBalanceTool {
    static func main() {
        let durations = parseDurations() ?? [30, 60, 120, 240]
        print("Native OGame balance probe")
        print("seed,difficulty,minutes,game_time,player_rank,leader,leader_score,player_score,player_victory,player_planets,player_fleet,player_defense,active_fleets,reports,leading_route")

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
        var universe = StarterUniverseFactory.makeNewGame(seed: seed, playerName: "指挥官")
        let tickSeconds: TimeInterval = 60

        for _ in 0..<minutes {
            SimulationEngine.tick(
                universe: &universe,
                delta: tickSeconds,
                allowAggressiveAIStrategy: true,
                aiDifficulty: difficulty
            )
        }

        StrategicEngine.updateStrategicState(in: &universe)
        let rankings = StrategicEngine.rankings(in: universe)
        let playerRank = rankings.first { $0.factionID == universe.playerFactionID }
        let playerPlanets = universe.planets.filter { $0.ownerID == universe.playerFactionID }
        let fleetUnits = playerPlanets.reduce(0) { total, planet in
            total + planet.shipInventory.values.reduce(0, +)
        }
        let defenseUnits = playerPlanets.reduce(0) { total, planet in
            total + planet.defenseInventory.values.reduce(0, +)
        }
        let leadingRoute = universe.victoryState.progress
            .filter { $0.factionID == universe.playerFactionID }
            .max { lhs, rhs in lhs.progress < rhs.progress }

        return BalanceSnapshot(
            label: "\(difficulty.localizedName)-\(minutes)m",
            gameTime: universe.gameTime,
            playerRank: playerRank,
            leader: rankings.first,
            playerPlanets: playerPlanets.count,
            playerFleetUnits: fleetUnits,
            playerDefenseUnits: defenseUnits,
            activeFleets: universe.fleets.filter { $0.phase != .completed }.count,
            reportCount: universe.reports.count,
            leadingRoute: leadingRoute
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
            whole(snapshot.gameTime),
            snapshot.playerRank.map { String($0.rank) } ?? "NA",
            snapshot.leader?.factionName ?? "NA",
            whole(snapshot.leader?.totalScore ?? 0),
            whole(snapshot.playerRank?.totalScore ?? 0),
            percent(snapshot.playerRank?.victoryProgress ?? 0),
            String(snapshot.playerPlanets),
            String(snapshot.playerFleetUnits),
            String(snapshot.playerDefenseUnits),
            String(snapshot.activeFleets),
            String(snapshot.reportCount),
            snapshot.leadingRoute?.route.localizedName ?? "NA"
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
