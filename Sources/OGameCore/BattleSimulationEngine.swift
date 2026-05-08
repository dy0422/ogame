import Foundation

public struct BattleSimulationInput: Equatable, Sendable {
    public var attackerShips: [ShipKind: Int]
    public var defenderShips: [ShipKind: Int]
    public var defenderDefenses: [DefenseKind: Int]
    public var attackerResearch: ResearchState
    public var defenderResearch: ResearchState
    public var ruleSet: RuleSet
    public var seed: UInt64

    public init(
        attackerShips: [ShipKind: Int],
        defenderShips: [ShipKind: Int],
        defenderDefenses: [DefenseKind: Int],
        attackerResearch: ResearchState,
        defenderResearch: ResearchState,
        ruleSet: RuleSet,
        seed: UInt64
    ) {
        self.attackerShips = attackerShips
        self.defenderShips = defenderShips
        self.defenderDefenses = defenderDefenses
        self.attackerResearch = attackerResearch
        self.defenderResearch = defenderResearch
        self.ruleSet = ruleSet
        self.seed = seed
    }
}

public struct BattleSimulationResult: Equatable, Sendable {
    public var attackerWon: Bool
    public var rounds: [BattleRoundSummary]
    public var remainingAttackerShips: [ShipKind: Int]
    public var remainingDefenderShips: [ShipKind: Int]
    public var remainingDefenderDefenses: [DefenseKind: Int]
    public var debris: ResourceBundle

    public init(
        attackerWon: Bool,
        rounds: [BattleRoundSummary],
        remainingAttackerShips: [ShipKind: Int],
        remainingDefenderShips: [ShipKind: Int],
        remainingDefenderDefenses: [DefenseKind: Int],
        debris: ResourceBundle = .zero
    ) {
        self.attackerWon = attackerWon
        self.rounds = rounds
        self.remainingAttackerShips = remainingAttackerShips
        self.remainingDefenderShips = remainingDefenderShips
        self.remainingDefenderDefenses = remainingDefenderDefenses
        self.debris = debris
    }
}

public enum BattleSimulationEngine {
    private static let maximumRounds = 6

    public static func resolve(_ input: BattleSimulationInput) -> BattleSimulationResult {
        var attackerShips = normalizedShips(input.attackerShips)
        var defenderShips = normalizedShips(input.defenderShips)
        var defenderDefenses = normalizedDefenses(input.defenderDefenses)
        var rounds: [BattleRoundSummary] = []

        for roundNumber in 1...maximumRounds {
            let defenderHasUnits = defenderShips.isEmpty == false || defenderDefenses.isEmpty == false
            guard attackerShips.isEmpty == false, defenderHasUnits else {
                break
            }

            let attackerPower = shipPower(attackerShips, research: input.attackerResearch, ruleSet: input.ruleSet) *
                roundVariation(seed: input.seed, round: roundNumber, side: "attacker")
            let defenderPower = (
                shipPower(defenderShips, research: input.defenderResearch, ruleSet: input.ruleSet) +
                    defensePower(defenderDefenses, research: input.defenderResearch, ruleSet: input.ruleSet)
            ) * roundVariation(seed: input.seed, round: roundNumber, side: "defender")

            let attackerLossFraction = lossFraction(incoming: defenderPower, own: attackerPower)
            let defenderLossFraction = lossFraction(incoming: attackerPower, own: defenderPower)
            let attackerLosses = destroyedShips(
                attackerShips,
                fraction: attackerLossFraction,
                research: input.attackerResearch,
                ruleSet: input.ruleSet
            )
            let defenderShipLosses = destroyedShips(
                defenderShips,
                fraction: defenderLossFraction,
                research: input.defenderResearch,
                ruleSet: input.ruleSet
            )
            let defenderDefenseLosses = destroyedDefenses(defenderDefenses, fraction: defenderLossFraction)

            rounds.append(
                BattleRoundSummary(
                    round: roundNumber,
                    attackerPower: attackerPower,
                    defenderPower: defenderPower,
                    attackerLosses: attackerLosses,
                    defenderShipLosses: defenderShipLosses,
                    defenderDefenseLosses: defenderDefenseLosses
                )
            )

            attackerShips = subtract(attackerShips, attackerLosses)
            defenderShips = subtract(defenderShips, defenderShipLosses)
            defenderDefenses = subtract(defenderDefenses, defenderDefenseLosses)

            if attackerLosses.isEmpty,
               defenderShipLosses.isEmpty,
               defenderDefenseLosses.isEmpty {
                break
            }
        }

        let remainingDefenderPower = shipPower(defenderShips, research: input.defenderResearch, ruleSet: input.ruleSet) +
            defensePower(defenderDefenses, research: input.defenderResearch, ruleSet: input.ruleSet)
        let remainingAttackerPower = shipPower(attackerShips, research: input.attackerResearch, ruleSet: input.ruleSet)
        let attackerWon = attackerShips.isEmpty == false &&
            (defenderShips.isEmpty && defenderDefenses.isEmpty || remainingAttackerPower >= remainingDefenderPower)

        return BattleSimulationResult(
            attackerWon: attackerWon,
            rounds: rounds,
            remainingAttackerShips: attackerShips,
            remainingDefenderShips: defenderShips,
            remainingDefenderDefenses: defenderDefenses
        )
    }

    private static func shipPower(
        _ ships: [ShipKind: Int],
        research: ResearchState,
        ruleSet: RuleSet
    ) -> Double {
        let weapons = 1 + Double(TechnologyEffects.level(.weapons, in: research)) * 0.10
        let shields = 1 + Double(TechnologyEffects.level(.shielding, in: research)) * 0.10
        let armor = 1 + Double(TechnologyEffects.level(.armor, in: research)) * 0.10
        return ships.reduce(0) { total, element in
            guard element.value > 0, let rule = ruleSet.shipRules[element.key] else {
                return total
            }

            return total + (max(rule.attack, 0) * weapons + max(rule.shield, 0) * shields * 0.5 + max(rule.hull, 0) * armor / 200) * Double(element.value)
        }
    }

    private static func defensePower(
        _ defenses: [DefenseKind: Int],
        research: ResearchState,
        ruleSet: RuleSet
    ) -> Double {
        let weapons = 1 + Double(TechnologyEffects.level(.weapons, in: research)) * 0.10
        let shields = 1 + Double(TechnologyEffects.level(.shielding, in: research)) * 0.10
        let armor = 1 + Double(TechnologyEffects.level(.armor, in: research)) * 0.10
        return defenses.reduce(0) { total, element in
            guard element.value > 0, let rule = ruleSet.defenseRules[element.key] else {
                return total
            }

            return total + (max(rule.attack, 0) * weapons + max(rule.shield, 0) * shields * 0.5 + max(rule.hull, 0) * armor / 200) * Double(element.value)
        }
    }

    private static func lossFraction(incoming: Double, own: Double) -> Double {
        guard incoming.isFinite, incoming > 0 else {
            return 0
        }
        guard own.isFinite, own > 0 else {
            return 1
        }

        let pressure = incoming / max(incoming + own, 1)
        return min(max(pressure * 0.85, 0), 0.95)
    }

    private static func destroyedShips(
        _ ships: [ShipKind: Int],
        fraction: Double,
        research: ResearchState,
        ruleSet: RuleSet
    ) -> [ShipKind: Int] {
        let totalQuantity = ships.values.reduce(0) { $0 + max($1, 0) }
        var remainingLosses = destroyedQuantity(totalQuantity, fraction: fraction)
        guard remainingLosses > 0 else {
            return [:]
        }

        let targetOrder = ships.keys.sorted {
            let lhsPower = shipUnitPower($0, research: research, ruleSet: ruleSet)
            let rhsPower = shipUnitPower($1, research: research, ruleSet: ruleSet)
            if lhsPower == rhsPower {
                return $0.rawValue < $1.rawValue
            }

            return lhsPower < rhsPower
        }

        var losses: [ShipKind: Int] = [:]
        for kind in targetOrder where remainingLosses > 0 {
            let destroyed = min(max(ships[kind] ?? 0, 0), remainingLosses)
            if destroyed > 0 {
                losses[kind] = destroyed
                remainingLosses -= destroyed
            }
        }

        return losses
    }

    private static func destroyedDefenses(_ defenses: [DefenseKind: Int], fraction: Double) -> [DefenseKind: Int] {
        defenses.reduce(into: [:]) { result, element in
            let destroyed = destroyedQuantity(element.value, fraction: fraction)
            if destroyed > 0 {
                result[element.key] = destroyed
            }
        }
    }

    private static func destroyedQuantity(_ quantity: Int, fraction: Double) -> Int {
        guard quantity > 0, fraction.isFinite, fraction > 0 else {
            return 0
        }

        let clampedFraction = min(fraction, 1)
        let raw = Double(quantity) * clampedFraction
        if raw >= 1 {
            return min(quantity, max(0, Int(raw.rounded())))
        }

        return clampedFraction >= 0.55 ? 1 : 0
    }

    private static func shipUnitPower(
        _ ship: ShipKind,
        research: ResearchState,
        ruleSet: RuleSet
    ) -> Double {
        shipPower([ship: 1], research: research, ruleSet: ruleSet)
    }

    private static func subtract<Key>(_ inventory: [Key: Int], _ losses: [Key: Int]) -> [Key: Int] {
        inventory.reduce(into: [:]) { result, element in
            let remaining = max(element.value, 0) - max(losses[element.key] ?? 0, 0)
            if remaining > 0 {
                result[element.key] = remaining
            }
        }
    }

    private static func normalizedShips(_ ships: [ShipKind: Int]) -> [ShipKind: Int] {
        ships.reduce(into: [:]) { result, element in
            let quantity = max(element.value, 0)
            if quantity > 0 {
                result[element.key, default: 0] += quantity
            }
        }
    }

    private static func normalizedDefenses(_ defenses: [DefenseKind: Int]) -> [DefenseKind: Int] {
        defenses.reduce(into: [:]) { result, element in
            let quantity = max(element.value, 0)
            if quantity > 0 {
                result[element.key, default: 0] += quantity
            }
        }
    }

    private static func roundVariation(seed: UInt64, round: Int, side: String) -> Double {
        let payload = "\(seed)|\(round)|\(side)"
        return 0.94 + Double(stableHash(payload) % 13) / 100
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
