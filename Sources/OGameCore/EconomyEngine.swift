import Foundation

public enum EconomyEngine {
    private static let baseProductionPerHour = ResourceBundle(metal: 80, crystal: 40)
    private static let serverGrowthBase = 1.1
    private static let storageGrowthBase = 1.5
    private static let fusionEnergyGrowthBase = 1.05

    public static func recomputeEnergy(for planet: inout Planet, ruleSet: RuleSet, research: ResearchState = ResearchState()) {
        planet.energy = energyState(for: planet, ruleSet: ruleSet, research: research)
    }

    public static func storageCapacity(for planet: Planet, ruleSet: RuleSet) -> ResourceStorage {
        var storage = sanitizedStorage(planet.storage)
        storage.metal = storageCapacity(base: storage.metal, level: normalizedLevel(planet.buildingLevels[.metalStorage] ?? 0))
        storage.crystal = storageCapacity(base: storage.crystal, level: normalizedLevel(planet.buildingLevels[.crystalStorage] ?? 0))
        storage.deuterium = storageCapacity(base: storage.deuterium, level: normalizedLevel(planet.buildingLevels[.deuteriumTank] ?? 0))

        for building in BuildingKind.allCases {
            guard !isDedicatedStorageBuilding(building) else {
                continue
            }

            let level = normalizedLevel(planet.buildingLevels[building] ?? 0)
            guard level > 0, let rule = ruleSet.buildingRules[building] else {
                continue
            }

            storage = storage.adding(sanitizedStorage(rule.storageBonus.scaled(by: Double(level))))
        }

        return storage
    }

    public static func productionPerHour(
        for planet: Planet,
        ruleSet: RuleSet,
        research: ResearchState = ResearchState()
    ) -> ResourceBundle {
        let energy = energyState(for: planet, ruleSet: ruleSet, research: research)
        let ratio = energyRatio(for: energy)
        var mineProduction = ResourceBundle.zero
        var fixedProduction = baseProductionPerHour

        for building in BuildingKind.allCases {
            let level = normalizedLevel(planet.buildingLevels[building] ?? 0)
            guard level > 0, let rule = ruleSet.buildingRules[building] else {
                continue
            }

            if building == .fusionReactor {
                fixedProduction = fixedProduction.adding(fusionFuelConsumption(level: level))
                continue
            }

            var buildingProduction = scaledProduction(rule.productionPerHour, level: level)
            if building == .deuteriumSynthesizer {
                buildingProduction.deuterium *= deuteriumTemperatureFactor(for: planet)
            }

            mineProduction = mineProduction.adding(
                buildingProduction.scaled(by: productionScale(for: building, on: planet))
            )
        }

        return fixedProduction.adding(mineProduction.scaled(by: ratio))
    }

    public static func applyProduction(
        to planet: inout Planet,
        delta: TimeInterval,
        ruleSet: RuleSet,
        research: ResearchState = ResearchState()
    ) {
        guard delta.isFinite, delta > 0 else {
            return
        }

        recomputeEnergy(for: &planet, ruleSet: ruleSet, research: research)

        let produced = productionPerHour(for: planet, ruleSet: ruleSet, research: research)
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

            applyProduction(
                to: &universe.planets[index],
                delta: delta,
                ruleSet: universe.ruleSet,
                research: researchState(for: universe.planets[index], in: universe)
            )
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

    public static func energyState(
        for planet: Planet,
        ruleSet: RuleSet,
        research: ResearchState = ResearchState()
    ) -> EnergyState {
        var produced: Double = 0
        var used: Double = 0

        for building in BuildingKind.allCases {
            let level = normalizedLevel(planet.buildingLevels[building] ?? 0)
            guard level > 0, let rule = ruleSet.buildingRules[building] else {
                continue
            }

            let productionScale = productionScale(for: building, on: planet)
            if building == .fusionReactor {
                produced += fusionEnergy(baseEnergy: rule.energyProduced, level: level, research: research) * productionScale
            } else {
                produced += scaledEnergy(rule.energyProduced, level: level)
            }
            used += scaledEnergy(rule.energyUsed, level: level) * productionScale
        }

        produced += solarSatelliteEnergy(for: planet)

        return EnergyState(produced: produced, used: used)
    }

    private static func energyRatio(for energy: EnergyState) -> Double {
        min(1, energy.produced / max(energy.used, 1))
    }

    private static func scaledProduction(_ baseProduction: ResourceBundle, level: Int) -> ResourceBundle {
        guard level > 0 else {
            return .zero
        }

        return ResourceBundle(
            metal: scaledServerCurve(baseProduction.metal, level: level),
            crystal: scaledServerCurve(baseProduction.crystal, level: level),
            deuterium: scaledServerCurve(baseProduction.deuterium, level: level)
        )
    }

    private static func scaledEnergy(_ baseEnergy: Double, level: Int) -> Double {
        guard level > 0 else {
            return 0
        }

        return scaledServerCurve(baseEnergy, level: level)
    }

    private static func scaledServerCurve(_ baseValue: Double, level: Int) -> Double {
        guard baseValue.isFinite else {
            return 0
        }

        return max(baseValue, 0) * Double(level) * pow(serverGrowthBase, Double(level))
    }

    private static func deuteriumTemperatureFactor(for planet: Planet) -> Double {
        max(0, -0.002 * planet.temperatureCelsius + 1.28)
    }

    private static func solarSatelliteEnergy(for planet: Planet) -> Double {
        let count = normalizedLevel(planet.shipInventory[.solarSatellite] ?? 0)
        guard count > 0 else {
            return 0
        }

        let perSatellite = max(0, floor((planet.temperatureCelsius + 140) / 6))
        return perSatellite * Double(count)
    }

    private static func fusionEnergy(baseEnergy: Double, level: Int, research: ResearchState) -> Double {
        guard baseEnergy.isFinite, level > 0 else {
            return 0
        }

        let energyTechnologyBonus = 1 + Double(normalizedLevel(research.levels[.energy] ?? 0)) * 0.01
        return max(baseEnergy, 0) * Double(level) * pow(fusionEnergyGrowthBase, Double(level)) * energyTechnologyBonus
    }

    private static func fusionFuelConsumption(level: Int) -> ResourceBundle {
        ResourceBundle(deuterium: -scaledServerCurve(40, level: level))
    }

    private static func storageCapacity(base: Double, level: Int) -> Double {
        guard base.isFinite else {
            return 0
        }

        guard level > 0 else {
            return max(base, 0)
        }

        return max(base, 0) * pow(storageGrowthBase, Double(level))
    }

    private static func sanitizedStorage(_ storage: ResourceStorage) -> ResourceStorage {
        ResourceStorage(
            metal: storage.metal.isFinite ? max(storage.metal, 0) : 0,
            crystal: storage.crystal.isFinite ? max(storage.crystal, 0) : 0,
            deuterium: storage.deuterium.isFinite ? max(storage.deuterium, 0) : 0
        )
    }

    private static func isDedicatedStorageBuilding(_ building: BuildingKind) -> Bool {
        building == .metalStorage || building == .crystalStorage || building == .deuteriumTank
    }

    private static func researchState(for planet: Planet, in universe: Universe) -> ResearchState {
        guard let ownerID = planet.ownerID,
              let faction = universe.factions.first(where: { $0.id == ownerID })
        else {
            return ResearchState()
        }

        return faction.technology
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
