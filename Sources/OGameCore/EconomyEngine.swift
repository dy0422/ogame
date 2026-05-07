import Foundation

public enum EconomyEngine {
    public static func recomputeEnergy(for planet: inout Planet, ruleSet: RuleSet) {
        planet.energy = energyState(for: planet, ruleSet: ruleSet)
    }

    public static func storageCapacity(for planet: Planet, ruleSet: RuleSet) -> ResourceStorage {
        var storage = planet.storage

        for building in BuildingKind.allCases {
            let level = normalizedLevel(planet.buildingLevels[building] ?? 0)
            guard level > 0, let rule = ruleSet.buildingRules[building] else {
                continue
            }

            storage = storage.adding(rule.storageBonus.scaled(by: Double(level)))
        }

        return storage
    }

    public static func productionPerHour(for planet: Planet, ruleSet: RuleSet) -> ResourceBundle {
        let energy = energyState(for: planet, ruleSet: ruleSet)
        let ratio = energyRatio(for: energy)
        var production = ResourceBundle.zero

        for building in BuildingKind.allCases {
            let level = normalizedLevel(planet.buildingLevels[building] ?? 0)
            guard level > 0, let rule = ruleSet.buildingRules[building] else {
                continue
            }

            production = production.adding(
                scaledProduction(rule.productionPerHour, level: level)
                    .scaled(by: productionScale(for: building, on: planet))
            )
        }

        return production.scaled(by: ratio)
    }

    public static func applyProduction(to planet: inout Planet, delta: TimeInterval, ruleSet: RuleSet) {
        guard delta.isFinite, delta > 0 else {
            return
        }

        recomputeEnergy(for: &planet, ruleSet: ruleSet)

        let produced = productionPerHour(for: planet, ruleSet: ruleSet)
            .scaled(by: delta / 3_600)
        planet.resources = planet.resources.adding(produced).clamped(to: storageCapacity(for: planet, ruleSet: ruleSet))
    }

    public static func tick(universe: inout Universe, delta: TimeInterval) {
        guard delta.isFinite, delta > 0 else {
            return
        }

        var updatedPlanetCount = 0
        for index in universe.planets.indices {
            guard universe.planets[index].ownerID != nil else {
                continue
            }

            applyProduction(to: &universe.planets[index], delta: delta, ruleSet: universe.ruleSet)
            updatedPlanetCount += 1
        }

        guard updatedPlanetCount > 0 else {
            return
        }

        universe.events.append(
            GameEvent(
                id: economyEventID(index: universe.events.count + 1),
                time: universe.gameTime + delta,
                kind: .economy,
                title: "Economy Updated",
                message: "Produced resources for \(updatedPlanetCount) owned planets over \(delta) seconds."
            )
        )
    }

    private static func energyState(for planet: Planet, ruleSet: RuleSet) -> EnergyState {
        var produced: Double = 0
        var used: Double = 0

        for building in BuildingKind.allCases {
            let level = normalizedLevel(planet.buildingLevels[building] ?? 0)
            guard level > 0, let rule = ruleSet.buildingRules[building] else {
                continue
            }

            let productionScale = productionScale(for: building, on: planet)
            produced += rule.energyProduced * Double(level)
            used += rule.energyUsed * Double(level) * productionScale
        }

        return EnergyState(produced: produced, used: used)
    }

    private static func energyRatio(for energy: EnergyState) -> Double {
        min(1, energy.produced / max(energy.used, 1))
    }

    private static func scaledProduction(_ baseProduction: ResourceBundle, level: Int) -> ResourceBundle {
        guard level > 0 else {
            return .zero
        }

        let multiplier = Double(level) * pow(1.12, Double(level - 1))
        return baseProduction.scaled(by: multiplier)
    }

    private static func productionScale(for building: BuildingKind, on planet: Planet) -> Double {
        guard let value = planet.productionSettings[building], value.isFinite else {
            return 1
        }

        return min(max(value, 0), 1)
    }

    private static func normalizedLevel(_ level: Int) -> Int {
        max(level, 0)
    }

    private static func economyEventID(index: Int) -> EventID {
        EventID(UUID(uuidString: String(format: "00000000-0000-0000-0003-%012d", index))!)
    }
}
