import Foundation

public enum CombatEngine {
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

        let attackerStats = shipStats(for: attackerBeforeShips, tech: attackerTech, ruleSet: universe.ruleSet)
        let defenderShipStats = shipStats(for: defenderBeforeShips, tech: defenderTech, ruleSet: universe.ruleSet)
        let defenderDefenseStats = defenseStats(for: defenderBeforeDefenses, tech: defenderTech, ruleSet: universe.ruleSet)
        let defenderStats = defenderShipStats.adding(defenderDefenseStats)
        let attackerVariation = deterministicVariation(
            namespace: "attacker",
            universe: universe,
            fleet: fleet
        )
        let defenderVariation = deterministicVariation(
            namespace: "defender",
            universe: universe,
            fleet: fleet
        )
        let attackerStrength = attackerStats.strength * attackerVariation
        let defenderStrength = defenderStats.strength * defenderVariation
        let attackerLossFraction = lossFraction(
            incomingStrength: defenderStrength,
            ownStrength: attackerStrength,
            winnerMultiplier: 0.55
        )
        let defenderLossFraction = lossFraction(
            incomingStrength: attackerStrength,
            ownStrength: defenderStrength,
            winnerMultiplier: 0.70
        )

        let attackerAfterShips = reducedShips(attackerBeforeShips, by: attackerLossFraction)
        let defenderAfterShips = reducedShips(defenderBeforeShips, by: defenderLossFraction)
        let destroyedDefenses = destroyedDefenses(from: defenderBeforeDefenses, lossFraction: defenderLossFraction)
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
        let attackerWon = attackerStrength >= defenderStrength && !attackerAfterShips.isEmpty
        let survivingCapacity = cargoCapacity(for: attackerAfterShips, ruleSet: universe.ruleSet)
        let cappedExistingCargo = collectCargo(from: fleet.cargo, limit: survivingCapacity)
        let loot = attackerWon
            ? collectLoot(
                from: universe.planets[targetIndex].resources,
                limit: max(survivingCapacity - cappedExistingCargo.totalAmount, 0)
            )
            : .zero

        universe.planets[targetIndex].shipInventory = defenderAfterShips
        universe.planets[targetIndex].defenseInventory = defenderAfterDefenses
        universe.planets[targetIndex].resources = universe.planets[targetIndex].resources.subtracting(loot).nonnegative
        universe.planets[targetIndex].debrisField = safeAdding(universe.planets[targetIndex].debrisField, debris)

        returningFleet.ships = attackerAfterShips
        returningFleet.cargo = safeAdding(cappedExistingCargo, loot)

        universe.reports.append(
            Report(
                id: stableReportID(kind: .battle, universe: universe, fleet: fleet),
                time: fleet.arrivalTime,
                kind: .battle,
                title: "Battle at \(universe.planets[targetIndex].coordinate.displayText)",
                summary: attackerWon ? "The attacker won and recovered loot." : "The defender held the field.",
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
                losses: safeAdding(attackerLosses, defenderLosses)
            )
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
        let target = universe.planets[targetIndex]
        let targetShips = normalizedShips(target.shipInventory)
        let targetDefenses = normalizedDefenses(target.defenseInventory)

        universe.reports.append(
            Report(
                id: stableReportID(kind: .espionage, universe: universe, fleet: fleet),
                time: fleet.arrivalTime,
                kind: .espionage,
                title: "Espionage at \(target.coordinate.displayText)",
                summary: "Resources \(resourceSummary(target.resources)); ships \(unitCount(targetShips)); defenses \(unitCount(targetDefenses)).",
                participants: [
                    ReportParticipant(
                        role: .attacker,
                        factionID: fleet.ownerID,
                        planetID: fleet.originPlanetID,
                        name: attackerFaction?.name ?? "Observer",
                        beforeShips: normalizedShips(fleet.ships),
                        afterShips: normalizedShips(fleet.ships)
                    ),
                    ReportParticipant(
                        role: .defender,
                        factionID: target.ownerID,
                        planetID: target.id,
                        name: defenderFaction?.name ?? target.name,
                        beforeShips: targetShips,
                        afterShips: targetShips,
                        beforeDefenses: targetDefenses,
                        afterDefenses: targetDefenses
                    )
                ]
            )
        )

        return returningFleet
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

            let payload = [
                "defense-recovery",
                String(universe.seed),
                fleet.id.rawValue.uuidString,
                element.key.rawValue,
                String(fleet.arrivalTime)
            ].joined(separator: "|")
            let recoveryRate = 0.35 + Double(stableHash(payload) % 21) / 100
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

    private static func collectLoot(from resources: ResourceBundle, limit: Double) -> ResourceBundle {
        guard limit.isFinite, limit > 0 else {
            return .zero
        }

        let lootable = ResourceBundle(
            metal: max(resources.metal, 0) * 0.5,
            crystal: max(resources.crystal, 0) * 0.5,
            deuterium: max(resources.deuterium, 0) * 0.5
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
