import Foundation

public enum ExplorationEventEngine {
    public static func resolve(fleet: Fleet, universe: Universe) -> ExplorationOutcome {
        let payload = [
            "exploration-event",
            String(universe.seed),
            fleet.id.rawValue.uuidString,
            fleet.ownerID.rawValue.uuidString,
            fleet.target.displayText,
            String(fleet.arrivalTime)
        ].joined(separator: "|")
        var generator = SeededGenerator(seed: stableHash(payload))
        let capacity = availableCargoCapacity(for: fleet, ruleSet: universe.ruleSet)
        let roll = generator.nextInt(in: 0...99)

        switch roll {
        case 0..<32:
            return ExplorationOutcome(
                kind: .resourceCache,
                reward: cappedReward(
                    ResourceBundle(
                        metal: Double(generator.nextInt(in: 80...240)),
                        crystal: Double(generator.nextInt(in: 35...160)),
                        deuterium: Double(generator.nextInt(in: 10...80))
                    ),
                    capacity: capacity
                ),
                messageKey: "resource-cache"
            )
        case 32..<46:
            return ExplorationOutcome(
                kind: .debrisField,
                reward: cappedReward(
                    ResourceBundle(
                        metal: Double(generator.nextInt(in: 120...360)),
                        crystal: Double(generator.nextInt(in: 60...220))
                    ),
                    capacity: capacity
                ),
                messageKey: "debris-field"
            )
        case 46..<58:
            let foundShips: [ShipKind: Int] = generator.nextInt(in: 0...1) == 0
                ? [.espionageProbe: 1]
                : [.smallCargo: 1]
            return ExplorationOutcome(
                kind: .derelictShips,
                reward: cappedReward(ResourceBundle(metal: 60, crystal: 40), capacity: capacity),
                foundShips: foundShips,
                messageKey: "derelict-ships"
            )
        case 58..<66:
            let foundShips: [ShipKind: Int] = generator.nextInt(in: 0...1) == 0
                ? [.cruiser: 1]
                : [.largeCargo: 1]
            return ExplorationOutcome(
                kind: .largeDerelictFleet,
                reward: cappedReward(ResourceBundle(metal: 180, crystal: 120), capacity: capacity),
                foundShips: foundShips,
                messageKey: "large-derelict-fleet"
            )
        case 66..<72:
            return ExplorationOutcome(
                kind: .darkMatter,
                reward: cappedReward(ResourceBundle(crystal: 240, deuterium: 160), capacity: capacity),
                messageKey: "dark-matter"
            )
        case 72..<82:
            let lost = explorationLoss(from: fleet.ships, generator: &generator, severity: 1)
            return ExplorationOutcome(
                kind: .pirateAmbush,
                reward: cappedReward(ResourceBundle(metal: 40, crystal: 20), capacity: capacity),
                lostShips: lost,
                messageKey: "pirate-ambush"
            )
        case 82..<88:
            return ExplorationOutcome(
                kind: .alienEncounter,
                lostShips: explorationLoss(from: fleet.ships, generator: &generator, severity: 2),
                messageKey: "alien-encounter"
            )
        case 88..<92:
            return ExplorationOutcome(
                kind: .earlyReturn,
                timeShift: -Double(generator.nextInt(in: 120...420)),
                messageKey: "early-return"
            )
        case 92..<96:
            return ExplorationOutcome(
                kind: .delayedReturn,
                timeShift: Double(generator.nextInt(in: 300...900)),
                messageKey: "delayed-return"
            )
        case 96..<98:
            return ExplorationOutcome(
                kind: .blackHole,
                lostShips: fleet.ships,
                messageKey: "black-hole"
            )
        default:
            return ExplorationOutcome(kind: .emptySignal, messageKey: "empty-signal")
        }
    }

    private static func explorationLoss(
        from ships: [ShipKind: Int],
        generator: inout SeededGenerator,
        severity: Int
    ) -> [ShipKind: Int] {
        let candidates = ships
            .filter { $0.value > 0 }
            .map(\.key)
            .sorted { $0.rawValue < $1.rawValue }
        guard !candidates.isEmpty else {
            return [:]
        }
        let kind = candidates[generator.nextInt(in: 0...(candidates.count - 1))]

        let available = max(ships[kind] ?? 0, 0)
        guard available > 0 else {
            return [:]
        }

        return [kind: min(available, max(severity, 1))]
    }

    private static func availableCargoCapacity(for fleet: Fleet, ruleSet: RuleSet) -> Double {
        let totalCapacity = fleet.ships.reduce(0) { partial, element in
            guard element.value > 0,
                  let rule = ruleSet.shipRules[element.key],
                  rule.cargoCapacity.isFinite,
                  rule.cargoCapacity > 0
            else {
                return partial
            }

            return partial + rule.cargoCapacity * Double(element.value)
        }
        let usedCapacity = max(fleet.cargo.metal, 0) + max(fleet.cargo.crystal, 0) + max(fleet.cargo.deuterium, 0)
        return max(totalCapacity - usedCapacity, 0)
    }

    private static func cappedReward(_ reward: ResourceBundle, capacity: Double) -> ResourceBundle {
        guard capacity.isFinite, capacity > 0 else {
            return .zero
        }

        var remaining = capacity
        let metal = min(max(reward.metal, 0), remaining)
        remaining -= metal
        let crystal = min(max(reward.crystal, 0), remaining)
        remaining -= crystal
        let deuterium = min(max(reward.deuterium, 0), remaining)
        return ResourceBundle(metal: metal, crystal: crystal, deuterium: deuterium)
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
