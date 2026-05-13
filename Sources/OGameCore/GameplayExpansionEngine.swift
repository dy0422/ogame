import Foundation

public enum GameplayExpansionEngine {
    private static let eventDuration: TimeInterval = 3_600
    private static let hostileDuration: TimeInterval = 7_200
    private static let actionChainDuration: TimeInterval = 7_200

    public static func refresh(in universe: inout Universe) {
        universe.sectorEvents = activeSectorEvents(in: universe)
        if universe.sectorEvents.isEmpty {
            universe.sectorEvents = generatedSectorEvents(in: universe)
        }

        universe.hostileSites = activeHostileSites(in: universe)
        if universe.hostileSites.isEmpty {
            universe.hostileSites = generatedHostileSites(in: universe)
        }

        universe.sectorControlSummaries = generatedSectorControl(in: universe)
        universe.tradeRoutes = generatedTradeRoutes(in: universe)
        universe.actionChains = generatedActionChains(in: universe)
        universe.deepIntelOperations = generatedDeepIntelOperations(in: universe)
        universe.fleetDoctrineSummaries = generatedDoctrineSummaries(in: universe)
        universe.artifacts = generatedArtifacts(in: universe)
        universe.crisisState = generatedCrisisState(in: universe)
    }

    private static func activeSectorEvents(in universe: Universe) -> [SectorEvent] {
        universe.sectorEvents
            .filter { $0.expiresAt > universe.gameTime }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private static func generatedSectorEvents(in universe: Universe) -> [SectorEvent] {
        let anchor = anchorCoordinate(in: universe)
        let startedAt = max(universe.gameTime, 0)
        let timeBucket = stableTimeBucket(startedAt, interval: eventDuration)
        return [
            SectorEvent(
                id: stableUUID("sector-event|pirate|\(universe.seed)|\(timeBucket)"),
                kind: .pirateActivity,
                title: "海盗活动",
                detail: "附近星区出现掠夺信号，打击海盗可获得残骸和行动链奖励。",
                coordinate: anchor,
                startedAt: startedAt,
                expiresAt: startedAt + eventDuration,
                resourceMultiplier: 1,
                fleetSpeedMultiplier: 1,
                riskModifier: 0.2
            ),
            SectorEvent(
                id: stableUUID("sector-event|relic|\(universe.seed)|\(timeBucket)"),
                kind: .ancientRelic,
                title: "远古遗迹",
                detail: "深空信号暴露了可回收遗物，适合派出侦察和远征舰队。",
                coordinate: anchor,
                startedAt: startedAt,
                expiresAt: startedAt + eventDuration * 2,
                resourceMultiplier: 1.1,
                fleetSpeedMultiplier: 1,
                riskModifier: -0.05
            )
        ]
    }

    private static func activeHostileSites(in universe: Universe) -> [HostileSite] {
        universe.hostileSites
            .filter { $0.expiresAt > universe.gameTime }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private static func generatedHostileSites(in universe: Universe) -> [HostileSite] {
        let candidates = universe.planets
            .filter { $0.ownerID == nil }
            .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
        let fallback = anchorCoordinate(in: universe)
        let first = candidates.first
        let second = candidates.dropFirst().first

        return [
            HostileSite(
                id: stableUUID("hostile|pirate|\(universe.seed)|\(first?.id.rawValue.uuidString ?? fallback.displayText)"),
                kind: .pirateBase,
                name: "海盗补给站",
                coordinate: first?.coordinate ?? fallback,
                targetPlanetID: first?.id,
                threatLevel: 2,
                requiredPower: 800,
                reward: ResourceBundle(metal: 4_000, crystal: 2_000, deuterium: 800),
                commanderReward: CommanderRewardBundle(
                    recruitmentTickets: 1,
                    trainingData: 120,
                    commanderDropChance: 0.01
                ),
                expiresAt: universe.gameTime + hostileDuration
            ),
            HostileSite(
                id: stableUUID("hostile|alien|\(universe.seed)|\(second?.id.rawValue.uuidString ?? fallback.displayText)"),
                kind: .alienOutpost,
                name: "外星前哨",
                coordinate: second?.coordinate ?? fallback,
                targetPlanetID: second?.id,
                threatLevel: 3,
                requiredPower: 1_500,
                reward: ResourceBundle(metal: 6_000, crystal: 4_000, deuterium: 1_500),
                commanderReward: CommanderRewardBundle(
                    recruitmentTickets: 2,
                    trainingData: 220,
                    commanderDropChance: 0.03
                ),
                expiresAt: universe.gameTime + hostileDuration
            )
        ]
    }

    private static func generatedActionChains(in universe: Universe) -> [ActionChain] {
        var chains: [ActionChain] = []
        if let site = universe.hostileSites.sorted(by: { $0.threatLevel < $1.threatLevel }).first {
            chains.append(
                ActionChain(
                    id: stableUUID("action-chain|hostile|\(site.id.uuidString)"),
                    kind: .hostileRaid,
                    title: "清剿 \(site.name)",
                    detail: "先侦察、再打击、最后回收残骸，形成一条完整 PVE 收益链。",
                    steps: [
                        ActionChain.Step(kind: .scoutTarget, title: "侦察目标", status: .ready),
                        ActionChain.Step(kind: .strikeHostile, title: "打击据点", status: playerCombatPower(in: universe) >= site.requiredPower ? .ready : .locked),
                        ActionChain.Step(kind: .recoverSpoils, title: "回收战利品", status: hasRecycler(in: universe) ? .ready : .locked)
                    ],
                    reward: site.reward,
                    commanderReward: site.commanderReward,
                    expiresAt: min(site.expiresAt, universe.gameTime + actionChainDuration)
                )
            )
        }

        if let control = generatedSectorControl(in: universe).first(where: { $0.ownerID == universe.playerFactionID }) {
            chains.append(
                ActionChain(
                    id: stableUUID("action-chain|sector|\(control.id)"),
                    kind: .sectorDevelopment,
                    title: "巩固 \(control.galaxy):\(control.system) 星区",
                    detail: "用贸易路线和驻防把殖民地变成稳定势力范围。",
                    steps: [
                        ActionChain.Step(kind: .secureSector, title: "维持双星控制", status: .complete),
                        ActionChain.Step(kind: .buildLogistics, title: "建立补给线", status: universe.tradeRoutes.isEmpty ? .locked : .ready)
                    ],
                    reward: ResourceBundle(metal: 3_000, crystal: 2_000, deuterium: 1_000),
                    commanderReward: CommanderRewardBundle(recruitmentTickets: 1, trainingData: 80),
                    expiresAt: universe.gameTime + actionChainDuration
                )
            )
        }

        return chains
    }

    private static func generatedSectorControl(in universe: Universe) -> [SectorControlSummary] {
        let ownedPlanets = universe.planets.filter { $0.ownerID != nil }
        let grouped = Dictionary(grouping: ownedPlanets) { planet in
            "\(planet.ownerID!.rawValue.uuidString)|\(planet.coordinate.galaxy)|\(planet.coordinate.system)"
        }

        return grouped.values.compactMap { planets in
            guard let ownerID = planets.first?.ownerID, let coordinate = planets.first?.coordinate, planets.count >= 2 else {
                return nil
            }
            let level = min(planets.count, 5)
            return SectorControlSummary(
                ownerID: ownerID,
                galaxy: coordinate.galaxy,
                system: coordinate.system,
                controlLevel: level,
                resourceBonus: Double(level) * 0.03,
                sensorBonus: Double(level) * 0.05
            )
        }
        .sorted { lhs, rhs in
            if lhs.ownerID != rhs.ownerID {
                return lhs.ownerID.rawValue.uuidString < rhs.ownerID.rawValue.uuidString
            }
            if lhs.galaxy != rhs.galaxy {
                return lhs.galaxy < rhs.galaxy
            }
            return lhs.system < rhs.system
        }
    }

    private static func generatedTradeRoutes(in universe: Universe) -> [TradeRoute] {
        universe.factions.flatMap { faction -> [TradeRoute] in
            let planets = universe.planets
                .filter { $0.ownerID == faction.id }
                .sorted { resourceTotal($0.resources) > resourceTotal($1.resources) }
            guard let origin = planets.first, let target = planets.last, origin.id != target.id else {
                return []
            }
            let flow = ResourceBundle(
                metal: max(origin.resources.metal - target.resources.metal, 0) * 0.10,
                crystal: max(origin.resources.crystal - target.resources.crystal, 0) * 0.10,
                deuterium: max(origin.resources.deuterium - target.resources.deuterium, 0) * 0.10
            )
            let flowTotal = resourceTotal(flow)
            let nearbyThreat = universe.hostileSites.contains { $0.coordinate.galaxy == origin.coordinate.galaxy && abs($0.coordinate.system - origin.coordinate.system) <= 3 }
            return [
                TradeRoute(
                    id: stableUUID("trade|\(faction.id.rawValue.uuidString)|\(origin.id.rawValue.uuidString)|\(target.id.rawValue.uuidString)"),
                    ownerID: faction.id,
                    originPlanetID: origin.id,
                    targetPlanetID: target.id,
                    status: .profitable,
                    resourceFlow: flowTotal > 0 ? flow : ResourceBundle(metal: 500, crystal: 300, deuterium: 100),
                    riskLevel: nearbyThreat ? 0.45 : 0.15,
                    title: "\(origin.name) -> \(target.name)"
                )
            ]
        }
    }

    private static func generatedDeepIntelOperations(in universe: Universe) -> [DeepIntelOperation] {
        guard let player = universe.factions.first(where: { $0.id == universe.playerFactionID }) else {
            return []
        }
        let espionageLevel = player.technology.levels[.espionage] ?? 0
        let targets = universe.factions
            .filter { $0.kind == .ai && $0.id != player.id }
            .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
            .prefix(2)

        return targets.map { target in
            DeepIntelOperation(
                id: stableUUID("intel|\(player.id.rawValue.uuidString)|\(target.id.rawValue.uuidString)|\(espionageLevel)"),
                ownerID: player.id,
                targetFactionID: target.id,
                kind: .signalIntercept,
                intelTier: max(espionageLevel, 1),
                riskLevel: espionageLevel >= 3 ? 0.15 : 0.35,
                title: "截获 \(target.name) 信号",
                detail: "消耗探测窗口换取 AI 意图、舰队倾向和反侦察风险提示。"
            )
        }
    }

    private static func generatedDoctrineSummaries(in universe: Universe) -> [FleetDoctrineSummary] {
        let ships = playerShips(in: universe)
        var summaries: [FleetDoctrineSummary] = [
            FleetDoctrineSummary(
                doctrine: .expeditionary,
                title: "远征编组",
                detail: "运输舰、探测器和回收船优先，提升探索收益和安全撤离能力。",
                recommendedShips: [.smallCargo: max(ships[.smallCargo] ?? 0, 1), .espionageProbe: max(ships[.espionageProbe] ?? 0, 1)],
                speedBonus: 0.05,
                riskModifier: -0.05
            ),
            FleetDoctrineSummary(
                doctrine: .logistics,
                title: "补给编组",
                detail: "偏向运输和低风险往返，适合贸易路线与殖民地供给。",
                recommendedShips: [.smallCargo: max(ships[.smallCargo] ?? 0, 1), .largeCargo: max(ships[.largeCargo] ?? 0, 0)],
                speedBonus: 0,
                lootBonus: 0.05,
                riskModifier: -0.10
            )
        ]

        if combatShipCount(ships) > 0 {
            summaries.insert(
                FleetDoctrineSummary(
                    doctrine: .raiding,
                    title: "突袭编组",
                    detail: "轻舰和巡洋舰优先，适合清剿海盗和抓落单资源。",
                    recommendedShips: [.cruiser: max(ships[.cruiser] ?? 0, 1), .lightFighter: max(ships[.lightFighter] ?? 0, 2)],
                    speedBonus: 0.08,
                    lootBonus: 0.08,
                    riskModifier: 0.10
                ),
                at: 0
            )
        }

        return summaries
    }

    private static func generatedArtifacts(in universe: Universe) -> [Artifact] {
        var artifacts = universe.artifacts
        var existing = Set(artifacts.map(\.kind))

        func append(kind: Artifact.Kind, title: String, effect: String) {
            guard !existing.contains(kind) else { return }
            existing.insert(kind)
            artifacts.append(
                Artifact(
                    id: stableUUID("artifact|\(kind.rawValue)|\(universe.seed)"),
                    kind: kind,
                    title: title,
                    effect: effect,
                    unlockedAt: universe.gameTime
                )
            )
        }

        if universe.sectorEvents.contains(where: { $0.kind == .ancientRelic }) {
            append(kind: .logisticsRelic, title: "折跃航标残片", effect: "贸易路线风险降低，远征返航更稳定。")
        }
        if universe.reports.contains(where: { $0.kind == .battle }) {
            append(kind: .ancientBlueprint, title: "旧式战斗蓝图", effect: "战报复盘会给出更明确的舰种搭配建议。")
        }
        if !StrategicEngine.explorationRecords(for: universe.playerFactionID, in: universe).isEmpty {
            append(kind: .surveyArchive, title: "星图档案", effect: "探索路线检查点更容易定位下一处目标。")
        }

        return artifacts.sorted { $0.kind.rawValue < $1.kind.rawValue }
    }

    private static func generatedCrisisState(in universe: Universe) -> CrisisState? {
        if let crisis = universe.crisisState, crisis.progress < 1 {
            return crisis
        }
        guard universe.gameTime >= 7_200 else {
            return nil
        }
        let progress = min(max((universe.gameTime - 7_200) / 14_400, 0.15), 1)
        let phase: CrisisState.Phase = progress >= 0.75 ? .escalating : .active
        return CrisisState(
            kind: .pirateWarlord,
            phase: phase,
            startedAt: 7_200,
            targetPower: 4_000,
            progress: progress,
            title: "海盗王集结",
            detail: "海盗据点正在联络周边舰队。若不主动清剿，后续会提高星区贸易和远征风险。"
        )
    }

    private static func anchorCoordinate(in universe: Universe) -> Coordinate {
        universe.planets
            .filter { $0.ownerID == universe.playerFactionID }
            .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
            .first?
            .coordinate ?? Coordinate(galaxy: 1, system: 1, position: 4)
    }

    private static func playerShips(in universe: Universe) -> [ShipKind: Int] {
        universe.planets
            .filter { $0.ownerID == universe.playerFactionID }
            .reduce(into: [ShipKind: Int]()) { result, planet in
                for (kind, quantity) in planet.shipInventory {
                    result[kind, default: 0] += max(quantity, 0)
                }
            }
    }

    private static func playerCombatPower(in universe: Universe) -> Double {
        let ships = playerShips(in: universe)
        return ships.reduce(0) { total, element in
            guard let rule = universe.ruleSet.shipRules[element.key] else {
                return total
            }
            return total + (rule.attack + rule.shield) * Double(max(element.value, 0))
        }
    }

    private static func hasRecycler(in universe: Universe) -> Bool {
        (playerShips(in: universe)[.recycler] ?? 0) > 0
    }

    private static func combatShipCount(_ ships: [ShipKind: Int]) -> Int {
        ships.reduce(0) { total, element in
            switch element.key {
            case .lightFighter, .heavyFighter, .cruiser, .battleship, .battlecruiser, .bomber, .destroyer, .deathstar:
                return total + max(element.value, 0)
            case .smallCargo, .largeCargo, .colonyShip, .recycler, .espionageProbe, .solarSatellite:
                return total
            }
        }
    }

    private static func resourceTotal(_ resources: ResourceBundle) -> Double {
        max(resources.metal, 0) + max(resources.crystal, 0) + max(resources.deuterium, 0)
    }

    private static func stableUUID(_ payload: String) -> UUID {
        let hash = stableHash(payload)
        return UUID(uuidString: String(format: "00000000-0000-0000-%04x-%012llx", Int(hash & 0xffff), hash & 0xffffffffffff))!
    }

    private static func stableTimeBucket(_ time: TimeInterval, interval: TimeInterval) -> String {
        guard time.isFinite, interval.isFinite, interval > 0 else {
            return "invalid"
        }
        let bucket = floor(time / interval)
        guard bucket.isFinite else {
            return "overflow"
        }
        if abs(bucket) <= Double(Int.max) {
            return String(Int(bucket))
        }
        return String(format: "%.0f", bucket)
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
