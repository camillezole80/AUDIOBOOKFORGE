import SwiftUI

/// Étape 4 : Génération audio
struct GenerationStepView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel

    var body: some View {
        VStack(spacing: 24) {
            // En-tête
            VStack(spacing: 8) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                Text("Génération audio")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Génération chapitre par chapitre via Fish S2 Pro MLX")
                    .foregroundColor(.secondary)
            }

            if let project = pipelineVM.project {
                // Liste des chapitres avec leur statut
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progression par chapitre")
                        .font(.headline)

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(project.chapters.enumerated()), id: \.offset) { index, chapter in
                                ChapterProgressRow(index: index, chapter: chapter)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Barre de progression globale
                if pipelineVM.isProcessing {
                    VStack(spacing: 8) {
                        ProgressView(value: pipelineVM.progress) {
                            Text(pipelineVM.progressText)
                                .font(.caption)
                        }
                        .progressViewStyle(.linear)

                        Text("\(Int(pipelineVM.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: 400)
                }

                // Boutons de contrôle
                HStack(spacing: 16) {
                    if !pipelineVM.isProcessing {
                        Button(action: {
                            Task { await pipelineVM.generateAudio() }
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Générer l'audio")
                            }
                            .frame(maxWidth: 200)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!project.voiceConfig.hasValidReference)
                    } else {
                        Button(action: { pipelineVM.togglePause() }) {
                            HStack {
                                Image(systemName: pipelineVM.isPaused ? "play.fill" : "pause.fill")
                                Text(pipelineVM.isPaused ? "Reprendre" : "Pause")
                            }
                            .frame(maxWidth: 150)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Message si pas de voix configurée
                if !project.voiceConfig.hasValidReference {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Configurez d'abord un sample vocal dans l'étape Voix")
                            .foregroundColor(.orange)
                    }
                    .font(.callout)
                }
            }
        }
        .padding()
    }
}

// MARK: - Ligne de progression d'un chapitre

struct ChapterProgressRow: View {
    let index: Int
    let chapter: Chapter

    var body: some View {
        HStack {
            Text("\(String(format: "%02d", index + 1))")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(chapter.title)
                .font(.callout)
                .lineLimit(1)

            Spacer()

            StatusBadge(status: chapter.status)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(4)
    }
}

struct StatusBadge: View {
    let status: ChapterStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status.rawValue)
                .font(.caption)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .cornerRadius(4)
    }

    private var color: Color {
        switch status {
        case .pending: return .gray
        case .textReady: return .blue
        case .tagged: return .orange
        case .audioReady: return .green
        case .error: return .red
        }
    }
}
