import Foundation

public enum MoonEngine {
    public struct SensorTrace: Equatable, Sendable {
        public enum Risk: String, Codable, Equatable, Sendable {
            case low
            case arrivalTiming
            case returnTiming
            case debrisFleetSave
        }

        public var fleet: Fleet
        public var interceptTime: TimeInterval?
        public var risk: Risk
        public var tacticalNote: String

        public init(
            fleet: Fleet,
            interceptTime: TimeInterval?,
            risk: Risk,
            tacticalNote: String
        ) {
            self.fleet = fleet
            self.interceptTime = interceptTime.flatMap { $0.isFinite ? $0 : nil }
            self.risk = risk
            self.tacticalNote = tacticalNote
        }
    }

    private static let jumpGateCooldown: TimeInterval = 3_600

    public static func startFacilityUpgrade(
        on planetID: PlanetID,
        in universe: inout Universe,
        kind: BuildingKind
    ) -> QueueResult {
        guard kind.isMoonFacility else {
            return .missingRule
        }
        guard let planet = universe.planets.first(where: { $0.id == planetID }) else {
            return .missingPlanet
        }
        guard planet.moon != nil else {
            return .missingRule
        }

        return QueueEngine.startBuildingUpgrade(on: planetID, in: &universe, kind: kind)
    }

    public static func sensorScan(
        from moonPlanetID: PlanetID,
        targetPlanetID: PlanetID,
        ownerID: FactionID,
        in universe: Universe
    ) -> [Fleet] {
        guard let origin = universe.planets.first(where: { $0.id == moonPlanetID && $0.ownerID == ownerID }),
              let moon = origin.moon,
              let target = universe.planets.first(where: { $0.id == targetPlanetID }),
              let level = moon.buildingLevels[.sensorPhalanx],
              level > 0
        else {
            return []
        }

        let range = level * level * 5
        guard origin.coordinate.galaxy == target.coordinate.galaxy,
              abs(origin.coordinate.system - target.coordinate.system) <= range
        else {
            return []
        }

        return universe.fleets.filter { fleet in
            fleet.phase != .completed &&
                fleet.recalledAt == nil &&
                !(fleet.originPlanetID == targetPlanetID && fleet.originSite == .moon) &&
                (fleet.originPlanetID == targetPlanetID || fleet.targetPlanetID == targetPlanetID)
        }
    }

    public static func sensorTrace(
        from moonPlanetID: PlanetID,
        targetPlanetID: PlanetID,
        ownerID: FactionID,
        in universe: Universe
    ) -> [SensorTrace] {
        sensorScan(
            from: moonPlanetID,
            targetPlanetID: targetPlanetID,
            ownerID: ownerID,
            in: universe
        )
        .map { tacticalTrace(for: $0) }
    }

    public static func jumpShips(
        from originPlanetID: PlanetID,
        to targetPlanetID: PlanetID,
        ownerID: FactionID,
        ships requestedShips: [ShipKind: Int],
        in universe: inout Universe
    ) -> Bool {
        guard originPlanetID != targetPlanetID,
              let originIndex = universe.planets.firstIndex(where: { $0.id == originPlanetID && $0.ownerID == ownerID }),
              let targetIndex = universe.planets.firstIndex(where: { $0.id == targetPlanetID && $0.ownerID == ownerID }),
              let originMoon = universe.planets[originIndex].moon,
              let targetMoon = universe.planets[targetIndex].moon,
              (originMoon.buildingLevels[.jumpGate] ?? 0) > 0,
              (targetMoon.buildingLevels[.jumpGate] ?? 0) > 0,
              originMoon.jumpGateReadyAt <= universe.gameTime
        else {
            return false
        }

        let ships = normalizedShips(requestedShips)
        guard !ships.isEmpty,
              ships.allSatisfy({ kind, quantity in
                  (universe.planets[originIndex].shipInventory[kind] ?? 0) >= quantity
              })
        else {
            return false
        }

        for (kind, quantity) in ships {
            let originRemaining = max(universe.planets[originIndex].shipInventory[kind] ?? 0, 0) - quantity
            universe.planets[originIndex].shipInventory[kind] = originRemaining > 0 ? originRemaining : nil
            universe.planets[targetIndex].shipInventory[kind, default: 0] += quantity
        }
        universe.planets[originIndex].moon?.jumpGateReadyAt = universe.gameTime + jumpGateCooldown
        universe.events.append(
            GameEvent(
                id: EventID(stableUUID(namespace: "0014", payload: "\(originPlanetID.rawValue.uuidString)|\(targetPlanetID.rawValue.uuidString)|\(universe.gameTime)")),
                time: universe.gameTime,
                kind: .system,
                title: "Jump Gate Transfer",
                message: "Ships jumped between moons."
            )
        )
        return true
    }

    private static func normalizedShips(_ ships: [ShipKind: Int]) -> [ShipKind: Int] {
        ships.reduce(into: [:]) { result, element in
            guard element.value > 0 else {
                return
            }
            result[element.key, default: 0] += element.value
        }
    }

    private static func tacticalTrace(for fleet: Fleet) -> SensorTrace {
        let interceptTime: TimeInterval?
        switch fleet.phase {
        case .outbound, .holding:
            interceptTime = fleet.arrivalTime
        case .returning:
            interceptTime = fleet.returnTime
        case .completed:
            interceptTime = nil
        }

        if fleet.mission == .recycle {
            return SensorTrace(
                fleet: fleet,
                interceptTime: interceptTime,
                risk: .debrisFleetSave,
                tacticalNote: "废墟 FS 风险：回收航线可被感应阵定位，适合按抵达或返航时间追秒。"
            )
        }

        if fleet.phase == .returning {
            return SensorTrace(
                fleet: fleet,
                interceptTime: interceptTime,
                risk: .returnTiming,
                tacticalNote: "返航追秒窗口：可按返航时间安排拦截。"
            )
        }

        if fleet.mission == .attack {
            return SensorTrace(
                fleet: fleet,
                interceptTime: interceptTime,
                risk: .arrivalTiming,
                tacticalNote: "抵达追秒窗口：可按抵达时间安排防守或反击。"
            )
        }

        return SensorTrace(
            fleet: fleet,
            interceptTime: interceptTime,
            risk: .low,
            tacticalNote: "普通可见航线。"
        )
    }

    private static func stableUUID(namespace: String, payload: String) -> UUID {
        let hash = stableHash("\(namespace)|\(payload)")
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
