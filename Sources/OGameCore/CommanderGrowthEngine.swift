public enum CommanderGrowthEngine {
    private static let experiencePerLevel: Double = 100
    private static let starCosts = [20, 40, 80, 160, 320]

    public static func train(
        _ commanderID: CommanderID,
        usingTrainingData amount: Int,
        in universe: inout Universe
    ) -> Bool {
        guard amount > 0,
              universe.commanderRoster.trainingData > 0,
              let index = universe.commanderRoster.ownedCommanders.firstIndex(where: { $0.id == commanderID })
        else {
            return false
        }

        let spent = min(amount, universe.commanderRoster.trainingData)
        universe.commanderRoster.trainingData -= spent
        addExperience(Double(spent), toCommanderAt: index, in: &universe)
        return true
    }

    public static func addExperience(_ amount: Double, to commanderID: CommanderID?, in universe: inout Universe) {
        guard amount.isFinite,
              amount > 0,
              let commanderID,
              let index = universe.commanderRoster.ownedCommanders.firstIndex(where: { $0.id == commanderID })
        else {
            return
        }

        addExperience(amount, toCommanderAt: index, in: &universe)
    }

    public static func promote(_ commanderID: CommanderID, in universe: inout Universe) -> Bool {
        guard let index = universe.commanderRoster.ownedCommanders.firstIndex(where: { $0.id == commanderID }) else {
            return false
        }
        let commander = universe.commanderRoster.ownedCommanders[index]
        guard let cost = shardCostForNextStar(currentStars: commander.stars),
              (universe.commanderRoster.shardsByDefinitionID[commander.definitionID] ?? 0) >= cost
        else {
            return false
        }

        let remaining = (universe.commanderRoster.shardsByDefinitionID[commander.definitionID] ?? 0) - cost
        universe.commanderRoster.shardsByDefinitionID[commander.definitionID] = remaining > 0 ? remaining : nil
        universe.commanderRoster.ownedCommanders[index].stars = min(commander.stars + 1, 5)
        return true
    }

    public static func levelCap(for rarity: CommanderRarity) -> Int {
        switch rarity {
        case .common:
            return 20
        case .elite:
            return 30
        case .epic:
            return 40
        case .legendary:
            return 50
        }
    }

    public static func shardCostForNextStar(currentStars: Int) -> Int? {
        guard currentStars >= 0, currentStars < starCosts.count else {
            return nil
        }
        return starCosts[currentStars]
    }

    private static func addExperience(_ amount: Double, toCommanderAt index: Int, in universe: inout Universe) {
        var commander = universe.commanderRoster.ownedCommanders[index]
        let cap = levelCap(for: commander.rarity)
        guard commander.level < cap else {
            commander.level = cap
            commander.experience = 0
            universe.commanderRoster.ownedCommanders[index] = commander
            return
        }

        commander.experience += amount
        while commander.experience >= experiencePerLevel && commander.level < cap {
            commander.experience -= experiencePerLevel
            commander.level += 1
        }
        if commander.level >= cap {
            commander.level = cap
            commander.experience = 0
        }
        universe.commanderRoster.ownedCommanders[index] = commander
    }
}
