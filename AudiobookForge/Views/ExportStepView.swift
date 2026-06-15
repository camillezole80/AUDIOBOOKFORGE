import SwiftUI

/// Étape 5 : Export
struct ExportStepView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel
    @State private var selectedFormat: ExportFormat = .aac
    @State private var selectedStructure: ExportStructure = .perChapter

    var body: some View {
        VStack(spacing: 24) {
            // En-tête
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                Text("Export")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choisissez le format et la structure de sortie")
                    .foregroundColor(.secondary)
            }

            if let project = pipelineVM.project {
                // Bandeau de synthèse de l'état des chapitres
                let readyCount = project.chapters.filter {
                    guard let p = $0.audioFilePath else { return false }
                    return FileManager.default.fileExists(atPath: p)
                }.count
                let totalCount = project.chapters.count
                let allReady = readyCount == totalCount && totalCount > 0

                HStack(spacing: 10) {
                    Image(systemName: allReady ? "checkmark.seal.fill"
                                       : (readyCount > 0 ? "exclamationmark.triangle.fill" : "xmark.octagon.fill"))
                        .foregroundColor(allReady ? .green : (readyCount > 0 ? .orange : .red))
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(allReady
                             ? "Tous les chapitres sont prêts"
                             : (readyCount > 0 ? "Export partiel possible" : "Aucun chapitre prêt à exporter"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("\(readyCount)/\(totalCount) chapitre(s) audio disponible(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background((allReady ? Color.green : (readyCount > 0 ? Color.orange : Color.red)).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((allReady ? Color.green : (readyCount > 0 ? Color.orange : Color.red)).opacity(0.4), lineWidth: 1)
                )
                .cornerRadius(8)
                .frame(maxWidth: 500)

                VStack(spacing: 20) {
                    // Format
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Format audio")
                            .font(.headline)

                        Picker("Format", selection: $selectedFormat) {
                            ForEach(ExportFormat.allCases, id: \.self) { format in
                                HStack {
                                    Image(systemName: formatIcon(format))
                                    Text(format.rawValue)
                                }
                                .tag(format)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Structure
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Structure de sortie")
                            .font(.headline)

                        Picker("Structure", selection: $selectedStructure) {
                            ForEach(ExportStructure.allCases, id: \.self) { structure in
                                HStack {
                                    Image(systemName: structure == .perChapter ? "doc.on.doc" : "book")
                                    Text(structure.rawValue)
                                }
                                .tag(structure)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Métadonnées
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Métadonnées")
                            .font(.headline)

                        HStack {
                            Text("Titre :")
                                .foregroundColor(.secondary)
                            Text(project.metadata.title.isEmpty ? "Non défini" : project.metadata.title)
                        }

                        HStack {
                            Text("Auteur :")
                                .foregroundColor(.secondary)
                            Text(project.metadata.author.isEmpty ? "Non défini" : project.metadata.author)
                        }

                        if project.coverImagePath != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Couverture incluse")
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Bouton d'export
                    Button(action: {
                        Task {
                            await pipelineVM.exportAudio(
                                format: selectedFormat,
                                structure: selectedStructure
                            )
                        }
                    }) {
                        HStack {
                            if pipelineVM.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "square.and.arrow.up")
                            Text(pipelineVM.isProcessing
                                 ? "Export en cours..."
                                 : (readyCount > 0 ? "Exporter \(readyCount) chapitre(s)" : "Exporter"))
                        }
                        .frame(maxWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pipelineVM.isProcessing || readyCount == 0)
                    .help(readyCount == 0
                          ? "Générez d'abord au moins un chapitre dans l'onglet Génération"
                          : "Exporte les \(readyCount) chapitre(s) déjà générés")

                    // Progression
                    if pipelineVM.isProcessing {
                        ProgressView(value: pipelineVM.progress) {
                            Text(pipelineVM.progressText)
                                .font(.caption)
                        }
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 400)
                    }

                    // Message de succès
                    if project.status == .exported {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Projet exporté avec succès !")
                        }
                        .font(.headline)

                        Button("Ouvrir le dossier d'export") {
                            NSWorkspace.shared.open(
                                URL(fileURLWithPath: "\(project.projectDirectory)/export")
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: 500)
            }
        }
        .padding()
    }

    private func formatIcon(_ format: ExportFormat) -> String {
        switch format {
        case .wav: return "waveform"
        case .aac: return "music.note"
        case .mp3: return "music.note.list"
        }
    }
}
