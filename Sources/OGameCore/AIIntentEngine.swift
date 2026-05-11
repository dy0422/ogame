public struct AIIntentSummary: Equatable, Identifiable, Sendable {
    public enum Intent: String, Codable, Equatable, Sendable {
        case buildUp
        case scout
        case expand
        case raid
        case recycle
        case defend
        case idle
    }

    public var factionID: FactionID
    public var factionName: String
    public var intent: Intent
    public var title: String
    public var detail: String
    public var priority: StrategicAdvisorRecommendation.Priority

    public var id: FactionID { factionID }

    public init(
        factionID: FactionID,
        factionName: String,
        intent: Intent,
        title: String,
        detail: String,
        priority: StrategicAdvisorRecommendation.Priority
    ) {
        self.factionID = factionID
        self.factionName = factionName
        self.intent = intent
        self.title = title
        self.detail = detail
        self.priority = priority
    }
}

public enum AIIntentEngine {
    public static func intentSummaries(in universe: Universe) -> [AIIntentSummary] {
        universe.factions
            .filter { $0.kind == .ai && $0.id != universe.playerFactionID }
            .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
            .map { intentSummary(for: $0, in: universe) }
    }

    public static func highestPlayerThreat(in universe: Universe) -> AIIntentSummary? {
        let playerRelations = universe.factions.first { $0.id == universe.playerFactionID }?.relations ?? []
        let threatByFactionID = Dictionary(uniqueKeysWithValues: playerRelations.map { ($0.factionID, $0.threatScore) })

        return intentSummaries(in: universe)
            .filter { (threatByFactionID[$0.factionID] ?? 0) > 0 || $0.priority >= .warning }
            .sorted { lhs, rhs in
                let lhsThreat = threatByFactionID[lhs.factionID] ?? 0
                let rhsThreat = threatByFactionID[rhs.factionID] ?? 0
                if lhsThreat != rhsThreat {
                    return lhsThreat > rhsThreat
                }
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.factionID.rawValue.uuidString < rhs.factionID.rawValue.uuidString
            }
            .first
    }

    private static func intentSummary(for faction: Faction, in universe: Universe) -> AIIntentSummary {
        let planets = universe.planets.filter { $0.ownerID == faction.id }
        let activeFleet = universe.fleets.first { $0.ownerID == faction.id && $0.phase != .completed }
        let threatScore = faction.relations.map(\.threatScore).max() ?? 0
        let ships = summedShips(on: planets)
        let knownDebris = StrategicEngine.explorationRecords(for: faction.id, in: universe)
            .contains { ($0.discoveredDebris.metal + $0.discoveredDebris.crystal) > 0 }

        if let activeFleet {
            return AIIntentSummary(
                factionID: faction.id,
                factionName: faction.name,
                intent: intent(for: activeFleet.mission),
                title: "\(faction.name) 正在\(activeFleet.mission.localizedName)",
                detail: "已有舰队在途，目标 \(activeFleet.target.displayText)。",
                priority: activeFleet.mission == .attack ? .warning : .info
            )
        }

        if threatScore > 0 {
            return AIIntentSummary(
                factionID: faction.id,
                factionName: faction.name,
                intent: .defend,
                title: "\(faction.name) 转入防御",
                detail: "近期威胁记忆为 \(threatScore)，更可能补防御并寻找反击窗口。",
                priority: .warning
            )
        }

        if knownDebris, (ships[.recycler] ?? 0) > 0 {
            return AIIntentSummary(
                factionID: faction.id,
                factionName: faction.name,
                intent: .recycle,
                title: "\(faction.name) 盯上残骸",
                detail: "已知残骸和回收船同时存在，可能优先抢残骸收益。",
                priority: .opportunity
            )
        }

        if faction.strategy == .expansionist {
            return AIIntentSummary(
                factionID: faction.id,
                factionName: faction.name,
                intent: .expand,
                title: "\(faction.name) 准备扩张",
                detail: "扩张型 AI 会优先侦察中立星位并准备殖民船。",
                priority: .opportunity
            )
        }

        if faction.strategy == .raider, combatShipCount(ships) >= 4 {
            return AIIntentSummary(
                factionID: faction.id,
                factionName: faction.name,
                intent: .raid,
                title: "\(faction.name) 有掠袭倾向",
                detail: "已有基础战斗舰，侦察到弱点后可能发动攻击。",
                priority: .warning
            )
        }

        if (ships[.espionageProbe] ?? 0) > 0 {
            return AIIntentSummary(
                factionID: faction.id,
                factionName: faction.name,
                intent: .scout,
                title: "\(faction.name) 正在找情报",
                detail: "探测器可用，下一步通常是侦察玩家或其他 AI 星球。",
                priority: .info
            )
        }

        return AIIntentSummary(
            factionID: faction.id,
            factionName: faction.name,
            intent: planets.isEmpty ? .idle : .buildUp,
            title: "\(faction.name) 积累实力",
            detail: "当前更可能继续补经济、造船或防御。",
            priority: .info
        )
    }

    private static func intent(for mission: Fleet.Mission) -> AIIntentSummary.Intent {
        switch mission {
        case .transport, .defend, .returning:
            return .defend
        case .colonize:
            return .expand
        case .espionage:
            return .scout
        case .attack:
            return .raid
        case .recycle:
            return .recycle
        case .explore:
            return .scout
        }
    }

    private static func summedShips(on planets: [Planet]) -> [ShipKind: Int] {
        planets.reduce(into: [ShipKind: Int]()) { result, planet in
            for (kind, quantity) in planet.shipInventory {
                result[kind, default: 0] += max(quantity, 0)
            }
        }
    }

    private static func combatShipCount(_ ships: [ShipKind: Int]) -> Int {
        ships.reduce(0) { total, element in
            total + (isCombatShip(element.key) ? max(element.value, 0) : 0)
        }
    }

    private static func isCombatShip(_ kind: ShipKind) -> Bool {
        switch kind {
        case .lightFighter, .heavyFighter, .cruiser, .battleship, .battlecruiser, .bomber, .destroyer, .deathstar:
            return true
        case .smallCargo, .largeCargo, .colonyShip, .recycler, .espionageProbe, .solarSatellite:
            return false
        }
    }
}
