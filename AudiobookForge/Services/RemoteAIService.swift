import Foundation

/// Service d'intégration avec les API d'IA distantes (OpenAI, Anthropic, DeepSeek)
class RemoteAIService {
    static let shared = RemoteAIService()
    
    private let session: URLSession
    private let logger = Logger.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes max
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Enrichit un texte avec des balises émotionnelles via une API distante
    func injectTags(
        text: String,
        provider: AIProvider,
        apiKey: String,
        model: String? = nil,
        progressHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        logger.info("Starting remote AI enrichment with \(provider.rawValue)")
        
        switch provider {
        case .openai:
            return try await enrichWithOpenAI(text: text, apiKey: apiKey, model: model ?? "gpt-4o-mini", progressHandler: progressHandler)
        case .anthropic:
            return try await enrichWithAnthropic(text: text, apiKey: apiKey, model: model ?? "claude-3-5-sonnet-20241022", progressHandler: progressHandler)
        case .deepseek:
            return try await enrichWithDeepSeek(text: text, apiKey: apiKey, model: model ?? "deepseek-chat", progressHandler: progressHandler)
        case .ollama:
            throw RemoteAIError.invalidProvider("Ollama should use OllamaService")
        }
    }
    
    /// Teste la validité d'une clé API
    func testConnection(provider: AIProvider, apiKey: String) async -> Bool {
        logger.info("🔍 Testing connection for \(provider.rawValue)...")
        
        do {
            let testText = "Bonjour, ceci est un test."
            let result = try await injectTags(text: testText, provider: provider, apiKey: apiKey)
            
            logger.info("✅ Connection test successful for \(provider.rawValue)")
            logger.info("   Result preview: \(result.prefix(100))...")
            
            return true
        } catch {
            logger.error("❌ Connection test failed for \(provider.rawValue): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Estime le coût d'enrichissement pour un texte donné
    func estimateCost(text: String, provider: AIProvider) -> (tokens: Int, cost: Double) {
        let tokens = estimateTokens(text: text)
        let costPer1K: Double
        
        switch provider {
        case .openai:
            costPer1K = 0.01 // GPT-4o-mini: ~$0.01/1K tokens
        case .anthropic:
            costPer1K = 0.015 // Claude 3.5 Sonnet: ~$0.015/1K tokens
        case .deepseek:
            costPer1K = 0.001 // DeepSeek V3: ~$0.001/1K tokens
        case .ollama:
            costPer1K = 0.0 // Local, gratuit
        }
        
        let cost = Double(tokens) / 1000.0 * costPer1K
        return (tokens, cost)
    }
    
    // MARK: - OpenAI
    
    private func enrichWithOpenAI(
        text: String,
        apiKey: String,
        model: String,
        progressHandler: ((String) -> Void)?
    ) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw RemoteAIError.invalidURL
        }
        
        let prompt = buildPrompt(text: text)
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "Tu es un directeur artistique spécialisé dans la narration d'audiobooks."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "stream": false
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("OpenAI API error (\(httpResponse.statusCode)): \(errorMessage)")
            throw RemoteAIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw RemoteAIError.invalidResponse
        }
        
        logger.info("OpenAI enrichment completed successfully")
        return content
    }
    
    // MARK: - Anthropic
    
    private func enrichWithAnthropic(
        text: String,
        apiKey: String,
        model: String,
        progressHandler: ((String) -> Void)?
    ) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw RemoteAIError.invalidURL
        }
        
        let prompt = buildPrompt(text: text)
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Anthropic API error (\(httpResponse.statusCode)): \(errorMessage)")
            throw RemoteAIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw RemoteAIError.invalidResponse
        }
        
        logger.info("Anthropic enrichment completed successfully")
        return text
    }
    
    // MARK: - DeepSeek
    
    private func enrichWithDeepSeek(
        text: String,
        apiKey: String,
        model: String,
        progressHandler: ((String) -> Void)?
    ) async throws -> String {
        guard let url = URL(string: "https://api.deepseek.com/v1/chat/completions") else {
            throw RemoteAIError.invalidURL
        }
        
        let prompt = buildPrompt(text: text)
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "Tu es un directeur artistique spécialisé dans la narration d'audiobooks."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "stream": false
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("DeepSeek API error (\(httpResponse.statusCode)): \(errorMessage)")
            throw RemoteAIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw RemoteAIError.invalidResponse
        }
        
        logger.info("DeepSeek enrichment completed successfully")
        return content
    }
    
    // MARK: - Helpers
    
    private func buildPrompt(text: String) -> String {
        """
        Tu es un directeur artistique spécialisé dans la narration d'audiobooks.
        Tu reçois un passage de texte en français.
        Ta tâche est d'insérer des balises d'expression Fish Audio S2 Pro directement dans le texte,
        aux endroits précis où elles améliorent la narration.

        Règles strictes :
        - Ne modifie JAMAIS le texte original, les mots, la ponctuation ou l'orthographe
        - Insère uniquement des balises entre crochets : [whisper], [excited], [sad], [pause],
          [angry], [laughing], [chuckle], [emphasis], [clearing throat], [inhale],
          [professional broadcast tone], [warm], [tense], [mysterious]
        - Une balise s'applique à la phrase ou segment qui la suit immédiatement
        - N'abuse pas des balises : maximum 1 balise tous les 3-4 phrases en moyenne
        - Pour les dialogues : utilise [excited], [whisper], [angry] etc. selon le contexte émotionnel
        - Pour la narration neutre : laisse sans balise ou utilise [warm] occasionnellement
        - Retourne uniquement le texte enrichi, sans commentaires ni explications

        Texte à enrichir :
        \(text)
        """
    }
    
    private func estimateTokens(text: String) -> Int {
        // Estimation approximative : 1 token ≈ 4 caractères en français
        // Le prompt système ajoute ~200 tokens
        let textTokens = text.count / 4
        let systemTokens = 200
        return textTokens + systemTokens
    }
}

// MARK: - Errors

enum RemoteAIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidProvider(String)
    case apiError(Int, String)
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL de l'API invalide"
        case .invalidResponse:
            return "Réponse de l'API invalide"
        case .invalidProvider(let message):
            return "Provider invalide : \(message)"
        case .apiError(let code, let message):
            return "Erreur API (\(code)) : \(message)"
        case .missingAPIKey:
            return "Clé API manquante"
        }
    }
}
