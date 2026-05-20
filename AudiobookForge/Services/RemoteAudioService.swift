import Foundation

// MARK: - Fish.Audio Voice Model

/// Échantillon audio d'une voix Fish.Audio (extrait court hébergé sur fish.audio).
/// On garde uniquement l'URL audio + un titre/transcript éventuels.
struct FishAudioSample: Codable, Hashable {
    let audio: String
    let title: String?
    let text: String?
}

/// Représente un modèle de voix Fish.Audio tel que retourné par GET /model.
/// La réponse réelle de l'API contient `_id`, `title`, `description`, `tags`,
/// `languages` (tableau), `samples` ; il n'y a PAS de champs `gender` / `style`
/// natifs — on les dérive depuis les tags pour l'affichage.
struct FishAudioVoice: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let languages: [String]
    let tags: [String]
    let samples: [FishAudioSample]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name = "title"
        case description
        case languages
        case tags
        case samples
    }

    /// URL d'aperçu (premier échantillon disponible) pour le mini-player de la liste.
    var previewURL: URL? {
        guard let raw = samples?.first?.audio, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    /// Première langue disponible (pour l'affichage / le filtrage)
    var language: String {
        languages.first?.uppercased() ?? "—"
    }

    /// Genre déduit des tags (la plupart des modèles Fish.Audio sont taggués)
    var gender: String {
        let lowercased = tags.map { $0.lowercased() }
        if lowercased.contains(where: { $0.contains("female") || $0.contains("féminin") || $0 == "f" }) {
            return "Female"
        }
        if lowercased.contains(where: { $0.contains("male") || $0.contains("masculin") || $0 == "m" }) {
            return "Male"
        }
        return "—"
    }

    /// Style déduit des tags (narration, conversation, etc.)
    var style: String? {
        let stylish = tags.first { tag in
            let t = tag.lowercased()
            return t.contains("narrat") || t.contains("convers") || t.contains("profession") ||
                   t.contains("warm") || t.contains("calm") || t.contains("happy") ||
                   t.contains("sad") || t.contains("angry") || t.contains("excited")
        }
        return stylish
    }
}

/// Réponse paginée de GET /model
private struct FishAudioModelListResponse: Decodable {
    let total: Int
    let items: [FishAudioVoice]
}

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
        
        // Utiliser le reference_id sauvegardé
        if let refId = referenceId {
            logger.info("Using saved reference ID: \(refId)")
            body["reference_id"] = refId
        } else {
            // Si pas de reference_id, on doit en créer un d'abord
            logger.error("No reference_id provided. Zero-shot cloning requires MessagePack, not JSON.")
            throw RemoteAudioError.missingReference
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            // Mapper les erreurs réseau classiques sur des messages français clairs
            // pour que l'utilisateur sache si c'est SA connexion ou le serveur Fish.
            switch urlError.code {
            case .notConnectedToInternet:
                throw RemoteAudioError.networkUnavailable("Pas de connexion internet")
            case .networkConnectionLost:
                throw RemoteAudioError.networkUnavailable("Connexion internet perdue pendant la requête")
            case .timedOut:
                throw RemoteAudioError.networkUnavailable("La requête Fish.Audio a expiré (timeout)")
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                throw RemoteAudioError.networkUnavailable("Impossible de joindre api.fish.audio")
            default:
                throw RemoteAudioError.networkUnavailable("Erreur réseau : \(urlError.localizedDescription)")
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteAudioError.invalidResponse
        }

        // 429 : rate limit. On lit Retry-After (secondes) si fourni et on remonte l'info
        // au caller pour qu'il puisse attendre intelligemment au lieu de retry instantané.
        if httpResponse.statusCode == 429 {
            let retryAfter = (httpResponse.value(forHTTPHeaderField: "Retry-After")
                              ?? httpResponse.value(forHTTPHeaderField: "retry-after"))
                .flatMap { Double($0) }
            let body = String(data: data, encoding: .utf8) ?? "—"
            logger.warning("Fish.Audio rate-limited (429), Retry-After=\(retryAfter ?? -1)s : \(body.prefix(200))")
            throw RemoteAudioError.rateLimited(retryAfter: retryAfter)
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Fish.Audio API error (\(httpResponse.statusCode)): \(errorMessage)")
            throw RemoteAudioError.apiError(httpResponse.statusCode, errorMessage)
        }

        logger.info("Fish.Audio generation completed successfully (\(data.count) bytes)")
        return data
    }
    
    /// Crée une voix sauvegardée sur Fish.Audio.
    /// L'API publique JSON ne supporte plus `/v1/references/add` (404). Pour créer une
    /// référence personnelle il faut passer par /model en MessagePack avec l'audio binaire
    /// — non implémenté côté Swift. On lève donc une erreur explicite pour éviter de faire
    /// croire à l'utilisateur qu'il peut créer une voix personnelle depuis l'app.
    func createReference(
        id: String,
        audio: Data,
        text: String,
        apiKey: String
    ) async throws {
        logger.error("createReference: endpoint /v1/references/add indisponible (404).")
        logger.error("→ Utilisez une voix publique via GET /model ou créez le modèle sur fish.audio.")
        throw RemoteAudioError.referenceCreationUnsupported
    }
    
    /// Teste la validité d'une clé API en interrogeant l'endpoint /model (lecture, gratuit).
    /// On évite /v1/tts qui facture la requête et exige un reference_id.
    func testConnection(apiKey: String) async -> Bool {
        logger.info("🔍 Testing Fish.Audio connection via GET /model...")

        guard var components = URLComponents(string: "https://api.fish.audio/model") else {
            return false
        }
        components.queryItems = [
            URLQueryItem(name: "page_size", value: "1"),
            URLQueryItem(name: "page_number", value: "1")
        ]
        guard let url = components.url else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            let success = httpResponse.statusCode == 200
            logger.info(success
                ? "✅ Fish.Audio connection successful (status 200)"
                : "❌ Fish.Audio connection failed (status \(httpResponse.statusCode))")
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
    
    /// Récupère la liste des voix Fish.Audio via GET /model.
    /// - Parameters:
    ///   - apiKey: clé API Bearer.
    ///   - language: code ISO (`fr`, `en`, `zh`, …). `nil` = pas de filtre côté API
    ///     (renvoie le top mondial, majoritairement zh/en).
    ///   - includeOwn: si vrai, ajoute aussi les modèles privés/publics de l'utilisateur
    ///     (`self=true`). Utile pour récupérer une voix clonée manuellement sur fish.audio.
    /// Les voix sont dédupliquées par `_id`.
    func fetchAvailableVoices(
        apiKey: String,
        language: String? = nil,
        includeOwn: Bool = false
    ) async throws -> [FishAudioVoice] {
        logger.info("Loading Fish.Audio voices (lang=\(language ?? "toutes"), includeOwn=\(includeOwn))...")

        // 1) Voix publiques — avec ou sans filtre langue
        var publicQuery: [URLQueryItem] = [URLQueryItem(name: "visibility", value: "public")]
        if let language, !language.isEmpty {
            publicQuery.append(URLQueryItem(name: "language", value: language))
        }
        let publicVoices = try await fetchModelPage(apiKey: apiKey, extraQuery: publicQuery)

        // 2) Voix personnelles de l'utilisateur — toujours sans filtre langue
        //    (l'utilisateur veut voir ses voix même si la langue ne correspond pas exactement)
        var ownVoices: [FishAudioVoice] = []
        if includeOwn {
            ownVoices = try await fetchModelPage(
                apiKey: apiKey,
                extraQuery: [URLQueryItem(name: "self", value: "true")]
            )
        }

        // Fusion + dédoublonnage (own d'abord pour les mettre en tête).
        var seen = Set<String>()
        var merged: [FishAudioVoice] = []
        for voice in ownVoices + publicVoices where seen.insert(voice.id).inserted {
            merged.append(voice)
        }

        logger.info("✅ Loaded \(merged.count) voices (\(ownVoices.count) perso + \(publicVoices.count) publiques, dédoublonnées)")
        return merged
    }

    /// Appelle GET /model avec pagination jusqu'à 200 modèles, en injectant des query items spécifiques.
    private func fetchModelPage(
        apiKey: String,
        extraQuery: [URLQueryItem]
    ) async throws -> [FishAudioVoice] {
        let pageSize = 100
        let maxPages = 2
        var result: [FishAudioVoice] = []

        for page in 1...maxPages {
            guard var components = URLComponents(string: "https://api.fish.audio/model") else {
                throw RemoteAudioError.invalidURL
            }
            var items: [URLQueryItem] = [
                URLQueryItem(name: "page_size", value: "\(pageSize)"),
                URLQueryItem(name: "page_number", value: "\(page)"),
                URLQueryItem(name: "type", value: "tts"),
                URLQueryItem(name: "sort_by", value: "task_count")
            ]
            items.append(contentsOf: extraQuery)
            components.queryItems = items

            guard let url = components.url else {
                throw RemoteAudioError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RemoteAudioError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "—"
                logger.error("Fish.Audio /model error (\(httpResponse.statusCode)): \(body)")
                throw RemoteAudioError.apiError(httpResponse.statusCode, body)
            }

            let decoded = try JSONDecoder().decode(FishAudioModelListResponse.self, from: data)
            result.append(contentsOf: decoded.items)

            if decoded.items.count < pageSize { break }
            if result.count >= decoded.total { break }
        }

        return result
    }
}

// MARK: - Errors

enum RemoteAudioError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case missingReference
    case apiError(Int, String)
    case missingAPIKey
    case referenceCreationUnsupported
    case rateLimited(retryAfter: Double?)
    case networkUnavailable(String)

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
        case .referenceCreationUnsupported:
            return "Création de voix sauvegardée non supportée depuis l'app (créez le modèle sur fish.audio puis sélectionnez-le dans la liste)."
        case .rateLimited(let retryAfter):
            if let s = retryAfter {
                return "Fish.Audio : limite de requêtes atteinte. Réessayer dans \(Int(s)) s."
            }
            return "Fish.Audio : limite de requêtes atteinte (429). Patientez quelques instants."
        case .networkUnavailable(let reason):
            return "Réseau : \(reason). La génération s'est arrêtée — les chunks déjà générés sont conservés et reprendront au prochain lancement."
        }
    }
}
