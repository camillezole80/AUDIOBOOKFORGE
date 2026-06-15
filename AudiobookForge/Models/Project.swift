import Foundation

struct Project: Identifiable, Codable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
    
    var id = UUID()
    var name: String
    var sourceFilePath: String
    var sourceFileType: FileType
    var metadata: BookMetadata
    var chapters: [Chapter]
    var voiceConfig: VoiceConfig
    var exportConfig: ExportConfig
    var aiConfig: AIConfig = AIConfig()
    var createdAt: Date
    var updatedAt: Date
    var status: ProjectStatus
    var coverImagePath: String?

    var progressPercentage: Double {
        guard !chapters.isEmpty else { return 0 }
        let completed = chapters.filter { $0.status == .audioReady }.count
        return Double(completed) / Double(chapters.count) * 100
    }

    var projectDirectory: String {
        "\(PathResolver.shared.projectsPath)/\(name)"
    }

    static func createDefault(name: String, sourcePath: String, fileType: FileType) -> Project {
        Project(
            name: name,
            sourceFilePath: sourcePath,
            sourceFileType: fileType,
            metadata: BookMetadata(),
            chapters: [],
            voiceConfig: VoiceConfig(),
            exportConfig: ExportConfig(),
            createdAt: Date(),
            updatedAt: Date(),
            status: .imported
        )
    }
}

enum FileType: String, Codable, CaseIterable {
    case epub = "EPUB"
    case pdf = "PDF"
    case docx = "DOCX"
}

enum ProjectStatus: String, Codable {
    case imported = "Importé"
    case textExtracted = "Texte extrait"
    case tagsInjected = "Balises injectées"
    case audioGenerated = "Audio généré"
    case exported = "Exporté"
    case error = "Erreur"
}

struct BookMetadata: Codable {
    var title: String = ""
    var author: String = ""
    var language: String = "fr"
}

struct Chapter: Identifiable, Codable {
    var id = UUID()
    var index: Int
    var title: String
    var rawText: String
    var taggedText: String?
    var artDirection: ChapterArtDirection?
    var status: ChapterStatus
    var audioFilePath: String?
    var duration: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case id, index, title, rawText, taggedText, artDirection, status, audioFilePath, duration
    }
}

struct ChapterArtDirection: Codable, Hashable {
    var overallTone: String
    var literaryStyle: String
    var narrativeVoice: String
    var pacing: String
    var emotionalArc: String
    var characterDynamics: String
    var dialogueGuidance: String
    var restraintNotes: String

    var promptContext: String {
        """
        Ton général : \(overallTone)
        Style littéraire : \(literaryStyle)
        Voix narrative : \(narrativeVoice)
        Rythme du chapitre : \(pacing)
        Arc émotionnel : \(emotionalArc)
        Personnages et dynamiques : \(characterDynamics)
        Direction des dialogues : \(dialogueGuidance)
        Points de retenue : \(restraintNotes)
        """
    }
}

enum ChapterStatus: String, Codable, CaseIterable {
    case pending = "En attente"
    case textReady = "Texte prêt"
    case tagged = "Balises ajoutées"
    case audioReady = "Audio prêt"
    case error = "Erreur"
}

struct VoiceConfig: Codable {
    var referenceAudioPath: String = ""
    var referenceTranscription: String = ""
    var speedScale: Double = 1.0
    var temperature: Double = 0.8
    var voices: [VoiceProfile] = []
    
    // Configuration audio
    var preferredProvider: AudioProvider = .ttsAudiobookTool  // Par défaut: TTS Audiobook Tool
    // ⚠️ Legacy : conservés pour la rétrocompat avec les anciens project.json
    //    quand il existait un provider .local (MLX). Plus aucune logique ne les lit.
    var forceRemote: Bool = false
    var fallbackToRemote: Bool = true
    var fishAudioReferenceId: String? = nil  // ID de la voix sauvegardée sur Fish.Audio
    var selectedFishAudioVoice: String? = nil  // ID de la voix prédéfinie sélectionnée
    
    // Configuration pour TTS Audiobook Tool
    var ttsModel: TtsModelType = .fishS2Pro
    var enableSttValidation: Bool = true
    var maxRetries: Int = 3
    var enableUpsampling: Bool = false
    var enableNormalization: Bool = true
    var topP: Double? = nil
    var topK: Int? = nil
    var seed: Int? = nil
    var qwenModelPath: String? = nil
    var qwenSpeakerId: String? = nil
    var qwenLanguage: String? = nil
    var qwenVoiceMode: QwenVoiceMode? = nil
    var qwenVoiceDesignProfileId: UUID? = nil
    var qwenVoiceDesignName: String? = nil
    var qwenVoiceDesignDescription: String? = nil
    var qwenVoiceCloneName: String? = nil

    static let defaultQwenModelPath =
        "\(PathResolver.externalVolumeRoot)/LocalData/Models/Qwen3TTS/Qwen3-TTS-12Hz-1.7B-CustomVoice"
    static let defaultQwenVoiceDesignModelPath =
        "\(PathResolver.externalVolumeRoot)/LocalData/Models/Qwen3TTS/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
    static let defaultQwenVoiceCloneModelPath =
        "\(PathResolver.externalVolumeRoot)/LocalData/Models/Qwen3TTS/Qwen3-TTS-12Hz-1.7B-Base"
    static let qwenCustomVoiceSpeakers = [
        "ryan", "aiden", "eric", "dylan", "serena",
        "vivian", "uncle_fu", "ono_anna", "sohee",
    ]

    var resolvedQwenModelPath: String {
        if let configured = qwenModelPath?
            .trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            return configured
        }
        switch resolvedQwenVoiceMode {
        case .voiceDesign:
            return Self.defaultQwenVoiceDesignModelPath
        case .voiceClone:
            return Self.defaultQwenVoiceCloneModelPath
        case .customVoice:
            return Self.defaultQwenModelPath
        }
    }

    var resolvedQwenVoiceMode: QwenVoiceMode {
        qwenVoiceMode ?? (qwenVoiceDesignProfileId == nil ? .customVoice : .voiceDesign)
    }

    var resolvedQwenSpeakerId: String {
        qwenSpeakerId?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "ryan"
    }

    var resolvedQwenLanguage: String {
        qwenLanguage?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "fr"
    }

    func resolvedQwenInstruction(expressiveInstruction: String?) -> String? {
        let expression = expressiveInstruction?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        let speed = qwenSpeedInstruction
        let language = qwenLanguageInstruction
        guard resolvedQwenVoiceMode == .voiceDesign else {
            return [language, expression, speed]
                .compactMap { $0 }
                .joined(separator: ". ")
                .nonEmpty
        }

        let voice = qwenVoiceDesignDescription?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        return [language, voice, speed, expression, language]
            .compactMap { $0 }
            .joined(separator: ". ")
            .nonEmpty
    }

    var resolvedQwenSeed: Int {
        seed ?? 424_242
    }

    private var qwenLanguageInstruction: String? {
        switch resolvedQwenLanguage.lowercased() {
        case "fr", "fr-fr":
            return """
            Parler exclusivement en français métropolitain natif, avec une diction française \
            naturelle. Ne jamais employer de prononciation anglaise ni d'accent étranger
            """
        default:
            return nil
        }
    }

    var qwenSpeedInstruction: String? {
        switch speedScale {
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

    /// La configuration courante peut-elle générer de l'audio ?
    /// - Fish.Audio : exige un model_id (voix publique sélectionnée OU référence legacy).
    /// - TTS Audiobook Tool : exige sample local + transcription.
    var hasValidReference: Bool {
        switch preferredProvider {
        case .fishAudio:
            let hasModelId = (selectedFishAudioVoice?.isEmpty == false)
                          || (fishAudioReferenceId?.isEmpty == false)
            return hasModelId
        case .ttsAudiobookTool where ttsModel == .qwen3:
            let modelExists = FileManager.default.fileExists(atPath: resolvedQwenModelPath)
            if resolvedQwenVoiceMode == .voiceDesign {
                return modelExists
                    && qwenVoiceDesignDescription?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty == false
            }
            if resolvedQwenVoiceMode == .voiceClone {
                return modelExists
                    && FileManager.default.fileExists(atPath: referenceAudioPath)
                    && !referenceTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return modelExists && !resolvedQwenSpeakerId.isEmpty
        case .mlxFishS2, .ttsAudiobookTool:
            return !referenceAudioPath.isEmpty && !referenceTranscription.isEmpty
        }
    }

    /// Message d'aide quand la config n'est pas prête pour générer.
    var missingReferenceHint: String? {
        guard !hasValidReference else { return nil }
        switch preferredProvider {
        case .fishAudio:
            return "Sélectionnez une voix Fish.Audio dans les Réglages audio (icône 🔊)."
        case .mlxFishS2:
            return "MLX Fish S2-Pro nécessite un sample audio + sa transcription (onglet Voix)."
        case .ttsAudiobookTool:
            if ttsModel == .qwen3 {
                if resolvedQwenVoiceMode == .voiceDesign {
                    return "Sélectionnez une voix VoiceDesign valide, enregistrée sur J3THext."
                }
                if resolvedQwenVoiceMode == .voiceClone {
                    return "Le clonage Qwen nécessite un sample audio et sa transcription exacte."
                }
                return "Le checkpoint Qwen3-TTS CustomVoice est introuvable sur J3THext."
            }
            return "Importez un sample audio + sa transcription dans l'onglet Voix."
        }
    }

    /// Le couple (provider, modèle) lit-il les balises émotionnelles ?
    /// Si non, l'étape Balises est masquée dans le pipeline et les balises seraient
    /// strippées de toute façon par `AudioGenerationService.textForEngine`.
    var engineSupportsTags: Bool {
        switch preferredProvider {
        case .fishAudio:
            return true  // s2-pro lit nativement
        case .mlxFishS2:
            return true  // même modèle Fish-S2, quantizé en INT8
        case .ttsAudiobookTool:
            return ttsModel.supportsEmotionalTags
        }
    }
}

enum QwenVoiceMode: String, Codable, CaseIterable {
    case customVoice
    case voiceDesign
    case voiceClone
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

struct VoiceProfile: Identifiable, Codable {
    var id = UUID()
    var name: String
    var referenceAudioPath: String
    var referenceTranscription: String
}

struct ExportConfig: Codable {
    var format: ExportFormat = .aac
    var structure: ExportStructure = .perChapter
    var includeCover: Bool = true
    var includeMetadata: Bool = true
}

enum ExportFormat: String, Codable, CaseIterable {
    case wav = "WAV (24bit 44.1kHz)"
    case aac = "AAC (256kbps)"
    case mp3 = "MP3 (320kbps CBR)"
}

enum ExportStructure: String, Codable, CaseIterable {
    case perChapter = "Un fichier par chapitre"
    case singleM4B = "Fichier unique M4B"
}

struct Chunk: Identifiable, Codable {
    var id = UUID()
    var index: Int
    var chapterIndex: Int
    var text: String
    var status: ChunkStatus
    var audioFilePath: String?
    var errorMessage: String?
}

enum ChunkStatus: String, Codable {
    case pending = "pending"
    case done = "done"
    case error = "error"
}

// MARK: - AI Configuration

struct AIConfig: Codable {
    var preferredProvider: AIProvider = .ollama
    var forceRemote: Bool = false
    var fallbackToRemote: Bool = true
    var showCostEstimate: Bool = true
    var taggingMode: TaggingMode = .fishS2

    // Modèles personnalisables
    var openaiModel: String = "gpt-4o-mini"
    var anthropicModel: String = "claude-3-5-sonnet-20241022"
    var deepseekModel: String = "deepseek-v4-flash"

    /// Densité de balises injectées par l'IA, de 0 (quasi aucune) à 1 (beaucoup).
    /// 0.5 = défaut "1 balise toutes les 3-4 phrases".
    var tagDensity: Double = 0.5

    // Note: Les clés API sont stockées dans le Keychain, pas ici

    private enum CodingKeys: String, CodingKey {
        case preferredProvider, forceRemote, fallbackToRemote, showCostEstimate
        case taggingMode, openaiModel, anthropicModel, deepseekModel, tagDensity
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredProvider = try container.decodeIfPresent(AIProvider.self, forKey: .preferredProvider) ?? .ollama
        forceRemote = try container.decodeIfPresent(Bool.self, forKey: .forceRemote) ?? false
        fallbackToRemote = try container.decodeIfPresent(Bool.self, forKey: .fallbackToRemote) ?? true
        showCostEstimate = try container.decodeIfPresent(Bool.self, forKey: .showCostEstimate) ?? true
        taggingMode = try container.decodeIfPresent(TaggingMode.self, forKey: .taggingMode) ?? .fishS2
        openaiModel = try container.decodeIfPresent(String.self, forKey: .openaiModel) ?? "gpt-4o-mini"
        anthropicModel = try container.decodeIfPresent(String.self, forKey: .anthropicModel) ?? "claude-3-5-sonnet-20241022"

        let savedDeepSeekModel = try container.decodeIfPresent(String.self, forKey: .deepseekModel)
        deepseekModel = savedDeepSeekModel == nil || savedDeepSeekModel == "deepseek-chat"
            ? "deepseek-v4-flash"
            : savedDeepSeekModel!
        tagDensity = try container.decodeIfPresent(Double.self, forKey: .tagDensity) ?? 0.5
    }
}

enum TaggingMode: String, Codable, CaseIterable, Identifiable {
    case none
    case fishS2
    case qwen3TTS

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Aucun"
        case .fishS2: return "Fish S2"
        case .qwen3TTS: return "Qwen3-TTS"
        }
    }

    var shortDescription: String {
        switch self {
        case .none:
            return "Le texte original est envoyé au moteur sans enrichissement."
        case .fishS2:
            return "Marqueurs Fish S2, par exemple [whispering] ou [excited]."
        case .qwen3TTS:
            return "Instructions expressives internes transmises séparément à Qwen3-TTS."
        }
    }

    var usesAI: Bool { self != .none }
}

/// Convertit une valeur 0..1 en consigne textuelle injectée dans le prompt LLM.
/// Centralisé ici pour que Ollama et les providers distants produisent un balisage
/// cohérent en intensité.
extension AIConfig {
    var tagDensityInstruction: String {
        switch tagDensity {
        case ..<0.15:
            return "TRÈS PEU de balises : maximum 1 balise toutes les 10-15 phrases, uniquement aux moments les plus forts du texte"
        case 0.15..<0.4:
            return "PEU de balises : environ 1 balise toutes les 6-8 phrases, réservées aux passages émotionnels marqués"
        case 0.4..<0.65:
            return "balisage MODÉRÉ : environ 1 balise toutes les 3-4 phrases en moyenne"
        case 0.65..<0.85:
            return "balisage DENSE : environ 1 balise toutes les 2 phrases, en suivant attentivement les changements de ton"
        default:
            return "balisage TRÈS DENSE : presque chaque phrase a une balise, suivez précisément chaque nuance émotionnelle (attention à ne pas saturer la narration)"
        }
    }
}

enum AIProvider: String, Codable, CaseIterable {
    case ollama = "Ollama (Local)"
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case deepseek = "DeepSeek"
    
    var displayName: String { rawValue }
    
    var requiresAPIKey: Bool {
        self != .ollama
    }
    
    var costPer1KTokens: Double {
        switch self {
        case .ollama: return 0.0
        case .openai: return 0.01  // GPT-4o-mini
        case .anthropic: return 0.015  // Claude 3.5 Sonnet
        case .deepseek: return 0.001  // DeepSeek V3
        }
    }
}

// MARK: - Audio Configuration

enum AudioProvider: String, Codable, CaseIterable {
    case fishAudio = "fishAudio"
    case mlxFishS2 = "mlxFishS2"         // MLX Fish-S2-Pro INT8 (local, optimisé Apple Silicon)
    case ttsAudiobookTool = "ttsAudiobookTool"

    var displayName: String {
        switch self {
        case .fishAudio: return "Fish.Audio API (Cloud)"
        case .mlxFishS2: return "Fish S2-Pro MLX INT8 (Local, M-series)"
        case .ttsAudiobookTool: return "TTS Audiobook Tool (Local, multi-modèles)"
        }
    }

    var requiresAPIKey: Bool {
        self == .fishAudio
    }

    var costPer1MBytes: Double {
        switch self {
        case .fishAudio: return 15.0
        case .mlxFishS2, .ttsAudiobookTool: return 0.0
        }
    }

    /// Le provider lit-il nativement les balises émotionnelles Fish-style
    /// ([whispering], [excited], …) ? Si non, les balises doivent être strippées
    /// avant l'envoi au moteur sous peine d'être prononcées comme du texte.
    /// Pour TTS Audiobook Tool, la réponse dépend du modèle choisi
    /// (`TtsModelType.supportsEmotionalTags`).
    var supportsEmotionalTags: Bool {
        switch self {
        case .fishAudio: return true
        case .mlxFishS2: return true  // même modèle Fish-S2, balises lues nativement
        case .ttsAudiobookTool: return false  // dépend du modèle (cf. TtsModelType)
        }
    }
}

// MARK: - TTS Model Types

enum TtsModelType: String, Codable, CaseIterable {
    case fishS2Pro = "fish-s2"
    case chatterbox = "chatterbox"
    case qwen3 = "qwen3"

    var displayName: String {
        switch self {
        case .fishS2Pro: return "Fish S2-Pro (Haute qualité)"
        case .chatterbox: return "Chatterbox (Multilingue)"
        case .qwen3: return "Qwen3-TTS (Rapide)"
        }
    }

    var requiresVRAM: Int {
        switch self {
        case .fishS2Pro: return 24
        case .chatterbox: return 8
        case .qwen3: return 12
        }
    }

    var description: String {
        switch self {
        case .fishS2Pro: return "Qualité maximale, 24GB VRAM requis"
        case .chatterbox: return "Multilingue, rapide, 8GB VRAM"
        case .qwen3: return "Batch processing, efficace, 12GB VRAM"
        }
    }

    /// Seul Fish S2-Pro reconnaît les balises émotionnelles Fish-style.
    /// Chatterbox et Qwen3 les liraient comme du texte → il faut les supprimer.
    var supportsEmotionalTags: Bool {
        switch self {
        case .fishS2Pro: return true
        case .chatterbox, .qwen3: return false
        }
    }
}
