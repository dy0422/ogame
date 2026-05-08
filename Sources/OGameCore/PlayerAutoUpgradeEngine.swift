import Foundation

public struct PlayerAutoUpgradeResult: Equatable, Sendable {
    public var queuedBuildings: Int
    public var queuedResearch: Int

    public var didQueue: Bool {
        queuedBuildings > 0 || queuedResearch > 0
    }

    public init(queuedBuildings: Int = 0, queuedResearch: Int = 0) {
        self.queuedBuildings = queuedBuildings
        self.queuedResearch = queuedResearch
    }
}

public enum PlayerAutoUpgradeEngine {
    @discardableResult
    public static func makeDecisions(in universe: inout Universe) -> PlayerAutoUpgradeResult {
        guard let player = universe.factions.first(where: { $0.id == universe.playerFactionID }) else {
            return PlayerAutoUpgradeResult()
        }

        var result = PlayerAutoUpgradeResult()
        if queueBuilding(for: player, in: &universe) {
            result.queuedBuildings += 1
        }
        if queueResearch(for: player, in: &universe) {
            result.queuedResearch += 1
        }

        return result
    }

    private static func queueBuilding(for player: Faction, in universe: inout Universe) -> Bool {
        for planetID in player.ownedPlanetIDs {
            guard let planetIndex = universe.planets.firstIndex(where: { $0.id == planetID && $0.ownerID == player.id }),
                  universe.planets[planetIndex].buildQueue.isEmpty
            else {
                continue
            }

            let priorities = buildingPriorities(
                for: universe.planets[planetIndex],
                player: player,
                ruleSet: universe.ruleSet
            )
            for kind in priorities where universe.ruleSet.buildingRules[kind] != nil && !kind.isMoonFacility {
                if QueueEngine.startBuildingUpgrade(on: planetID, in: &universe, kind: kind) == .queued {
                    return true
                }
            }
        }

        return false
    }

    private static func queueResearch(for player: Faction, in universe: inout Universe) -> Bool {
        guard player.researchQueue.isEmpty else {
            return false
        }

        guard hasResearchLab(for: player, in: universe) else {
            return false
        }

        for technology in researchPriorities where universe.ruleSet.researchRules[technology] != nil {
            if QueueEngine.startResearch(for: player.id, in: &universe, technology: technology) == .queued {
                return true
            }
        }

        return false
    }

    private static func buildingPriorities(
        for planet: Planet,
        player: Faction,
        ruleSet: RuleSet
    ) -> [BuildingKind] {
        let energy = EconomyEngine.energyState(for: planet, ruleSet: ruleSet, research: player.technology)
        if energy.available < 0 {
            return [
                .solarPlant,
                .fusionReactor,
                .metalMine,
                .crystalMine,
                .deuteriumSynthesizer,
                .roboticsFactory,
                .researchLab,
                .shipyard,
                .metalStorage,
                .crystalStorage,
                .deuteriumTank,
                .naniteFactory,
                .missileSilo
            ]
        }

        return [
            .metalMine,
            .crystalMine,
            .solarPlant,
            .deuteriumSynthesizer,
            .researchLab,
            .roboticsFactory,
            .shipyard,
            .fusionReactor,
            .metalStorage,
            .crystalStorage,
            .deuteriumTank,
            .naniteFactory,
            .missileSilo
        ]
    }

    private static func hasResearchLab(for player: Faction, in universe: Universe) -> Bool {
        player.ownedPlanetIDs.contains { planetID in
            guard let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == player.id }) else {
                return false
            }

            return max(planet.buildingLevels[.researchLab] ?? 0, 0) > 0
        }
    }

    private static let researchPriorities: [TechnologyKind] = [
        .energy,
        .computer,
        .espionage,
        .combustionDrive,
        .impulseDrive,
        .weapons,
        .shielding,
        .armor,
        .hyperspaceDrive
    ]
}
