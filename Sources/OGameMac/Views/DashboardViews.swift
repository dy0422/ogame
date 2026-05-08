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
