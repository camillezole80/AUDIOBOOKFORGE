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
        let baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AudiobookForge/Projects")
            .path
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
    
    // Configuration pour Fish.Audio API
    var preferredProvider: AudioProvider = .local
    var forceRemote: Bool = false
    var fallbackToRemote: Bool = true
    var fishAudioReferenceId: String? = nil  // ID de la voix sauvegardée sur Fish.Audio

    var hasValidReference: Bool {
        // Si Fish.Audio est configuré, pas besoin de référence locale
        if preferredProvider == .fishAudio {
            return true
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
    case local = "Local (MLX)"
    case fishAudio = "Fish.Audio API"
    
    var displayName: String {
        switch self {
        case .local: return "Local (MLX - Gratuit)"
        case .fishAudio: return "Fish.Audio API"
        }
    }
    
    var requiresAPIKey: Bool {
        self == .fishAudio
    }
    
    var costPer1MBytes: Double {
        switch self {
        case .local: return 0.0
        case .fishAudio: return 15.0  // $15 per 1M bytes UTF-8
        }
    }
}
