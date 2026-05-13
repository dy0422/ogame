import Foundation

public struct ActionChainFleetActionPlan: Equatable, Sendable {
    public enum RiskLevel: String, Equatable, Sendable {
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

    public enum Status: String, Equatable, Sendable {
        case ready
        case complete
        case locked
        case missingChain
        case missingTarget
        case unsupported
        case blocked
    }

    public var status: Status
    public var chainID: UUID?
    public var stepKind: ActionChain.Step.Kind?
    public var mission: Fleet.Mission?
    public var originID: PlanetID?
    public var targetID: PlanetID?
    public var commanderID: CommanderID?
    public var ships: [ShipKind: Int]
    public var blockers: [FleetMissionPlan.Blocker]
    public var selectedPower: Double
    public var requiredPower: Double

    public init(
        status: Status,
        chainID: UUID? = nil,
        stepKind: ActionChain.Step.Kind? = nil,
        mission: Fleet.Mission? = nil,
        originID: PlanetID? = nil,
        targetID: PlanetID? = nil,
        commanderID: CommanderID? = nil,
        ships: [ShipKind: Int] = [:],
        blockers: [FleetMissionPlan.Blocker] = [],
        selectedPower: Double = 0,
        requiredPower: Double = 0
    ) {
        self.status = status
        self.chainID = chainID
        self.stepKind = stepKind
        self.mission = mission
        self.originID = originID
        self.targetID = targetID
        self.commanderID = commanderID
        self.ships = ships.filter { $0.value > 0 }
        self.blockers = blockers
        self.selectedPower = selectedPower.isFinite ? max(selectedPower, 0) : 0
        self.requiredPower = requiredPower.isFinite ? max(requiredPower, 0) : 0
    }

    public var isLaunchable: Bool {
        status == .ready &&
            mission != nil &&
            originID != nil &&
            targetID != nil &&
            !ships.isEmpty &&
            blockers.isEmpty
    }

    public var powerRatio: Double {
        guard requiredPower > 0 else {
            return selectedPower > 0 ? .infinity : 0
        }
        return selectedPower / requiredPower
    }

    public var riskLevel: RiskLevel {
        if powerRatio >= 1 {
            return .low
        }
        if powerRatio >= 0.65 {
            return .medium
        }
        return .high
    }
}

public enum ActionChainFleetPlannerEngine {
    public static func nextActionPlan(for chainID: UUID, in universe: Universe) -> ActionChainFleetActionPlan {
        guard let chain = universe.actionChains.first(where: { $0.id == chainID }) else {
            return ActionChainFleetActionPlan(status: .missingChain, chainID: chainID)
        }
        guard let step = chain.steps.first(where: { $0.status != .complete }) else {
            return ActionChainFleetActionPlan(status: .complete, chainID: chainID)
        }
        guard step.status == .ready else {
            return ActionChainFleetActionPlan(status: .locked, chainID: chainID, stepKind: step.kind)
        }

        switch chain.kind {
        case .hostileRaid:
            return hostileRaidPlan(for: chain, step: step, in: universe)
        case .sectorDevelopment, .relicRecovery:
            return ActionChainFleetActionPlan(status: .unsupported, chainID: chainID, stepKind: step.kind)
        }
    }

    private static func hostileRaidPlan(
        for chain: ActionChain,
        step: ActionChain.Step,
        in universe: Universe
    ) -> ActionChainFleetActionPlan {
        guard let site = hostileSite(for: chain, in: universe),
              let targetID = site.targetPlanetID
        else {
            return ActionChainFleetActionPlan(status: .missingTarget, chainID: chain.id, stepKind: step.kind)
        }

        let mission: Fleet.Mission
        switch step.kind {
        case .scoutTarget:
            mission = .espionage
        case .strikeHostile:
            mission = .attack
        case .recoverSpoils:
            mission = .recycle
        case .secureSector, .buildLogistics:
            return ActionChainFleetActionPlan(status: .unsupported, chainID: chain.id, stepKind: step.kind)
        }

        return bestLaunchPlan(
            chainID: chain.id,
            stepKind: step.kind,
            mission: mission,
            targetID: targetID,
            requiredPower: mission == .attack ? site.requiredPower : 0,
            in: universe
        )
    }

    private static func bestLaunchPlan(
        chainID: UUID,
        stepKind: ActionChain.Step.Kind,
        mission: Fleet.Mission,
        targetID: PlanetID,
        requiredPower: Double,
        in universe: Universe
    ) -> ActionChainFleetActionPlan {
        let origins = universe.planets
            .filter { $0.ownerID == universe.playerFactionID }
            .sorted { lhs, rhs in
                if lhs.coordinate.displayText != rhs.coordinate.displayText {
                    return lhs.coordinate.displayText < rhs.coordinate.displayText
                }
                return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
            }

        var fallback: ActionChainFleetActionPlan?
        var bestLaunchableFallback: ActionChainFleetActionPlan?
        for origin in origins {
            let ships = recommendedShips(for: mission, on: origin)
            guard !ships.isEmpty else {
                continue
            }
            let commanderID = recommendedCommanderID(for: mission, ownerID: universe.playerFactionID, in: universe)

            let fleetPlan = FleetMissionPlannerEngine.plan(
                originID: origin.id,
                targetID: targetID,
                in: universe,
                mission: mission,
                ships: ships
            )
            let actionPlan = ActionChainFleetActionPlan(
                status: fleetPlan.isLaunchable ? .ready : .blocked,
                chainID: chainID,
                stepKind: stepKind,
                mission: mission,
                originID: origin.id,
                targetID: targetID,
                commanderID: commanderID,
                ships: ships,
                blockers: fleetPlan.blockers,
                selectedPower: combatPower(
                    for: ships,
                    ruleSet: universe.ruleSet,
                    commanderBonus: CommanderBonusEngine.fleetBonus(for: commanderID, in: universe)
                ),
                requiredPower: requiredPower
            )
            if actionPlan.isLaunchable {
                if mission != .attack || actionPlan.powerRatio >= 1 {
                    return actionPlan
                }
                if bestLaunchableFallback == nil || actionPlan.selectedPower > (bestLaunchableFallback?.selectedPower ?? 0) {
                    bestLaunchableFallback = actionPlan
                }
            }
            fallback = fallback ?? actionPlan
        }

        if let bestLaunchableFallback {
            return bestLaunchableFallback
        }

        return fallback ?? ActionChainFleetActionPlan(
            status: .blocked,
            chainID: chainID,
            stepKind: stepKind,
            mission: mission,
            targetID: targetID,
            blockers: [.noShipsSelected]
        )
    }

    private static func recommendedShips(for mission: Fleet.Mission, on planet: Planet) -> [ShipKind: Int] {
        switch mission {
        case .espionage:
            let probes = max(planet.shipInventory[.espionageProbe] ?? 0, 0)
            return probes > 0 ? [.espionageProbe: 1] : [:]
        case .recycle:
            let recyclers = max(planet.shipInventory[.recycler] ?? 0, 0)
            return recyclers > 0 ? [.recycler: 1] : [:]
        case .attack:
            let priorities: [ShipKind] = [.battlecruiser, .battleship, .cruiser, .heavyFighter, .lightFighter, .bomber, .destroyer, .deathstar]
            return priorities.reduce(into: [:]) { result, kind in
                let quantity = max(planet.shipInventory[kind] ?? 0, 0)
                if quantity > 0 {
                    result[kind] = quantity
                }
            }
        case .transport, .colonize, .defend, .explore, .returning:
            return FleetMissionPlannerEngine.recommendedShips(for: mission, on: planet)
        }
    }

    private static func recommendedCommanderID(
        for mission: Fleet.Mission,
        ownerID: FactionID,
        in universe: Universe
    ) -> CommanderID? {
        let busyCommanderIDs = Set(
            universe.fleets
                .filter { $0.ownerID == ownerID && $0.phase != .completed }
                .compactMap(\.commanderID)
        )

        return universe.commanderRoster.ownedCommanders
            .filter { !busyCommanderIDs.contains($0.id) }
            .sorted { lhs, rhs in
                let lhsScore = commanderPreferenceScore(lhs, mission: mission)
                let rhsScore = commanderPreferenceScore(rhs, mission: mission)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                if lhs.rarity != rhs.rarity {
                    return lhs.rarity > rhs.rarity
                }
                if lhs.level != rhs.level {
                    return lhs.level > rhs.level
                }
                return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
            }
            .first?
            .id
    }

    private static func commanderPreferenceScore(_ commander: OwnedCommander, mission: Fleet.Mission) -> Int {
        guard let definition = CommanderCatalog.definition(id: commander.definitionID) else {
            return 0
        }

        switch mission {
        case .attack, .defend:
            switch definition.specialty {
            case .fleetAdmiral:
                return 100
            case .technocrat:
                return 80
            case .engineer:
                return 70
            case .geologist:
                return 40
            case .explorer:
                return 30
            }
        case .espionage:
            switch definition.specialty {
            case .technocrat:
                return 100
            case .explorer:
                return 70
            case .fleetAdmiral:
                return 60
            case .engineer:
                return 40
            case .geologist:
                return 30
            }
        case .recycle, .transport:
            switch definition.specialty {
            case .geologist:
                return 100
            case .engineer:
                return 70
            case .fleetAdmiral:
                return 50
            case .technocrat:
                return 40
            case .explorer:
                return 30
            }
        case .explore, .colonize:
            switch definition.specialty {
            case .explorer:
                return 100
            case .geologist:
                return 60
            case .engineer:
                return 50
            case .technocrat:
                return 40
            case .fleetAdmiral:
                return 30
            }
        case .returning:
            return 0
        }
    }

    private static func combatPower(
        for ships: [ShipKind: Int],
        ruleSet: RuleSet,
        commanderBonus: CommanderFleetBonus = .none
    ) -> Double {
        ships.reduce(0) { total, element in
            guard let rule = ruleSet.shipRules[element.key] else {
                return total
            }
            let attack = max(rule.attack, 0) * commanderBonus.attackMultiplier
            let shield = max(rule.shield, 0) * commanderBonus.shieldMultiplier
            return total + (attack + shield) * Double(max(element.value, 0))
        }
    }

    private static func hostileSite(for chain: ActionChain, in universe: Universe) -> HostileSite? {
        universe.hostileSites.first { site in
            stableUUID("action-chain|hostile|\(site.id.uuidString)") == chain.id
        }
    }

    private static func stableUUID(_ payload: String) -> UUID {
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
