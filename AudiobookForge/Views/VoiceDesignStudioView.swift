import SwiftUI
import AVFoundation

struct VoiceDesignStudioView: View {
    @Binding var voiceConfig: VoiceConfig
    @ObservedObject var library: VoiceDesignLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var selectedId: UUID?
    @State private var name = ""
    @State private var voiceDescription = ""
    @State private var language = "fr"
    @State private var previewText =
        "La porte céda dans un claquement sec. Élise retint son souffle, puis s'élança dans l'escalier tandis que les pas se rapprochaient."
    @State private var isGenerating = false
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var selectedGender: VoiceDesignGender = .masculine
    @State private var selectedAge: VoiceDesignAge = .adult
    @State private var selectedQualities: Set<VoiceDesignQuality> = [.warm, .natural]
    @State private var selectedMood: VoiceDesignMood = .neutral
    @State private var selectedReadingStyle: VoiceDesignReadingStyle = .literaryNarration
    @State private var speedScale = 1.0
    @State private var emotionTest: QwenEmotionTest = .none

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Atelier VoiceDesign")
                        .font(.title2.bold())
                    Text("Créez des voix françaises Qwen utilisables dans tous les projets ABF.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Fermer") {
                    audioPlayer?.stop()
                    dismiss()
                }
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Mes voix")
                            .font(.headline)
                        Spacer()
                        Button {
                            beginNewProfile()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("Nouvelle voix")
                    }

                    List(selection: $selectedId) {
                        ForEach(library.profiles) { profile in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                Text(profile.language.uppercased())
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .tag(profile.id)
                        }
                    }
                    .onChange(of: selectedId) { _, newValue in
                        loadProfile(id: newValue)
                    }

                    Text("\(library.profiles.count) voix dans \(library.directoryPath)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding()
                .frame(width: 220)

                Divider()

                Form {
                    Section("Identité") {
                        TextField("Nom dans ABF", text: $name)
                        TextField("Langue", text: $language)
                            .frame(maxWidth: 120)
                    }

                    Section("Filtres VoiceDesign") {
                        Picker("Voix", selection: $selectedGender) {
                            ForEach(VoiceDesignGender.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }

                        Picker("Âge", selection: $selectedAge) {
                            ForEach(VoiceDesignAge.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }

                        Picker("Humeur", selection: $selectedMood) {
                            ForEach(VoiceDesignMood.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }

                        Picker("Type de lecture", selection: $selectedReadingStyle) {
                            ForEach(VoiceDesignReadingStyle.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caractéristiques sonores")
                                .font(.subheadline)
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 105), spacing: 6)],
                                alignment: .leading,
                                spacing: 6
                            ) {
                                ForEach(VoiceDesignQuality.allCases) { quality in
                                    Button {
                                        toggleQuality(quality)
                                    } label: {
                                        Label(
                                            quality.label,
                                            systemImage: selectedQualities.contains(quality)
                                                ? "checkmark.circle.fill"
                                                : "circle"
                                        )
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(selectedQualities.contains(quality) ? .accentColor : .secondary)
                                }
                            }
                        }

                        Button {
                            applyVoiceDesignFilters()
                        } label: {
                            Label("Construire le prompt Qwen", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.borderedProminent)

                        HStack {
                            Text("Vitesse de lecture")
                            Slider(value: $speedScale, in: 0.75...2.0, step: 0.05)
                            Text("\(speedScale, specifier: "%.2f")×")
                                .monospacedDigit()
                                .frame(width: 52, alignment: .trailing)
                        }
                        Text(speedScale < 0.98
                             ? "Qwen reçoit une consigne de débit lent, puis la durée est ajustée précisément."
                             : speedScale > 1.02
                                ? "Qwen reçoit une consigne de débit rapide, puis la durée est ajustée précisément."
                                : "Vitesse naturelle.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section("Prompt Qwen VoiceDesign") {
                        TextEditor(text: $voiceDescription)
                            .frame(minHeight: 100)
                        Text("Le prompt est généré en anglais avec des indications de timbre, hauteur, texture, prosodie et style. Il reste entièrement modifiable.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section("Essai") {
                        Picker("Émotion à tester", selection: $emotionTest) {
                            ForEach(QwenEmotionTest.allCases) { emotion in
                                Text(emotion.label).tag(emotion)
                            }
                        }

                        if let instruction = emotionTest.instruction {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Instruction expressive envoyée séparément à Qwen")
                                    .font(.caption.bold())
                                Text(instruction)
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                        }

                        TextEditor(text: $previewText)
                            .frame(minHeight: 90)

                        Text("L'émotion est transmise comme une instruction Qwen, équivalente aux balises [[qwen:…]] du livre. Elle n'est pas écrite dans le texte et ne sera donc pas prononcée.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("« Générer » crée un nouveau WAV. « Écouter » rejoue ensuite ce WAV instantanément, sans recalculer la voix.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Une fois l'exemple satisfaisant, « Utiliser comme voix maître » verrouille son identité pour les livres longs. Le clonage conserve une expressivité naturelle guidée par le texte, mais atténue les changements émotionnels extrêmes.")
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
                .padding()
            }

            Divider()

            HStack {
                if currentProfile != nil {
                    Button("Supprimer", role: .destructive) {
                        deleteCurrentProfile()
                    }
                    .disabled(isGenerating)
                }

                Spacer()

                Button {
                    generatePreview()
                } label: {
                    HStack(spacing: 8) {
                        if isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "waveform.badge.plus")
                        }
                        Text(isGenerating
                             ? "Génération de l'exemple…"
                             : "Générer")
                    }
                    .frame(minWidth: 125)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)

                Button {
                    if isPlaying {
                        stopPreview()
                    } else {
                        playPreview()
                    }
                } label: {
                    Label(
                        isPlaying ? "Arrêter" : "Écouter",
                        systemImage: isPlaying ? "stop.fill" : "play.fill"
                    )
                    .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .tint(isPlaying ? .red : .accentColor)
                .disabled(isGenerating || !hasPlayablePreview)

                Button {
                    usePreviewAsMasterVoice()
                } label: {
                    Label("Utiliser comme voix maître", systemImage: "lock.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating || !hasPlayablePreview)

                Button("Enregistrer et sélectionner") {
                    saveAndSelect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            }
            .padding()
        }
        .frame(width: 920, height: 780)
        .onAppear {
            if let selected = library.profile(id: voiceConfig.qwenVoiceDesignProfileId) {
                selectedId = selected.id
                loadProfile(id: selected.id)
            } else if let first = library.profiles.first {
                selectedId = first.id
                loadProfile(id: first.id)
            } else {
                beginNewProfile()
            }
        }
        .onDisappear { audioPlayer?.stop() }
    }

    private var currentProfile: VoiceDesignProfile? {
        library.profile(id: selectedId)
    }

    private var hasPlayablePreview: Bool {
        guard let path = currentProfile?.previewAudioPath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private func beginNewProfile() {
        stopPreview()
        selectedId = nil
        name = nextAvailableName()
        selectedGender = .masculine
        selectedAge = .adult
        selectedQualities = [.warm, .natural]
        selectedMood = .neutral
        selectedReadingStyle = .literaryNarration
        speedScale = 1.0
        emotionTest = .none
        applyVoiceDesignFilters()
        language = "fr"
        previewText =
            "La porte céda dans un claquement sec. Élise retint son souffle, puis s'élança dans l'escalier tandis que les pas se rapprochaient."
        statusIsError = false
        statusMessage = "Nouveau profil prêt à être personnalisé."
    }

    private func nextAvailableName() -> String {
        let existingNames = Set(library.profiles.map { $0.name.lowercased() })
        var index = 1
        while existingNames.contains("ma voix \(index)") {
            index += 1
        }
        return "Ma voix \(index)"
    }

    private func toggleQuality(_ quality: VoiceDesignQuality) {
        if selectedQualities.contains(quality) {
            selectedQualities.remove(quality)
        } else {
            selectedQualities.insert(quality)
        }
    }

    private func applyVoiceDesignFilters() {
        let qualities = selectedQualities
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.prompt)
            .joined(separator: ", ")
        let texture = qualities.isEmpty ? "natural vocal texture" : qualities
        voiceDescription = """
        A native French \(selectedGender.prompt), \(selectedAge.prompt). \
        The voice has \(texture). \
        \(selectedMood.prompt). \
        \(selectedReadingStyle.prompt). \
        Clear intelligible French diction, natural breathing, realistic human prosody, no synthetic or announcer-like delivery.
        """
    }

    private func loadProfile(id: UUID?) {
        guard let profile = library.profile(id: id) else { return }
        stopPreview()
        name = profile.name
        voiceDescription = profile.voiceDescription
        language = profile.language
        previewText = profile.previewText
        speedScale = profile.speedScale ?? 1.0
        emotionTest = .none
        statusMessage = nil
    }

    @discardableResult
    private func saveDraft() throws -> VoiceDesignProfile {
        let previous = currentProfile
        let profile = VoiceDesignProfile(
            id: previous?.id ?? UUID(),
            name: name,
            voiceDescription: voiceDescription,
            language: language,
            previewText: previewText,
            previewAudioPath: previous?.previewAudioPath,
            speedScale: speedScale,
            createdAt: previous?.createdAt ?? Date()
        )
        let saved = try library.save(profile)
        selectedId = saved.id
        return saved
    }

    private func select(_ profile: VoiceDesignProfile) {
        voiceConfig.preferredProvider = .ttsAudiobookTool
        voiceConfig.ttsModel = .qwen3
        voiceConfig.qwenVoiceMode = .voiceDesign
        voiceConfig.qwenVoiceDesignProfileId = profile.id
        voiceConfig.qwenVoiceDesignName = profile.name
        voiceConfig.qwenVoiceDesignDescription = profile.voiceDescription
        voiceConfig.qwenModelPath = VoiceConfig.defaultQwenVoiceDesignModelPath
        voiceConfig.qwenLanguage = profile.language
        voiceConfig.speedScale = profile.speedScale ?? 1.0
        voiceConfig.enableSttValidation = true
        voiceConfig.maxRetries = max(voiceConfig.maxRetries, 3)
    }

    private func saveAndSelect() {
        do {
            let saved = try saveDraft()
            select(saved)
            statusIsError = false
            statusMessage = "Voix « \(saved.name) » enregistrée et sélectionnée dans ABF."
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }

    private func usePreviewAsMasterVoice() {
        stopPreview()
        do {
            let saved = try saveDraft()
            guard let previewPath = saved.previewAudioPath,
                  FileManager.default.fileExists(atPath: previewPath) else {
                throw MasterVoiceError.missingPreview
            }

            let directory =
                "\(PathResolver.externalVolumeRoot)/LocalData/QwenVoiceClones"
            try FileManager.default.createDirectory(
                atPath: directory,
                withIntermediateDirectories: true
            )
            let destination =
                "\(directory)/master-\(saved.id.uuidString)-\(UUID().uuidString).wav"
            try FileManager.default.copyItem(atPath: previewPath, toPath: destination)

            voiceConfig.preferredProvider = .ttsAudiobookTool
            voiceConfig.ttsModel = .qwen3
            voiceConfig.qwenVoiceMode = .voiceClone
            voiceConfig.qwenVoiceCloneName = "\(saved.name) — maître"
            voiceConfig.qwenModelPath = VoiceConfig.defaultQwenVoiceCloneModelPath
            voiceConfig.referenceAudioPath = destination
            voiceConfig.referenceTranscription = saved.previewText
            voiceConfig.qwenLanguage = saved.language
            voiceConfig.speedScale = saved.speedScale ?? 1.0
            voiceConfig.seed = voiceConfig.resolvedQwenSeed
            voiceConfig.enableSttValidation = true
            voiceConfig.maxRetries = max(voiceConfig.maxRetries, 3)

            statusIsError = false
            statusMessage =
                "Voix maître « \(saved.name) » sélectionnée. Son timbre sera verrouillé pour les livres longs."
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }

    private func generatePreview() {
        stopPreview()
        do {
            let saved = try saveDraft()
            select(saved)
            let outputPath = try library.previewPath(for: saved)
            let previousPreviewPath = saved.previewAudioPath
            isGenerating = true
            statusMessage = "Chargement de Qwen VoiceDesign et génération de l'essai…"
            statusIsError = false

            Task {
                do {
                    try await TTSDaemon.shared.ttsToolGenerate(
                        model: "qwen3",
                        text: saved.previewText,
                        referenceAudio: "",
                        referenceText: "",
                        output: outputPath,
                        temperature: -1,
                        maxRetries: 1,
                        enableSttValidation: false,
                        topP: nil,
                        topK: nil,
                        seed: nil,
                        qwenInstruction: [
                            saved.voiceDescription,
                            qwenSpeedInstruction(for: saved.speedScale ?? 1.0),
                            emotionTest.instruction,
                        ]
                        .compactMap { $0 }
                        .joined(separator: ". "),
                        qwenModelPath: VoiceConfig.defaultQwenVoiceDesignModelPath,
                        qwenSpeakerId: nil,
                        qwenLanguage: saved.language,
                        qwenMaxNewTokens: 384,
                        timeoutSeconds: 300
                    )
                    try await AudioSpeedProcessor.apply(
                        speed: saved.speedScale ?? 1.0,
                        to: outputPath
                    )

                    await MainActor.run {
                        do {
                            guard FileManager.default.fileExists(atPath: outputPath) else {
                                throw PreviewError.missingGeneratedFile
                            }
                            var updated = saved
                            updated.previewAudioPath = outputPath
                            let stored = try library.save(updated)
                            if let previousPreviewPath, previousPreviewPath != outputPath {
                                try? FileManager.default.removeItem(atPath: previousPreviewPath)
                            }
                            select(stored)
                            isGenerating = false
                            statusMessage = "Exemple prêt. Cliquez sur « Écouter »."
                            statusIsError = false
                        } catch {
                            isGenerating = false
                            statusMessage = error.localizedDescription
                            statusIsError = true
                        }
                    }
                } catch {
                    try? FileManager.default.removeItem(atPath: outputPath)
                    await MainActor.run {
                        isGenerating = false
                        statusMessage =
                            "Échec de génération : \(error.localizedDescription). L'ancien exemple n'a pas été remplacé."
                        statusIsError = true
                    }
                }
            }
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private enum PreviewError: LocalizedError {
        case missingGeneratedFile

        var errorDescription: String? {
            "Qwen a terminé sans produire de fichier WAV."
        }
    }

    private enum MasterVoiceError: LocalizedError {
        case missingPreview

        var errorDescription: String? {
            "Générez d'abord un exemple audio satisfaisant."
        }
    }

    private func qwenSpeedInstruction(for speed: Double) -> String? {
        switch speed {
        case ..<0.80:
            return "Speak very slowly, with long natural pauses and an unhurried rhythm"
        case 0.80..<0.93:
            return "Speak slowly, with measured pacing and natural pauses"
        case 0.93..<1.08:
            return nil
        case 1.08..<1.18:
            return "Speak briskly, with a lively but clearly articulated rhythm"
        case 1.18..<1.45:
            return "Speak quickly and energetically while remaining clear and intelligible"
        default:
            return "Speak extremely quickly with very short pauses, while preserving clear articulation and intelligibility"
        }
    }

    private func playPreview() {
        guard let path = currentProfile?.previewAudioPath,
              FileManager.default.fileExists(atPath: path) else {
            statusMessage = "Aucun WAV d'essai disponible pour cette voix."
            statusIsError = true
            return
        }
        do {
            stopPreview()
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            let duration = audioPlayer?.duration ?? 0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                if audioPlayer?.isPlaying != true {
                    isPlaying = false
                }
            }
        } catch {
            statusMessage = "Lecture impossible : \(error.localizedDescription)"
            statusIsError = true
        }
    }

    private func stopPreview() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    private func deleteCurrentProfile() {
        guard let profile = currentProfile else { return }
        do {
            try library.delete(profile)
            if voiceConfig.qwenVoiceDesignProfileId == profile.id {
                voiceConfig.qwenVoiceDesignProfileId = nil
                voiceConfig.qwenVoiceDesignName = nil
                voiceConfig.qwenVoiceDesignDescription = nil
                voiceConfig.qwenVoiceMode = .customVoice
                voiceConfig.qwenModelPath = VoiceConfig.defaultQwenModelPath
            }
            beginNewProfile()
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }
}
