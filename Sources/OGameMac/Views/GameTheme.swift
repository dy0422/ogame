import SwiftUI

enum GameTheme {
    static let cardRadius: CGFloat = 8
    static let compactRadius: CGFloat = 6
    static let panelStrokeOpacity = 0.16
    static let softFillOpacity = 0.10
}

struct GameStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(tint.opacity(GameTheme.softFillOpacity), in: RoundedRectangle(cornerRadius: GameTheme.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GameTheme.compactRadius, style: .continuous)
                    .stroke(tint.opacity(0.18))
            }
    }
}

struct GameMetricTile: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    var tint: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: GameTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GameTheme.cardRadius, style: .continuous)
                .stroke(tint.opacity(GameTheme.panelStrokeOpacity))
        }
    }
}

struct GameCostToken: View {
    let title: String
    let value: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .foregroundStyle(.secondary)

            Text(value)
                .foregroundStyle(tint)
        }
        .font(.caption.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: GameTheme.compactRadius, style: .continuous))
    }
}

struct GameEmptyGuidance: View {
    let title: String
    let detail: String
    let systemImage: String
    var tint: Color = .blue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: GameTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GameTheme.cardRadius, style: .continuous)
                .stroke(tint.opacity(0.16))
        }
    }
}
