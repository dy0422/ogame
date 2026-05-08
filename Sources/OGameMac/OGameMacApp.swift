import SwiftUI

@main
@MainActor
struct OGameMacApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onChange(of: scenePhase) { phase in
                    guard phase != .active else {
                        return
                    }

                    model.saveForLifecycleChange()
                }
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
                Button(model.simulationControlTitle) {
                    model.toggleSimulationPaused()
                }
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(!model.canSave)

                Button("新游戏") {
                    model.startNewGame()
                }
            }

            CommandMenu("导航") {
                Button("总览") {
                    model.selectedDestination = .dashboard
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("舰队") {
                    model.selectedDestination = .fleets
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("星图") {
                    model.selectedDestination = .starMap
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("设置") {
                    model.selectedDestination = .settings
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}
