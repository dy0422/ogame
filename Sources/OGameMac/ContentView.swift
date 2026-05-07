import OGameCore
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
    case research
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
        case .research:
            ResearchOverviewView(model: model)
        }
    }
}

private struct DashboardView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HeaderView(universe: model.universe, faction: model.playerFaction)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Recent Events", detail: "\(events.count) shown")

            if events.isEmpty {
                EmptyStateView(title: "No events recorded", systemImage: "text.bubble")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(events) { event in
                        EventRow(event: event)

                        if event.id != events.last?.id {
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

private struct EventRow: View {
    let event: GameEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(1)

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
            }
        }
        .padding(.vertical, 10)
    }

    private var symbolName: String {
        switch event.kind {
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

            VStack(spacing: 8) {
                Button {
                    model.advanceOneMinute()
                } label: {
                    Label("Advance 1 Minute", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canSave)

                Button {
                    model.save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!model.canSave)

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
            StatusMetric(title: "Save", value: model.canSave ? "Ready" : "Protected")

            Spacer()
        }
        .padding(20)
        .frame(width: 280, alignment: .topLeading)
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
                    BuildQueueView(planet: planet, model: model)
                    BuildingControlsView(planet: planet, model: model)
                    InventoryCard(title: "Ships", values: planet.shipInventory)
                    InventoryCard(title: "Defense", values: planet.defenseInventory)
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

private struct BuildQueueView: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: "Construction Queue",
                    detail: planet.buildQueue.isEmpty ? "Idle" : "\(planet.buildQueue.count) active"
                )

                if planet.buildQueue.isEmpty {
                    QueueEmptyLine(title: "No active construction", systemImage: "hammer")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(planet.buildQueue) { item in
                            BuildQueueRow(item: item, model: model)

                            if item.id != planet.buildQueue.last?.id {
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

private struct FleetOverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ManagementListView(
            title: "Fleets",
            emptyTitle: "No active fleets",
            emptySystemImage: "paperplane",
            isEmpty: model.universe.fleets.isEmpty,
            model: model
        ) {
            ForEach(model.universe.fleets) { fleet in
                EventStyleRow(
                    title: fleet.mission.rawValue.capitalized,
                    detail: "\(fleet.origin.displayText) to \(fleet.target.displayText)",
                    accessory: fleet.phase.rawValue.capitalized,
                    systemImage: "paperplane"
                )
            }
        }
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

                Text(detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
