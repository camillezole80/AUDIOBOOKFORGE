import SwiftUI

/// Panneau droit : paramètres contextuels selon l'étape active
struct ContextualSettingsView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paramètres")
                .font(.title3)
                .fontWeight(.semibold)

            Divider()

            switch pipelineVM.currentStep {
            case .import_:
                ImportSettings()
            case .tags:
                TagsSettings()
            case .voice:
                VoiceSettings()
            case .generation:
                GenerationSettings()
            case .export:
                ExportSettings()
            }
        }
        .padding()
        .frame(minWidth: 200)
    }
}

// MARK: - Settings panels

struct ImportSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Formats supportés", systemImage: "doc")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                FormatRow(name: "EPUB", desc: "ebooklib")
                FormatRow(name: "PDF", desc: "PyMuPDF")
                FormatRow(name: "DOCX", desc: "python-docx")
            }

            Divider()

            Label("Nettoyage appliqué", systemImage: "sparkle.magnifyingglass")
                .font(.headline)

            Text("• Numéros de page supprimés")
            Text("• Headers/footers détectés")
            Text("• Notes de bas de page retirées")
            Text("• Coupures de mots fusionnées")
            Text("• Guillemets normalisés")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct FormatRow: View {
    let name: String
    let desc: String

    var body: some View {
        HStack {
            Text(name)
                .fontWeight(.medium)
            Spacer()
            Text(desc)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TagsSettings: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Modèle", systemImage: "brain")
                .font(.headline)

            if let project = pipelineVM.project {
                Text(project.aiConfig.preferredProvider.displayName)
                    .font(.callout)
            } else {
                Text("Non configuré")
                    .font(.callout)
            }

            Text("Temperature: 0.3")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Label("Balises disponibles", systemImage: "tag")
                .font(.headline)

            TagList()
        }
    }
}

struct TagList: View {
    let tags = [
        ("[whisper]", "Murmure"),
        ("[excited]", "Excité"),
        ("[sad]", "Triste"),
        ("[pause]", "Pause"),
        ("[angry]", "En colère"),
        ("[laughing]", "Rire"),
        ("[chuckle]", "Ricanement"),
        ("[emphasis]", "Emphase"),
        ("[clearing throat]", "Raclage de gorge"),
        ("[inhale]", "Inspiration"),
        ("[professional broadcast tone]", "Ton professionnel"),
        ("[warm]", "Chaleureux"),
        ("[tense]", "Tendu"),
        ("[mysterious]", "Mystérieux")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(tags, id: \.0) { tag, desc in
                    HStack {
                        Text(tag)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        Text(desc)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxHeight: 200)
    }
}

struct VoiceSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Voice Cloning", systemImage: "waveform")
                .font(.headline)

            Text("Fish Audio S2 Pro via MLX")
                .font(.callout)

            Divider()

            Text("Sample recommandé : 10-30s")
                .font(.caption)

            Text("Transcription exacte requise")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct GenerationSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Génération", systemImage: "gearshape.2")
                .font(.headline)

            Text("Chunks de 200 mots max")
                .font(.callout)

            Text("Traitement chapitre par chapitre")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text("Progression persistante")
                .font(.headline)

            Text("Reprise automatique après interruption")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ExportSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export", systemImage: "square.and.arrow.up")
                .font(.headline)

            Text("Formats disponibles :")
                .font(.callout)

            Text("• WAV 24bit 44.1kHz")
            Text("• AAC 256kbps")
            Text("• MP3 320kbps CBR")
            Text("• M4B avec marqueurs")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text("Métadonnées automatiques")
                .font(.headline)

            Text("Titre, Auteur, Couverture")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
