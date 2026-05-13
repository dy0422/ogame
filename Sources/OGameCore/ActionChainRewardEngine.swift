import Foundation

public struct ActionChainRewardClaim: Equatable, Sendable {
    public enum Status: String, Equatable, Sendable {
        case claimed
        case notFound
        case expired
        case locked
        case noPlayerPlanet
    }

    public var status: Status
    public var chainID: UUID?
    public var title: String
    public var resources: ResourceBundle
    public var commanderReward: CommanderRewardBundle?
    public var commanderDrop: PendingCommanderRecruit?
    public var receivingPlanetID: PlanetID?

    public init(
        status: Status,
        chainID: UUID? = nil,
        title: String = "",
        resources: ResourceBundle = .zero,
        commanderReward: CommanderRewardBundle? = nil,
        commanderDrop: PendingCommanderRecruit? = nil,
        receivingPlanetID: PlanetID? = nil
    ) {
        self.status = status
        self.chainID = chainID
        self.title = title
        self.resources = resources.nonnegative
        self.commanderReward = commanderReward.flatMap { $0.isEmpty ? nil : $0 }
        self.commanderDrop = commanderDrop
        self.receivingPlanetID = receivingPlanetID
    }
}

public enum ActionChainRewardEngine {
    public static func claim(_ chainID: UUID, in universe: inout Universe) -> ActionChainRewardClaim {
        guard let chainIndex = universe.actionChains.firstIndex(where: { $0.id == chainID }) else {
            return ActionChainRewardClaim(status: .notFound, chainID: chainID)
        }

        let chain = universe.actionChains[chainIndex]
        guard chain.expiresAt > universe.gameTime else {
            return ActionChainRewardClaim(status: .expired, chainID: chain.id, title: chain.title)
        }
        guard canClaim(chain, at: universe.gameTime) else {
            return ActionChainRewardClaim(status: .locked, chainID: chain.id, title: chain.title)
        }
        guard let receiverIndex = firstPlayerPlanetIndex(in: universe) else {
            return ActionChainRewardClaim(status: .noPlayerPlanet, chainID: chain.id, title: chain.title)
        }

        let receiver = universe.planets[receiverIndex]
        let receiverID = receiver.id
        universe.planets[receiverIndex].resources = universe.planets[receiverIndex].resources
            .adding(chain.reward)
            .nonnegative

        if let commanderReward = chain.commanderReward {
            universe.commanderRoster.recruitmentTickets += commanderReward.recruitmentTickets
            universe.commanderRoster.trainingData += commanderReward.trainingData
        }

        let commanderDrop = droppedCommanderCandidate(for: chain, in: universe)
        if let commanderDrop {
            universe.commanderRoster.pendingRecruits.append(commanderDrop)
        }

        universe.actionChains.remove(at: chainIndex)
        clearResolvedHostileSite(for: chain, in: &universe)
        universe.events.append(claimEvent(for: chain, receiver: receiver, commanderDrop: commanderDrop, in: universe))

        return ActionChainRewardClaim(
            status: .claimed,
            chainID: chain.id,
            title: chain.title,
            resources: chain.reward,
            commanderReward: chain.commanderReward,
            commanderDrop: commanderDrop,
            receivingPlanetID: receiverID
        )
    }

    public static func canClaim(_ chain: ActionChain, at gameTime: TimeInterval) -> Bool {
        chain.expiresAt > gameTime && chain.steps.allSatisfy { $0.status == .complete }
    }

    private static func firstPlayerPlanetIndex(in universe: Universe) -> Int? {
        universe.planets.firstIndex { $0.ownerID == universe.playerFactionID }
    }

    private static func clearResolvedHostileSite(for chain: ActionChain, in universe: inout Universe) {
        guard chain.kind == .hostileRaid else {
            return
        }

        universe.hostileSites.removeAll { site in
            stableUUID("action-chain|hostile|\(site.id.uuidString)") == chain.id
        }
    }

    private static func droppedCommanderCandidate(for chain: ActionChain, in universe: Universe) -> PendingCommanderRecruit? {
        guard let commanderReward = chain.commanderReward,
              commanderReward.commanderDropChance > 0,
              let definition = droppedCommanderDefinition(for: chain, chance: commanderReward.commanderDropChance, in: universe)
        else {
            return nil
        }

        return PendingCommanderRecruit(
            id: stableUUID("action-chain-commander|\(universe.id.rawValue.uuidString)|\(chain.id.uuidString)|\(definition.id)"),
            definitionID: definition.id,
            rarity: definition.rarity,
            pulledAt: universe.gameTime
        )
    }

    private static func droppedCommanderDefinition(
        for chain: ActionChain,
        chance: Double,
        in universe: Universe
    ) -> CommanderDefinition? {
        var generator = SeededGenerator(
            seed: stableHash("action-chain-drop|\(universe.seed)|\(universe.gameTime)|\(chain.id.uuidString)")
        )
        let roll = Double(generator.nextInt(in: 0...9_999)) / 10_000
        guard roll < chance else {
            return nil
        }

        let rarity = droppedRarity(generator: &generator)
        let candidates = CommanderCatalog.definitions
            .filter { $0.rarity == rarity }
            .sorted { $0.id < $1.id }
        guard !candidates.isEmpty else {
            return CommanderCatalog.definitions.sorted { $0.id < $1.id }.first
        }

        return candidates[generator.nextInt(in: 0...(candidates.count - 1))]
    }

    private static func droppedRarity(generator: inout SeededGenerator) -> CommanderRarity {
        let roll = Double(generator.nextInt(in: 0...9_999)) / 10_000
        if roll < 0.02 {
            return .legendary
        }
        if roll < 0.10 {
            return .epic
        }
        if roll < 0.35 {
            return .elite
        }
        return .common
    }

    private static func claimEvent(
        for chain: ActionChain,
        receiver: Planet,
        commanderDrop: PendingCommanderRecruit?,
        in universe: Universe
    ) -> GameEvent {
        let reward = chain.reward
        let ticketText = chain.commanderReward.map { "，招募令 +\($0.recruitmentTickets)，训练数据 +\($0.trainingData)" } ?? ""
        let dropText = commanderDrop.flatMap { CommanderCatalog.definition(id: $0.definitionID)?.name }
            .map { "，发现候选指挥官\($0)" } ?? ""
        return GameEvent(
            id: EventID(stableUUID("event|action-chain-claim|\(universe.id.rawValue.uuidString)|\(chain.id.uuidString)")),
            time: universe.gameTime,
            kind: .system,
            title: "行动链奖励领取",
            message: "\(chain.title) 已结算到 \(receiver.name) \(receiver.coordinate.displayText)：金属 +\(Int(reward.metal))，晶体 +\(Int(reward.crystal))，重氢 +\(Int(reward.deuterium))\(ticketText)\(dropText)。"
        )
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
