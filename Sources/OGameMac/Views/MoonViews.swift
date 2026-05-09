import OGameCore
import SwiftUI

struct MoonSummaryCard: View {
    let planet: Planet
    let moon: Moon
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            HStack(alignment: .top, spacing: 14) {
                ServerAssetThumbnail(
                    url: GameArt.moonImageURL,
                    fallbackSystemImage: "moon.stars",
                    size: 72
                )

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "月球", detail: moon.name.displayName)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160), alignment: .topLeading)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        DispatchMetric(title: "创建时间", value: "T+\(Formatters.wholeSeconds(moon.createdAt))")
                        DispatchMetric(title: "设施", value: Formatters.wholeNumber(Double(moon.buildingLevels.values.reduce(0, +))))
                        ForEach(model.availableMoonFacilityKinds, id: \.self) { facility in
                            HStack {
                                DispatchMetric(
                                    title: facility.localizedName,
                                    value: "等级 \(moon.buildingLevels[facility, default: 0])"
                                )
                                Spacer(minLength: 8)
                                Button {
                                    model.startMoonFacilityUpgrade(planetID: planet.id, kind: facility)
                                } label: {
                                    Label("升级", systemImage: "arrow.up.circle")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("升级\(facility.localizedName)")
                            }
                        }
                    }

                    MoonActionPanel(planet: planet, model: model)
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }
}

private struct MoonActionPanel: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    private var scans: [MoonScanSummary] {
        model.moonSensorScanSummaries(from: planet.id)
    }

    private var jumpTargets: [MoonJumpTargetSummary] {
        model.moonJumpTargets(from: planet.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "月球行动", detail: actionDetail)

            if scans.isEmpty && jumpTargets.isEmpty {
                QueueEmptyLine(title: "升级感应阵或跳跃门后可执行月球行动", systemImage: "moon.stars")
            } else {
                if !scans.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(scans.prefix(4))) { scan in
                            MoonScanRow(scan: scan)

                            if scan.id != scans.prefix(4).last?.id {
                                Divider()
                            }
                        }
                    }
                }

                if !jumpTargets.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180), alignment: .topLeading)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(jumpTargets) { target in
                            MoonJumpTargetButton(originID: planet.id, target: target, model: model)
                        }
                    }
                }
            }
        }
    }

    private var actionDetail: String {
        let scanText = scans.isEmpty ? "无扫描" : "\(scans.count) 支舰队"
        let jumpText = jumpTargets.isEmpty ? "无跳跃目标" : "\(jumpTargets.count) 座门"
        return "\(scanText) · \(jumpText)"
    }
}

private struct MoonScanRow: View {
    let scan: MoonScanSummary

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(.purple)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(scan.missionText)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    Text(scan.phaseText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(scan.remainingText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(scan.targetName) · \(scan.routeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 7)
    }
}

private struct MoonJumpTargetButton: View {
    let originID: PlanetID
    let target: MoonJumpTargetSummary
    @ObservedObject var model: AppModel

    var body: some View {
        Button {
            model.jumpOneShipThroughGate(from: originID, to: target.planetID)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.swap")
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(target.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text("\(target.coordinateText) · \(target.readyText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!model.canJumpOneShipThroughGate(from: originID, to: target.planetID))
        .help("通过跳跃门转移 1 艘舰船")
    }
}
