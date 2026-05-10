import Foundation

public struct FleetMissionPlanNote: Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case value
        case timing
        case requirement
        case warning
        case risk
    }

    public var kind: Kind
    public var title: String
    public var detail: String

    public var id: String {
        [kind.rawValue, title, detail].joined(separator: "|")
    }

    public init(kind: Kind, title: String, detail: String) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

public struct FleetMissionPlan: Equatable, Sendable {
    public enum Blocker: String, Codable, Equatable, Sendable {
        case missingOrigin
        case missingTarget
        case missingOwner
        case invalidMission
        case noShipsSelected
        case missingRequiredShip
        case insufficientShips
        case invalidCargo
        case insufficientCargoCapacity
        case insufficientFuel
        case fleetSlotLimit
        case colonizationLimit
        case occupiedTarget
        case friendlyTargetRequired
        case targetNotVisible

        public var localizedName: String {
            switch self {
            case .missingOrigin:
                return "缺少出发星球"
            case .missingTarget:
                return "缺少目标"
            case .missingOwner:
                return "出发星球没有归属"
            case .invalidMission:
                return "任务不可执行"
            case .noShipsSelected:
                return "未选择舰船"
            case .missingRequiredShip:
                return "缺少任务舰船"
            case .insufficientShips:
                return "舰船数量不足"
            case .invalidCargo:
                return "货物无效"
            case .insufficientCargoCapacity:
                return "货舱不足"
            case .insufficientFuel:
                return "重氢不足"
            case .fleetSlotLimit:
                return "舰队槽已满"
            case .colonizationLimit:
                return "殖民上限已满"
            case .occupiedTarget:
                return "目标已被占领"
            case .friendlyTargetRequired:
                return "驻防需要己方目标"
            case .targetNotVisible:
                return "目标尚未侦察"
            }
        }
    }

    public enum RiskLevel: String, Codable, Equatable, Sendable {
        case low
        case medium
        case high

        public var localizedName: String {
            switch self {
            case .low:
                return "低风险"
            case .medium:
                return "中风险"
            case .high:
                return "高风险"
            }
        }
    }

    public var mission: Fleet.Mission
    public var originID: PlanetID?
    public var targetID: PlanetID?
    public var targetCoordinate: Coordinate?
    public var ships: [ShipKind: Int]
    public var cargo: ResourceBundle
    public var cargoCapacity: Double
    public var cargoUsed: Double
    public var fuelCost: Double
    public var travelDuration: TimeInterval
    public var roundTripDuration: TimeInterval
    public var expectedValue: ResourceBundle
    public var riskLevel: RiskLevel
    public var blockers: [Blocker]
    public var notes: [FleetMissionPlanNote]

    public var isLaunchable: Bool {
        blockers.isEmpty
    }

    public init(
        mission: Fleet.Mission,
        originID: PlanetID?,
        targetID: PlanetID?,
        targetCoordinate: Coordinate?,
        ships: [ShipKind: Int],
        cargo: ResourceBundle,
        cargoCapacity: Double,
        cargoUsed: Double,
        fuelCost: Double,
        travelDuration: TimeInterval,
        roundTripDuration: TimeInterval,
        expectedValue: ResourceBundle,
        riskLevel: RiskLevel,
        blockers: [Blocker],
        notes: [FleetMissionPlanNote]
    ) {
        self.mission = mission
        self.originID = originID
        self.targetID = targetID
        self.targetCoordinate = targetCoordinate
        self.ships = ships
        self.cargo = cargo
        self.cargoCapacity = cargoCapacity
        self.cargoUsed = cargoUsed
        self.fuelCost = fuelCost
        self.travelDuration = travelDuration
        self.roundTripDuration = roundTripDuration
        self.expectedValue = expectedValue
        self.riskLevel = riskLevel
        self.blockers = blockers
        self.notes = notes
    }
}

public enum FleetMissionPlannerEngine {
    private struct TargetSnapshot {
        var id: PlanetID?
        var coordinate: Coordinate
        var ownerID: FactionID?
        var isVisible: Bool
        var resources: ResourceBundle
        var debris: ResourceBundle
    }

    public static func plan(
        originID: PlanetID?,
        targetID: PlanetID?,
        targetCoordinate: Coordinate? = nil,
        targetOwnerID: FactionID? = nil,
        targetIsVisible: Bool = true,
        targetResources: ResourceBundle = .zero,
        targetDebris: ResourceBundle = .zero,
        in universe: Universe,
        mission: Fleet.Mission,
        ships requestedShips: [ShipKind: Int],
        cargo: ResourceBundle = .zero,
        speedPercent: Double = 1
    ) -> FleetMissionPlan {
        let origin = originID.flatMap { id in universe.planets.first { $0.id == id } }
        let target = targetSnapshot(
            targetID: targetID,
            targetCoordinate: targetCoordinate,
            targetOwnerID: targetOwnerID,
            targetIsVisible: targetIsVisible,
            targetResources: targetResources,
            targetDebris: targetDebris,
            in: universe
        )
        let ships = normalizedShips(requestedShips)
        let cargo = sanitizedCargo(cargo)
        let cargoCapacity = fleetCargoCapacity(for: ships, ruleSet: universe.ruleSet)
        let cargoUsed = resourceTotal(cargo)
        let ownerID = origin?.ownerID
        let ownerFaction = ownerID.flatMap { id in universe.factions.first { $0.id == id } }
        let ownerResearch = ownerFaction?.technology ?? ResearchState()
        let fuelCost = computedFuelCost(origin: origin, target: target, ships: ships, ruleSet: universe.ruleSet, research: ownerResearch, speedPercent: speedPercent)
        let travelDuration = computedTravelDuration(origin: origin, target: target, ships: ships, ruleSet: universe.ruleSet, research: ownerResearch, speedPercent: speedPercent)
        let roundTripDuration = mission == .defend ? travelDuration : travelDuration * 2
        let expectedValue = expectedValue(
            mission: mission,
            cargo: cargo,
            cargoCapacity: cargoCapacity,
            target: target
        )
        let riskLevel = riskLevel(mission: mission, target: target, ownerID: ownerID)
        let blockers = blockers(
            mission: mission,
            origin: origin,
            ownerID: ownerID,
            ownerFaction: ownerFaction,
            target: target,
            ships: ships,
            cargo,
            cargoCapacity: cargoCapacity,
            cargoUsed: cargoUsed,
            fuelCost: fuelCost,
            universe: universe
        )
        let notes = notes(
            mission: mission,
            blockers: blockers,
            expectedValue: expectedValue,
            fuelCost: fuelCost,
            travelDuration: travelDuration,
            roundTripDuration: roundTripDuration,
            riskLevel: riskLevel
        )

        return FleetMissionPlan(
            mission: mission,
            originID: origin?.id,
            targetID: target?.id ?? targetID,
            targetCoordinate: target?.coordinate ?? targetCoordinate,
            ships: ships,
            cargo: cargo,
            cargoCapacity: cargoCapacity,
            cargoUsed: cargoUsed,
            fuelCost: fuelCost,
            travelDuration: travelDuration,
            roundTripDuration: roundTripDuration,
            expectedValue: expectedValue,
            riskLevel: riskLevel,
            blockers: blockers,
            notes: notes
        )
    }

    public static func recommendedShips(for mission: Fleet.Mission, on planet: Planet) -> [ShipKind: Int] {
        let priorities: [ShipKind]
        switch mission {
        case .colonize:
            priorities = [.colonyShip]
        case .recycle:
            priorities = [.recycler]
        case .espionage:
            priorities = [.espionageProbe]
        case .explore:
            priorities = [.smallCargo, .largeCargo, .espionageProbe]
        case .attack:
            priorities = [.battlecruiser, .battleship, .cruiser, .heavyFighter, .lightFighter]
        case .defend:
            priorities = [.battlecruiser, .battleship, .cruiser, .heavyFighter, .lightFighter, .smallCargo, .largeCargo]
        case .transport:
            priorities = [.largeCargo, .smallCargo]
        case .returning:
            priorities = []
        }

        for kind in priorities {
            let available = max(planet.shipInventory[kind] ?? 0, 0)
            if available > 0 {
                return [kind: mission == .attack || mission == .defend ? min(available, 4) : 1]
            }
        }

        return [:]
    }

    private static func targetSnapshot(
        targetID: PlanetID?,
        targetCoordinate: Coordinate?,
        targetOwnerID: FactionID?,
        targetIsVisible: Bool,
        targetResources: ResourceBundle,
        targetDebris: ResourceBundle,
        in universe: Universe
    ) -> TargetSnapshot? {
        if let targetID,
           let planet = universe.planets.first(where: { $0.id == targetID })
        {
            return TargetSnapshot(
                id: planet.id,
                coordinate: planet.coordinate,
                ownerID: targetIsVisible ? planet.ownerID : targetOwnerID,
                isVisible: targetIsVisible,
                resources: targetIsVisible ? planet.resources : targetResources.nonnegative,
                debris: targetIsVisible ? planet.debrisField : targetDebris.nonnegative
            )
        }

        guard let targetCoordinate else {
            return nil
        }

        return TargetSnapshot(
            id: targetID,
            coordinate: targetCoordinate,
            ownerID: targetOwnerID,
            isVisible: targetIsVisible,
            resources: targetResources.nonnegative,
            debris: targetDebris.nonnegative
        )
    }

    private static func blockers(
        mission: Fleet.Mission,
        origin: Planet?,
        ownerID: FactionID?,
        ownerFaction: Faction?,
        target: TargetSnapshot?,
        ships: [ShipKind: Int],
        _ cargo: ResourceBundle,
        cargoCapacity: Double,
        cargoUsed: Double,
        fuelCost: Double,
        universe: Universe
    ) -> [FleetMissionPlan.Blocker] {
        var result: [FleetMissionPlan.Blocker] = []

        if origin == nil {
            result.append(.missingOrigin)
        }
        if target == nil {
            result.append(.missingTarget)
        }
        if origin != nil, ownerID == nil {
            result.append(.missingOwner)
        }
        if mission == .returning {
            result.append(.invalidMission)
        }
        if ships.isEmpty {
            result.append(.noShipsSelected)
        }

        if let ownerID {
            let activeFleetCount = universe.fleets.filter { $0.ownerID == ownerID && $0.phase != .completed }.count
            let ownerResearch = ownerFaction?.technology ?? ResearchState()
            if activeFleetCount >= TechnologyEffects.maxFleetSlots(for: ownerResearch) {
                result.append(.fleetSlotLimit)
            }
        }

        if let origin {
            for (kind, quantity) in ships where max(quantity, 0) > max(origin.shipInventory[kind] ?? 0, 0) {
                result.append(.insufficientShips)
                break
            }
        }

        if !requiredShipKinds(for: mission).isEmpty,
           requiredShipKinds(for: mission).allSatisfy({ (ships[$0] ?? 0) <= 0 })
        {
            result.append(.missingRequiredShip)
        }

        if !isValidCargo(cargo) {
            result.append(.invalidCargo)
        }

        if cargoUsed > max(cargoCapacity, 0) {
            result.append(.insufficientCargoCapacity)
        }

        if let origin, fuelCost.isFinite, fuelCost >= 0 {
            let resourcesAfterCargo = origin.resources.subtracting(cargo)
            if !resourcesAfterCargo.canAfford(ResourceBundle(deuterium: fuelCost)) {
                result.append(.insufficientFuel)
            }
        } else if !ships.isEmpty, origin != nil, target != nil {
            result.append(.invalidMission)
        }

        if let target {
            switch mission {
            case .colonize:
                if target.ownerID != nil {
                    result.append(.occupiedTarget)
                }
                if !UniverseTopologyEngine.isValidPlanetCoordinate(target.coordinate) {
                    result.append(.invalidMission)
                }
                if let ownerFaction,
                   ownerFaction.ownedPlanetIDs.count >= TechnologyEffects.maxColonies(for: ownerFaction.technology)
                {
                    result.append(.colonizationLimit)
                }
            case .defend:
                if target.ownerID != ownerID {
                    result.append(.friendlyTargetRequired)
                }
            case .attack, .espionage:
                if !target.isVisible {
                    result.append(.targetNotVisible)
                }
            case .transport, .recycle, .explore, .returning:
                break
            }
        }

        return result.uniqued()
    }

    private static func notes(
        mission: Fleet.Mission,
        blockers: [FleetMissionPlan.Blocker],
        expectedValue: ResourceBundle,
        fuelCost: Double,
        travelDuration: TimeInterval,
        roundTripDuration: TimeInterval,
        riskLevel: FleetMissionPlan.RiskLevel
    ) -> [FleetMissionPlanNote] {
        var result: [FleetMissionPlanNote] = []

        if blockers.contains(.missingRequiredShip) {
            result.append(
                FleetMissionPlanNote(
                    kind: .requirement,
                    title: "任务舰船",
                    detail: "该任务需要 \(requiredShipKinds(for: mission).map(\.localizedName).joined(separator: " / "))。"
                )
            )
        }
        if blockers.contains(.insufficientFuel) {
            result.append(
                FleetMissionPlanNote(
                    kind: .warning,
                    title: "燃料不足",
                    detail: "补充重氢或降低货物后再发射。"
                )
            )
        }
        if blockers.contains(.insufficientCargoCapacity) {
            result.append(
                FleetMissionPlanNote(
                    kind: .warning,
                    title: "货舱不足",
                    detail: "减少货物或增加运输舰。"
                )
            )
        }
        if resourceTotal(expectedValue) > 0 {
            result.append(
                FleetMissionPlanNote(
                    kind: .value,
                    title: valueTitle(for: mission),
                    detail: resourceSummary(expectedValue)
                )
            )
        }
        if travelDuration > 0 {
            result.append(
                FleetMissionPlanNote(
                    kind: .timing,
                    title: "航程时间",
                    detail: "单程 \(wholeSeconds(travelDuration)) 秒，往返 \(wholeSeconds(roundTripDuration)) 秒。"
                )
            )
        }
        result.append(
            FleetMissionPlanNote(
                kind: .risk,
                title: "风险判断",
                detail: "\(riskLevel.localizedName)，发射前确认目标和返航时间。"
            )
        )

        return result
    }

    private static func expectedValue(
        mission: Fleet.Mission,
        cargo: ResourceBundle,
        cargoCapacity: Double,
        target: TargetSnapshot?
    ) -> ResourceBundle {
        let remainingCapacity = max(cargoCapacity - resourceTotal(cargo), 0)
        guard remainingCapacity > 0 else {
            return .zero
        }

        switch mission {
        case .recycle:
            return capped(target?.debris ?? .zero, limit: remainingCapacity)
        case .attack:
            return capped((target?.resources ?? .zero).scaled(by: 0.5), limit: remainingCapacity)
        case .transport:
            return cargo.nonnegative
        case .explore:
            return ResourceBundle(metal: min(remainingCapacity * 0.35, 5_000))
        case .colonize, .espionage, .defend, .returning:
            return .zero
        }
    }

    private static func riskLevel(
        mission: Fleet.Mission,
        target: TargetSnapshot?,
        ownerID: FactionID?
    ) -> FleetMissionPlan.RiskLevel {
        switch mission {
        case .attack:
            return .high
        case .espionage, .explore:
            return .medium
        case .recycle:
            return (target?.ownerID == nil || target?.ownerID == ownerID) ? .low : .medium
        case .transport, .colonize, .defend, .returning:
            return .low
        }
    }

    private static func requiredShipKinds(for mission: Fleet.Mission) -> [ShipKind] {
        switch mission {
        case .colonize:
            return [.colonyShip]
        case .recycle:
            return [.recycler]
        case .espionage:
            return [.espionageProbe]
        case .explore:
            return [.smallCargo, .largeCargo, .espionageProbe]
        case .attack, .defend, .transport, .returning:
            return []
        }
    }

    private static func computedTravelDuration(
        origin: Planet?,
        target: TargetSnapshot?,
        ships: [ShipKind: Int],
        ruleSet: RuleSet,
        research: ResearchState,
        speedPercent: Double
    ) -> TimeInterval {
        guard let origin, let target, !ships.isEmpty else {
            return 0
        }

        return FleetEngine.travelDuration(
            from: origin.coordinate,
            to: target.coordinate,
            ships: ships,
            ruleSet: ruleSet,
            research: research,
            speedPercent: speedPercent
        )
    }

    private static func computedFuelCost(
        origin: Planet?,
        target: TargetSnapshot?,
        ships: [ShipKind: Int],
        ruleSet: RuleSet,
        research: ResearchState,
        speedPercent: Double
    ) -> Double {
        guard let origin, let target, !ships.isEmpty else {
            return 0
        }

        return FleetEngine.fuelCost(
            from: origin.coordinate,
            to: target.coordinate,
            ships: ships,
            ruleSet: ruleSet,
            research: research,
            speedPercent: speedPercent
        )
    }

    private static func fleetCargoCapacity(for ships: [ShipKind: Int], ruleSet: RuleSet) -> Double {
        var capacity = 0.0
        for (kind, quantity) in ships {
            guard let rule = ruleSet.shipRules[kind],
                  rule.cargoCapacity.isFinite,
                  rule.cargoCapacity >= 0
            else {
                return -1
            }
            capacity += rule.cargoCapacity * Double(max(quantity, 0))
        }
        return capacity.isFinite ? capacity : -1
    }

    private static func normalizedShips(_ ships: [ShipKind: Int]) -> [ShipKind: Int] {
        ships.reduce(into: [:]) { result, element in
            let quantity = max(element.value, 0)
            guard quantity > 0 else {
                return
            }
            result[element.key, default: 0] += quantity
        }
    }

    private static func sanitizedCargo(_ cargo: ResourceBundle) -> ResourceBundle {
        guard isValidCargo(cargo) else {
            return cargo
        }
        return cargo.nonnegative
    }

    private static func isValidCargo(_ cargo: ResourceBundle) -> Bool {
        cargo.metal.isFinite &&
            cargo.crystal.isFinite &&
            cargo.deuterium.isFinite &&
            cargo.metal >= 0 &&
            cargo.crystal >= 0 &&
            cargo.deuterium >= 0
    }

    private static func capped(_ resources: ResourceBundle, limit: Double) -> ResourceBundle {
        guard limit.isFinite, limit > 0 else {
            return .zero
        }

        var remaining = limit
        let metal = min(max(resources.metal, 0), remaining)
        remaining -= metal
        let crystal = min(max(resources.crystal, 0), remaining)
        remaining -= crystal
        let deuterium = min(max(resources.deuterium, 0), remaining)
        return ResourceBundle(metal: metal, crystal: crystal, deuterium: deuterium)
    }

    private static func resourceTotal(_ resources: ResourceBundle) -> Double {
        guard resources.metal.isFinite, resources.crystal.isFinite, resources.deuterium.isFinite else {
            return .infinity
        }
        return resources.metal + resources.crystal + resources.deuterium
    }

    private static func resourceSummary(_ resources: ResourceBundle) -> String {
        "金属 \(whole(resources.metal)) / 晶体 \(whole(resources.crystal)) / 重氢 \(whole(resources.deuterium))"
    }

    private static func valueTitle(for mission: Fleet.Mission) -> String {
        switch mission {
        case .recycle:
            return "残骸收益"
        case .attack:
            return "掠夺预估"
        case .transport:
            return "运输货物"
        case .explore:
            return "远征期望"
        case .colonize, .espionage, .defend, .returning:
            return "任务收益"
        }
    }

    private static func whole(_ value: Double) -> String {
        guard value.isFinite else {
            return "未知"
        }
        return String(Int(value.rounded()))
    }

    private static func wholeSeconds(_ value: TimeInterval) -> String {
        whole(value)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        var result: [Element] = []
        for element in self where !seen.contains(element) {
            seen.insert(element)
            result.append(element)
        }
        return result
    }
}
