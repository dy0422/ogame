import Foundation

public enum PlayerVisibilityEngine {
    public static func playerOwnedPlanets(in universe: Universe) -> [Planet] {
        ownedPlanets(for: universe.playerFactionID, in: universe)
    }

    public static func playerOwnedPlanetIDs(in universe: Universe) -> Set<PlanetID> {
        Set(playerOwnedPlanets(in: universe).map(\.id))
    }

    public static func isPlayerOwned(_ planet: Planet, in universe: Universe) -> Bool {
        planet.ownerID == universe.playerFactionID
    }

    public static func normalizeFactionPlanetIndexes(in universe: inout Universe) {
        for factionIndex in universe.factions.indices {
            let factionID = universe.factions[factionIndex].id
            universe.factions[factionIndex].ownedPlanetIDs = normalizedOwnedPlanetIDs(
                for: factionID,
                currentIDs: universe.factions[factionIndex].ownedPlanetIDs,
                in: universe
            )
        }
    }

    public static func ownedPlanets(for factionID: FactionID, in universe: Universe) -> [Planet] {
        universe.planets
            .filter { $0.ownerID == factionID }
            .sorted(by: sortPlanetsByCoordinate)
    }

    private static func sortPlanetsByCoordinate(_ lhs: Planet, _ rhs: Planet) -> Bool {
        if lhs.coordinate.galaxy != rhs.coordinate.galaxy {
            return lhs.coordinate.galaxy < rhs.coordinate.galaxy
        }
        if lhs.coordinate.system != rhs.coordinate.system {
            return lhs.coordinate.system < rhs.coordinate.system
        }
        if lhs.coordinate.position != rhs.coordinate.position {
            return lhs.coordinate.position < rhs.coordinate.position
        }

        return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }

    private static func normalizedOwnedPlanetIDs(
        for factionID: FactionID,
        currentIDs: [PlanetID],
        in universe: Universe
    ) -> [PlanetID] {
        let ownerBackedIDs = Set(
            universe.planets
                .filter { $0.ownerID == factionID }
                .map(\.id)
        )
        let retainedIDs = currentIDs.filter { ownerBackedIDs.contains($0) }
        let retainedIDSet = Set(retainedIDs)
        let missingIDs = ownedPlanets(for: factionID, in: universe)
            .map(\.id)
            .filter { !retainedIDSet.contains($0) }

        return retainedIDs + missingIDs
    }
}
