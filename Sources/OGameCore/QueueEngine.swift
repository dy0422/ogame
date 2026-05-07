import Foundation

public enum QueueResult: Equatable, Sendable {
    case queued
    case insufficientResources
    case missingPlanet
    case missingFaction
    case queueBusy
    case missingRule
}

public enum QueueEngine {
    public static func startBuildingUpgrade(
        on planetID: PlanetID,
        in universe: inout Universe,
        kind: BuildingKind
    ) -> QueueResult {
        guard let planetIndex = universe.planets.firstIndex(where: { $0.id == planetID }) else {
            return .missingPlanet
        }

        guard universe.planets[planetIndex].buildQueue.isEmpty else {
            return .queueBusy
        }

        guard let rule = universe.ruleSet.buildingRules[kind] else {
            return .missingRule
        }

        let currentLevel = normalizedLevel(universe.planets[planetIndex].buildingLevels[kind] ?? 0)
        guard currentLevel < Int.max else {
            return .missingRule
        }

        let targetLevel = currentLevel + 1
        guard let terms = buildingTerms(rule: rule, targetLevel: targetLevel) else {
            return .missingRule
        }

        let paidCost = terms.cost

        guard universe.planets[planetIndex].resources.canAfford(paidCost) else {
            return .insufficientResources
        }

        let startTime = universe.gameTime
        let finishTime = startTime + terms.duration
        guard startTime.isFinite, finishTime.isFinite else {
            return .missingRule
        }

        let item = BuildQueueItem(
            id: queueItemID(
                namespace: "0004",
                payload: [
                    "building",
                    universe.id.rawValue.uuidString,
                    planetID.rawValue.uuidString,
                    kind.rawValue,
                    String(targetLevel),
                    String(startTime),
                    String(finishTime),
                    resourcePayload(paidCost)
                ].joined(separator: "|")
            ),
            planetID: planetID,
            buildingKind: kind,
            targetLevel: targetLevel,
            startTime: startTime,
            finishTime: finishTime,
            paidCost: paidCost
        )

        universe.planets[planetIndex].resources = universe.planets[planetIndex].resources.subtracting(paidCost)
        universe.planets[planetIndex].buildQueue = [item]

        return .queued
    }

    public static func startResearch(
        for factionID: FactionID,
        in universe: inout Universe,
        technology: TechnologyKind
    ) -> QueueResult {
        guard let factionIndex = universe.factions.firstIndex(where: { $0.id == factionID }) else {
            return .missingFaction
        }

        guard universe.factions[factionIndex].researchQueue.isEmpty else {
            return .queueBusy
        }

        guard let rule = universe.ruleSet.researchRules[technology] else {
            return .missingRule
        }

        guard let planetIndex = paymentPlanetIndex(for: universe.factions[factionIndex], in: universe) else {
            return .missingPlanet
        }

        let currentLevel = normalizedLevel(universe.factions[factionIndex].technology.levels[technology] ?? 0)
        guard currentLevel < Int.max else {
            return .missingRule
        }

        let targetLevel = currentLevel + 1
        guard let terms = researchTerms(rule: rule, targetLevel: targetLevel) else {
            return .missingRule
        }

        let paidCost = terms.cost

        guard universe.planets[planetIndex].resources.canAfford(paidCost) else {
            return .insufficientResources
        }

        let startTime = universe.gameTime
        let finishTime = startTime + terms.duration
        guard startTime.isFinite, finishTime.isFinite else {
            return .missingRule
        }

        let item = ResearchQueueItem(
            id: queueItemID(
                namespace: "0005",
                payload: [
                    "research",
                    universe.id.rawValue.uuidString,
                    factionID.rawValue.uuidString,
                    technology.rawValue,
                    String(targetLevel),
                    String(startTime),
                    String(finishTime),
                    resourcePayload(paidCost)
                ].joined(separator: "|")
            ),
            factionID: factionID,
            technologyKind: technology,
            targetLevel: targetLevel,
            startTime: startTime,
            finishTime: finishTime,
            paidCost: paidCost
        )

        universe.planets[planetIndex].resources = universe.planets[planetIndex].resources.subtracting(paidCost)
        universe.factions[factionIndex].researchQueue = [item]

        return .queued
    }

    public static func completeDueItems(in universe: inout Universe) {
        guard universe.gameTime.isFinite else {
            return
        }

        let completionTime = universe.gameTime

        for planetIndex in universe.planets.indices {
            let dueItems = universe.planets[planetIndex].buildQueue
                .filter { $0.finishTime.isFinite && $0.finishTime <= completionTime }
                .sorted(by: compareBuildQueueItems)

            guard !dueItems.isEmpty else {
                continue
            }

            for item in dueItems {
                let currentLevel = normalizedLevel(universe.planets[planetIndex].buildingLevels[item.buildingKind] ?? 0)
                universe.planets[planetIndex].buildingLevels[item.buildingKind] = max(currentLevel, item.targetLevel)
                universe.events.append(constructionCompletionEvent(for: item, planet: universe.planets[planetIndex], time: item.finishTime))
            }

            let dueIDs = Set(dueItems.map(\.id))
            universe.planets[planetIndex].buildQueue.removeAll { dueIDs.contains($0.id) }
            EconomyEngine.recomputeEnergy(for: &universe.planets[planetIndex], ruleSet: universe.ruleSet)
        }

        for factionIndex in universe.factions.indices {
            let dueItems = universe.factions[factionIndex].researchQueue
                .filter { $0.finishTime.isFinite && $0.finishTime <= completionTime }
                .sorted(by: compareResearchQueueItems)

            guard !dueItems.isEmpty else {
                continue
            }

            for item in dueItems {
                let currentLevel = normalizedLevel(universe.factions[factionIndex].technology.levels[item.technologyKind] ?? 0)
                universe.factions[factionIndex].technology.levels[item.technologyKind] = max(currentLevel, item.targetLevel)
                universe.events.append(researchCompletionEvent(for: item, faction: universe.factions[factionIndex], time: item.finishTime))
            }

            let dueIDs = Set(dueItems.map(\.id))
            universe.factions[factionIndex].researchQueue.removeAll { dueIDs.contains($0.id) }
        }
    }

    private static func paymentPlanetIndex(for faction: Faction, in universe: Universe) -> Int? {
        for planetID in faction.ownedPlanetIDs {
            if let index = universe.planets.firstIndex(where: { $0.id == planetID && $0.ownerID == faction.id }) {
                return index
            }
        }

        return nil
    }

    private static func buildingTerms(rule: BuildingRule, targetLevel: Int) -> (cost: ResourceBundle, duration: TimeInterval)? {
        guard
            isValidCost(rule.baseCost),
            rule.costMultiplier.isFinite,
            rule.costMultiplier > 0,
            rule.baseDuration.isFinite,
            rule.baseDuration > 0,
            rule.durationMultiplier.isFinite,
            rule.durationMultiplier > 0
        else {
            return nil
        }

        let exponent = Double(max(targetLevel - 1, 0))
        let costMultiplier = pow(rule.costMultiplier, exponent)
        let durationMultiplier = pow(rule.durationMultiplier, exponent)
        guard costMultiplier.isFinite, durationMultiplier.isFinite else {
            return nil
        }

        let cost = rule.baseCost.scaled(by: costMultiplier)
        let duration = rule.baseDuration * durationMultiplier
        guard isValidCost(cost), duration.isFinite, duration > 0 else {
            return nil
        }

        return (cost, duration)
    }

    private static func researchTerms(rule: ResearchRule, targetLevel: Int) -> (cost: ResourceBundle, duration: TimeInterval)? {
        guard
            isValidCost(rule.baseCost),
            rule.costMultiplier.isFinite,
            rule.costMultiplier > 0,
            rule.baseDuration.isFinite,
            rule.baseDuration > 0,
            rule.durationMultiplier.isFinite,
            rule.durationMultiplier > 0
        else {
            return nil
        }

        let exponent = Double(max(targetLevel - 1, 0))
        let costMultiplier = pow(rule.costMultiplier, exponent)
        let durationMultiplier = pow(rule.durationMultiplier, exponent)
        guard costMultiplier.isFinite, durationMultiplier.isFinite else {
            return nil
        }

        let cost = rule.baseCost.scaled(by: costMultiplier)
        let duration = rule.baseDuration * durationMultiplier
        guard isValidCost(cost), duration.isFinite, duration > 0 else {
            return nil
        }

        return (cost, duration)
    }

    private static func isValidCost(_ cost: ResourceBundle) -> Bool {
        cost.metal.isFinite &&
            cost.crystal.isFinite &&
            cost.deuterium.isFinite &&
            cost.metal >= 0 &&
            cost.crystal >= 0 &&
            cost.deuterium >= 0
    }

    private static func normalizedLevel(_ level: Int) -> Int {
        max(level, 0)
    }

    private static func constructionCompletionEvent(for item: BuildQueueItem, planet: Planet, time: TimeInterval) -> GameEvent {
        GameEvent(
            id: EventID(
                queueItemID(
                    namespace: "0006",
                    payload: [
                        "construction-complete",
                        item.id.uuidString,
                        planet.id.rawValue.uuidString,
                        item.buildingKind.rawValue,
                        String(item.targetLevel),
                        String(time)
                    ].joined(separator: "|")
                )
            ),
            time: time,
            kind: .economy,
            title: "Construction Complete",
            message: "\(planet.name) completed \(item.buildingKind.rawValue) level \(item.targetLevel)."
        )
    }

    private static func researchCompletionEvent(for item: ResearchQueueItem, faction: Faction, time: TimeInterval) -> GameEvent {
        GameEvent(
            id: EventID(
                queueItemID(
                    namespace: "0007",
                    payload: [
                        "research-complete",
                        item.id.uuidString,
                        faction.id.rawValue.uuidString,
                        item.technologyKind.rawValue,
                        String(item.targetLevel),
                        String(time)
                    ].joined(separator: "|")
                )
            ),
            time: time,
            kind: .economy,
            title: "Research Complete",
            message: "\(faction.name) completed \(item.technologyKind.rawValue) level \(item.targetLevel)."
        )
    }

    private static func compareBuildQueueItems(_ lhs: BuildQueueItem, _ rhs: BuildQueueItem) -> Bool {
        if lhs.finishTime != rhs.finishTime {
            return lhs.finishTime < rhs.finishTime
        }

        if lhs.buildingKind.rawValue != rhs.buildingKind.rawValue {
            return lhs.buildingKind.rawValue < rhs.buildingKind.rawValue
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func compareResearchQueueItems(_ lhs: ResearchQueueItem, _ rhs: ResearchQueueItem) -> Bool {
        if lhs.finishTime != rhs.finishTime {
            return lhs.finishTime < rhs.finishTime
        }

        if lhs.technologyKind.rawValue != rhs.technologyKind.rawValue {
            return lhs.technologyKind.rawValue < rhs.technologyKind.rawValue
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func queueItemID(namespace: String, payload: String) -> UUID {
        let tail = String(format: "%012llx", stableHash(payload) & 0x0000_FFFF_FFFF_FFFF)
        return UUID(uuidString: "00000000-0000-0000-\(namespace)-\(tail)")!
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037

        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return hash
    }

    private static func resourcePayload(_ resources: ResourceBundle) -> String {
        "\(resources.metal),\(resources.crystal),\(resources.deuterium)"
    }
}
