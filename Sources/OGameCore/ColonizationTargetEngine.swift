import Foundation

public enum ColonizationTargetEngine {
    public static func ensureNeutralTarget(
        at coordinate: Coordinate,
        visibleTo factionID: FactionID,
        in universe: inout Universe
    ) -> PlanetID? {
        guard UniverseTopologyEngine.isValidPlanetCoordinate(coordinate) else {
            return nil
        }

        if let existingIndex = universe.planets.firstIndex(where: { $0.coordinate == coordinate }) {
            guard universe.planets[existingIndex].ownerID == nil else {
                return nil
            }
            ensureExplorationRecord(
                for: universe.planets[existingIndex],
                visibleTo: factionID,
                in: &universe
            )
            return universe.planets[existingIndex].id
        }

        let planetID = PlanetID(stableUUID(payload: "colonization-target|\(universe.id.rawValue.uuidString)|\(coordinate.displayText)"))
        guard !universe.planets.contains(where: { $0.id == planetID }) else {
            return nil
        }

        let profile = UniverseTopologyEngine.planetProfile(for: coordinate, universeSeed: universe.seed)
        let planet = Planet(
            id: planetID,
            name: "未占领 \(coordinate.displayText)",
            coordinate: coordinate,
            ownerID: nil,
            resources: ResourceBundle(metal: 120, crystal: 60, deuterium: 20),
            temperatureCelsius: profile.temperatureCelsius,
            debrisField: .zero,
            maxFields: profile.maxFields
        )
        universe.planets.append(planet)
        ensureExplorationRecord(for: planet, visibleTo: factionID, in: &universe)
        return planetID
    }

    private static func ensureExplorationRecord(
        for planet: Planet,
        visibleTo factionID: FactionID,
        in universe: inout Universe
    ) {
        guard !universe.explorationRecords.contains(where: { $0.factionID == factionID && $0.targetPlanetID == planet.id }) else {
            return
        }

        universe.explorationRecords.append(
            ExplorationRecord(
                factionID: factionID,
                targetPlanetID: planet.id,
                exploredAt: universe.gameTime,
                discoveredResources: planet.resources.nonnegative,
                discoveredDebris: planet.debrisField.nonnegative,
                discoveredOwnerID: planet.ownerID,
                discoveredNeutral: planet.ownerID == nil
            )
        )
    }

    private static func stableUUID(payload: String) -> UUID {
        let hash = stableHash(payload)
        return UUID(uuidString: String(format: "00000000-0000-0000-%04x-%012llx", Int(hash & 0xffff), hash & 0xffffffffffff))!
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

public enum FleetTargetSelectionEngine {
    public static func ensureTarget(
        at coordinate: Coordinate,
        visibleTo factionID: FactionID,
        in universe: inout Universe
    ) -> PlanetID? {
        if let existing = universe.planets.first(where: { $0.coordinate == coordinate }) {
            ensureExplorationRecord(for: existing, visibleTo: factionID, in: &universe)
            return existing.id
        }

        if UniverseTopologyEngine.isValidPlanetCoordinate(coordinate) {
            return ColonizationTargetEngine.ensureNeutralTarget(at: coordinate, visibleTo: factionID, in: &universe)
        }

        guard UniverseTopologyEngine.isExpeditionCoordinate(coordinate) else {
            return nil
        }

        let planetID = PlanetID(stableUUID(payload: "fleet-target|\(universe.id.rawValue.uuidString)|\(coordinate.displayText)"))
        guard !universe.planets.contains(where: { $0.id == planetID }) else {
            return nil
        }

        let planet = Planet(
            id: planetID,
            name: "外太空 \(coordinate.displayText)",
            coordinate: coordinate,
            ownerID: nil,
            resources: .zero,
            temperatureCelsius: 0,
            debrisField: .zero,
            maxFields: 1
        )
        universe.planets.append(planet)
        ensureExplorationRecord(for: planet, visibleTo: factionID, in: &universe)
        return planetID
    }

    private static func ensureExplorationRecord(
        for planet: Planet,
        visibleTo factionID: FactionID,
        in universe: inout Universe
    ) {
        guard !universe.explorationRecords.contains(where: { $0.factionID == factionID && $0.targetPlanetID == planet.id }) else {
            return
        }

        universe.explorationRecords.append(
            ExplorationRecord(
                factionID: factionID,
                targetPlanetID: planet.id,
                exploredAt: universe.gameTime,
                discoveredResources: planet.resources.nonnegative,
                discoveredDebris: planet.debrisField.nonnegative,
                discoveredOwnerID: planet.ownerID,
                discoveredNeutral: planet.ownerID == nil && UniverseTopologyEngine.isValidPlanetCoordinate(planet.coordinate)
            )
        )
    }

    private static func stableUUID(payload: String) -> UUID {
        let hash = stableHash(payload)
        return UUID(uuidString: String(format: "00000000-0000-0000-%04x-%012llx", Int(hash & 0xffff), hash & 0xffffffffffff))!
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
