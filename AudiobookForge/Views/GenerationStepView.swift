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
                Text("Génération chapitre par chapitre")
                    .foregroundColor(.secondary)
            }

            if let project = pipelineVM.project {
                // Bandeau de synthèse (vert/orange/gris) selon l'état global
                ChapterSummaryBanner(chapters: project.chapters, isProcessing: pipelineVM.isProcessing)

                // Bouton principal toujours visible (désactivé pendant la génération)
                // + Pause/Annuler accessibles en parallèle.
                GenerationControlBar(project: project)

                // Liste des chapitres avec leur statut
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progression par chapitre")
                            .font(.headline)
                        Spacer()
                        // Bouton "Réessayer les chapitres en erreur" si pertinent
                        let errorCount = project.chapters.filter { $0.status == .error }.count
                        if errorCount > 0 && !pipelineVM.isProcessing {
                            Button(action: {
                                Task { await pipelineVM.generateAudio() }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Réessayer (\(errorCount))")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Relancer la génération uniquement sur les chapitres en erreur")
                        }
                    }

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(project.chapters.enumerated()), id: \.offset) { index, chapter in
                                ChapterProgressRow(index: index, chapter: chapter)
                            }
                        }
                        // Marge à droite pour ne pas que les boutons d'action des lignes
                        // (lecture, régénérer, réinitialiser) tombent SOUS la barre de scroll
                        // macOS quand elle est visible.
                        .padding(.trailing, 14)
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // (Barre de progression maintenant intégrée dans GenerationControlBar)

                // Info sur le provider audio
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(project.voiceConfig.preferredProvider == .fishAudio ? .blue : .green)
                    Text(project.voiceConfig.preferredProvider == .fishAudio
                         ? "Génération via Fish.Audio API"
                         : "Génération locale via TTS Audiobook Tool")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Message si pas de voix configurée (le bouton est de toute façon désactivé)
                if !project.voiceConfig.hasValidReference {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(project.voiceConfig.missingReferenceHint
                             ?? "Configurez d'abord un moteur de voix dans l'étape Voix")
                            .foregroundColor(.orange)
                    }
                    .font(.callout)
                }
            }
        }
        .padding()
    }
}

// MARK: - Barre de contrôle principale

/// Toujours affichée : bouton "Générer tous les chapitres" en évidence + actions
/// secondaires (Pause / Annuler) à droite. Pendant la génération, le bouton principal
/// est désactivé mais reste visible (l'utilisateur sait toujours où regarder).
struct GenerationControlBar: View {
    let project: Project
    @EnvironmentObject private var pipelineVM: PipelineViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Bouton principal
                Button(action: {
                    Task { await pipelineVM.generateAudio() }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Générer tous les chapitres")
                    }
                    .frame(maxWidth: 250)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(pipelineVM.isProcessing || !project.voiceConfig.hasValidReference)
                .help(!project.voiceConfig.hasValidReference
                      ? (project.voiceConfig.missingReferenceHint ?? "Configuration audio incomplète")
                      : "Génère ou complète tous les chapitres (les chapitres déjà OK sont sautés)")

                // Pause / Reprendre — visible uniquement pendant la génération
                if pipelineVM.isProcessing {
                    Button(action: { pipelineVM.togglePause() }) {
                        HStack {
                            Image(systemName: pipelineVM.isPaused ? "play.fill" : "pause.fill")
                            Text(pipelineVM.isPaused ? "Reprendre" : "Pause")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help("Met en pause entre deux chapitres")

                    // Annuler — secours si l'UI semble bloquée
                    Button(action: { pipelineVM.cancelCurrentOperation() }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Annuler")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help("Libère l'interface en cas de blocage (n'annule pas le sous-processus)")
                }
            }

            // Barre de progression pendant la génération
            if pipelineVM.isProcessing {
                VStack(spacing: 4) {
                    ProgressView(value: pipelineVM.progress) {
                        Text(pipelineVM.progressText)
                            .font(.caption)
                    }
                    .progressViewStyle(.linear)
                    Text("\(Int(pipelineVM.progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: 500)
            }
        }
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
            
            // Bouton pour générer/régénérer ce chapitre individuellement
            if chapter.status != .audioReady {
                Button(action: {
                    Task {
                        await pipelineVM.generateSingleChapter(at: index)
                    }
                }) {
                    Image(systemName: chapter.status == .error ? "arrow.clockwise.circle" : "play.circle")
                        .foregroundColor(chapter.status == .error ? .red : .accentColor)
                }
                .buttonStyle(.borderless)
                .help(chapter.status == .error ? "Relancer la génération" : "Générer ce chapitre")
                .disabled(pipelineVM.isProcessing)
            }
            
            // Bouton pour réinitialiser ce chapitre
            if chapter.status == .audioReady {
                Button(action: {
                    pipelineVM.resetChapter(at: index)
                }) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.borderless)
                .help("Réinitialiser ce chapitre")
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

// MARK: - Bandeau de synthèse

/// Bandeau au-dessus de la liste : vert si tout est OK, orange si erreurs partielles,
/// gris sinon. Évite que l'utilisateur reste sur l'impression "rouge = échec" alors
/// que les autres chapitres ont marché.
struct ChapterSummaryBanner: View {
    let chapters: [Chapter]
    let isProcessing: Bool

    var body: some View {
        let total = chapters.count
        let done = chapters.filter { $0.status == .audioReady }.count
        let errors = chapters.filter { $0.status == .error }.count

        if isProcessing {
            banner(
                color: .blue,
                icon: "gearshape.2.fill",
                title: "Génération en cours",
                detail: "\(done)/\(total) chapitres terminés"
            )
        } else if total > 0 && done == total {
            banner(
                color: .green,
                icon: "checkmark.seal.fill",
                title: "Tous les chapitres sont générés",
                detail: "\(done)/\(total) — prêt pour l'export"
            )
        } else if errors > 0 {
            banner(
                color: .orange,
                icon: "exclamationmark.triangle.fill",
                title: "Génération partielle",
                detail: "\(done)/\(total) OK, \(errors) en erreur — cliquez sur Réessayer"
            )
        } else if done > 0 {
            banner(
                color: .gray,
                icon: "ellipsis.circle.fill",
                title: "Génération incomplète",
                detail: "\(done)/\(total) chapitres terminés"
            )
        }
    }

    private func banner(color: Color, icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}
