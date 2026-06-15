import Foundation

struct VoiceDesignProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var voiceDescription: String
    var language: String
    var previewText: String
    var previewAudioPath: String?
    var speedScale: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        voiceDescription: String,
        language: String = "fr",
        previewText: String,
        previewAudioPath: String? = nil,
        speedScale: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.voiceDescription = voiceDescription
        self.language = language
        self.previewText = previewText
        self.previewAudioPath = previewAudioPath
        self.speedScale = speedScale
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
