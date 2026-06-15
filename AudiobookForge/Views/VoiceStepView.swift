import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// Étape 3 : Configuration de la voix
struct VoiceStepView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel
    @State private var showAudioPicker = false
    @State private var previewReady = false
    @State private var showAudioSettings = false
    @State private var showVoiceDesignStudio = false
    @State private var showQwenVoiceClone = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingPreview = false
    @StateObject private var voiceDesignLibrary = VoiceDesignLibrary.shared

    var body: some View {
        VStack(spacing: 24) {
            // En-tête
            HStack(alignment: .top) {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                    Text("Configuration de la voix")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(pipelineVM.project?.voiceConfig.ttsModel == .qwen3
                         ? "Sélectionnez une voix Qwen intégrée ou VoiceDesign"
                         : "Importez un sample vocal de référence (10-30 secondes)")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Bouton de configuration audio
                VStack(spacing: 4) {
                    Button(action: { showAudioSettings = true }) {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.borderless)
                    .help("Configurer la génération audio (TTS Audiobook Tool / Fish.Audio API)")
                    
                    Text("Réglages audio")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Import du sample vocal
            if let project = pipelineVM.project {
                VStack(alignment: .leading, spacing: 16) {
                    TaggingModeSelector()

                    if project.voiceConfig.ttsModel == .qwen3 {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Voix Qwen active", systemImage: "waveform.badge.plus")
                                .font(.headline)

                            Text(qwenVoiceDescription(project.voiceConfig))
                                .font(.body)
                                .fontWeight(.medium)

                            Text(qwenVoiceModeDescription(project.voiceConfig))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Button("Choisir une voix Qwen") {
                                    showAudioSettings = true
                                }

                                Button("Créer une voix Qwen") {
                                    showVoiceDesignStudio = true
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Cloner une voix Qwen") {
                                    showQwenVoiceClone = true
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sample de référence")
                                .font(.headline)

                            HStack {
                                if !project.voiceConfig.referenceAudioPath.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(URL(fileURLWithPath: project.voiceConfig.referenceAudioPath).lastPathComponent)
                                        .lineLimit(1)
                                } else {
                                    Image(systemName: "music.note")
                                        .foregroundColor(.secondary)
                                    Text("Aucun fichier sélectionné")
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button("Parcourir...") {
                                    showAudioPicker = true
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transcription exacte du sample")
                                .font(.headline)

                            TextEditor(text: Binding(
                                get: { project.voiceConfig.referenceTranscription },
                                set: { pipelineVM.setVoiceReference(
                                    audioPath: project.voiceConfig.referenceAudioPath,
                                    transcription: $0
                                )}
                            ))
                            .font(.body)
                            .frame(height: 80)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                        }
                    }

                    // Paramètres
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Paramètres de génération")
                            .font(.headline)

                        VStack(spacing: 16) {
                            HStack {
                                Text("Vitesse : \(String(format: "%.1f", project.voiceConfig.speedScale))×")
                                Slider(value: Binding(
                                    get: { project.voiceConfig.speedScale },
                                    set: { newValue in
                                        pipelineVM.updateVoiceSpeed(newValue)
                                    }
                                ), in: 0.8...1.2, step: 0.05)
                            }

                            HStack {
                                Text("Temperature : \(String(format: "%.1f", project.voiceConfig.temperature))")
                                Slider(value: Binding(
                                    get: { project.voiceConfig.temperature },
                                    set: { newValue in
                                        pipelineVM.updateVoiceTemperature(newValue)
                                    }
                                ), in: 0.6...1.0, step: 0.05)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Preview et Navigation
                    VStack(spacing: 12) {
                        Button(action: {
                            Task { await pipelineVM.generateVoicePreview() }
                        }) {
                            HStack {
                                Image(systemName: "play.circle")
                                Text("Générer un preview")
                            }
                            .frame(maxWidth: 200)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!project.voiceConfig.hasValidReference || pipelineVM.isProcessing)

                        if pipelineVM.progressText == "Preview prêt !" {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Preview généré")
                                }
                                
                                // Lecteur audio pour le preview
                                Button(action: { playPreview(project: project) }) {
                                    HStack {
                                        Image(systemName: isPlayingPreview ? "stop.circle.fill" : "play.circle.fill")
                                        Text(isPlayingPreview ? "Arrêter" : "Écouter le preview")
                                    }
                                    .frame(maxWidth: 200)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        let usesTags = project.aiConfig.taggingMode.usesAI
                        Button(action: {
                            pipelineVM.currentStep = usesTags ? .tags : .generation
                        }) {
                            HStack {
                                Text(usesTags ? "Passer aux balises" : "Passer à la génération")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: 280)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!project.voiceConfig.hasValidReference)
                        .help(project.voiceConfig.missingReferenceHint ?? "")

                        // Raccourci : sauter à la génération même quand les balises sont disponibles
                        if usesTags && project.voiceConfig.hasValidReference {
                            Button(action: { pipelineVM.currentStep = .generation }) {
                                Text("Sauter le balisage et générer directement")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(maxWidth: 500)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showAudioPicker,
            allowedContentTypes: [.audio, .wav, UTType(filenameExtension: "m4a") ?? .audio, .mp3],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pipelineVM.setVoiceReference(
                        audioPath: url.path,
                        transcription: pipelineVM.project?.voiceConfig.referenceTranscription ?? ""
                    )
                }
            case .failure:
                break
            }
        }
        .sheet(isPresented: $showAudioSettings) {
            // IMPORTANT : on lit pipelineVM.project AU MOMENT du get, jamais une copie
            // capturée. Sinon, chaque mutation via $voiceConfig.X (TTS options, etc.)
            // partirait d'un snapshot périmé et écraserait les changements précédents.
            AudioSettingsView(
                voiceConfig: Binding(
                    get: { pipelineVM.project?.voiceConfig ?? VoiceConfig() },
                    set: { pipelineVM.updateVoiceConfig($0) }
                ),
                defaultLanguage: pipelineVM.project?.metadata.language ?? "fr"
            )
        }
        .sheet(isPresented: $showVoiceDesignStudio) {
            VoiceDesignStudioView(
                voiceConfig: Binding(
                    get: { pipelineVM.project?.voiceConfig ?? VoiceConfig() },
                    set: { pipelineVM.updateVoiceConfig($0) }
                ),
                library: voiceDesignLibrary
            )
        }
        .sheet(isPresented: $showQwenVoiceClone) {
            QwenVoiceCloneView(
                voiceConfig: Binding(
                    get: { pipelineVM.project?.voiceConfig ?? VoiceConfig() },
                    set: { pipelineVM.updateVoiceConfig($0) }
                )
            )
        }
    }
    
    // MARK: - Audio Player

    private func qwenVoiceDescription(_ config: VoiceConfig) -> String {
        switch config.resolvedQwenVoiceMode {
        case .voiceDesign:
            return config.qwenVoiceDesignName ?? "Profil VoiceDesign"
        case .voiceClone:
            return config.qwenVoiceCloneName ?? "Voix Qwen clonée"
        case .customVoice:
            return "\(config.resolvedQwenSpeakerId) (CustomVoice)"
        }
    }

    private func qwenVoiceModeDescription(_ config: VoiceConfig) -> String {
        switch config.resolvedQwenVoiceMode {
        case .voiceDesign:
            return "VoiceDesign conçoit une voix depuis sa description. Aucun sample audio n'est utilisé."
        case .voiceClone:
            return "Qwen Base reproduit le timbre du sample vocal et utilise sa transcription exacte."
        case .customVoice:
            return "CustomVoice utilise une voix intégrée au checkpoint. Aucun sample audio n'est utilisé."
        }
    }
    
    private func playPreview(project: Project) {
        let previewPath = "\(project.projectDirectory)/voice_preview.wav"
        let url = URL(fileURLWithPath: previewPath)
        
        guard FileManager.default.fileExists(atPath: previewPath) else {
            print("❌ Preview file not found: \(previewPath)")
            return
        }
        
        if isPlayingPreview {
            // Arrêter la lecture
            audioPlayer?.stop()
            audioPlayer = nil
            isPlayingPreview = false
        } else {
            // Démarrer la lecture
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                isPlayingPreview = true
                
                // Arrêter automatiquement à la fin
                DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                    isPlayingPreview = false
                }
            } catch {
                print("❌ Error playing preview: \(error.localizedDescription)")
            }
        }
    }
}
