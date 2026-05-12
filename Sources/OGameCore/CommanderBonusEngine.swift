public struct CommanderFleetBonus: Equatable, Sendable {
    public var attackMultiplier: Double
    public var shieldMultiplier: Double
    public var hullMultiplier: Double
    public var speedMultiplier: Double
    public var fuelMultiplier: Double
    public var cargoMultiplier: Double
    public var lootMultiplier: Double
    public var expeditionRewardMultiplier: Double
    public var expeditionRiskModifier: Double

    public init(
        attackMultiplier: Double = 1,
        shieldMultiplier: Double = 1,
        hullMultiplier: Double = 1,
        speedMultiplier: Double = 1,
        fuelMultiplier: Double = 1,
        cargoMultiplier: Double = 1,
        lootMultiplier: Double = 1,
        expeditionRewardMultiplier: Double = 1,
        expeditionRiskModifier: Double = 0
    ) {
        self.attackMultiplier = attackMultiplier.isFinite ? max(attackMultiplier, 0) : 1
        self.shieldMultiplier = shieldMultiplier.isFinite ? max(shieldMultiplier, 0) : 1
        self.hullMultiplier = hullMultiplier.isFinite ? max(hullMultiplier, 0) : 1
        self.speedMultiplier = speedMultiplier.isFinite ? max(speedMultiplier, 0.1) : 1
        self.fuelMultiplier = fuelMultiplier.isFinite ? min(max(fuelMultiplier, 0.1), 2) : 1
        self.cargoMultiplier = cargoMultiplier.isFinite ? max(cargoMultiplier, 0) : 1
        self.lootMultiplier = lootMultiplier.isFinite ? max(lootMultiplier, 0) : 1
        self.expeditionRewardMultiplier = expeditionRewardMultiplier.isFinite ? max(expeditionRewardMultiplier, 0) : 1
        self.expeditionRiskModifier = expeditionRiskModifier.isFinite ? min(max(expeditionRiskModifier, -0.5), 0.5) : 0
    }

    public static let none = CommanderFleetBonus()
}

public enum CommanderBonusEngine {
    public static func fleetBonus(for commander: OwnedCommander?, in universe: Universe) -> CommanderFleetBonus {
        guard let commander,
              let definition = CommanderCatalog.definition(id: commander.definitionID)
        else {
            return .none
        }

        let power = rarityBase(for: commander.rarity) +
            Double(max(commander.level, 1)) * 0.0025 +
            Double(max(commander.stars, 0)) * 0.01

        switch definition.specialty {
        case .fleetAdmiral:
            return CommanderFleetBonus(
                attackMultiplier: 1 + power,
                speedMultiplier: 1 + power * 0.6
            )
        case .engineer:
            return CommanderFleetBonus(
                shieldMultiplier: 1 + power,
                hullMultiplier: 1 + power * 0.8,
                fuelMultiplier: 1 - min(power * 0.5, 0.15)
            )
        case .geologist:
            return CommanderFleetBonus(
                cargoMultiplier: 1 + power,
                lootMultiplier: 1 + power * 0.75
            )
        case .technocrat:
            return CommanderFleetBonus(
                attackMultiplier: 1 + power * 0.5,
                shieldMultiplier: 1 + power * 0.35
            )
        case .explorer:
            return CommanderFleetBonus(
                expeditionRewardMultiplier: 1 + power,
                expeditionRiskModifier: -min(power * 0.5, 0.12)
            )
        }
    }

    public static func fleetBonus(for commanderID: CommanderID?, in universe: Universe) -> CommanderFleetBonus {
        guard let commanderID,
              let commander = universe.commanderRoster.ownedCommanders.first(where: { $0.id == commanderID })
        else {
            return .none
        }
        return fleetBonus(for: commander, in: universe)
    }

    public static func summaryText(for commander: OwnedCommander, in universe: Universe) -> String {
        guard let definition = CommanderCatalog.definition(id: commander.definitionID) else {
            return "未知指挥官"
        }

        let bonus = fleetBonus(for: commander, in: universe)
        switch definition.specialty {
        case .fleetAdmiral:
            return "攻击 +\(percent(bonus.attackMultiplier - 1))%，航速 +\(percent(bonus.speedMultiplier - 1))%"
        case .engineer:
            return "护盾 +\(percent(bonus.shieldMultiplier - 1))%，结构 +\(percent(bonus.hullMultiplier - 1))%，油耗 -\(percent(1 - bonus.fuelMultiplier))%"
        case .geologist:
            return "货舱 +\(percent(bonus.cargoMultiplier - 1))%，掠夺 +\(percent(bonus.lootMultiplier - 1))%"
        case .technocrat:
            return "火控 +\(percent(bonus.attackMultiplier - 1))%，护盾校准 +\(percent(bonus.shieldMultiplier - 1))%"
        case .explorer:
            return "远征收益 +\(percent(bonus.expeditionRewardMultiplier - 1))%，风险 -\(percent(-bonus.expeditionRiskModifier))%"
        }
    }

    private static func rarityBase(for rarity: CommanderRarity) -> Double {
        switch rarity {
        case .common:
            return 0.01
        case .elite:
            return 0.025
        case .epic:
            return 0.04
        case .legendary:
            return 0.06
        }
    }

    private static func percent(_ value: Double) -> Int {
        guard value.isFinite else {
            return 0
        }
        return Int((value * 100).rounded())
    }
}
