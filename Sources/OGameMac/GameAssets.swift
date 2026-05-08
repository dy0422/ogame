import AppKit
import Foundation
import OGameCore
import SwiftUI

enum GameResourceArt {
    case metal
    case crystal
    case deuterium
    case energy
}

enum GameArt {
    static var moonImageURL: URL? {
        assetURL("planeten/mond.jpg")
    }

    static var debrisImageURL: URL? {
        assetURL("planeten/debris.jpg")
    }

    static func resourceImageURL(_ resource: GameResourceArt) -> URL? {
        switch resource {
        case .metal:
            return assetURL("images/metall.gif")
        case .crystal:
            return assetURL("images/kristall.gif")
        case .deuterium:
            return assetURL("images/deuterium.gif")
        case .energy:
            return assetURL("images/energie.gif")
        }
    }

    static func planetImageURL(for planet: Planet, small: Bool = false) -> URL? {
        let families = planetImageFamilies
        let seed = abs(planet.coordinate.galaxy * 97 + planet.coordinate.system * 31 + planet.coordinate.position * 11)
        let family = families[seed % families.count]
        let index = (seed % family.count) + 1
        let fileName = "\(small ? "s_" : "")\(family.name)\(Self.twoDigit(index)).jpg"
        let prefix = small ? "planeten/small" : "planeten"
        return assetURL("\(prefix)/\(fileName)")
    }

    static func imageURL(for kind: BuildingKind) -> URL? {
        buildingAssetIDs[kind].flatMap { gebaeudeURL($0) }
    }

    static func imageURL(for technology: TechnologyKind) -> URL? {
        technologyAssetIDs[technology].flatMap { gebaeudeURL($0) }
    }

    static func imageURL(for kind: ShipKind) -> URL? {
        shipAssetIDs[kind].flatMap { gebaeudeURL($0) }
    }

    static func imageURL(for kind: DefenseKind) -> URL? {
        defenseAssetIDs[kind].flatMap { gebaeudeURL($0) }
    }

    static func imageURL(for kind: MissileKind) -> URL? {
        missileAssetIDs[kind].flatMap { gebaeudeURL($0) }
    }

    static func imageURL(for unitKind: UnitBuildQueueItem.UnitKind) -> URL? {
        switch unitKind {
        case .ship(let kind):
            return imageURL(for: kind)
        case .defense(let kind):
            return imageURL(for: kind)
        case .missile(let kind):
            return imageURL(for: kind)
        }
    }

    static func inventoryImageURL(for rawValue: String) -> URL? {
        rawValueAssetIDs[rawValue].flatMap { gebaeudeURL($0) }
    }

    private static func gebaeudeURL(_ assetID: Int) -> URL? {
        assetURL("gebaeude/\(assetID).gif")
    }

    private static func assetURL(_ relativePath: String) -> URL? {
        for root in assetRoots {
            let candidate = root.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private static var assetRoots: [URL] {
        var roots: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            roots.append(resourceURL.appendingPathComponent("skins/xnova", isDirectory: true))
        }

        roots.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("skins/xnova", isDirectory: true))

        roots.append(URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("skins/xnova", isDirectory: true))

        return roots
    }

    private static func twoDigit(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    private static let planetImageFamilies: [(name: String, count: Int)] = [
        ("normaltempplanet", 7),
        ("wasserplanet", 7),
        ("eisplanet", 10),
        ("trockenplanet", 10),
        ("wuestenplanet", 4),
        ("dschjungelplanet", 10),
        ("gasplanet", 8)
    ]

    private static let buildingAssetIDs: [BuildingKind: Int] = [
        .metalMine: 1,
        .crystalMine: 2,
        .deuteriumSynthesizer: 3,
        .solarPlant: 4,
        .roboticsFactory: 14,
        .naniteFactory: 15,
        .shipyard: 21,
        .metalStorage: 22,
        .crystalStorage: 23,
        .deuteriumTank: 24,
        .researchLab: 31
    ]

    private static let technologyAssetIDs: [TechnologyKind: Int] = [
        .espionage: 106,
        .computer: 108,
        .weapons: 109,
        .shielding: 110,
        .armor: 111,
        .energy: 113,
        .combustionDrive: 115,
        .impulseDrive: 117,
        .hyperspaceDrive: 118
    ]

    private static let shipAssetIDs: [ShipKind: Int] = [
        .smallCargo: 202,
        .largeCargo: 203,
        .lightFighter: 204,
        .heavyFighter: 205,
        .cruiser: 206,
        .battleship: 207,
        .colonyShip: 208,
        .recycler: 209,
        .espionageProbe: 210
    ]

    private static let defenseAssetIDs: [DefenseKind: Int] = [
        .rocketLauncher: 401,
        .lightLaser: 402,
        .heavyLaser: 403,
        .gaussCannon: 404,
        .ionCannon: 405,
        .plasmaTurret: 406
    ]

    private static let missileAssetIDs: [MissileKind: Int] = [
        .interplanetaryMissile: 503
    ]

    private static let rawValueAssetIDs: [String: Int] =
        Dictionary(uniqueKeysWithValues: buildingAssetIDs.map { ($0.key.rawValue, $0.value) }) +
        Dictionary(uniqueKeysWithValues: technologyAssetIDs.map { ($0.key.rawValue, $0.value) }) +
        Dictionary(uniqueKeysWithValues: shipAssetIDs.map { ($0.key.rawValue, $0.value) }) +
        Dictionary(uniqueKeysWithValues: defenseAssetIDs.map { ($0.key.rawValue, $0.value) }) +
        Dictionary(uniqueKeysWithValues: missileAssetIDs.map { ($0.key.rawValue, $0.value) })
}

struct ServerAssetImage: View {
    let url: URL?
    let fallbackSystemImage: String
    var contentMode: ContentMode = .fit

    var body: some View {
        Group {
            if let url, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: fallbackSystemImage)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
    }
}

struct ServerAssetThumbnail: View {
    let url: URL?
    let fallbackSystemImage: String
    var size: CGFloat = 44
    var contentMode: ContentMode = .fill

    var body: some View {
        ServerAssetImage(
            url: url,
            fallbackSystemImage: fallbackSystemImage,
            contentMode: contentMode
        )
        .frame(width: size, height: size)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.secondary.opacity(0.18))
        }
    }
}

private func + <Key, Value>(
    lhs: [Key: Value],
    rhs: [Key: Value]
) -> [Key: Value] where Key: Hashable {
    lhs.merging(rhs) { current, _ in current }
}
