import SwiftUI

struct GamePage<Content: View>: View {
    let title: String?
    @ObservedObject var model: AppModel
    var showsActivityPanel = true
    var maxContentWidth: CGFloat? = nil
    let content: Content

    init(
        title: String?,
        model: AppModel,
        showsActivityPanel: Bool = true,
        maxContentWidth: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.model = model
        self.showsActivityPanel = showsActivityPanel
        self.maxContentWidth = maxContentWidth
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let title {
                        PageTitle(title)
                    }

                    content
                }
                .padding(24)
                .frame(maxWidth: maxContentWidth ?? .infinity, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showsActivityPanel {
                Divider()
                ActivityPanel(model: model)
            }
        }
    }
}

private struct PageTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.largeTitle.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
