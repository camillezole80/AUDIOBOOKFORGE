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
        // Utiliser le disque externe J3THext pour stocker les fichiers audio
        let baseDir = "/Volumes/J3THext/Audiobookforge/audio/Projects"
        return "\(baseDir)/\(name)"
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
    var status: ChapterStatus
    var audioFilePath: String?
    var duration: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case id, index, title, rawText, taggedText, status, audioFilePath, duration
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

    var hasValidReference: Bool {
        // Si Fish.Audio est configuré, pas besoin de référence locale
        if preferredProvider == .fishAudio {
            return true
        }
        // TTS Audiobook Tool nécessite une référence locale
        if preferredProvider == .ttsAudiobookTool {
            return !referenceAudioPath.isEmpty && !referenceTranscription.isEmpty
        }
        // Sinon, vérifier la référence locale
        return !referenceAudioPath.isEmpty && !referenceTranscription.isEmpty
    }
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
    
    // Modèles personnalisables
    var openaiModel: String = "gpt-4o-mini"
    var anthropicModel: String = "claude-3-5-sonnet-20241022"
    var deepseekModel: String = "deepseek-chat"
    
    // Note: Les clés API sont stockées dans le Keychain, pas ici
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
    case local = "local"
    case fishAudio = "fishAudio"
    case ttsAudiobookTool = "ttsAudiobookTool"
    
    var displayName: String {
        switch self {
        case .local: return "Local (MLX - Gratuit)"
        case .fishAudio: return "Fish.Audio API"
        case .ttsAudiobookTool: return "TTS Audiobook Tool (Local)"
        }
    }
    
    var requiresAPIKey: Bool {
        self == .fishAudio
    }
    
    var costPer1MBytes: Double {
        switch self {
        case .local: return 0.0
        case .fishAudio: return 15.0  // $15 per 1M bytes UTF-8
        case .ttsAudiobookTool: return 0.0
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
}
