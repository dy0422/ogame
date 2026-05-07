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
                Button("Save") {
                    model.save()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!model.canSave)
            }

            CommandMenu("Simulation") {
                Button("Advance 1 Minute") {
                    model.advanceOneMinute()
                }
                .keyboardShortcut("t", modifiers: [.command])
                .disabled(!model.canSave)

                Button("New Game") {
                    model.startNewGame()
                }
            }
        }
    }
}
