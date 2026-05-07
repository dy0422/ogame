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
            }

            CommandMenu("Simulation") {
                Button("Advance 1 Minute") {
                    model.advanceOneMinute()
                }
                .keyboardShortcut("t", modifiers: [.command])
            }
        }
    }
}
