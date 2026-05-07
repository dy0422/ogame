import Foundation

public enum FleetLaunchFailure: Equatable, Sendable {
    case missingOrigin
    case missingTarget
    case missingOwner
    case insufficientShips
    case insufficientCargo
    case insufficientFuel
    case invalidMission
}

public enum FleetLaunchResult: Equatable, Sendable {
    case launched(Fleet)
    case failure(FleetLaunchFailure)
}

public enum FleetEngine {
    public static func launchFleet(
        from originPlanetID: PlanetID,
        to targetPlanetID: PlanetID,
        in universe: inout Universe,
        mission: Fleet.Mission,
        ships requestedShips: [ShipKind: Int],
        cargo: ResourceBundle = .zero
    ) -> FleetLaunchResult {
        guard let originIndex = universe.planets.firstIndex(where: { $0.id == originPlanetID }) else {
            return .failure(.missingOrigin)
        }

        guard let targetIndex = universe.planets.firstIndex(where: { $0.id == targetPlanetID }) else {
            return .failure(.missingTarget)
        }

        guard let ownerID = universe.planets[originIndex].ownerID else {
            return .failure(.missingOwner)
        }

        let ships = normalizedShips(requestedShips)
        guard !ships.isEmpty, isValidLaunchMission(mission, ships: ships, target: universe.planets[targetIndex]) else {
            return .failure(.invalidMission)
        }

        guard ships.allSatisfy({ kind, quantity in
            (universe.planets[originIndex].shipInventory[kind] ?? 0) >= quantity
        }) else {
            return .failure(.insufficientShips)
        }

        guard isValidResources(cargo) else {
            return .failure(.insufficientCargo)
        }

        guard universe.planets[originIndex].resources.canAfford(cargo) else {
            return .failure(.insufficientCargo)
        }

        let availableCargoCapacity = cargoCapacity(for: ships, ruleSet: universe.ruleSet)
        guard availableCargoCapacity.isFinite, availableCargoCapacity >= 0 else {
            return .failure(.invalidMission)
        }

        guard cargo.totalAmount <= availableCargoCapacity else {
            return .failure(.insufficientCargo)
        }

        let fuel = fuelCost(
            from: universe.planets[originIndex].coordinate,
            to: universe.planets[targetIndex].coordinate,
            ships: ships,
            ruleSet: universe.ruleSet
        )
        guard fuel.isFinite, fuel >= 0 else {
            return .failure(.invalidMission)
        }

        let resourcesAfterCargo = universe.planets[originIndex].resources.subtracting(cargo)
        guard resourcesAfterCargo.canAfford(ResourceBundle(deuterium: fuel)) else {
            return .failure(.insufficientFuel)
        }

        let travelTime = travelDuration(
            from: universe.planets[originIndex].coordinate,
            to: universe.planets[targetIndex].coordinate,
            ships: ships,
            ruleSet: universe.ruleSet
        )
        guard universe.gameTime.isFinite, travelTime.isFinite, travelTime > 0 else {
            return .failure(.invalidMission)
        }

        let arrivalTime = universe.gameTime + travelTime
        let returnTime = arrivalTime + travelTime
        guard arrivalTime.isFinite, returnTime.isFinite else {
            return .failure(.invalidMission)
        }

        let launchSequence = launchSequencePayload(in: universe)

        for (kind, quantity) in ships {
            let remainingQuantity = (universe.planets[originIndex].shipInventory[kind] ?? 0) - quantity
            universe.planets[originIndex].shipInventory[kind] = remainingQuantity > 0 ? remainingQuantity : nil
        }
        universe.planets[originIndex].resources = resourcesAfterCargo
            .subtracting(ResourceBundle(deuterium: fuel))
            .nonnegative

        let fleet = Fleet(
            id: FleetID(
                stableUUID(
                    namespace: "000c",
                    payload: [
                        "fleet-launch",
                        universe.id.rawValue.uuidString,
                        ownerID.rawValue.uuidString,
                        originPlanetID.rawValue.uuidString,
                        targetPlanetID.rawValue.uuidString,
                        mission.rawValue,
                        shipPayload(ships),
                        resourcePayload(cargo),
                        launchSequence,
                        String(universe.gameTime),
                        String(arrivalTime),
                        String(returnTime)
                    ].joined(separator: "|")
                )
            ),
            ownerID: ownerID,
            mission: mission,
            origin: universe.planets[originIndex].coordinate,
            target: universe.planets[targetIndex].coordinate,
            ships: ships,
            cargo: cargo,
            launchTime: universe.gameTime,
            arrivalTime: arrivalTime,
            returnTime: returnTime,
            phase: .outbound,
            originPlanetID: originPlanetID,
            targetPlanetID: targetPlanetID
        )

        universe.fleets.append(fleet)
        universe.events.append(
            fleetLaunchEvent(
                for: fleet,
                origin: universe.planets[originIndex],
                target: universe.planets[targetIndex],
                sequence: launchSequence
            )
        )

        return .launched(fleet)
    }

    public static func resolveDueFleets(in universe: inout Universe) {
        guard universe.gameTime.isFinite else {
            return
        }

        var unresolvedFleets: [Fleet] = []

        for fleet in universe.fleets {
            switch fleet.phase {
            case .outbound, .holding:
                if fleet.arrivalTime.isFinite, fleet.arrivalTime <= universe.gameTime {
                    if let returningFleet = resolveArrival(fleet, in: &universe) {
                        if returningFleet.phase == .returning,
                           returningFleet.returnTime.isFinite,
                           returningFleet.returnTime <= universe.gameTime
                        {
                            resolveReturn(returningFleet, in: &universe)
                        } else {
                            unresolvedFleets.append(returningFleet)
                        }
                    }
                } else {
                    unresolvedFleets.append(fleet)
                }
            case .returning:
                if fleet.returnTime.isFinite, fleet.returnTime <= universe.gameTime {
                    resolveReturn(fleet, in: &universe)
                } else {
                    unresolvedFleets.append(fleet)
                }
            case .completed:
                continue
            }
        }

        universe.fleets = unresolvedFleets
    }

    public static func travelDuration(
        from origin: Coordinate,
        to target: Coordinate,
        ships: [ShipKind: Int],
        ruleSet: RuleSet
    ) -> TimeInterval {
        let normalized = normalizedShips(ships)
        guard !normalized.isEmpty else {
            return 0
        }

        let slowestSpeed = normalized.keys.compactMap { ruleSet.shipRules[$0]?.speed }.min() ?? 0
        guard slowestSpeed.isFinite, slowestSpeed > 0 else {
            return 0
        }

        let distance = coordinateDistance(from: origin, to: target)
        guard distance.isFinite, distance > 0 else {
            return 0
        }

        let duration = ceil((distance / slowestSpeed) * 3_600)
        guard duration.isFinite, duration > 0 else {
            return 0
        }

        return duration
    }

    public static func fuelCost(
        from origin: Coordinate,
        to target: Coordinate,
        ships: [ShipKind: Int],
        ruleSet: RuleSet
    ) -> Double {
        let normalized = normalizedShips(ships)
        guard !normalized.isEmpty else {
            return 0
        }

        let distance = coordinateDistance(from: origin, to: target)
        guard distance.isFinite, distance > 0 else {
            return 0
        }

        var baseCost = 0.0
        for (kind, quantity) in normalized {
            guard let rule = ruleSet.shipRules[kind],
                  rule.fuelCost.isFinite,
                  rule.fuelCost >= 0
            else {
                return .infinity
            }

            baseCost += rule.fuelCost * Double(quantity)
        }

        guard baseCost.isFinite, baseCost >= 0 else {
            return .infinity
        }

        return ceil((distance / 1_000) * baseCost)
    }

    private static func resolveArrival(_ fleet: Fleet, in universe: inout Universe) -> Fleet? {
        var returningFleet = fleet
        returningFleet.phase = .returning

        switch fleet.mission {
        case .transport:
            if let targetIndex = targetPlanetIndex(for: fleet, in: universe) {
                returningFleet.cargo = depositCargo(
                    fleet.cargo,
                    into: &universe.planets[targetIndex],
                    limitedByStorage: true
                )
                universe.events.append(missionEvent(for: fleet, time: fleet.arrivalTime, kind: .system, title: "Transport Delivered"))
            }
        case .recycle:
            if let targetIndex = targetPlanetIndex(for: fleet, in: universe) {
                let availableCapacity = max(cargoCapacity(for: fleet.ships, ruleSet: universe.ruleSet) - fleet.cargo.totalAmount, 0)
                let collected = collectResources(from: universe.planets[targetIndex].debrisField, limit: availableCapacity)
                universe.planets[targetIndex].debrisField = universe.planets[targetIndex].debrisField.subtracting(collected).nonnegative
                returningFleet.cargo = safeAdding(fleet.cargo, collected)
                universe.events.append(missionEvent(for: fleet, time: fleet.arrivalTime, kind: .system, title: "Debris Recovered"))
            }
        case .explore:
            let reward = explorationReward(for: fleet, universe: universe)
            returningFleet.cargo = safeAdding(fleet.cargo, reward)
            recordExploredTarget(for: fleet, in: &universe)
            universe.events.append(missionEvent(for: fleet, time: fleet.arrivalTime, kind: .exploration, title: "Exploration Complete"))
        case .colonize:
            if let targetIndex = targetPlanetIndex(for: fleet, in: universe),
               universe.planets[targetIndex].ownerID == nil,
               (fleet.ships[.colonyShip] ?? 0) > 0
            {
                universe.planets[targetIndex].ownerID = fleet.ownerID
                if let factionIndex = universe.factions.firstIndex(where: { $0.id == fleet.ownerID }),
                   !universe.factions[factionIndex].ownedPlanetIDs.contains(universe.planets[targetIndex].id)
                {
                    universe.factions[factionIndex].ownedPlanetIDs.append(universe.planets[targetIndex].id)
                }

                let remainingColonyShips = (returningFleet.ships[.colonyShip] ?? 0) - 1
                returningFleet.ships[.colonyShip] = remainingColonyShips > 0 ? remainingColonyShips : nil
                universe.events.append(missionEvent(for: fleet, time: fleet.arrivalTime, kind: .system, title: "Colony Established"))
            }
        case .attack:
            guard let combatReturn = CombatEngine.resolveAttack(fleet, in: &universe) else {
                universe.events.append(missionEvent(for: fleet, time: fleet.arrivalTime, kind: .combat, title: "Combat Resolved"))
                return nil
            }
            returningFleet = combatReturn
            universe.events.append(missionEvent(for: returningFleet, time: fleet.arrivalTime, kind: .combat, title: "Combat Resolved"))
        case .espionage:
            guard let espionageReturn = CombatEngine.resolveEspionage(fleet, in: &universe) else {
                universe.events.append(missionEvent(for: fleet, time: fleet.arrivalTime, kind: .intelligence, title: "Espionage Report"))
                return nil
            }
            returningFleet = espionageReturn
            universe.events.append(missionEvent(for: returningFleet, time: fleet.arrivalTime, kind: .intelligence, title: "Espionage Report"))
        case .returning:
            resolveReturn(fleet, in: &universe)
            return nil
        }

        return returningFleet
    }

    private static func resolveReturn(_ fleet: Fleet, in universe: inout Universe) {
        guard let originIndex = originPlanetIndex(for: fleet, in: universe) else {
            universe.events.append(missionEvent(for: fleet, time: fleet.returnTime, kind: .system, title: "Fleet Lost Contact"))
            return
        }

        for (kind, quantity) in fleet.ships where quantity > 0 {
            let currentQuantity = max(universe.planets[originIndex].shipInventory[kind] ?? 0, 0)
            let addition = currentQuantity.addingReportingOverflow(quantity)
            guard !addition.overflow else {
                continue
            }

            universe.planets[originIndex].shipInventory[kind] = addition.partialValue
        }

        _ = depositCargo(fleet.cargo, into: &universe.planets[originIndex], limitedByStorage: false)
        universe.events.append(missionEvent(for: fleet, time: fleet.returnTime, kind: .system, title: "Fleet Returned"))
    }

    private static func isValidLaunchMission(_ mission: Fleet.Mission, ships: [ShipKind: Int], target: Planet) -> Bool {
        switch mission {
        case .transport, .attack, .espionage, .explore:
            return true
        case .recycle:
            return (ships[.recycler] ?? 0) > 0
        case .colonize:
            return target.ownerID == nil && (ships[.colonyShip] ?? 0) > 0
        case .returning:
            return false
        }
    }

    private static func normalizedShips(_ ships: [ShipKind: Int]) -> [ShipKind: Int] {
        ships.reduce(into: [:]) { result, element in
            guard element.value > 0 else {
                return
            }

            let current = result[element.key] ?? 0
            let addition = current.addingReportingOverflow(element.value)
            guard !addition.overflow else {
                return
            }

            result[element.key] = addition.partialValue
        }
    }

    private static func cargoCapacity(for ships: [ShipKind: Int], ruleSet: RuleSet) -> Double {
        var capacity = 0.0

        for (kind, quantity) in normalizedShips(ships) {
            guard let rule = ruleSet.shipRules[kind],
                  rule.speed.isFinite,
                  rule.speed > 0,
                  rule.cargoCapacity.isFinite,
                  rule.cargoCapacity >= 0
            else {
                return -1
            }

            capacity += rule.cargoCapacity * Double(quantity)
        }

        return capacity.isFinite ? capacity : -1
    }

    private static func coordinateDistance(from origin: Coordinate, to target: Coordinate) -> Double {
        let galaxyDistance = abs(target.galaxy - origin.galaxy)
        if galaxyDistance > 0 {
            return Double(galaxyDistance) * 20_000
        }

        let systemDistance = abs(target.system - origin.system)
        if systemDistance > 0 {
            return Double(systemDistance) * 2_700 + 95
        }

        let positionDistance = abs(target.position - origin.position)
        if positionDistance > 0 {
            return Double(positionDistance) * 1_000 + 5
        }

        return 5
    }

    private static func originPlanetIndex(for fleet: Fleet, in universe: Universe) -> Int? {
        if let originPlanetID = fleet.originPlanetID,
           let index = universe.planets.firstIndex(where: { $0.id == originPlanetID })
        {
            return index
        }

        return universe.planets.firstIndex(where: { $0.coordinate == fleet.origin && $0.ownerID == fleet.ownerID })
    }

    private static func targetPlanetIndex(for fleet: Fleet, in universe: Universe) -> Int? {
        if let targetPlanetID = fleet.targetPlanetID,
           let index = universe.planets.firstIndex(where: { $0.id == targetPlanetID })
        {
            return index
        }

        return universe.planets.firstIndex(where: { $0.coordinate == fleet.target })
    }

    private static func recordExploredTarget(for fleet: Fleet, in universe: inout Universe) {
        guard fleet.ownerID == universe.playerFactionID,
              let targetIndex = targetPlanetIndex(for: fleet, in: universe)
        else {
            return
        }

        let planetID = universe.planets[targetIndex].id
        guard !universe.victoryState.exploredPlanetIDs.contains(planetID) else {
            return
        }

        universe.victoryState.exploredPlanetIDs.append(planetID)
    }

    private static func collectResources(from resources: ResourceBundle, limit: Double) -> ResourceBundle {
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

    private static func explorationReward(for fleet: Fleet, universe: Universe) -> ResourceBundle {
        let payload = [
            "explore",
            String(universe.seed),
            fleet.id.rawValue.uuidString,
            fleet.ownerID.rawValue.uuidString,
            fleet.target.displayText,
            String(fleet.arrivalTime)
        ].joined(separator: "|")
        var generator = SeededGenerator(seed: stableHash(payload))
        let availableCapacity = max(cargoCapacity(for: fleet.ships, ruleSet: universe.ruleSet) - fleet.cargo.totalAmount, 0)
        guard availableCapacity > 0 else {
            return .zero
        }

        let rawReward = ResourceBundle(
            metal: Double(generator.nextInt(in: 25...90)),
            crystal: Double(generator.nextInt(in: 10...60)),
            deuterium: Double(generator.nextInt(in: 0...25))
        )
        return collectResources(from: rawReward, limit: availableCapacity)
    }

    private static func depositCargo(
        _ cargo: ResourceBundle,
        into planet: inout Planet,
        limitedByStorage: Bool
    ) -> ResourceBundle {
        guard isValidResources(cargo) else {
            return .zero
        }

        if !limitedByStorage {
            planet.resources = safeAdding(planet.resources, cargo)
            return .zero
        }

        let availableStorage = ResourceBundle(
            metal: max(planet.storage.metal - planet.resources.metal, 0),
            crystal: max(planet.storage.crystal - planet.resources.crystal, 0),
            deuterium: max(planet.storage.deuterium - planet.resources.deuterium, 0)
        )
        let delivered = ResourceBundle(
            metal: min(cargo.metal, availableStorage.metal),
            crystal: min(cargo.crystal, availableStorage.crystal),
            deuterium: min(cargo.deuterium, availableStorage.deuterium)
        )

        planet.resources = safeAdding(planet.resources, delivered)
        return cargo.subtracting(delivered).nonnegative
    }

    private static func safeAdding(_ lhs: ResourceBundle, _ rhs: ResourceBundle) -> ResourceBundle {
        let result = lhs.adding(rhs)
        guard isValidResources(result) else {
            return ResourceBundle(
                metal: lhs.metal.isFinite ? max(lhs.metal, 0) : 0,
                crystal: lhs.crystal.isFinite ? max(lhs.crystal, 0) : 0,
                deuterium: lhs.deuterium.isFinite ? max(lhs.deuterium, 0) : 0
            )
        }

        return result
    }

    private static func isValidResources(_ resources: ResourceBundle) -> Bool {
        resources.metal.isFinite &&
            resources.crystal.isFinite &&
            resources.deuterium.isFinite &&
            resources.metal >= 0 &&
            resources.crystal >= 0 &&
            resources.deuterium >= 0
    }

    private static func fleetLaunchEvent(for fleet: Fleet, origin: Planet, target: Planet, sequence: String) -> GameEvent {
        GameEvent(
            id: EventID(
                stableUUID(
                    namespace: "000d",
                    payload: [
                        "fleet-launched",
                        fleet.id.rawValue.uuidString,
                        origin.id.rawValue.uuidString,
                        target.id.rawValue.uuidString,
                        sequence,
                        String(fleet.launchTime)
                    ].joined(separator: "|")
                )
            ),
            time: fleet.launchTime,
            kind: .system,
            title: "Fleet Launched",
            message: "\(origin.name) launched a \(fleet.mission.rawValue) fleet to \(target.coordinate.displayText)."
        )
    }

    private static func launchSequencePayload(in universe: Universe) -> String {
        [
            String(universe.fleets.count),
            String(universe.events.count)
        ].joined(separator: ":")
    }

    private static func missionEvent(for fleet: Fleet, time: TimeInterval, kind: GameEvent.Kind, title: String) -> GameEvent {
        GameEvent(
            id: EventID(
                stableUUID(
                    namespace: "000e",
                    payload: [
                        title,
                        fleet.id.rawValue.uuidString,
                        fleet.mission.rawValue,
                        fleet.phase.rawValue,
                        String(time),
                        resourcePayload(fleet.cargo),
                        shipPayload(fleet.ships)
                    ].joined(separator: "|")
                )
            ),
            time: time,
            kind: kind,
            title: title,
            message: "\(fleet.mission.rawValue.capitalized) fleet \(fleet.id.rawValue.uuidString) resolved at \(fleet.target.displayText)."
        )
    }

    private static func stableUUID(namespace: String, payload: String) -> UUID {
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

    private static func shipPayload(_ ships: [ShipKind: Int]) -> String {
        normalizedShips(ships)
            .keys
            .sorted(by: { $0.rawValue < $1.rawValue })
            .map { "\($0.rawValue):\(ships[$0] ?? 0)" }
            .joined(separator: ",")
    }

    private static func resourcePayload(_ resources: ResourceBundle) -> String {
        "\(resources.metal),\(resources.crystal),\(resources.deuterium)"
    }
}

private extension ResourceBundle {
    var totalAmount: Double {
        metal + crystal + deuterium
    }
}
