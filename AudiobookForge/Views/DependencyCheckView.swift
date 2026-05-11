import SwiftUI

/// Vue de vérification des dépendances système
struct DependencyCheckView: View {
    @EnvironmentObject private var projectListVM: ProjectListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var status: ProjectManager.DependencyStatus?
    @State private var isChecking = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "wrench.adjustable")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Vérification des dépendances")
                .font(.title2)
                .fontWeight(.semibold)

            if isChecking {
                ProgressView("Vérification en cours...")
            } else if let status = status {
                VStack(spacing: 16) {
                    DependencyRow(
                        name: "ffmpeg",
                        description: "Encodage audio",
                        isInstalled: status.ffmpegInstalled,
                        installCommand: "brew install ffmpeg"
                    )

                    DependencyRow(
                        name: "Ollama",
                        description: "Serveur LLM local",
                        isInstalled: status.ollamaRunning,
                        installCommand: "brew install ollama && ollama serve"
                    )

                    DependencyRow(
                        name: "Qwen 2.5 (7B ou plus)",
                        description: "Modèle LLM pour balises",
                        isInstalled: status.qwenModelAvailable,
                        installCommand: "ollama pull qwen2.5:7b"
                    )

                    DependencyRow(
                        name: "Fish S2 Pro MLX",
                        description: "Modèle TTS local",
                        isInstalled: status.fishModelAvailable,
                        installCommand: "Téléchargez le modèle depuis Hugging Face"
                    )
                }

                if status.allMet {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Toutes les dépendances sont satisfaites")
                    }
                    .font(.headline)
                }
            }

            HStack(spacing: 16) {
                Button("Vérifier") {
                    Task {
                        isChecking = true
                        status = await ProjectManager.shared.checkDependencies()
                        isChecking = false
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Ouvrir les logs") {
                    let logPath = Logger.shared.logFileURL.path
                    NSWorkspace.shared.selectFile(logPath, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.bordered)

                Button("Fermer") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
        }
        .padding(30)
        .frame(width: 450)
        .onAppear {
            Task {
                isChecking = true
                status = await ProjectManager.shared.checkDependencies()
                isChecking = false
            }
        }
    }
}

struct DependencyRow: View {
    let name: String
    let description: String
    let isInstalled: Bool
    let installCommand: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isInstalled ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isInstalled {
                Button("Copier") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(installCommand, forType: .string)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal)
    }
}
