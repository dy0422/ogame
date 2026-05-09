import Foundation

public enum CombatEngine {
    public enum MissileStrikeFailure: Equatable, Sendable {
        case invalidMissileCount
        case missingOrigin
        case missingTarget
        case missingOriginOwner
        case samePlanet
        case invalidTarget
        case insufficientMissiles
        case noTargetDefenses
    }

    public enum MissileStrikeResult: Equatable, Sendable {
        case resolved(Report)
        case failed(MissileStrikeFailure)
    }

    public static func resolveAttack(_ fleet: Fleet, in universe: inout Universe) -> Fleet? {
        var returningFleet = fleet
        returningFleet.phase = .returning

        guard let targetIndex = targetPlanetIndex(for: fleet, in: universe) else {
            return returningFleet
        }

        let attackerFaction = faction(for: fleet.ownerID, in: universe)
        let defenderFaction = universe.planets[targetIndex].ownerID.flatMap { faction(for: $0, in: universe) }
        let attackerTech = attackerFaction?.technology ?? ResearchState()
        let defenderTech = defenderFaction?.technology ?? ResearchState()
        let attackerBeforeShips = normalizedShips(fleet.ships)
        let defenderBeforeShips = normalizedShips(universe.planets[targetIndex].shipInventory)
        let defenderBeforeDefenses = normalizedDefenses(universe.planets[targetIndex].defenseInventory)
        guard hasRequiredRules(
            attackerShips: attackerBeforeShips,
            defenderShips: defenderBeforeShips,
            defenderDefenses: defenderBeforeDefenses,
            ruleSet: universe.ruleSet
        ) else {
            universe.reports.append(
                deferredBattleReport(
                    fleet: fleet,
                    universe: universe,
                    target: universe.planets[targetIndex],
                    attackerFaction: attackerFaction,
                    defenderFaction: defenderFaction,
                    attackerShips: attackerBeforeShips,
                    defenderShips: defenderBeforeShips,
                    defenderDefenses: defenderBeforeDefenses
                )
            )
            return returningFleet
        }

        let simulation = BattleSimulationEngine.resolve(
            BattleSimulationInput(
                attackerShips: attackerBeforeShips,
                defenderShips: defenderBeforeShips,
                defenderDefenses: defenderBeforeDefenses,
                attackerResearch: attackerTech,
                defenderResearch: defenderTech,
                ruleSet: universe.ruleSet,
                seed: stableHash(fleet.id.rawValue.uuidString)
            )
        )
        let attackerAfterShips = simulation.remainingAttackerShips
        let defenderAfterShips = simulation.remainingDefenderShips
        let destroyedDefenses = defenseDifference(before: defenderBeforeDefenses, after: simulation.remainingDefenderDefenses)
        let recoveredDefenses = recoveredDefenses(
            from: destroyedDefenses,
            universe: universe,
            fleet: fleet
        )
        let defenderAfterDefenses = defenseInventory(
            before: defenderBeforeDefenses,
            destroyed: destroyedDefenses,
            recovered: recoveredDefenses
        )
        let attackerLostShips = shipDifference(before: attackerBeforeShips, after: attackerAfterShips)
        let defenderLostShips = shipDifference(before: defenderBeforeShips, after: defenderAfterShips)
        let defenderLostDefenses = defenseDifference(before: defenderBeforeDefenses, after: defenderAfterDefenses)
        let attackerLosses = shipCost(attackerLostShips, ruleSet: universe.ruleSet)
        let defenderShipLosses = shipCost(defenderLostShips, ruleSet: universe.ruleSet)
        let defenderDefenseLosses = defenseCost(defenderLostDefenses, ruleSet: universe.ruleSet)
        let defenderLosses = safeAdding(defenderShipLosses, defenderDefenseLosses)
        let debris = debrisFromLosses(safeAdding(attackerLosses, defenderLosses))
        let attackerWon = simulation.attackerWon && !attackerAfterShips.isEmpty
        let protection = CombatProtectionEngine.evaluate(
            attackerID: fleet.ownerID,
            defenderID: universe.planets[targetIndex].ownerID,
            attackerFaction: attackerFaction,
            defenderFaction: defenderFaction,
            universe: universe
        )
        let survivingCapacity = cargoCapacity(for: attackerAfterShips, ruleSet: universe.ruleSet)
        let cappedExistingCargo = collectCargo(from: fleet.cargo, limit: survivingCapacity)
        let loot = attackerWon
            ? collectLoot(
                from: universe.planets[targetIndex].resources,
                limit: max(survivingCapacity - cappedExistingCargo.totalAmount, 0),
                fraction: protection.lootFraction
            )
            : .zero

        universe.planets[targetIndex].shipInventory = defenderAfterShips
        universe.planets[targetIndex].defenseInventory = defenderAfterDefenses
        universe.planets[targetIndex].resources = universe.planets[targetIndex].resources.subtracting(loot).nonnegative
        universe.planets[targetIndex].debrisField = safeAdding(universe.planets[targetIndex].debrisField, debris)

        returningFleet.ships = attackerAfterShips
        returningFleet.cargo = safeAdding(cappedExistingCargo, loot)

        let reportID = stableReportID(kind: .battle, universe: universe, fleet: fleet)
        let report = Report(
            id: reportID,
            time: fleet.arrivalTime,
            kind: .battle,
            title: "Battle at \(universe.planets[targetIndex].coordinate.displayText)",
            summary: battleSummary(
                attackerWon: attackerWon,
                protection: protection,
                debris: debris,
                moonChance: UniverseTopologyEngine.moonChancePercent(forDebris: debris),
                recoveredDefenses: recoveredDefenses
            ),
            participants: [
                ReportParticipant(
                    role: .attacker,
                    factionID: fleet.ownerID,
                    planetID: fleet.originPlanetID,
                    name: attackerFaction?.name ?? "Attacker",
                    beforeShips: attackerBeforeShips,
                    afterShips: attackerAfterShips,
                    losses: attackerLosses
                ),
                ReportParticipant(
                    role: .defender,
                    factionID: universe.planets[targetIndex].ownerID,
                    planetID: universe.planets[targetIndex].id,
                    name: defenderFaction?.name ?? universe.planets[targetIndex].name,
                    beforeShips: defenderBeforeShips,
                    afterShips: defenderAfterShips,
                    beforeDefenses: defenderBeforeDefenses,
                    afterDefenses: defenderAfterDefenses,
                    losses: defenderLosses
                )
            ],
            loot: loot,
            debris: debris,
            losses: safeAdding(attackerLosses, defenderLosses),
            battleRounds: simulation.rounds
        )
        universe.reports.append(report)
        createMoonIfEligible(
            targetIndex: targetIndex,
            reportID: reportID,
            battleTime: fleet.arrivalTime,
            debris: debris,
            universe: &universe
        )

        return attackerAfterShips.isEmpty ? nil : returningFleet
    }

    public static func resolveEspionage(_ fleet: Fleet, in universe: inout Universe) -> Fleet? {
        var returningFleet = fleet
        returningFleet.phase = .returning

        guard let targetIndex = targetPlanetIndex(for: fleet, in: universe) else {
            return returningFleet
        }

        let attackerFaction = faction(for: fleet.ownerID, in: universe)
        let defenderFaction = universe.planets[targetIndex].ownerID.flatMap { faction(for: $0, in: universe) }
        let attackerTech = attackerFaction?.technology ?? ResearchState()
        let defenderTech = defenderFaction?.technology ?? ResearchState()
        let target = universe.planets[targetIndex]
        let targetShips = normalizedShips(target.shipInventory)
        let targetDefenses = normalizedDefenses(target.defenseInventory)
        let defenderCombatUnitCount = targetShips.values.reduce(0) { $0 + max($1, 0) } +
            targetDefenses.values.reduce(0) { $0 + max($1, 0) }
        let intel = IntelEngine.resolveEspionage(
            fleet: fleet,
            attackerResearch: attackerTech,
            defenderResearch: defenderTech,
            defenderCombatUnitCount: defenderCombatUnitCount,
            universeSeed: universe.seed
        )
        let visibleShips = IntelEngine.maskedShips(targetShips, tier: intel.intelTier)
        let visibleDefenses = IntelEngine.maskedDefenses(targetDefenses, tier: intel.intelTier)
        let survivingProbeCount = max((returningFleet.ships[.espionageProbe] ?? 0) - intel.lostProbes, 0)
        returningFleet.ships[.espionageProbe] = survivingProbeCount > 0 ? survivingProbeCount : nil

        universe.reports.append(
            Report(
                id: stableReportID(kind: .espionage, universe: universe, fleet: fleet),
                time: fleet.arrivalTime,
                kind: .espionage,
                title: "Espionage at \(target.coordinate.displayText)",
                summary: espionageSummary(
                    resources: target.resources,
                    ships: visibleShips,
                    defenses: visibleDefenses,
                    intelTier: intel.intelTier,
                    lostProbes: intel.lostProbes
                ),
                participants: [
                    ReportParticipant(
                        role: .attacker,
                        factionID: fleet.ownerID,
                        planetID: fleet.originPlanetID,
                        name: attackerFaction?.name ?? "Observer",
                        beforeShips: normalizedShips(fleet.ships),
                        afterShips: normalizedShips(returningFleet.ships)
                    ),
                    ReportParticipant(
                        role: .defender,
                        factionID: target.ownerID,
                        planetID: target.id,
                        name: defenderFaction?.name ?? target.name,
                        beforeShips: visibleShips,
                        afterShips: visibleShips,
                        beforeDefenses: visibleDefenses,
                        afterDefenses: visibleDefenses
                    )
                ],
                intelTier: intel.intelTier
            )
        )

        return returningFleet.ships.isEmpty ? nil : returningFleet
    }

    public static func previewAttack(_ fleet: Fleet, in universe: Universe) -> BattleSimulationResult? {
        guard let targetIndex = targetPlanetIndex(for: fleet, in: universe) else {
            return nil
        }

        let attackerFaction = faction(for: fleet.ownerID, in: universe)
        let defenderFaction = universe.planets[targetIndex].ownerID.flatMap { faction(for: $0, in: universe) }
        let attackerShips = normalizedShips(fleet.ships)
        let defenderShips = normalizedShips(universe.planets[targetIndex].shipInventory)
        let defenderDefenses = normalizedDefenses(universe.planets[targetIndex].defenseInventory)

        return BattleSimulationEngine.resolve(
            BattleSimulationInput(
                attackerShips: attackerShips,
                defenderShips: defenderShips,
                defenderDefenses: defenderDefenses,
                attackerResearch: attackerFaction?.technology ?? ResearchState(),
                defenderResearch: defenderFaction?.technology ?? ResearchState(),
                ruleSet: universe.ruleSet,
                seed: stableHash(fleet.id.rawValue.uuidString)
            )
        )
    }

    public static func launchMissileStrike(
        from originPlanetID: PlanetID,
        to targetPlanetID: PlanetID,
        in universe: inout Universe,
        missileCount: Int
    ) -> MissileStrikeResult {
        guard missileCount > 0 else {
            return .failed(.invalidMissileCount)
        }
        guard let originIndex = universe.planets.firstIndex(where: { $0.id == originPlanetID }) else {
            return .failed(.missingOrigin)
        }
        guard let targetIndex = universe.planets.firstIndex(where: { $0.id == targetPlanetID }) else {
            return .failed(.missingTarget)
        }
        guard originPlanetID != targetPlanetID else {
            return .failed(.samePlanet)
        }
        guard let originOwnerID = universe.planets[originIndex].ownerID else {
            return .failed(.missingOriginOwner)
        }
        guard let targetOwnerID = universe.planets[targetIndex].ownerID,
              targetOwnerID != originOwnerID
        else {
            return .failed(.invalidTarget)
        }

        let availableMissiles = max(universe.planets[originIndex].missileInventory[.interplanetaryMissile] ?? 0, 0)
        guard availableMissiles >= missileCount else {
            return .failed(.insufficientMissiles)
        }

        let targetBeforeDefenses = normalizedDefenses(universe.planets[targetIndex].defenseInventory)
        guard !targetBeforeDefenses.isEmpty else {
            return .failed(.noTargetDefenses)
        }

        let originBefore = universe.planets[originIndex]
        let targetBefore = universe.planets[targetIndex]
        let availableInterceptors = max(targetBefore.missileInventory[.antiBallisticMissile] ?? 0, 0)
        let interceptedMissiles = min(missileCount, availableInterceptors)
        let effectiveMissileCount = max(missileCount - interceptedMissiles, 0)
        let destroyedDefenses = missileDestroyedDefenses(
            from: targetBeforeDefenses,
            missileCount: effectiveMissileCount
        )
        let targetAfterDefenses = defenseInventory(
            before: targetBeforeDefenses,
            destroyed: destroyedDefenses,
            recovered: [:]
        )
        let losses = defenseCost(destroyedDefenses, ruleSet: universe.ruleSet)
        let reportID = stableMissileReportID(
            originPlanetID: originPlanetID,
            targetPlanetID: targetPlanetID,
            missileCount: missileCount,
            universe: universe
        )
        let attackerFaction = originBefore.ownerID.flatMap { faction(for: $0, in: universe) }
        let defenderFaction = targetBefore.ownerID.flatMap { faction(for: $0, in: universe) }
        let report = Report(
            id: reportID,
            time: universe.gameTime,
            kind: .missile,
            title: "Missile strike at \(targetBefore.coordinate.displayText)",
            summary: missileStrikeSummary(
                destroyedDefenses: destroyedDefenses,
                interceptedMissiles: interceptedMissiles
            ),
            participants: [
                ReportParticipant(
                    role: .attacker,
                    factionID: originBefore.ownerID,
                    planetID: originBefore.id,
                    name: attackerFaction?.name ?? originBefore.name
                ),
                ReportParticipant(
                    role: .defender,
                    factionID: targetBefore.ownerID,
                    planetID: targetBefore.id,
                    name: defenderFaction?.name ?? targetBefore.name,
                    beforeDefenses: targetBeforeDefenses,
                    afterDefenses: targetAfterDefenses,
                    losses: losses
                )
            ],
            loot: .zero,
            debris: .zero,
            losses: losses
        )

        let remainingMissiles = availableMissiles - missileCount
        if remainingMissiles > 0 {
            universe.planets[originIndex].missileInventory[.interplanetaryMissile] = remainingMissiles
        } else {
            universe.planets[originIndex].missileInventory[.interplanetaryMissile] = nil
        }
        let remainingInterceptors = availableInterceptors - interceptedMissiles
        if remainingInterceptors > 0 {
            universe.planets[targetIndex].missileInventory[.antiBallisticMissile] = remainingInterceptors
        } else if interceptedMissiles > 0 {
            universe.planets[targetIndex].missileInventory[.antiBallisticMissile] = nil
        }
        universe.planets[targetIndex].defenseInventory = targetAfterDefenses
        universe.reports.append(report)
        universe.events.append(
            GameEvent(
                id: EventID(reportID),
                time: universe.gameTime,
                kind: .combat,
                title: "Missile Strike",
                message: "\(originBefore.name) launched \(missileCount) missiles at \(targetBefore.coordinate.displayText)."
            )
        )

        return .resolved(report)
    }

    private struct CombatStats {
        var attack: Double
        var shield: Double
        var hull: Double

        var strength: Double {
            max(attack, 0) + max(shield, 0) * 0.5 + max(hull, 0) / 200
        }

        func adding(_ other: CombatStats) -> CombatStats {
            CombatStats(
                attack: attack + other.attack,
                shield: shield + other.shield,
                hull: hull + other.hull
            )
        }
    }

    private static func shipStats(for ships: [ShipKind: Int], tech: ResearchState, ruleSet: RuleSet) -> CombatStats {
        let attackMultiplier = technologyMultiplier(.weapons, tech: tech)
        let shieldMultiplier = technologyMultiplier(.shielding, tech: tech)
        let hullMultiplier = technologyMultiplier(.armor, tech: tech)
        var stats = CombatStats(attack: 0, shield: 0, hull: 0)

        for (kind, quantity) in ships where quantity > 0 {
            guard let rule = ruleSet.shipRules[kind] else {
                continue
            }

            stats.attack += safe(rule.attack) * Double(quantity) * attackMultiplier
            stats.shield += safe(rule.shield) * Double(quantity) * shieldMultiplier
            stats.hull += safe(rule.hull) * Double(quantity) * hullMultiplier
        }

        return stats
    }

    private static func defenseStats(for defenses: [DefenseKind: Int], tech: ResearchState, ruleSet: RuleSet) -> CombatStats {
        let attackMultiplier = technologyMultiplier(.weapons, tech: tech)
        let shieldMultiplier = technologyMultiplier(.shielding, tech: tech)
        let hullMultiplier = technologyMultiplier(.armor, tech: tech)
        var stats = CombatStats(attack: 0, shield: 0, hull: 0)

        for (kind, quantity) in defenses where quantity > 0 {
            guard let rule = ruleSet.defenseRules[kind] else {
                continue
            }

            stats.attack += safe(rule.attack) * Double(quantity) * attackMultiplier
            stats.shield += safe(rule.shield) * Double(quantity) * shieldMultiplier
            stats.hull += safe(rule.hull) * Double(quantity) * hullMultiplier
        }

        return stats
    }

    private static func hasRequiredRules(
        attackerShips: [ShipKind: Int],
        defenderShips: [ShipKind: Int],
        defenderDefenses: [DefenseKind: Int],
        ruleSet: RuleSet
    ) -> Bool {
        attackerShips.keys.allSatisfy { shipRuleIsUsable(ruleSet.shipRules[$0]) } &&
            defenderShips.keys.allSatisfy { shipRuleIsUsable(ruleSet.shipRules[$0]) } &&
            defenderDefenses.keys.allSatisfy { defenseRuleIsUsable(ruleSet.defenseRules[$0]) }
    }

    private static func shipRuleIsUsable(_ rule: ShipRule?) -> Bool {
        guard let rule else {
            return false
        }

        return resourceBundleIsUsable(rule.baseCost) &&
            rule.attack.isFinite &&
            rule.shield.isFinite &&
            rule.hull.isFinite &&
            rule.attack >= 0 &&
            rule.shield >= 0 &&
            rule.hull >= 0 &&
            rule.cargoCapacity.isFinite &&
            rule.cargoCapacity >= 0
    }

    private static func defenseRuleIsUsable(_ rule: DefenseRule?) -> Bool {
        guard let rule else {
            return false
        }

        return resourceBundleIsUsable(rule.baseCost) &&
            rule.attack.isFinite &&
            rule.shield.isFinite &&
            rule.hull.isFinite &&
            rule.attack >= 0 &&
            rule.shield >= 0 &&
            rule.hull >= 0
    }

    private static func resourceBundleIsUsable(_ resources: ResourceBundle) -> Bool {
        resources.metal.isFinite &&
            resources.crystal.isFinite &&
            resources.deuterium.isFinite &&
            resources.metal >= 0 &&
            resources.crystal >= 0 &&
            resources.deuterium >= 0
    }

    private static func deferredBattleReport(
        fleet: Fleet,
        universe: Universe,
        target: Planet,
        attackerFaction: Faction?,
        defenderFaction: Faction?,
        attackerShips: [ShipKind: Int],
        defenderShips: [ShipKind: Int],
        defenderDefenses: [DefenseKind: Int]
    ) -> Report {
        Report(
            id: stableReportID(kind: .battle, universe: universe, fleet: fleet),
            time: fleet.arrivalTime,
            kind: .battle,
            title: "Battle deferred at \(target.coordinate.displayText)",
            summary: "Combat deferred because unit rules are incomplete.",
            participants: [
                ReportParticipant(
                    role: .attacker,
                    factionID: fleet.ownerID,
                    planetID: fleet.originPlanetID,
                    name: attackerFaction?.name ?? "Attacker",
                    beforeShips: attackerShips,
                    afterShips: attackerShips
                ),
                ReportParticipant(
                    role: .defender,
                    factionID: target.ownerID,
                    planetID: target.id,
                    name: defenderFaction?.name ?? target.name,
                    beforeShips: defenderShips,
                    afterShips: defenderShips,
                    beforeDefenses: defenderDefenses,
                    afterDefenses: defenderDefenses
                )
            ]
        )
    }

    private static func technologyMultiplier(_ kind: TechnologyKind, tech: ResearchState) -> Double {
        1 + Double(max(tech.levels[kind] ?? 0, 0)) * 0.10
    }

    private static func lossFraction(incomingStrength: Double, ownStrength: Double, winnerMultiplier: Double) -> Double {
        guard incomingStrength.isFinite, incomingStrength > 0 else {
            return 0
        }
        guard ownStrength.isFinite, ownStrength > 0 else {
            return 1
        }

        return min(max((incomingStrength / ownStrength) * winnerMultiplier, 0), 1)
    }

    private static func reducedShips(_ ships: [ShipKind: Int], by lossFraction: Double) -> [ShipKind: Int] {
        ships.reduce(into: [:]) { result, element in
            let quantity = max(element.value, 0)
            let destroyed = destroyedQuantity(quantity, by: lossFraction)
            let survivors = quantity - destroyed
            if survivors > 0 {
                result[element.key] = survivors
            }
        }
    }

    private static func destroyedDefenses(from defenses: [DefenseKind: Int], lossFraction: Double) -> [DefenseKind: Int] {
        defenses.reduce(into: [:]) { result, element in
            let destroyed = destroyedQuantity(max(element.value, 0), by: lossFraction)
            if destroyed > 0 {
                result[element.key] = destroyed
            }
        }
    }

    private static func recoveredDefenses(
        from destroyed: [DefenseKind: Int],
        universe: Universe,
        fleet: Fleet
    ) -> [DefenseKind: Int] {
        destroyed.reduce(into: [:]) { result, element in
            guard element.value > 1 else {
                return
            }

            let recoveryRate = 0.70
            let recovered = min(element.value - 1, max(1, Int(floor(Double(element.value) * recoveryRate))))
            if recovered > 0 {
                result[element.key] = recovered
            }
        }
    }

    private static func defenseInventory(
        before: [DefenseKind: Int],
        destroyed: [DefenseKind: Int],
        recovered: [DefenseKind: Int]
    ) -> [DefenseKind: Int] {
        before.reduce(into: [:]) { result, element in
            let remaining = max(element.value, 0) - (destroyed[element.key] ?? 0) + (recovered[element.key] ?? 0)
            if remaining > 0 {
                result[element.key] = remaining
            }
        }
    }

    private static func missileDestroyedDefenses(
        from defenses: [DefenseKind: Int],
        missileCount: Int
    ) -> [DefenseKind: Int] {
        let damageBudget = max(missileCount, 0) * 4
        guard damageBudget > 0 else {
            return [:]
        }

        var remainingDamage = damageBudget
        var destroyed: [DefenseKind: Int] = [:]
        for kind in missileTargetPriority {
            guard remainingDamage > 0 else {
                break
            }
            let available = max(defenses[kind] ?? 0, 0)
            guard available > 0 else {
                continue
            }

            let removed = min(available, remainingDamage)
            destroyed[kind] = removed
            remainingDamage -= removed
        }

        return destroyed
    }

    private static func missileStrikeSummary(
        destroyedDefenses: [DefenseKind: Int],
        interceptedMissiles: Int
    ) -> String {
        let damageText = "Interplanetary missiles damaged \(unitCount(destroyedDefenses)) defensive units"
        guard interceptedMissiles > 0 else {
            return "\(damageText)."
        }

        return "\(damageText), \(interceptedMissiles) intercepted."
    }

    private static var missileTargetPriority: [DefenseKind] {
        [
            .plasmaTurret,
            .gaussCannon,
            .ionCannon,
            .heavyLaser,
            .lightLaser,
            .rocketLauncher
        ]
    }

    private static func createMoonIfEligible(
        targetIndex: Int,
        reportID: UUID,
        battleTime: TimeInterval,
        debris: ResourceBundle,
        universe: inout Universe
    ) {
        guard universe.planets.indices.contains(targetIndex),
              universe.planets[targetIndex].moon == nil,
              UniverseTopologyEngine.moonChancePercent(forDebris: debris) > 0
        else {
            return
        }

        let planet = universe.planets[targetIndex]
        let moonChance = UniverseTopologyEngine.moonChancePercent(forDebris: debris)
        guard UniverseTopologyEngine.moonRollSucceeds(
            chancePercent: moonChance,
            universeID: universe.id,
            targetPlanetID: planet.id,
            reportID: reportID,
            battleTime: battleTime
        ) else {
            return
        }

        universe.planets[targetIndex].moon = Moon(
            id: stableUUID(
                namespace: "0011",
                payload: [
                    "moon",
                    universe.id.rawValue.uuidString,
                    planet.id.rawValue.uuidString,
                    reportID.uuidString,
                    String(battleTime)
                ].joined(separator: "|")
            ),
            name: "\(planet.name) Moon",
            createdAt: battleTime,
            buildingLevels: [:],
            debrisOriginReportID: reportID
        )
    }

    private static func destroyedQuantity(_ quantity: Int, by lossFraction: Double) -> Int {
        guard quantity > 0, lossFraction.isFinite, lossFraction > 0 else {
            return 0
        }

        return min(quantity, max(0, Int((Double(quantity) * min(lossFraction, 1)).rounded())))
    }

    private static func shipDifference(before: [ShipKind: Int], after: [ShipKind: Int]) -> [ShipKind: Int] {
        before.reduce(into: [:]) { result, element in
            let lost = max(element.value, 0) - max(after[element.key] ?? 0, 0)
            if lost > 0 {
                result[element.key] = lost
            }
        }
    }

    private static func defenseDifference(before: [DefenseKind: Int], after: [DefenseKind: Int]) -> [DefenseKind: Int] {
        before.reduce(into: [:]) { result, element in
            let lost = max(element.value, 0) - max(after[element.key] ?? 0, 0)
            if lost > 0 {
                result[element.key] = lost
            }
        }
    }

    private static func shipCost(_ ships: [ShipKind: Int], ruleSet: RuleSet) -> ResourceBundle {
        ships.reduce(.zero) { partial, element in
            guard let rule = ruleSet.shipRules[element.key], element.value > 0 else {
                return partial
            }

            return safeAdding(partial, rule.baseCost.scaled(by: Double(element.value)))
        }
    }

    private static func defenseCost(_ defenses: [DefenseKind: Int], ruleSet: RuleSet) -> ResourceBundle {
        defenses.reduce(.zero) { partial, element in
            guard let rule = ruleSet.defenseRules[element.key], element.value > 0 else {
                return partial
            }

            return safeAdding(partial, rule.baseCost.scaled(by: Double(element.value)))
        }
    }

    private static func debrisFromLosses(_ losses: ResourceBundle) -> ResourceBundle {
        ResourceBundle(
            metal: max(safe(losses.metal) * 0.35, 0),
            crystal: max(safe(losses.crystal) * 0.35, 0)
        )
    }

    private static func collectLoot(from resources: ResourceBundle, limit: Double, fraction: Double = 0.5) -> ResourceBundle {
        guard limit.isFinite, limit > 0 else {
            return .zero
        }

        let lootFraction = min(max(fraction.isFinite ? fraction : 0.5, 0), 1)
        let lootable = ResourceBundle(
            metal: max(resources.metal, 0) * lootFraction,
            crystal: max(resources.crystal, 0) * lootFraction,
            deuterium: max(resources.deuterium, 0) * lootFraction
        )
        var remaining = limit
        let metal = min(lootable.metal, remaining)
        remaining -= metal
        let crystal = min(lootable.crystal, remaining)
        remaining -= crystal
        let deuterium = min(lootable.deuterium, remaining)

        return ResourceBundle(metal: metal, crystal: crystal, deuterium: deuterium)
    }

    private static func collectCargo(from resources: ResourceBundle, limit: Double) -> ResourceBundle {
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

    private static func cargoCapacity(for ships: [ShipKind: Int], ruleSet: RuleSet) -> Double {
        var capacity = 0.0

        for (kind, quantity) in ships where quantity > 0 {
            guard let rule = ruleSet.shipRules[kind],
                  rule.cargoCapacity.isFinite,
                  rule.cargoCapacity >= 0
            else {
                continue
            }

            capacity += rule.cargoCapacity * Double(quantity)
        }

        return capacity.isFinite ? capacity : 0
    }

    private static func deterministicVariation(namespace: String, universe: Universe, fleet: Fleet) -> Double {
        let payload = [
            namespace,
            String(universe.seed),
            fleet.id.rawValue.uuidString,
            String(fleet.arrivalTime)
        ].joined(separator: "|")
        return 0.92 + Double(stableHash(payload) % 17) / 100
    }

    private static func stableReportID(kind: Report.Kind, universe: Universe, fleet: Fleet) -> UUID {
        stableUUID(
            namespace: "000f",
            payload: [
                "report",
                kind.rawValue,
                universe.id.rawValue.uuidString,
                String(universe.seed),
                fleet.id.rawValue.uuidString,
                fleet.mission.rawValue,
                fleet.target.displayText,
                String(fleet.arrivalTime)
            ].joined(separator: "|")
        )
    }

    private static func stableMissileReportID(
        originPlanetID: PlanetID,
        targetPlanetID: PlanetID,
        missileCount: Int,
        universe: Universe
    ) -> UUID {
        stableUUID(
            namespace: "0012",
            payload: [
                "missile-report",
                universe.id.rawValue.uuidString,
                String(universe.seed),
                originPlanetID.rawValue.uuidString,
                targetPlanetID.rawValue.uuidString,
                String(max(missileCount, 0)),
                String(universe.gameTime),
                String(universe.reports.count),
                String(universe.events.count)
            ].joined(separator: "|")
        )
    }

    private static func faction(for factionID: FactionID, in universe: Universe) -> Faction? {
        universe.factions.first(where: { $0.id == factionID })
    }

    private static func targetPlanetIndex(for fleet: Fleet, in universe: Universe) -> Int? {
        if let targetPlanetID = fleet.targetPlanetID,
           let index = universe.planets.firstIndex(where: { $0.id == targetPlanetID })
        {
            return index
        }

        return universe.planets.firstIndex(where: { $0.coordinate == fleet.target })
    }

    private static func normalizedShips(_ ships: [ShipKind: Int]) -> [ShipKind: Int] {
        ships.reduce(into: [:]) { result, element in
            guard element.value > 0 else {
                return
            }

            result[element.key] = max((result[element.key] ?? 0) + element.value, 0)
        }
    }

    private static func normalizedDefenses(_ defenses: [DefenseKind: Int]) -> [DefenseKind: Int] {
        defenses.reduce(into: [:]) { result, element in
            guard element.value > 0 else {
                return
            }

            result[element.key] = max((result[element.key] ?? 0) + element.value, 0)
        }
    }

    private static func unitCount<Key>(_ inventory: [Key: Int]) -> Int {
        inventory.values.reduce(0) { $0 + max($1, 0) }
    }

    private static func resourceSummary(_ resources: ResourceBundle) -> String {
        "M\(Int(max(resources.metal, 0))) C\(Int(max(resources.crystal, 0))) D\(Int(max(resources.deuterium, 0)))"
    }

    private static func espionageSummary(
        resources: ResourceBundle,
        ships: [ShipKind: Int],
        defenses: [DefenseKind: Int],
        intelTier: Int,
        lostProbes: Int
    ) -> String {
        var parts = [
            "Intel tier \(min(max(intelTier, 1), 5))/5",
            "resources \(resourceSummary(resources))"
        ]

        if intelTier >= 3 {
            parts.append("ships \(unitCount(ships))")
            parts.append("defenses \(unitCount(defenses))")
        } else {
            parts.append("ships hidden")
            parts.append("defenses hidden")
        }

        if lostProbes > 0 {
            parts.append("\(lostProbes) probes lost")
        }

        return parts.joined(separator: "; ") + "."
    }

    private static func battleSummary(
        attackerWon: Bool,
        protection: CombatProtectionEngine.ProtectionResult,
        debris: ResourceBundle,
        moonChance: Int,
        recoveredDefenses: [DefenseKind: Int]
    ) -> String {
        let outcome = attackerWon ? "攻击方获胜" : "防守方守住战场"
        let recoveryText = unitCount(recoveredDefenses) > 0
            ? "防御修复 \(unitCount(recoveredDefenses))"
            : "无防御修复"
        return "\(outcome)。\(protection.label)，掠夺上限 \(Int((protection.lootFraction * 100).rounded()))%。残骸 \(resourceSummary(debris))，月球概率 \(moonChance)%，\(recoveryText)。"
    }

    private static func safeAdding(_ lhs: ResourceBundle, _ rhs: ResourceBundle) -> ResourceBundle {
        let result = lhs.adding(rhs)
        guard result.metal.isFinite,
              result.crystal.isFinite,
              result.deuterium.isFinite
        else {
            return lhs.nonnegative
        }

        return result.nonnegative
    }

    private static func safe(_ value: Double) -> Double {
        value.isFinite ? max(value, 0) : 0
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
}

private extension ResourceBundle {
    var totalAmount: Double {
        metal + crystal + deuterium
    }
}
