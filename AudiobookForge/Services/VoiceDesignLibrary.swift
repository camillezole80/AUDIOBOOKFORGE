import Foundation
import Combine

@MainActor
final class VoiceDesignLibrary: ObservableObject {
    static let shared = VoiceDesignLibrary()

    @Published private(set) var profiles: [VoiceDesignProfile] = []
    @Published private(set) var loadError: String?

    let directoryPath: String
    private let catalogPath: String
    private let fileManager = FileManager.default

    private init() {
        directoryPath = "\(PathResolver.externalVolumeRoot)/LocalData/VoiceDesignProfiles"
        catalogPath = "\(directoryPath)/profiles.json"
        load()
    }

    func profile(id: UUID?) -> VoiceDesignProfile? {
        guard let id else { return nil }
        return profiles.first { $0.id == id }
    }

    @discardableResult
    func save(_ profile: VoiceDesignProfile) throws -> VoiceDesignProfile {
        var saved = profile
        saved.name = saved.name.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.voiceDescription = saved.voiceDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.previewText = saved.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.language = saved.language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        saved.updatedAt = Date()

        guard !saved.name.isEmpty else {
            throw LibraryError.invalidProfile("Donnez un nom à la voix.")
        }
        guard !saved.voiceDescription.isEmpty else {
            throw LibraryError.invalidProfile("Décrivez la voix à concevoir.")
        }
        guard !saved.previewText.isEmpty else {
            throw LibraryError.invalidProfile("Saisissez le texte à lire pour l'essai.")
        }
        if saved.language.isEmpty {
            saved.language = "fr"
        }

        try ensureDirectory()
        if let index = profiles.firstIndex(where: { $0.id == saved.id }) {
            profiles[index] = saved
        } else {
            profiles.append(saved)
        }
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        try persist()
        return saved
    }

    func delete(_ profile: VoiceDesignProfile) throws {
        profiles.removeAll { $0.id == profile.id }
        if let path = profile.previewAudioPath {
            try? fileManager.removeItem(atPath: path)
        }
        try persist()
    }

    func previewPath(for profile: VoiceDesignProfile) throws -> String {
        try ensureDirectory()
        return "\(directoryPath)/\(profile.id.uuidString)-\(UUID().uuidString).wav"
    }

    private func load() {
        do {
            try ensureDirectory()
            if fileManager.fileExists(atPath: catalogPath) {
                let data = try Data(contentsOf: URL(fileURLWithPath: catalogPath))
                profiles = try JSONDecoder.voiceDesign.decode([VoiceDesignProfile].self, from: data)
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            } else {
                try installStarterProfiles()
            }
            try installCuratedProfiles()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func installStarterProfiles() throws {
        let previewText =
            "La nuit descendait sur la vallée. Au loin, une lumière apparut derrière les arbres, puis s'éteignit brusquement. Camille retint son souffle et avança sans bruit."
        let sourceDirectory =
            "\(PathResolver.externalVolumeRoot)/audio/Projects/qwen_expressivite_abf/export/voix_francaises"
        let starters: [(UUID, String, String, String)] = [
            (
                UUID(uuidString: "A9CB2301-613F-49FD-AC64-88C42B158001")!,
                "Narrateur français grave",
                "Voix masculine française native, adulte, grave et chaleureuse, narration littéraire naturelle, diction française précise.",
                "\(sourceDirectory)/01_narrateur_francais_qwen.wav"
            ),
            (
                UUID(uuidString: "A9CB2301-613F-49FD-AC64-88C42B158002")!,
                "Narratrice française chaleureuse",
                "Voix féminine française native, adulte, claire et chaleureuse, narration littéraire naturelle, diction française précise.",
                "\(sourceDirectory)/02_narratrice_francaise_qwen.wav"
            ),
        ]

        profiles = try starters.map { id, name, description, sourcePath in
            let destination = "\(directoryPath)/\(id.uuidString).wav"
            if fileManager.fileExists(atPath: sourcePath),
               !fileManager.fileExists(atPath: destination) {
                try fileManager.copyItem(atPath: sourcePath, toPath: destination)
            }
            return VoiceDesignProfile(
                id: id,
                name: name,
                voiceDescription: description,
                language: "fr",
                previewText: previewText,
                previewAudioPath: fileManager.fileExists(atPath: destination) ? destination : nil
            )
        }
        try persist()
    }

    private func installCuratedProfiles() throws {
        let preview =
            "La pluie frappait les vitres. Soudain, trois coups résonnèrent derrière la porte, et toute la maison sembla retenir son souffle."
        let definitions: [(String, String, Double)] = [
            (
                "Aventurier héroïque",
                "A native French male voice, a young adult around 30 years old. The voice has strong chest resonance, a warm timbre and a powerful but natural projection. Confident, courageous and energetic. Read as grand adventure narration, vivid and cinematic without shouting. Clear intelligible French diction and realistic human prosody.",
                1.08
            ),
            (
                "Bibliothécaire mystérieuse",
                "A native French female voice, a mature person around 58 years old. The voice has a soft, slightly breathy texture, a low pitch and a warm restrained timbre. Mysterious, observant and quietly intriguing. Read as intimate literary narration with deliberate pauses.",
                0.92
            ),
            (
                "Conteur merveilleux",
                "A native French male voice, a mature person around 62 years old. The voice is warm, resonant, gentle and expressive. Kind, imaginative and reassuring. Read as enchanting fairy-tale storytelling with playful character color and spacious pauses.",
                0.90
            ),
            (
                "Détective désabusé",
                "A native French male voice, an adult around 48 years old. The voice has a low pitch, a smoky raspy texture and dry resonance. World-weary, ironic and restrained. Read as noir detective narration with terse phrasing and subtle tension.",
                0.95
            ),
            (
                "Documentaire scientifique",
                "A native French gender-neutral voice, an adult around 40 years old. The voice is clear, balanced, precise and naturally resonant. Calm, curious and authoritative. Read as accessible scientific documentary narration, informative and steady.",
                1.02
            ),
            (
                "Enfant espiègle",
                "A native French child voice around 10 years old. The voice is bright, light, youthful and natural. Curious, mischievous and joyful. Speak spontaneously with lively rhythm, playful emphasis and believable childlike energy.",
                1.12
            ),
            (
                "Grande dame aristocratique",
                "A native French female voice, a mature person around 68 years old. The voice is poised, resonant, slightly low-pitched and refined. Dignified, cool and subtly intimidating. Read in an elegant formal manner with impeccable measured articulation.",
                0.88
            ),
            (
                "Horreur chuchotée",
                "A native French gender-neutral voice, an adult around 38 years old. The voice is airy, breathy, fragile and close to a whisper. Ominous, unsettling and secretive. Read as atmospheric horror narration with long silences and intimate proximity.",
                0.82
            ),
            (
                "Héroïne romantique",
                "A native French female voice, a young adult around 28 years old. The voice is warm, soft, clear and gently breathy. Tender, emotionally open and intimate. Read as nuanced romantic-fiction narration with natural vulnerability.",
                0.96
            ),
            (
                "Historien solennel",
                "A native French male voice, a mature person around 60 years old. The voice is deep, resonant and composed. Solemn, dignified and authoritative. Read as historical documentary narration with deliberate pacing and restrained gravity.",
                0.90
            ),
            (
                "Humoriste pince-sans-rire",
                "A native French male voice, an adult around 42 years old. The voice is dry, clear and slightly nasal. Calmly amused, ironic and understated. Read with precise deadpan comic timing and unexpected subtle emphasis.",
                1.05
            ),
            (
                "IA androgyne apaisante",
                "A native French gender-neutral and androgynous voice, an adult around 32 years old. The voice is smooth, clear, soft and evenly resonant. Serene, attentive and reassuring. Speak with controlled natural phrasing, minimal affect and no robotic metallic tone.",
                1.00
            ),
            (
                "Journaliste énergique",
                "A native French female voice, a young adult around 34 years old. The voice is bright, focused, confident and well projected. Alert, direct and energetic. Read as polished broadcast journalism with brisk pacing and crisp articulation.",
                1.15
            ),
            (
                "Mère tendre",
                "A native French female voice, an adult around 45 years old. The voice is warm, soft, naturally breathy and reassuring. Tender, patient and protective. Read closely and intimately as if comforting one listener.",
                0.90
            ),
            (
                "Méchant théâtral",
                "A native French male voice, a mature person around 55 years old. The voice is deep, gravelly, resonant and controlled. Sinister, confident and darkly amused. Perform theatrical villain dialogue with deliberate menace, never caricatural.",
                0.88
            ),
            (
                "Narrateur de thriller",
                "A native French male voice, an adult around 40 years old. The voice is low-pitched, focused, slightly raspy and natural. Tense, controlled and urgent. Read as suspenseful thriller narration with accelerating rhythm and deliberate pauses.",
                1.08
            ),
            (
                "Poétesse mélancolique",
                "A native French female voice, a mature person around 52 years old. The voice is soft, smoky, warm and lightly breathy. Melancholic, reflective and emotionally restrained. Read poetry with musical phrasing and spacious natural pauses.",
                0.82
            ),
            (
                "Professeur bienveillant",
                "A native French male voice, a mature person around 57 years old. The voice is warm, clear, resonant and approachable. Patient, encouraging and quietly enthusiastic. Explain complex ideas conversationally with careful emphasis.",
                0.98
            ),
            (
                "Très vieille conteuse",
                "A native French female voice, a very elderly person around 90 years old, frail and breath-limited, with audible vocal aging. The voice has a low pitch, a hoarse raspy texture, a subtle tremor and low energy. Warm, wise and intimate. Read an old folktale slowly with frequent natural breaths.",
                0.78
            ),
            (
                "Urgence catastrophe",
                "A native French gender-neutral voice, an adult around 36 years old. The voice is clear, tense and strongly projected. Alarmed, urgent and focused under pressure. Deliver emergency narration rapidly with short breaths, sharp emphasis and complete intelligibility.",
                1.22
            ),
        ]

        var didChange = false
        for (index, definition) in definitions.enumerated() {
            let id = curatedProfileId(index: index)
            guard !profiles.contains(where: { $0.id == id }) else { continue }
            profiles.append(
                VoiceDesignProfile(
                    id: id,
                    name: definition.0,
                    voiceDescription: definition.1,
                    language: "fr",
                    previewText: preview,
                    speedScale: definition.2
                )
            )
            didChange = true
        }
        guard didChange else { return }
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        try persist()
    }

    private func curatedProfileId(index: Int) -> UUID {
        UUID(uuidString: String(format: "ABF00000-0000-4000-8000-%012X", index + 1))!
    }

    private func persist() throws {
        try ensureDirectory()
        let data = try JSONEncoder.voiceDesign.encode(profiles)
        try data.write(to: URL(fileURLWithPath: catalogPath), options: .atomic)
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)
    }

    enum LibraryError: LocalizedError {
        case invalidProfile(String)

        var errorDescription: String? {
            switch self {
            case .invalidProfile(let message): return message
            }
        }
    }
}

private extension JSONEncoder {
    static var voiceDesign: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var voiceDesign: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
