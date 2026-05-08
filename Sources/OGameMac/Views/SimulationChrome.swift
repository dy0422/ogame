import SwiftUI

struct ActivityPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("活动")
                .font(.headline)

            Text(model.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let offlineSummaryText = model.offlineSummaryText {
                OfflineSummaryLine(summaryText: offlineSummaryText)
            }

            Divider()

            StatusMetric(title: "游戏时间", value: "T+\(Formatters.wholeSeconds(model.universe.gameTime))")
            StatusMetric(title: "势力", value: Formatters.wholeNumber(Double(model.universe.factions.count)))
            StatusMetric(title: "舰队", value: Formatters.wholeNumber(Double(model.universe.fleets.count)))
            StatusMetric(title: "存档", value: model.canSave ? model.autosaveStatusText : "受保护")
            StatusMetric(title: "设置", value: model.settingsStatusText)

            Spacer()
        }
        .padding(20)
        .frame(width: 280, alignment: .topLeading)
    }
}

struct SimulationCommandBar: View {
    @ObservedObject var model: AppModel

    private var speedBinding: Binding<Double> {
        Binding(
            get: { model.settings.gameSpeed },
            set: { model.updateGameSpeed($0) }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Label(model.runtimeStatusText, systemImage: model.isSimulationPaused ? "pause.circle" : "play.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(model.isSimulationPaused ? Color.orange : Color.green)
                .lineLimit(1)
                .frame(minWidth: 170, alignment: .leading)

            Divider()
                .frame(height: 22)

            Label(model.nextSimulationEventText, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            GameStatusPill(
                title: model.settings.isAutoUpgradeEnabled ? "托管开启" : "托管关闭",
                systemImage: "wand.and.stars",
                tint: model.settings.isAutoUpgradeEnabled ? .green : .secondary
            )

            Button {
                model.toggleSimulationPaused()
            } label: {
                Label(model.simulationControlTitle, systemImage: model.simulationControlSystemImage)
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("t", modifiers: [.command])
            .disabled(!model.canSave)
            .help(model.canSave ? model.simulationControlTitle : "开始新游戏前模拟不可用")

            Picker("速度", selection: speedBinding) {
                ForEach(Self.speedPresets, id: \.self) { speed in
                    Text("\(speed.formatted(.number.precision(.fractionLength(speed < 1 ? 2 : 0))))x")
                        .tag(speed)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)
            .disabled(!model.canSave)

            Button {
                model.save()
            } label: {
                Label("保存", systemImage: "square.and.arrow.down")
                    .labelStyle(.iconOnly)
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!model.canSave)
            .help(model.canSave ? "保存宇宙" : "开始新游戏前保存不可用")

            if !model.canSave {
                Button {
                    model.startNewGame()
                } label: {
                    Label("新游戏", systemImage: "plus")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private static let speedPresets: [Double] = [0.25, 0.5, 1, 2, 4, 8]
}

private struct OfflineSummaryLine: View {
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("离线补算", systemImage: "clock.arrow.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StatusMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.title3.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
