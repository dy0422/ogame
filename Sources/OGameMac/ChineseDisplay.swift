import Foundation

extension String {
    var displayName: String {
        if let localized = ChineseDisplay.name(for: self) {
            return localized
        }
        if let localized = ChineseDisplay.dynamicName(for: self) {
            return localized
        }

        return reduce(into: "") { result, character in
            if character.isUppercase, !result.isEmpty {
                result.append(" ")
            }
            result.append(character)
        }
        .capitalized
    }
}

private enum ChineseDisplay {
    static func name(for rawValue: String) -> String? {
        switch rawValue {
        case "Fast Skirmish":
            return "快速遭遇战"
        case "fast-skirmish-v1":
            return "快速遭遇战"
        case "paused":
            return "暂停"
        case "reduced":
            return "低强度"
        case "normal", "standard":
            return "标准"
        case "intense":
            return "高强度"
        case "easy":
            return "简单"
        case "hard":
            return "困难"
        case "economy":
            return "经济"
        case "technology":
            return "科技"
        case "domination":
            return "统治"
        case "exploration", "explore":
            return "探索"
        case "neutral":
            return "中立"
        case "wary":
            return "警惕"
        case "hostile":
            return "敌对"
        case "pressured":
            return "受压"
        case "miner":
            return "矿工"
        case "raider":
            return "掠袭者"
        case "technologist":
            return "科研派"
        case "expansionist":
            return "扩张者"
        case "balanced":
            return "均衡"
        case "transport":
            return "运输"
        case "colonize":
            return "殖民"
        case "espionage":
            return "侦察"
        case "attack":
            return "攻击"
        case "recycle":
            return "回收"
        case "returning":
            return "返航"
        case "outbound":
            return "出航"
        case "holding":
            return "驻留"
        case "completed":
            return "完成"
        case "metalMine":
            return "金属矿"
        case "crystalMine":
            return "晶体矿"
        case "deuteriumSynthesizer":
            return "重氢合成厂"
        case "solarPlant":
            return "太阳能发电站"
        case "fusionReactor":
            return "聚变反应堆"
        case "roboticsFactory":
            return "机器人工厂"
        case "shipyard":
            return "造船厂"
        case "researchLab":
            return "研究实验室"
        case "metalStorage":
            return "金属仓库"
        case "crystalStorage":
            return "晶体仓库"
        case "deuteriumTank":
            return "重氢储罐"
        case "naniteFactory":
            return "纳米工厂"
        case "computer":
            return "计算机技术"
        case "astrophysics":
            return "天体物理学"
        case "weapons":
            return "武器技术"
        case "shielding":
            return "防御盾技术"
        case "armor":
            return "装甲技术"
        case "energy":
            return "能量技术"
        case "combustionDrive":
            return "燃烧引擎"
        case "impulseDrive":
            return "脉冲引擎"
        case "hyperspaceDrive":
            return "超空间引擎"
        case "smallCargo":
            return "小型运输舰"
        case "largeCargo":
            return "大型运输舰"
        case "lightFighter":
            return "轻型战斗机"
        case "heavyFighter":
            return "重型战斗机"
        case "cruiser":
            return "巡洋舰"
        case "battleship":
            return "战列舰"
        case "colonyShip":
            return "殖民船"
        case "recycler":
            return "回收船"
        case "espionageProbe":
            return "间谍探测器"
        case "solarSatellite":
            return "太阳能卫星"
        case "rocketLauncher":
            return "火箭发射器"
        case "lightLaser":
            return "轻型激光炮"
        case "heavyLaser":
            return "重型激光炮"
        case "gaussCannon":
            return "高斯炮"
        case "ionCannon":
            return "离子炮"
        case "plasmaTurret":
            return "等离子炮塔"
        case "interplanetaryMissile":
            return "星际导弹"
        default:
            return nil
        }
    }

    static func dynamicName(for rawValue: String) -> String? {
        if rawValue.hasPrefix("Unclaimed ") {
            return rawValue.replacingOccurrences(of: "Unclaimed ", with: "未占领 ")
        }
        if rawValue.hasPrefix("AI Economy Test") {
            return rawValue.replacingOccurrences(of: "AI Economy Test", with: "AI 经济测试")
        }
        if rawValue.hasPrefix("AI World ") {
            return rawValue.replacingOccurrences(of: "AI World ", with: "AI 星球 ")
        }
        if rawValue == "AI" {
            return "AI"
        }

        switch rawValue {
        case "Commander":
            return "指挥官"
        case "Homeworld":
            return "母星"
        case "Player":
            return "玩家"
        case "Player World":
            return "玩家星球"
        default:
            return nil
        }
    }
}
