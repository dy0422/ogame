import Combine
import Foundation
import OGameCore
import OGamePersistence
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var universe: Universe
    @Published var statusMessage: String
    @Published private(set) var canSave: Bool
    @Published private(set) var offlineSummary: OfflineCatchUpSummary? = nil
    @Published private(set) var hasPendingOfflineCatchUpSave = false
    @Published private(set) var isSimulationPaused = false
    @Published private(set) var lastRealtimeTickDate: Date? = nil
    @Published private(set) var lastPeriodicAutosaveDate: Date? = nil
    @Published var settings: GameSettings
    @Published private(set) var saveSlots: [JSONSaveRepository.SaveSlot] = []
    @Published private(set) var isOnboardingVisible: Bool
    @Published var selectedDestination: SidebarDestination? = .dashboard

    private let repository: JSONSaveRepository
    private let currentDate: () -> Date
    private let periodicAutosaveInterval: TimeInterval = 45

    init(
        repository: JSONSaveRepository? = nil,
        currentDate: @escaping () -> Date = Date.init
    ) {
        let resolvedRepository: JSONSaveRepository
        if let repository {
            resolvedRepository = repository
        } else {
            resolvedRepository = (try? JSONSaveRepository.defaultRepository())
                ?? JSONSaveRepository(
                    saveDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(
                        "NativeOGame",
                        isDirectory: true
                    )
                )
        }

        self.repository = resolvedRepository
        self.currentDate = currentDate

        do {
            let envelope = try resolvedRepository.load()
            let loadedAt = currentDate()
            let catchUpResult = envelope.offlineCatchUp(until: loadedAt)
            universe = Self.refreshedStrategicUniverse(catchUpResult.universe)
            settings = envelope.settings
            offlineSummary = catchUpResult.summary.didMutate ? catchUpResult.summary : nil
            hasPendingOfflineCatchUpSave = catchUpResult.summary.didMutate
            isOnboardingVisible = false
            canSave = true

            if catchUpResult.summary.didMutate {
                statusMessage = Self.offlineCatchUpPendingStatus(for: catchUpResult.summary)
            } else {
                statusMessage = "已载入存档：\(envelope.lastSavedAt.formatted(date: .abbreviated, time: .shortened))。"
            }
        } catch JSONSaveRepository.RepositoryError.missingSave {
            universe = Self.refreshedStrategicUniverse(
                StarterUniverseFactory.makeNewGame(seed: 1, playerName: "指挥官")
            )
            settings = GameSettings()
            offlineSummary = nil
            hasPendingOfflineCatchUpSave = false
            isOnboardingVisible = true
            statusMessage = "新的快速遭遇战已初始化。"
            canSave = true
        } catch {
            universe = Self.refreshedStrategicUniverse(
                StarterUniverseFactory.makeNewGame(seed: 1, playerName: "指挥官")
            )
            settings = GameSettings()
            offlineSummary = nil
            hasPendingOfflineCatchUpSave = false
            isOnboardingVisible = true
            statusMessage = Self.loadFailureStatus(for: error)
            canSave = false
        }

        refreshSaveSlots()
    }

    var playerFaction: Faction? {
        universe.factions.first { faction in
            faction.id == universe.playerFactionID
        }
    }

    var playerPlanets: [Planet] {
        PlayerVisibilityEngine.playerOwnedPlanets(in: universe)
    }

    var playerObjectiveStates: [PlayerObjectiveState] {
        PlayerObjectiveEngine.states(in: universe)
    }

    var strategicAdvisorRecommendations: [StrategicAdvisorRecommendation] {
        StrategicAdvisorEngine.recommendations(in: universe)
    }

    var availableBuildingKinds: [BuildingKind] {
        BuildingKind.allCases.filter { kind in
            universe.ruleSet.buildingRules[kind] != nil && !kind.isMoonFacility
        }
    }

    var availableMoonFacilityKinds: [BuildingKind] {
        BuildingKind.allCases.filter { kind in
            universe.ruleSet.buildingRules[kind] != nil && kind.isMoonFacility
        }
    }

    var availableResearchKinds: [TechnologyKind] {
        TechnologyKind.allCases.filter { technology in
            universe.ruleSet.researchRules[technology] != nil
        }
    }

    var availableShipKinds: [ShipKind] {
        ShipKind.allCases.filter { kind in
            universe.ruleSet.shipRules[kind] != nil
        }
    }

    var availableDefenseKinds: [DefenseKind] {
        DefenseKind.allCases.filter { kind in
            universe.ruleSet.defenseRules[kind] != nil
        }
    }

    var availableMissileKinds: [MissileKind] {
        MissileKind.allCases.filter { kind in
            universe.ruleSet.missileRules[kind] != nil
        }
    }

    var fleetMissionKinds: [Fleet.Mission] {
        [.transport, .defend, .attack, .espionage, .recycle, .colonize, .explore]
    }

    var activeFleets: [Fleet] {
        universe.fleets.sorted { lhs, rhs in
            fleetNextTime(lhs) < fleetNextTime(rhs)
        }
    }

    var commanderSummaries: [CommanderSummary] {
        let activeAssignments = activeCommanderAssignments()
        return universe.commanderRoster.ownedCommanders.compactMap { commander in
            guard let definition = CommanderCatalog.definition(id: commander.definitionID) else {
                return nil
            }

            let levelCap = CommanderGrowthEngine.levelCap(for: commander.rarity)
            let shards = universe.commanderRoster.shardsByDefinitionID[commander.definitionID] ?? 0
            let nextStarCost = CommanderGrowthEngine.shardCostForNextStar(currentStars: commander.stars)
            let activeFleet = activeAssignments[commander.id]
            return CommanderSummary(
                id: commander.id,
                definitionID: commander.definitionID,
                name: definition.name,
                title: definition.title,
                rarity: commander.rarity,
                rarityText: Self.commanderRarityText(commander.rarity),
                specialtyText: Self.commanderSpecialtyText(definition.specialty),
                level: commander.level,
                levelCap: levelCap,
                experienceProgress: min(max(commander.experience / 100, 0), 1),
                experienceText: "\(Self.formattedWholeNumber(commander.experience)) / 100",
                stars: commander.stars,
                shards: shards,
                nextStarCost: nextStarCost,
                canTrain: universe.commanderRoster.trainingData > 0 && commander.level < levelCap,
                canPromote: nextStarCost.map { shards >= $0 } ?? false,
                bonusText: CommanderBonusEngine.summaryText(for: commander, in: universe),
                lore: definition.lore,
                isAssigned: activeFleet != nil,
                assignmentText: activeFleet.map { "执行\($0.mission.localizedName)至 \($0.target.displayText)" } ?? "空闲"
            )
        }
    }

    var availableCommandersForFleet: [CommanderSummary] {
        let activeIDs = Set(activeCommanderAssignments().keys)
        return commanderSummaries.filter { !activeIDs.contains($0.id) }
    }

    var commanderRecruitmentPreview: CommanderRecruitmentPreview {
        let state = universe.commanderRoster.recruitmentState
        return CommanderRecruitmentPreview(
            tickets: universe.commanderRoster.recruitmentTickets,
            trainingData: universe.commanderRoster.trainingData,
            ownedCount: universe.commanderRoster.ownedCommanders.count,
            totalPulls: state.totalPulls,
            legendaryPityText: "\(max(0, 40 - state.pullsSinceLegendary)) 抽内必出传奇",
            eliteGuaranteeText: "十连至少精英级"
        )
    }

    var starMapSections: [StarMapPlanetSection] {
        let factionNamesByID = Dictionary(uniqueKeysWithValues: universe.factions.map { ($0.id, $0.name.displayName) })
        let factionKindsByID = Dictionary(uniqueKeysWithValues: universe.factions.map { ($0.id, $0.kind) })
        let playerOwnedPlanetIDs = PlayerVisibilityEngine.playerOwnedPlanetIDs(in: universe)
        let exploredPlanetIDs = playerExploredPlanetIDs

        let summaries = universe.planets
            .sorted(by: Self.sortPlanetsByCoordinate)
            .map { planet in
                let isPlayerOwned = playerOwnedPlanetIDs.contains(planet.id)
                let isExploredByPlayer = exploredPlanetIDs.contains(planet.id)
                let isVisible = isPlayerOwned || isExploredByPlayer
                let touchingFleets = isVisible ? universe.fleets.filter { fleet in
                    fleet.phase != .completed && Self.fleet(fleet, touches: planet.id)
                } : []
                let friendlyFleetCount = touchingFleets.filter { $0.ownerID == universe.playerFactionID }.count
                let otherFleetCount = touchingFleets.count - friendlyFleetCount
                let ownerName = isPlayerOwned
                    ? (playerFaction?.name.displayName ?? "玩家")
                    : isVisible ? planet.ownerID.flatMap { factionNamesByID[$0] } ?? "中立" : "未知"
                let ownerKind = isPlayerOwned
                    ? Faction.Kind.player
                    : isVisible ? planet.ownerID.flatMap { factionKindsByID[$0] } : nil

                return StarMapPlanetSummary(
                    planet: planet,
                    displayName: isVisible ? planet.name.displayName : "未知区域",
                    ownerName: ownerName,
                    ownerKind: ownerKind,
                    isPlayerOwned: isPlayerOwned,
                    isExploredByPlayer: isExploredByPlayer,
                    isVisible: isVisible,
                    hasMoon: isVisible && planet.moon != nil,
                    debrisTotal: isVisible ? planet.debrisField.totalAmountForDisplay : 0,
                    friendlyFleetCount: friendlyFleetCount,
                    otherFleetCount: otherFleetCount
                )
            }

        return StarMapPlanetSection.Kind.allCases.map { kind in
            StarMapPlanetSection(
                kind: kind,
                planets: summaries.filter { summary in
                    switch kind {
                    case .player:
                        return summary.isPlayerOwned
                    case .ai:
                        return summary.isVisible && summary.ownerKind == .ai
                    case .neutral:
                        return summary.isVisible && summary.ownerKind == nil
                    case .unknown:
                        return !summary.isVisible
                    }
                }
            )
        }
    }

    func solarSystemSlots(galaxy: Int, system: Int) -> [SolarSystemSlotSummary] {
        let normalizedGalaxy = min(max(galaxy, 1), UniverseTopologyEngine.defaultGalaxyCount)
        let normalizedSystem = min(max(system, 1), UniverseTopologyEngine.defaultSystemsPerGalaxy)
        let planetsByPosition = universe.planets
            .filter { $0.coordinate.galaxy == normalizedGalaxy && $0.coordinate.system == normalizedSystem }
            .reduce(into: [Int: Planet]()) { result, planet in
                result[planet.coordinate.position] = planet
            }

        return (1...UniverseTopologyEngine.expeditionPosition).map { position in
            let coordinate = Coordinate(galaxy: normalizedGalaxy, system: normalizedSystem, position: position)
            if position == UniverseTopologyEngine.expeditionPosition {
                return SolarSystemSlotSummary(
                    position: position,
                    coordinate: coordinate,
                    planetID: nil,
                    displayName: "外太空",
                    ownerName: "远征",
                    ownerKind: nil,
                    isPlayerOwned: false,
                    isVisible: true,
                    isExpedition: true,
                    hasMoon: false,
                    debrisTotal: 0
                )
            }

            guard let planet = planetsByPosition[position] else {
                return SolarSystemSlotSummary(
                    position: position,
                    coordinate: coordinate,
                    planetID: nil,
                    displayName: "空位",
                    ownerName: "可殖民",
                    ownerKind: nil,
                    isPlayerOwned: false,
                    isVisible: true,
                    isExpedition: false,
                    hasMoon: false,
                    debrisTotal: 0
                )
            }

            let isPlayerOwned = isPlayerOwned(planet)
            let isVisible = isVisibleToPlayer(planet)
            let ownerKind = isPlayerOwned
                ? Faction.Kind.player
                : isVisible ? planet.ownerID.flatMap { faction(with: $0)?.kind } : nil
            let ownerName = isPlayerOwned
                ? (playerFaction?.name.displayName ?? "玩家")
                : isVisible ? planet.ownerID.map(factionName(for:)) ?? "中立" : "未知"

            return SolarSystemSlotSummary(
                position: position,
                coordinate: coordinate,
                planetID: planet.id,
                displayName: isVisible ? planet.name.displayName : "未知区域",
                ownerName: ownerName,
                ownerKind: ownerKind,
                isPlayerOwned: isPlayerOwned,
                isVisible: isVisible,
                isExpedition: false,
                hasMoon: isVisible && planet.moon != nil,
                debrisTotal: isVisible ? planet.debrisField.totalAmountForDisplay : 0
            )
        }
    }

    func colonySpecialization(for planet: Planet) -> ColonySpecialization {
        ColonySpecializationEngine.specialization(for: planet)
    }

    func colonySpecializationPreview(for slot: SolarSystemSlotSummary) -> ColonySpecialization? {
        guard !slot.isExpedition else {
            return nil
        }

        if let planet = planet(for: slot.planetID), slot.isVisible {
            return ColonySpecializationEngine.specialization(for: planet)
        }

        guard slot.planetID == nil else {
            return nil
        }

        return ColonySpecializationEngine.preview(for: slot.coordinate, universeSeed: universe.seed)
    }

    var factionRankings: [FactionScore] {
        let rankings = universe.rankings.isEmpty ? StrategicEngine.rankings(in: universe) : universe.rankings
        return rankings.sorted { lhs, rhs in
            if lhs.rank != rhs.rank {
                return lhs.rank < rhs.rank
            }

            return lhs.totalScore > rhs.totalScore
        }
    }

    var victoryBannerSummary: VictoryBannerSummary {
        if let winningFactionID = universe.victoryState.winningFactionID {
            let factionName = factionName(for: winningFactionID)
            let routeName = universe.victoryState.winningRoute?.localizedName ?? "战略"
            let achievedText = universe.victoryState.achievedAt.map { "，达成时间 T+\(Self.formattedWholeSeconds($0))" } ?? ""
            return VictoryBannerSummary(
                title: "\(factionName) 已取得胜利",
                detail: "\(routeName)路线已完成\(achievedText)。",
                isComplete: true
            )
        }

        if let leadingProgress = victoryProgressSummaries
            .filter(\.isPlayer)
            .max(by: { lhs, rhs in lhs.progress < rhs.progress })
        {
            return VictoryBannerSummary(
                title: "胜利路线进行中",
                detail: "\(leadingProgress.route.localizedName)路线领先，进度 \(Self.formattedPercent(leadingProgress.progress))。",
                isComplete: false
            )
        }

        return VictoryBannerSummary(
            title: "胜利路线进行中",
            detail: "各势力发展后会显示战略进度。",
            isComplete: false
        )
    }

    var victoryProgressSummaries: [VictoryProgressSummary] {
        universe.victoryState.progress.map { progress in
            VictoryProgressSummary(
                factionID: progress.factionID,
                factionName: factionName(for: progress.factionID),
                isPlayer: progress.factionID == universe.playerFactionID,
                route: progress.route,
                currentValue: progress.currentValue,
                targetValue: progress.targetValue,
                progress: progress.progress
            )
        }
        .sorted { lhs, rhs in
            if lhs.isPlayer != rhs.isPlayer {
                return lhs.isPlayer
            }
            if lhs.progress != rhs.progress {
                return lhs.progress > rhs.progress
            }
            if lhs.factionName != rhs.factionName {
                return lhs.factionName < rhs.factionName
            }
            return lhs.route.rawValue < rhs.route.rawValue
        }
    }

    var relationSummaries: [FactionRelationSummary] {
        let playerRelationByFactionID = Dictionary(
            uniqueKeysWithValues: (playerFaction?.relations ?? []).map { ($0.factionID, $0) }
        )

        return universe.factions
            .filter { $0.id != universe.playerFactionID }
            .map { faction in
                let directRelation = playerRelationByFactionID[faction.id]
                let relation = directRelation ?? FactionRelation(factionID: faction.id)
                let perspective = directRelation == nil ? "未接触" : "我方记录"
                let summary = directRelation?.summary ?? "未记录我方接触。"

                return FactionRelationSummary(
                    factionID: faction.id,
                    factionName: faction.name.displayName,
                    kind: faction.kind,
                    strategy: faction.strategy,
                    posture: relation.posture,
                    threatScore: relation.threatScore,
                    attackCount: relation.attackCount,
                    lastInteractionTime: relation.lastInteractionTime,
                    summary: summary,
                    perspective: perspective
                )
            }
            .sorted { lhs, rhs in
                if lhs.posture.severity != rhs.posture.severity {
                    return lhs.posture.severity > rhs.posture.severity
                }
                if lhs.threatScore != rhs.threatScore {
                    return lhs.threatScore > rhs.threatScore
                }
                return lhs.factionName < rhs.factionName
            }
    }

    var playerExplorationSummaries: [ExplorationSummary] {
        StrategicEngine
            .explorationRecords(for: universe.playerFactionID, in: universe)
            .sorted { lhs, rhs in
                if lhs.exploredAt != rhs.exploredAt {
                    return lhs.exploredAt > rhs.exploredAt
                }

                return lhs.targetPlanetID.rawValue.uuidString < rhs.targetPlanetID.rawValue.uuidString
            }
            .compactMap { record in
                guard let planet = universe.planets.first(where: { $0.id == record.targetPlanetID }) else {
                    return nil
                }

                let ownerName = record.discoveredOwnerID.map(factionName(for:)) ??
                    (record.discoveredNeutral ? "中立" : "未知")

                return ExplorationSummary(
                    planet: planet,
                    exploredAt: record.exploredAt,
                    ownerName: ownerName,
                    reward: record.reward,
                    discoveredResources: record.discoveredResources,
                    discoveredDebris: record.discoveredDebris,
                    discoveredNeutral: record.discoveredNeutral
                )
            }
    }

    var recentReports: [Report] {
        universe.reports
            .filter { report in
                report.kind == .battle ||
                    report.kind == .espionage ||
                    report.kind == .exploration ||
                    report.kind == .missile
            }
            .sorted { lhs, rhs in
                lhs.time > rhs.time
            }
            .prefix(8)
            .map { $0 }
    }

    var saveDirectoryURL: URL {
        repository.saveDirectory
    }

    var victorySettlementSummary: VictorySettlementSummary? {
        guard let winningFactionID = universe.victoryState.winningFactionID else {
            return nil
        }

        let factionName = factionName(for: winningFactionID)
        let routeName = universe.victoryState.winningRoute?.localizedName ?? "战略"
        let achievedText = universe.victoryState.achievedAt.map { "T+\(Self.formattedWholeSeconds($0))" } ?? "未知时间"

        return VictorySettlementSummary(
            title: "\(factionName) 完成\(routeName)胜利",
            detail: winningFactionID == universe.playerFactionID
                ? "本局目标已经达成。可以继续沙盒推进，也可以立即重新开局挑战更快节奏。"
                : "对手已经完成胜利路线。本局仍可继续作为沙盒宇宙运行，或重新开局调整策略。",
            routeText: "\(routeName)路线",
            timeText: achievedText,
            isPlayerVictory: winningFactionID == universe.playerFactionID
        )
    }

    var commanderBriefingItems: [CommanderBriefingItem] {
        var items: [CommanderBriefingItem] = []

        if let settlement = victorySettlementSummary {
            items.append(
                CommanderBriefingItem(
                    title: settlement.isPlayerVictory ? "胜利结算" : "战局结算",
                    detail: "\(settlement.routeText)已完成，达成时间 \(settlement.timeText)。",
                    systemImage: "flag.checkered",
                    urgency: settlement.isPlayerVictory ? .good : .warning
                )
            )
        }

        if let home = playerPlanets.first {
            items.append(resourceFocusBriefing(for: home))
            items.append(buildingBriefing(for: home))
        }

        if let research = researchBriefing() {
            items.append(research)
        }

        items.append(fleetBriefing())

        if let route = victoryProgressSummaries
            .filter(\.isPlayer)
            .max(by: { lhs, rhs in lhs.progress < rhs.progress })
        {
            items.append(
                CommanderBriefingItem(
                    title: "胜利路线",
                    detail: "\(route.route.localizedName)路线当前 \(Self.formattedPercent(route.progress))，目标 \(Self.formattedWholeNumber(route.targetValue))。",
                    systemImage: Self.victoryRouteSystemImage(route.route),
                    urgency: route.progress >= 0.75 ? .good : .info
                )
            )
        }

        let unknownCount = starMapSections.first { $0.kind == .unknown }?.planets.count ?? 0
        if unknownCount > 0 {
            items.append(
                CommanderBriefingItem(
                    title: "星图探索",
                    detail: "仍有 \(unknownCount) 个未知区域。派遣探索舰队可打开殖民和残骸机会。",
                    systemImage: "sparkles",
                    urgency: .info
                )
            )
        }

        return Array(items.prefix(5))
    }

    var recentExplorationEvents: [GameEvent] {
        universe.events
            .filter { $0.kind == .exploration }
            .sorted { lhs, rhs in
                lhs.time > rhs.time
            }
            .prefix(5)
            .map { $0 }
    }

    var offlineSummaryText: String? {
        guard let offlineSummary else {
            return nil
        }

        return Self.offlineSummaryDetail(
            for: offlineSummary,
            hasPendingSave: hasPendingOfflineCatchUpSave
        )
    }

    var settingsStatusText: String {
        "实时 \(formattedGameSpeed) - 离线 \(settings.offlineIntensity.displayName) - \(settings.difficulty.displayName)"
    }

    var autosaveStatusText: String {
        settings.isAutosaveEnabled ? "自动保存开启" : "自动保存关闭"
    }

    var runtimeStatusText: String {
        guard canSave else {
            return "模拟受保护"
        }

        if isSimulationPaused {
            return "已暂停"
        }

        if hasPendingOfflineCatchUpSave {
            return "运行中 - 离线进度待保存"
        }

        return "运行中"
    }

    var simulationControlTitle: String {
        isSimulationPaused ? "继续模拟" : "暂停模拟"
    }

    var simulationControlSystemImage: String {
        isSimulationPaused ? "play.fill" : "pause.fill"
    }

    var formattedGameSpeed: String {
        "\(settings.gameSpeed.formatted(.number.precision(.fractionLength(2))))x"
    }

    var nextSimulationEventText: String {
        guard let event = nextSimulationEvent else {
            return "暂无队列或舰队"
        }

        let remaining = max(0, event.time - universe.gameTime)
        return "\(event.title) - \(Self.formattedDuration(remaining))"
    }

    func startBuildingUpgrade(planetID: PlanetID, kind: BuildingKind) {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再加入建造队列。"
            return
        }

        let result = QueueEngine.startBuildingUpgrade(on: planetID, in: &universe, kind: kind)
        guard result == .queued else {
            statusMessage = Self.buildingQueueFailureStatus(result, kind: kind)
            return
        }

        let planet = universe.planets.first { $0.id == planetID }
        let targetLevel = planet?.buildQueue.last { $0.buildingKind == kind }?.targetLevel
        let status = Self.buildingQueuedStatus(
            planetName: planet?.name,
            kind: kind,
            targetLevel: targetLevel
        )
        autosaveAfterQueueing(successStatus: status)
    }

    func startResearch(_ technology: TechnologyKind) {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再加入研究队列。"
            return
        }

        let result = QueueEngine.startResearch(for: universe.playerFactionID, in: &universe, technology: technology)
        guard result == .queued else {
            statusMessage = Self.researchQueueFailureStatus(result, technology: technology)
            return
        }

        let targetLevel = playerFaction?.researchQueue.last { $0.technologyKind == technology }?.targetLevel
        let status = Self.researchQueuedStatus(technology: technology, targetLevel: targetLevel)
        autosaveAfterQueueing(successStatus: status)
    }

    func startShipBuild(planetID: PlanetID, kind: ShipKind, quantity: Int) {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再建造舰船。"
            return
        }

        guard quantity > 0 else {
            statusMessage = "无法加入\(kind.localizedName)：数量必须为正数。"
            return
        }

        let result = QueueEngine.startShipBuild(on: planetID, in: &universe, kind: kind, quantity: quantity)
        guard result == .queued else {
            statusMessage = Self.shipQueueFailureStatus(result, kind: kind)
            return
        }

        let planet = universe.planets.first { $0.id == planetID }
        let status = "已在\(planet?.name.displayName ?? "殖民地")加入 \(quantity) 架\(kind.localizedName)。"
        autosaveAfterQueueing(successStatus: status)
    }

    func startDefenseBuild(planetID: PlanetID, kind: DefenseKind, quantity: Int) {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再建造防御。"
            return
        }

        guard quantity > 0 else {
            statusMessage = "无法加入\(kind.localizedName)：数量必须为正数。"
            return
        }

        let result = QueueEngine.startDefenseBuild(on: planetID, in: &universe, kind: kind, quantity: quantity)
        guard result == .queued else {
            statusMessage = Self.defenseQueueFailureStatus(result, kind: kind)
            return
        }

        let planet = universe.planets.first { $0.id == planetID }
        let status = "已在\(planet?.name.displayName ?? "殖民地")加入 \(quantity) 个\(kind.localizedName)。"
        autosaveAfterQueueing(successStatus: status)
    }

    func startMissileBuild(planetID: PlanetID, kind: MissileKind, quantity: Int) {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再建造导弹。"
            return
        }

        guard quantity > 0 else {
            statusMessage = "无法加入\(kind.localizedName)：数量必须为正数。"
            return
        }

        let result = QueueEngine.startMissileBuild(on: planetID, in: &universe, kind: kind, quantity: quantity)
        guard result == .queued else {
            statusMessage = Self.missileQueueFailureStatus(result, kind: kind)
            return
        }

        let planet = universe.planets.first { $0.id == planetID }
        let status = "已在\(planet?.name.displayName ?? "殖民地")加入 \(quantity) 枚\(kind.localizedName)。"
        autosaveAfterQueueing(successStatus: status)
    }

    func startMoonFacilityUpgrade(planetID: PlanetID, kind: BuildingKind) {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再升级月球设施。"
            return
        }

        let result = MoonEngine.startFacilityUpgrade(on: planetID, in: &universe, kind: kind)
        guard result == .queued else {
            statusMessage = "无法升级\(kind.localizedName)：\(Self.queueFailureDescription(result))。"
            return
        }

        autosaveAfterQueueing(successStatus: "已加入\(kind.localizedName)月球设施升级。")
    }

    func moonSensorScanSummaries(from moonPlanetID: PlanetID) -> [MoonScanSummary] {
        guard let origin = planet(for: moonPlanetID),
              isPlayerOwned(origin),
              origin.moon?.buildingLevels[.sensorPhalanx, default: 0] ?? 0 > 0
        else {
            return []
        }

        var seenFleetIDs = Set<FleetID>()
        var summaries: [MoonScanSummary] = []
        for target in universe.planets.sorted(by: Self.sortPlanetsByCoordinate) where target.id != moonPlanetID {
            let scannedTraces = MoonEngine.sensorTrace(
                from: moonPlanetID,
                targetPlanetID: target.id,
                ownerID: universe.playerFactionID,
                in: universe
            )

            for trace in scannedTraces where !seenFleetIDs.contains(trace.fleet.id) {
                let fleet = trace.fleet
                seenFleetIDs.insert(fleet.id)
                summaries.append(
                    MoonScanSummary(
                        fleetID: fleet.id,
                        targetName: isVisibleToPlayer(target) ? target.name.displayName : target.coordinate.displayText,
                        missionText: fleet.mission.localizedName,
                        phaseText: fleet.phase.localizedName,
                        routeText: "\(fleet.origin.displayText) -> \(fleet.target.displayText)",
                        remainingText: fleetRemainingText(fleet),
                        interceptText: trace.interceptTime.map { "追秒 T+\(Self.formattedWholeNumber($0))" } ?? "无追秒窗口",
                        tacticalText: trace.tacticalNote
                    )
                )
            }
        }

        return summaries.sorted { lhs, rhs in
            lhs.fleetID.rawValue.uuidString < rhs.fleetID.rawValue.uuidString
        }
    }

    func moonJumpTargets(from originPlanetID: PlanetID) -> [MoonJumpTargetSummary] {
        guard let origin = planet(for: originPlanetID),
              isPlayerOwned(origin),
              origin.moon?.buildingLevels[.jumpGate, default: 0] ?? 0 > 0
        else {
            return []
        }

        return playerPlanets
            .filter { planet in
                planet.id != originPlanetID &&
                    (planet.moon?.buildingLevels[.jumpGate, default: 0] ?? 0) > 0
            }
            .sorted(by: Self.sortPlanetsByCoordinate)
            .map { planet in
                MoonJumpTargetSummary(
                    planetID: planet.id,
                    displayName: planet.name.displayName,
                    coordinateText: planet.coordinate.displayText,
                    readyText: (origin.moon?.jumpGateReadyAt ?? 0) <= universe.gameTime ? "就绪" : "冷却中"
                )
            }
    }

    func canJumpOneShipThroughGate(from originPlanetID: PlanetID, to targetPlanetID: PlanetID) -> Bool {
        guard let origin = planet(for: originPlanetID),
              isPlayerOwned(origin),
              defaultJumpGateShips(from: origin).isEmpty == false
        else {
            return false
        }

        return origin.moon?.buildingLevels[.jumpGate, default: 0] ?? 0 > 0 &&
            (origin.moon?.jumpGateReadyAt ?? 0) <= universe.gameTime &&
            (planet(for: targetPlanetID)?.moon?.buildingLevels[.jumpGate, default: 0] ?? 0) > 0
    }

    func jumpOneShipThroughGate(from originPlanetID: PlanetID, to targetPlanetID: PlanetID) {
        guard let origin = planet(for: originPlanetID) else {
            statusMessage = "无法使用跳跃门：找不到出发月球。"
            return
        }

        let ships = defaultJumpGateShips(from: origin)
        guard ships.isEmpty == false else {
            statusMessage = "无法使用跳跃门：出发星球没有可跳跃舰船。"
            return
        }

        guard MoonEngine.jumpShips(
            from: originPlanetID,
            to: targetPlanetID,
            ownerID: universe.playerFactionID,
            ships: ships,
            in: &universe
        ) else {
            statusMessage = "无法使用跳跃门：目标月球、设施或冷却时间不满足。"
            return
        }

        autosaveAfterQueueing(successStatus: "已通过跳跃门转移\(fleetShipsSummary(ships))。")
    }

    func recruitCommanders(count: Int) {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再招募指挥官。"
            return
        }

        let result = CommanderRecruitmentEngine.recruit(count: count, in: &universe)
        guard result.ticketsSpent > 0 else {
            statusMessage = "招募令不足，暂时无法招募指挥官。"
            return
        }

        let pullSummary = result.pulls
            .prefix(4)
            .map { pull in
                pull.isDuplicate ? "\(pull.name)+\(pull.shardsGranted)碎片" : pull.name
            }
            .joined(separator: "、")
        let extraCount = max(result.pulls.count - 4, 0)
        let suffix = extraCount > 0 ? " 等 \(result.pulls.count) 名结果" : ""
        autosaveAfterQueueing(successStatus: "已招募 \(result.ticketsSpent) 次：\(pullSummary)\(suffix)。")
    }

    func trainCommander(_ commanderID: CommanderID) {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再训练指挥官。"
            return
        }

        let amount = min(100, universe.commanderRoster.trainingData)
        guard amount > 0 else {
            statusMessage = "训练数据不足，暂时无法训练指挥官。"
            return
        }

        let name = commanderName(for: commanderID)
        guard CommanderGrowthEngine.train(commanderID, usingTrainingData: amount, in: &universe) else {
            statusMessage = "\(name) 暂时无法训练。"
            return
        }

        autosaveAfterQueueing(successStatus: "已为\(name)投入 \(amount) 点训练数据。")
    }

    func promoteCommander(_ commanderID: CommanderID) {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再升星指挥官。"
            return
        }

        let name = commanderName(for: commanderID)
        guard CommanderGrowthEngine.promote(commanderID, in: &universe) else {
            statusMessage = "\(name) 碎片不足，暂时无法升星。"
            return
        }

        autosaveAfterQueueing(successStatus: "\(name) 已完成升星。")
    }

    func commanderName(for commanderID: CommanderID?) -> String {
        guard let commanderID else {
            return "无指挥官"
        }

        return commanderSummaries.first { $0.id == commanderID }?.name ?? "未知指挥官"
    }

    func launchFleet(
        originID: PlanetID?,
        targetID: PlanetID?,
        mission: Fleet.Mission,
        ships: [ShipKind: Int],
        cargo: ResourceBundle,
        speedPercent: Double = 1,
        commanderID: CommanderID? = nil
    ) {
        if let validationFailure = fleetLaunchValidationFailure(
            originID: originID,
            targetID: targetID,
            mission: mission,
            ships: ships,
            cargo: cargo,
            speedPercent: speedPercent,
            commanderID: commanderID
        ) {
            statusMessage = "无法派遣舰队：\(validationFailure.description)。"
            return
        }

        guard let originID, let targetID else {
            statusMessage = "无法派遣舰队：请选择出发星球和目标。"
            return
        }

        let result = FleetEngine.launchFleet(
            from: originID,
            to: targetID,
            in: &universe,
            mission: mission,
            ships: normalizedShips(ships),
            cargo: cargo,
            speedPercent: speedPercent,
            commanderID: commanderID
        )

        switch result {
        case .launched(let fleet):
            autosaveAfterQueueing(successStatus: fleetLaunchStatus(for: fleet))
        case .failure(let failure):
            statusMessage = "无法派遣舰队：\(Self.fleetFailureDescription(failure))。"
        }
    }

    func canQuickLaunchStarMapMission(_ mission: Fleet.Mission, slot: SolarSystemSlotSummary) -> Bool {
        guard starMapMissionIsAllowed(mission, for: slot),
              let plan = starMapMissionPlan(mission, slot: slot)
        else {
            return false
        }

        return plan.isLaunchable
    }

    func quickLaunchStarMapMission(_ mission: Fleet.Mission, slot: SolarSystemSlotSummary) {
        guard let origin = defaultStarMapOrigin(for: mission, slot: slot),
              starMapMissionIsAllowed(mission, for: slot)
        else {
            statusMessage = "无法从星图派遣：没有可用出发星球或任务。"
            return
        }

        guard let plan = starMapMissionPlan(mission, slot: slot) else {
            statusMessage = "无法从星图派遣：无法生成任务计划。"
            return
        }

        guard plan.isLaunchable else {
            statusMessage = "无法从星图派遣：\(plan.blockers.map(\.localizedName).joined(separator: "、"))。"
            return
        }

        guard let targetID = ensureStarMapFleetTarget(for: slot) else {
            statusMessage = "无法从星图派遣：目标槽位无效。"
            return
        }

        launchFleet(originID: origin.id, targetID: targetID, mission: mission, ships: plan.ships, cargo: .zero)
    }

    func ensureColonizationTarget(galaxy: Int, system: Int, position: Int) -> PlanetID? {
        let coordinate = Coordinate(galaxy: galaxy, system: system, position: position)
        guard UniverseTopologyEngine.isValidPlanetCoordinate(coordinate) else {
            statusMessage = "无法选择殖民坐标：请输入有效星位。"
            return nil
        }

        if let existing = universe.planets.first(where: { $0.coordinate == coordinate }),
           existing.ownerID != nil
        {
            statusMessage = "无法选择殖民坐标：\(coordinate.displayText) 已被占领。"
            return nil
        }

        guard let targetID = ColonizationTargetEngine.ensureNeutralTarget(
            at: coordinate,
            visibleTo: universe.playerFactionID,
            in: &universe
        ) else {
            statusMessage = "无法选择殖民坐标：目标星位不可用。"
            return nil
        }

        refreshStrategicState()
        statusMessage = "已选择殖民坐标 \(coordinate.displayText)。"
        return targetID
    }

    func recallFleet(_ fleet: Fleet) {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再召回舰队。"
            return
        }

        guard FleetEngine.recallFleet(fleet.id, ownerID: universe.playerFactionID, in: &universe) else {
            statusMessage = "无法召回舰队：舰队已返航或不属于玩家。"
            return
        }

        autosaveAfterQueueing(successStatus: "已召回\(fleet.mission.localizedName)舰队。")
    }

    func productionPerHour(for planet: Planet) -> ResourceBundle {
        EconomyEngine.productionPerHour(for: planet, ruleSet: universe.ruleSet, research: researchState(for: planet))
    }

    func storageCapacity(for planet: Planet) -> ResourceStorage {
        EconomyEngine.storageCapacity(for: planet, ruleSet: universe.ruleSet)
    }

    func productionSetting(for kind: BuildingKind, on planet: Planet) -> Double {
        guard let value = planet.productionSettings[kind], value.isFinite else {
            return 1
        }

        return min(max(value, 0), 1)
    }

    func updateProductionSetting(planetID: PlanetID, kind: BuildingKind, value: Double) {
        guard let planetIndex = universe.planets.firstIndex(where: { $0.id == planetID }) else {
            statusMessage = "无法调整产能：找不到殖民地。"
            return
        }

        let clampedValue = min(max(value.isFinite ? value : 1, 0), 1)
        universe.planets[planetIndex].productionSettings[kind] = clampedValue
        EconomyEngine.recomputeEnergy(
            for: &universe.planets[planetIndex],
            ruleSet: universe.ruleSet,
            research: researchState(for: universe.planets[planetIndex])
        )
        statusMessage = "\(kind.localizedName)产能已设为 \(Self.formattedPercent(clampedValue))。保存后保留设置。"
    }

    func researchState(for planet: Planet) -> ResearchState {
        faction(with: planet.ownerID)?.technology ?? ResearchState()
    }

    func energySupplyRatio(for planet: Planet) -> Double {
        guard planet.energy.produced.isFinite, planet.energy.used.isFinite else {
            return 0
        }

        guard planet.energy.used > 0 else {
            return 1
        }

        return min(1, planet.energy.produced / max(planet.energy.used, 1))
    }

    func energyStatusText(for planet: Planet) -> String {
        let produced = Self.formattedWholeNumber(planet.energy.produced)
        let used = Self.formattedWholeNumber(planet.energy.used)
        let available = Self.formattedSignedWholeNumber(planet.energy.available)

        guard planet.energy.used > 0 else {
            return "产出 \(produced) · 空闲"
        }

        return "供能 \(Self.formattedPercent(energySupplyRatio(for: planet))) · 产出 \(produced) / 消耗 \(used) · 余量 \(available)"
    }

    func buildingLevel(for kind: BuildingKind, on planet: Planet) -> Int {
        max(planet.buildingLevels[kind] ?? 0, 0)
    }

    func nextBuildingLevel(for kind: BuildingKind, on planet: Planet) -> Int {
        let level = queuedBuildingLevel(for: kind, on: planet)
        guard level < Int.max else {
            return level
        }

        return level + 1
    }

    func buildingUpgradeCost(for planet: Planet, kind: BuildingKind) -> ResourceBundle? {
        buildingUpgradeTerms(for: planet, kind: kind)?.cost
    }

    func buildingUpgradeDuration(for planet: Planet, kind: BuildingKind) -> TimeInterval? {
        buildingUpgradeTerms(for: planet, kind: kind)?.duration
    }

    func canStartBuildingUpgrade(planet: Planet, kind: BuildingKind) -> Bool {
        buildingUpgradeLockedReason(planet: planet, kind: kind) == nil
    }

    func buildingUpgradeLockedReason(planet: Planet, kind: BuildingKind) -> String? {
        guard canSave else {
            return "请先开始或载入有效存档"
        }

        guard let rule = universe.ruleSet.buildingRules[kind],
              let cost = buildingUpgradeCost(for: planet, kind: kind)
        else {
            return "经济规则缺失或无效"
        }

        if let missingRequirement = QueueEngine.missingRequirement(
            for: rule.requirements,
            planet: planet,
            faction: faction(with: planet.ownerID)
        ) {
            return missingRequirement.lockedReason
        }

        guard planet.resources.canAfford(cost) else {
            return "资源不足"
        }

        return nil
    }

    func researchLevel(for technology: TechnologyKind) -> Int {
        max(playerFaction?.technology.levels[technology] ?? 0, 0)
    }

    func nextResearchLevel(for technology: TechnologyKind) -> Int {
        let level = queuedResearchLevel(for: technology)
        guard level < Int.max else {
            return level
        }

        return level + 1
    }

    func researchCost(for technology: TechnologyKind) -> ResourceBundle? {
        researchTerms(for: technology)?.cost
    }

    func researchDuration(for technology: TechnologyKind) -> TimeInterval? {
        researchTerms(for: technology)?.duration
    }

    func canAffordResearch(_ technology: TechnologyKind) -> Bool {
        guard
            let paymentPlanet = playerResearchPaymentPlanet,
            let cost = researchCost(for: technology)
        else {
            return false
        }

        return paymentPlanet.resources.canAfford(cost)
    }

    func canStartResearch(_ technology: TechnologyKind) -> Bool {
        researchLockedReason(technology) == nil
    }

    func researchLockedReason(_ technology: TechnologyKind) -> String? {
        guard canSave else {
            return "请先开始或载入有效存档"
        }

        guard let rule = universe.ruleSet.researchRules[technology],
              let paymentPlanet = playerResearchPaymentPlanet,
              let cost = researchCost(for: technology)
        else {
            return "研究规则缺失或无效"
        }

        if let missingRequirement = QueueEngine.missingRequirement(
            for: rule.requirements,
            planet: paymentPlanet,
            faction: playerFaction
        ) {
            return missingRequirement.lockedReason
        }

        guard paymentPlanet.resources.canAfford(cost) else {
            return "资源不足"
        }

        return nil
    }

    func shipBuildCost(for kind: ShipKind, quantity: Int) -> ResourceBundle? {
        guard let rule = universe.ruleSet.shipRules[kind] else {
            return nil
        }

        return unitTerms(baseCost: rule.baseCost, baseDuration: rule.baseDuration, quantity: quantity)?.cost
    }

    func shipBuildDuration(for kind: ShipKind, quantity: Int, on planet: Planet) -> TimeInterval? {
        guard let rule = universe.ruleSet.shipRules[kind] else {
            return nil
        }

        return unitTerms(baseCost: rule.baseCost, baseDuration: rule.baseDuration, quantity: quantity, planet: planet)?.duration
    }

    func defenseBuildCost(for kind: DefenseKind, quantity: Int) -> ResourceBundle? {
        guard let rule = universe.ruleSet.defenseRules[kind] else {
            return nil
        }

        return unitTerms(baseCost: rule.baseCost, baseDuration: rule.baseDuration, quantity: quantity)?.cost
    }

    func defenseBuildDuration(for kind: DefenseKind, quantity: Int, on planet: Planet) -> TimeInterval? {
        guard let rule = universe.ruleSet.defenseRules[kind] else {
            return nil
        }

        return unitTerms(baseCost: rule.baseCost, baseDuration: rule.baseDuration, quantity: quantity, planet: planet)?.duration
    }

    func missileBuildCost(for kind: MissileKind, quantity: Int) -> ResourceBundle? {
        guard let rule = universe.ruleSet.missileRules[kind] else {
            return nil
        }

        return unitTerms(baseCost: rule.baseCost, baseDuration: rule.baseDuration, quantity: quantity)?.cost
    }

    func missileBuildDuration(for kind: MissileKind, quantity: Int, on planet: Planet) -> TimeInterval? {
        guard let rule = universe.ruleSet.missileRules[kind] else {
            return nil
        }

        return unitTerms(baseCost: rule.baseCost, baseDuration: rule.baseDuration, quantity: quantity, planet: planet)?.duration
    }

    func canStartShipBuild(planet: Planet, kind: ShipKind, quantity: Int) -> Bool {
        shipBuildLockedReason(planet: planet, kind: kind, quantity: quantity) == nil
    }

    func shipBuildLockedReason(planet: Planet, kind: ShipKind, quantity: Int) -> String? {
        guard canSave else {
            return "请先开始或载入有效存档"
        }

        guard quantity > 0 else {
            return "数量无效"
        }

        guard let rule = universe.ruleSet.shipRules[kind],
              let cost = shipBuildCost(for: kind, quantity: quantity)
        else {
            return "舰船规则缺失或无效"
        }

        if let missingRequirement = QueueEngine.missingRequirement(
            for: rule.requirements,
            planet: planet,
            faction: faction(with: planet.ownerID)
        ) {
            return missingRequirement.lockedReason
        }

        guard planet.resources.canAfford(cost) else {
            return "资源不足"
        }

        return nil
    }

    func canStartDefenseBuild(planet: Planet, kind: DefenseKind, quantity: Int) -> Bool {
        defenseBuildLockedReason(planet: planet, kind: kind, quantity: quantity) == nil
    }

    func defenseBuildLockedReason(planet: Planet, kind: DefenseKind, quantity: Int) -> String? {
        guard canSave else {
            return "请先开始或载入有效存档"
        }

        guard quantity > 0 else {
            return "数量无效"
        }

        guard let rule = universe.ruleSet.defenseRules[kind],
              let cost = defenseBuildCost(for: kind, quantity: quantity)
        else {
            return "防御规则缺失或无效"
        }

        if let missingRequirement = QueueEngine.missingRequirement(
            for: rule.requirements,
            planet: planet,
            faction: faction(with: planet.ownerID)
        ) {
            return missingRequirement.lockedReason
        }

        guard planet.resources.canAfford(cost) else {
            return "资源不足"
        }

        return nil
    }

    func canStartMissileBuild(planet: Planet, kind: MissileKind, quantity: Int) -> Bool {
        missileBuildLockedReason(planet: planet, kind: kind, quantity: quantity) == nil
    }

    func missileBuildLockedReason(planet: Planet, kind: MissileKind, quantity: Int) -> String? {
        guard canSave else {
            return "请先开始或载入有效存档"
        }

        guard quantity > 0 else {
            return "数量无效"
        }

        guard let rule = universe.ruleSet.missileRules[kind],
              let cost = missileBuildCost(for: kind, quantity: quantity)
        else {
            return "导弹规则缺失或无效"
        }

        if let missingRequirement = QueueEngine.missingRequirement(
            for: rule.requirements,
            planet: planet,
            faction: faction(with: planet.ownerID)
        ) {
            return missingRequirement.lockedReason
        }

        guard planet.resources.canAfford(cost) else {
            return "资源不足"
        }

        return nil
    }

    func unitQueueStatus(_ item: UnitBuildQueueItem) -> String {
        "\(unitQueueTitle(item)) x\(item.quantity) - \(queueRemainingText(until: item.finishTime))"
    }

    func unitQueueTitle(_ item: UnitBuildQueueItem) -> String {
        switch item.unitKind {
        case .ship(let kind):
            return kind.localizedName
        case .defense(let kind):
            return kind.localizedName
        case .missile(let kind):
            return kind.localizedName
        }
    }

    func defaultOriginPlanetID() -> PlanetID? {
        playerPlanets.first?.id
    }

    private func defaultStarMapOrigin(for mission: Fleet.Mission, slot: SolarSystemSlotSummary) -> Planet? {
        playerPlanets.first { planet in
            mission != .defend || planet.id != slot.planetID
        }
    }

    func defaultTargetPlanetID(excluding originID: PlanetID?) -> PlanetID? {
        fleetTargetSummaries(excluding: originID).first?.id
    }

    func planet(for planetID: PlanetID?) -> Planet? {
        guard let planetID else {
            return nil
        }

        return universe.planets.first { $0.id == planetID }
    }

    func fleetTargetSummaries(excluding originID: PlanetID?) -> [FleetTargetSummary] {
        universe.planets
            .sorted(by: Self.sortPlanetsByCoordinate)
            .filter { planet in
                Optional(planet.id) != originID
            }
            .map(fleetTargetSummary(for:))
    }

    func fleetTargetStateSignature(targetID: PlanetID?) -> String {
        guard let target = planet(for: targetID) else {
            return "缺失"
        }

        let summary = fleetTargetSummary(for: target)
        return [
            summary.id.rawValue.uuidString,
            summary.isVisible ? "visible" : "hidden",
            summary.isPlayerOwned ? "owned" : "not-owned",
            summary.ownerName,
            Self.formattedWholeNumber(summary.debrisTotal)
        ].joined(separator: "|")
    }

    func isMissionAvailable(_ mission: Fleet.Mission, originID: PlanetID?, targetID: PlanetID?, ships: [ShipKind: Int]) -> Bool {
        guard
            let origin = planet(for: originID),
            let target = planet(for: targetID),
            originID != targetID
        else {
            return false
        }

        let normalizedShips = normalizedShips(ships)
        let targetIsVisible = isVisibleToPlayer(target)
        let targetIsPlayerOwned = isPlayerOwned(target)

        switch mission {
        case .transport:
            return targetIsPlayerOwned
        case .defend:
            return targetIsPlayerOwned && !normalizedShips.isEmpty
        case .attack, .espionage:
            return targetIsVisible && !targetIsPlayerOwned && target.ownerID != nil
        case .explore:
            return origin.id != target.id && !targetIsPlayerOwned
        case .recycle:
            return targetIsVisible &&
                (normalizedShips[.recycler] ?? 0) > 0 &&
                target.debrisField.totalAmountForDisplay > 0
        case .colonize:
            return targetIsVisible &&
                target.ownerID == nil &&
                UniverseTopologyEngine.isValidPlanetCoordinate(target.coordinate) &&
                (normalizedShips[.colonyShip] ?? 0) > 0
        case .returning:
            return false
        }
    }

    func firstAvailableMission(originID: PlanetID?, targetID: PlanetID?, ships: [ShipKind: Int]) -> Fleet.Mission? {
        fleetMissionKinds.first { mission in
            isMissionAvailable(mission, originID: originID, targetID: targetID, ships: ships)
        }
    }

    func canLaunchFleet(
        originID: PlanetID?,
        targetID: PlanetID?,
        mission: Fleet.Mission,
        ships: [ShipKind: Int],
        cargo: ResourceBundle,
        speedPercent: Double = 1,
        commanderID: CommanderID? = nil
    ) -> Bool {
        fleetLaunchValidationFailure(
            originID: originID,
            targetID: targetID,
            mission: mission,
            ships: ships,
            cargo: cargo,
            speedPercent: speedPercent,
            commanderID: commanderID
        ) == nil
    }

    func interplanetaryMissileCount(on planetID: PlanetID?) -> Int {
        max(planet(for: planetID)?.missileInventory[.interplanetaryMissile] ?? 0, 0)
    }

    func canShowMissileStrikeControls(originID: PlanetID?) -> Bool {
        interplanetaryMissileCount(on: originID) > 0
    }

    func canLaunchMissileStrike(originID: PlanetID?, targetID: PlanetID?, missileCount: Int) -> Bool {
        missileStrikeValidationFailure(originID: originID, targetID: targetID, missileCount: missileCount) == nil
    }

    func launchMissileStrike(originID: PlanetID?, targetID: PlanetID?, missileCount: Int) {
        if let validationFailure = missileStrikeValidationFailure(
            originID: originID,
            targetID: targetID,
            missileCount: missileCount
        ) {
            statusMessage = "无法发射导弹：\(validationFailure.description)。"
            return
        }

        guard let originID, let targetID, let target = planet(for: targetID) else {
            statusMessage = "无法发射导弹：请选择发射星球和目标。"
            return
        }

        switch CombatEngine.launchMissileStrike(
            from: originID,
            to: targetID,
            in: &universe,
            missileCount: missileCount
        ) {
        case .resolved:
            autosaveAfterQueueing(successStatus: "已向 \(target.coordinate.displayText) 发射导弹打击。")
        case .failed(let failure):
            statusMessage = "无法发射导弹：\(Self.missileStrikeFailureDescription(failure))。"
        }
    }

    func fleetCargoCapacity(for ships: [ShipKind: Int]) -> Double {
        normalizedShips(ships).reduce(0) { partialResult, element in
            guard let rule = universe.ruleSet.shipRules[element.key], rule.cargoCapacity.isFinite else {
                return partialResult
            }

            return partialResult + max(0, rule.cargoCapacity) * Double(element.value)
        }
    }

    func fleetMissionPlan(
        originID: PlanetID?,
        targetID: PlanetID?,
        mission: Fleet.Mission,
        ships: [ShipKind: Int],
        cargo: ResourceBundle = .zero,
        speedPercent: Double = 1
    ) -> FleetMissionPlan {
        let target = planet(for: targetID)
        return FleetMissionPlannerEngine.plan(
            originID: originID,
            targetID: targetID,
            targetIsVisible: target.map(isVisibleToPlayer) ?? true,
            in: universe,
            mission: mission,
            ships: normalizedShips(ships),
            cargo: cargo,
            speedPercent: speedPercent
        )
    }

    func starMapMissionPlan(_ mission: Fleet.Mission, slot: SolarSystemSlotSummary) -> FleetMissionPlan? {
        guard let origin = defaultStarMapOrigin(for: mission, slot: slot) else {
            return nil
        }

        let ships = defaultShips(for: mission, on: origin)
        return FleetMissionPlannerEngine.plan(
            originID: origin.id,
            targetID: slot.planetID,
            targetCoordinate: slot.coordinate,
            targetIsVisible: slot.isVisible,
            in: universe,
            mission: mission,
            ships: ships
        )
    }

    func primaryStarMapMissionPlan(for slot: SolarSystemSlotSummary) -> FleetMissionPlan? {
        let mission: Fleet.Mission
        if slot.isExpedition {
            mission = .explore
        } else if slot.planetID == nil {
            mission = .colonize
        } else if slot.debrisTotal > 0 {
            mission = .recycle
        } else if slot.isPlayerOwned {
            mission = .defend
        } else if !slot.isVisible {
            mission = .explore
        } else if slot.ownerKind != nil {
            mission = .espionage
        } else {
            mission = .explore
        }

        guard starMapMissionIsAllowed(mission, for: slot) else {
            return nil
        }

        return starMapMissionPlan(mission, slot: slot)
    }

    func fleetFuelCost(
        originID: PlanetID?,
        targetID: PlanetID?,
        ships: [ShipKind: Int],
        speedPercent: Double = 1,
        commanderID: CommanderID? = nil
    ) -> Double? {
        guard
            let origin = planet(for: originID),
            let target = planet(for: targetID)
        else {
            return nil
        }

        let fuel = FleetEngine.fuelCost(
            from: origin.coordinate,
            to: target.coordinate,
            ships: normalizedShips(ships),
            ruleSet: universe.ruleSet,
            speedPercent: speedPercent,
            commanderBonus: CommanderBonusEngine.fleetBonus(for: commanderID, in: universe)
        )
        return fuel.isFinite ? fuel : nil
    }

    func canAffordFleetFuel(
        originID: PlanetID?,
        targetID: PlanetID?,
        ships: [ShipKind: Int],
        cargo: ResourceBundle,
        speedPercent: Double = 1,
        commanderID: CommanderID? = nil
    ) -> Bool {
        guard
            let origin = planet(for: originID),
            let fuel = fleetFuelCost(
                originID: originID,
                targetID: targetID,
                ships: ships,
                speedPercent: speedPercent,
                commanderID: commanderID
            ),
            fuel >= 0
        else {
            return false
        }

        let resourcesAfterCargo = origin.resources.subtracting(cargo)
        return resourcesAfterCargo.canAfford(ResourceBundle(deuterium: fuel))
    }

    func fleetFuelStatusText(
        originID: PlanetID?,
        targetID: PlanetID?,
        ships: [ShipKind: Int],
        cargo: ResourceBundle,
        speedPercent: Double = 1,
        commanderID: CommanderID? = nil
    ) -> String {
        guard let fuel = fleetFuelCost(
            originID: originID,
            targetID: targetID,
            ships: ships,
            speedPercent: speedPercent,
            commanderID: commanderID
        ) else {
            return "未知"
        }

        guard let origin = planet(for: originID) else {
            return Self.formattedWholeNumber(fuel)
        }

        let deuteriumAfterCargo = origin.resources.subtracting(cargo).deuterium
        guard deuteriumAfterCargo < fuel else {
            return Self.formattedWholeNumber(fuel)
        }

        return "需要 \(Self.formattedWholeNumber(fuel))；可用 \(Self.formattedWholeNumber(max(0, deuteriumAfterCargo)))"
    }

    func fleetTravelDuration(
        originID: PlanetID?,
        targetID: PlanetID?,
        ships: [ShipKind: Int],
        speedPercent: Double = 1,
        commanderID: CommanderID? = nil
    ) -> TimeInterval? {
        guard
            let origin = planet(for: originID),
            let target = planet(for: targetID)
        else {
            return nil
        }

        let duration = FleetEngine.travelDuration(
            from: origin.coordinate,
            to: target.coordinate,
            ships: normalizedShips(ships),
            ruleSet: universe.ruleSet,
            research: researchState(for: origin),
            speedPercent: speedPercent,
            commanderBonus: CommanderBonusEngine.fleetBonus(for: commanderID, in: universe)
        )
        return duration.isFinite && duration > 0 ? duration : nil
    }

    func battlePreviewText(
        originID: PlanetID?,
        targetID: PlanetID?,
        mission: Fleet.Mission,
        ships: [ShipKind: Int],
        cargo: ResourceBundle,
        speedPercent: Double = 1,
        commanderID: CommanderID? = nil
    ) -> String? {
        guard mission == .attack,
              let origin = planet(for: originID),
              let target = planet(for: targetID),
              let ownerID = origin.ownerID
        else {
            return nil
        }

        let duration = fleetTravelDuration(
            originID: originID,
            targetID: targetID,
            ships: ships,
            speedPercent: speedPercent,
            commanderID: commanderID
        ) ?? 1
        let fleet = Fleet(
            ownerID: ownerID,
            mission: .attack,
            origin: origin.coordinate,
            target: target.coordinate,
            ships: normalizedShips(ships),
            cargo: cargo,
            launchTime: universe.gameTime,
            arrivalTime: universe.gameTime + duration,
            returnTime: universe.gameTime + duration * 2,
            originPlanetID: origin.id,
            targetPlanetID: target.id,
            speedPercent: speedPercent,
            commanderID: commanderID
        )

        guard let preview = CombatEngine.previewAttack(fleet, in: universe),
              let firstRound = preview.rounds.first
        else {
            return "无法预估"
        }

        let winner = preview.attackerWon ? "优势" : "劣势"
        let losses = firstRound.attackerLosses.values.reduce(0) { $0 + max($1, 0) }
        return "\(winner) · 预计损失 \(losses) 艘 · 回合 \(preview.rounds.count)"
    }

    func fleetShipsSummary(_ ships: [ShipKind: Int]) -> String {
        let parts = normalizedShips(ships)
            .sorted { lhs, rhs in lhs.key.rawValue < rhs.key.rawValue }
            .map { "\($0.key.rawValue.displayName) x\($0.value)" }
        return parts.isEmpty ? "无舰船" : parts.joined(separator: ", ")
    }

    func fleetCargoSummary(_ cargo: ResourceBundle) -> String {
        guard cargo.totalAmountForDisplay > 0 else {
            return "无货物"
        }

        return "金 \(Self.formattedWholeNumber(cargo.metal)) / 晶 \(Self.formattedWholeNumber(cargo.crystal)) / 重 \(Self.formattedWholeNumber(cargo.deuterium))"
    }

    func fleetPhaseText(_ fleet: Fleet) -> String {
        "\(fleet.phase.localizedName) - \(fleetRemainingText(fleet))"
    }

    func fleetRemainingText(_ fleet: Fleet) -> String {
        let nextTime = fleetNextTime(fleet)
        guard nextTime.isFinite, universe.gameTime.isFinite else {
            return "剩余时间未知"
        }

        let remaining = max(0, nextTime - universe.gameTime)
        guard remaining > 0 else {
            return "就绪"
        }

        return "剩余 \(Self.formattedDuration(remaining))"
    }

    func reportDetailSummary(_ report: Report) -> String {
        let loot = fleetCargoSummary(report.loot)
        let debris = fleetCargoSummary(report.debris)
        let losses = fleetCargoSummary(report.losses)
        guard report.kind == .battle, !report.battleRounds.isEmpty else {
            return "战利品 \(loot) - 残骸 \(debris) - 损失 \(losses)"
        }

        let attackerShots = report.battleRounds.reduce(0) { $0 + $1.attackerShots }
        let defenderShots = report.battleRounds.reduce(0) { $0 + $1.defenderShots }
        let rapidFire = report.battleRounds.reduce(0) { $0 + $1.rapidFireShots }
        let explosions = report.battleRounds.reduce(0) { $0 + $1.explodedUnits }
        let moonChance = UniverseTopologyEngine.moonChancePercent(forDebris: report.debris)
        return "\(report.battleRounds.count) 回合 - 射击 \(attackerShots)/\(defenderShots) - RF \(rapidFire) - 爆炸 \(explosions) - 月球 \(moonChance)% - 战利品 \(loot) - 残骸 \(debris)"
    }

    func combatReview(for report: Report) -> CombatReview? {
        CombatReviewEngine.review(for: report)
    }

    func queueRemainingText(until finishTime: TimeInterval) -> String {
        guard finishTime.isFinite, universe.gameTime.isFinite else {
            return "剩余时间未知"
        }

        let remaining = max(0, finishTime - universe.gameTime)
        guard remaining > 0 else {
            return "就绪"
        }

        return "剩余 \(Self.formattedDuration(remaining))"
    }

    func durationText(_ duration: TimeInterval?) -> String {
        guard let duration, duration.isFinite else {
            return "未知"
        }

        return Self.formattedDuration(duration)
    }

    func buildQueueStatus(_ item: BuildQueueItem) -> String {
        "\(item.buildingKind.localizedName) \(item.targetLevel) 级 - \(queueRemainingText(until: item.finishTime))"
    }

    func researchQueueStatus(_ item: ResearchQueueItem) -> String {
        "\(item.technologyKind.localizedName) \(item.targetLevel) 级 - \(queueRemainingText(until: item.finishTime))"
    }

    func queueProgress(startTime: TimeInterval, finishTime: TimeInterval) -> Double {
        guard
            startTime.isFinite,
            finishTime.isFinite,
            universe.gameTime.isFinite
        else {
            return 0
        }

        let duration = finishTime - startTime
        guard duration > 0 else {
            return 1
        }

        let elapsed = min(max(universe.gameTime - startTime, 0), duration)
        return elapsed / duration
    }

    func handleRealtimeFrame(now: Date) {
        guard canSave else {
            lastRealtimeTickDate = now
            return
        }

        var realtimeState = RealtimeSimulationState(lastFrameDate: lastRealtimeTickDate)
        let result = RealtimeSimulationEngine.advanceFrame(
            universe: &universe,
            state: &realtimeState,
            now: now,
            settings: settings,
            isPaused: isSimulationPaused
        )
        lastRealtimeTickDate = realtimeState.lastFrameDate

        guard result.didAdvance else {
            return
        }

        refreshStrategicState()
        autosaveAfterRealtimeAdvanceIfNeeded(now: now)
    }

    func toggleSimulationPaused() {
        setSimulationPaused(!isSimulationPaused)
    }

    func setSimulationPaused(_ isPaused: Bool) {
        isSimulationPaused = isPaused
        lastRealtimeTickDate = currentDate()
        statusMessage = isPaused
            ? "实时模拟已暂停。离线补算仍由离线强度控制。"
            : "实时模拟已继续，以 \(formattedGameSpeed) 运行。"
    }

    func save() {
        guard canSave else {
            statusMessage = "自动存档载入失败，保存已禁用。请先开始新游戏。"
            return
        }

        do {
            refreshStrategicState()
            let savedPendingOfflineCatchUp = hasPendingOfflineCatchUpSave
            let savedAt = currentDate()
            try repository.save(universe, wallClockDate: savedAt, settings: settings)
            hasPendingOfflineCatchUpSave = false
            lastPeriodicAutosaveDate = savedAt
            statusMessage = savedPendingOfflineCatchUp
                ? "宇宙已保存，离线进度也已写入。"
                : "宇宙已保存。"
            refreshSaveSlots()
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    func startNewGame() {
        universe = StarterUniverseFactory.makeNewGame(seed: 1, playerName: "指挥官")
        refreshStrategicState()
        offlineSummary = nil
        hasPendingOfflineCatchUpSave = false
        isSimulationPaused = false
        lastRealtimeTickDate = nil
        lastPeriodicAutosaveDate = nil
        canSave = true
        isOnboardingVisible = true
        statusMessage = "新游戏已开始。保存后会替换当前自动存档。"
    }

    func dismissOnboarding() {
        isOnboardingVisible = false
        statusMessage = "初始提示已关闭。可在设置中调整保存和模拟速度。"
    }

    func updateGameSpeed(_ gameSpeed: Double) {
        settings.gameSpeed = GameSettings.clampedGameSpeed(gameSpeed)
        statusMessage = "实时模拟速度已设为 \(formattedGameSpeed)。"
    }

    func updateOfflineIntensity(_ offlineIntensity: GameSettings.OfflineIntensity) {
        settings.offlineIntensity = offlineIntensity
        statusMessage = "离线模拟已设为\(offlineIntensity.displayName)。保存后保留设置。"
    }

    func updateAutosaveEnabled(_ isEnabled: Bool) {
        settings.isAutosaveEnabled = isEnabled
        statusMessage = isEnabled
            ? "队列、舰队和实时模拟将自动保存。"
            : "自动保存已关闭，实时进度需手动保存。"
    }

    func updateAutoUpgradeEnabled(_ isEnabled: Bool) {
        settings.isAutoUpgradeEnabled = isEnabled

        guard isEnabled else {
            autosaveSettingsChange(successStatus: "托管升级已关闭。")
            return
        }

        runAutoUpgradeNow()
    }

    func runAutoUpgradeNow() {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再启用托管升级。"
            return
        }

        let result = PlayerAutoUpgradeEngine.makeDecisions(in: &universe, policy: settings.autoUpgradePolicy)
        guard result.didQueue else {
            let noActionStatus = settings.isAutoUpgradeEnabled
                ? "托管升级已开启：当前资源、前置或队列状态不足，空闲时会继续尝试。"
                : "当前没有可自动加入的建筑或科技。"
            if settings.isAutoUpgradeEnabled {
                autosaveSettingsChange(successStatus: noActionStatus)
            } else {
                refreshStrategicState()
                statusMessage = noActionStatus
            }
            return
        }

        autosaveAfterQueueing(successStatus: Self.autoUpgradeQueuedStatus(for: result))
    }

    func grantInfiniteResourcesForTesting() {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再使用测试资源。"
            return
        }

        let updatedCount = TestingResourceGrant.grantInfiniteResources(toPlayerIn: &universe)
        guard updatedCount > 0 else {
            statusMessage = "没有可注入测试资源的玩家星球。"
            return
        }

        autosaveAfterQueueing(successStatus: "测试资源已注入：\(updatedCount) 个玩家星球获得近似无限资源。")
    }

    func updateDifficulty(_ difficulty: GameSettings.Difficulty) {
        settings.difficulty = difficulty
        statusMessage = "难度已设为\(difficulty.displayName)。\(difficulty.behaviorDescription)"
    }

    func updateAutoUpgradeStrategy(_ strategy: AutoUpgradeStrategy) {
        settings.autoUpgradePolicy.strategy = strategy
        autosaveSettingsChange(successStatus: "托管策略已设为\(strategy.localizedName)。")
    }

    func updateAutoUpgradeReserveRatio(_ ratio: Double) {
        settings.autoUpgradePolicy.resourceReserveRatio = AutoUpgradePolicy(
            strategy: settings.autoUpgradePolicy.strategy,
            resourceReserveRatio: ratio,
            maxBuildQueueDepthPerPlanet: settings.autoUpgradePolicy.maxBuildQueueDepthPerPlanet,
            maxResearchQueueDepth: settings.autoUpgradePolicy.maxResearchQueueDepth,
            allowShipConstruction: settings.autoUpgradePolicy.allowShipConstruction,
            allowDefenseConstruction: settings.autoUpgradePolicy.allowDefenseConstruction,
            allowMissileConstruction: settings.autoUpgradePolicy.allowMissileConstruction
        ).resourceReserveRatio
        statusMessage = "托管资源保留已设为 \(Self.formattedPercent(settings.autoUpgradePolicy.resourceReserveRatio))。保存后保留设置。"
    }

    func updateAutoUpgradeBuildQueueDepth(_ depth: Int) {
        settings.autoUpgradePolicy.maxBuildQueueDepthPerPlanet = AutoUpgradePolicy(
            strategy: settings.autoUpgradePolicy.strategy,
            resourceReserveRatio: settings.autoUpgradePolicy.resourceReserveRatio,
            maxBuildQueueDepthPerPlanet: depth,
            maxResearchQueueDepth: settings.autoUpgradePolicy.maxResearchQueueDepth,
            allowShipConstruction: settings.autoUpgradePolicy.allowShipConstruction,
            allowDefenseConstruction: settings.autoUpgradePolicy.allowDefenseConstruction,
            allowMissileConstruction: settings.autoUpgradePolicy.allowMissileConstruction
        ).maxBuildQueueDepthPerPlanet
        statusMessage = "托管建筑队列深度已设为 \(settings.autoUpgradePolicy.maxBuildQueueDepthPerPlanet)。保存后保留设置。"
    }

    func updateAutoUpgradeResearchQueueDepth(_ depth: Int) {
        settings.autoUpgradePolicy.maxResearchQueueDepth = AutoUpgradePolicy(
            strategy: settings.autoUpgradePolicy.strategy,
            resourceReserveRatio: settings.autoUpgradePolicy.resourceReserveRatio,
            maxBuildQueueDepthPerPlanet: settings.autoUpgradePolicy.maxBuildQueueDepthPerPlanet,
            maxResearchQueueDepth: depth,
            allowShipConstruction: settings.autoUpgradePolicy.allowShipConstruction,
            allowDefenseConstruction: settings.autoUpgradePolicy.allowDefenseConstruction,
            allowMissileConstruction: settings.autoUpgradePolicy.allowMissileConstruction
        ).maxResearchQueueDepth
        statusMessage = "托管科研队列深度已设为 \(settings.autoUpgradePolicy.maxResearchQueueDepth)。保存后保留设置。"
    }

    func updateAutoUpgradeShipConstruction(_ isAllowed: Bool) {
        settings.autoUpgradePolicy.allowShipConstruction = isAllowed
        statusMessage = isAllowed ? "托管已允许自动造舰。" : "托管已停止自动造舰。"
    }

    func updateAutoUpgradeDefenseConstruction(_ isAllowed: Bool) {
        settings.autoUpgradePolicy.allowDefenseConstruction = isAllowed
        statusMessage = isAllowed ? "托管已允许自动造防御。" : "托管已停止自动造防御。"
    }

    func updateAutoUpgradeMissileConstruction(_ isAllowed: Bool) {
        settings.autoUpgradePolicy.allowMissileConstruction = isAllowed
        statusMessage = isAllowed ? "托管已允许自动造导弹。" : "托管已停止自动造导弹。"
    }

    func refreshSaveSlots() {
        do {
            saveSlots = try repository.listSaveSlots()
        } catch {
            saveSlots = []
        }
    }

    func createBackup() {
        do {
            let slot = try repository.createBackup(wallClockDate: currentDate())
            refreshSaveSlots()
            statusMessage = "已创建备份 \(slot.name)，自动存档未修改。"
        } catch {
            statusMessage = "备份失败：\(Self.loadFailureDescription(for: error))"
        }
    }

    func saveForLifecycleChange() {
        guard canSave, settings.isAutosaveEnabled, !hasPendingOfflineCatchUpSave else {
            return
        }

        do {
            refreshStrategicState()
            let savedAt = currentDate()
            try repository.save(universe, wallClockDate: savedAt, settings: settings)
            lastPeriodicAutosaveDate = savedAt
            refreshSaveSlots()
        } catch {
            statusMessage = "离开前自动保存失败：\(error.localizedDescription)"
        }
    }

    func deleteSaveSlot(named slotName: String) {
        guard slotName != repository.fileName else {
            statusMessage = "自动存档受保护。请先创建备份，再手动移除存档。"
            return
        }

        do {
            try repository.deleteBackup(named: slotName)
            refreshSaveSlots()
            statusMessage = "已删除备份 \(slotName)。"
        } catch {
            statusMessage = "删除失败：\(Self.loadFailureDescription(for: error))"
        }
    }

    func openSaveDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: repository.saveDirectory,
                withIntermediateDirectories: true
            )
            #if canImport(AppKit)
            NSWorkspace.shared.open(repository.saveDirectory)
            statusMessage = "已打开存档文件夹。"
            #else
            statusMessage = "存档路径：\(repository.saveDirectory.path)"
            #endif
        } catch {
            statusMessage = "无法打开存档文件夹：\(error.localizedDescription)"
        }
    }

    private func resourceFocusBriefing(for planet: Planet) -> CommanderBriefingItem {
        let rates = productionPerHour(for: planet)
        let resources = [
            (name: "金属", amount: planet.resources.metal, rate: rates.metal),
            (name: "晶体", amount: planet.resources.crystal, rate: rates.crystal),
            (name: "重氢", amount: planet.resources.deuterium, rate: rates.deuterium)
        ]
        let focus = resources.min { lhs, rhs in
            lhs.amount < rhs.amount
        } ?? resources[0]

        return CommanderBriefingItem(
            title: "资源焦点",
            detail: "\(focus.name)储备 \(Self.formattedWholeNumber(focus.amount))，小时产量 +\(Self.formattedWholeNumber(focus.rate))。",
            systemImage: "shippingbox",
            urgency: focus.amount < 250 ? .warning : .info
        )
    }

    private func buildingBriefing(for planet: Planet) -> CommanderBriefingItem {
        if let readyKind = availableBuildingKinds.first(where: { canStartBuildingUpgrade(planet: planet, kind: $0) }) {
            return CommanderBriefingItem(
                title: "建筑建议",
                detail: "\(readyKind.localizedName)可立即升级到 \(nextBuildingLevel(for: readyKind, on: planet)) 级。",
                systemImage: "hammer",
                urgency: .good
            )
        }

        if !planet.buildQueue.isEmpty {
            return CommanderBriefingItem(
                title: "建筑建议",
                detail: "已排 \(planet.buildQueue.count) 个建筑项目，资源足够时可继续追加经济建筑与电力。",
                systemImage: "timer",
                urgency: .info
            )
        }

        let reason = availableBuildingKinds
            .compactMap { buildingUpgradeLockedReason(planet: planet, kind: $0) }
            .first ?? "资源不足"

        return CommanderBriefingItem(
            title: "建筑建议",
            detail: "暂时无法开工：\(reason)。优先等待产能或调整资源。",
            systemImage: "exclamationmark.triangle",
            urgency: .warning
        )
    }

    private func researchBriefing() -> CommanderBriefingItem? {
        if let technology = availableResearchKinds.first(where: canStartResearch) {
            return CommanderBriefingItem(
                title: "科研建议",
                detail: "\(technology.localizedName)可研究到 \(nextResearchLevel(for: technology)) 级，适合解锁舰队节奏。",
                systemImage: "atom",
                urgency: .good
            )
        }

        guard playerFaction != nil else {
            return nil
        }

        if let researchQueue = playerFaction?.researchQueue, !researchQueue.isEmpty {
            return CommanderBriefingItem(
                title: "科研建议",
                detail: "已排 \(researchQueue.count) 个研究项目，资源足够时可继续追加驱动和战斗科技。",
                systemImage: "timer",
                urgency: .info
            )
        }

        return CommanderBriefingItem(
            title: "科研建议",
            detail: "当前科研受资源或实验室等级限制，先补经济与研究实验室。",
            systemImage: "testtube.2",
            urgency: .info
        )
    }

    private func fleetBriefing() -> CommanderBriefingItem {
        let ownedShips = playerPlanets.reduce(0) { total, planet in
            total + planet.shipInventory.values.reduce(0, +)
        }
        let activePlayerFleets = activeFleets.filter { $0.ownerID == universe.playerFactionID }.count

        if activePlayerFleets > 0 {
            return CommanderBriefingItem(
                title: "舰队态势",
                detail: "\(activePlayerFleets) 支舰队正在飞行，停泊舰船 \(ownedShips) 艘。",
                systemImage: "paperplane",
                urgency: .info
            )
        }

        if ownedShips == 0 {
            return CommanderBriefingItem(
                title: "舰队态势",
                detail: "尚无可用舰船。先造小型运输舰或探测器，打开探索与运输循环。",
                systemImage: "paperplane",
                urgency: .warning
            )
        }

        return CommanderBriefingItem(
            title: "舰队态势",
            detail: "停泊舰船 \(ownedShips) 艘，可选择探索、回收或侦察来加速前期收益。",
            systemImage: "paperplane",
            urgency: .good
        )
    }

    private static func victoryRouteSystemImage(_ route: VictoryRoute) -> String {
        switch route {
        case .economy:
            return "chart.line.uptrend.xyaxis"
        case .technology:
            return "atom"
        case .domination:
            return "scope"
        case .exploration:
            return "sparkles"
        }
    }

    private static func loadFailureStatus(for error: Error) -> String {
        "自动存档载入失败：\(loadFailureDescription(for: error))。为保护现有文件，保存已禁用。"
    }

    private static func loadFailureDescription(for error: Error) -> String {
        if case JSONSaveRepository.RepositoryError.unsupportedSchema(let schemaVersion) = error {
            return "不支持的存档结构版本 \(schemaVersion)"
        }

        if case JSONSaveRepository.RepositoryError.invalidFileName(let fileName) = error {
            return "存档文件名无效：\(fileName)"
        }

        return error.localizedDescription
    }

    private static func formattedWholeSeconds(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else {
            return "未知时间"
        }

        return seconds.formatted(.number.precision(.fractionLength(0))) + " 秒"
    }

    private static func offlineCatchUpPendingStatus(for summary: OfflineCatchUpSummary) -> String {
        "已补算离线进度 \(formattedDuration(summary.elapsedSeconds))，进度已应用但尚未保存。"
    }

    private static func offlineSummaryDetail(
        for summary: OfflineCatchUpSummary,
        hasPendingSave: Bool
    ) -> String {
        let constructionText = itemCountText(summary.completedConstructionCount, singular: "项建造")
        let researchText = itemCountText(summary.completedResearchCount, singular: "项研究")
        let saveText = hasPendingSave ? "等待保存。" : "已保存。"
        return "处理 \(summary.processedChunks) 个片段；完成 \(constructionText) 和 \(researchText)。\(saveText)"
    }

    private static func itemCountText(_ count: Int, singular: String) -> String {
        "\(count) \(singular)"
    }

    private var playerResearchPaymentPlanet: Planet? {
        guard let playerFaction else {
            return nil
        }

        for planetID in playerFaction.ownedPlanetIDs {
            if let planet = universe.planets.first(where: { $0.id == planetID && $0.ownerID == playerFaction.id }) {
                return planet
            }
        }

        return nil
    }

    private func autosaveAfterQueueing(successStatus: String) {
        refreshStrategicState()

        if hasPendingOfflineCatchUpSave {
            statusMessage = "\(successStatus) 离线进度和本次操作等待保存。"
            return
        }

        guard settings.isAutosaveEnabled else {
            statusMessage = "\(successStatus) 自动保存已关闭，需要时请手动保存。"
            return
        }

        do {
            let savedAt = currentDate()
            try repository.save(universe, wallClockDate: savedAt, settings: settings)
            lastPeriodicAutosaveDate = savedAt
            refreshSaveSlots()
            statusMessage = "\(successStatus) 已自动保存。"
        } catch {
            statusMessage = "\(successStatus) 自动保存失败：\(error.localizedDescription)"
        }
    }

    private func autosaveSettingsChange(successStatus: String) {
        refreshStrategicState()

        if hasPendingOfflineCatchUpSave {
            statusMessage = "\(successStatus) 离线进度和设置等待保存。"
            return
        }

        guard settings.isAutosaveEnabled else {
            statusMessage = "\(successStatus) 自动保存已关闭，需要时请手动保存。"
            return
        }

        do {
            let savedAt = currentDate()
            try repository.save(universe, wallClockDate: savedAt, settings: settings)
            lastPeriodicAutosaveDate = savedAt
            refreshSaveSlots()
            statusMessage = "\(successStatus) 已自动保存。"
        } catch {
            statusMessage = "\(successStatus) 自动保存失败：\(error.localizedDescription)"
        }
    }

    private func autosaveAfterRealtimeAdvanceIfNeeded(now: Date) {
        guard settings.isAutosaveEnabled, !hasPendingOfflineCatchUpSave else {
            return
        }

        if let lastPeriodicAutosaveDate {
            let elapsed = now.timeIntervalSince(lastPeriodicAutosaveDate)
            guard elapsed.isFinite, elapsed >= periodicAutosaveInterval else {
                return
            }
        }

        do {
            try repository.save(universe, wallClockDate: now, settings: settings)
            lastPeriodicAutosaveDate = now
            refreshSaveSlots()
        } catch {
            statusMessage = "实时自动保存失败：\(error.localizedDescription)"
        }
    }

    private func refreshStrategicState() {
        PlayerVisibilityEngine.normalizeFactionPlanetIndexes(in: &universe)
        StrategicEngine.updateStrategicState(in: &universe)
        PlayerObjectiveEngine.updatePlayerObjectives(in: &universe)
    }

    private static func refreshedStrategicUniverse(_ universe: Universe) -> Universe {
        var refreshed = universe
        PlayerVisibilityEngine.normalizeFactionPlanetIndexes(in: &refreshed)
        StrategicEngine.updateStrategicState(in: &refreshed)
        PlayerObjectiveEngine.updatePlayerObjectives(in: &refreshed)
        return refreshed
    }

    private func faction(with factionID: FactionID?) -> Faction? {
        guard let factionID else {
            return nil
        }

        return universe.factions.first { $0.id == factionID }
    }

    private func activeCommanderAssignments() -> [CommanderID: Fleet] {
        universe.fleets.reduce(into: [:]) { result, fleet in
            guard fleet.phase != .completed, let commanderID = fleet.commanderID else {
                return
            }
            result[commanderID] = fleet
        }
    }

    private func commanderIsAvailableForLaunch(_ commanderID: CommanderID?) -> Bool {
        guard let commanderID else {
            return true
        }

        return universe.commanderRoster.ownedCommanders.contains { $0.id == commanderID } &&
            activeCommanderAssignments()[commanderID] == nil
    }

    private func buildingUpgradeTerms(for planet: Planet, kind: BuildingKind) -> (cost: ResourceBundle, duration: TimeInterval)? {
        guard let rule = universe.ruleSet.buildingRules[kind] else {
            return nil
        }

        let targetLevel = nextBuildingLevel(for: kind, on: planet)
        guard targetLevel > buildingLevel(for: kind, on: planet) else {
            return nil
        }

        return Self.terms(
            baseCost: rule.baseCost,
            costMultiplier: rule.costMultiplier,
            baseDuration: rule.baseDuration,
            durationMultiplier: rule.durationMultiplier,
            targetLevel: targetLevel,
            speedFactor: constructionSpeedFactor(for: planet)
        )
    }

    private func unitTerms(
        baseCost: ResourceBundle,
        baseDuration: TimeInterval,
        quantity: Int,
        planet: Planet? = nil
    ) -> (cost: ResourceBundle, duration: TimeInterval)? {
        guard
            quantity > 0,
            Self.isValidCost(baseCost),
            baseDuration.isFinite,
            baseDuration > 0
        else {
            return nil
        }

        let multiplier = Double(quantity)
        let cost = baseCost.scaled(by: multiplier)
        let duration = Self.acceleratedDuration(
            baseDuration * multiplier,
            speedFactor: planet.map(shipyardSpeedFactor(for:)) ?? 1
        )
        guard Self.isValidCost(cost), duration.isFinite, duration > 0 else {
            return nil
        }

        return (cost, duration)
    }

    private func researchTerms(for technology: TechnologyKind) -> (cost: ResourceBundle, duration: TimeInterval)? {
        guard let rule = universe.ruleSet.researchRules[technology] else {
            return nil
        }

        let targetLevel = nextResearchLevel(for: technology)
        guard targetLevel > researchLevel(for: technology) else {
            return nil
        }

        return Self.terms(
            baseCost: rule.baseCost,
            costMultiplier: rule.costMultiplier,
            baseDuration: rule.baseDuration,
            durationMultiplier: rule.durationMultiplier,
            targetLevel: targetLevel
        )
    }

    private func queuedBuildingLevel(for kind: BuildingKind, on planet: Planet) -> Int {
        let currentLevel = buildingLevel(for: kind, on: planet)
        let queuedLevel = planet.buildQueue
            .filter { $0.buildingKind == kind }
            .map { max($0.targetLevel, 0) }
            .max() ?? currentLevel

        return max(currentLevel, queuedLevel)
    }

    private func queuedResearchLevel(for technology: TechnologyKind) -> Int {
        let currentLevel = researchLevel(for: technology)
        let queuedLevel = playerFaction?.researchQueue
            .filter { $0.technologyKind == technology }
            .map { max($0.targetLevel, 0) }
            .max() ?? currentLevel

        return max(currentLevel, queuedLevel)
    }

    private static func terms(
        baseCost: ResourceBundle,
        costMultiplier: Double,
        baseDuration: TimeInterval,
        durationMultiplier: Double,
        targetLevel: Int,
        speedFactor: Double = 1
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
        let costScale = pow(costMultiplier, exponent)
        let durationScale = pow(durationMultiplier, exponent)
        guard costScale.isFinite, durationScale.isFinite else {
            return nil
        }

        let cost = baseCost.scaled(by: costScale)
        let duration = acceleratedDuration(baseDuration * durationScale, speedFactor: speedFactor)
        guard isValidCost(cost), duration.isFinite, duration > 0 else {
            return nil
        }

        return (cost, duration)
    }

    private static func acceleratedDuration(_ duration: TimeInterval, speedFactor: Double) -> TimeInterval {
        guard duration.isFinite, duration > 0, speedFactor.isFinite, speedFactor > 0 else {
            return duration
        }

        return max(1, ceil(duration / speedFactor))
    }

    private func constructionSpeedFactor(for planet: Planet) -> Double {
        speedFactor(for: planet, keyPath: \.constructionSpeedBonus)
    }

    private func shipyardSpeedFactor(for planet: Planet) -> Double {
        speedFactor(for: planet, keyPath: \.shipyardSpeedBonus)
    }

    private func speedFactor(for planet: Planet, keyPath: KeyPath<BuildingRule, Double>) -> Double {
        var factor = 1.0

        for (building, level) in planet.buildingLevels {
            let normalizedLevel = max(level, 0)
            guard normalizedLevel > 0,
                  let rule = universe.ruleSet.buildingRules[building]
            else {
                continue
            }

            let bonus = rule[keyPath: keyPath]
            guard bonus.isFinite, bonus > 0 else {
                continue
            }

            factor += bonus * Double(normalizedLevel)
        }

        return max(factor, 1)
    }

    private static func isValidCost(_ cost: ResourceBundle) -> Bool {
        cost.metal.isFinite &&
            cost.crystal.isFinite &&
            cost.deuterium.isFinite &&
            cost.metal >= 0 &&
            cost.crystal >= 0 &&
            cost.deuterium >= 0
    }

    private static func buildingQueuedStatus(
        planetName: String?,
        kind: BuildingKind,
        targetLevel: Int?
    ) -> String {
        let levelText = targetLevel.map { "等级 \($0)" } ?? ""
        let location = planetName.map { "（\($0.displayName)）" } ?? ""
        return "已加入\(kind.localizedName)\(levelText)\(location)。"
    }

    private static func researchQueuedStatus(technology: TechnologyKind, targetLevel: Int?) -> String {
        let levelText = targetLevel.map { "等级 \($0)" } ?? ""
        return "已加入\(technology.localizedName)\(levelText)。"
    }

    private static func autoUpgradeQueuedStatus(for result: PlayerAutoUpgradeResult) -> String {
        var queuedItems: [String] = []
        if result.queuedBuildings > 0 {
            queuedItems.append("\(result.queuedBuildings) 项建筑")
        }
        if result.queuedResearch > 0 {
            queuedItems.append("\(result.queuedResearch) 项科技")
        }
        if result.queuedShips > 0 {
            queuedItems.append("\(result.queuedShips) 项造舰")
        }
        if result.queuedDefenses > 0 {
            queuedItems.append("\(result.queuedDefenses) 项防御")
        }
        if result.queuedMissiles > 0 {
            queuedItems.append("\(result.queuedMissiles) 项导弹")
        }

        let detail = queuedItems.isEmpty ? "升级" : queuedItems.joined(separator: "、")
        return "托管升级已加入\(detail)。"
    }

    private func fleetLaunchStatus(for fleet: Fleet) -> String {
        let commanderText = fleet.commanderID.map { "，指挥官 \(commanderName(for: $0))" } ?? ""
        return "已派遣\(fleet.mission.localizedName)舰队前往 \(fleet.target.displayText)\(commanderText)。"
    }

    private static func buildingQueueFailureStatus(_ result: QueueResult, kind: BuildingKind) -> String {
        "无法加入\(kind.localizedName)：\(queueFailureDescription(result))。"
    }

    private static func researchQueueFailureStatus(_ result: QueueResult, technology: TechnologyKind) -> String {
        "无法加入\(technology.localizedName)：\(queueFailureDescription(result))。"
    }

    private static func shipQueueFailureStatus(_ result: QueueResult, kind: ShipKind) -> String {
        "无法加入\(kind.localizedName)：\(queueFailureDescription(result))。"
    }

    private static func defenseQueueFailureStatus(_ result: QueueResult, kind: DefenseKind) -> String {
        "无法加入\(kind.localizedName)：\(queueFailureDescription(result))。"
    }

    private static func missileQueueFailureStatus(_ result: QueueResult, kind: MissileKind) -> String {
        "无法加入\(kind.localizedName)：\(queueFailureDescription(result))。"
    }

    private static func queueFailureDescription(_ result: QueueResult) -> String {
        switch result {
        case .queued:
            return "已经加入队列"
        case .insufficientResources:
            return "资源不足"
        case .missingPlanet:
            return "找不到殖民地"
        case .missingFaction:
            return "找不到阵营"
        case .queueBusy:
            return "队列暂不可用"
        case .missingRule:
            return "规则缺失或无效"
        case .missingRequirement(let requirement):
            return requirement.lockedReason
        case .noAvailableFields:
            return "星球可用地块不足"
        }
    }

    private static func fleetFailureDescription(_ failure: FleetLaunchFailure) -> String {
        switch failure {
        case .missingOrigin:
            return "找不到出发星球"
        case .missingTarget:
            return "找不到目标"
        case .missingOwner:
            return "出发星球没有归属"
        case .insufficientShips:
            return "舰船不足"
        case .insufficientCargo:
            return "货舱容量或资源不足"
        case .insufficientFuel:
            return "重氢燃料不足"
        case .invalidMission:
            return "所选舰船或目标无法执行该任务"
        case .fleetSlotLimit:
            return "舰队槽已满"
        case .commanderUnavailable:
            return "指挥官不可用"
        }
    }

    private static func missileStrikeFailureDescription(_ failure: CombatEngine.MissileStrikeFailure) -> String {
        switch failure {
        case .invalidMissileCount:
            return "至少选择 1 枚导弹"
        case .missingOrigin:
            return "找不到发射星球"
        case .missingTarget:
            return "找不到目标"
        case .missingOriginOwner:
            return "发射星球没有归属"
        case .samePlanet:
            return "目标不能与发射星球相同"
        case .invalidTarget:
            return "目标必须是敌对殖民地"
        case .insufficientMissiles:
            return "星际导弹不足"
        case .noTargetDefenses:
            return "目标没有防御设施"
        }
    }

    private enum FleetLaunchValidationFailure {
        case saveUnavailable
        case missingOrigin
        case missingTarget
        case samePlanet
        case invalidMission
        case noShips
        case invalidCargo
        case insufficientShips
        case insufficientCargo
        case insufficientCargoCapacity
        case insufficientFuel
        case fleetSlotLimit
        case commanderUnavailable

        var description: String {
            switch self {
            case .saveUnavailable:
                return "自动存档载入失败，请先开始新游戏再派遣舰队"
            case .missingOrigin:
                return "请选择出发殖民地"
            case .missingTarget:
                return "请选择目标"
            case .samePlanet:
                return "目标不能与出发星球相同"
            case .invalidMission:
                return "所选舰船或目标无法执行该任务"
            case .noShips:
                return "至少选择 1 艘舰船"
            case .invalidCargo:
                return "货物数量不能为负"
            case .insufficientShips:
                return "舰船不足"
            case .insufficientCargo:
                return "装载资源不足"
            case .insufficientCargoCapacity:
                return "货舱容量不足"
            case .insufficientFuel:
                return "重氢燃料不足"
            case .fleetSlotLimit:
                return "舰队槽已满，请等待舰队返航或提升计算机技术"
            case .commanderUnavailable:
                return "指挥官正在执行任务或不存在"
            }
        }
    }

    private enum MissileStrikeValidationFailure {
        case saveUnavailable
        case missingOrigin
        case missingTarget
        case samePlanet
        case invalidTarget
        case invalidMissileCount
        case insufficientMissiles
        case noTargetDefenses

        var description: String {
            switch self {
            case .saveUnavailable:
                return "自动存档载入失败，请先开始新游戏再发射导弹"
            case .missingOrigin:
                return "请选择发射殖民地"
            case .missingTarget:
                return "请选择目标"
            case .samePlanet:
                return "目标不能与发射星球相同"
            case .invalidTarget:
                return "目标必须是已侦察的敌对殖民地"
            case .invalidMissileCount:
                return "至少选择 1 枚导弹"
            case .insufficientMissiles:
                return "星际导弹不足"
            case .noTargetDefenses:
                return "目标没有防御设施"
            }
        }
    }

    private func fleetLaunchValidationFailure(
        originID: PlanetID?,
        targetID: PlanetID?,
        mission: Fleet.Mission,
        ships: [ShipKind: Int],
        cargo: ResourceBundle,
        speedPercent: Double = 1,
        commanderID: CommanderID? = nil
    ) -> FleetLaunchValidationFailure? {
        guard canSave else {
            return .saveUnavailable
        }

        guard let origin = planet(for: originID), isPlayerOwned(origin) else {
            return .missingOrigin
        }

        guard planet(for: targetID) != nil else {
            return .missingTarget
        }

        guard originID != targetID else {
            return .samePlanet
        }

        let normalizedShips = normalizedShips(ships)
        guard !normalizedShips.isEmpty else {
            return .noShips
        }

        guard isMissionAvailable(mission, originID: originID, targetID: targetID, ships: normalizedShips) else {
            return .invalidMission
        }

        guard cargo.metal.isFinite,
              cargo.crystal.isFinite,
              cargo.deuterium.isFinite,
              cargo.metal >= 0,
              cargo.crystal >= 0,
              cargo.deuterium >= 0
        else {
            return .invalidCargo
        }

        guard normalizedShips.allSatisfy({ kind, quantity in
            (origin.shipInventory[kind] ?? 0) >= quantity
        }) else {
            return .insufficientShips
        }

        guard let playerFaction else {
            return .missingOrigin
        }
        let activeFleetCount = universe.fleets.filter { $0.ownerID == playerFaction.id && $0.phase != .completed }.count
        guard activeFleetCount < TechnologyEffects.maxFleetSlots(for: playerFaction.technology) else {
            return .fleetSlotLimit
        }

        guard commanderIsAvailableForLaunch(commanderID) else {
            return .commanderUnavailable
        }

        guard origin.resources.canAfford(cargo) else {
            return .insufficientCargo
        }

        guard cargo.totalAmountForDisplay <= fleetCargoCapacity(for: normalizedShips) else {
            return .insufficientCargoCapacity
        }

        guard canAffordFleetFuel(
            originID: originID,
            targetID: targetID,
            ships: normalizedShips,
            cargo: cargo,
            speedPercent: speedPercent,
            commanderID: commanderID
        ) else {
            return .insufficientFuel
        }

        return nil
    }

    private func missileStrikeValidationFailure(
        originID: PlanetID?,
        targetID: PlanetID?,
        missileCount: Int
    ) -> MissileStrikeValidationFailure? {
        guard canSave else {
            return .saveUnavailable
        }

        guard let origin = planet(for: originID), isPlayerOwned(origin) else {
            return .missingOrigin
        }

        guard let target = planet(for: targetID) else {
            return .missingTarget
        }

        guard originID != targetID else {
            return .samePlanet
        }

        guard isVisibleToPlayer(target), !isPlayerOwned(target), target.ownerID != nil else {
            return .invalidTarget
        }

        guard missileCount > 0 else {
            return .invalidMissileCount
        }

        guard interplanetaryMissileCount(on: origin.id) >= missileCount else {
            return .insufficientMissiles
        }

        guard target.defenseInventory.values.contains(where: { $0 > 0 }) else {
            return .noTargetDefenses
        }

        return nil
    }

    private func isPlayerOwned(_ planet: Planet) -> Bool {
        PlayerVisibilityEngine.isPlayerOwned(planet, in: universe)
    }

    private var playerExploredPlanetIDs: Set<PlanetID> {
        Set(
            StrategicEngine
                .explorationRecords(for: universe.playerFactionID, in: universe)
                .map(\.targetPlanetID)
        )
    }

    private func isVisibleToPlayer(_ planet: Planet) -> Bool {
        isPlayerOwned(planet) || playerExploredPlanetIDs.contains(planet.id)
    }

    private func fleetTargetSummary(for planet: Planet) -> FleetTargetSummary {
        let isPlayerOwned = isPlayerOwned(planet)
        let isVisible = isVisibleToPlayer(planet)
        let ownerName = isPlayerOwned
            ? (playerFaction?.name.displayName ?? "玩家")
            : isVisible ? planet.ownerID.map(factionName(for:)) ?? "中立" : "未侦察"

        return FleetTargetSummary(
            id: planet.id,
            displayName: isVisible ? planet.name.displayName : "未知区域",
            coordinateText: planet.coordinate.displayText,
            ownerName: ownerName,
            isPlayerOwned: isPlayerOwned,
            isVisible: isVisible,
            debrisTotal: isVisible ? planet.debrisField.totalAmountForDisplay : 0
        )
    }

    private func defaultShips(for mission: Fleet.Mission, on origin: Planet) -> [ShipKind: Int] {
        FleetMissionPlannerEngine.recommendedShips(for: mission, on: origin)
    }

    private func defaultJumpGateShips(from origin: Planet) -> [ShipKind: Int] {
        let priorities: [ShipKind] = [.battlecruiser, .battleship, .cruiser, .heavyFighter, .lightFighter, .smallCargo, .largeCargo, .recycler]
        for kind in priorities {
            if (origin.shipInventory[kind] ?? 0) > 0 {
                return [kind: 1]
            }
        }
        return [:]
    }

    private func starMapMissionIsAllowed(_ mission: Fleet.Mission, for slot: SolarSystemSlotSummary) -> Bool {
        switch mission {
        case .colonize:
            return slot.planetID == nil &&
                !slot.isExpedition &&
                UniverseTopologyEngine.isValidPlanetCoordinate(slot.coordinate)
        case .explore:
            return slot.isExpedition || !slot.isPlayerOwned
        case .espionage:
            return slot.planetID != nil && slot.isVisible && !slot.isPlayerOwned && slot.ownerKind != nil
        case .recycle:
            return slot.planetID != nil && slot.isVisible && slot.debrisTotal > 0
        case .attack:
            return slot.planetID != nil && slot.isVisible && !slot.isPlayerOwned && slot.ownerKind != nil
        case .defend:
            return slot.planetID != nil && slot.isVisible && slot.isPlayerOwned
        case .transport, .returning:
            return false
        }
    }

    private func ensureStarMapFleetTarget(for slot: SolarSystemSlotSummary) -> PlanetID? {
        if let planetID = slot.planetID {
            return planetID
        }
        if let existing = universe.planets.first(where: { $0.coordinate == slot.coordinate }) {
            return existing.id
        }

        if UniverseTopologyEngine.isValidPlanetCoordinate(slot.coordinate) {
            return ColonizationTargetEngine.ensureNeutralTarget(
                at: slot.coordinate,
                visibleTo: universe.playerFactionID,
                in: &universe
            )
        }

        guard UniverseTopologyEngine.isExpeditionCoordinate(slot.coordinate) else {
            return nil
        }

        let profile = UniverseTopologyEngine.planetProfile(for: slot.coordinate, universeSeed: universe.seed)
        let planetID = PlanetID(Self.stablePlaceholderUUID(payload: "star-map-target|\(universe.id.rawValue.uuidString)|\(slot.coordinate.displayText)"))
        let displayName = slot.isExpedition ? "外太空 \(slot.coordinate.displayText)" : "未占领 \(slot.coordinate.displayText)"
        let planet = Planet(
            id: planetID,
            name: displayName,
            coordinate: slot.coordinate,
            ownerID: nil,
            resources: slot.isExpedition ? .zero : ResourceBundle(metal: 120, crystal: 60, deuterium: 20),
            temperatureCelsius: profile.temperatureCelsius,
            debrisField: .zero,
            maxFields: slot.isExpedition ? 1 : profile.maxFields
        )
        universe.planets.append(planet)
        universe.explorationRecords.append(
            ExplorationRecord(
                factionID: universe.playerFactionID,
                targetPlanetID: planetID,
                exploredAt: universe.gameTime,
                discoveredResources: planet.resources,
                discoveredDebris: planet.debrisField,
                discoveredOwnerID: nil,
                discoveredNeutral: !slot.isExpedition
            )
        )
        return planetID
    }

    private func factionName(for factionID: FactionID) -> String {
        universe.factions.first { $0.id == factionID }?.name.displayName ?? "未知势力"
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

        return lhs.name < rhs.name
    }

    private static func fleet(_ fleet: Fleet, touches planetID: PlanetID) -> Bool {
        fleet.originPlanetID == planetID || fleet.targetPlanetID == planetID
    }

    private func fleetNextTime(_ fleet: Fleet) -> TimeInterval {
        switch fleet.phase {
        case .outbound, .holding:
            return fleet.arrivalTime
        case .returning, .completed:
            return fleet.returnTime
        }
    }

    private var nextSimulationEvent: UpcomingSimulationEvent? {
        var events: [UpcomingSimulationEvent] = []

        for planet in playerPlanets {
            for item in planet.buildQueue {
                events.append(
                    UpcomingSimulationEvent(
                        time: item.finishTime,
                        title: "\(planet.name.displayName) \(item.buildingKind.localizedName)完成"
                    )
                )
            }

            for item in planet.shipBuildQueue {
                events.append(
                    UpcomingSimulationEvent(
                        time: item.finishTime,
                        title: "\(planet.name.displayName) \(unitQueueTitle(item))完成"
                    )
                )
            }

            for item in planet.defenseBuildQueue {
                events.append(
                    UpcomingSimulationEvent(
                        time: item.finishTime,
                        title: "\(planet.name.displayName) \(unitQueueTitle(item))完成"
                    )
                )
            }
        }

        if let playerFaction {
            for item in playerFaction.researchQueue {
                events.append(
                    UpcomingSimulationEvent(
                        time: item.finishTime,
                        title: "\(item.technologyKind.localizedName)研究完成"
                    )
                )
            }
        }

        for fleet in activeFleets where fleet.ownerID == universe.playerFactionID {
            events.append(
                UpcomingSimulationEvent(
                    time: fleetNextTime(fleet),
                    title: "\(fleet.mission.localizedName)舰队\(fleet.phase == .returning ? "返航" : "抵达")"
                )
            )
        }

        return events
            .filter { $0.time.isFinite && $0.time >= universe.gameTime }
            .min { lhs, rhs in lhs.time < rhs.time }
    }

    private func normalizedShips(_ ships: [ShipKind: Int]) -> [ShipKind: Int] {
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

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else {
            return "未知"
        }

        let clampedSeconds = max(0, seconds)
        if let formatted = durationFormatter.string(from: clampedSeconds) {
            return formatted
        }

        return formattedWholeSeconds(clampedSeconds)
    }

    private static func formattedWholeNumber(_ value: Double) -> String {
        guard value.isFinite else {
            return "未知"
        }

        return value.formatted(.number.precision(.fractionLength(0)))
    }

    private static func formattedSignedWholeNumber(_ value: Double) -> String {
        guard value.isFinite else {
            return "未知"
        }

        let formatted = formattedWholeNumber(abs(value))
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    private static func formattedPercent(_ value: Double) -> String {
        guard value.isFinite else {
            return "未知"
        }

        return value.formatted(.percent.precision(.fractionLength(0)))
    }

    private static func commanderRarityText(_ rarity: CommanderRarity) -> String {
        switch rarity {
        case .common:
            return "普通"
        case .elite:
            return "精英"
        case .epic:
            return "史诗"
        case .legendary:
            return "传奇"
        }
    }

    private static func commanderSpecialtyText(_ specialty: CommanderSpecialty) -> String {
        switch specialty {
        case .fleetAdmiral:
            return "舰队"
        case .engineer:
            return "工程"
        case .geologist:
            return "采掠"
        case .technocrat:
            return "科技"
        case .explorer:
            return "远征"
        }
    }

    private static func stablePlaceholderUUID(payload: String) -> UUID {
        let hash = stableHash("app-placeholder|\(payload)")
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

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()
}

struct StarMapPlanetSection: Identifiable {
    enum Kind: String, CaseIterable {
        case player
        case ai
        case neutral
        case unknown

        var title: String {
            switch self {
            case .player:
                return "我的星球"
            case .ai:
                return "AI 星球"
            case .neutral:
                return "中立星系"
            case .unknown:
                return "未知区域"
            }
        }

        var systemImage: String {
            switch self {
            case .player:
                return "house.and.flag"
            case .ai:
                return "cpu"
            case .neutral:
                return "circle.dashed"
            case .unknown:
                return "questionmark.circle"
            }
        }
    }

    let kind: Kind
    let planets: [StarMapPlanetSummary]

    var id: Kind { kind }
}

extension GameSettings.OfflineIntensity {
    var displayName: String {
        localizedName
    }
}

extension GameSettings.Difficulty {
    var displayName: String {
        localizedName
    }

    var behaviorDescription: String {
        switch self {
        case .easy:
            return "AI 会先侦察再攻击，并用更多防御回应威胁。"
        case .standard:
            return "AI 会平衡侦察、扩张、攻击和防御反应。"
        case .hard:
            return "AI 会更积极利用排名和关系压力，但不会读取隐藏库存。"
        }
    }
}

struct StarMapPlanetSummary: Identifiable {
    let planet: Planet
    let displayName: String
    let ownerName: String
    let ownerKind: Faction.Kind?
    let isPlayerOwned: Bool
    let isExploredByPlayer: Bool
    let isVisible: Bool
    let hasMoon: Bool
    let debrisTotal: Double
    let friendlyFleetCount: Int
    let otherFleetCount: Int

    var id: PlanetID { planet.id }
}

struct SolarSystemSlotSummary: Identifiable {
    let position: Int
    let coordinate: Coordinate
    let planetID: PlanetID?
    let displayName: String
    let ownerName: String
    let ownerKind: Faction.Kind?
    let isPlayerOwned: Bool
    let isVisible: Bool
    let isExpedition: Bool
    let hasMoon: Bool
    let debrisTotal: Double

    var id: Int { position }
}

struct MoonScanSummary: Identifiable {
    let fleetID: FleetID
    let targetName: String
    let missionText: String
    let phaseText: String
    let routeText: String
    let remainingText: String
    let interceptText: String
    let tacticalText: String

    var id: FleetID { fleetID }
}

struct MoonJumpTargetSummary: Identifiable {
    let planetID: PlanetID
    let displayName: String
    let coordinateText: String
    let readyText: String

    var id: PlanetID { planetID }
}

struct FleetTargetSummary: Identifiable {
    let id: PlanetID
    let displayName: String
    let coordinateText: String
    let ownerName: String
    let isPlayerOwned: Bool
    let isVisible: Bool
    let debrisTotal: Double

    var pickerTitle: String {
        "\(displayName) \(coordinateText)"
    }

    var detailText: String {
        isVisible ? ownerName : "未侦察"
    }
}

struct VictoryBannerSummary {
    let title: String
    let detail: String
    let isComplete: Bool
}

enum BriefingUrgency {
    case info
    case good
    case warning
}

struct CommanderBriefingItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let urgency: BriefingUrgency

    init(title: String, detail: String, systemImage: String, urgency: BriefingUrgency) {
        self.id = "\(title)-\(detail)-\(systemImage)"
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.urgency = urgency
    }
}

struct CommanderRecruitmentPreview {
    let tickets: Int
    let trainingData: Int
    let ownedCount: Int
    let totalPulls: Int
    let legendaryPityText: String
    let eliteGuaranteeText: String
}

struct CommanderSummary: Identifiable {
    let id: CommanderID
    let definitionID: String
    let name: String
    let title: String
    let rarity: CommanderRarity
    let rarityText: String
    let specialtyText: String
    let level: Int
    let levelCap: Int
    let experienceProgress: Double
    let experienceText: String
    let stars: Int
    let shards: Int
    let nextStarCost: Int?
    let canTrain: Bool
    let canPromote: Bool
    let bonusText: String
    let lore: String
    let isAssigned: Bool
    let assignmentText: String

    var pickerTitle: String {
        "\(name) Lv.\(level) · \(bonusText)"
    }

    var starText: String {
        stars > 0 ? "\(stars) 星" : "未升星"
    }
}

struct VictorySettlementSummary {
    let title: String
    let detail: String
    let routeText: String
    let timeText: String
    let isPlayerVictory: Bool
}

struct VictoryProgressSummary: Identifiable {
    let factionID: FactionID
    let factionName: String
    let isPlayer: Bool
    let route: VictoryRoute
    let currentValue: Double
    let targetValue: Double
    let progress: Double

    var id: String {
        "\(factionID.rawValue.uuidString)-\(route.rawValue)"
    }
}

struct FactionRelationSummary: Identifiable {
    let factionID: FactionID
    let factionName: String
    let kind: Faction.Kind
    let strategy: Faction.Strategy
    let posture: RelationPosture
    let threatScore: Int
    let attackCount: Int
    let lastInteractionTime: TimeInterval
    let summary: String
    let perspective: String

    var id: FactionID { factionID }
}

struct ExplorationSummary: Identifiable {
    let planet: Planet
    let exploredAt: TimeInterval
    let ownerName: String
    let reward: ResourceBundle
    let discoveredResources: ResourceBundle
    let discoveredDebris: ResourceBundle
    let discoveredNeutral: Bool

    var id: String {
        "\(planet.id.rawValue.uuidString)-\(exploredAt)"
    }
}

private struct UpcomingSimulationEvent {
    let time: TimeInterval
    let title: String
}

private extension RelationPosture {
    var severity: Int {
        switch self {
        case .neutral:
            return 0
        case .wary:
            return 1
        case .pressured:
            return 2
        case .hostile:
            return 3
        }
    }
}

private extension ResourceBundle {
    var totalAmountForDisplay: Double {
        guard metal.isFinite, crystal.isFinite, deuterium.isFinite else {
            return .infinity
        }

        return metal + crystal + deuterium
    }
}
