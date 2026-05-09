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
    private enum Side {
        case attacker
        case defender
    }

    private enum CombatUnitKind: Hashable {
        case ship(ShipKind)
        case defense(DefenseKind)
    }

    private struct CombatUnit {
        var side: Side
        var kind: CombatUnitKind
        var attack: Double
        var maxShield: Double
        var shield: Double
        var maxHull: Double
        var hull: Double
        var isDestroyed: Bool
    }

    private struct RoundAccumulator {
        var attackerPower: Double = 0
        var defenderPower: Double = 0
        var attackerShots: Int = 0
        var defenderShots: Int = 0
        var rapidFireShots: Int = 0
        var shieldDamage: Double = 0
        var hullDamage: Double = 0
        var explodedUnits: Int = 0
    }

    private static let maximumRounds = 6
    private static let maximumShotsPerUnitTurn = 32

    public static func resolve(_ input: BattleSimulationInput) -> BattleSimulationResult {
        var units = combatUnits(for: input)
        var generator = SeededGenerator(seed: input.seed)
        var rounds: [BattleRoundSummary] = []

        for roundNumber in 1...maximumRounds {
            guard hasLivingUnits(on: .attacker, in: units),
                  hasLivingUnits(on: .defender, in: units)
            else {
                break
            }

            resetShields(in: &units)
            let attackerBeforeShips = shipCounts(on: .attacker, in: units)
            let defenderBeforeShips = shipCounts(on: .defender, in: units)
            let defenderBeforeDefenses = defenseCounts(on: .defender, in: units)
            let attackerFiringOrder = livingIndices(on: .attacker, in: units)
            let defenderFiringOrder = livingIndices(on: .defender, in: units)
            var accumulator = RoundAccumulator()

            for index in attackerFiringOrder {
                fireUnit(
                    at: index,
                    targetSide: .defender,
                    units: &units,
                    generator: &generator,
                    accumulator: &accumulator
                )
            }

            for index in defenderFiringOrder {
                fireUnit(
                    at: index,
                    targetSide: .attacker,
                    units: &units,
                    generator: &generator,
                    accumulator: &accumulator
                )
            }

            let attackerAfterShips = shipCounts(on: .attacker, in: units)
            let defenderAfterShips = shipCounts(on: .defender, in: units)
            let defenderAfterDefenses = defenseCounts(on: .defender, in: units)
            let attackerLosses = subtract(attackerBeforeShips, attackerAfterShips)
            let defenderShipLosses = subtract(defenderBeforeShips, defenderAfterShips)
            let defenderDefenseLosses = subtract(defenderBeforeDefenses, defenderAfterDefenses)

            rounds.append(
                BattleRoundSummary(
                    round: roundNumber,
                    attackerPower: accumulator.attackerPower,
                    defenderPower: accumulator.defenderPower,
                    attackerLosses: attackerLosses,
                    defenderShipLosses: defenderShipLosses,
                    defenderDefenseLosses: defenderDefenseLosses,
                    attackerShots: accumulator.attackerShots,
                    defenderShots: accumulator.defenderShots,
                    rapidFireShots: accumulator.rapidFireShots,
                    shieldDamage: accumulator.shieldDamage,
                    hullDamage: accumulator.hullDamage,
                    explodedUnits: accumulator.explodedUnits
                )
            )
        }

        let remainingAttackerShips = shipCounts(on: .attacker, in: units)
        let remainingDefenderShips = shipCounts(on: .defender, in: units)
        let remainingDefenderDefenses = defenseCounts(on: .defender, in: units)
        let attackerWon = !remainingAttackerShips.isEmpty &&
            remainingDefenderShips.isEmpty &&
            remainingDefenderDefenses.isEmpty

        return BattleSimulationResult(
            attackerWon: attackerWon,
            rounds: rounds,
            remainingAttackerShips: remainingAttackerShips,
            remainingDefenderShips: remainingDefenderShips,
            remainingDefenderDefenses: remainingDefenderDefenses
        )
    }

    private static func combatUnits(for input: BattleSimulationInput) -> [CombatUnit] {
        var units: [CombatUnit] = []
        appendShips(input.attackerShips, side: .attacker, research: input.attackerResearch, ruleSet: input.ruleSet, to: &units)
        appendShips(input.defenderShips, side: .defender, research: input.defenderResearch, ruleSet: input.ruleSet, to: &units)
        appendDefenses(input.defenderDefenses, side: .defender, research: input.defenderResearch, ruleSet: input.ruleSet, to: &units)
        return units
    }

    private static func appendShips(
        _ ships: [ShipKind: Int],
        side: Side,
        research: ResearchState,
        ruleSet: RuleSet,
        to units: inout [CombatUnit]
    ) {
        let attackMultiplier = multiplier(for: .weapons, research: research)
        let shieldMultiplier = multiplier(for: .shielding, research: research)
        let hullMultiplier = multiplier(for: .armor, research: research)

        for kind in ShipKind.allCases {
            let quantity = max(ships[kind] ?? 0, 0)
            guard quantity > 0, let rule = ruleSet.shipRules[kind] else {
                continue
            }

            let unit = CombatUnit(
                side: side,
                kind: .ship(kind),
                attack: safe(rule.attack) * attackMultiplier,
                maxShield: safe(rule.shield) * shieldMultiplier,
                shield: safe(rule.shield) * shieldMultiplier,
                maxHull: combatHull(rule.hull, multiplier: hullMultiplier),
                hull: combatHull(rule.hull, multiplier: hullMultiplier),
                isDestroyed: false
            )
            units.append(contentsOf: Array(repeating: unit, count: quantity))
        }
    }

    private static func appendDefenses(
        _ defenses: [DefenseKind: Int],
        side: Side,
        research: ResearchState,
        ruleSet: RuleSet,
        to units: inout [CombatUnit]
    ) {
        let attackMultiplier = multiplier(for: .weapons, research: research)
        let shieldMultiplier = multiplier(for: .shielding, research: research)
        let hullMultiplier = multiplier(for: .armor, research: research)

        for kind in DefenseKind.allCases {
            let quantity = max(defenses[kind] ?? 0, 0)
            guard quantity > 0, let rule = ruleSet.defenseRules[kind] else {
                continue
            }

            let unit = CombatUnit(
                side: side,
                kind: .defense(kind),
                attack: safe(rule.attack) * attackMultiplier,
                maxShield: safe(rule.shield) * shieldMultiplier,
                shield: safe(rule.shield) * shieldMultiplier,
                maxHull: combatHull(rule.hull, multiplier: hullMultiplier),
                hull: combatHull(rule.hull, multiplier: hullMultiplier),
                isDestroyed: false
            )
            units.append(contentsOf: Array(repeating: unit, count: quantity))
        }
    }

    private static func fireUnit(
        at shooterIndex: Int,
        targetSide: Side,
        units: inout [CombatUnit],
        generator: inout SeededGenerator,
        accumulator: inout RoundAccumulator
    ) {
        guard units.indices.contains(shooterIndex),
              units[shooterIndex].attack > 0
        else {
            return
        }

        var shotCount = 0
        var shouldContinue = true
        while shouldContinue && shotCount < maximumShotsPerUnitTurn {
            guard let targetIndex = randomLivingTarget(on: targetSide, in: units, generator: &generator) else {
                return
            }

            let shooterKind = units[shooterIndex].kind
            let targetKind = units[targetIndex].kind
            let attack = units[shooterIndex].attack
            shotCount += 1
            if units[shooterIndex].side == .attacker {
                accumulator.attackerShots += 1
                accumulator.attackerPower += attack
            } else {
                accumulator.defenderShots += 1
                accumulator.defenderPower += attack
            }

            applyDamage(
                attack,
                to: targetIndex,
                units: &units,
                generator: &generator,
                accumulator: &accumulator
            )

            let rapidFire = rapidFireValue(from: shooterKind, to: targetKind)
            if rapidFire > 1, generator.nextInt(in: 1...rapidFire) < rapidFire {
                accumulator.rapidFireShots += 1
                shouldContinue = true
            } else {
                shouldContinue = false
            }
        }
    }

    private static func applyDamage(
        _ rawDamage: Double,
        to targetIndex: Int,
        units: inout [CombatUnit],
        generator: inout SeededGenerator,
        accumulator: inout RoundAccumulator
    ) {
        guard units.indices.contains(targetIndex),
              !units[targetIndex].isDestroyed,
              rawDamage.isFinite,
              rawDamage > 0
        else {
            return
        }

        var remainingDamage = rawDamage
        let shieldAbsorbed = min(max(units[targetIndex].shield, 0), remainingDamage)
        if shieldAbsorbed > 0 {
            units[targetIndex].shield -= shieldAbsorbed
            remainingDamage -= shieldAbsorbed
            accumulator.shieldDamage += shieldAbsorbed
        }

        guard remainingDamage > 0 else {
            return
        }

        let hullDamage = min(units[targetIndex].hull, remainingDamage)
        units[targetIndex].hull -= hullDamage
        accumulator.hullDamage += hullDamage

        if units[targetIndex].hull <= 0 {
            units[targetIndex].isDestroyed = true
            accumulator.explodedUnits += 1
            return
        }

        let integrity = units[targetIndex].hull / max(units[targetIndex].maxHull, 1)
        guard integrity < 0.70 else {
            return
        }

        let explosionChance = min(max(Int(((1 - integrity) * 100).rounded(.down)), 1), 95)
        if generator.nextInt(in: 1...100) <= explosionChance {
            units[targetIndex].isDestroyed = true
            accumulator.explodedUnits += 1
        }
    }

    private static func resetShields(in units: inout [CombatUnit]) {
        for index in units.indices where !units[index].isDestroyed {
            units[index].shield = max(units[index].maxShield, 0)
        }
    }

    private static func randomLivingTarget(
        on side: Side,
        in units: [CombatUnit],
        generator: inout SeededGenerator
    ) -> Int? {
        let targets = units.indices.filter { units[$0].side == side && !units[$0].isDestroyed }
        guard !targets.isEmpty else {
            return nil
        }

        return targets[generator.nextInt(in: 0...(targets.count - 1))]
    }

    private static func livingIndices(on side: Side, in units: [CombatUnit]) -> [Int] {
        units.indices.filter { units[$0].side == side && !units[$0].isDestroyed }
    }

    private static func hasLivingUnits(on side: Side, in units: [CombatUnit]) -> Bool {
        units.contains { $0.side == side && !$0.isDestroyed }
    }

    private static func shipCounts(on side: Side, in units: [CombatUnit]) -> [ShipKind: Int] {
        units.reduce(into: [:]) { result, unit in
            guard unit.side == side, !unit.isDestroyed else {
                return
            }
            if case let .ship(kind) = unit.kind {
                result[kind, default: 0] += 1
            }
        }
    }

    private static func defenseCounts(on side: Side, in units: [CombatUnit]) -> [DefenseKind: Int] {
        units.reduce(into: [:]) { result, unit in
            guard unit.side == side, !unit.isDestroyed else {
                return
            }
            if case let .defense(kind) = unit.kind {
                result[kind, default: 0] += 1
            }
        }
    }

    private static func subtract<Key>(_ before: [Key: Int], _ after: [Key: Int]) -> [Key: Int] {
        before.reduce(into: [:]) { result, element in
            let lost = max(element.value, 0) - max(after[element.key] ?? 0, 0)
            if lost > 0 {
                result[element.key] = lost
            }
        }
    }

    private static func multiplier(for technology: TechnologyKind, research: ResearchState) -> Double {
        1 + Double(TechnologyEffects.level(technology, in: research)) * 0.10
    }

    private static func combatHull(_ hull: Double, multiplier: Double) -> Double {
        max((safe(hull) * multiplier) / 10, 1)
    }

    private static func rapidFireValue(from shooter: CombatUnitKind, to target: CombatUnitKind) -> Int {
        guard case let .ship(ship) = shooter else {
            return 1
        }

        switch (ship, target) {
        case (.smallCargo, .ship(.espionageProbe)), (.smallCargo, .ship(.solarSatellite)):
            return 5
        case (.largeCargo, .ship(.espionageProbe)), (.largeCargo, .ship(.solarSatellite)):
            return 5
        case (.lightFighter, .ship(.espionageProbe)), (.lightFighter, .ship(.solarSatellite)):
            return 5
        case (.heavyFighter, .ship(.espionageProbe)), (.heavyFighter, .ship(.solarSatellite)):
            return 5
        case (.heavyFighter, .ship(.smallCargo)):
            return 3
        case (.cruiser, .ship(.espionageProbe)), (.cruiser, .ship(.solarSatellite)):
            return 5
        case (.cruiser, .ship(.lightFighter)):
            return 6
        case (.cruiser, .defense(.rocketLauncher)):
            return 10
        case (.battleship, .ship(.espionageProbe)), (.battleship, .ship(.solarSatellite)):
            return 5
        case (.bomber, .ship(.espionageProbe)), (.bomber, .ship(.solarSatellite)):
            return 5
        case (.bomber, .defense(.rocketLauncher)), (.bomber, .defense(.lightLaser)):
            return 20
        case (.bomber, .defense(.heavyLaser)), (.bomber, .defense(.ionCannon)):
            return 10
        case (.destroyer, .ship(.espionageProbe)), (.destroyer, .ship(.solarSatellite)):
            return 5
        case (.destroyer, .ship(.battlecruiser)):
            return 2
        case (.destroyer, .defense(.plasmaTurret)):
            return 2
        case (.deathstar, .ship(.espionageProbe)), (.deathstar, .ship(.solarSatellite)):
            return 1_250
        case (.deathstar, .ship(.smallCargo)), (.deathstar, .ship(.largeCargo)), (.deathstar, .ship(.colonyShip)), (.deathstar, .ship(.recycler)):
            return 250
        case (.deathstar, .ship(.lightFighter)):
            return 200
        case (.deathstar, .ship(.heavyFighter)):
            return 100
        case (.deathstar, .ship(.cruiser)):
            return 33
        case (.deathstar, .ship(.battleship)):
            return 30
        case (.deathstar, .ship(.bomber)):
            return 25
        case (.deathstar, .ship(.destroyer)):
            return 5
        case (.deathstar, .ship(.battlecruiser)):
            return 15
        case (.deathstar, .defense(.rocketLauncher)), (.deathstar, .defense(.lightLaser)):
            return 200
        case (.deathstar, .defense(.heavyLaser)), (.deathstar, .defense(.ionCannon)):
            return 100
        case (.deathstar, .defense(.gaussCannon)):
            return 50
        case (.deathstar, .defense(.plasmaTurret)):
            return 20
        case (.battlecruiser, .ship(.espionageProbe)), (.battlecruiser, .ship(.solarSatellite)):
            return 5
        case (.battlecruiser, .ship(.smallCargo)):
            return 3
        case (.battlecruiser, .ship(.largeCargo)), (.battlecruiser, .ship(.heavyFighter)), (.battlecruiser, .ship(.cruiser)):
            return 4
        case (.battlecruiser, .ship(.battleship)):
            return 7
        default:
            return 1
        }
    }

    private static func safe(_ value: Double) -> Double {
        value.isFinite ? max(value, 0) : 0
    }
}
