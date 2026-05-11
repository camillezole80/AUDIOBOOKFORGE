import SwiftUI
import UniformTypeIdentifiers

/// Étape 3 : Configuration de la voix
struct VoiceStepView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel
    @State private var showAudioPicker = false
    @State private var previewReady = false
    @State private var showAudioSettings = false

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
                    Text("Importez un sample vocal de référence (10-30 secondes)")
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
                    .help("Configurer la génération audio (Local / Fish.Audio API)")
                    
                    Text("Génération distante")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("par API")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Import du sample vocal
            if let project = pipelineVM.project {
                VStack(alignment: .leading, spacing: 16) {
                    // Fichier audio
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

                    // Transcription
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
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Preview généré")
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Bouton pour passer à l'étape suivante
                        Button(action: {
                            pipelineVM.currentStep = .generation
                        }) {
                            HStack {
                                Text("Passer à la génération")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: 250)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!project.voiceConfig.hasValidReference)
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
            if let project = pipelineVM.project {
                AudioSettingsView(voiceConfig: Binding(
                    get: { project.voiceConfig },
                    set: { pipelineVM.updateVoiceConfig($0) }
                ))
            }
        }
    }
}
