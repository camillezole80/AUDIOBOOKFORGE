import SwiftUI
import AppKit

@main
struct AudiobookForgeApp: App {
    @StateObject private var projectListVM = ProjectListViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectListVM)
                .preferredColorScheme(.dark)
        }
        .commands {
            // Menu Fichier
            CommandGroup(replacing: .newItem) {
                Button("Nouveau projet...") {
                    projectListVM.showImportSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            // Menu standard macOS
            CommandGroup(after: .appInfo) {
                Divider()
            }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Log de la version au démarrage
        AppVersion.logVersion()
        
        // Activer l'app au premier plan
        NSApp.activate(ignoringOtherApps: true)
        
        // S'assurer que l'app reste au premier plan
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Fermer le terminal parent si lancé via script
        killParentTerminal()
    }
    
    private func killParentTerminal() {
        // Récupérer le PID du processus parent
        let ppid = getppid()
        
        // Vérifier si le parent est un shell (bash, zsh, sh)
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(ppid)", "-o", "comm="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // Si le parent est un shell, le tuer
                if output.contains("bash") || output.contains("zsh") || output.contains("sh") {
                    kill(ppid, SIGTERM)
                }
            }
        } catch {
            // Ignorer les erreurs
        }
    }
}
