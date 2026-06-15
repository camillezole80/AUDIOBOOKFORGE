import SwiftUI

/// Étape (conditionnelle) : Injection et édition des balises émotionnelles.
/// N'apparaît dans le pipeline que si `voiceConfig.engineSupportsTags == true`.
struct TagsStepView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel
    @State private var showAISettings = false

    var body: some View {
        VStack(spacing: 20) {
            // En-tête
            HStack(alignment: .top) {
                VStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                    Text("Balises émotionnelles")
                        .font(.title2)
                        .fontWeight(.semibold)
                    if let project = pipelineVM.project {
                        HStack(spacing: 6) {
                            Text("Enrichissement via \(project.aiConfig.preferredProvider.displayName)")
                                .foregroundColor(.secondary)
                            Button(action: { showAISettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.borderless)
                            .help("Changer le provider IA (Ollama / OpenAI / Anthropic / DeepSeek)")
                        }
                    } else {
                        Text("Enrichissement du texte")
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Raccourci visible "Sauter le balisage"
                if pipelineVM.project != nil {
                    VStack(spacing: 4) {
                        Button(action: { pipelineVM.currentStep = .generation }) {
                            HStack(spacing: 4) {
                                Image(systemName: "forward.fill")
                                Text("Sauter")
                            }
                        }
                        .buttonStyle(.bordered)
                        .help("Aller directement à la génération sans baliser le texte")

                        Text("Étape optionnelle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if pipelineVM.project != nil {
                TaggingModeSelector()
            }

            // Curseur de densité de balises (s'applique à tous les providers)
            if pipelineVM.project?.aiConfig.taggingMode.usesAI == true {
                TagDensitySlider(
                    density: Binding(
                        get: { pipelineVM.project?.aiConfig.tagDensity ?? 0.5 },
                        set: { newValue in
                            guard var p = pipelineVM.project else { return }
                            p.aiConfig.tagDensity = newValue
                            ProjectManager.shared.updateProject(p)
                            pipelineVM.project = p
                        }
                    )
                )
                .padding(.horizontal)
            }

            // Sélecteur de chapitre
            if let project = pipelineVM.project,
               project.aiConfig.taggingMode.usesAI,
               !project.chapters.isEmpty {
                Picker("Chapitre", selection: $pipelineVM.selectedChapterIndex) {
                    ForEach(Array(project.chapters.enumerated()), id: \.offset) { index, chapter in
                        Text(chapter.title)
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 300)

                // Texte enrichi avec balises colorées
                if let chapter = project.chapters[safe: pipelineVM.selectedChapterIndex] {
                    if let direction = chapter.artDirection {
                        DisclosureGroup("Direction artistique du chapitre") {
                            VStack(alignment: .leading, spacing: 6) {
                                ArtDirectionRow(label: "Ton", value: direction.overallTone)
                                ArtDirectionRow(label: "Style", value: direction.literaryStyle)
                                ArtDirectionRow(label: "Narration", value: direction.narrativeVoice)
                                ArtDirectionRow(label: "Rythme", value: direction.pacing)
                                ArtDirectionRow(label: "Arc émotionnel", value: direction.emotionalArc)
                                ArtDirectionRow(label: "Personnages", value: direction.characterDynamics)
                                ArtDirectionRow(label: "Dialogues", value: direction.dialogueGuidance)
                                ArtDirectionRow(label: "Retenue", value: direction.restraintNotes)
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(Color.accentColor.opacity(0.08))
                        .cornerRadius(8)
                    }

                    TaggedTextView(
                        text: chapter.taggedText ?? chapter.rawText,
                        tagColors: pipelineVM.tagColors
                    )
                    .frame(maxHeight: 300)
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)

                    // Actions sur le chapitre
                    HStack(spacing: 16) {
                        Button("Régénérer ce chapitre") {
                            Task {
                                await pipelineVM.regenerateChapter(at: pipelineVM.selectedChapterIndex)
                            }
                        }
                        .disabled(pipelineVM.isProcessing)

                        Button("Supprimer les balises") {
                            pipelineVM.removeAllTags(from: pipelineVM.selectedChapterIndex)
                        }
                        .foregroundColor(.red)
                    }
                }
            }

            // Bouton d'injection globale
            if let project = pipelineVM.project, project.aiConfig.taggingMode.usesAI {
                if project.status == .textExtracted || project.status == .tagsInjected {
                    VStack(spacing: 12) {
                        Button(action: {
                            Task { await pipelineVM.injectTags() }
                        }) {
                            HStack {
                                if pipelineVM.isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(pipelineVM.isProcessing ? "Enrichissement en cours..." : "Enrichir tous les chapitres")
                            }
                            .frame(maxWidth: 250)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(pipelineVM.isProcessing)

                        if pipelineVM.isProcessing {
                            ProgressView(value: pipelineVM.progress) {
                                Text("\(Int(pipelineVM.progress * 100))%")
                                    .font(.caption)
                            }
                            .frame(maxWidth: 300)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Boutons d'export du texte balisé
                        HStack(spacing: 12) {
                            Button(action: {
                                Task { await pipelineVM.exportTaggedText(format: .txt) }
                            }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                    Text("Exporter en TXT")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(pipelineVM.isProcessing)
                            
                            Button(action: {
                                Task { await pipelineVM.exportTaggedText(format: .pdf) }
                            }) {
                                HStack {
                                    Image(systemName: "doc.richtext")
                                    Text("Exporter en PDF")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(pipelineVM.isProcessing)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Bouton pour passer à l'étape suivante (même si balisage partiel)
                        let taggedCount = project.chapters.filter { $0.status == .tagged }.count
                        if taggedCount > 0 {
                            VStack(spacing: 8) {
                                Text("\(taggedCount)/\(project.chapters.count) chapitre(s) enrichi(s)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

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
                                .disabled(pipelineVM.isProcessing)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showAISettings) {
            // Sheet de config du provider IA : lit pipelineVM.project directement
            // (cf. note dans VoiceStepView sur le piège du snapshot capturé).
            AISettingsView(aiConfig: Binding(
                get: { pipelineVM.project?.aiConfig ?? AIConfig() },
                set: { newConfig in
                    guard var project = pipelineVM.project else { return }
                    project.aiConfig = newConfig
                    ProjectManager.shared.updateProject(project)
                    pipelineVM.project = project
                }
            ))
        }
    }
}

struct TaggingModeSelector: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel

    var body: some View {
        if let project = pipelineVM.project {
            VStack(alignment: .leading, spacing: 10) {
                Text("Type de balisage")
                    .font(.headline)

                Picker("Type de balisage", selection: Binding(
                    get: { pipelineVM.project?.aiConfig.taggingMode ?? .none },
                    set: { pipelineVM.updateTaggingMode($0) }
                )) {
                    Text("Sans balisage").tag(TaggingMode.none)
                    Text("Fish S2").tag(TaggingMode.fishS2)
                    Text("Qwen3-TTS").tag(TaggingMode.qwen3TTS)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(project.aiConfig.taggingMode.shortDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if project.aiConfig.taggingMode == .qwen3TTS {
                    Label(
                        "Le moteur Qwen3-TTS est sélectionné automatiquement. Choisissez ensuite une voix intégrée ou VoiceDesign dans Réglages audio.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundColor(.orange)
                } else if project.aiConfig.taggingMode == .fishS2 {
                    Label(
                        "Le moteur Fish S2-Pro est sélectionné automatiquement.",
                        systemImage: "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

private struct ArtDirectionRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.bold())
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Vue texte enrichi avec balises colorées

struct TaggedTextView: View {
    let text: String
    let tagColors: [String: Color]

    var body: some View {
        ScrollView {
            Text(attributedText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var attributedText: AttributedString {
        var attributed = AttributedString(text)

        for (tag, color) in tagColors {
            var searchRange = text.startIndex..<text.endIndex

            while let range = text.range(of: tag, range: searchRange) {
                let nsRange = NSRange(range, in: text)
                if let attrRange = Range(nsRange, in: attributed) {
                    attributed[attrRange].foregroundColor = color
                    attributed[attrRange].font = .body.bold()
                    attributed[attrRange].backgroundColor = color.opacity(0.15)
                }
                searchRange = range.upperBound..<text.endIndex
            }
        }

        return attributed
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

// MARK: - Curseur de densité de balises

/// Slider 0..1 pilotant l'agressivité du balisage par l'IA (Ollama / OpenAI / Anthropic / DeepSeek).
/// La valeur est passée à `AIConfig.tagDensityInstruction` qui la traduit en consigne textuelle
/// injectée dans le prompt — identique pour tous les providers.
struct TagDensitySlider: View {
    @Binding var density: Double

    private var label: String {
        switch density {
        case ..<0.15:  return "Très peu"
        case 0.15..<0.4: return "Peu"
        case 0.4..<0.65: return "Modéré"
        case 0.65..<0.85: return "Dense"
        default: return "Très dense"
        }
    }

    private var labelColor: Color {
        switch density {
        case ..<0.15:  return .gray
        case 0.15..<0.4: return .blue
        case 0.4..<0.65: return .green
        case 0.65..<0.85: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.secondary)
                Text("Densité de balises")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(labelColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(labelColor.opacity(0.15))
                    .cornerRadius(4)
            }

            HStack(spacing: 8) {
                Text("Très peu")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Slider(value: $density, in: 0.0...1.0, step: 0.05)
                Text("Très dense")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text("La consigne s'applique aux 4 providers d'IA (Ollama, OpenAI, Anthropic, DeepSeek) et n'a pas d'effet sur les chapitres déjà balisés.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
