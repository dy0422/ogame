import Foundation

public struct ActionChainFeedback: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case battle
    }

    public var kind: Kind
    public var title: String
    public var detail: String
    public var reportID: UUID
    public var reportTime: TimeInterval
    public var loot: ResourceBundle
    public var debris: ResourceBundle
    public var losses: ResourceBundle
    public var moonChancePercent: Int
    public var commanderExperienceEstimate: Int
    public var roundCount: Int

    public init(
        kind: Kind,
        title: String,
        detail: String,
        reportID: UUID,
        reportTime: TimeInterval,
        loot: ResourceBundle,
        debris: ResourceBundle,
        losses: ResourceBundle,
        moonChancePercent: Int,
        commanderExperienceEstimate: Int,
        roundCount: Int
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.reportID = reportID
        self.reportTime = reportTime.isFinite ? max(reportTime, 0) : 0
        self.loot = loot.nonnegative
        self.debris = debris.nonnegative
        self.losses = losses.nonnegative
        self.moonChancePercent = max(moonChancePercent, 0)
        self.commanderExperienceEstimate = max(commanderExperienceEstimate, 0)
        self.roundCount = max(roundCount, 0)
    }
}

public enum ActionChainFeedbackEngine {
    private static let feedbackWindow: TimeInterval = 7_200

    public static func feedback(for chainID: UUID, in universe: Universe) -> ActionChainFeedback? {
        guard let chain = universe.actionChains.first(where: { $0.id == chainID }),
              chain.kind == .hostileRaid,
              let site = hostileSite(for: chain, in: universe),
              let report = latestBattleReport(for: site, in: universe)
        else {
            return nil
        }

        let review = CombatReviewEngine.review(for: report)
        let moonChance = review?.moonChancePercent ?? UniverseTopologyEngine.moonChancePercent(forDebris: report.debris)
        let experience = commanderExperienceEstimate(for: report.losses)
        let title = review.map { "最近战斗：\($0.title)" } ?? "最近战斗"
        let detail = [
            "掠夺 \(resourceSummary(report.loot))",
            "残骸 \(resourceSummary(report.debris))",
            "损失 \(resourceSummary(report.losses))",
            "月球 \(moonChance)%",
            "指挥官经验约 \(experience)"
        ].joined(separator: " · ")

        return ActionChainFeedback(
            kind: .battle,
            title: title,
            detail: detail,
            reportID: report.id,
            reportTime: report.time,
            loot: report.loot,
            debris: report.debris,
            losses: report.losses,
            moonChancePercent: moonChance,
            commanderExperienceEstimate: experience,
            roundCount: report.battleRounds.count
        )
    }

    private static func latestBattleReport(for site: HostileSite, in universe: Universe) -> Report? {
        universe.reports
            .filter { report in
                report.kind == .battle &&
                    isRecent(report.time, in: universe) &&
                    report.participants.contains { $0.role == .attacker && $0.factionID == universe.playerFactionID } &&
                    reportMatches(site: site, report: report)
            }
            .sorted { lhs, rhs in
                if lhs.time != rhs.time {
                    return lhs.time > rhs.time
                }
                return lhs.id.uuidString > rhs.id.uuidString
            }
            .first
    }

    private static func hostileSite(for chain: ActionChain, in universe: Universe) -> HostileSite? {
        universe.hostileSites.first { site in
            stableUUID("action-chain|hostile|\(site.id.uuidString)") == chain.id
        }
    }

    private static func reportMatches(site: HostileSite, report: Report) -> Bool {
        if let targetPlanetID = site.targetPlanetID,
           report.participants.contains(where: { $0.role == .defender && $0.planetID == targetPlanetID }) {
            return true
        }

        return report.title.contains(site.coordinate.displayText) || report.summary.contains(site.coordinate.displayText)
    }

    private static func isRecent(_ time: TimeInterval, in universe: Universe) -> Bool {
        time <= universe.gameTime && time >= universe.gameTime - feedbackWindow
    }

    private static func commanderExperienceEstimate(for losses: ResourceBundle) -> Int {
        let total = resourceTotal(losses)
        guard total > 0, total.isFinite else {
            return 0
        }

        return max(25, Int(floor(total / 500)))
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

    private static func stableUUID(_ payload: String) -> UUID {
        let hash = stableHash(payload)
        return UUID(uuidString: String(format: "00000000-0000-0000-%04x-%012llx", Int(hash & 0xffff), hash & 0xffffffffffff))!
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
