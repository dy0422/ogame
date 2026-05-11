import Foundation

public struct CombatRoundReview: Equatable, Identifiable, Sendable {
    public var round: Int
    public var title: String
    public var detail: String
    public var attackerLossCount: Int
    public var defenderShipLossCount: Int
    public var defenderDefenseLossCount: Int
    public var rapidFireShots: Int
    public var shieldDamage: Double
    public var hullDamage: Double
    public var explodedUnits: Int

    public var id: Int { round }

    public init(
        round: Int,
        title: String,
        detail: String,
        attackerLossCount: Int,
        defenderShipLossCount: Int,
        defenderDefenseLossCount: Int,
        rapidFireShots: Int,
        shieldDamage: Double,
        hullDamage: Double,
        explodedUnits: Int
    ) {
        self.round = max(round, 0)
        self.title = title
        self.detail = detail
        self.attackerLossCount = max(attackerLossCount, 0)
        self.defenderShipLossCount = max(defenderShipLossCount, 0)
        self.defenderDefenseLossCount = max(defenderDefenseLossCount, 0)
        self.rapidFireShots = max(rapidFireShots, 0)
        self.shieldDamage = shieldDamage.isFinite ? max(shieldDamage, 0) : 0
        self.hullDamage = hullDamage.isFinite ? max(hullDamage, 0) : 0
        self.explodedUnits = max(explodedUnits, 0)
    }
}

public struct CombatReviewInsight: Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case battleOutcome
        case rapidFire
        case debrisRecovery
        case moonChance
        case loot
        case fleetComposition
        case defenseRecovery
    }

    public var kind: Kind
    public var title: String
    public var detail: String

    public var id: String {
        [kind.rawValue, title, detail].joined(separator: "|")
    }

    public init(kind: Kind, title: String, detail: String) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

public struct CombatReview: Equatable, Sendable {
    public enum Outcome: String, Codable, Equatable, Sendable {
        case attackerVictory
        case defenderHeld
        case mutualDestruction
        case stalemate

        public var localizedName: String {
            switch self {
            case .attackerVictory:
                return "攻击方胜利"
            case .defenderHeld:
                return "防守方守住"
            case .mutualDestruction:
                return "双方同归于尽"
            case .stalemate:
                return "战斗僵持"
            }
        }
    }

    public var outcome: Outcome
    public var title: String
    public var summary: String
    public var rounds: [CombatRoundReview]
    public var insights: [CombatReviewInsight]
    public var moonChancePercent: Int
    public var totalRapidFireShots: Int
    public var totalExplodedUnits: Int
    public var totalShieldDamage: Double
    public var totalHullDamage: Double
    public var attackerLossUnits: Int
    public var defenderLossUnits: Int

    public init(
        outcome: Outcome,
        title: String,
        summary: String,
        rounds: [CombatRoundReview],
        insights: [CombatReviewInsight],
        moonChancePercent: Int,
        totalRapidFireShots: Int,
        totalExplodedUnits: Int,
        totalShieldDamage: Double,
        totalHullDamage: Double,
        attackerLossUnits: Int,
        defenderLossUnits: Int
    ) {
        self.outcome = outcome
        self.title = title
        self.summary = summary
        self.rounds = rounds
        self.insights = insights
        self.moonChancePercent = max(moonChancePercent, 0)
        self.totalRapidFireShots = max(totalRapidFireShots, 0)
        self.totalExplodedUnits = max(totalExplodedUnits, 0)
        self.totalShieldDamage = totalShieldDamage.isFinite ? max(totalShieldDamage, 0) : 0
        self.totalHullDamage = totalHullDamage.isFinite ? max(totalHullDamage, 0) : 0
        self.attackerLossUnits = max(attackerLossUnits, 0)
        self.defenderLossUnits = max(defenderLossUnits, 0)
    }
}

public enum CombatReviewEngine {
    public static func review(for report: Report) -> CombatReview? {
        guard report.kind == .battle else {
            return nil
        }

        let attacker = report.participants.first { $0.role == .attacker }
        let defender = report.participants.first { $0.role == .defender }
        let outcome = outcome(attacker: attacker, defender: defender)
        let rounds = report.battleRounds.map(roundReview)
        let totalRapidFire = report.battleRounds.reduce(0) { $0 + $1.rapidFireShots }
        let totalExplosions = report.battleRounds.reduce(0) { $0 + $1.explodedUnits }
        let totalShieldDamage = report.battleRounds.reduce(0) { $0 + $1.shieldDamage }
        let totalHullDamage = report.battleRounds.reduce(0) { $0 + $1.hullDamage }
        let attackerLossUnits = report.battleRounds.reduce(0) { $0 + unitCount($1.attackerLosses) }
        let defenderLossUnits = report.battleRounds.reduce(0) {
            $0 + unitCount($1.defenderShipLosses) + unitCount($1.defenderDefenseLosses)
        }
        let moonChance = UniverseTopologyEngine.moonChancePercent(forDebris: report.debris)
        let insights = insights(
            report: report,
            outcome: outcome,
            attacker: attacker,
            defender: defender,
            totalRapidFire: totalRapidFire,
            totalExplosions: totalExplosions,
            moonChance: moonChance,
            attackerLossUnits: attackerLossUnits,
            defenderLossUnits: defenderLossUnits
        )

        return CombatReview(
            outcome: outcome,
            title: outcome.localizedName,
            summary: summary(
                outcome: outcome,
                roundCount: report.battleRounds.count,
                loot: report.loot,
                debris: report.debris,
                moonChance: moonChance
            ),
            rounds: rounds,
            insights: insights,
            moonChancePercent: moonChance,
            totalRapidFireShots: totalRapidFire,
            totalExplodedUnits: totalExplosions,
            totalShieldDamage: totalShieldDamage,
            totalHullDamage: totalHullDamage,
            attackerLossUnits: attackerLossUnits,
            defenderLossUnits: defenderLossUnits
        )
    }

    private static func outcome(attacker: ReportParticipant?, defender: ReportParticipant?) -> CombatReview.Outcome {
        let attackerSurvived = unitCount(attacker?.afterShips ?? [:]) > 0
        let defenderSurvived = unitCount(defender?.afterShips ?? [:]) + unitCount(defender?.afterDefenses ?? [:]) > 0

        switch (attackerSurvived, defenderSurvived) {
        case (true, false):
            return .attackerVictory
        case (false, true):
            return .defenderHeld
        case (false, false):
            return .mutualDestruction
        case (true, true):
            return .stalemate
        }
    }

    private static func roundReview(_ round: BattleRoundSummary) -> CombatRoundReview {
        let attackerLosses = unitCount(round.attackerLosses)
        let defenderShips = unitCount(round.defenderShipLosses)
        let defenderDefenses = unitCount(round.defenderDefenseLosses)
        let detailParts = [
            "射击 \(round.attackerShots)/\(round.defenderShots)",
            "RF \(round.rapidFireShots)",
            "护盾 \(whole(round.shieldDamage))",
            "结构 \(whole(round.hullDamage))",
            "爆炸 \(round.explodedUnits)"
        ]

        return CombatRoundReview(
            round: round.round,
            title: "第 \(round.round) 回合",
            detail: detailParts.joined(separator: " · "),
            attackerLossCount: attackerLosses,
            defenderShipLossCount: defenderShips,
            defenderDefenseLossCount: defenderDefenses,
            rapidFireShots: round.rapidFireShots,
            shieldDamage: round.shieldDamage,
            hullDamage: round.hullDamage,
            explodedUnits: round.explodedUnits
        )
    }

    private static func insights(
        report: Report,
        outcome: CombatReview.Outcome,
        attacker: ReportParticipant?,
        defender: ReportParticipant?,
        totalRapidFire: Int,
        totalExplosions: Int,
        moonChance: Int,
        attackerLossUnits: Int,
        defenderLossUnits: Int
    ) -> [CombatReviewInsight] {
        var result: [CombatReviewInsight] = [
            CombatReviewInsight(
                kind: .battleOutcome,
                title: outcome.localizedName,
                detail: "战斗持续 \(report.battleRounds.count) 回合，攻击方损失 \(attackerLossUnits) 个单位，防守方损失 \(defenderLossUnits) 个单位。"
            )
        ]

        if totalRapidFire > 0 {
            result.append(
                CombatReviewInsight(
                    kind: .rapidFire,
                    title: "Rapid Fire 生效",
                    detail: "额外触发 \(totalRapidFire) 次射击，舰种克制已经影响战局。"
                )
            )
        }

        if totalExplosions > 0 {
            result.append(
                CombatReviewInsight(
                    kind: .fleetComposition,
                    title: "结构损伤造成爆炸",
                    detail: "\(totalExplosions) 个单位在结构受损后爆炸，炮灰和护盾科技会改变损失曲线。"
                )
            )
        }

        if resourceTotal(report.loot) > 0 {
            result.append(
                CombatReviewInsight(
                    kind: .loot,
                    title: "掠夺收益",
                    detail: "带回 \(resourceSummary(report.loot))，货舱和保护规则会限制实际收益。"
                )
            )
        }

        if resourceTotal(report.debris) > 0 {
            result.append(
                CombatReviewInsight(
                    kind: .debrisRecovery,
                    title: "残骸待回收",
                    detail: "新生成 \(resourceSummary(report.debris))，及时派回收船能把损失转回经济。"
                )
            )
        }

        if moonChance > 0 {
            result.append(
                CombatReviewInsight(
                    kind: .moonChance,
                    title: "月球概率 \(moonChance)%",
                    detail: "残骸达到月球判定阈值，若生成月球可解锁感应阵和跳跃门玩法。"
                )
            )
        }

        if outcome == .defenderHeld,
           unitCount(attacker?.beforeShips ?? [:]) > 0,
           unitCount(attacker?.afterShips ?? [:]) == 0
        {
            result.append(
                CombatReviewInsight(
                    kind: .fleetComposition,
                    title: "攻击舰队全灭",
                    detail: "下次增加炮灰、提高战斗科技，或先侦察防御后再派主力。"
                )
            )
        }

        let defenderDefenseBefore = unitCount(defender?.beforeDefenses ?? [:])
        let defenderDefenseAfter = unitCount(defender?.afterDefenses ?? [:])
        if defenderDefenseBefore > defenderDefenseAfter, defenderDefenseAfter > 0 {
            result.append(
                CombatReviewInsight(
                    kind: .defenseRecovery,
                    title: "防御部分修复",
                    detail: "防御被摧毁后仍有部分恢复，导弹清防和舰队攻击的长期效果不同。"
                )
            )
        }

        return result
    }

    private static func summary(
        outcome: CombatReview.Outcome,
        roundCount: Int,
        loot: ResourceBundle,
        debris: ResourceBundle,
        moonChance: Int
    ) -> String {
        "\(outcome.localizedName) · \(roundCount) 回合 · 掠夺 \(resourceSummary(loot)) · 残骸 \(resourceSummary(debris)) · 月球 \(moonChance)%"
    }

    private static func unitCount<Key>(_ values: [Key: Int]) -> Int {
        values.values.reduce(0) { $0 + max($1, 0) }
    }

    private static func resourceTotal(_ resources: ResourceBundle) -> Double {
        guard resources.metal.isFinite, resources.crystal.isFinite, resources.deuterium.isFinite else {
            return .infinity
        }
        return max(resources.metal, 0) + max(resources.crystal, 0) + max(resources.deuterium, 0)
    }

    private static func resourceSummary(_ resources: ResourceBundle) -> String {
        "金属 \(whole(resources.metal)) / 晶体 \(whole(resources.crystal)) / 重氢 \(whole(resources.deuterium))"
    }

    private static func whole(_ value: Double) -> String {
        guard value.isFinite, abs(value) <= Double(Int.max) else {
            return "未知"
        }
        return String(Int(value.rounded()))
    }
}
