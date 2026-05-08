import Foundation
import OGameCore
import OGamePersistence
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: SidebarDestination? = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, planets: model.playerPlanets)
        } detail: {
            DetailView(selection: selection, model: model)
        }
        .frame(minWidth: 980, minHeight: 640)
    }
}

private enum SidebarDestination: Hashable {
    case dashboard
    case fleets
    case starMap
    case rankings
    case victory
    case relations
    case research
    case settings
    case planet(PlanetID)
}

private struct SidebarView: View {
    @Binding var selection: SidebarDestination?
    let planets: [Planet]

    var body: some View {
        List(selection: $selection) {
            Section("帝国") {
                Label("总览", systemImage: "chart.bar")
                    .tag(SidebarDestination.dashboard)

                Label("舰队", systemImage: "paperplane")
                    .tag(SidebarDestination.fleets)

                Label("研究", systemImage: "atom")
                    .tag(SidebarDestination.research)
            }

            Section("战略") {
                Label("星图", systemImage: "map")
                    .tag(SidebarDestination.starMap)

                Label("排名", systemImage: "list.number")
                    .tag(SidebarDestination.rankings)

                Label("胜利", systemImage: "flag.checkered")
                    .tag(SidebarDestination.victory)

                Label("关系", systemImage: "person.2.wave.2")
                    .tag(SidebarDestination.relations)
            }

            Section("系统") {
                Label("设置", systemImage: "gearshape")
                    .tag(SidebarDestination.settings)
            }

            Section("星球") {
                ForEach(planets) { planet in
                    SidebarPlanetRow(planet: planet)
                        .tag(SidebarDestination.planet(planet.id))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("OGame")
    }
}

private struct SidebarPlanetRow: View {
    let planet: Planet

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.grid.cross")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(planet.name.displayName)
                    .lineLimit(1)

                Text(planet.coordinate.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct DetailView: View {
    let selection: SidebarDestination?
    @ObservedObject var model: AppModel

    var body: some View {
        switch selection {
        case .dashboard, .none:
            DashboardView(model: model)
        case .planet(let planetID):
            if let planet = model.playerPlanets.first(where: { $0.id == planetID }) {
                PlanetDetailView(planet: planet, model: model)
            } else {
                DashboardView(model: model)
            }
        case .fleets:
            FleetOverviewView(model: model)
        case .starMap:
            StarMapView(model: model)
        case .rankings:
            RankingsView(model: model)
        case .victory:
            VictoryProgressView(model: model)
        case .relations:
            FactionRelationsView(model: model)
        case .research:
            ResearchOverviewView(model: model)
        case .settings:
            SettingsAndSavesView(model: model)
        }
    }
}

private struct DashboardView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.isOnboardingVisible {
                        OnboardingPanel(model: model)
                    }

                    HeaderView(universe: model.universe, faction: model.playerFaction)
                    VictoryBannerView(summary: model.victoryBannerSummary, compact: true)
                    PlanetSummaryView(planets: model.playerPlanets, model: model)
                    RecentEventsView(events: Array(model.universe.events.suffix(6).reversed()))
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle("总览")
    }
}

private struct HeaderView: View {
    let universe: Universe
    let faction: Faction?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(universe.name.displayName)
                .font(.largeTitle.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 12) {
                Label(faction?.name.displayName ?? "未知势力", systemImage: "person.crop.circle")
                Label("T+\(Formatters.wholeSeconds(universe.gameTime))", systemImage: "clock")
                Label(universe.ruleSet.displayName.displayName, systemImage: "speedometer")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}

private struct PlanetSummaryView: View {
    let planets: [Planet]
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "星球", detail: "\(planets.count) 个殖民地")

            if planets.isEmpty {
                EmptyStateView(title: "没有已拥有星球", systemImage: "circle.dashed")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    ForEach(planets) { planet in
                        PlanetSummaryCard(planet: planet, model: model)
                    }
                }
            }
        }
    }
}

private struct PlanetSummaryCard: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(planet.name.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(planet.coordinate.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let moon = planet.moon {
                    Label(moon.name.displayName, systemImage: "moon.stars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            ResourceGrid(resources: planet.resources)
            ResourceRateGrid(rates: model.productionPerHour(for: planet))

            EnergyStatusLine(planet: planet, model: model)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.16))
        }
    }
}

private struct ResourceGrid: View {
    let resources: ResourceBundle

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            ResourceRow(label: "金属", value: resources.metal)
            ResourceRow(label: "晶体", value: resources.crystal)
            ResourceRow(label: "重氢", value: resources.deuterium)
        }
        .font(.callout)
    }
}

private struct ResourceRateGrid: View {
    let rates: ResourceBundle

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            ResourceRateRow(label: "金属 /时", value: rates.metal)
            ResourceRateRow(label: "晶体 /时", value: rates.crystal)
            ResourceRateRow(label: "重氢 /时", value: rates.deuterium)
        }
        .font(.caption)
    }
}

private struct ResourceRow: View {
    let label: String
    let value: Double

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(Formatters.wholeNumber(value))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

private struct ResourceRateRow: View {
    let label: String
    let value: Double

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("+\(Formatters.wholeNumber(value))")
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

private struct EnergyStatusLine: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    var body: some View {
        Label(model.energyStatusText(for: planet), systemImage: "bolt.fill")
            .font(.caption)
            .foregroundStyle(planet.energy.available >= 0 ? Color.secondary : Color.red)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

private struct RecentEventsView: View {
    let events: [GameEvent]

    private var groups: [EventFeedGroup] {
        EventFeedGroup.group(events)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "近期事件", detail: "显示 \(events.count) 条")

            if events.isEmpty {
                EmptyStateView(title: "尚无事件记录", systemImage: "text.bubble")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groups) { group in
                        EventFeedGroupView(group: group)

                        if group.id != groups.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.16))
                }
            }
        }
    }
}

private struct EventFeedGroup: Identifiable {
    let kindRawValue: String
    let title: String
    let events: [GameEvent]

    var id: String {
        kindRawValue
    }

    static func group(_ events: [GameEvent]) -> [EventFeedGroup] {
        var groupedEvents: [String: [GameEvent]] = [:]
        var orderedKinds: [String] = []

        for event in events {
            let kindRawValue = event.kind.rawValue
            if groupedEvents[kindRawValue] == nil {
                orderedKinds.append(kindRawValue)
            }
            groupedEvents[kindRawValue, default: []].append(event)
        }

        return orderedKinds.compactMap { kindRawValue in
            guard let events = groupedEvents[kindRawValue], !events.isEmpty else {
                return nil
            }

            return EventFeedGroup(
                kindRawValue: kindRawValue,
                title: eventGroupTitle(for: events[0].kind),
                events: events
            )
        }
    }

    private static func eventGroupTitle(for kind: GameEvent.Kind) -> String {
        switch kind {
        case .system:
            return "系统"
        case .economy:
            return "经济"
        case .intelligence:
            return "情报"
        case .combat:
            return "战斗"
        case .exploration:
            return "探索"
        case .victory:
            return "胜利"
        }
    }
}

private struct EventFeedGroupView: View {
    let group: EventFeedGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: group.events.first?.symbolName ?? "circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Text(group.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(group.events.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 10)

            ForEach(group.events) { event in
                EventRow(event: event)

                if event.id != group.events.last?.id {
                    Divider()
                }
            }
        }
    }
}

private struct EventRow: View {
    let event: GameEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.localizedTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 12)

                    Text("T+\(Formatters.wholeSeconds(event.time))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Text(event.localizedMessage)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct ActivityPanel: View {
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

            VStack(spacing: 8) {
                Button {
                    model.advanceOneMinute()
                } label: {
                    Label(model.advanceActionTitle, systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(!model.canSave)
                .help(model.canSave ? model.advanceActionTitle : "推进前请先开始新游戏")

                Button {
                    model.save()
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!model.canSave)
                .help(model.canSave ? "保存宇宙" : "开始新游戏前保存不可用")

                if !model.canSave {
                    Button {
                        model.startNewGame()
                    } label: {
                        Label("新游戏", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                }
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

private struct OnboardingPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "首次启动", detail: "快速设置")

                Text("新的指挥官档案已经就绪。确认自动保存和模拟速度后，可以将这个宇宙写入当前自动存档。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        model.dismissOnboarding()
                    } label: {
                        Label("开始游戏", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.save()
                        model.dismissOnboarding()
                    } label: {
                        Label("立即保存", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                    .disabled(!model.canSave)
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

private struct SettingsAndSavesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("设置")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    SettingsPanel(model: model)
                    SaveManagementPanel(model: model)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle("设置")
        .onAppear {
            model.refreshSaveSlots()
        }
    }
}

private struct SettingsPanel: View {
    @ObservedObject var model: AppModel

    private var gameSpeedBinding: Binding<Double> {
        Binding(
            get: { model.settings.gameSpeed },
            set: { model.updateGameSpeed($0) }
        )
    }

    private var autosaveBinding: Binding<Bool> {
        Binding(
            get: { model.settings.isAutosaveEnabled },
            set: { model.updateAutosaveEnabled($0) }
        )
    }

    private var offlineIntensityBinding: Binding<GameSettings.OfflineIntensity> {
        Binding(
            get: { model.settings.offlineIntensity },
            set: { model.updateOfflineIntensity($0) }
        )
    }

    private var difficultyBinding: Binding<GameSettings.Difficulty> {
        Binding(
            get: { model.settings.difficulty },
            set: { model.updateDifficulty($0) }
        )
    }

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "模拟", detail: model.settingsStatusText)

                Toggle(isOn: autosaveBinding) {
                    Label("队列和舰队操作自动保存", systemImage: "externaldrive.badge.checkmark")
                }
                .toggleStyle(.checkbox)
                .disabled(!model.canSave)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("游戏速度", systemImage: "speedometer")
                            .font(.callout.weight(.semibold))

                        Spacer(minLength: 12)

                        Text("\(model.settings.gameSpeed.formatted(.number.precision(.fractionLength(2))))x")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Slider(value: gameSpeedBinding, in: 0.25...8, step: 0.25)
                        .disabled(!model.canSave)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), alignment: .topLeading)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    SettingPicker(
                        title: "离线强度",
                        systemImage: "moon.zzz",
                        selection: offlineIntensityBinding,
                        options: GameSettings.OfflineIntensity.allCases
                    ) { option in
                        option.displayName
                    }

                    SettingPicker(
                        title: "难度",
                        systemImage: "dial.medium",
                        selection: difficultyBinding,
                        options: GameSettings.Difficulty.allCases
                    ) { option in
                        option.displayName
                    }
                }

                Text(model.settings.difficulty.behaviorDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()

                    Button {
                        model.save()
                    } label: {
                        Label("保存设置", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: [.command])
                    .disabled(!model.canSave)
                    .help(model.canSave ? "保存设置" : "开始新游戏前保存不可用")
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

private struct SettingPicker<Option: Hashable, LabelContent: StringProtocol>: View {
    let title: String
    let systemImage: String
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> LabelContent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(String(label(option)))
                        .tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct SaveManagementPanel: View {
    @ObservedObject var model: AppModel

    private var canCreateBackup: Bool {
        model.canSave && model.saveSlots.contains { $0.isAutosave }
    }

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "存档管理", detail: "\(model.saveSlots.count) 个槽位")

                HStack(spacing: 10) {
                    Button {
                        model.createBackup()
                    } label: {
                        Label("创建备份", systemImage: "archivebox")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreateBackup)

                    Button {
                        model.refreshSaveSlots()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }

                if model.saveSlots.isEmpty {
                    QueueEmptyLine(title: "请先保存自动存档再创建备份", systemImage: "externaldrive.badge.plus")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.saveSlots) { slot in
                            SaveSlotRow(slot: slot, model: model)

                            if slot.id != model.saveSlots.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

private struct SaveSlotRow: View {
    let slot: JSONSaveRepository.SaveSlot
    @ObservedObject var model: AppModel
    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: slot.isAutosave ? "externaldrive.badge.checkmark" : "doc.badge.clock")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(slot.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(slotDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label(slot.isAutosave ? "自动存档受保护" : "删除备份", systemImage: "trash")
            }
            .controlSize(.small)
            .disabled(slot.isAutosave)
        }
        .padding(.vertical, 10)
        .confirmationDialog(
            "删除备份",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("删除 \(slot.name)", role: .destructive) {
                model.deleteSaveSlot(named: slot.name)
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("确定删除备份 \(slot.name)？此操作无法撤销。")
        }
    }

    private var slotDetail: String {
        let kind = slot.isAutosave ? "自动存档" : "备份"
        let size = ByteCountFormatter.string(fromByteCount: slot.byteCount, countStyle: .file)
        guard let lastModifiedAt = slot.lastModifiedAt else {
            return "\(kind) - \(size)"
        }

        return "\(kind) - \(size) - \(lastModifiedAt.formatted(date: .abbreviated, time: .shortened))"
    }
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

private struct PlanetDetailView: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(planet.name.displayName)
                            .font(.largeTitle.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(planet.coordinate.displayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let moon = planet.moon {
                        MoonSummaryCard(moon: moon)
                    }

                    PlanetEconomyView(planet: planet, model: model)
                    ConstructionQueueView(planet: planet, model: model)
                    BuildingControlsView(planet: planet, model: model)
                    ShipyardControlsView(planet: planet, model: model)
                    InventoryCard(title: "舰船", values: planet.shipInventory)
                    InventoryCard(title: "防御", values: planet.defenseInventory)
                    if !planet.missileInventory.isEmpty {
                        InventoryCard(title: "导弹", values: planet.missileInventory)
                    }
                    ResourceCard(title: "残骸带", resources: planet.debrisField)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle(planet.name.displayName)
    }
}

private struct MoonSummaryCard: View {
    let moon: Moon

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "月球", detail: moon.name.displayName)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160), alignment: .topLeading)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    DispatchMetric(title: "创建时间", value: "T+\(Formatters.wholeSeconds(moon.createdAt))")
                    DispatchMetric(title: "设施", value: Formatters.wholeNumber(Double(moon.buildingLevels.values.reduce(0, +))))
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }
}

private struct PlanetEconomyView: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "经济", detail: model.energyStatusText(for: planet))

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180), alignment: .topLeading)],
                    alignment: .leading,
                    spacing: 16
                ) {
                    EconomyColumn(title: "资源") {
                        ResourceGrid(resources: planet.resources)
                    }

                    EconomyColumn(title: "每小时产量") {
                        ResourceRateGrid(rates: model.productionPerHour(for: planet))
                    }

                    EconomyColumn(title: "仓储") {
                        ResourceGrid(resources: model.storageCapacity(for: planet).resourceBundle)
                    }
                }

                ProductionControlsView(planet: planet, model: model)
                EnergyMeterView(planet: planet, model: model)
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }
}

private struct ProductionControlsView: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    private let mineKinds: [BuildingKind] = [.metalMine, .crystalMine, .deuteriumSynthesizer]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(mineKinds, id: \.self) { kind in
                HStack(spacing: 10) {
                    Image(systemName: kind.systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    Text(kind.localizedName)
                        .font(.caption.weight(.semibold))
                        .frame(width: 128, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { model.productionSetting(for: kind, on: planet) },
                            set: { model.updateProductionSetting(planetID: planet.id, kind: kind, value: $0) }
                        ),
                        in: 0...1,
                        step: 0.05
                    )
                    .disabled(!model.canSave)

                    Text(Formatters.percent(model.productionSetting(for: kind, on: planet)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }
}

private struct EconomyColumn<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EnergyMeterView: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label("能源", systemImage: "bolt.fill")
                    .font(.callout.weight(.semibold))

                Spacer(minLength: 12)

                Text(model.energyStatusText(for: planet))
                    .font(.caption)
                    .foregroundStyle(planet.energy.available >= 0 ? Color.secondary : Color.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            ProgressView(value: model.energySupplyRatio(for: planet))
                .tint(planet.energy.available >= 0 ? Color.green : Color.red)
        }
    }
}

private enum ConstructionQueueEntry: Identifiable {
    case building(BuildQueueItem)
    case unit(UnitBuildQueueItem)

    var id: String {
        switch self {
        case .building(let item):
            return "building-\(item.id.uuidString)"
        case .unit(let item):
            return "unit-\(item.id.uuidString)"
        }
    }
}

private struct ConstructionQueueView: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    private var entries: [ConstructionQueueEntry] {
        planet.buildQueue.map(ConstructionQueueEntry.building) +
            planet.shipBuildQueue.map(ConstructionQueueEntry.unit) +
            planet.defenseBuildQueue.map(ConstructionQueueEntry.unit)
    }

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: "队列",
                    detail: entries.isEmpty ? "空闲" : "\(entries.count) 个进行中"
                )

                if entries.isEmpty {
                    QueueEmptyLine(title: "没有进行中的建造", systemImage: "hammer")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(entries) { entry in
                            switch entry {
                            case .building(let item):
                                BuildQueueRow(item: item, model: model)
                            case .unit(let item):
                                UnitQueueRow(item: item, model: model)
                            }

                            if entry.id != entries.last?.id {
                                QueueDivider()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }
}

private struct UnitQueueRow: View {
    let item: UnitBuildQueueItem
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.unitQueueTitle(item))
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(model.queueRemainingText(until: item.finishTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Text(model.unitQueueStatus(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: model.queueProgress(startTime: item.startTime, finishTime: item.finishTime))
            }
        }
        .padding(.vertical, 10)
    }
}

private struct QueueDivider: View {
    var body: some View {
        Divider()
    }
}

private struct BuildQueueRow: View {
    let item: BuildQueueItem
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.buildingKind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.buildingKind.localizedName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(model.queueRemainingText(until: item.finishTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Text(model.buildQueueStatus(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: model.queueProgress(startTime: item.startTime, finishTime: item.finishTime))
            }
        }
        .padding(.vertical, 10)
    }
}

private struct BuildingControlsView: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: "建筑",
                    detail: planet.buildQueue.isEmpty ? "就绪" : "队列忙碌"
                )

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.availableBuildingKinds, id: \.self) { kind in
                        BuildingUpgradeRow(planet: planet, kind: kind, model: model)

                        if kind != model.availableBuildingKinds.last {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }
}

private struct BuildingUpgradeRow: View {
    let planet: Planet
    let kind: BuildingKind
    @ObservedObject var model: AppModel

    private var cost: ResourceBundle? {
        model.buildingUpgradeCost(for: planet, kind: kind)
    }

    private var canAfford: Bool {
        cost.map { planet.resources.canAfford($0) } ?? false
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(kind.localizedName)
                    .font(.headline)
                    .lineLimit(1)

                Text("等级 \(model.buildingLevel(for: kind, on: planet)) -> \(model.nextBuildingLevel(for: kind, on: planet))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ResourceCostLine(
                    cost: cost,
                    durationText: model.durationText(model.buildingUpgradeDuration(for: planet, kind: kind)),
                    canAfford: canAfford
                )

                if let lockedReason = model.buildingUpgradeLockedReason(planet: planet, kind: kind) {
                    Text(lockedReason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            Button {
                model.startBuildingUpgrade(planetID: planet.id, kind: kind)
            } label: {
                Label("升级", systemImage: "arrow.up.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .disabled(!model.canStartBuildingUpgrade(planet: planet, kind: kind))
            .help(model.buildingUpgradeLockedReason(planet: planet, kind: kind) ?? "加入建筑升级队列")
        }
        .padding(.vertical, 10)
    }
}

private struct ShipyardControlsView: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(
                    title: "造船厂",
                    detail: shipyardDetail
                )

                UnitBuildSection(
                    title: "舰船",
                    systemImage: "paperplane",
                    isEmpty: model.availableShipKinds.isEmpty
                ) {
                    ForEach(model.availableShipKinds, id: \.self) { kind in
                        ShipBuildRow(planet: planet, kind: kind, model: model)

                        if kind != model.availableShipKinds.last {
                            Divider()
                        }
                    }
                }

                UnitBuildSection(
                    title: "防御",
                    systemImage: "shield",
                    isEmpty: model.availableDefenseKinds.isEmpty
                ) {
                    ForEach(model.availableDefenseKinds, id: \.self) { kind in
                        DefenseBuildRow(planet: planet, kind: kind, model: model)

                        if kind != model.availableDefenseKinds.last {
                            Divider()
                        }
                    }
                }

                UnitBuildSection(
                    title: "导弹",
                    systemImage: "scope",
                    isEmpty: model.availableMissileKinds.isEmpty
                ) {
                    ForEach(model.availableMissileKinds, id: \.self) { kind in
                        MissileBuildRow(planet: planet, kind: kind, model: model)

                        if kind != model.availableMissileKinds.last {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var shipyardDetail: String {
        if !planet.shipBuildQueue.isEmpty || !planet.defenseBuildQueue.isEmpty {
            return "队列进行中"
        }

        return "就绪"
    }
}

private struct UnitBuildSection<Content: View>: View {
    let title: String
    let systemImage: String
    let isEmpty: Bool
    let content: Content

    init(title: String, systemImage: String, isEmpty: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.isEmpty = isEmpty
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .lineLimit(1)

            if isEmpty {
                QueueEmptyLine(title: "没有可用规则", systemImage: "tray")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
            }
        }
    }
}

private struct ShipBuildRow: View {
    let planet: Planet
    let kind: ShipKind
    @ObservedObject var model: AppModel
    @State private var quantity = 1

    private var cost: ResourceBundle? {
        model.shipBuildCost(for: kind, quantity: quantity)
    }

    private var canAfford: Bool {
        cost.map { planet.resources.canAfford($0) } ?? false
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(kind.localizedName)
                    .font(.headline)
                    .lineLimit(1)

                Text("拥有 \(planet.shipInventory[kind, default: 0])")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ResourceCostLine(
                    cost: cost,
                    durationText: model.durationText(model.shipBuildDuration(for: kind, quantity: quantity, on: planet)),
                    canAfford: canAfford
                )

                if let lockedReason = model.shipBuildLockedReason(planet: planet, kind: kind, quantity: quantity) {
                    Text(lockedReason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            QuantityStepper(value: $quantity, range: 1...999)

            Button {
                model.startShipBuild(planetID: planet.id, kind: kind, quantity: quantity)
            } label: {
                Label("建造", systemImage: "plus.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .disabled(!model.canStartShipBuild(planet: planet, kind: kind, quantity: quantity))
            .help(model.shipBuildLockedReason(planet: planet, kind: kind, quantity: quantity) ?? "加入舰船生产队列")
        }
        .padding(.vertical, 10)
    }
}

private struct DefenseBuildRow: View {
    let planet: Planet
    let kind: DefenseKind
    @ObservedObject var model: AppModel
    @State private var quantity = 1

    private var cost: ResourceBundle? {
        model.defenseBuildCost(for: kind, quantity: quantity)
    }

    private var canAfford: Bool {
        cost.map { planet.resources.canAfford($0) } ?? false
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(kind.localizedName)
                    .font(.headline)
                    .lineLimit(1)

                Text("拥有 \(planet.defenseInventory[kind, default: 0])")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ResourceCostLine(
                    cost: cost,
                    durationText: model.durationText(model.defenseBuildDuration(for: kind, quantity: quantity, on: planet)),
                    canAfford: canAfford
                )

                if let lockedReason = model.defenseBuildLockedReason(planet: planet, kind: kind, quantity: quantity) {
                    Text(lockedReason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            QuantityStepper(value: $quantity, range: 1...999)

            Button {
                model.startDefenseBuild(planetID: planet.id, kind: kind, quantity: quantity)
            } label: {
                Label("建造", systemImage: "plus.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .disabled(!model.canStartDefenseBuild(planet: planet, kind: kind, quantity: quantity))
            .help(model.defenseBuildLockedReason(planet: planet, kind: kind, quantity: quantity) ?? "加入防御生产队列")
        }
        .padding(.vertical, 10)
    }
}

private struct MissileBuildRow: View {
    let planet: Planet
    let kind: MissileKind
    @ObservedObject var model: AppModel
    @State private var quantity = 1

    private var cost: ResourceBundle? {
        model.missileBuildCost(for: kind, quantity: quantity)
    }

    private var canAfford: Bool {
        cost.map { planet.resources.canAfford($0) } ?? false
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(kind.localizedName)
                    .font(.headline)
                    .lineLimit(1)

                Text("拥有 \(planet.missileInventory[kind, default: 0])")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ResourceCostLine(
                    cost: cost,
                    durationText: model.durationText(model.missileBuildDuration(for: kind, quantity: quantity, on: planet)),
                    canAfford: canAfford
                )

                if let lockedReason = model.missileBuildLockedReason(planet: planet, kind: kind, quantity: quantity) {
                    Text(lockedReason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            QuantityStepper(value: $quantity, range: 1...99)

            Button {
                model.startMissileBuild(planetID: planet.id, kind: kind, quantity: quantity)
            } label: {
                Label("建造", systemImage: "plus.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .disabled(!model.canStartMissileBuild(planet: planet, kind: kind, quantity: quantity))
            .help(model.missileBuildLockedReason(planet: planet, kind: kind, quantity: quantity) ?? "加入导弹生产队列")
        }
        .padding(.vertical, 10)
    }
}

private struct QuantityStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            Text("x\(value)")
                .font(.callout.monospacedDigit())
                .frame(width: 48, alignment: .trailing)
                .lineLimit(1)
        }
        .controlSize(.small)
        .frame(width: 112)
    }
}

private struct FleetOverviewView: View {
    @ObservedObject var model: AppModel
    @State private var originID: PlanetID?
    @State private var targetID: PlanetID?
    @State private var mission: Fleet.Mission = .transport
    @State private var selectedShips: [ShipKind: Int] = [:]
    @State private var metalCargo = 0.0
    @State private var crystalCargo = 0.0
    @State private var deuteriumCargo = 0.0

    private var launchCargo: ResourceBundle {
        ResourceBundle(
            metal: max(0, metalCargo),
            crystal: max(0, crystalCargo),
            deuterium: max(0, deuteriumCargo)
        )
    }

    private var originInventorySignature: String {
        guard let origin = model.planet(for: originID) else {
            return "缺失"
        }

        let shipCounts = model.availableShipKinds
            .map { "\($0.rawValue):\(origin.shipInventory[$0, default: 0])" } +
            ["interplanetaryMissile:\(origin.missileInventory[.interplanetaryMissile, default: 0])"]
        return shipCounts.joined(separator: "|")
    }

    private var targetStateSignature: String {
        model.fleetTargetStateSignature(targetID: targetID)
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("舰队")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    FleetDispatchPanel(
                        model: model,
                        originID: $originID,
                        targetID: $targetID,
                        mission: $mission,
                        selectedShips: $selectedShips,
                        metalCargo: $metalCargo,
                        crystalCargo: $crystalCargo,
                        deuteriumCargo: $deuteriumCargo,
                        launchCargo: launchCargo
                    )

                    ActiveFleetsPanel(model: model)
                    ReportsPanel(model: model)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle("舰队")
        .onAppear(perform: initializeSelection)
        .onChange(of: originID) { _ in
            synchronizeFleetSelection(updateTarget: true)
        }
        .onChange(of: targetID) { _ in
            synchronizeFleetSelection()
        }
        .onChange(of: selectedShips) { _ in
            synchronizeFleetSelection()
        }
        .onChange(of: originInventorySignature) { _ in
            synchronizeFleetSelection()
        }
        .onChange(of: targetStateSignature) { _ in
            synchronizeFleetSelection()
        }
        .onChange(of: metalCargo) { value in
            metalCargo = max(0, value)
        }
        .onChange(of: crystalCargo) { value in
            crystalCargo = max(0, value)
        }
        .onChange(of: deuteriumCargo) { value in
            deuteriumCargo = max(0, value)
        }
    }

    private func initializeSelection() {
        if originID == nil {
            originID = model.defaultOriginPlanetID()
        }

        if targetID == nil || targetID == originID {
            targetID = model.defaultTargetPlanetID(excluding: originID)
        }

        synchronizeFleetSelection()
    }

    private func synchronizeFleetSelection(updateTarget: Bool = false) {
        if updateTarget || targetID == nil || targetID == originID {
            targetID = model.defaultTargetPlanetID(excluding: originID)
        }

        clampShipSelection()

        if !model.isMissionAvailable(mission, originID: originID, targetID: targetID, ships: selectedShips) {
            mission = model.firstAvailableMission(originID: originID, targetID: targetID, ships: selectedShips) ?? .transport
        }
    }

    private func clampShipSelection() {
        guard let origin = model.planet(for: originID) else {
            if !selectedShips.isEmpty {
                selectedShips = [:]
            }
            return
        }

        var clampedShips: [ShipKind: Int] = [:]
        for kind in model.availableShipKinds {
            let available = origin.shipInventory[kind, default: 0]
            let selected = selectedShips[kind, default: 0]
            let clamped = min(max(0, selected), max(0, available))
            if clamped > 0 {
                clampedShips[kind] = clamped
            }
        }

        if selectedShips != clampedShips {
            selectedShips = clampedShips
        }
    }
}

private struct FleetDispatchPanel: View {
    @ObservedObject var model: AppModel
    @Binding var originID: PlanetID?
    @Binding var targetID: PlanetID?
    @Binding var mission: Fleet.Mission
    @Binding var selectedShips: [ShipKind: Int]
    @Binding var metalCargo: Double
    @Binding var crystalCargo: Double
    @Binding var deuteriumCargo: Double
    @State private var missileCount = 1
    let launchCargo: ResourceBundle

    private var origin: Planet? {
        model.planet(for: originID)
    }

    private var selectedShipTotal: Int {
        selectedShips.values.reduce(0) { $0 + max(0, $1) }
    }

    private var cargoCapacity: Double {
        model.fleetCargoCapacity(for: selectedShips)
    }

    private var cargoUsed: Double {
        max(0, metalCargo) + max(0, crystalCargo) + max(0, deuteriumCargo)
    }

    private var originMissileCount: Int {
        model.interplanetaryMissileCount(on: originID)
    }

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "派遣", detail: selectedShipTotal == 0 ? "选择舰船" : "\(selectedShipTotal) 艘舰船")

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), alignment: .topLeading)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    PlanetPicker(title: "出发地", selection: $originID, planets: model.playerPlanets, emptyTitle: "无殖民地")
                    FleetTargetPicker(
                        title: "目标",
                        selection: $targetID,
                        targets: model.fleetTargetSummaries(excluding: originID),
                        emptyTitle: "无目标"
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("任务")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Picker("任务", selection: $mission) {
                            ForEach(model.fleetMissionKinds, id: \.rawValue) { option in
                                Label(option.localizedName, systemImage: option.systemImage)
                                    .tag(option)
                                    .disabled(!model.isMissionAvailable(option, originID: originID, targetID: targetID, ships: selectedShips))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                }

                FleetShipSelector(origin: origin, model: model, selectedShips: $selectedShips)

                CargoEditor(
                    metalCargo: $metalCargo,
                    crystalCargo: $crystalCargo,
                    deuteriumCargo: $deuteriumCargo
                )

                FleetDispatchSummary(
                    model: model,
                    originID: originID,
                    targetID: targetID,
                    ships: selectedShips,
                    cargo: launchCargo,
                    cargoUsed: cargoUsed,
                    cargoCapacity: cargoCapacity
                )

                if model.canShowMissileStrikeControls(originID: originID) {
                    MissileStrikeControls(
                        model: model,
                        originID: originID,
                        targetID: targetID,
                        missileCount: $missileCount,
                        availableMissiles: originMissileCount
                    )
                }

                HStack {
                    Spacer()

                    Button {
                        model.launchFleet(
                            originID: originID,
                            targetID: targetID,
                            mission: mission,
                            ships: selectedShips,
                            cargo: launchCargo
                        )
                    } label: {
                        Label("派遣", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canLaunchFleet(
                        originID: originID,
                        targetID: targetID,
                        mission: mission,
                        ships: selectedShips,
                        cargo: launchCargo
                    ))
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
        .onChange(of: originMissileCount) { available in
            missileCount = min(max(1, missileCount), max(1, available))
        }
    }
}

private struct MissileStrikeControls: View {
    @ObservedObject var model: AppModel
    let originID: PlanetID?
    let targetID: PlanetID?
    @Binding var missileCount: Int
    let availableMissiles: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "导弹打击", detail: "\(availableMissiles) 枚就绪")

            HStack(alignment: .center, spacing: 14) {
                Stepper(value: $missileCount, in: 1...max(1, availableMissiles)) {
                    Label("\(missileCount)", systemImage: MissileKind.interplanetaryMissile.systemImage)
                        .font(.callout.monospacedDigit())
                        .lineLimit(1)
                }
                .frame(maxWidth: 180, alignment: .leading)

                Spacer()

                Button {
                    model.launchMissileStrike(
                        originID: originID,
                        targetID: targetID,
                        missileCount: missileCount
                    )
                } label: {
                    Label("打击", systemImage: "scope")
                }
                .buttonStyle(.bordered)
                .disabled(!model.canLaunchMissileStrike(
                    originID: originID,
                    targetID: targetID,
                    missileCount: missileCount
                ))
            }
        }
        .padding(.top, 2)
        .onAppear(perform: clampMissileCount)
        .onChange(of: availableMissiles) { _ in
            clampMissileCount()
        }
    }

    private func clampMissileCount() {
        missileCount = min(max(1, missileCount), max(1, availableMissiles))
    }
}

private struct PlanetPicker: View {
    let title: String
    @Binding var selection: PlanetID?
    let planets: [Planet]
    let emptyTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker(title, selection: $selection) {
                if planets.isEmpty {
                    Text(emptyTitle)
                        .tag(Optional<PlanetID>.none)
                } else {
                    ForEach(planets) { planet in
                            Text("\(planet.name.displayName) \(planet.coordinate.displayText)")
                            .lineLimit(1)
                            .tag(Optional(planet.id))
                    }
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }
}

private struct FleetTargetPicker: View {
    let title: String
    @Binding var selection: PlanetID?
    let targets: [FleetTargetSummary]
    let emptyTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker(title, selection: $selection) {
                if targets.isEmpty {
                    Text(emptyTitle)
                        .tag(Optional<PlanetID>.none)
                } else {
                    ForEach(targets) { target in
                        Text(target.pickerTitle)
                            .lineLimit(1)
                            .tag(Optional(target.id))
                    }
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            if let selected = targets.first(where: { $0.id == selection }) {
                Label(selected.detailText, systemImage: selected.isVisible ? "location.viewfinder" : "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct FleetShipSelector: View {
    let origin: Planet?
    @ObservedObject var model: AppModel
    @Binding var selectedShips: [ShipKind: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("舰船", systemImage: "paperplane")
                .font(.callout.weight(.semibold))
                .lineLimit(1)

            if let origin, !model.availableShipKinds.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.availableShipKinds, id: \.self) { kind in
                        FleetShipSelectionRow(
                            kind: kind,
                            available: max(0, origin.shipInventory[kind, default: 0]),
                            quantity: Binding(
                                get: { selectedShips[kind, default: 0] },
                                set: { selectedShips[kind] = min(max(0, $0), max(0, origin.shipInventory[kind, default: 0])) }
                            )
                        )

                        if kind != model.availableShipKinds.last {
                            Divider()
                        }
                    }
                }
            } else {
                QueueEmptyLine(title: "请选择出发殖民地", systemImage: "paperplane")
            }
        }
    }
}

private struct FleetShipSelectionRow: View {
    let kind: ShipKind
    let available: Int
    @Binding var quantity: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.localizedName)
                    .font(.headline)
                    .lineLimit(1)

                Text("可用 \(available)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Stepper(value: $quantity, in: 0...available) {
                Text("\(quantity)")
                    .font(.callout.monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
                    .lineLimit(1)
            }
            .controlSize(.small)
            .frame(width: 112)
            .disabled(available == 0)
        }
        .padding(.vertical, 8)
    }
}

private struct CargoEditor: View {
    @Binding var metalCargo: Double
    @Binding var crystalCargo: Double
    @Binding var deuteriumCargo: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("货物", systemImage: "shippingbox")
                .font(.callout.weight(.semibold))
                .lineLimit(1)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)],
                alignment: .leading,
                spacing: 10
            ) {
                CargoField(title: "金属", value: $metalCargo)
                CargoField(title: "晶体", value: $crystalCargo)
                CargoField(title: "重氢", value: $deuteriumCargo)
            }
        }
    }
}

private struct CargoField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            TextField(title, value: $value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                .frame(maxWidth: 180)
                .onChange(of: value) { newValue in
                    value = max(0, newValue)
                }
        }
    }
}

private struct FleetDispatchSummary: View {
    @ObservedObject var model: AppModel
    let originID: PlanetID?
    let targetID: PlanetID?
    let ships: [ShipKind: Int]
    let cargo: ResourceBundle
    let cargoUsed: Double
    let cargoCapacity: Double

    private var hasShipsSelected: Bool {
        ships.values.contains { $0 > 0 }
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), alignment: .topLeading)],
            alignment: .leading,
            spacing: 10
        ) {
            DispatchMetric(title: "容量", value: "\(Formatters.wholeNumber(cargoUsed)) / \(Formatters.wholeNumber(cargoCapacity))")
            DispatchMetric(title: "燃料", value: fuelText, isWarning: hasShipsSelected && !fuelIsAffordable)
            DispatchMetric(title: "航程", value: model.durationText(model.fleetTravelDuration(originID: originID, targetID: targetID, ships: ships)))
        }
    }

    private var fuelText: String {
        model.fleetFuelStatusText(originID: originID, targetID: targetID, ships: ships, cargo: cargo)
    }

    private var fuelIsAffordable: Bool {
        model.canAffordFleetFuel(originID: originID, targetID: targetID, ships: ships, cargo: cargo)
    }
}

private struct DispatchMetric: View {
    let title: String
    let value: String
    var isWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(isWarning ? Color.red : Color.secondary)
                .lineLimit(1)

            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(isWarning ? Color.red : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct ActiveFleetsPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: "活动舰队",
                    detail: model.activeFleets.isEmpty ? "空闲" : "\(model.activeFleets.count) 支飞行中"
                )

                if model.activeFleets.isEmpty {
                    QueueEmptyLine(title: "没有活动舰队", systemImage: "paperplane")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.activeFleets) { fleet in
                            ActiveFleetRow(fleet: fleet, model: model)

                            if fleet.id != model.activeFleets.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

private struct ActiveFleetRow: View {
    let fleet: Fleet
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: fleet.mission.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(fleet.mission.localizedName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(model.fleetPhaseText(fleet))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Text("\(fleet.origin.displayText) -> \(fleet.target.displayText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(model.fleetShipsSummary(fleet.ships))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(model.fleetCargoSummary(fleet.cargo))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct ReportsPanel: View {
    @ObservedObject var model: AppModel

    private var battleReports: [Report] {
        model.recentReports.filter { $0.kind == .battle }
    }

    private var espionageReports: [Report] {
        model.recentReports.filter { $0.kind == .espionage }
    }

    private var explorationReports: [Report] {
        model.recentReports.filter { $0.kind == .exploration }
    }

    private var missileReports: [Report] {
        model.recentReports.filter { $0.kind == .missile }
    }

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "报告", detail: reportsDetail)

                if model.recentReports.isEmpty && model.recentExplorationEvents.isEmpty {
                    QueueEmptyLine(title: "尚无报告记录", systemImage: "doc.text.magnifyingglass")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ReportRowsSection(
                            title: "战斗",
                            systemImage: "target",
                            reports: battleReports,
                            model: model
                        )
                        SectionDivider(isVisible: !battleReports.isEmpty && (!missileReports.isEmpty || !espionageReports.isEmpty || !explorationReports.isEmpty || !model.recentExplorationEvents.isEmpty))

                        ReportRowsSection(
                            title: "导弹",
                            systemImage: "scope",
                            reports: missileReports,
                            model: model
                        )
                        SectionDivider(isVisible: !missileReports.isEmpty && (!espionageReports.isEmpty || !explorationReports.isEmpty || !model.recentExplorationEvents.isEmpty))

                        ReportRowsSection(
                            title: "侦察",
                            systemImage: "eye",
                            reports: espionageReports,
                            model: model
                        )
                        SectionDivider(isVisible: !espionageReports.isEmpty && (!explorationReports.isEmpty || !model.recentExplorationEvents.isEmpty))

                        ReportRowsSection(
                            title: "探索",
                            systemImage: "sparkles",
                            reports: explorationReports,
                            model: model
                        )
                        SectionDivider(isVisible: !explorationReports.isEmpty && !model.recentExplorationEvents.isEmpty)

                        ExplorationEventRowsSection(events: model.recentExplorationEvents)
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }

    private var reportsDetail: String {
        let count = model.recentReports.count + model.recentExplorationEvents.count
        return count == 0 ? "无" : "\(count) 条近期"
    }
}

private struct ReportRowsSection: View {
    let title: String
    let systemImage: String
    let reports: [Report]
    @ObservedObject var model: AppModel

    var body: some View {
        if !reports.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ReportGroupHeader(title: title, systemImage: systemImage, count: reports.count)

                ForEach(reports) { report in
                    ReportRow(report: report, model: model)

                    if report.id != reports.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct ExplorationEventRowsSection: View {
    let events: [GameEvent]

    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ReportGroupHeader(title: "探索事件", systemImage: "sparkles", count: events.count)

                ForEach(events) { event in
                    ExplorationEventReportRow(event: event)

                    if event.id != events.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct ReportGroupHeader: View {
    let title: String
    let systemImage: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.top, 10)
    }
}

private struct SectionDivider: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            Divider()
        }
    }
}

private struct ReportRow: View {
    let report: Report
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: report.kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(report.localizedTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 12)

                    Text("T+\(Formatters.wholeSeconds(report.time))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Text(report.localizedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(model.reportDetailSummary(report))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct ExplorationEventReportRow: View {
    let event: GameEvent

    var body: some View {
        EventStyleRow(
            title: event.localizedTitle,
            detail: event.localizedMessage,
            accessory: "T+\(Formatters.wholeSeconds(event.time))",
            systemImage: "sparkles"
        )
    }
}

private struct StarMapView: View {
    @ObservedObject var model: AppModel

    private var allPlanets: [StarMapPlanetSummary] {
        model.starMapSections.flatMap(\.planets)
    }

    private var debrisSystemCount: Int {
        allPlanets.filter { $0.debrisTotal > 0 }.count
    }

    private var activeFleetTouchCount: Int {
        allPlanets.reduce(0) { $0 + $1.friendlyFleetCount + $1.otherFleetCount }
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("星图")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    PanelSurface {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), alignment: .topLeading)],
                            alignment: .leading,
                            spacing: 12
                        ) {
                            StrategicMetric(title: "星球", value: Formatters.wholeNumber(Double(allPlanets.count)))
                            StrategicMetric(title: "拥有", value: Formatters.wholeNumber(Double(model.playerPlanets.count)))
                            StrategicMetric(title: "残骸", value: Formatters.wholeNumber(Double(debrisSystemCount)))
                            StrategicMetric(title: "舰队标记", value: Formatters.wholeNumber(Double(activeFleetTouchCount)))
                        }
                    }
                    .frame(maxWidth: 860, alignment: .leading)

                    ForEach(model.starMapSections) { section in
                        StarMapSectionView(section: section)
                    }

                    ExplorationSummaryPanel(model: model)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle("星图")
    }
}

private struct StarMapSectionView: View {
    let section: StarMapPlanetSection

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: section.kind.title, detail: "\(section.planets.count) 个星系")

                if section.planets.isEmpty {
                    QueueEmptyLine(title: "此分区暂无星系", systemImage: section.kind.systemImage)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(section.planets) { summary in
                            StarMapPlanetRow(summary: summary)

                            if summary.id != section.planets.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

private struct StarMapPlanetRow: View {
    let summary: StarMapPlanetSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(iconTint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(summary.planet.coordinate.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(summary.ownerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 86), alignment: .leading)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    StrategicChip(title: ownershipTitle, systemImage: systemImage, tint: iconTint)

                    if summary.debrisTotal > 0 {
                        StrategicChip(
                            title: "残骸 \(Formatters.wholeNumber(summary.debrisTotal))",
                            systemImage: "sparkles",
                            tint: .orange
                        )
                    }

                    if summary.friendlyFleetCount > 0 {
                        StrategicChip(
                            title: "舰队 \(summary.friendlyFleetCount)",
                            systemImage: "paperplane",
                            tint: .blue
                        )
                    }

                    if summary.otherFleetCount > 0 {
                        StrategicChip(
                            title: "接触 \(summary.otherFleetCount)",
                            systemImage: "scope",
                            tint: .red
                        )
                    }

                    StrategicChip(
                        title: summary.isExploredByPlayer ? "已侦察" : "未侦察",
                        systemImage: summary.isExploredByPlayer ? "checkmark.seal" : "questionmark.circle",
                        tint: summary.isExploredByPlayer ? .green : .secondary
                    )
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var ownershipTitle: String {
        if summary.isPlayerOwned {
            return "拥有"
        }

        if !summary.isVisible {
            return "未知"
        }

        if summary.ownerKind == .ai {
            return "AI"
        }

        return "中立"
    }

    private var systemImage: String {
        if summary.isPlayerOwned {
            return "house.and.flag"
        }

        if !summary.isVisible {
            return "questionmark.circle"
        }

        if summary.ownerKind == .ai {
            return "cpu"
        }

        return "circle.dashed"
    }

    private var iconTint: Color {
        if summary.isPlayerOwned {
            return .blue
        }

        if !summary.isVisible {
            return .secondary
        }

        if summary.ownerKind == .ai {
            return .red
        }

        return .secondary
    }
}

private struct ExplorationSummaryPanel: View {
    @ObservedObject var model: AppModel

    private var summaries: [ExplorationSummary] {
        Array(model.playerExplorationSummaries.prefix(8))
    }

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: "探索情报",
                    detail: summaries.isEmpty ? "无记录" : "\(summaries.count) 条近期"
                )

                if summaries.isEmpty {
                    QueueEmptyLine(title: "尚无已探索星系记录", systemImage: "sparkles")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(summaries) { summary in
                            ExplorationSummaryRow(summary: summary)

                            if summary.id != summaries.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

private struct ExplorationSummaryRow: View {
    let summary: ExplorationSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.planet.name.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(summary.planet.coordinate.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text("T+\(Formatters.wholeSeconds(summary.exploredAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Text("归属 \(summary.ownerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                StrategicResourceLine(title: "奖励", resources: summary.reward)
                StrategicResourceLine(title: "资源", resources: summary.discoveredResources)
                StrategicResourceLine(title: "残骸", resources: summary.discoveredDebris)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct RankingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("排名")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    PanelSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "势力排名", detail: "\(model.factionRankings.count) 个势力")

                            if model.factionRankings.isEmpty {
                                QueueEmptyLine(title: "暂无排名", systemImage: "list.number")
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(model.factionRankings) { ranking in
                                        RankingRow(ranking: ranking, isPlayer: ranking.factionID == model.universe.playerFactionID)

                                        if ranking.id != model.factionRankings.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 920, alignment: .leading)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle("排名")
    }
}

private struct RankingRow: View {
    let ranking: FactionScore
    let isPlayer: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("#\(ranking.rank)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .frame(width: 44, alignment: .leading)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ranking.factionName.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    if isPlayer {
                        StrategicChip(title: "玩家", systemImage: "person.crop.circle", tint: .blue)
                    }

                    Spacer(minLength: 12)

                    Text(Formatters.wholeNumber(ranking.totalScore))
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                ProgressView(value: ranking.victoryProgress)
                    .tint(isPlayer ? Color.blue : Color.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    StrategicMetric(title: "经济", value: Formatters.wholeNumber(ranking.economyScore))
                    StrategicMetric(title: "舰队", value: Formatters.wholeNumber(ranking.fleetScore))
                    StrategicMetric(title: "研究", value: Formatters.wholeNumber(ranking.researchScore))
                    StrategicMetric(title: "星球", value: Formatters.wholeNumber(ranking.planetScore))
                    StrategicMetric(title: "防御", value: Formatters.wholeNumber(ranking.defenseScore))
                }
            }
        }
        .padding(.vertical, 10)
    }
}

private struct VictoryProgressView: View {
    @ObservedObject var model: AppModel

    private var playerRoutes: [VictoryProgressSummary] {
        model.victoryProgressSummaries.filter(\.isPlayer)
    }

    private var leadingRoutes: [VictoryProgressSummary] {
        Array(model.victoryProgressSummaries.sorted { lhs, rhs in
            if lhs.progress != rhs.progress {
                return lhs.progress > rhs.progress
            }
            if lhs.factionName != rhs.factionName {
                return lhs.factionName < rhs.factionName
            }
            return lhs.route.rawValue < rhs.route.rawValue
        }.prefix(8))
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("胜利")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    VictoryBannerView(summary: model.victoryBannerSummary)

                    VictoryRoutePanel(title: "玩家路线", routes: playerRoutes)
                    VictoryRoutePanel(title: "路线领先者", routes: leadingRoutes)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle("胜利")
    }
}

private struct VictoryBannerView: View {
    let summary: VictoryBannerSummary
    var compact = false

    var body: some View {
        PanelSurface {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: summary.isComplete ? "flag.checkered" : "flag")
                    .foregroundStyle(summary.isComplete ? Color.green : Color.blue)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.title)
                        .font(compact ? .headline : .title2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(summary.detail)
                        .font(compact ? .caption : .callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

private struct VictoryRoutePanel: View {
    let title: String
    let routes: [VictoryProgressSummary]

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: title, detail: routes.isEmpty ? "无进度" : "\(routes.count) 条路线")

                if routes.isEmpty {
                    QueueEmptyLine(title: "暂无胜利路线进度", systemImage: "flag")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(routes) { route in
                            VictoryRouteRow(route: route)

                            if route.id != routes.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}

private struct VictoryRouteRow: View {
    let route: VictoryProgressSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: route.route.systemImage)
                .foregroundStyle(route.isPlayer ? Color.blue : Color.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(route.route.localizedName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(route.factionName.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(Formatters.percent(route.progress))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                ProgressView(value: route.progress)
                    .tint(route.isPlayer ? Color.blue : Color.secondary)

                Text("\(Formatters.wholeNumber(route.currentValue)) / \(Formatters.wholeNumber(route.targetValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct FactionRelationsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("关系")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    PanelSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "势力关系", detail: "\(model.relationSummaries.count) 个接触")

                            if model.relationSummaries.isEmpty {
                                QueueEmptyLine(title: "暂无势力接触", systemImage: "person.2.wave.2")
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(model.relationSummaries) { summary in
                                        FactionRelationRow(summary: summary)

                                        if summary.id != model.relationSummaries.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 860, alignment: .leading)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle("关系")
    }
}

private struct FactionRelationRow: View {
    let summary: FactionRelationSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: summary.posture.systemImage)
                .foregroundStyle(summary.posture.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.factionName.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    StrategicChip(
                        title: summary.posture.localizedName,
                        systemImage: summary.posture.systemImage,
                        tint: summary.posture.tint
                    )

                    Spacer(minLength: 12)

                    Text(summary.perspective)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(summary.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    StrategicMetric(title: "策略", value: summary.strategy.localizedName)
                    StrategicMetric(title: "威胁", value: "\(summary.threatScore)")
                    StrategicMetric(title: "攻击", value: "\(summary.attackCount)")
                    StrategicMetric(title: "最近", value: lastInteractionText)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var lastInteractionText: String {
        summary.lastInteractionTime > 0 ? "T+\(Formatters.wholeSeconds(summary.lastInteractionTime))" : "无"
    }
}

private struct ResearchOverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("研究")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    ResearchQueueView(model: model)
                    ResearchControlsView(model: model)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle("研究")
    }
}

private struct ResearchQueueView: View {
    @ObservedObject var model: AppModel

    private var queue: [ResearchQueueItem] {
        model.playerFaction?.researchQueue ?? []
    }

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: "研究队列",
                    detail: queue.isEmpty ? "空闲" : "\(queue.count) 个进行中"
                )

                if queue.isEmpty {
                    QueueEmptyLine(title: "没有进行中的研究", systemImage: "atom")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(queue) { item in
                            ResearchQueueRow(item: item, model: model)

                            if item.id != queue.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }
}

private struct ResearchQueueRow: View {
    let item: ResearchQueueItem
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.technologyKind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.technologyKind.localizedName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(model.queueRemainingText(until: item.finishTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Text(model.researchQueueStatus(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: model.queueProgress(startTime: item.startTime, finishTime: item.finishTime))
            }
        }
        .padding(.vertical, 10)
    }
}

private struct ResearchControlsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: "科技",
                    detail: model.playerFaction?.researchQueue.isEmpty == false ? "队列忙碌" : "就绪"
                )

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.availableResearchKinds, id: \.self) { technology in
                        ResearchUpgradeRow(technology: technology, model: model)

                        if technology != model.availableResearchKinds.last {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }
}

private struct ResearchUpgradeRow: View {
    let technology: TechnologyKind
    @ObservedObject var model: AppModel

    private var cost: ResourceBundle? {
        model.researchCost(for: technology)
    }

    private var canAfford: Bool {
        model.canAffordResearch(technology)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: technology.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(technology.localizedName)
                    .font(.headline)
                    .lineLimit(1)

                Text("等级 \(model.researchLevel(for: technology)) -> \(model.nextResearchLevel(for: technology))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ResourceCostLine(
                    cost: cost,
                    durationText: model.durationText(model.researchDuration(for: technology)),
                    canAfford: canAfford
                )

                if let lockedReason = model.researchLockedReason(technology) {
                    Text(lockedReason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            Button {
                model.startResearch(technology)
            } label: {
                Label("研究", systemImage: "play.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .disabled(!model.canStartResearch(technology))
            .help(model.researchLockedReason(technology) ?? "加入研究队列")
        }
        .padding(.vertical, 10)
    }
}

private struct ManagementListView<Content: View>: View {
    let title: String
    let emptyTitle: String
    let emptySystemImage: String
    let isEmpty: Bool
    @ObservedObject var model: AppModel
    let content: Content

    init(
        title: String,
        emptyTitle: String,
        emptySystemImage: String,
        isEmpty: Bool,
        model: AppModel,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.isEmpty = isEmpty
        self.model = model
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if isEmpty {
                        EmptyStateView(title: emptyTitle, systemImage: emptySystemImage)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            content
                        }
                        .padding(.horizontal, 14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.secondary.opacity(0.16))
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle(title)
    }
}

private struct EventStyleRow: View {
    let title: String
    let detail: String
    let accessory: String?
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let accessory {
                Text(accessory)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct StrategicMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.callout.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StrategicChip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct StrategicResourceLine: View {
    let title: String
    let resources: ResourceBundle

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)

            Text("金 \(Formatters.wholeNumber(resources.metal))")
            Text("晶 \(Formatters.wholeNumber(resources.crystal))")
            Text("重 \(Formatters.wholeNumber(resources.deuterium))")
        }
        .font(.caption)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

private struct ResourceCostLine: View {
    let cost: ResourceBundle?
    let durationText: String
    let canAfford: Bool

    var body: some View {
        if let cost {
            HStack(spacing: 8) {
                Text("金 \(Formatters.wholeNumber(cost.metal))")
                Text("晶 \(Formatters.wholeNumber(cost.crystal))")
                Text("重 \(Formatters.wholeNumber(cost.deuterium))")
                Text("时间 \(durationText)")
            }
            .font(.caption)
            .foregroundStyle(canAfford ? Color.secondary : Color.red)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        } else {
            Text("规则不可用")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }
}

private struct QueueEmptyLine: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PanelSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16))
            }
    }
}

private struct ResourceCard: View {
    let title: String
    let resources: ResourceBundle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: title, detail: nil)
            ResourceGrid(resources: resources)
        }
        .padding(14)
        .frame(maxWidth: 360, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.16))
        }
    }
}

private struct InventoryCard<Key: RawRepresentable & Hashable>: View where Key.RawValue == String {
    let title: String
    let values: [Key: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: title, detail: nil)

            if values.isEmpty {
                EmptyStateView(title: "无", systemImage: "tray")
            } else {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    ForEach(values.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { key in
                        GridRow {
                            Text(key.rawValue.displayName)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text(Formatters.wholeNumber(Double(values[key, default: 0])))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .lineLimit(1)
                        }
                    }
                }
                .font(.callout)
            }
        }
        .padding(14)
        .frame(maxWidth: 420, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.16))
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }
}

private struct EmptyStateView: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension GameEvent {
    var localizedTitle: String {
        LocalizedGameText.title(title)
    }

    var localizedMessage: String {
        LocalizedGameText.message(message)
    }
}

private extension Report {
    var localizedTitle: String {
        LocalizedGameText.title(title)
    }

    var localizedSummary: String {
        LocalizedGameText.reportSummary(summary)
    }
}

private enum LocalizedGameText {
    static func title(_ text: String) -> String {
        switch text {
        case "Command Link Established":
            return "指挥链路已建立"
        case "Economy Updated":
            return "经济已更新"
        case "Simulation Advanced":
            return "模拟已推进"
        case "Offline Catch-Up Complete":
            return "离线补算完成"
        case "Construction Complete":
            return "建造完成"
        case "Research Complete":
            return "研究完成"
        case "Ship Construction Complete":
            return "舰船建造完成"
        case "Defense Construction Complete":
            return "防御建造完成"
        case "Missile Construction Complete":
            return "导弹建造完成"
        case "Fleet Launched":
            return "舰队已派遣"
        case "Transport Delivered":
            return "运输已送达"
        case "Debris Recovered":
            return "残骸已回收"
        case "Exploration Complete":
            return "探索完成"
        case "Colony Established":
            return "殖民地已建立"
        case "Combat Resolved":
            return "战斗已结算"
        case "Espionage Report":
            return "侦察报告"
        case "Fleet Lost Contact":
            return "舰队失联"
        case "Fleet Returned":
            return "舰队返航"
        case "Missile Strike":
            return "导弹打击"
        case "Victory Achieved":
            return "达成胜利"
        default:
            if let coordinate = suffix(in: text, after: "Battle deferred at ") {
                return "战斗延期 \(coordinate)"
            }
            if let coordinate = suffix(in: text, after: "Battle at ") {
                return "战斗报告 \(coordinate)"
            }
            if let coordinate = suffix(in: text, after: "Espionage at ") {
                return "侦察报告 \(coordinate)"
            }
            if let coordinate = suffix(in: text, after: "Exploration at ") {
                return "探索报告 \(coordinate)"
            }
            if let coordinate = suffix(in: text, after: "Missile strike at ") {
                return "导弹打击 \(coordinate)"
            }
            return text.displayName
        }
    }

    static func message(_ text: String) -> String {
        switch text {
        case "Your first colony is online. Rival factions are already moving.":
            return "第一座殖民地已上线，敌对势力已经开始行动。"
        case "Combat deferred because unit rules are incomplete.":
            return "单位规则不完整，战斗已延期。"
        case "The attacker won and recovered loot.":
            return "攻击方获胜并带回战利品。"
        case "The defender held the field.":
            return "防守方守住了战场。"
        default:
            if let localized = localizedFleetLaunch(text) {
                return localized
            }
            if let localized = localizedFleetResolution(text) {
                return localized
            }
            if let localized = localizedVictory(text) {
                return localized
            }
            if let localized = localizedCompletion(text) {
                return localized
            }
            if let localized = localizedMissileStrike(text) {
                return localized
            }
            if let localized = localizedSimulationTick(text) {
                return localized
            }
            if let localized = localizedEconomyTick(text) {
                return localized
            }
            if let localized = localizedOfflineSummary(text) {
                return localized
            }
            return text
        }
    }

    static func reportSummary(_ text: String) -> String {
        if let localized = localizedEspionageSummary(text) {
            return localized
        }
        if let localized = localizedExplorationSummary(text) {
            return localized
        }
        if let localized = localizedMissileSummary(text) {
            return localized
        }
        return message(text)
    }

    private static func localizedFleetLaunch(_ text: String) -> String? {
        guard let launchedRange = text.range(of: " launched a ") else {
            return nil
        }
        let origin = String(text[..<launchedRange.lowerBound]).displayName
        let rest = String(text[launchedRange.upperBound...])
        guard let missionRange = rest.range(of: " fleet to ") else {
            return nil
        }
        let mission = String(rest[..<missionRange.lowerBound]).displayName
        let target = trimmedPeriod(String(rest[missionRange.upperBound...]))
        return "\(origin) 派遣\(mission)舰队前往 \(target)。"
    }

    private static func localizedFleetResolution(_ text: String) -> String? {
        guard let range = text.range(of: " fleet "),
              let resolvedRange = text.range(of: " resolved at ")
        else {
            return nil
        }
        let mission = String(text[..<range.lowerBound]).lowercased().displayName
        let target = trimmedPeriod(String(text[resolvedRange.upperBound...]))
        return "\(mission)舰队已在 \(target) 结算。"
    }

    private static func localizedCompletion(_ text: String) -> String? {
        guard let completedRange = text.range(of: " completed ") else {
            return nil
        }
        let subject = String(text[..<completedRange.lowerBound]).displayName
        let detail = trimmedPeriod(String(text[completedRange.upperBound...]))

        if let levelRange = detail.range(of: " level ") {
            let name = String(detail[..<levelRange.lowerBound]).displayName
            let level = String(detail[levelRange.upperBound...])
            return "\(subject) 完成\(name)等级 \(level)。"
        }

        let parts = detail.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            return "\(subject) 完成 \(parts[0]) 个\(parts[1].displayName)。"
        }

        return nil
    }

    private static func localizedMissileStrike(_ text: String) -> String? {
        guard let launchedRange = text.range(of: " launched "),
              let missilesRange = text.range(of: " missiles at ")
        else {
            return nil
        }
        let origin = String(text[..<launchedRange.lowerBound]).displayName
        let count = String(text[launchedRange.upperBound..<missilesRange.lowerBound])
        let target = trimmedPeriod(String(text[missilesRange.upperBound...]))
        return "\(origin) 向 \(target) 发射 \(count) 枚导弹。"
    }

    private static func localizedSimulationTick(_ text: String) -> String? {
        guard let seconds = suffix(in: text, after: "Advanced the universe by ") else {
            return nil
        }
        return "宇宙已推进 \(trimmedPeriod(seconds).replacingOccurrences(of: " seconds", with: " 秒"))。"
    }

    private static func localizedEconomyTick(_ text: String) -> String? {
        guard text.hasPrefix("Produced resources for ") else {
            return nil
        }
        return "已为己方星球结算资源生产。"
    }

    private static func localizedOfflineSummary(_ text: String) -> String? {
        guard text.hasPrefix("Caught up ") else {
            return nil
        }
        return "离线进度已补算，并汇总了期间产生的事件。"
    }

    private static func localizedVictory(_ text: String) -> String? {
        guard let range = text.range(of: " completed the "),
              text.hasSuffix(" victory route.")
        else {
            return nil
        }
        let faction = String(text[..<range.lowerBound]).displayName
        let route = String(text[range.upperBound...]).replacingOccurrences(of: " victory route.", with: "").displayName
        return "\(faction) 已完成\(route)胜利路线。"
    }

    private static func localizedEspionageSummary(_ text: String) -> String? {
        guard text.hasPrefix("Resources ") else {
            return nil
        }
        return text
            .replacingOccurrences(of: "Resources ", with: "资源 ")
            .replacingOccurrences(of: "; ships ", with: "；舰船 ")
            .replacingOccurrences(of: "; defenses ", with: "；防御 ")
            .replacingOccurrences(of: ".", with: "。")
    }

    private static func localizedExplorationSummary(_ text: String) -> String? {
        guard text.hasPrefix("Exploration found a ") else {
            return nil
        }
        return text
            .replacingOccurrences(of: "Exploration found a neutral target", with: "探索发现中立目标")
            .replacingOccurrences(of: "Exploration found a occupied target", with: "探索发现已占领目标")
            .replacingOccurrences(of: "; reward ", with: "；奖励 ")
            .replacingOccurrences(of: "; resources ", with: "；资源 ")
            .replacingOccurrences(of: "; debris ", with: "；残骸 ")
            .replacingOccurrences(of: ".", with: "。")
    }

    private static func localizedMissileSummary(_ text: String) -> String? {
        guard text.hasPrefix("Interplanetary missiles damaged ") else {
            return nil
        }
        return text
            .replacingOccurrences(of: "Interplanetary missiles damaged ", with: "星际导弹摧毁 ")
            .replacingOccurrences(of: " defensive units.", with: " 个防御单位。")
    }

    private static func suffix(in text: String, after prefix: String) -> String? {
        guard text.hasPrefix(prefix) else {
            return nil
        }
        return String(text.dropFirst(prefix.count))
    }

    private static func trimmedPeriod(_ text: String) -> String {
        text.hasSuffix(".") ? String(text.dropLast()) : text
    }
}

private extension GameEvent {
    var symbolName: String {
        switch kind {
        case .system:
            return "gearshape"
        case .economy:
            return "chart.line.uptrend.xyaxis"
        case .intelligence:
            return "eye"
        case .combat:
            return "target"
        case .exploration:
            return "sparkles"
        case .victory:
            return "flag.checkered"
        }
    }
}

private enum Formatters {
    static func wholeSeconds(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else {
            return "未知"
        }

        return wholeNumber(seconds) + " 秒"
    }

    static func wholeNumber(_ value: Double) -> String {
        guard value.isFinite else {
            return "未知"
        }

        return value.formatted(.number.precision(.fractionLength(0)))
    }

    static func signedWholeNumber(_ value: Double) -> String {
        guard value.isFinite else {
            return "未知"
        }

        let formatted = wholeNumber(abs(value))
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    static func percent(_ value: Double) -> String {
        guard value.isFinite else {
            return "未知"
        }

        return value.formatted(.percent.precision(.fractionLength(0)))
    }
}

private extension ResourceStorage {
    var resourceBundle: ResourceBundle {
        ResourceBundle(metal: metal, crystal: crystal, deuterium: deuterium)
    }
}

private extension BuildingKind {
    var systemImage: String {
        switch self {
        case .metalMine:
            return "cube.box"
        case .crystalMine:
            return "diamond"
        case .deuteriumSynthesizer:
            return "drop"
        case .solarPlant:
            return "sun.max"
        case .roboticsFactory:
            return "gearshape.2"
        case .shipyard:
            return "wrench.and.screwdriver"
        case .researchLab:
            return "testtube.2"
        case .metalStorage:
            return "shippingbox"
        case .crystalStorage:
            return "shippingbox.fill"
        case .deuteriumTank:
            return "cylinder"
        case .naniteFactory:
            return "cpu"
        }
    }
}

private extension TechnologyKind {
    var systemImage: String {
        switch self {
        case .espionage:
            return "eye"
        case .computer:
            return "desktopcomputer"
        case .weapons:
            return "scope"
        case .shielding:
            return "shield"
        case .armor:
            return "hexagon"
        case .energy:
            return "bolt"
        case .combustionDrive:
            return "flame"
        case .impulseDrive:
            return "wave.3.forward"
        case .hyperspaceDrive:
            return "sparkles"
        }
    }
}

private extension UnitBuildQueueItem {
    var systemImage: String {
        switch unitKind {
        case .ship(let kind):
            return kind.systemImage
        case .defense(let kind):
            return kind.systemImage
        case .missile(let kind):
            return kind.systemImage
        }
    }
}

private extension ShipKind {
    var systemImage: String {
        switch self {
        case .smallCargo, .largeCargo:
            return "shippingbox"
        case .lightFighter, .heavyFighter:
            return "paperplane"
        case .cruiser:
            return "airplane"
        case .battleship:
            return "scope"
        case .colonyShip:
            return "flag"
        case .recycler:
            return "arrow.triangle.2.circlepath"
        case .espionageProbe:
            return "eye"
        }
    }
}

private extension DefenseKind {
    var systemImage: String {
        switch self {
        case .rocketLauncher:
            return "target"
        case .lightLaser, .heavyLaser:
            return "laser.burst"
        case .gaussCannon:
            return "dot.scope"
        case .ionCannon:
            return "bolt"
        case .plasmaTurret:
            return "shield.lefthalf.filled"
        }
    }
}

private extension MissileKind {
    var systemImage: String {
        switch self {
        case .interplanetaryMissile:
            return "scope"
        }
    }
}

private extension Fleet.Mission {
    var systemImage: String {
        switch self {
        case .transport:
            return "shippingbox"
        case .colonize:
            return "flag"
        case .espionage:
            return "eye"
        case .attack:
            return "target"
        case .recycle:
            return "arrow.triangle.2.circlepath"
        case .explore:
            return "sparkles"
        case .returning:
            return "arrow.uturn.backward"
        }
    }
}

private extension VictoryRoute {
    var systemImage: String {
        switch self {
        case .economy:
            return "chart.line.uptrend.xyaxis"
        case .technology:
            return "atom"
        case .domination:
            return "scope"
        case .exploration:
            return "sparkles"
        }
    }
}

private extension RelationPosture {
    var systemImage: String {
        switch self {
        case .neutral:
            return "circle"
        case .wary:
            return "exclamationmark.triangle"
        case .hostile:
            return "target"
        case .pressured:
            return "shield.lefthalf.filled"
        }
    }

    var tint: Color {
        switch self {
        case .neutral:
            return .secondary
        case .wary:
            return .orange
        case .hostile:
            return .red
        case .pressured:
            return .purple
        }
    }
}

private extension Report.Kind {
    var systemImage: String {
        switch self {
        case .battle:
            return "target"
        case .espionage:
            return "eye"
        case .exploration:
            return "sparkles"
        case .missile:
            return "scope"
        }
    }
}
