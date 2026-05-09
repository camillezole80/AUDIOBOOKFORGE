import SwiftUI

/// Étape 1 : Import et extraction du texte
struct ImportStepView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel

    var body: some View {
        VStack(spacing: 24) {
            // En-tête
            VStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text("Import et extraction")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let project = pipelineVM.project {
                    Text(project.name)
                        .foregroundColor(.secondary)
                }
            }

            // Métadonnées du projet
            if let project = pipelineVM.project {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Métadonnées")
                        .font(.headline)

                    HStack {
                        Text("Fichier source :")
                            .foregroundColor(.secondary)
                        Text(project.sourceFileType.rawValue)
                            .fontWeight(.medium)
                    }

                    if !project.metadata.title.isEmpty {
                        HStack {
                            Text("Titre :")
                                .foregroundColor(.secondary)
                            Text(project.metadata.title)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Auteur :")
                                .foregroundColor(.secondary)
                            Text(project.metadata.author)
                                .fontWeight(.medium)
                        }
                    }

                    HStack {
                        Text("Chapitres :")
                            .foregroundColor(.secondary)
                        Text("\(project.chapters.count)")
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            // Bouton d'extraction
            if let project = pipelineVM.project {
                if project.status == .imported || project.status == .error {
                    Button(action: {
                        Task { await pipelineVM.extractText() }
                    }) {
                        HStack {
                            if pipelineVM.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(pipelineVM.isProcessing ? "Extraction en cours..." : "Extraire le texte")
                        }
                        .frame(maxWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pipelineVM.isProcessing)
                } else if project.status == .textExtracted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Texte extrait avec succès")
                    }
                    .font(.headline)
                }
            }
        }
        .padding()
    }
}
