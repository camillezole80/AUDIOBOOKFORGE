import SwiftUI
import UniformTypeIdentifiers

struct QwenVoiceCloneView: View {
    @Binding var voiceConfig: VoiceConfig
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var sourceAudioPath = ""
    @State private var transcription = ""
    @State private var showAudioPicker = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cloner une voix Qwen")
                        .font(.title2.bold())
                    Text("Qwen Base reproduit le timbre à partir d'un court sample et de sa transcription exacte.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Fermer") { dismiss() }
            }

            Form {
                Section("Identité") {
                    TextField("Nom de la voix", text: $name)
                }

                Section("Sample vocal") {
                    HStack {
                        Text(sourceAudioPath.isEmpty
                             ? "Aucun fichier sélectionné"
                             : URL(fileURLWithPath: sourceAudioPath).lastPathComponent)
                            .lineLimit(1)
                        Spacer()
                        Button("Parcourir…") { showAudioPicker = true }
                    }
                    Text("Utilisez idéalement 5 à 15 secondes, une seule personne, sans musique ni réverbération.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Transcription exacte") {
                    TextEditor(text: $transcription)
                        .frame(minHeight: 100)
                    Text("Respectez exactement les mots, hésitations et ponctuation entendus dans le sample.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(statusIsError ? .red : .green)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Enregistrer et sélectionner") {
                    saveAndSelect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 650, height: 520)
        .onAppear {
            name = voiceConfig.qwenVoiceCloneName ?? "Ma voix clonée"
            sourceAudioPath = voiceConfig.resolvedQwenVoiceMode == .voiceClone
                ? voiceConfig.referenceAudioPath
                : ""
            transcription = voiceConfig.resolvedQwenVoiceMode == .voiceClone
                ? voiceConfig.referenceTranscription
                : ""
        }
        .fileImporter(
            isPresented: $showAudioPicker,
            allowedContentTypes: [.audio, .wav, .mp3],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                sourceAudioPath = url.path
            }
        }
    }

    private func saveAndSelect() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            showError("Donnez un nom à la voix.")
            return
        }
        guard FileManager.default.fileExists(atPath: sourceAudioPath) else {
            showError("Sélectionnez un fichier audio valide.")
            return
        }
        guard !cleanText.isEmpty else {
            showError("Saisissez la transcription exacte du sample.")
            return
        }

        do {
            let directory =
                "\(PathResolver.externalVolumeRoot)/LocalData/QwenVoiceClones"
            try FileManager.default.createDirectory(
                atPath: directory,
                withIntermediateDirectories: true
            )
            let source = URL(fileURLWithPath: sourceAudioPath)
            let ext = source.pathExtension.isEmpty ? "wav" : source.pathExtension
            let destination =
                "\(directory)/\(UUID().uuidString).\(ext)"
            try FileManager.default.copyItem(atPath: sourceAudioPath, toPath: destination)

            voiceConfig.preferredProvider = .ttsAudiobookTool
            voiceConfig.ttsModel = .qwen3
            voiceConfig.qwenVoiceMode = .voiceClone
            voiceConfig.qwenVoiceCloneName = cleanName
            voiceConfig.qwenModelPath = VoiceConfig.defaultQwenVoiceCloneModelPath
            voiceConfig.referenceAudioPath = destination
            voiceConfig.referenceTranscription = cleanText
            voiceConfig.qwenLanguage = voiceConfig.resolvedQwenLanguage
            voiceConfig.qwenVoiceDesignProfileId = nil
            voiceConfig.qwenVoiceDesignName = nil
            voiceConfig.qwenVoiceDesignDescription = nil
            statusIsError = false
            statusMessage = "Voix clonée sélectionnée dans ABF."
            dismiss()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        statusIsError = true
        statusMessage = message
    }
}
