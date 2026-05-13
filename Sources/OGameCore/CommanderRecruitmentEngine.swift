import Foundation

public struct CommanderPullResult: Equatable, Sendable {
    public var candidateID: UUID?
    public var definitionID: String
    public var name: String
    public var rarity: CommanderRarity
    public var isDuplicate: Bool
    public var shardsGranted: Int

    public init(
        candidateID: UUID? = nil,
        definitionID: String,
        name: String,
        rarity: CommanderRarity,
        isDuplicate: Bool,
        shardsGranted: Int
    ) {
        self.candidateID = candidateID
        self.definitionID = definitionID
        self.name = name
        self.rarity = rarity
        self.isDuplicate = isDuplicate
        self.shardsGranted = max(shardsGranted, 0)
    }
}

public struct CommanderRecruitmentResult: Equatable, Sendable {
    public var pulls: [CommanderPullResult]
    public var ticketsSpent: Int

    public init(pulls: [CommanderPullResult], ticketsSpent: Int) {
        self.pulls = pulls
        self.ticketsSpent = max(ticketsSpent, 0)
    }
}

public enum CommanderRecruitmentEngine {
    public static func recruit(count: Int, in universe: inout Universe) -> CommanderRecruitmentResult {
        guard universe.commanderRoster.recruitmentTickets > 0 else {
            return CommanderRecruitmentResult(pulls: [], ticketsSpent: 0)
        }

        let requestedCount = min(max(count, 1), 10)
        let pullCount = min(requestedCount, universe.commanderRoster.recruitmentTickets)
        guard pullCount > 0 else {
            return CommanderRecruitmentResult(pulls: [], ticketsSpent: 0)
        }

        var generator = SeededGenerator(
            seed: stableHash("commander-recruit|\(universe.seed)|\(universe.commanderRoster.recruitmentState.totalPulls)|\(pullCount)")
        )
        var pulls: [CommanderPullResult] = []
        var didPullEliteOrBetter = false

        for index in 0..<pullCount {
            var rarity = selectedRarity(state: universe.commanderRoster.recruitmentState, generator: &generator)
            if pullCount == 10, index == pullCount - 1, !didPullEliteOrBetter, rarity == .common {
                rarity = .elite
            }

            guard let definition = definition(for: rarity, generator: &generator) else {
                continue
            }

            let candidateID = stableUUID(
                "pending-commander|\(universe.id.rawValue.uuidString)|\(universe.commanderRoster.recruitmentState.totalPulls)|\(index)|\(definition.id)"
            )
            let candidate = PendingCommanderRecruit(
                id: candidateID,
                definitionID: definition.id,
                rarity: definition.rarity,
                pulledAt: universe.gameTime
            )
            let isDuplicate = universe.commanderRoster.ownedCommanders.contains { $0.definitionID == definition.id }
            let pull = CommanderPullResult(
                candidateID: candidate.id,
                definitionID: definition.id,
                name: definition.name,
                rarity: definition.rarity,
                isDuplicate: isDuplicate,
                shardsGranted: isDuplicate ? duplicateShardValue(for: definition.rarity) : 0
            )

            universe.commanderRoster.pendingRecruits.append(candidate)
            pulls.append(pull)
            didPullEliteOrBetter = didPullEliteOrBetter || pull.rarity >= .elite
            universe.commanderRoster.recruitmentTickets = max(universe.commanderRoster.recruitmentTickets - 1, 0)
            updateRecruitmentCounters(after: pull.rarity, in: &universe.commanderRoster.recruitmentState)
        }

        return CommanderRecruitmentResult(pulls: pulls, ticketsSpent: pulls.count)
    }

    public static func claimPendingRecruit(_ candidateID: UUID, in universe: inout Universe) -> CommanderPullResult? {
        guard let index = universe.commanderRoster.pendingRecruits.firstIndex(where: { $0.id == candidateID }) else {
            return nil
        }

        let candidate = universe.commanderRoster.pendingRecruits.remove(at: index)
        return applyPull(definitionID: candidate.definitionID, candidateID: candidate.id, in: &universe)
    }

    public static func claimAllPendingRecruits(in universe: inout Universe) -> [CommanderPullResult] {
        let candidateIDs = universe.commanderRoster.pendingRecruits.map(\.id)
        return candidateIDs.compactMap { candidateID in
            claimPendingRecruit(candidateID, in: &universe)
        }
    }

    public static func applyPull(definitionID: String, candidateID: UUID? = nil, in universe: inout Universe) -> CommanderPullResult? {
        guard let definition = CommanderCatalog.definition(id: definitionID) else {
            return nil
        }

        if universe.commanderRoster.ownedCommanders.contains(where: { $0.definitionID == definition.id }) {
            let shards = duplicateShardValue(for: definition.rarity)
            universe.commanderRoster.shardsByDefinitionID[definition.id, default: 0] += shards
            return CommanderPullResult(
                candidateID: candidateID,
                definitionID: definition.id,
                name: definition.name,
                rarity: definition.rarity,
                isDuplicate: true,
                shardsGranted: shards
            )
        }

        universe.commanderRoster.ownedCommanders.append(
            OwnedCommander(
                id: stableCommanderID("commander|\(universe.id.rawValue.uuidString)|\(definition.id)"),
                definitionID: definition.id,
                rarity: definition.rarity,
                acquiredAt: universe.gameTime
            )
        )
        universe.commanderRoster.ownedCommanders.sort { lhs, rhs in
            if lhs.rarity != rhs.rarity {
                return lhs.rarity > rhs.rarity
            }
            return lhs.definitionID < rhs.definitionID
        }

        return CommanderPullResult(
            candidateID: candidateID,
            definitionID: definition.id,
            name: definition.name,
            rarity: definition.rarity,
            isDuplicate: false,
            shardsGranted: 0
        )
    }

    private static func selectedRarity(
        state: CommanderRecruitmentState,
        generator: inout SeededGenerator
    ) -> CommanderRarity {
        if state.pullsSinceLegendary >= 39 {
            return .legendary
        }

        let softPityBonus = 0.03 * Double(max(state.pullsSinceLegendary - 24, 0))
        let legendaryChance = min(0.01 + softPityBonus, 0.50)
        let commonChance = max(0.70 - softPityBonus, 0.20)
        let eliteChance = 0.24
        let epicChance = 0.05
        let roll = Double(generator.nextInt(in: 0...9_999)) / 10_000

        if roll < legendaryChance {
            return .legendary
        }
        if roll < legendaryChance + epicChance {
            return .epic
        }
        if roll < legendaryChance + epicChance + eliteChance {
            return .elite
        }
        if roll < legendaryChance + epicChance + eliteChance + commonChance {
            return .common
        }
        return .common
    }

    private static func definition(for rarity: CommanderRarity, generator: inout SeededGenerator) -> CommanderDefinition? {
        let candidates = CommanderCatalog.definitions
            .filter { $0.rarity == rarity }
            .sorted { $0.id < $1.id }
        guard !candidates.isEmpty else {
            return nil
        }
        return candidates[generator.nextInt(in: 0...(candidates.count - 1))]
    }

    private static func updateRecruitmentCounters(after rarity: CommanderRarity, in state: inout CommanderRecruitmentState) {
        state.totalPulls += 1
        state.pullsSinceEliteOrBetter = rarity >= .elite ? 0 : state.pullsSinceEliteOrBetter + 1
        state.pullsSinceLegendary = rarity == .legendary ? 0 : state.pullsSinceLegendary + 1
    }

    private static func duplicateShardValue(for rarity: CommanderRarity) -> Int {
        switch rarity {
        case .common:
            return 5
        case .elite:
            return 10
        case .epic:
            return 25
        case .legendary:
            return 50
        }
    }

    private static func stableCommanderID(_ payload: String) -> CommanderID {
        CommanderID(stableUUID(payload))
    }

    private static func stableUUID(_ payload: String) -> UUID {
        let hash = stableHash(payload)
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
}
