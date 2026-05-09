import SwiftUI

/// Étape 2 : Injection et édition des balises émotionnelles
struct TagsStepView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel

    var body: some View {
        VStack(spacing: 20) {
            // En-tête
            VStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                Text("Balises émotionnelles")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Enrichissement du texte via Qwen3 Ollama")
                    .foregroundColor(.secondary)
            }

            // Sélecteur de chapitre
            if let project = pipelineVM.project, !project.chapters.isEmpty {
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
            if let project = pipelineVM.project {
                if project.status == .textExtracted || project.status == .tagsInjected {
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
                }
            }
        }
        .padding()
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
