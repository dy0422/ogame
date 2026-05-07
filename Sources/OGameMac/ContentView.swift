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

            if let offlineSummaryText = model.offlineSummaryText {
                OfflineSummaryLine(summaryText: offlineSummaryText)
            }

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
        guard let target = model.planet(for: targetID) else {
            return "missing"
        }

        return [
            target.id.rawValue.uuidString,
            target.ownerID?.rawValue.uuidString ?? "unowned",
            Formatters.wholeNumber(target.debrisField.metal),
            Formatters.wholeNumber(target.debrisField.crystal),
            Formatters.wholeNumber(target.debrisField.deuterium)
        ].joined(separator: "|")
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
                    PlanetPicker(title: "Target", selection: $targetID, planets: model.targetPlanets(excluding: originID), emptyTitle: "No target")

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

    var body: some View {
        PanelSurface {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Reports", detail: reportsDetail)

                if model.recentReports.isEmpty && model.recentExplorationEvents.isEmpty {
                    QueueEmptyLine(title: "No reports recorded", systemImage: "doc.text.magnifyingglass")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.recentReports) { report in
                            ReportRow(report: report, model: model)

                            if report.id != model.recentReports.last?.id || !model.recentExplorationEvents.isEmpty {
                                Divider()
                            }
                        }

                        ForEach(model.recentExplorationEvents) { event in
                            ExplorationEventReportRow(event: event)

                            if event.id != model.recentExplorationEvents.last?.id {
                                Divider()
                            }
                        }
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
