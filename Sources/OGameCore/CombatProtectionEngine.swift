import Foundation

public enum CombatProtectionEngine {
    public enum BattleClass: String, Codable, Equatable, Sendable {
        case specialTarget
        case honorable
        case standard
        case nonHonorable
    }

    public struct ProtectionResult: Equatable, Sendable {
        public var battleClass: BattleClass
        public var lootFraction: Double
        public var label: String

        public init(battleClass: BattleClass, lootFraction: Double, label: String) {
            self.battleClass = battleClass
            self.lootFraction = min(max(lootFraction.isFinite ? lootFraction : 0.5, 0), 1)
            self.label = label
        }
    }

    public static func evaluate(
        attackerID: FactionID,
        defenderID: FactionID?,
        attackerFaction: Faction?,
        defenderFaction: Faction?,
        universe: Universe
    ) -> ProtectionResult {
        guard let defenderID else {
            return ProtectionResult(battleClass: .specialTarget, lootFraction: 1.0, label: "特殊目标")
        }

        let attackerScore = score(for: attackerID, in: universe)
        let defenderScore = score(for: defenderID, in: universe)
        guard attackerScore > 0, defenderScore > 0 else {
            return ProtectionResult(battleClass: .standard, lootFraction: 0.5, label: "标准战斗")
        }

        let ratio = attackerScore / max(defenderScore, 1)
        if ratio >= 5 {
            return ProtectionResult(battleClass: .nonHonorable, lootFraction: 0.25, label: "非荣誉战斗")
        }
        if ratio >= 3 {
            return ProtectionResult(battleClass: .nonHonorable, lootFraction: 0.35, label: "非荣誉战斗")
        }
        if defenderScore >= attackerScore * 0.5 || defenderFaction?.kind == .player {
            return ProtectionResult(battleClass: .honorable, lootFraction: 0.6, label: "荣誉战斗")
        }

        return ProtectionResult(battleClass: .standard, lootFraction: 0.5, label: "标准战斗")
    }

    private static func score(for factionID: FactionID, in universe: Universe) -> Double {
        if let rankedScore = universe.rankings.first(where: { $0.factionID == factionID })?.totalScore,
           rankedScore.isFinite,
           rankedScore > 0
        {
            return rankedScore
        }

        return StrategicEngine.rankings(in: universe)
            .first(where: { $0.factionID == factionID })?
            .totalScore ?? 0
    }
}
