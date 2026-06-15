import Foundation

/// Service d'intégration avec les API d'IA distantes (OpenAI, Anthropic, DeepSeek)
class RemoteAIService {
    static let shared = RemoteAIService()

    static let fishS2Markers = [
        "happy", "sad", "angry", "excited", "calm", "nervous", "scared",
        "worried", "surprised", "hopeful", "determined", "mysterious",
        "in a hurry tone", "shouting", "whispering", "soft tone",
        "laughing", "chuckling", "sighing", "gasping", "break", "long-break",
    ]
    
    private let session: URLSession
    private let logger = Logger.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes max
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API

    func analyzeChapter(
        text: String,
        title: String,
        provider: AIProvider,
        apiKey: String,
        model: String? = nil
    ) async throws -> ChapterArtDirection {
        let prompt = buildAnalysisPrompt(text: text, title: title)
        let result: String
        switch provider {
        case .openai:
            result = try await enrichWithOpenAI(
                prompt: prompt,
                apiKey: apiKey,
                model: model ?? "gpt-4o-mini",
                progressHandler: nil
            )
        case .anthropic:
            result = try await enrichWithAnthropic(
                prompt: prompt,
                apiKey: apiKey,
                model: model ?? "claude-3-5-sonnet-20241022",
                progressHandler: nil
            )
        case .deepseek:
            result = try await enrichWithDeepSeek(
                prompt: prompt,
                apiKey: apiKey,
                model: model ?? "deepseek-v4-flash",
                progressHandler: nil
            )
        case .ollama:
            throw RemoteAIError.invalidProvider("Ollama should use OllamaService")
        }
        return try decodeArtDirection(result)
    }
    
    /// Enrichit un texte avec des balises émotionnelles via une API distante.
    /// - Parameter densityInstruction: consigne textuelle pilotant la densité de balises
    ///   (voir `AIConfig.tagDensityInstruction`). Identique pour tous les providers.
    func injectTags(
        text: String,
        provider: AIProvider,
        apiKey: String,
        model: String? = nil,
        taggingMode: TaggingMode = .fishS2,
        densityInstruction: String = "balisage MODÉRÉ : environ 1 balise toutes les 3-4 phrases en moyenne",
        artDirection: ChapterArtDirection? = nil,
        progressHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        guard taggingMode.usesAI else { return text }
        logger.info("Starting remote AI enrichment with \(provider.rawValue)")

        let prompt = buildPrompt(
            text: text,
            taggingMode: taggingMode,
            densityInstruction: densityInstruction,
            artDirection: artDirection
        )
        let result: String
        switch provider {
        case .openai:
            result = try await enrichWithOpenAI(prompt: prompt, apiKey: apiKey, model: model ?? "gpt-4o-mini", progressHandler: progressHandler)
        case .anthropic:
            result = try await enrichWithAnthropic(prompt: prompt, apiKey: apiKey, model: model ?? "claude-3-5-sonnet-20241022", progressHandler: progressHandler)
        case .deepseek:
            result = try await enrichWithDeepSeek(prompt: prompt, apiKey: apiKey, model: model ?? "deepseek-v4-flash", progressHandler: progressHandler)
        case .ollama:
            throw RemoteAIError.invalidProvider("Ollama should use OllamaService")
        }
        return try validateEnrichedText(result, original: text, mode: taggingMode)
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

    /// Vérifie une clé DeepSeek sans lancer un enrichissement facturé.
    func testDeepSeekConnection(apiKey: String) async -> Bool {
        guard let url = URL(string: "https://api.deepseek.com/models") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            logger.error("DeepSeek connection test failed: \(error.localizedDescription)")
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
        prompt: String,
        apiKey: String,
        model: String,
        progressHandler: ((String) -> Void)?
    ) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw RemoteAIError.invalidURL
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "Tu es un directeur artistique spécialisé dans la narration d'audiobooks."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 8192,
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

        if firstChoice["finish_reason"] as? String == "length" {
            throw RemoteAIError.truncatedResponse
        }
        
        logger.info("OpenAI enrichment completed successfully")
        return content
    }
    
    // MARK: - Anthropic
    
    private func enrichWithAnthropic(
        prompt: String,
        apiKey: String,
        model: String,
        progressHandler: ((String) -> Void)?
    ) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw RemoteAIError.invalidURL
        }
        
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
        prompt: String,
        apiKey: String,
        model: String,
        progressHandler: ((String) -> Void)?
    ) async throws -> String {
        guard let url = URL(string: "https://api.deepseek.com/chat/completions") else {
            throw RemoteAIError.invalidURL
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "Tu es un directeur artistique spécialisé dans la narration d'audiobooks."],
                ["role": "user", "content": prompt]
            ],
            // L'analyse est déjà explicitement structurée en deux passes. Pour
            // chacune, une réponse directe et déterministe est préférable.
            "thinking": ["type": "disabled"],
            "temperature": 0.3,
            "max_tokens": 8192,
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

        if firstChoice["finish_reason"] as? String == "length" {
            throw RemoteAIError.truncatedResponse
        }
        
        let cleaned = cleanModelOutput(content)
        guard !cleaned.isEmpty else { throw RemoteAIError.emptyResponse }
        logger.info("DeepSeek enrichment completed successfully with model \(model)")
        return cleaned
    }
    
    // MARK: - Helpers
    
    private func buildAnalysisPrompt(text: String, title: String) -> String {
        """
        Lis le chapitre entier avant de répondre. Analyse sa mise en scène pour préparer
        une narration audio cohérente. Tiens compte des paragraphes précédents et suivants,
        des transitions, du ton général, du style littéraire, du point de vue, des dialogues,
        des personnages et de la progression émotionnelle.

        Retourne UNIQUEMENT un objet JSON valide avec exactement ces clés de chaîne :
        {
          "overallTone": "ton dominant et nuances",
          "literaryStyle": "registre, syntaxe, degré de sobriété",
          "narrativeVoice": "point de vue et distance du narrateur",
          "pacing": "rythme global et principales transitions",
          "emotionalArc": "progression émotionnelle du début à la fin",
          "characterDynamics": "personnages présents et rapports émotionnels",
          "dialogueGuidance": "différenciation sobre des dialogues",
          "restraintNotes": "passages à ne pas surjouer et risques de contresens"
        }

        N'invente aucun fait absent du texte. Chaque valeur doit rester concise.

        Titre : \(title)

        Chapitre complet :
        \(text)
        """
    }

    private func buildPrompt(
        text: String,
        taggingMode: TaggingMode,
        densityInstruction: String,
        artDirection: ChapterArtDirection?
    ) -> String {
        let formatRules: String
        switch taggingMode {
        case .none:
            return text
        case .fishS2:
            formatRules = """
            Insère uniquement ces marqueurs Fish S2 officiels entre crochets :
            [happy], [sad], [angry], [excited], [calm], [nervous], [scared], [worried],
            [surprised], [hopeful], [determined], [mysterious], [in a hurry tone],
            [shouting], [whispering], [soft tone], [laughing], [chuckling], [sighing],
            [gasping], [break], [long-break].
            Place le marqueur au début de la phrase concernée.
            Utilise une émotion principale par phrase et au maximum deux marqueurs compatibles.
            Espace les changements émotionnels et évite les effets sonores sauf s'ils sont
            clairement justifiés par le texte.
            """
        case .qwen3TTS:
            formatRules = """
            Insère des instructions Qwen3-TTS au format exact [[qwen:instruction en français]].
            Place chaque instruction avant un segment cohérent de 1 à 3 phrases. Elle s'applique
            à tout ce segment jusqu'à la prochaine instruction.
            Décris uniquement le jeu vocal momentané : émotion, intensité, volume ou rythme.
            Ne redéfinis jamais le timbre, l'âge, le genre, l'accent ou l'identité de la voix.
            Utilise 10 mots maximum et un ou deux attributs compatibles, par exemple
            [[qwen:Inquiet, voix basse et retenue]].
            Préfère des consignes sobres et naturelles. N'impose un débit rapide ou lent que
            lorsque le texte le justifie explicitement.
            Ne demande jamais de bruitage, de parole ajoutée, de cri ajouté ou de modification
            du texte original.
            N'utilise aucune balise Fish et aucun autre format.
            """
        }

        let direction = artDirection?.promptContext ?? "Aucune fiche préalable disponible."
        return """
        Tu es un directeur artistique spécialisé dans la narration d'audiobooks.
        Tu reçois un chapitre complet en français et sa fiche de direction artistique.
        Ta tâche est d'ajouter des indications expressives aux endroits précis où elles améliorent la narration.

        FICHE DE DIRECTION ARTISTIQUE :
        \(direction)

        Règles strictes :
        - Lis le chapitre entier et utilise les paragraphes précédents et suivants pour chaque choix
        - Respecte le ton général, le style littéraire, le point de vue et l'arc émotionnel de la fiche
        - Préserve les contrastes : ne transforme pas une tension progressive en urgence permanente
        - Différencie les dialogues avec sobriété sans caricaturer les personnages
        - Ne modifie JAMAIS le texte original, les mots, la ponctuation ou l'orthographe
        - \(formatRules)
        - DENSITÉ DEMANDÉE : \(densityInstruction)
        - Retourne uniquement le texte enrichi, sans commentaires ni explications

        Texte à enrichir :
        \(text)
        """
    }

    private func decodeArtDirection(_ content: String) throws -> ChapterArtDirection {
        let cleaned = cleanModelOutput(content)
        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              start <= end,
              let data = String(cleaned[start...end]).data(using: .utf8) else {
            throw RemoteAIError.invalidArtDirection
        }
        do {
            return try JSONDecoder().decode(ChapterArtDirection.self, from: data)
        } catch {
            logger.error("Invalid art direction JSON: \(error.localizedDescription)")
            throw RemoteAIError.invalidArtDirection
        }
    }

    private func cleanModelOutput(_ content: String) -> String {
        var result = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```"), result.hasSuffix("```") {
            result = result.replacingOccurrences(
                of: "^```(?:text|txt)?\\s*|\\s*```$",
                with: "",
                options: .regularExpression
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validateEnrichedText(
        _ content: String,
        original: String,
        mode: TaggingMode
    ) throws -> String {
        let cleaned = cleanModelOutput(content)
        guard !cleaned.isEmpty else { throw RemoteAIError.emptyResponse }

        switch mode {
        case .none:
            return original
        case .fishS2:
            let pattern = "\\[([^\\]\\n]{1,40})\\]"
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                throw RemoteAIError.invalidResponse
            }
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            let allowed = Set(Self.fishS2Markers.map { $0.lowercased() })
            let invalid = regex.matches(in: cleaned, range: range).compactMap { match -> String? in
                guard let valueRange = Range(match.range(at: 1), in: cleaned) else { return nil }
                let value = String(cleaned[valueRange]).lowercased()
                return allowed.contains(value) ? nil : value
            }
            guard invalid.isEmpty else {
                throw RemoteAIError.invalidMarkers(invalid)
            }

            let matches = regex.matches(in: cleaned, range: range)
            let withoutMarkers = regex.stringByReplacingMatches(
                in: cleaned,
                range: range,
                withTemplate: ""
            )
            return try validatedOrReconstructedText(
                cleaned: cleaned,
                withoutMarkers: withoutMarkers,
                original: original,
                matches: matches
            )
        case .qwen3TTS:
            let pattern = "\\[\\[qwen:(.*?)\\]\\]"
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else {
                throw RemoteAIError.invalidResponse
            }
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            let instructions = regex.matches(in: cleaned, range: range).compactMap { match -> String? in
                guard let valueRange = Range(match.range(at: 1), in: cleaned) else { return nil }
                return String(cleaned[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let invalid = instructions.filter {
                $0.isEmpty || $0.split(whereSeparator: \.isWhitespace).count > 16
            }
            guard invalid.isEmpty else {
                throw RemoteAIError.invalidMarkers(invalid)
            }

            let matches = regex.matches(in: cleaned, range: range)
            let withoutMarkers = regex.stringByReplacingMatches(
                in: cleaned,
                range: range,
                withTemplate: ""
            )
            return try validatedOrReconstructedText(
                cleaned: cleaned,
                withoutMarkers: withoutMarkers,
                original: original,
                matches: matches
            )
        }
    }

    private func validatedOrReconstructedText(
        cleaned: String,
        withoutMarkers: String,
        original: String,
        matches: [NSTextCheckingResult]
    ) throws -> String {
        if withoutMarkers == original {
            return cleaned
        }

        // Les LLM normalisent parfois les guillemets, apostrophes, tirets,
        // espaces insécables ou retours de paragraphe malgré la consigne.
        // Si la suite exacte des lettres et chiffres reste identique, on jette
        // leur copie du texte et on replace seulement les marqueurs dans
        // l'original. Une vraie modification lexicale reste refusée.
        guard lexicalSignature(withoutMarkers) == lexicalSignature(original) else {
            logger.error("Enriched text changed lexical content; refusing automatic reconstruction")
            throw RemoteAIError.originalTextModified
        }

        let placements = matches.compactMap { match -> (offset: Int, marker: String)? in
            guard let markerRange = Range(match.range, in: cleaned) else { return nil }
            let prefix = String(cleaned[..<markerRange.lowerBound])
                .replacingOccurrences(
                    of: "\\[\\[qwen:.*?\\]\\]|\\[[^\\]\\n]{1,40}\\]",
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
            return (
                lexicalOffset(in: prefix),
                String(cleaned[markerRange])
            )
        }

        let positionedMarkers = placements.map {
            (
                characterOffset: insertionCharacterOffset(in: original, lexicalOffset: $0.offset),
                marker: $0.marker
            )
        }
        var reconstructed = original
        for placement in positionedMarkers.reversed() {
            let index = reconstructed.index(
                reconstructed.startIndex,
                offsetBy: placement.characterOffset
            )
            let suffix = reconstructed[index...]
            let separator = suffix.first?.isWhitespace == true ? "" : " "
            reconstructed.insert(contentsOf: placement.marker + separator, at: index)
        }
        logger.warning("DeepSeek typography normalized; markers projected back onto exact original text")
        return reconstructed
    }

    private func lexicalSignature(_ text: String) -> String {
        String(text.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        })
    }

    private func lexicalOffset(in text: String) -> Int {
        text.unicodeScalars.reduce(0) {
            $0 + (CharacterSet.alphanumerics.contains($1) ? 1 : 0)
        }
    }

    private func insertionCharacterOffset(in text: String, lexicalOffset target: Int) -> Int {
        var count = 0
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let lexicalCount = character.unicodeScalars.reduce(0) {
                $0 + (CharacterSet.alphanumerics.contains($1) ? 1 : 0)
            }
            if lexicalCount > 0 && count >= target {
                return text.distance(from: text.startIndex, to: index)
            }
            count += lexicalCount
            index = text.index(after: index)
        }
        return text.count
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
    case emptyResponse
    case truncatedResponse
    case originalTextModified
    case invalidMarkers([String])
    case invalidArtDirection
    
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
        case .emptyResponse:
            return "L'API a retourné une réponse vide"
        case .truncatedResponse:
            return "La réponse de l'API a été tronquée avant la fin du chapitre"
        case .originalTextModified:
            return "L'API a modifié le texte original au lieu d'ajouter uniquement des balises"
        case .invalidMarkers(let markers):
            return "L'API a produit des balises invalides : \(markers.joined(separator: ", "))"
        case .invalidArtDirection:
            return "L'API n'a pas produit une fiche de direction artistique JSON valide"
        }
    }
}
