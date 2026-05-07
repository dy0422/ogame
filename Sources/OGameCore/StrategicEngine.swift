import Foundation

public enum StrategicEngine {
    private static let economyVictoryTarget = 25_000.0
    private static let technologyVictoryTarget = 24.0
    private static let dominationVictoryTarget = 0.75
    private static let maxExplorationRecords = 128

    public static func rankings(in universe: Universe) -> [FactionScore] {
        let progress = victoryProgress(in: universe)
        let progressByFaction = Dictionary(grouping: progress, by: \.factionID)
        var scores = universe.factions.map { faction in
            score(for: faction, in: universe, progress: progressByFaction[faction.id] ?? [])
        }

        scores.sort { lhs, rhs in
            if lhs.totalScore != rhs.totalScore {
                return lhs.totalScore > rhs.totalScore
            }
            if lhs.factionName != rhs.factionName {
                return lhs.factionName < rhs.factionName
            }
            return lhs.factionID.rawValue.uuidString < rhs.factionID.rawValue.uuidString
        }

        for index in scores.indices {
            scores[index].rank = index + 1
        }

        return scores
    }

    public static func explorationRecords(for factionID: FactionID, in universe: Universe) -> [ExplorationRecord] {
        normalizedExplorationRecords(in: universe)
            .filter { $0.factionID == factionID }
    }

    public static func updateStrategicState(in universe: inout Universe) {
        universe.explorationRecords = normalizedExplorationRecords(in: universe)
        let exploredPlanetIDs = normalizedExploredPlanetIDs(for: universe.playerFactionID, in: universe)
        let progress = victoryProgress(in: universe, playerExploredPlanetIDs: exploredPlanetIDs)
        let previousWinner = universe.victoryState.winningFactionID
        let previousRoute = universe.victoryState.winningRoute
        let previousAchievedAt = universe.victoryState.achievedAt
        var didAnnounceVictory = universe.victoryState.didAnnounceVictory

        var winningFactionID = previousWinner
        var winningRoute = previousRoute
        var achievedAt = previousAchievedAt

        if winningFactionID == nil, let completed = firstCompletedProgress(progress) {
            winningFactionID = completed.factionID
            winningRoute = completed.route
            achievedAt = universe.gameTime
            didAnnounceVictory = false
        }

        universe.victoryState = VictoryState(
            progress: progress,
            winningFactionID: winningFactionID,
            winningRoute: winningRoute,
            achievedAt: achievedAt,
            didAnnounceVictory: didAnnounceVictory,
            exploredPlanetIDs: exploredPlanetIDs
        )
        universe.rankings = rankings(in: universe)

        if universe.victoryState.winningFactionID != nil, !universe.victoryState.didAnnounceVictory {
            universe.events.append(victoryEvent(in: universe))
            universe.victoryState.didAnnounceVictory = true
        }
    }

    private static func score(
        for faction: Faction,
        in universe: Universe,
        progress: [VictoryProgress]
    ) -> FactionScore {
        let ownedPlanets = universe.planets.filter { $0.ownerID == faction.id }
        let economyScore = economyScore(for: ownedPlanets, ruleSet: universe.ruleSet)
        let fleetScore = fleetScore(for: faction.id, ownedPlanets: ownedPlanets, universe: universe)
        let researchScore = researchScore(for: faction, ruleSet: universe.ruleSet)
        let planetScore = Double(ownedPlanets.count) * 1_500
        let defenseScore = defenseScore(for: ownedPlanets, ruleSet: universe.ruleSet)
        let victoryProgress = progress.map { sanitizedNonnegative($0.progress) }.max() ?? 0
        let totalScore = sanitizedNonnegative(economyScore +
            fleetScore +
            researchScore +
            planetScore +
            defenseScore +
            (victoryProgress * 5_000))

        return FactionScore(
            factionID: faction.id,
            factionName: faction.name,
            economyScore: sanitizedNonnegative(economyScore),
            fleetScore: sanitizedNonnegative(fleetScore),
            researchScore: sanitizedNonnegative(researchScore),
            planetScore: sanitizedNonnegative(planetScore),
            defenseScore: sanitizedNonnegative(defenseScore),
            victoryProgress: victoryProgress,
            totalScore: totalScore
        )
    }

    private static func economyScore(for planets: [Planet], ruleSet: RuleSet) -> Double {
        planets.reduce(0) { total, planet in
            let buildingScore = planet.buildingLevels.reduce(0) { partial, element in
                sanitizedNonnegative(partial + (sanitizedQuantity(element.value) * 100))
            }
            let stockpileScore = resourceValue(planet.resources) * 0.1
            let productionScore = resourceValue(EconomyEngine.productionPerHour(for: planet, ruleSet: ruleSet))

            return sanitizedNonnegative(total + buildingScore + stockpileScore + productionScore)
        }
    }

    private static func fleetScore(for factionID: FactionID, ownedPlanets: [Planet], universe: Universe) -> Double {
        let dockedScore = ownedPlanets.reduce(0) { total, planet in
            sanitizedNonnegative(total + shipInventoryScore(planet.shipInventory, ruleSet: universe.ruleSet))
        }
        let activeScore = universe.fleets
            .filter { $0.ownerID == factionID }
            .reduce(0) { total, fleet in
                sanitizedNonnegative(total + shipInventoryScore(fleet.ships, ruleSet: universe.ruleSet))
            }

        return sanitizedNonnegative(dockedScore + activeScore)
    }

    private static func researchScore(for faction: Faction, ruleSet: RuleSet) -> Double {
        faction.technology.levels.reduce(0) { total, element in
            let level = sanitizedQuantity(element.value)
            guard level > 0 else {
                return total
            }

            let baseValue = resourceValue(ruleSet.researchRules[element.key]?.baseCost ?? .zero)
            return sanitizedNonnegative(total + max(baseValue, 400) * level)
        }
    }

    private static func defenseScore(for planets: [Planet], ruleSet: RuleSet) -> Double {
        planets.reduce(0) { total, planet in
            let planetScore = planet.defenseInventory.reduce(0) { partial, element in
                let quantity = sanitizedQuantity(element.value)
                guard quantity > 0, let rule = ruleSet.defenseRules[element.key] else {
                    return partial
                }

                let combatValue = sanitizedNonnegative(rule.attack) +
                    sanitizedNonnegative(rule.shield) +
                    sanitizedNonnegative(rule.hull)
                return sanitizedNonnegative(partial + ((resourceValue(rule.baseCost) + combatValue) * quantity))
            }
            return sanitizedNonnegative(total + planetScore)
        }
    }

    private static func shipInventoryScore(_ ships: [ShipKind: Int], ruleSet: RuleSet) -> Double {
        ships.reduce(0) { total, element in
            let quantity = sanitizedQuantity(element.value)
            guard quantity > 0, let rule = ruleSet.shipRules[element.key] else {
                return total
            }

            let combatValue = sanitizedNonnegative(rule.attack) +
                sanitizedNonnegative(rule.shield) +
                sanitizedNonnegative(rule.hull)
            let unitValue = resourceValue(rule.baseCost) + combatValue + sanitizedNonnegative(rule.cargoCapacity)
            return sanitizedNonnegative(total + (unitValue * quantity))
        }
    }

    private static func victoryProgress(in universe: Universe) -> [VictoryProgress] {
        victoryProgress(
            in: universe,
            playerExploredPlanetIDs: normalizedExploredPlanetIDs(for: universe.playerFactionID, in: universe)
        )
    }

    private static func victoryProgress(in universe: Universe, playerExploredPlanetIDs: [PlanetID]) -> [VictoryProgress] {
        let rawInhabitedPlanetCount = universe.planets.filter { $0.ownerID != nil }.count
        let inhabitedPlanetCount = max(rawInhabitedPlanetCount, 1)
        let neutralPlanetIDs = Set(universe.planets.filter { $0.ownerID == nil }.map(\.id))
        let explorationTarget = neutralPlanetIDs.count

        return universe.factions.flatMap { faction in
            let ownedPlanets = universe.planets.filter { $0.ownerID == faction.id }
            let exploredPlanetIDs = faction.id == universe.playerFactionID
                ? playerExploredPlanetIDs
                : normalizedExploredPlanetIDs(for: faction.id, in: universe)
            let exploredNeutralCount = exploredPlanetIDs.filter { neutralPlanetIDs.contains($0) }.count
            let economyValue = sanitizedNonnegative(economyScore(for: ownedPlanets, ruleSet: universe.ruleSet))
            let technologyValue = sanitizedNonnegative(
                faction.technology.levels.values.reduce(0) { $0 + sanitizedQuantity($1) } +
                    lateGameObjectiveValue(for: ownedPlanets)
            )
            let dominationValue = rawInhabitedPlanetCount >= 3
                ? Double(ownedPlanets.count) / Double(inhabitedPlanetCount)
                : 0
            let explorationValue = explorationTarget > 0
                ? sanitizedQuantity(exploredNeutralCount)
                : 0

            return [
                VictoryProgress(
                    factionID: faction.id,
                    route: .economy,
                    currentValue: economyValue,
                    targetValue: economyVictoryTarget,
                    progress: normalizedProgress(current: economyValue, target: economyVictoryTarget)
                ),
                VictoryProgress(
                    factionID: faction.id,
                    route: .technology,
                    currentValue: technologyValue,
                    targetValue: technologyVictoryTarget,
                    progress: normalizedProgress(current: technologyValue, target: technologyVictoryTarget)
                ),
                VictoryProgress(
                    factionID: faction.id,
                    route: .domination,
                    currentValue: dominationValue,
                    targetValue: dominationVictoryTarget,
                    progress: normalizedProgress(current: dominationValue, target: dominationVictoryTarget)
                ),
                VictoryProgress(
                    factionID: faction.id,
                    route: .exploration,
                    currentValue: explorationValue,
                    targetValue: Double(explorationTarget),
                    progress: explorationTarget > 0
                        ? normalizedProgress(current: explorationValue, target: Double(explorationTarget))
                        : 0
                )
            ]
        }
    }

    private static func firstCompletedProgress(_ progress: [VictoryProgress]) -> VictoryProgress? {
        progress
            .filter(\.isComplete)
            .sorted { lhs, rhs in
                if lhs.route != rhs.route {
                    let lhsIndex = VictoryRoute.allCases.firstIndex(of: lhs.route) ?? 0
                    let rhsIndex = VictoryRoute.allCases.firstIndex(of: rhs.route) ?? 0
                    return lhsIndex < rhsIndex
                }
                return lhs.factionID.rawValue.uuidString < rhs.factionID.rawValue.uuidString
            }
            .first
    }

    private static func lateGameObjectiveValue(for planets: [Planet]) -> Double {
        sanitizedQuantity(planets.filter { $0.moon != nil }.count)
    }

    private static func normalizedProgress(current: Double, target: Double) -> Double {
        let current = sanitizedNonnegative(current)
        let target = sanitizedNonnegative(target)
        guard target > 0 else {
            return 0
        }

        return min(max(current / target, 0), 1)
    }

    private static func normalizedExploredPlanetIDs(for factionID: FactionID, in universe: Universe) -> [PlanetID] {
        let recordPlanetIDs = explorationRecords(for: factionID, in: universe).map(\.targetPlanetID)
        let legacyPlanetIDs = factionID == universe.playerFactionID ? universe.victoryState.exploredPlanetIDs : []
        let exploredSet = Set(legacyPlanetIDs + recordPlanetIDs)

        return universe.planets
            .map(\.id)
            .filter { exploredSet.contains($0) }
    }

    private static func normalizedExplorationRecords(in universe: Universe) -> [ExplorationRecord] {
        let knownPlanetIDs = Set(universe.planets.map(\.id))
        let knownFactionIDs = Set(universe.factions.map(\.id))
        var latestByPair: [String: ExplorationRecord] = [:]

        for record in universe.explorationRecords {
            guard knownFactionIDs.contains(record.factionID),
                  knownPlanetIDs.contains(record.targetPlanetID)
            else {
                continue
            }

            let key = explorationRecordKey(factionID: record.factionID, targetPlanetID: record.targetPlanetID)
            if let existing = latestByPair[key],
               explorationRecordSortKey(existing) >= explorationRecordSortKey(record)
            {
                continue
            }

            latestByPair[key] = ExplorationRecord(
                factionID: record.factionID,
                targetPlanetID: record.targetPlanetID,
                exploredAt: record.exploredAt,
                reward: record.reward,
                discoveredResources: record.discoveredResources,
                discoveredDebris: record.discoveredDebris,
                discoveredOwnerID: record.discoveredOwnerID,
                discoveredNeutral: record.discoveredNeutral
            )
        }

        return Array(latestByPair.values
            .sorted { lhs, rhs in
                let lhsKey = explorationRecordSortKey(lhs)
                let rhsKey = explorationRecordSortKey(rhs)
                if lhsKey != rhsKey {
                    return lhsKey < rhsKey
                }

                return explorationRecordKey(factionID: lhs.factionID, targetPlanetID: lhs.targetPlanetID) <
                    explorationRecordKey(factionID: rhs.factionID, targetPlanetID: rhs.targetPlanetID)
            }
            .suffix(maxExplorationRecords))
    }

    private static func explorationRecordSortKey(_ record: ExplorationRecord) -> String {
        [
            String(format: "%020.6f", record.exploredAt),
            record.factionID.rawValue.uuidString,
            record.targetPlanetID.rawValue.uuidString
        ].joined(separator: "|")
    }

    private static func explorationRecordKey(factionID: FactionID, targetPlanetID: PlanetID) -> String {
        "\(factionID.rawValue.uuidString)|\(targetPlanetID.rawValue.uuidString)"
    }

    private static func resourceValue(_ resources: ResourceBundle) -> Double {
        sanitizedNonnegative(
            sanitizedNonnegative(resources.metal) +
                sanitizedNonnegative(resources.crystal) +
                sanitizedNonnegative(resources.deuterium)
        )
    }

    private static func sanitizedQuantity(_ quantity: Int) -> Double {
        sanitizedNonnegative(Double(max(quantity, 0)))
    }

    private static func sanitizedNonnegative(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else {
            return 0
        }

        return value
    }

    private static func victoryEvent(in universe: Universe) -> GameEvent {
        let winnerName = universe.factions.first { $0.id == universe.victoryState.winningFactionID }?.name ?? "Unknown faction"
        let routeName = universe.victoryState.winningRoute?.rawValue ?? "strategic"

        return GameEvent(
            id: victoryEventID(index: universe.events.count + 1),
            time: universe.gameTime,
            kind: .victory,
            title: "Victory Achieved",
            message: "\(winnerName) completed the \(routeName) victory route."
        )
    }

    private static func victoryEventID(index: Int) -> EventID {
        EventID(UUID(uuidString: String(format: "00000000-0000-0000-000d-%012d", index))!)
    }
}
