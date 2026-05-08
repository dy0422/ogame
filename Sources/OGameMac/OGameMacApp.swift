import SwiftUI

@main
@MainActor
struct OGameMacApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("保存") {
                    model.save()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!model.canSave)
            }

            CommandMenu("模拟") {
                Button("推进 1 分钟") {
                    model.advanceOneMinute()
                }
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(!model.canSave)

                Button("新游戏") {
                    model.startNewGame()
                }
            }
        }
    }
}
