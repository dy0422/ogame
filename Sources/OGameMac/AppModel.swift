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
            universe = catchUpResult.universe
            offlineSummary = catchUpResult.summary.didMutate ? catchUpResult.summary : nil
            hasPendingOfflineCatchUpSave = catchUpResult.summary.didMutate
            canSave = true

            if catchUpResult.summary.didMutate {
                statusMessage = Self.offlineCatchUpPendingStatus(for: catchUpResult.summary)
            } else {
                statusMessage = "Loaded save from \(envelope.lastSavedAt.formatted(date: .abbreviated, time: .shortened))."
            }
        } catch JSONSaveRepository.RepositoryError.missingSave {
            universe = StarterUniverseFactory.makeNewGame(seed: 1, playerName: "Commander")
            offlineSummary = nil
            hasPendingOfflineCatchUpSave = false
            statusMessage = "New fast skirmish initialized."
            canSave = true
        } catch {
            universe = StarterUniverseFactory.makeNewGame(seed: 1, playerName: "Commander")
            offlineSummary = nil
            hasPendingOfflineCatchUpSave = false
            statusMessage = Self.loadFailureStatus(for: error)
            canSave = false
        }
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

    var offlineSummaryText: String? {
        guard let offlineSummary else {
            return nil
        }

        return Self.offlineSummaryDetail(
            for: offlineSummary,
            hasPendingSave: hasPendingOfflineCatchUpSave
        )
    }

    func startBuildingUpgrade(planetID: PlanetID, kind: BuildingKind) {
        guard canSave else {
            statusMessage = "Loading autosave failed. Start a new game before queueing construction."
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
            statusMessage = "Loading autosave failed. Start a new game before queueing research."
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

    func productionPerHour(for planet: Planet) -> ResourceBundle {
        EconomyEngine.productionPerHour(for: planet, ruleSet: universe.ruleSet)
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
            return "\(produced) produced - idle"
        }

        return "\(Self.formattedPercent(energySupplyRatio(for: planet))) supply - \(produced)/\(used) - \(available)"
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
        guard
            canSave,
            planet.buildQueue.isEmpty,
            let cost = buildingUpgradeCost(for: planet, kind: kind)
        else {
            return false
        }

        return planet.resources.canAfford(cost)
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
        guard
            canSave,
            playerFaction?.researchQueue.isEmpty == true
        else {
            return false
        }

        return canAffordResearch(technology)
    }

    func queueRemainingText(until finishTime: TimeInterval) -> String {
        guard finishTime.isFinite, universe.gameTime.isFinite else {
            return "unknown remaining"
        }

        let remaining = max(0, finishTime - universe.gameTime)
        guard remaining > 0 else {
            return "ready"
        }

        return "\(Self.formattedDuration(remaining)) remaining"
    }

    func durationText(_ duration: TimeInterval?) -> String {
        guard let duration, duration.isFinite else {
            return "unknown"
        }

        return Self.formattedDuration(duration)
    }

    func buildQueueStatus(_ item: BuildQueueItem) -> String {
        "\(item.buildingKind.rawValue.displayName) level \(item.targetLevel) - \(queueRemainingText(until: item.finishTime))"
    }

    func researchQueueStatus(_ item: ResearchQueueItem) -> String {
        "\(item.technologyKind.rawValue.displayName) level \(item.targetLevel) - \(queueRemainingText(until: item.finishTime))"
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
            statusMessage = "Loading autosave failed. Start a new game before advancing or saving."
            return
        }

        SimulationEngine.tick(universe: &universe, delta: 60)
        statusMessage = "Advanced to T+\(Self.formattedWholeSeconds(universe.gameTime))."
    }

    func save() {
        guard canSave else {
            statusMessage = "Save is disabled because autosave loading failed. Start a new game before saving."
            return
        }

        do {
            let savedPendingOfflineCatchUp = hasPendingOfflineCatchUpSave
            try repository.save(universe, wallClockDate: currentDate())
            hasPendingOfflineCatchUpSave = false
            statusMessage = savedPendingOfflineCatchUp
                ? "Saved universe. Offline progress is now saved."
                : "Saved universe."
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func startNewGame() {
        universe = StarterUniverseFactory.makeNewGame(seed: 1, playerName: "Commander")
        offlineSummary = nil
        hasPendingOfflineCatchUpSave = false
        canSave = true
        statusMessage = "New game started. Saving will replace the current autosave."
    }

    private static func loadFailureStatus(for error: Error) -> String {
        "Loading autosave failed: \(loadFailureDescription(for: error)). Saving is disabled to protect the existing file."
    }

    private static func loadFailureDescription(for error: Error) -> String {
        if case JSONSaveRepository.RepositoryError.unsupportedSchema(let schemaVersion) = error {
            return "unsupported save schema \(schemaVersion)"
        }

        if case JSONSaveRepository.RepositoryError.invalidFileName(let fileName) = error {
            return "invalid save file name '\(fileName)'"
        }

        return error.localizedDescription
    }

    private static func formattedWholeSeconds(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else {
            return "unknown time"
        }

        return seconds.formatted(.number.precision(.fractionLength(0))) + " seconds"
    }

    private static func offlineCatchUpPendingStatus(for summary: OfflineCatchUpSummary) -> String {
        "Caught up \(formattedDuration(summary.elapsedSeconds)) offline. Progress is applied but not saved yet."
    }

    private static func offlineSummaryDetail(
        for summary: OfflineCatchUpSummary,
        hasPendingSave: Bool
    ) -> String {
        let constructionText = itemCountText(summary.completedConstructionCount, singular: "construction")
        let researchText = itemCountText(summary.completedResearchCount, singular: "research")
        let saveText = hasPendingSave ? "Pending save." : "Saved."
        return "Processed \(summary.processedChunks) chunks; completed \(constructionText) and \(researchText). \(saveText)"
    }

    private static func itemCountText(_ count: Int, singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)"
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
        if hasPendingOfflineCatchUpSave {
            statusMessage = "\(successStatus) Offline progress and this action are pending save."
            return
        }

        do {
            try repository.save(universe, wallClockDate: currentDate())
            statusMessage = "\(successStatus) Autosaved."
        } catch {
            statusMessage = "\(successStatus) Autosave failed: \(error.localizedDescription)"
        }
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
            targetLevel: currentLevel + 1
        )
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
        targetLevel: Int
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
        let duration = baseDuration * durationScale
        guard isValidCost(cost), duration.isFinite, duration > 0 else {
            return nil
        }

        return (cost, duration)
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
        let levelText = targetLevel.map { " level \($0)" } ?? ""
        let location = planetName.map { " on \($0)" } ?? ""
        return "Queued \(kind.rawValue.displayName)\(levelText)\(location)."
    }

    private static func researchQueuedStatus(technology: TechnologyKind, targetLevel: Int?) -> String {
        let levelText = targetLevel.map { " level \($0)" } ?? ""
        return "Queued \(technology.rawValue.displayName)\(levelText)."
    }

    private static func buildingQueueFailureStatus(_ result: QueueResult, kind: BuildingKind) -> String {
        "Could not queue \(kind.rawValue.displayName): \(queueFailureDescription(result))."
    }

    private static func researchQueueFailureStatus(_ result: QueueResult, technology: TechnologyKind) -> String {
        "Could not queue \(technology.rawValue.displayName): \(queueFailureDescription(result))."
    }

    private static func queueFailureDescription(_ result: QueueResult) -> String {
        switch result {
        case .queued:
            return "already queued"
        case .insufficientResources:
            return "insufficient resources"
        case .missingPlanet:
            return "missing colony"
        case .missingFaction:
            return "missing faction"
        case .queueBusy:
            return "queue busy"
        case .missingRule:
            return "missing or invalid economy rule"
        }
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else {
            return "unknown"
        }

        let clampedSeconds = max(0, seconds)
        if let formatted = durationFormatter.string(from: clampedSeconds) {
            return formatted
        }

        return formattedWholeSeconds(clampedSeconds)
    }

    private static func formattedWholeNumber(_ value: Double) -> String {
        guard value.isFinite else {
            return "unknown"
        }

        return value.formatted(.number.precision(.fractionLength(0)))
    }

    private static func formattedSignedWholeNumber(_ value: Double) -> String {
        guard value.isFinite else {
            return "unknown"
        }

        let formatted = formattedWholeNumber(abs(value))
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    private static func formattedPercent(_ value: Double) -> String {
        guard value.isFinite else {
            return "unknown"
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

private extension String {
    var displayName: String {
        reduce(into: "") { result, character in
            if character.isUppercase, !result.isEmpty {
                result.append(" ")
            }
            result.append(character)
        }
        .capitalized
    }
}
