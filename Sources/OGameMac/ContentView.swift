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
            Section("Empire") {
                Label("Dashboard", systemImage: "chart.bar")
                    .tag(SidebarDestination.dashboard)

                Label("Fleets", systemImage: "paperplane")
                    .tag(SidebarDestination.fleets)

                Label("Research", systemImage: "atom")
                    .tag(SidebarDestination.research)
            }

            Section("Strategy") {
                Label("Star Map", systemImage: "map")
                    .tag(SidebarDestination.starMap)

                Label("Rankings", systemImage: "list.number")
                    .tag(SidebarDestination.rankings)

                Label("Victory", systemImage: "flag.checkered")
                    .tag(SidebarDestination.victory)

                Label("Relations", systemImage: "person.2.wave.2")
                    .tag(SidebarDestination.relations)
            }

            Section("System") {
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarDestination.settings)
            }

            Section("Planets") {
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
                Text(planet.name)
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
        .navigationTitle("Dashboard")
    }
}

private struct HeaderView: View {
    let universe: Universe
    let faction: Faction?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(universe.name)
                .font(.largeTitle.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 12) {
                Label(faction?.name ?? "Unknown faction", systemImage: "person.crop.circle")
                Label("T+\(Formatters.wholeSeconds(universe.gameTime))", systemImage: "clock")
                Label(universe.ruleSet.displayName, systemImage: "speedometer")
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
            SectionTitle(title: "Planets", detail: "\(planets.count) colonies")

            if planets.isEmpty {
                EmptyStateView(title: "No owned planets", systemImage: "circle.dashed")
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
                Text(planet.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(planet.coordinate.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
            ResourceRow(label: "Metal", value: resources.metal)
            ResourceRow(label: "Crystal", value: resources.crystal)
            ResourceRow(label: "Deuterium", value: resources.deuterium)
        }
        .font(.callout)
    }
}

private struct ResourceRateGrid: View {
    let rates: ResourceBundle

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            ResourceRateRow(label: "Metal /h", value: rates.metal)
            ResourceRateRow(label: "Crystal /h", value: rates.crystal)
            ResourceRateRow(label: "Deuterium /h", value: rates.deuterium)
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
            SectionTitle(title: "Recent Events", detail: "\(events.count) shown")

            if events.isEmpty {
                EmptyStateView(title: "No events recorded", systemImage: "text.bubble")
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
            return "System"
        case .economy:
            return "Economy"
        case .intelligence:
            return "Intel"
        case .combat:
            return "Combat"
        case .exploration:
            return "Exploration"
        case .victory:
            return "Victory"
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
                    Text(event.title)
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

                Text(event.message)
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
            Text("Activity")
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
                .help(model.canSave ? model.advanceActionTitle : "Start a new game before advancing")

                Button {
                    model.save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!model.canSave)
                .help(model.canSave ? "Save universe" : "Saving is disabled until a new game starts")

                if !model.canSave {
                    Button {
                        model.startNewGame()
                    } label: {
                        Label("New Game", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Divider()

            StatusMetric(title: "Game Time", value: "T+\(Formatters.wholeSeconds(model.universe.gameTime))")
            StatusMetric(title: "Factions", value: Formatters.wholeNumber(Double(model.universe.factions.count)))
            StatusMetric(title: "Fleets", value: Formatters.wholeNumber(Double(model.universe.fleets.count)))
            StatusMetric(title: "Save", value: model.canSave ? model.autosaveStatusText : "Protected")
            StatusMetric(title: "Settings", value: model.settingsStatusText)

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
                SectionTitle(title: "First Launch", detail: "Quick setup")

                Text("A new commander profile is ready. Review autosave and simulation speed, then save when you want this universe to become the current autosave.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        model.dismissOnboarding()
                    } label: {
                        Label("Start Playing", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.save()
                        model.dismissOnboarding()
                    } label: {
                        Label("Save Now", systemImage: "square.and.arrow.down")
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
                    Text("Settings")
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
        .navigationTitle("Settings")
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
                SectionTitle(title: "Simulation", detail: model.settingsStatusText)

                Toggle(isOn: autosaveBinding) {
                    Label("Autosave queue and fleet actions", systemImage: "externaldrive.badge.checkmark")
                }
                .toggleStyle(.checkbox)
                .disabled(!model.canSave)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Game Speed", systemImage: "speedometer")
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
                        title: "Offline Intensity",
                        systemImage: "moon.zzz",
                        selection: offlineIntensityBinding,
                        options: GameSettings.OfflineIntensity.allCases
                    ) { option in
                        option.displayName
                    }

                    SettingPicker(
                        title: "Difficulty",
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
                        Label("Save Settings", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: [.command])
                    .disabled(!model.canSave)
                    .help(model.canSave ? "Save settings" : "Saving is disabled until a new game starts")
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
                SectionTitle(title: "Save Management", detail: "\(model.saveSlots.count) slots")

                HStack(spacing: 10) {
                    Button {
                        model.createBackup()
                    } label: {
                        Label("Create Backup", systemImage: "archivebox")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreateBackup)

                    Button {
                        model.refreshSaveSlots()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }

                if model.saveSlots.isEmpty {
                    QueueEmptyLine(title: "Save autosave before creating backups", systemImage: "externaldrive.badge.plus")
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
                Label(slot.isAutosave ? "Autosave Protected" : "Delete Backup", systemImage: "trash")
            }
            .controlSize(.small)
            .disabled(slot.isAutosave)
        }
        .padding(.vertical, 10)
        .confirmationDialog(
            "Delete Backup",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete \(slot.name)", role: .destructive) {
                model.deleteSaveSlot(named: slot.name)
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete backup \(slot.name)? This cannot be undone.")
        }
    }

    private var slotDetail: String {
        let kind = slot.isAutosave ? "Autosave" : "Backup"
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
            Label("Offline Catch-Up", systemImage: "clock.arrow.circlepath")
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
                        Text(planet.name)
                            .font(.largeTitle.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(planet.coordinate.displayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    PlanetEconomyView(planet: planet, model: model)
                    ConstructionQueueView(planet: planet, model: model)
                    BuildingControlsView(planet: planet, model: model)
                    ShipyardControlsView(planet: planet, model: model)
                    InventoryCard(title: "Ships", values: planet.shipInventory)
                    InventoryCard(title: "Defense", values: planet.defenseInventory)
                    ResourceCard(title: "Debris Field", resources: planet.debrisField)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle(planet.name)
    }
}

private struct PlanetEconomyView: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Economy", detail: model.energyStatusText(for: planet))

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180), alignment: .topLeading)],
                    alignment: .leading,
                    spacing: 16
                ) {
                    EconomyColumn(title: "Resources") {
                        ResourceGrid(resources: planet.resources)
                    }

                    EconomyColumn(title: "Hourly Rates") {
                        ResourceRateGrid(rates: model.productionPerHour(for: planet))
                    }

                    EconomyColumn(title: "Storage") {
                        ResourceGrid(resources: planet.storage.resourceBundle)
                    }
                }

                EnergyMeterView(planet: planet, model: model)
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
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
                Label("Energy", systemImage: "bolt.fill")
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
                    title: "Queues",
                    detail: entries.isEmpty ? "Idle" : "\(entries.count) active"
                )

                if entries.isEmpty {
                    QueueEmptyLine(title: "No active construction", systemImage: "hammer")
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
                    Text(item.buildingKind.rawValue.displayName)
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
                    title: "Buildings",
                    detail: planet.buildQueue.isEmpty ? "Ready" : "Queue busy"
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
                Text(kind.rawValue.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text("Level \(model.buildingLevel(for: kind, on: planet)) -> \(model.nextBuildingLevel(for: kind, on: planet))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ResourceCostLine(
                    cost: cost,
                    durationText: model.durationText(model.buildingUpgradeDuration(for: planet, kind: kind)),
                    canAfford: canAfford
                )
            }

            Spacer(minLength: 12)

            Button {
                model.startBuildingUpgrade(planetID: planet.id, kind: kind)
            } label: {
                Label("Upgrade", systemImage: "arrow.up.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .disabled(!model.canStartBuildingUpgrade(planet: planet, kind: kind))
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
                    title: "Shipyard",
                    detail: shipyardDetail
                )

                UnitBuildSection(
                    title: "Ships",
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
                    title: "Defense",
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
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var shipyardDetail: String {
        if !planet.shipBuildQueue.isEmpty || !planet.defenseBuildQueue.isEmpty {
            return "Queues active"
        }

        return "Ready"
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
                QueueEmptyLine(title: "No rules available", systemImage: "tray")
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
                Text(kind.rawValue.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text("Owned \(planet.shipInventory[kind, default: 0])")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ResourceCostLine(
                    cost: cost,
                    durationText: model.durationText(model.shipBuildDuration(for: kind, quantity: quantity)),
                    canAfford: canAfford
                )
            }

            Spacer(minLength: 12)

            QuantityStepper(value: $quantity, range: 1...999)

            Button {
                model.startShipBuild(planetID: planet.id, kind: kind, quantity: quantity)
            } label: {
                Label("Build", systemImage: "plus.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .disabled(!model.canStartShipBuild(planet: planet, kind: kind, quantity: quantity))
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
                Text(kind.rawValue.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text("Owned \(planet.defenseInventory[kind, default: 0])")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ResourceCostLine(
                    cost: cost,
                    durationText: model.durationText(model.defenseBuildDuration(for: kind, quantity: quantity)),
                    canAfford: canAfford
                )
            }

            Spacer(minLength: 12)

            QuantityStepper(value: $quantity, range: 1...999)

            Button {
                model.startDefenseBuild(planetID: planet.id, kind: kind, quantity: quantity)
            } label: {
                Label("Build", systemImage: "plus.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .disabled(!model.canStartDefenseBuild(planet: planet, kind: kind, quantity: quantity))
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
            return "missing"
        }

        return model.availableShipKinds
            .map { "\($0.rawValue):\(origin.shipInventory[$0, default: 0])" }
            .joined(separator: "|")
    }

    private var targetStateSignature: String {
        model.fleetTargetStateSignature(targetID: targetID)
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Fleets")
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
        .navigationTitle("Fleets")
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

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "Dispatch", detail: selectedShipTotal == 0 ? "Select ships" : "\(selectedShipTotal) ships")

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), alignment: .topLeading)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    PlanetPicker(title: "Origin", selection: $originID, planets: model.playerPlanets, emptyTitle: "No colony")
                    FleetTargetPicker(
                        title: "Target",
                        selection: $targetID,
                        targets: model.fleetTargetSummaries(excluding: originID),
                        emptyTitle: "No target"
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mission")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Picker("Mission", selection: $mission) {
                            ForEach(model.fleetMissionKinds, id: \.rawValue) { option in
                                Label(option.rawValue.displayName, systemImage: option.systemImage)
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
                        Label("Launch", systemImage: "paperplane.fill")
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
                        Text("\(planet.name) \(planet.coordinate.displayText)")
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
            Label("Ships", systemImage: "paperplane")
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
                QueueEmptyLine(title: "Select an origin colony", systemImage: "paperplane")
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
                Text(kind.rawValue.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text("Available \(available)")
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
            Label("Cargo", systemImage: "shippingbox")
                .font(.callout.weight(.semibold))
                .lineLimit(1)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)],
                alignment: .leading,
                spacing: 10
            ) {
                CargoField(title: "Metal", value: $metalCargo)
                CargoField(title: "Crystal", value: $crystalCargo)
                CargoField(title: "Deuterium", value: $deuteriumCargo)
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
            DispatchMetric(title: "Capacity", value: "\(Formatters.wholeNumber(cargoUsed)) / \(Formatters.wholeNumber(cargoCapacity))")
            DispatchMetric(title: "Fuel", value: fuelText, isWarning: hasShipsSelected && !fuelIsAffordable)
            DispatchMetric(title: "Travel", value: model.durationText(model.fleetTravelDuration(originID: originID, targetID: targetID, ships: ships)))
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
                    title: "Active Fleets",
                    detail: model.activeFleets.isEmpty ? "Idle" : "\(model.activeFleets.count) in flight"
                )

                if model.activeFleets.isEmpty {
                    QueueEmptyLine(title: "No active fleets", systemImage: "paperplane")
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
                    Text(fleet.mission.rawValue.displayName)
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

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Reports", detail: reportsDetail)

                if model.recentReports.isEmpty && model.recentExplorationEvents.isEmpty {
                    QueueEmptyLine(title: "No reports recorded", systemImage: "doc.text.magnifyingglass")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ReportRowsSection(
                            title: "Battle",
                            systemImage: "target",
                            reports: battleReports,
                            model: model
                        )
                        SectionDivider(isVisible: !battleReports.isEmpty && (!espionageReports.isEmpty || !explorationReports.isEmpty || !model.recentExplorationEvents.isEmpty))

                        ReportRowsSection(
                            title: "Espionage",
                            systemImage: "eye",
                            reports: espionageReports,
                            model: model
                        )
                        SectionDivider(isVisible: !espionageReports.isEmpty && (!explorationReports.isEmpty || !model.recentExplorationEvents.isEmpty))

                        ReportRowsSection(
                            title: "Exploration",
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
        return count == 0 ? "None" : "\(count) recent"
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
                ReportGroupHeader(title: "Exploration Events", systemImage: "sparkles", count: events.count)

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
                    Text(report.title)
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

                Text(report.summary)
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
            title: event.title,
            detail: event.message,
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
                    Text("Star Map")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    PanelSurface {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), alignment: .topLeading)],
                            alignment: .leading,
                            spacing: 12
                        ) {
                            StrategicMetric(title: "Planets", value: Formatters.wholeNumber(Double(allPlanets.count)))
                            StrategicMetric(title: "Owned", value: Formatters.wholeNumber(Double(model.playerPlanets.count)))
                            StrategicMetric(title: "Debris", value: Formatters.wholeNumber(Double(debrisSystemCount)))
                            StrategicMetric(title: "Fleet Marks", value: Formatters.wholeNumber(Double(activeFleetTouchCount)))
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
        .navigationTitle("Star Map")
    }
}

private struct StarMapSectionView: View {
    let section: StarMapPlanetSection

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: section.kind.title, detail: "\(section.planets.count) systems")

                if section.planets.isEmpty {
                    QueueEmptyLine(title: "No systems in this section", systemImage: section.kind.systemImage)
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
                            title: "Debris \(Formatters.wholeNumber(summary.debrisTotal))",
                            systemImage: "sparkles",
                            tint: .orange
                        )
                    }

                    if summary.friendlyFleetCount > 0 {
                        StrategicChip(
                            title: "Fleet \(summary.friendlyFleetCount)",
                            systemImage: "paperplane",
                            tint: .blue
                        )
                    }

                    if summary.otherFleetCount > 0 {
                        StrategicChip(
                            title: "Contact \(summary.otherFleetCount)",
                            systemImage: "scope",
                            tint: .red
                        )
                    }

                    StrategicChip(
                        title: summary.isExploredByPlayer ? "Explored" : "Unscouted",
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
            return "Owned"
        }

        if !summary.isVisible {
            return "Unknown"
        }

        if summary.ownerKind == .ai {
            return "AI"
        }

        return "Neutral"
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
                    title: "Exploration Intel",
                    detail: summaries.isEmpty ? "No records" : "\(summaries.count) recent"
                )

                if summaries.isEmpty {
                    QueueEmptyLine(title: "No explored systems recorded", systemImage: "sparkles")
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
                    Text(summary.planet.name)
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

                Text("Owner \(summary.ownerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                StrategicResourceLine(title: "Reward", resources: summary.reward)
                StrategicResourceLine(title: "Resources", resources: summary.discoveredResources)
                StrategicResourceLine(title: "Debris", resources: summary.discoveredDebris)
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
                    Text("Rankings")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    PanelSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "Faction Standings", detail: "\(model.factionRankings.count) factions")

                            if model.factionRankings.isEmpty {
                                QueueEmptyLine(title: "No rankings available", systemImage: "list.number")
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
        .navigationTitle("Rankings")
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
                    Text(ranking.factionName)
                        .font(.headline)
                        .lineLimit(1)

                    if isPlayer {
                        StrategicChip(title: "Player", systemImage: "person.crop.circle", tint: .blue)
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
                    StrategicMetric(title: "Economy", value: Formatters.wholeNumber(ranking.economyScore))
                    StrategicMetric(title: "Fleet", value: Formatters.wholeNumber(ranking.fleetScore))
                    StrategicMetric(title: "Research", value: Formatters.wholeNumber(ranking.researchScore))
                    StrategicMetric(title: "Planets", value: Formatters.wholeNumber(ranking.planetScore))
                    StrategicMetric(title: "Defense", value: Formatters.wholeNumber(ranking.defenseScore))
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
                    Text("Victory")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    VictoryBannerView(summary: model.victoryBannerSummary)

                    VictoryRoutePanel(title: "Player Routes", routes: playerRoutes)
                    VictoryRoutePanel(title: "Route Leaders", routes: leadingRoutes)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            ActivityPanel(model: model)
        }
        .navigationTitle("Victory")
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
                SectionTitle(title: title, detail: routes.isEmpty ? "No progress" : "\(routes.count) routes")

                if routes.isEmpty {
                    QueueEmptyLine(title: "No route progress available", systemImage: "flag")
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
                    Text(route.route.rawValue.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(route.factionName)
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
                    Text("Relations")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    PanelSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "Faction Relations", detail: "\(model.relationSummaries.count) contacts")

                            if model.relationSummaries.isEmpty {
                                QueueEmptyLine(title: "No faction contacts available", systemImage: "person.2.wave.2")
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
        .navigationTitle("Relations")
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
                    Text(summary.factionName)
                        .font(.headline)
                        .lineLimit(1)

                    StrategicChip(
                        title: summary.posture.rawValue.displayName,
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
                    StrategicMetric(title: "Strategy", value: summary.strategy.rawValue.displayName)
                    StrategicMetric(title: "Threat", value: "\(summary.threatScore)")
                    StrategicMetric(title: "Attacks", value: "\(summary.attackCount)")
                    StrategicMetric(title: "Last", value: lastInteractionText)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var lastInteractionText: String {
        summary.lastInteractionTime > 0 ? "T+\(Formatters.wholeSeconds(summary.lastInteractionTime))" : "None"
    }
}

private struct ResearchOverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Research")
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
        .navigationTitle("Research")
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
                    title: "Research Queue",
                    detail: queue.isEmpty ? "Idle" : "\(queue.count) active"
                )

                if queue.isEmpty {
                    QueueEmptyLine(title: "No active research", systemImage: "atom")
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
                    Text(item.technologyKind.rawValue.displayName)
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
                    title: "Technologies",
                    detail: model.playerFaction?.researchQueue.isEmpty == false ? "Queue busy" : "Ready"
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
                Text(technology.rawValue.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text("Level \(model.researchLevel(for: technology)) -> \(model.nextResearchLevel(for: technology))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ResourceCostLine(
                    cost: cost,
                    durationText: model.durationText(model.researchDuration(for: technology)),
                    canAfford: canAfford
                )
            }

            Spacer(minLength: 12)

            Button {
                model.startResearch(technology)
            } label: {
                Label("Research", systemImage: "play.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .disabled(!model.canStartResearch(technology))
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

            Text("M \(Formatters.wholeNumber(resources.metal))")
            Text("C \(Formatters.wholeNumber(resources.crystal))")
            Text("D \(Formatters.wholeNumber(resources.deuterium))")
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
                Text("M \(Formatters.wholeNumber(cost.metal))")
                Text("C \(Formatters.wholeNumber(cost.crystal))")
                Text("D \(Formatters.wholeNumber(cost.deuterium))")
                Text("Time \(durationText)")
            }
            .font(.caption)
            .foregroundStyle(canAfford ? Color.secondary : Color.red)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        } else {
            Text("Rule unavailable")
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
                EmptyStateView(title: "None", systemImage: "tray")
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
            return "unknown"
        }

        return wholeNumber(seconds) + "s"
    }

    static func wholeNumber(_ value: Double) -> String {
        guard value.isFinite else {
            return "unknown"
        }

        return value.formatted(.number.precision(.fractionLength(0)))
    }

    static func signedWholeNumber(_ value: Double) -> String {
        guard value.isFinite else {
            return "unknown"
        }

        let formatted = wholeNumber(abs(value))
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    static func percent(_ value: Double) -> String {
        guard value.isFinite else {
            return "unknown"
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
        }
    }
}

private extension String {
    var displayName: String {
        reduce(into: "") { result, character in
            if character.isUppercase, !result.isEmpty {
                result.append(" ")
            }
            result.append(character)
        }
        .capitalized
    }
}
