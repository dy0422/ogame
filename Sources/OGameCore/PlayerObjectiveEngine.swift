import Foundation

public enum PlayerObjectiveEngine {
    public static func states(in universe: Universe) -> [PlayerObjectiveState] {
        let claimedKinds = Set(universe.playerObjectiveRecords.map(\.kind))
        return objectiveDefinitions.map { definition in
            PlayerObjectiveState(
                kind: definition.kind,
                title: definition.title,
                detail: definition.detail,
                progressValue: progressValue(for: definition.kind, in: universe),
                targetValue: definition.targetValue,
                reward: definition.reward,
                isClaimed: claimedKinds.contains(definition.kind)
            )
        }
    }

    @discardableResult
    public static func updatePlayerObjectives(in universe: inout Universe) -> [PlayerObjectiveState] {
        let completedRecords = Set(universe.playerObjectiveRecords.map(\.kind))
        let newlyCompleted = states(in: universe).filter { state in
            state.isComplete && !completedRecords.contains(state.kind)
        }
        guard newlyCompleted.isEmpty == false else {
            return []
        }

        for state in newlyCompleted {
            universe.playerObjectiveRecords.append(
                PlayerObjectiveRecord(
                    kind: state.kind,
                    completedAt: universe.gameTime,
                    reward: state.reward
                )
            )
            grantReward(state.reward, in: &universe)
            universe.events.append(completionEvent(for: state, in: universe))
        }
        universe.playerObjectiveRecords.sort { lhs, rhs in
            if lhs.completedAt != rhs.completedAt {
                return lhs.completedAt < rhs.completedAt
            }

            return objectiveIndex(lhs.kind) < objectiveIndex(rhs.kind)
        }

        return newlyCompleted
    }

    private struct ObjectiveDefinition {
        var kind: PlayerObjectiveKind
        var title: String
        var detail: String
        var targetValue: Double
        var reward: ResourceBundle
    }

    private static let objectiveDefinitions: [ObjectiveDefinition] = [
        ObjectiveDefinition(
            kind: .solarStability,
            title: "稳定能源",
            detail: "任一玩家星球太阳能发电站达到 4 级。",
            targetValue: 4,
            reward: ResourceBundle(metal: 800, crystal: 400, deuterium: 100)
        ),
        ObjectiveDefinition(
            kind: .industrialFoundation,
            title: "工业基础",
            detail: "同一星球达成金属矿 6、晶体矿 5、重氢合成器 3。",
            targetValue: 3,
            reward: ResourceBundle(metal: 1_500, crystal: 1_000, deuterium: 400)
        ),
        ObjectiveDefinition(
            kind: .researchProgram,
            title: "科研计划",
            detail: "累计研究等级达到 2。",
            targetValue: 2,
            reward: ResourceBundle(metal: 1_000, crystal: 1_500, deuterium: 600)
        ),
        ObjectiveDefinition(
            kind: .orbitalLogistics,
            title: "轨道后勤",
            detail: "拥有或派出第一艘舰船。",
            targetValue: 1,
            reward: ResourceBundle(metal: 1_200, crystal: 900, deuterium: 500)
        ),
        ObjectiveDefinition(
            kind: .firstEspionage,
            title: "第一次侦察",
            detail: "获得第一份侦察报告。",
            targetValue: 1,
            reward: ResourceBundle(metal: 1_500, crystal: 1_500, deuterium: 900)
        ),
        ObjectiveDefinition(
            kind: .deepSpaceSurvey,
            title: "深空调查",
            detail: "完成第一次探索记录。",
            targetValue: 1,
            reward: ResourceBundle(metal: 2_500, crystal: 1_800, deuterium: 1_200)
        ),
        ObjectiveDefinition(
            kind: .secondColony,
            title: "第二殖民地",
            detail: "拥有 2 个玩家星球。",
            targetValue: 2,
            reward: ResourceBundle(metal: 5_000, crystal: 3_000, deuterium: 1_500)
        ),
        ObjectiveDefinition(
            kind: .lunarOutpost,
            title: "月面前哨",
            detail: "拥有第一颗月球。",
            targetValue: 1,
            reward: ResourceBundle(metal: 10_000, crystal: 8_000, deuterium: 4_000)
        )
    ]

    private static func progressValue(for kind: PlayerObjectiveKind, in universe: Universe) -> Double {
        let planets = playerPlanets(in: universe)
        switch kind {
        case .solarStability:
            return Double(planets.map { normalizedLevel($0.buildingLevels[.solarPlant] ?? 0) }.max() ?? 0)
        case .industrialFoundation:
            return Double(planets.map(industrialFoundationStepCount).max() ?? 0)
        case .researchProgram:
            guard let player = playerFaction(in: universe) else {
                return 0
            }

            return Double(player.technology.levels.values.reduce(0) { $0 + normalizedLevel($1) })
        case .orbitalLogistics:
            let dockedShips = planets.reduce(0) { total, planet in
                total + planet.shipInventory.values.reduce(0) { $0 + normalizedLevel($1) }
            }
            let activeShips = universe.fleets
                .filter { $0.ownerID == universe.playerFactionID && $0.phase != .completed }
                .reduce(0) { total, fleet in
                    total + fleet.ships.values.reduce(0) { $0 + normalizedLevel($1) }
                }
            return Double(dockedShips + activeShips)
        case .firstEspionage:
            return universe.reports.contains { report in
                report.kind == .espionage &&
                    report.participants.contains { $0.role == .attacker && $0.factionID == universe.playerFactionID }
            } ? 1 : 0
        case .deepSpaceSurvey:
            return Double(
                StrategicEngine.explorationRecords(for: universe.playerFactionID, in: universe).count
            )
        case .secondColony:
            return Double(planets.count)
        case .lunarOutpost:
            return Double(planets.filter { $0.moon != nil }.count)
        }
    }

    private static func industrialFoundationStepCount(_ planet: Planet) -> Int {
        var count = 0
        if normalizedLevel(planet.buildingLevels[.metalMine] ?? 0) >= 6 {
            count += 1
        }
        if normalizedLevel(planet.buildingLevels[.crystalMine] ?? 0) >= 5 {
            count += 1
        }
        if normalizedLevel(planet.buildingLevels[.deuteriumSynthesizer] ?? 0) >= 3 {
            count += 1
        }
        return count
    }

    private static func grantReward(_ reward: ResourceBundle, in universe: inout Universe) {
        guard let planetIndex = firstPlayerPlanetIndex(in: universe) else {
            return
        }

        universe.planets[planetIndex].resources = universe.planets[planetIndex].resources.adding(reward).nonnegative
    }

    private static func completionEvent(for state: PlayerObjectiveState, in universe: Universe) -> GameEvent {
        GameEvent(
            id: objectiveEventID(kind: state.kind, universe: universe),
            time: universe.gameTime,
            kind: .system,
            title: "阶段目标完成",
            message: "\(state.title) 已完成，奖励已发放到主星。"
        )
    }

    private static func playerFaction(in universe: Universe) -> Faction? {
        universe.factions.first { $0.id == universe.playerFactionID }
    }

    private static func playerPlanets(in universe: Universe) -> [Planet] {
        PlayerVisibilityEngine.playerOwnedPlanets(in: universe)
    }

    private static func firstPlayerPlanetIndex(in universe: Universe) -> Int? {
        if let faction = playerFaction(in: universe) {
            for planetID in faction.ownedPlanetIDs {
                if let index = universe.planets.firstIndex(where: { $0.id == planetID && $0.ownerID == faction.id }) {
                    return index
                }
            }
        }

        guard let firstPlayerPlanet = PlayerVisibilityEngine.playerOwnedPlanets(in: universe).first else {
            return nil
        }
        return universe.planets.firstIndex {
            $0.id == firstPlayerPlanet.id && $0.ownerID == universe.playerFactionID
        }
    }

    private static func objectiveIndex(_ kind: PlayerObjectiveKind) -> Int {
        PlayerObjectiveKind.allCases.firstIndex(of: kind) ?? Int.max
    }

    private static func normalizedLevel(_ level: Int) -> Int {
        max(level, 0)
    }

    private static func objectiveEventID(kind: PlayerObjectiveKind, universe: Universe) -> EventID {
        let payload = [
            "player-objective",
            universe.id.rawValue.uuidString,
            kind.rawValue,
            String(universe.gameTime)
        ].joined(separator: "|")
        let tail = String(format: "%012llx", stableHash(payload) & 0x0000_FFFF_FFFF_FFFF)
        return EventID(UUID(uuidString: "00000000-0000-0000-0016-\(tail)")!)
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
