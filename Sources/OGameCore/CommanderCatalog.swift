public struct CommanderDefinition: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var title: String
    public var rarity: CommanderRarity
    public var specialty: CommanderSpecialty
    public var lore: String

    public init(
        id: String,
        name: String,
        title: String,
        rarity: CommanderRarity,
        specialty: CommanderSpecialty,
        lore: String
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.rarity = rarity
        self.specialty = specialty
        self.lore = lore
    }
}

public enum CommanderCatalog {
    public static let definitions: [CommanderDefinition] = [
        CommanderDefinition(id: "lin-vanguard", name: "林远航", title: "先锋舰队上将", rarity: .legendary, specialty: .fleetAdmiral, lore: "擅长高速突袭和多波舰队协同。"),
        CommanderDefinition(id: "qiao-reactor", name: "乔映辉", title: "反应堆工程师", rarity: .epic, specialty: .engineer, lore: "把舰队护盾和能源管理压到极限。"),
        CommanderDefinition(id: "shen-surveyor", name: "沈玄石", title: "深空地质专家", rarity: .epic, specialty: .geologist, lore: "能从残骸和贸易航线里榨出更多价值。"),
        CommanderDefinition(id: "xie-technocrat", name: "谢穹", title: "星链技术官", rarity: .epic, specialty: .technocrat, lore: "擅长探测窗口和火控校准。"),
        CommanderDefinition(id: "mira-pathfinder", name: "米拉", title: "远征领航员", rarity: .elite, specialty: .explorer, lore: "熟悉外太空异常和返航窗口。"),
        CommanderDefinition(id: "han-shield", name: "韩盾", title: "护航军官", rarity: .elite, specialty: .engineer, lore: "稳健的护航和损管专家。"),
        CommanderDefinition(id: "rao-raider", name: "饶锋", title: "掠袭队长", rarity: .elite, specialty: .fleetAdmiral, lore: "偏爱短航程打击和快速回收。"),
        CommanderDefinition(id: "xu-miner", name: "许砾", title: "矿务协调员", rarity: .common, specialty: .geologist, lore: "能稳定提升基础运输收益。"),
        CommanderDefinition(id: "lu-scout", name: "陆遥", title: "侦察军士", rarity: .common, specialty: .technocrat, lore: "给探测器分队提供简易校准。"),
        CommanderDefinition(id: "tang-pilot", name: "唐星", title: "航路飞行员", rarity: .common, specialty: .explorer, lore: "熟悉近地星系航线。")
    ]

    public static func definition(id: String) -> CommanderDefinition? {
        definitions.first { $0.id == id }
    }
}
