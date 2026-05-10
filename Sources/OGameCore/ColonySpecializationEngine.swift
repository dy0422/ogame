public struct ColonySpecialization: Equatable, Sendable {
    public enum Role: String, Codable, Equatable, Sendable {
        case solarOutpost
        case coreWorld
        case deuteriumWorld
        case shipyardHub
        case researchCampus
        case moonBase
        case marginalColony
    }

    public var role: Role
    public var title: String
    public var detail: String
    public var coordinate: Coordinate
    public var slotProfile: UniverseTopologyEngine.ColonySlotProfile
    public var maxFields: Int
    public var usedFields: Int
    public var fieldUsageRatio: Double
    public var temperatureCelsius: Double
    public var recommendedBuildings: [BuildingKind]
    public var warnings: [ColonySpecializationWarning]

    public init(
        role: Role,
        title: String,
        detail: String,
        coordinate: Coordinate,
        slotProfile: UniverseTopologyEngine.ColonySlotProfile,
        maxFields: Int,
        usedFields: Int,
        fieldUsageRatio: Double,
        temperatureCelsius: Double,
        recommendedBuildings: [BuildingKind],
        warnings: [ColonySpecializationWarning]
    ) {
        self.role = role
        self.title = title
        self.detail = detail
        self.coordinate = coordinate
        self.slotProfile = slotProfile
        self.maxFields = max(maxFields, 1)
        self.usedFields = max(usedFields, 0)
        self.fieldUsageRatio = Self.normalizedRatio(fieldUsageRatio)
        self.temperatureCelsius = temperatureCelsius.isFinite ? temperatureCelsius : 40
        self.recommendedBuildings = recommendedBuildings
        self.warnings = warnings
    }

    private static func normalizedRatio(_ ratio: Double) -> Double {
        guard ratio.isFinite else {
            return 0
        }

        return min(max(ratio, 0), 1)
    }
}

public struct ColonySpecializationWarning: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case lowFields
        case hotDeuterium
        case coldSolar
        case crowdedFields
        case missingShipyard
        case missingResearchLab
        case noMoon
    }

    public var kind: Kind
    public var title: String
    public var detail: String

    public var id: String {
        kind.rawValue
    }

    public init(kind: Kind, title: String, detail: String) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

public enum ColonySpecializationEngine {
    public static func specialization(for planet: Planet) -> ColonySpecialization {
        let slotProfile = UniverseTopologyEngine.colonySlotProfile(forPosition: planet.coordinate.position)
        let usedFields = fieldUsage(on: planet)
        let maxFields = max(planet.maxFields, 1)
        let fieldUsageRatio = Double(usedFields) / Double(maxFields)
        let role = role(
            for: planet,
            profile: slotProfile,
            maxFields: maxFields,
            fieldUsageRatio: fieldUsageRatio
        )

        return makeSpecialization(
            role: role,
            coordinate: planet.coordinate,
            slotProfile: slotProfile,
            maxFields: maxFields,
            usedFields: usedFields,
            fieldUsageRatio: fieldUsageRatio,
            temperatureCelsius: planet.temperatureCelsius,
            hasMoon: planet.moon != nil,
            buildingLevels: planet.buildingLevels
        )
    }

    public static func preview(for coordinate: Coordinate, universeSeed: UInt64) -> ColonySpecialization {
        let profile = UniverseTopologyEngine.planetProfile(for: coordinate, universeSeed: universeSeed)
        let slotProfile = UniverseTopologyEngine.colonySlotProfile(forPosition: coordinate.position)
        let role = previewRole(
            for: coordinate,
            profile: slotProfile,
            maxFields: profile.maxFields,
            temperatureCelsius: profile.temperatureCelsius
        )

        return makeSpecialization(
            role: role,
            coordinate: coordinate,
            slotProfile: slotProfile,
            maxFields: profile.maxFields,
            usedFields: 0,
            fieldUsageRatio: 0,
            temperatureCelsius: profile.temperatureCelsius,
            hasMoon: false,
            buildingLevels: [:]
        )
    }

    private static func role(
        for planet: Planet,
        profile: UniverseTopologyEngine.ColonySlotProfile,
        maxFields: Int,
        fieldUsageRatio: Double
    ) -> ColonySpecialization.Role {
        if let moon = planet.moon,
           moon.buildingLevels.contains(where: { $0.key.isMoonFacility && normalizedLevel($0.value) > 0 }) {
            return .moonBase
        }

        let shipyardLevel = normalizedLevel(planet.buildingLevels[.shipyard] ?? 0)
        let naniteLevel = normalizedLevel(planet.buildingLevels[.naniteFactory] ?? 0)
        if shipyardLevel >= 6 || (shipyardLevel >= 4 && naniteLevel >= 1) {
            return .shipyardHub
        }

        if normalizedLevel(planet.buildingLevels[.researchLab] ?? 0) >= 7 {
            return .researchCampus
        }

        if maxFields < 115 && fieldUsageRatio >= 0.55 {
            return .marginalColony
        }

        return slotRole(
            position: planet.coordinate.position,
            profile: profile,
            temperatureCelsius: planet.temperatureCelsius,
            maxFields: maxFields
        )
    }

    private static func previewRole(
        for coordinate: Coordinate,
        profile: UniverseTopologyEngine.ColonySlotProfile,
        maxFields: Int,
        temperatureCelsius: Double
    ) -> ColonySpecialization.Role {
        slotRole(
            position: coordinate.position,
            profile: profile,
            temperatureCelsius: temperatureCelsius,
            maxFields: maxFields
        )
    }

    private static func slotRole(
        position: Int,
        profile: UniverseTopologyEngine.ColonySlotProfile,
        temperatureCelsius: Double,
        maxFields: Int
    ) -> ColonySpecialization.Role {
        if position <= 3 || temperatureCelsius >= 70 {
            return .solarOutpost
        }

        if position >= 12 || temperatureCelsius <= -45 {
            return .deuteriumWorld
        }

        if maxFields < 120 || profile.fieldFactor < 0.7 {
            return .marginalColony
        }

        return .coreWorld
    }

    private static func makeSpecialization(
        role: ColonySpecialization.Role,
        coordinate: Coordinate,
        slotProfile: UniverseTopologyEngine.ColonySlotProfile,
        maxFields: Int,
        usedFields: Int,
        fieldUsageRatio: Double,
        temperatureCelsius: Double,
        hasMoon: Bool,
        buildingLevels: [BuildingKind: Int]
    ) -> ColonySpecialization {
        ColonySpecialization(
            role: role,
            title: role.localizedTitle,
            detail: detail(for: role, slotProfile: slotProfile),
            coordinate: coordinate,
            slotProfile: slotProfile,
            maxFields: maxFields,
            usedFields: usedFields,
            fieldUsageRatio: fieldUsageRatio,
            temperatureCelsius: temperatureCelsius,
            recommendedBuildings: recommendedBuildings(for: role),
            warnings: warnings(
                role: role,
                slotProfile: slotProfile,
                maxFields: maxFields,
                fieldUsageRatio: fieldUsageRatio,
                temperatureCelsius: temperatureCelsius,
                hasMoon: hasMoon,
                buildingLevels: buildingLevels
            )
        )
    }

    private static func fieldUsage(on planet: Planet) -> Int {
        Set(planet.buildingLevels.filter { normalizedLevel($0.value) > 0 }.map(\.key))
            .union(planet.buildQueue.map(\.buildingKind))
            .filter { !$0.isMoonFacility }
            .count
    }

    private static func recommendedBuildings(for role: ColonySpecialization.Role) -> [BuildingKind] {
        let priority: [BuildingKind]
        switch role {
        case .solarOutpost:
            priority = [.solarPlant, .metalMine, .crystalMine, .metalStorage]
        case .coreWorld:
            priority = [.metalMine, .crystalMine, .deuteriumSynthesizer, .researchLab, .roboticsFactory]
        case .deuteriumWorld:
            priority = [.deuteriumSynthesizer, .fusionReactor, .deuteriumTank, .solarPlant]
        case .shipyardHub:
            priority = [.shipyard, .naniteFactory, .roboticsFactory, .missileSilo]
        case .researchCampus:
            priority = [.researchLab, .roboticsFactory, .naniteFactory, .deuteriumTank]
        case .moonBase:
            priority = [.lunarBase, .sensorPhalanx, .jumpGate]
        case .marginalColony:
            priority = [.metalMine, .crystalMine, .solarPlant, .metalStorage]
        }

        return priority.deduplicated()
    }

    private static func warnings(
        role: ColonySpecialization.Role,
        slotProfile: UniverseTopologyEngine.ColonySlotProfile,
        maxFields: Int,
        fieldUsageRatio: Double,
        temperatureCelsius: Double,
        hasMoon: Bool,
        buildingLevels: [BuildingKind: Int]
    ) -> [ColonySpecializationWarning] {
        var result: [ColonySpecializationWarning] = []

        if maxFields < 130 || slotProfile.fieldFactor < 0.72 {
            result.append(
                ColonySpecializationWarning(
                    kind: .lowFields,
                    title: "方圆偏小",
                    detail: "适合短期能源、重氢或专项用途，长期主星需要控制建筑选择。"
                )
            )
        }

        if fieldUsageRatio >= 0.8 {
            result.append(
                ColonySpecializationWarning(
                    kind: .crowdedFields,
                    title: "方圆紧张",
                    detail: "已接近可用方圆上限，继续扩张前优先判断是否值得长期保留。"
                )
            )
        }

        if temperatureCelsius >= 70 {
            result.append(
                ColonySpecializationWarning(
                    kind: .hotDeuterium,
                    title: "重氢偏弱",
                    detail: "高温星球重氢效率低，更适合太阳能、早期矿场或前哨用途。"
                )
            )
        }

        if temperatureCelsius <= -50 {
            result.append(
                ColonySpecializationWarning(
                    kind: .coldSolar,
                    title: "太阳能偏弱",
                    detail: "低温星位重氢更强，但太阳能卫星和太阳能发电效率较弱。"
                )
            )
        }

        if role == .shipyardHub && normalizedLevel(buildingLevels[.naniteFactory] ?? 0) == 0 {
            result.append(
                ColonySpecializationWarning(
                    kind: .missingShipyard,
                    title: "缺少纳米",
                    detail: "造船核心需要纳米工厂支撑，否则中后期补舰速度会被拖慢。"
                )
            )
        }

        if role == .researchCampus && normalizedLevel(buildingLevels[.researchLab] ?? 0) < 9 {
            result.append(
                ColonySpecializationWarning(
                    kind: .missingResearchLab,
                    title: "科研纵深不足",
                    detail: "科研星应继续提高研究实验室，形成稳定科技路线。"
                )
            )
        }

        if (role == .coreWorld || role == .shipyardHub || role == .researchCampus) && !hasMoon {
            result.append(
                ColonySpecializationWarning(
                    kind: .noMoon,
                    title: "尚无月球",
                    detail: "后期主力星拥有月球后，感应阵、跳跃门和舰队保存会更完整。"
                )
            )
        }

        return result.deduplicatedByKind()
    }

    private static func detail(
        for role: ColonySpecialization.Role,
        slotProfile: UniverseTopologyEngine.ColonySlotProfile
    ) -> String {
        switch role {
        case .solarOutpost:
            return "靠近恒星，能源表现突出；适合快节奏开局、太阳能卫星和轻量资源前哨。"
        case .coreWorld:
            return "方圆较宽，资源路线均衡；适合作为长期主矿、科研和后勤中心。"
        case .deuteriumWorld:
            return "低温强化重氢产出；适合供给远征、舰队燃料和高阶研究。"
        case .shipyardHub:
            return "造船设施已经成型；适合集中纳米、导弹井和主力舰队补充。"
        case .researchCampus:
            return "科研基础突出；适合堆高研究实验室并承接关键科技升级。"
        case .moonBase:
            return "月面设施已形成战略价值；适合扩展感应阵、跳跃门和舰队保存能力。"
        case .marginalColony:
            return "\(slotProfile.strategyHint) 方圆偏紧，建议作为专项星或未来替换候选。"
        }
    }

    private static func normalizedLevel(_ level: Int) -> Int {
        max(level, 0)
    }
}

public extension ColonySpecialization.Role {
    var localizedTitle: String {
        switch self {
        case .solarOutpost:
            return "太阳前哨"
        case .coreWorld:
            return "核心主星"
        case .deuteriumWorld:
            return "重氢冷星"
        case .shipyardHub:
            return "造船核心"
        case .researchCampus:
            return "科研学院"
        case .moonBase:
            return "月面基地"
        case .marginalColony:
            return "专项殖民地"
        }
    }
}

private extension Array where Element == BuildingKind {
    func deduplicated() -> [BuildingKind] {
        var seen: Set<BuildingKind> = []
        var result: [BuildingKind] = []
        for element in self where !seen.contains(element) {
            seen.insert(element)
            result.append(element)
        }
        return result
    }
}

private extension Array where Element == ColonySpecializationWarning {
    func deduplicatedByKind() -> [ColonySpecializationWarning] {
        var seen: Set<ColonySpecializationWarning.Kind> = []
        var result: [ColonySpecializationWarning] = []
        for warning in self where !seen.contains(warning.kind) {
            seen.insert(warning.kind)
            result.append(warning)
        }
        return result
    }
}
