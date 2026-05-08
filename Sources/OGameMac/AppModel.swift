import Combine
import Foundation
import OGameCore
import OGamePersistence

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var universe: Universe
    @Published var statusMessage: String
    @Published private(set) var canSave: Bool
    @Published private(set) var offlineSummary: OfflineCatchUpSummary? = nil
    @Published private(set) var hasPendingOfflineCatchUpSave = false
    @Published var settings: GameSettings
    @Published private(set) var saveSlots: [JSONSaveRepository.SaveSlot] = []
    @Published private(set) var isOnboardingVisible: Bool

    private let repository: JSONSaveRepository
    private let currentDate: () -> Date

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
        guard let playerFaction else {
            return []
        }

        return universe.planets.filter { planet in
            playerFaction.ownedPlanetIDs.contains(planet.id)
        }
    }

    var availableBuildingKinds: [BuildingKind] {
        BuildingKind.allCases.filter { kind in
            universe.ruleSet.buildingRules[kind] != nil
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
        [.transport, .attack, .espionage, .recycle, .colonize, .explore]
    }

    var activeFleets: [Fleet] {
        universe.fleets.sorted { lhs, rhs in
            fleetNextTime(lhs) < fleetNextTime(rhs)
        }
    }

    var starMapSections: [StarMapPlanetSection] {
        let factionNamesByID = Dictionary(uniqueKeysWithValues: universe.factions.map { ($0.id, $0.name) })
        let factionKindsByID = Dictionary(uniqueKeysWithValues: universe.factions.map { ($0.id, $0.kind) })
        let playerOwnedPlanetIDs = Set(playerFaction?.ownedPlanetIDs ?? [])
        let exploredPlanetIDs = playerExploredPlanetIDs

        let summaries = universe.planets
            .sorted(by: Self.sortPlanetsByCoordinate)
            .map { planet in
                let isPlayerOwned = planet.ownerID == universe.playerFactionID || playerOwnedPlanetIDs.contains(planet.id)
                let isExploredByPlayer = exploredPlanetIDs.contains(planet.id)
                let isVisible = isPlayerOwned || isExploredByPlayer
                let touchingFleets = isVisible ? universe.fleets.filter { fleet in
                    fleet.phase != .completed && Self.fleet(fleet, touches: planet.id)
                } : []
                let friendlyFleetCount = touchingFleets.filter { $0.ownerID == universe.playerFactionID }.count
                let otherFleetCount = touchingFleets.count - friendlyFleetCount
                let ownerName = isPlayerOwned
                    ? (playerFaction?.name ?? "玩家")
                    : isVisible ? planet.ownerID.flatMap { factionNamesByID[$0] } ?? "中立" : "未知"
                let ownerKind = isPlayerOwned
                    ? Faction.Kind.player
                    : isVisible ? planet.ownerID.flatMap { factionKindsByID[$0] } : nil

                return StarMapPlanetSummary(
                    planet: planet,
                    displayName: isVisible ? planet.name : "未知区域",
                    ownerName: ownerName,
                    ownerKind: ownerKind,
                    isPlayerOwned: isPlayerOwned,
                    isExploredByPlayer: isExploredByPlayer,
                    isVisible: isVisible,
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
                    factionName: faction.name,
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

    var advanceActionTitle: String {
        "推进 \(Self.formattedDuration(advanceDelta))"
    }

    var settingsStatusText: String {
        "速度 \(settings.gameSpeed.formatted(.number.precision(.fractionLength(2))))x - 离线 \(settings.offlineIntensity.displayName) - \(settings.difficulty.displayName)"
    }

    var autosaveStatusText: String {
        settings.isAutosaveEnabled ? "自动保存开启" : "自动保存关闭"
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
        let targetLevel = planet?.buildQueue.first { $0.buildingKind == kind }?.targetLevel
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

        let targetLevel = playerFaction?.researchQueue.first { $0.technologyKind == technology }?.targetLevel
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
        let status = "已在\(planet?.name ?? "殖民地")加入 \(quantity) 架\(kind.localizedName)。"
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
        let status = "已在\(planet?.name ?? "殖民地")加入 \(quantity) 个\(kind.localizedName)。"
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
        let status = "已在\(planet?.name ?? "殖民地")加入 \(quantity) 枚\(kind.localizedName)。"
        autosaveAfterQueueing(successStatus: status)
    }

    func launchFleet(
        originID: PlanetID?,
        targetID: PlanetID?,
        mission: Fleet.Mission,
        ships: [ShipKind: Int],
        cargo: ResourceBundle
    ) {
        if let validationFailure = fleetLaunchValidationFailure(
            originID: originID,
            targetID: targetID,
            mission: mission,
            ships: ships,
            cargo: cargo
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
            cargo: cargo
        )

        switch result {
        case .launched(let fleet):
            autosaveAfterQueueing(successStatus: fleetLaunchStatus(for: fleet))
        case .failure(let failure):
            statusMessage = "无法派遣舰队：\(Self.fleetFailureDescription(failure))。"
        }
    }

    func productionPerHour(for planet: Planet) -> ResourceBundle {
        EconomyEngine.productionPerHour(for: planet, ruleSet: universe.ruleSet)
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
        EconomyEngine.recomputeEnergy(for: &universe.planets[planetIndex], ruleSet: universe.ruleSet)
        statusMessage = "\(kind.localizedName)产能已设为 \(Self.formattedPercent(clampedValue))。保存后保留设置。"
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
            return "产出 \(produced) - 空闲"
        }

        return "供能 \(Self.formattedPercent(energySupplyRatio(for: planet))) - \(produced)/\(used) - \(available)"
    }

    func buildingLevel(for kind: BuildingKind, on planet: Planet) -> Int {
        max(planet.buildingLevels[kind] ?? 0, 0)
    }

    func nextBuildingLevel(for kind: BuildingKind, on planet: Planet) -> Int {
        let level = buildingLevel(for: kind, on: planet)
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

        guard planet.buildQueue.isEmpty else {
            return "建造队列忙碌"
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
        let level = researchLevel(for: technology)
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

        guard playerFaction?.researchQueue.isEmpty == true else {
            return "研究队列忙碌"
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

        guard planet.shipBuildQueue.isEmpty else {
            return "造船厂队列忙碌"
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

        guard planet.defenseBuildQueue.isEmpty else {
            return "防御队列忙碌"
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

        guard planet.defenseBuildQueue.isEmpty else {
            return "防御队列忙碌"
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
        case .attack, .espionage:
            return targetIsVisible && !targetIsPlayerOwned && target.ownerID != nil
        case .explore:
            return origin.id != target.id && !targetIsPlayerOwned
        case .recycle:
            return targetIsVisible &&
                (normalizedShips[.recycler] ?? 0) > 0 &&
                target.debrisField.totalAmountForDisplay > 0
        case .colonize:
            return targetIsVisible && target.ownerID == nil && (normalizedShips[.colonyShip] ?? 0) > 0
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
        cargo: ResourceBundle
    ) -> Bool {
        fleetLaunchValidationFailure(
            originID: originID,
            targetID: targetID,
            mission: mission,
            ships: ships,
            cargo: cargo
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

    func fleetFuelCost(originID: PlanetID?, targetID: PlanetID?, ships: [ShipKind: Int]) -> Double? {
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
            ruleSet: universe.ruleSet
        )
        return fuel.isFinite ? fuel : nil
    }

    func canAffordFleetFuel(originID: PlanetID?, targetID: PlanetID?, ships: [ShipKind: Int], cargo: ResourceBundle) -> Bool {
        guard
            let origin = planet(for: originID),
            let fuel = fleetFuelCost(originID: originID, targetID: targetID, ships: ships),
            fuel >= 0
        else {
            return false
        }

        let resourcesAfterCargo = origin.resources.subtracting(cargo)
        return resourcesAfterCargo.canAfford(ResourceBundle(deuterium: fuel))
    }

    func fleetFuelStatusText(originID: PlanetID?, targetID: PlanetID?, ships: [ShipKind: Int], cargo: ResourceBundle) -> String {
        guard let fuel = fleetFuelCost(originID: originID, targetID: targetID, ships: ships) else {
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

    func fleetTravelDuration(originID: PlanetID?, targetID: PlanetID?, ships: [ShipKind: Int]) -> TimeInterval? {
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
            ruleSet: universe.ruleSet
        )
        return duration.isFinite && duration > 0 ? duration : nil
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
        return "战利品 \(loot) - 残骸 \(debris) - 损失 \(losses)"
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

    func advanceOneMinute() {
        guard canSave else {
            statusMessage = "自动存档载入失败。请先开始新游戏再推进或保存。"
            return
        }

        SimulationEngine.tick(universe: &universe, delta: advanceDelta, aiDifficulty: settings.difficulty)
        refreshStrategicState()
        statusMessage = "以 \(settings.gameSpeed.formatted(.number.precision(.fractionLength(2))))x 速度推进 \(Self.formattedDuration(advanceDelta))，当前 T+\(Self.formattedWholeSeconds(universe.gameTime))。"
    }

    func save() {
        guard canSave else {
            statusMessage = "自动存档载入失败，保存已禁用。请先开始新游戏。"
            return
        }

        do {
            refreshStrategicState()
            let savedPendingOfflineCatchUp = hasPendingOfflineCatchUpSave
            try repository.save(universe, wallClockDate: currentDate(), settings: settings)
            hasPendingOfflineCatchUpSave = false
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
        statusMessage = "游戏速度已设为 \(settings.gameSpeed.formatted(.number.precision(.fractionLength(2))))x。手动推进会使用该速度。"
    }

    func updateOfflineIntensity(_ offlineIntensity: GameSettings.OfflineIntensity) {
        settings.offlineIntensity = offlineIntensity
        statusMessage = "离线模拟已设为\(offlineIntensity.displayName)。保存后保留设置。"
    }

    func updateAutosaveEnabled(_ isEnabled: Bool) {
        settings.isAutosaveEnabled = isEnabled
        statusMessage = isEnabled
            ? "队列和舰队操作将自动保存。"
            : "自动保存已关闭，队列和舰队操作需手动保存。"
    }

    func updateDifficulty(_ difficulty: GameSettings.Difficulty) {
        settings.difficulty = difficulty
        statusMessage = "难度已设为\(difficulty.displayName)。\(difficulty.behaviorDescription)"
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

    private var advanceDelta: TimeInterval {
        60 * GameSettings.clampedGameSpeed(settings.gameSpeed)
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
            try repository.save(universe, wallClockDate: currentDate(), settings: settings)
            refreshSaveSlots()
            statusMessage = "\(successStatus) 已自动保存。"
        } catch {
            statusMessage = "\(successStatus) 自动保存失败：\(error.localizedDescription)"
        }
    }

    private func refreshStrategicState() {
        StrategicEngine.updateStrategicState(in: &universe)
    }

    private static func refreshedStrategicUniverse(_ universe: Universe) -> Universe {
        var refreshed = universe
        StrategicEngine.updateStrategicState(in: &refreshed)
        return refreshed
    }

    private func faction(with factionID: FactionID?) -> Faction? {
        guard let factionID else {
            return nil
        }

        return universe.factions.first { $0.id == factionID }
    }

    private func buildingUpgradeTerms(for planet: Planet, kind: BuildingKind) -> (cost: ResourceBundle, duration: TimeInterval)? {
        guard let rule = universe.ruleSet.buildingRules[kind] else {
            return nil
        }

        let currentLevel = buildingLevel(for: kind, on: planet)
        guard currentLevel < Int.max else {
            return nil
        }

        return Self.terms(
            baseCost: rule.baseCost,
            costMultiplier: rule.costMultiplier,
            baseDuration: rule.baseDuration,
            durationMultiplier: rule.durationMultiplier,
            targetLevel: currentLevel + 1,
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

        let currentLevel = researchLevel(for: technology)
        guard currentLevel < Int.max else {
            return nil
        }

        return Self.terms(
            baseCost: rule.baseCost,
            costMultiplier: rule.costMultiplier,
            baseDuration: rule.baseDuration,
            durationMultiplier: rule.durationMultiplier,
            targetLevel: currentLevel + 1
        )
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
        let location = planetName.map { "（\($0)）" } ?? ""
        return "已加入\(kind.localizedName)\(levelText)\(location)。"
    }

    private static func researchQueuedStatus(technology: TechnologyKind, targetLevel: Int?) -> String {
        let levelText = targetLevel.map { "等级 \($0)" } ?? ""
        return "已加入\(technology.localizedName)\(levelText)。"
    }

    private func fleetLaunchStatus(for fleet: Fleet) -> String {
        "已派遣\(fleet.mission.localizedName)舰队前往 \(fleet.target.displayText)。"
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
            return "队列忙碌"
        case .missingRule:
            return "规则缺失或无效"
        case .missingRequirement(let requirement):
            return requirement.lockedReason
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
        cargo: ResourceBundle
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

        guard origin.resources.canAfford(cargo) else {
            return .insufficientCargo
        }

        guard cargo.totalAmountForDisplay <= fleetCargoCapacity(for: normalizedShips) else {
            return .insufficientCargoCapacity
        }

        guard canAffordFleetFuel(originID: originID, targetID: targetID, ships: normalizedShips, cargo: cargo) else {
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
        planet.ownerID == universe.playerFactionID ||
            playerFaction?.ownedPlanetIDs.contains(planet.id) == true
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
            ? (playerFaction?.name ?? "玩家")
            : isVisible ? planet.ownerID.map(factionName(for:)) ?? "中立" : "未侦察"

        return FleetTargetSummary(
            id: planet.id,
            displayName: isVisible ? planet.name : "未知区域",
            coordinateText: planet.coordinate.displayText,
            ownerName: ownerName,
            isPlayerOwned: isPlayerOwned,
            isVisible: isVisible,
            debrisTotal: isVisible ? planet.debrisField.totalAmountForDisplay : 0
        )
    }

    private func factionName(for factionID: FactionID) -> String {
        universe.factions.first { $0.id == factionID }?.name ?? "未知势力"
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
    let debrisTotal: Double
    let friendlyFleetCount: Int
    let otherFleetCount: Int

    var id: PlanetID { planet.id }
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
