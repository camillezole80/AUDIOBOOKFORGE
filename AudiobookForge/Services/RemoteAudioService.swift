import Foundation

/// Service d'intégration avec l'API Fish.Audio pour la génération audio distante
class RemoteAudioService {
    static let shared = RemoteAudioService()
    
    private let session: URLSession
    private let logger = Logger.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes max
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Génère l'audio via Fish.Audio API
    func generateAudio(
        text: String,
        referenceAudio: Data?,
        referenceText: String?,
        referenceId: String?,
        apiKey: String,
        voiceConfig: VoiceConfig
    ) async throws -> Data {
        logger.info("Starting Fish.Audio generation...")
        
        guard let url = URL(string: "https://api.fish.audio/v1/tts") else {
            throw RemoteAudioError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("s2-pro", forHTTPHeaderField: "model")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "text": text,
            "temperature": voiceConfig.temperature,
            "format": "wav",
            "sample_rate": 44100,
            "max_new_tokens": 2048,
            "repetition_penalty": 1.2,
            "prosody": [
                "speed": voiceConfig.speedScale,
                "normalize_loudness": true
            ]
        ]
        
        // Méthode A : Utiliser un reference_id sauvegardé
        if let refId = referenceId {
            logger.info("Using saved reference ID: \(refId)")
            body["reference_id"] = refId
        }
        // Méthode B : Voice cloning à la volée (zero-shot)
        else if let audioData = referenceAudio, let refText = referenceText {
            logger.info("Using zero-shot voice cloning")
            let base64Audio = audioData.base64EncodedString()
            body["references"] = [[
                "audio": base64Audio,
                "text": refText
            ]]
        } else {
            throw RemoteAudioError.missingReference
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteAudioError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Fish.Audio API error (\(httpResponse.statusCode)): \(errorMessage)")
            throw RemoteAudioError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        logger.info("Fish.Audio generation completed successfully (\(data.count) bytes)")
        return data
    }
    
    /// Crée une voix sauvegardée sur Fish.Audio (pour réutilisation)
    func createReference(
        id: String,
        audio: Data,
        text: String,
        apiKey: String
    ) async throws {
        logger.info("Creating Fish.Audio reference: \(id)")
        
        guard let url = URL(string: "https://api.fish.audio/v1/references/add") else {
            throw RemoteAudioError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id": id,
            "text": text,
            "audio": audio.base64EncodedString()
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteAudioError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Fish.Audio reference creation error (\(httpResponse.statusCode)): \(errorMessage)")
            throw RemoteAudioError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        logger.info("Fish.Audio reference created successfully: \(id)")
    }
    
    /// Teste la validité d'une clé API
    func testConnection(apiKey: String) async -> Bool {
        logger.info("🔍 Testing Fish.Audio connection...")
        
        do {
            // Test simple sans référence audio
            let testText = "Test de connexion."
            let url = URL(string: "https://api.fish.audio/v1/tts")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("s2-pro", forHTTPHeaderField: "model")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "text": testText,
                "format": "wav"
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            let success = httpResponse.statusCode == 200
            logger.info(success ? "✅ Fish.Audio connection successful" : "❌ Fish.Audio connection failed")
            
            return success
        } catch {
            logger.error("❌ Fish.Audio connection test failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Estime le coût pour un texte donné
    func estimateCost(text: String) -> (bytes: Int, cost: Double) {
        let bytes = text.utf8.count
        let costPer1M = 15.0
        let cost = Double(bytes) / 1_000_000.0 * costPer1M
        return (bytes, cost)
    }
}

// MARK: - Errors

enum RemoteAudioError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case missingReference
    case apiError(Int, String)
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL de l'API invalide"
        case .invalidResponse:
            return "Réponse de l'API invalide"
        case .missingReference:
            return "Référence audio manquante (audio ou reference_id requis)"
        case .apiError(let code, let message):
            return "Erreur API Fish.Audio (\(code)) : \(message)"
        case .missingAPIKey:
            return "Clé API Fish.Audio manquante"
        }
    }
}
