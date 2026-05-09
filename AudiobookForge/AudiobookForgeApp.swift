import SwiftUI

@main
struct AudiobookForgeApp: App {
    @StateObject private var projectListVM = ProjectListViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectListVM)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nouveau projet...") {
                    projectListVM.showImportSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
