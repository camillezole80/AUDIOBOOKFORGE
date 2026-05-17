import SwiftUI
import AVFoundation

/// Étape 4 : Génération audio
struct GenerationStepView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playingChapterIndex: Int?

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
                VStack(spacing: 12) {
                    if !pipelineVM.isProcessing {
                        HStack(spacing: 16) {
                            // Bouton pour générer tous les chapitres
                            Button(action: {
                                Task { await pipelineVM.generateAudio() }
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Générer tous les chapitres")
                                }
                                .frame(maxWidth: 250)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!project.voiceConfig.hasValidReference)
                        }
                        
                        // Info sur le provider audio
                        if project.voiceConfig.preferredProvider == .fishAudio {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("Génération via Fish.Audio API")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.green)
                                Text("Génération locale via MLX")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
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
    @EnvironmentObject private var pipelineVM: PipelineViewModel
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false

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
            
            // Bouton pour écouter le chapitre généré
            if chapter.status == .audioReady, let audioPath = chapter.audioFilePath {
                Button(action: { playChapter(audioPath: audioPath) }) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "speaker.wave.2.circle")
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)
                .help(isPlaying ? "Arrêter la lecture" : "Écouter ce chapitre")
            }
            
            // Bouton pour générer ce chapitre individuellement
            if chapter.status == .tagged && chapter.audioFilePath == nil {
                Button(action: {
                    Task {
                        await pipelineVM.generateSingleChapter(at: index)
                    }
                }) {
                    Image(systemName: "play.circle")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
                .help("Générer ce chapitre")
                .disabled(pipelineVM.isProcessing)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(4)
    }
    
    private func playChapter(audioPath: String) {
        let url = URL(fileURLWithPath: audioPath)
        
        guard FileManager.default.fileExists(atPath: audioPath) else {
            print("❌ Audio file not found: \(audioPath)")
            return
        }
        
        if isPlaying {
            // Arrêter la lecture
            audioPlayer?.stop()
            audioPlayer = nil
            isPlaying = false
        } else {
            // Démarrer la lecture
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                isPlaying = true
                
                // Arrêter automatiquement à la fin
                DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                    isPlaying = false
                }
            } catch {
                print("❌ Error playing chapter: \(error.localizedDescription)")
            }
        }
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
