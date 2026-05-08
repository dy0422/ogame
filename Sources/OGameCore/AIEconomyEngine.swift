import Foundation

public enum AIEconomyEngine {
    private static let serverGrowthBase = 1.1

    public static func makeDecisions(in universe: inout Universe) {
        let aiFactionIDs = universe.factions
            .filter { $0.kind == .ai && $0.id != universe.playerFactionID }
            .sorted(by: compareFactions)
            .map(\.id)

        for factionID in aiFactionIDs {
            let candidates = rankedCandidates(for: factionID, in: universe)

            for candidate in candidates {
                if candidate.start(in: &universe) == .queued {
                    break
                }
            }
        }
    }

    private static func rankedCandidates(for factionID: FactionID, in universe: Universe) -> [Candidate] {
        guard let faction = universe.factions.first(where: { $0.id == factionID }) else {
            return []
        }

        guard !hasActiveQueue(for: faction, in: universe) else {
            return []
        }

        let planets = ownedPlanets(for: faction, in: universe)
        guard !planets.isEmpty else {
            return []
        }

        let buildingOptions = planets.flatMap { planet in
            buildingCandidates(for: faction, planet: planet, in: universe)
        }
        let researchOptions = researchCandidates(for: faction, planets: planets, in: universe)

        return (buildingOptions + researchOptions).sorted(by: compareCandidates)
    }

    private static func buildingCandidates(
        for faction: Faction,
        planet: Planet,
        in universe: Universe
    ) -> [Candidate] {
        guard planet.buildQueue.isEmpty else {
            return []
        }

        let levels = normalizedBuildingLevels(for: planet)
        let energy = energyState(for: planet, ruleSet: universe.ruleSet)

        return BuildingKind.allCases.compactMap { kind in
            guard let rule = universe.ruleSet.buildingRules[kind] else {
                return nil
            }

            let currentLevel = levels[kind] ?? 0
            let targetLevel = currentLevel + 1
            guard
                let terms = buildingTerms(rule: rule, targetLevel: targetLevel),
                planet.resources.canAfford(terms.cost)
            else {
                return nil
            }

            let score = buildingScore(
                kind: kind,
                rule: rule,
                currentLevel: currentLevel,
                strategy: faction.strategy,
                planet: planet,
                energy: energy,
                cost: terms.cost,
                universe: universe,
                factionID: faction.id
            )
            return Candidate(
                action: .building(planetID: planet.id, kind: kind),
                score: score,
                tieBreaker: tieBreaker(
                    universe: universe,
                    factionID: faction.id,
                    payload: "building|\(planet.id.rawValue.uuidString)|\(kind.rawValue)|\(targetLevel)"
                )
            )
        }
    }

    private static func researchCandidates(
        for faction: Faction,
        planets: [Planet],
        in universe: Universe
    ) -> [Candidate] {
        guard faction.researchQueue.isEmpty else {
            return []
        }

        guard planets.contains(where: { normalizedBuildingLevels(for: $0)[.researchLab, default: 0] > 0 }) else {
            return []
        }

        guard let paymentPlanet = researchPaymentPlanet(for: faction, in: universe) else {
            return []
        }

        return TechnologyKind.allCases.compactMap { technology in
            guard let rule = universe.ruleSet.researchRules[technology] else {
                return nil
            }

            let currentLevel = normalizedTechnologyLevel(faction.technology.levels[technology] ?? 0)
            let targetLevel = currentLevel + 1
            guard
                let terms = researchTerms(rule: rule, targetLevel: targetLevel),
                paymentPlanet.resources.canAfford(terms.cost)
            else {
                return nil
            }

            let score = researchScore(
                technology: technology,
                rule: rule,
                currentLevel: currentLevel,
                strategy: faction.strategy,
                resources: paymentPlanet.resources,
                cost: terms.cost
            )
            return Candidate(
                action: .research(factionID: faction.id, technology: technology),
                score: score,
                tieBreaker: tieBreaker(
                    universe: universe,
                    factionID: faction.id,
                    payload: "research|\(technology.rawValue)|\(targetLevel)"
                )
            )
        }
    }

    private static func buildingScore(
        kind: BuildingKind,
        rule: BuildingRule,
        currentLevel: Int,
        strategy: Faction.Strategy,
        planet: Planet,
        energy: EnergyState,
        cost: ResourceBundle,
        universe: Universe,
        factionID: FactionID
    ) -> Double {
        let levels = normalizedBuildingLevels(for: planet)
        let strategicWeight = buildingStrategyWeight(
            strategy: strategy,
            kind: kind,
            currentLevel: currentLevel,
            levels: levels,
            energy: energy
        )

        return rule.aiPriorityWeight *
            strategicWeight *
            levelCatchUpFactor(currentLevel) *
            resourceHeadroomFactor(resources: planet.resources, cost: cost) *
            deterministicScoreNudge(universe: universe, factionID: factionID, payload: "building-score|\(planet.id.rawValue.uuidString)|\(kind.rawValue)")
    }

    private static func researchScore(
        technology: TechnologyKind,
        rule: ResearchRule,
        currentLevel: Int,
        strategy: Faction.Strategy,
        resources: ResourceBundle,
        cost: ResourceBundle
    ) -> Double {
        rule.aiPriorityWeight *
            researchStrategyWeight(strategy: strategy, technology: technology) *
            levelCatchUpFactor(currentLevel) *
            resourceHeadroomFactor(resources: resources, cost: cost)
    }

    private static func buildingStrategyWeight(
        strategy: Faction.Strategy,
        kind: BuildingKind,
        currentLevel: Int,
        levels: [BuildingKind: Int],
        energy: EnergyState
    ) -> Double {
        switch strategy {
        case .miner:
            switch kind {
            case .metalMine:
                return 4.0
            case .crystalMine:
                return 3.7
            case .deuteriumSynthesizer:
                return 3.2
            case .solarPlant:
                return energy.available < 20 ? 3.4 : 2.4
            case .roboticsFactory:
                return 0.5
            case .shipyard:
                return 0.2
            case .researchLab:
                return 0.3
            case .metalStorage, .crystalStorage, .deuteriumTank:
                return 0.4
            case .naniteFactory:
                return 0.1
            case .missileSilo:
                return 0.08
            case .lunarBase, .sensorPhalanx, .jumpGate:
                return 0.02
            }
        case .technologist:
            switch kind {
            case .researchLab:
                return currentLevel == 0 ? 5.0 : 1.2
            case .solarPlant:
                return energy.available < 10 ? 1.6 : 1.0
            case .metalMine, .crystalMine, .deuteriumSynthesizer:
                return 0.8
            case .roboticsFactory:
                return 0.6
            case .shipyard:
                return 0.3
            case .metalStorage, .crystalStorage, .deuteriumTank:
                return 0.2
            case .naniteFactory:
                return levels[.roboticsFactory, default: 0] >= 2 ? 1.0 : 0.1
            case .missileSilo:
                return 0.12
            case .lunarBase, .sensorPhalanx, .jumpGate:
                return 0.05
            }
        case .expansionist:
            switch kind {
            case .roboticsFactory:
                return currentLevel == 0 ? 5.0 : 2.2
            case .shipyard:
                return levels[.roboticsFactory, default: 0] > 0 && currentLevel == 0 ? 4.6 : 1.7
            case .solarPlant:
                return energy.available < 10 ? 2.0 : 1.2
            case .metalMine, .crystalMine, .deuteriumSynthesizer:
                return 1.1
            case .researchLab:
                return 0.8
            case .metalStorage, .crystalStorage, .deuteriumTank:
                return 0.3
            case .naniteFactory:
                return levels[.roboticsFactory, default: 0] >= 2 ? 1.2 : 0.1
            case .missileSilo:
                return 0.10
            case .lunarBase, .sensorPhalanx, .jumpGate:
                return 0.04
            }
        case .balanced:
            switch kind {
            case .solarPlant:
                return energy.available < 0 ? 4.6 : 1.4
            case .metalMine, .crystalMine, .deuteriumSynthesizer:
                return 2.0
            case .researchLab:
                return 1.4
            case .roboticsFactory:
                return 1.0
            case .shipyard:
                return 0.8
            case .metalStorage, .crystalStorage, .deuteriumTank:
                return 0.35
            case .naniteFactory:
                return levels[.roboticsFactory, default: 0] >= 2 ? 0.8 : 0.1
            case .missileSilo:
                return 0.12
            case .lunarBase, .sensorPhalanx, .jumpGate:
                return 0.04
            }
        case .raider:
            switch kind {
            case .shipyard:
                return levels[.roboticsFactory, default: 0] > 0 && currentLevel == 0 ? 5.0 : 1.8
            case .roboticsFactory:
                return currentLevel == 0 ? 4.0 : 1.6
            case .researchLab:
                return 1.5
            case .solarPlant:
                return energy.available < 10 ? 1.8 : 1.2
            case .metalMine, .crystalMine, .deuteriumSynthesizer:
                return 1.1
            case .metalStorage, .crystalStorage, .deuteriumTank:
                return 0.25
            case .naniteFactory:
                return levels[.roboticsFactory, default: 0] >= 2 ? 1.1 : 0.1
            case .missileSilo:
                return 0.18
            case .lunarBase, .sensorPhalanx, .jumpGate:
                return 0.03
            }
        }
    }

    private static func researchStrategyWeight(strategy: Faction.Strategy, technology: TechnologyKind) -> Double {
        switch strategy {
        case .miner:
            switch technology {
            case .energy:
                return 1.3
            case .computer:
                return 0.9
            default:
                return 0.5
            }
        case .technologist:
            switch technology {
            case .computer:
                return 5.0
            case .energy:
                return 4.2
            case .espionage:
                return 3.6
            case .weapons, .shielding, .armor:
                return 2.2
            case .combustionDrive, .impulseDrive, .hyperspaceDrive:
                return 1.6
            }
        case .expansionist:
            switch technology {
            case .computer:
                return 2.0
            case .combustionDrive, .impulseDrive, .hyperspaceDrive:
                return 1.8
            case .energy:
                return 1.4
            default:
                return 0.9
            }
        case .balanced:
            switch technology {
            case .computer:
                return 2.2
            case .energy:
                return 1.9
            case .weapons, .shielding, .armor:
                return 1.2
            default:
                return 1.0
            }
        case .raider:
            switch technology {
            case .weapons:
                return 3.2
            case .armor:
                return 2.6
            case .shielding:
                return 2.4
            case .combustionDrive:
                return 2.2
            case .espionage:
                return 2.0
            case .computer:
                return 1.5
            default:
                return 1.0
            }
        }
    }

    private static func hasActiveQueue(for faction: Faction, in universe: Universe) -> Bool {
        if !faction.researchQueue.isEmpty {
            return true
        }

        return universe.planets.contains { planet in
            planet.ownerID == faction.id && !planet.buildQueue.isEmpty
        }
    }

    private static func ownedPlanets(for faction: Faction, in universe: Universe) -> [Planet] {
        let ownedIDs = Set(faction.ownedPlanetIDs)

        return universe.planets
            .filter { planet in
                ownedIDs.contains(planet.id) && planet.ownerID == faction.id
            }
            .sorted(by: comparePlanets)
    }

    private static func researchPaymentPlanet(for faction: Faction, in universe: Universe) -> Planet? {
        for planetID in faction.ownedPlanetIDs {
            if let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == faction.id }) {
                return planet
            }
        }

        return nil
    }

    private static func normalizedBuildingLevels(for planet: Planet) -> [BuildingKind: Int] {
        Dictionary(uniqueKeysWithValues: planet.buildingLevels.map { kind, level in
            (kind, max(level, 0))
        })
    }

    private static func normalizedTechnologyLevel(_ level: Int) -> Int {
        max(level, 0)
    }

    private static func levelCatchUpFactor(_ currentLevel: Int) -> Double {
        1 / (1 + Double(max(currentLevel, 0)) * 0.35)
    }

    private static func resourceHeadroomFactor(resources: ResourceBundle, cost: ResourceBundle) -> Double {
        let ratios = [
            laneRatio(available: resources.metal, required: cost.metal),
            laneRatio(available: resources.crystal, required: cost.crystal),
            laneRatio(available: resources.deuterium, required: cost.deuterium)
        ]
        let constrainedHeadroom = min(max(ratios.min() ?? 1, 1), 4)

        return 1 + constrainedHeadroom * 0.02
    }

    private static func laneRatio(available: Double, required: Double) -> Double {
        guard required > 0 else {
            return 4
        }

        return available / required
    }

    private static func deterministicScoreNudge(universe: Universe, factionID: FactionID, payload: String) -> Double {
        let value = tieBreaker(universe: universe, factionID: factionID, payload: payload) % 1_000
        return 1 + (Double(value) / 1_000_000)
    }

    private static func energyState(for planet: Planet, ruleSet: RuleSet) -> EnergyState {
        var produced = 0.0
        var used = 0.0

        for building in BuildingKind.allCases {
            let level = max(planet.buildingLevels[building] ?? 0, 0)
            guard level > 0, let rule = ruleSet.buildingRules[building] else {
                continue
            }

            produced += scaledServerCurve(rule.energyProduced, level: level)
            used += scaledServerCurve(rule.energyUsed, level: level)
        }

        return EnergyState(produced: produced, used: used)
    }

    private static func scaledServerCurve(_ baseValue: Double, level: Int) -> Double {
        guard level > 0, baseValue.isFinite else {
            return 0
        }

        return max(baseValue, 0) * Double(level) * pow(serverGrowthBase, Double(level))
    }

    private static func buildingTerms(rule: BuildingRule, targetLevel: Int) -> (cost: ResourceBundle, duration: TimeInterval)? {
        terms(
            baseCost: rule.baseCost,
            costMultiplier: rule.costMultiplier,
            baseDuration: rule.baseDuration,
            durationMultiplier: rule.durationMultiplier,
            targetLevel: targetLevel
        )
    }

    private static func researchTerms(rule: ResearchRule, targetLevel: Int) -> (cost: ResourceBundle, duration: TimeInterval)? {
        terms(
            baseCost: rule.baseCost,
            costMultiplier: rule.costMultiplier,
            baseDuration: rule.baseDuration,
            durationMultiplier: rule.durationMultiplier,
            targetLevel: targetLevel
        )
    }

    private static func terms(
        baseCost: ResourceBundle,
        costMultiplier: Double,
        baseDuration: TimeInterval,
        durationMultiplier: Double,
        targetLevel: Int
    ) -> (cost: ResourceBundle, duration: TimeInterval)? {
        guard
            isValidCost(baseCost),
            costMultiplier.isFinite,
            costMultiplier > 0,
            baseDuration.isFinite,
            baseDuration > 0,
            durationMultiplier.isFinite,
            durationMultiplier > 0
        else {
            return nil
        }

        let exponent = Double(max(targetLevel - 1, 0))
        let scaledCostMultiplier = pow(costMultiplier, exponent)
        let scaledDurationMultiplier = pow(durationMultiplier, exponent)
        guard scaledCostMultiplier.isFinite, scaledDurationMultiplier.isFinite else {
            return nil
        }

        let cost = baseCost.scaled(by: scaledCostMultiplier)
        let duration = baseDuration * scaledDurationMultiplier
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

    private static func compareFactions(_ lhs: Faction, _ rhs: Faction) -> Bool {
        lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }

    private static func comparePlanets(_ lhs: Planet, _ rhs: Planet) -> Bool {
        lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }

    private static func compareCandidates(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        if lhs.tieBreaker != rhs.tieBreaker {
            return lhs.tieBreaker < rhs.tieBreaker
        }

        return lhs.action.sortKey < rhs.action.sortKey
    }

    private static func tieBreaker(universe: Universe, factionID: FactionID, payload: String) -> UInt64 {
        stableHash(
            [
                "ai-economy",
                String(universe.seed),
                String(universe.gameTime),
                factionID.rawValue.uuidString,
                payload
            ].joined(separator: "|")
        )
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

private struct Candidate: Equatable {
    var action: AIAction
    var score: Double
    var tieBreaker: UInt64

    func start(in universe: inout Universe) -> QueueResult {
        switch action {
        case let .building(planetID, kind):
            return QueueEngine.startBuildingUpgrade(on: planetID, in: &universe, kind: kind)
        case let .research(factionID, technology):
            return QueueEngine.startResearch(for: factionID, in: &universe, technology: technology)
        }
    }
}

private enum AIAction: Equatable {
    case building(planetID: PlanetID, kind: BuildingKind)
    case research(factionID: FactionID, technology: TechnologyKind)

    var sortKey: String {
        switch self {
        case let .building(planetID, kind):
            return "building|\(planetID.rawValue.uuidString)|\(kind.rawValue)"
        case let .research(factionID, technology):
            return "research|\(factionID.rawValue.uuidString)|\(technology.rawValue)"
        }
    }
}
