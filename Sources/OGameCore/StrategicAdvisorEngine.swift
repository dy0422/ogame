import Foundation

public struct StrategicAdvisorRecommendation: Equatable, Identifiable, Sendable {
    public enum Kind: String, CaseIterable, Hashable, Sendable {
        case crisis
        case hostileSite
        case sectorEvent
        case actionChain
        case tradeRoute
        case deepIntel
        case artifact
        case victoryRoute
        case aiThreat
        case energyDeficit
        case storagePressure
        case idleConstruction
        case idleResearch
        case debrisRecovery
        case colonyWindow
        case expeditionWindow
        case fleetSafety
        case combatReview
    }

    public enum Priority: Int, Comparable, Sendable {
        case info = 0
        case opportunity = 1
        case warning = 2
        case critical = 3

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public var kind: Kind
    public var priority: Priority
    public var title: String
    public var detail: String
    public var actionLabel: String
    public var planetID: PlanetID?
    public var targetCoordinate: Coordinate?

    public var id: String {
        [
            kind.rawValue,
            planetID?.rawValue.uuidString ?? "global",
            targetCoordinate?.displayText ?? "no-coordinate",
            title,
            actionLabel
        ].joined(separator: "|")
    }

    public init(
        kind: Kind,
        priority: Priority,
        title: String,
        detail: String,
        actionLabel: String,
        planetID: PlanetID? = nil,
        targetCoordinate: Coordinate? = nil
    ) {
        self.kind = kind
        self.priority = priority
        self.title = title
        self.detail = detail
        self.actionLabel = actionLabel
        self.planetID = planetID
        self.targetCoordinate = targetCoordinate
    }
}

public enum StrategicAdvisorEngine {
    private enum ResourceLane: String {
        case metal = "金属"
        case crystal = "晶体"
        case deuterium = "重氢"
    }

    public static func recommendations(in universe: Universe, limit: Int = 6) -> [StrategicAdvisorRecommendation] {
        let safeLimit = min(max(limit, 0), 12)
        guard safeLimit > 0 else {
            return []
        }

        let playerPlanets = PlayerVisibilityEngine.playerOwnedPlanets(in: universe)
        guard !playerPlanets.isEmpty else {
            return []
        }

        var recommendations: [StrategicAdvisorRecommendation] = []
        let playerFaction = universe.factions.first { $0.id == universe.playerFactionID }

        recommendations.append(contentsOf: strategicRouteRecommendations(playerFaction: playerFaction, universe: universe))
        recommendations.append(contentsOf: expansionRecommendations(universe: universe))
        recommendations.append(contentsOf: economyRecommendations(for: playerPlanets, playerFaction: playerFaction, universe: universe))
        recommendations.append(contentsOf: queueRecommendations(for: playerPlanets, playerFaction: playerFaction, universe: universe))
        recommendations.append(contentsOf: fleetLoopRecommendations(for: playerPlanets, playerFaction: playerFaction, universe: universe))
        recommendations.append(contentsOf: reportRecommendations(universe: universe))

        return Array(
            recommendations
                .uniquedByID()
                .sorted { lhs, rhs in
                    if lhs.priority != rhs.priority {
                        return lhs.priority > rhs.priority
                    }
                    if priorityOrder(lhs.kind) != priorityOrder(rhs.kind) {
                        return priorityOrder(lhs.kind) < priorityOrder(rhs.kind)
                    }
                    return lhs.id < rhs.id
                }
                .prefix(safeLimit)
        )
    }

    private static func strategicRouteRecommendations(
        playerFaction: Faction?,
        universe: Universe
    ) -> [StrategicAdvisorRecommendation] {
        guard let playerFaction else {
            return []
        }

        var recommendations: [StrategicAdvisorRecommendation] = []

        if let plan = VictoryRoutePlanEngine.bestPlan(for: playerFaction.id, in: universe),
           let next = plan.nextCheckpoint {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .victoryRoute,
                    priority: plan.progress >= 0.75 ? .warning : .opportunity,
                    title: "路线建议：\(plan.title)",
                    detail: "当前进度 \(whole(plan.progress * 100))%。下一步：\(next.title) - \(next.detail)",
                    actionLabel: "查看路线"
                )
            )
        }

        if let threat = AIIntentEngine.highestPlayerThreat(in: universe) {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .aiThreat,
                    priority: threat.priority,
                    title: "AI 动向：\(threat.title)",
                    detail: threat.detail,
                    actionLabel: "查看关系"
                )
            )
        }

        return recommendations
    }

    private static func expansionRecommendations(universe: Universe) -> [StrategicAdvisorRecommendation] {
        var recommendations: [StrategicAdvisorRecommendation] = []

        if let crisis = universe.crisisState {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .crisis,
                    priority: crisis.phase == .escalating ? .critical : .warning,
                    title: "危机：\(crisis.title)",
                    detail: "\(crisis.detail) 当前进度 \(whole(crisis.progress * 100))%。",
                    actionLabel: "查看舰队"
                )
            )
        }

        if let hostile = universe.hostileSites.sorted(by: { $0.threatLevel > $1.threatLevel }).first {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .hostileSite,
                    priority: .warning,
                    title: "PVE 目标：\(hostile.name)",
                    detail: "威胁 \(hostile.threatLevel)，建议战力 \(whole(hostile.requiredPower))，奖励约 \(whole(hostile.reward.metal + hostile.reward.crystal + hostile.reward.deuterium)) 资源。",
                    actionLabel: "准备打击",
                    targetCoordinate: hostile.coordinate
                )
            )
        }

        if let event = universe.sectorEvents.sorted(by: { $0.expiresAt < $1.expiresAt }).first {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .sectorEvent,
                    priority: event.riskModifier > 0 ? .warning : .opportunity,
                    title: "星区事件：\(event.title)",
                    detail: "\(event.detail) 坐标 \(event.coordinate.displayText)，剩余 \(whole(event.expiresAt - universe.gameTime)) 秒。",
                    actionLabel: "查看星图",
                    targetCoordinate: event.coordinate
                )
            )
        }

        if let chain = universe.actionChains.sorted(by: { $0.expiresAt < $1.expiresAt }).first {
            let nextStep = chain.steps.first { $0.status != .complete }?.title ?? "领取奖励"
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .actionChain,
                    priority: .opportunity,
                    title: "行动链：\(chain.title)",
                    detail: "下一步：\(nextStep)。完成后可获得 \(whole(chain.reward.metal + chain.reward.crystal + chain.reward.deuterium)) 资源。",
                    actionLabel: "查看任务"
                )
            )
        }

        if let route = universe.tradeRoutes.first(where: { $0.ownerID == universe.playerFactionID }) {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .tradeRoute,
                    priority: route.status == .profitable ? .opportunity : .warning,
                    title: "贸易线：\(route.title)",
                    detail: "预估流量 \(whole(route.resourceFlow.metal + route.resourceFlow.crystal + route.resourceFlow.deuterium))，风险 \(whole(route.riskLevel * 100))%。",
                    actionLabel: "查看星球"
                )
            )
        }

        if let intel = universe.deepIntelOperations.first(where: { $0.ownerID == universe.playerFactionID }) {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .deepIntel,
                    priority: intel.riskLevel >= 0.4 ? .warning : .opportunity,
                    title: "深度情报：\(intel.title)",
                    detail: "\(intel.detail) 风险 \(whole(intel.riskLevel * 100))%。",
                    actionLabel: "查看关系"
                )
            )
        }

        if let artifact = universe.artifacts.sorted(by: { $0.unlockedAt > $1.unlockedAt }).first {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .artifact,
                    priority: .opportunity,
                    title: "遗物：\(artifact.title)",
                    detail: artifact.effect,
                    actionLabel: "查看胜利"
                )
            )
        }

        return recommendations
    }

    private static func economyRecommendations(
        for playerPlanets: [Planet],
        playerFaction: Faction?,
        universe: Universe
    ) -> [StrategicAdvisorRecommendation] {
        var recommendations: [StrategicAdvisorRecommendation] = []

        for planet in playerPlanets {
            let energy = EconomyEngine.energyState(
                for: planet,
                ruleSet: universe.ruleSet,
                research: playerFaction?.technology ?? ResearchState()
            )
            if energy.available < 0 {
                recommendations.append(
                    StrategicAdvisorRecommendation(
                        kind: .energyDeficit,
                        priority: .critical,
                        title: "能源赤字",
                        detail: "\(planet.name) 缺口 \(whole(abs(energy.available))) 能量，矿场产出会被压低。优先补太阳能、聚变或降低高耗能矿场占比。",
                        actionLabel: "补能源",
                        planetID: planet.id
                    )
                )
            }

            let production = EconomyEngine.productionPerHour(
                for: planet,
                ruleSet: universe.ruleSet,
                research: playerFaction?.technology ?? ResearchState()
            )
            if let pressure = storagePressure(on: planet, production: production) {
                recommendations.append(
                    StrategicAdvisorRecommendation(
                        kind: .storagePressure,
                        priority: .warning,
                        title: "仓库接近上限",
                        detail: "\(planet.name) 的\(pressure.lane.rawValue)库存已到 \(whole(pressure.ratio * 100))%，继续生产会浪费产能。",
                        actionLabel: "升级仓库",
                        planetID: planet.id
                    )
                )
            }
        }

        return recommendations
    }

    private static func reportRecommendations(universe: Universe) -> [StrategicAdvisorRecommendation] {
        guard let latestBattle = universe.reports
            .filter({
                $0.kind == .battle &&
                    $0.participants.contains { $0.factionID == universe.playerFactionID }
            })
            .sorted(by: { $0.time > $1.time })
            .first
        else {
            return []
        }

        return [
            StrategicAdvisorRecommendation(
                kind: .combatReview,
                priority: .info,
                title: "战报可复盘",
                detail: "最近战斗发生在 T+\(whole(latestBattle.time)) 秒。复盘 RF、残骸、月球概率和损失结构，可优化下一次舰队搭配。",
                actionLabel: "查看战报"
            )
        ]
    }

    private static func queueRecommendations(
        for playerPlanets: [Planet],
        playerFaction: Faction?,
        universe: Universe
    ) -> [StrategicAdvisorRecommendation] {
        var recommendations: [StrategicAdvisorRecommendation] = []

        if let planet = playerPlanets.first(where: { $0.buildQueue.isEmpty }),
           let building = affordableBuildingCandidate(on: planet, playerFaction: playerFaction, universe: universe)
        {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .idleConstruction,
                    priority: .opportunity,
                    title: "建筑队列空闲",
                    detail: "\(planet.name) 可立即升级\(building.localizedName)，保持经济建筑连续开工。",
                    actionLabel: "升级建筑",
                    planetID: planet.id
                )
            )
        }

        if let playerFaction,
           playerFaction.researchQueue.isEmpty,
           let technology = affordableResearchCandidate(for: playerFaction, universe: universe)
        {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .idleResearch,
                    priority: .opportunity,
                    title: "科研队列空闲",
                    detail: "\(technology.localizedName)可继续研究，优先补舰队槽、殖民上限或战斗科技。",
                    actionLabel: "开始研究"
                )
            )
        }

        return recommendations
    }

    private static func fleetLoopRecommendations(
        for playerPlanets: [Planet],
        playerFaction: Faction?,
        universe: Universe
    ) -> [StrategicAdvisorRecommendation] {
        var recommendations: [StrategicAdvisorRecommendation] = []
        let activePlayerFleets = universe.fleets.filter { $0.ownerID == universe.playerFactionID && $0.phase != .completed }
        let dockedShips = summedShips(on: playerPlanets)
        let knownPlanets = knownPlanetsForPlayer(in: universe)

        if hasShip(.recycler, in: dockedShips),
           let debrisTarget = knownPlanets
            .filter({ !isPlayerPlanet($0, in: universe) && resourceTotal($0.debrisField) > 0 })
            .sorted(by: { resourceTotal($0.debrisField) > resourceTotal($1.debrisField) })
            .first,
           !activePlayerFleets.contains(where: { $0.mission == .recycle && $0.targetPlanetID == debrisTarget.id })
        {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .debrisRecovery,
                    priority: .opportunity,
                    title: "残骸待回收",
                    detail: "\(debrisTarget.coordinate.displayText) 有 \(whole(resourceTotal(debrisTarget.debrisField))) 资源残骸，回收船可直接转化为建设收益。",
                    actionLabel: "派回收船",
                    planetID: debrisTarget.id,
                    targetCoordinate: debrisTarget.coordinate
                )
            )
        }

        if canColonizeMore(playerFaction: playerFaction),
           hasShip(.colonyShip, in: dockedShips)
        {
            let exploredNeutral = knownPlanets.first {
                $0.ownerID == nil && UniverseTopologyEngine.isValidPlanetCoordinate($0.coordinate)
            }
            let colonyCoordinate = exploredNeutral?.coordinate ?? bestOpenColonyCoordinate(from: playerPlanets, in: universe)

            if let colonyCoordinate {
                recommendations.append(
                    StrategicAdvisorRecommendation(
                        kind: .colonyWindow,
                        priority: .opportunity,
                        title: "殖民窗口",
                        detail: "\(colonyCoordinate.displayText) 可殖民。星位会影响方圆、太阳能和重氢长期收益。",
                        actionLabel: "派殖民船",
                        planetID: exploredNeutral?.id,
                        targetCoordinate: colonyCoordinate
                    )
                )
            }
        }

        if hasExpeditionFleet(in: dockedShips),
           activePlayerFleets.filter({ $0.mission == .explore }).count < maxExpeditionPressure(for: playerFaction)
        {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .expeditionWindow,
                    priority: .info,
                    title: "远征窗口",
                    detail: "货船或探测器空闲。远征可带回资源、舰船、暗物质，也可能遭遇海盗或黑洞。",
                    actionLabel: "派探索"
                )
            )
        }

        let parkedCombatShips = dockedShips.reduce(0) { total, element in
            total + (isCombatShip(element.key) ? max(element.value, 0) : 0)
        }
        let pressure = playerFaction?.relations.map(\.threatScore).max() ?? 0
        if parkedCombatShips >= 6, activePlayerFleets.isEmpty, pressure > 0 {
            recommendations.append(
                StrategicAdvisorRecommendation(
                    kind: .fleetSafety,
                    priority: .warning,
                    title: "舰队停泊风险",
                    detail: "已有敌对压力且 \(parkedCombatShips) 艘战斗舰停泊。可用驻防、运输或远征模拟 FS 节奏。",
                    actionLabel: "安排舰队"
                )
            )
        }

        return recommendations
    }

    private static func storagePressure(on planet: Planet, production: ResourceBundle) -> (lane: ResourceLane, ratio: Double)? {
        let lanes: [(ResourceLane, Double, Double, Double)] = [
            (.metal, planet.resources.metal, planet.storage.metal, production.metal),
            (.crystal, planet.resources.crystal, planet.storage.crystal, production.crystal),
            (.deuterium, planet.resources.deuterium, planet.storage.deuterium, production.deuterium)
        ]

        return lanes
            .compactMap { lane, amount, storage, rate -> (lane: ResourceLane, ratio: Double)? in
                guard storage.isFinite, storage > 0, rate > 0 else {
                    return nil
                }
                let ratio = max(amount, 0) / storage
                return ratio >= 0.85 ? (lane, ratio) : nil
            }
            .max { lhs, rhs in lhs.ratio < rhs.ratio }
    }

    private static func affordableBuildingCandidate(
        on planet: Planet,
        playerFaction: Faction?,
        universe: Universe
    ) -> BuildingKind? {
        let energy = EconomyEngine.energyState(
            for: planet,
            ruleSet: universe.ruleSet,
            research: playerFaction?.technology ?? ResearchState()
        )
        let baseOrder: [BuildingKind] = [.metalMine, .crystalMine, .deuteriumSynthesizer, .solarPlant, .roboticsFactory, .shipyard, .researchLab]
        let order = energy.available < 0
            ? [.solarPlant, .fusionReactor] + baseOrder
            : baseOrder

        return order.first { kind in
            guard let cost = QueueEngine.buildingUpgradeCost(on: planet.id, in: universe, kind: kind) else {
                return false
            }
            return planet.resources.canAfford(cost)
        }
    }

    private static func affordableResearchCandidate(for faction: Faction, universe: Universe) -> TechnologyKind? {
        let order: [TechnologyKind] = [.computer, .astrophysics, .espionage, .energy, .combustionDrive, .impulseDrive, .weapons, .shielding, .armor, .hyperspaceDrive]
        let paymentPlanet = paymentPlanet(for: faction, in: universe)

        return order.first { technology in
            guard let paymentPlanet,
                  let cost = QueueEngine.researchCost(for: faction.id, in: universe, technology: technology)
            else {
                return false
            }
            return paymentPlanet.resources.canAfford(cost)
        }
    }

    private static func paymentPlanet(for faction: Faction, in universe: Universe) -> Planet? {
        for planetID in faction.ownedPlanetIDs {
            if let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == faction.id }) {
                return planet
            }
        }
        return universe.planets.first { $0.ownerID == faction.id }
    }

    private static func knownPlanetsForPlayer(in universe: Universe) -> [Planet] {
        let exploredIDs = Set(
            universe.explorationRecords
                .filter { $0.factionID == universe.playerFactionID }
                .map(\.targetPlanetID)
        )
        return universe.planets.filter { planet in
            planet.ownerID == universe.playerFactionID ||
                exploredIDs.contains(planet.id) ||
                resourceTotal(planet.debrisField) > 0
        }
    }

    private static func bestOpenColonyCoordinate(from playerPlanets: [Planet], in universe: Universe) -> Coordinate? {
        guard let origin = playerPlanets.first?.coordinate else {
            return nil
        }

        let occupied = Set(universe.planets.map(\.coordinate))
        return UniverseTopologyEngine
            .regionalColonyCoordinates(around: origin, occupied: occupied, limit: 1)
            .first
    }

    private static func isPlayerPlanet(_ planet: Planet, in universe: Universe) -> Bool {
        planet.ownerID == universe.playerFactionID
    }

    private static func canColonizeMore(playerFaction: Faction?) -> Bool {
        guard let playerFaction else {
            return false
        }
        return playerFaction.ownedPlanetIDs.count < TechnologyEffects.maxColonies(for: playerFaction.technology)
    }

    private static func summedShips(on planets: [Planet]) -> [ShipKind: Int] {
        planets.reduce(into: [:]) { result, planet in
            for (kind, quantity) in planet.shipInventory where quantity > 0 {
                result[kind, default: 0] += quantity
            }
        }
    }

    private static func hasShip(_ kind: ShipKind, in ships: [ShipKind: Int]) -> Bool {
        (ships[kind] ?? 0) > 0
    }

    private static func hasExpeditionFleet(in ships: [ShipKind: Int]) -> Bool {
        hasShip(.smallCargo, in: ships) ||
            hasShip(.largeCargo, in: ships) ||
            hasShip(.espionageProbe, in: ships)
    }

    private static func maxExpeditionPressure(for faction: Faction?) -> Int {
        guard let faction else {
            return 1
        }
        return max(1, min(3, TechnologyEffects.maxFleetSlots(for: faction.technology) / 2))
    }

    private static func isCombatShip(_ kind: ShipKind) -> Bool {
        switch kind {
        case .lightFighter, .heavyFighter, .cruiser, .battleship, .battlecruiser, .bomber, .destroyer, .deathstar:
            return true
        case .smallCargo, .largeCargo, .colonyShip, .recycler, .espionageProbe, .solarSatellite:
            return false
        }
    }

    private static func resourceTotal(_ resources: ResourceBundle) -> Double {
        [resources.metal, resources.crystal, resources.deuterium]
            .filter { $0.isFinite && $0 > 0 }
            .reduce(0, +)
    }

    private static func whole(_ value: Double) -> String {
        guard value.isFinite, abs(value) <= Double(Int.max) else {
            return "未知"
        }
        return String(Int(value.rounded()))
    }

    private static func priorityOrder(_ kind: StrategicAdvisorRecommendation.Kind) -> Int {
        StrategicAdvisorRecommendation.Kind.allCases.firstIndex(of: kind) ?? Int.max
    }
}

private extension Array where Element == StrategicAdvisorRecommendation {
    func uniquedByID() -> [StrategicAdvisorRecommendation] {
        var seen = Set<String>()
        var result: [StrategicAdvisorRecommendation] = []
        for recommendation in self where !seen.contains(recommendation.id) {
            seen.insert(recommendation.id)
            result.append(recommendation)
        }
        return result
    }
}
