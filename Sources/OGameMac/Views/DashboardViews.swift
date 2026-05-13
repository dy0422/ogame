import OGameCore
import SwiftUI

struct CommanderBriefingPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "指挥官简报", detail: "下一步建议")

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), alignment: .topLeading)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(model.commanderBriefingItems) { item in
                        CommanderBriefingCard(item: item)
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

struct StrategicAdvisorPanel: View {
    @ObservedObject var model: AppModel

    private var recommendations: [StrategicAdvisorRecommendation] {
        model.strategicAdvisorRecommendations
    }

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "战略顾问", detail: "经济、舰队与殖民机会")

                if recommendations.isEmpty {
                    Label("暂无紧急建议", systemImage: "checkmark.seal")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(recommendations) { recommendation in
                            StrategicAdvisorRow(recommendation: recommendation) {
                                navigate(to: recommendation)
                            }

                            if recommendation.id != recommendations.last?.id {
                                Divider()
                                    .padding(.leading, 42)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }

    private func navigate(to recommendation: StrategicAdvisorRecommendation) {
        switch recommendation.kind {
        case .crisis, .hostileSite, .actionChain:
            model.selectedDestination = .fleets
        case .sectorEvent:
            model.selectedDestination = .starMap
        case .tradeRoute:
            model.selectedDestination = .dashboard
        case .deepIntel:
            model.selectedDestination = .relations
        case .artifact:
            model.selectedDestination = .victory
        case .commanderRecruitment, .commanderTraining, .commanderAssignment:
            model.selectedDestination = .commanders
        case .victoryRoute:
            model.selectedDestination = .victory
        case .aiThreat:
            model.selectedDestination = .relations
        case .energyDeficit, .storagePressure, .idleConstruction:
            if let planetID = recommendation.planetID {
                model.selectedDestination = .planet(planetID)
            }
        case .idleResearch:
            model.selectedDestination = .research
        case .debrisRecovery, .colonyWindow:
            model.selectedDestination = .starMap
        case .expeditionWindow, .fleetSafety:
            model.selectedDestination = .fleets
        case .combatReview:
            model.selectedDestination = .fleets
        }
    }
}

struct ActionChainRewardsPanel: View {
    @ObservedObject var model: AppModel

    private var summaries: [ActionChainSummary] {
        model.actionChainSummaries
    }

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "行动链奖励", detail: "PVE 据点与星区任务")

                if summaries.isEmpty {
                    Label("暂无可追踪行动链", systemImage: "checklist.unchecked")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(summaries) { summary in
                            ActionChainRewardRow(summary: summary) {
                                model.claimActionChainReward(summary.id)
                            }

                            if summary.id != summaries.last?.id {
                                Divider()
                                    .padding(.leading, 42)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

private struct StrategicAdvisorRow: View {
    let recommendation: StrategicAdvisorRecommendation
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: recommendation.kind.systemImage)
                .font(.headline)
                .foregroundStyle(recommendation.priority.tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(recommendation.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(recommendation.priority.localizedName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(recommendation.priority.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(recommendation.priority.tint.opacity(0.1), in: Capsule())
                }

                Text(recommendation.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            Button(action: action) {
                Label(recommendation.actionLabel, systemImage: "arrow.right")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct ActionChainRewardRow: View {
    let summary: ActionChainSummary
    let claim: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: summary.canClaim ? "checkmark.seal.fill" : "lock.open.trianglebadge.exclamationmark")
                .font(.headline)
                .foregroundStyle(summary.canClaim ? Color.green : Color.orange)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(summary.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(summary.statusText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(summary.canClaim ? Color.green : Color.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((summary.canClaim ? Color.green : Color.orange).opacity(0.1), in: Capsule())
                }

                Text(summary.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 3) {
                    Label(summary.rewardText, systemImage: "shippingbox")
                    Label(summary.commanderRewardText, systemImage: "person.crop.circle.badge.plus")
                    Label(summary.stepText, systemImage: "list.bullet.rectangle")
                    Label(summary.timeText, systemImage: "timer")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 10)

            Button(action: claim) {
                Label("领取", systemImage: "tray.and.arrow.down")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!summary.canClaim)
            .help(summary.canClaim ? "领取行动链奖励" : "条件未满足，暂时不能领取")
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct CommandCenterStrip: View {
    @ObservedObject var model: AppModel

    private var primaryPlanet: Planet? {
        model.playerPlanets.first
    }

    private var buildQueueCount: Int {
        model.playerPlanets.reduce(0) { $0 + $1.buildQueue.count }
    }

    private var researchQueueCount: Int {
        model.playerFaction?.researchQueue.count ?? 0
    }

    var body: some View {
        PanelSurface {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), alignment: .topLeading)],
                alignment: .leading,
                spacing: 10
            ) {
                GameMetricTile(
                    title: "托管升级",
                    value: model.settings.isAutoUpgradeEnabled ? "开启" : "关闭",
                    systemImage: "wand.and.stars",
                    tint: model.settings.isAutoUpgradeEnabled ? .green : .secondary
                )
                GameMetricTile(
                    title: "建筑队列",
                    value: buildQueueCount == 0 ? "空闲" : "\(buildQueueCount)",
                    systemImage: "hammer",
                    tint: buildQueueCount == 0 ? .orange : .blue
                )
                GameMetricTile(
                    title: "研究队列",
                    value: researchQueueCount == 0 ? "空闲" : "\(researchQueueCount)",
                    systemImage: "atom",
                    tint: researchQueueCount == 0 ? .orange : .purple
                )

                if let primaryPlanet {
                    let energyRatio = model.energySupplyRatio(for: primaryPlanet)
                    GameMetricTile(
                        title: "能源效率",
                        value: Formatters.percent(energyRatio),
                        systemImage: "bolt.fill",
                        tint: primaryPlanet.energy.available >= 0 ? .green : .red
                    )
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

private struct CommanderBriefingCard: View {
    let item: CommanderBriefingItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.systemImage)
                .foregroundStyle(item.urgency.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(item.urgency.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(item.urgency.tint.opacity(0.16))
        }
    }
}

struct VictorySettlementPanel: View {
    let summary: VictorySettlementSummary
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: summary.isPlayerVictory ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(summary.isPlayerVictory ? Color.green : Color.orange)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.title)
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(summary.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Label(summary.routeText, systemImage: "flag")
                        Label(summary.timeText, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Button {
                    model.startNewGame()
                } label: {
                    Label("重新开局", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

extension BriefingUrgency {
    var tint: Color {
        switch self {
        case .info:
            return .blue
        case .good:
            return .green
        case .warning:
            return .orange
        }
    }
}

private extension StrategicAdvisorRecommendation.Kind {
    var systemImage: String {
        switch self {
        case .crisis:
            return "exclamationmark.triangle.fill"
        case .hostileSite:
            return "scope"
        case .sectorEvent:
            return "sparkle.magnifyingglass"
        case .actionChain:
            return "checklist"
        case .tradeRoute:
            return "arrow.left.arrow.right.circle"
        case .deepIntel:
            return "antenna.radiowaves.left.and.right"
        case .artifact:
            return "shippingbox.and.arrow.backward"
        case .commanderRecruitment:
            return "person.crop.circle.badge.plus"
        case .commanderTraining:
            return "arrow.up.forward.circle"
        case .commanderAssignment:
            return "person.crop.rectangle.stack"
        case .victoryRoute:
            return "flag.checkered"
        case .aiThreat:
            return "exclamationmark.shield"
        case .energyDeficit:
            return "bolt.trianglebadge.exclamationmark"
        case .storagePressure:
            return "archivebox"
        case .idleConstruction:
            return "hammer"
        case .idleResearch:
            return "atom"
        case .debrisRecovery:
            return "arrow.triangle.2.circlepath"
        case .colonyWindow:
            return "globe.europe.africa"
        case .expeditionWindow:
            return "sparkles"
        case .fleetSafety:
            return "shield.lefthalf.filled"
        case .combatReview:
            return "doc.text.magnifyingglass"
        }
    }
}

private extension StrategicAdvisorRecommendation.Priority {
    var localizedName: String {
        switch self {
        case .critical:
            return "紧急"
        case .warning:
            return "注意"
        case .opportunity:
            return "机会"
        case .info:
            return "提示"
        }
    }

    var tint: Color {
        switch self {
        case .critical:
            return .red
        case .warning:
            return .orange
        case .opportunity:
            return .blue
        case .info:
            return .green
        }
    }
}
