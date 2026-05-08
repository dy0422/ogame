import OGameCore
import SwiftUI

struct PlanetHeroPanel: View {
    let planet: Planet
    @ObservedObject var model: AppModel

    var body: some View {
        PanelSurface {
            HStack(alignment: .top, spacing: 18) {
                ServerAssetThumbnail(
                    url: GameArt.planetImageURL(for: planet),
                    fallbackSystemImage: "globe.europe.africa.fill",
                    size: 132
                )

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(planet.name.displayName)
                            .font(.largeTitle.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        HStack(spacing: 8) {
                            GameStatusPill(title: planet.coordinate.displayText, systemImage: "scope", tint: .blue)
                            GameStatusPill(
                                title: "温度 \(Formatters.wholeNumber(planet.temperatureCelsius))°C",
                                systemImage: "thermometer.medium",
                                tint: planet.temperatureCelsius < 0 ? .cyan : .orange
                            )
                            if planet.moon != nil {
                                GameStatusPill(title: "月球", systemImage: "moon.stars", tint: .purple)
                            }
                        }
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 130), alignment: .topLeading)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        GameMetricTile(
                            title: "能源",
                            value: Formatters.percent(model.energySupplyRatio(for: planet)),
                            systemImage: "bolt.fill",
                            tint: planet.energy.available >= 0 ? .green : .red
                        )
                        GameMetricTile(
                            title: "建筑队列",
                            value: planet.buildQueue.isEmpty ? "空闲" : "\(planet.buildQueue.count)",
                            systemImage: "hammer",
                            tint: planet.buildQueue.isEmpty ? .orange : .blue
                        )
                        GameMetricTile(
                            title: "造船队列",
                            value: planet.shipBuildQueue.isEmpty ? "空闲" : "\(planet.shipBuildQueue.count)",
                            systemImage: "wrench.and.screwdriver",
                            tint: planet.shipBuildQueue.isEmpty ? .secondary : .blue
                        )
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
    }
}
