import Foundation

public enum IntelEngine {
    public struct EspionageResolution: Equatable, Sendable {
        public var intelTier: Int
        public var lostProbes: Int

        public init(intelTier: Int, lostProbes: Int = 0) {
            self.intelTier = min(max(intelTier, 1), 5)
            self.lostProbes = max(lostProbes, 0)
        }
    }

    public static func resolveEspionage(
        fleet: Fleet,
        attackerResearch: ResearchState,
        defenderResearch: ResearchState,
        defenderCombatUnitCount: Int,
        universeSeed: UInt64
    ) -> EspionageResolution {
        let probeCount = max(fleet.ships[.espionageProbe] ?? 0, 0)
        let tier = TechnologyEffects.espionageIntelTier(
            attacker: attackerResearch,
            defender: defenderResearch,
            probeCount: probeCount
        )
        let lossChance = probeLossChance(
            attackerResearch: attackerResearch,
            defenderResearch: defenderResearch,
            defenderCombatUnitCount: defenderCombatUnitCount
        )
        let rollPayload = [
            "probe-loss",
            String(universeSeed),
            fleet.id.rawValue.uuidString,
            String(fleet.arrivalTime)
        ].joined(separator: "|")
        let roll = Double(stableHash(rollPayload) % 10_000) / 10_000
        let lostProbes = roll < lossChance ? max(1, probeCount) : 0

        return EspionageResolution(intelTier: tier, lostProbes: lostProbes)
    }

    public static func maskedShips(_ ships: [ShipKind: Int], tier: Int) -> [ShipKind: Int] {
        tier >= 3 ? ships : [:]
    }

    public static func maskedDefenses(_ defenses: [DefenseKind: Int], tier: Int) -> [DefenseKind: Int] {
        tier >= 3 ? defenses : [:]
    }

    private static func probeLossChance(
        attackerResearch: ResearchState,
        defenderResearch: ResearchState,
        defenderCombatUnitCount: Int
    ) -> Double {
        let defenderAdvantage = max(
            0,
            TechnologyEffects.level(.espionage, in: defenderResearch) -
                TechnologyEffects.level(.espionage, in: attackerResearch)
        )
        return min(0.75, Double(defenderAdvantage) * 0.08 + Double(max(defenderCombatUnitCount, 0)) * 0.005)
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
