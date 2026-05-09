import Foundation

/// Service d'intégration avec Ollama pour l'injection de balises émotionnelles
class OllamaService {
    static let shared = OllamaService()

    private let baseURL = "http://localhost:11434"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes max par chapitre
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }

    /// Vérifie si Ollama est accessible et si le modèle est disponible
    func checkAvailability() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let models = json?["models"] as? [[String: Any]] {
                return models.contains { ($0["name"] as? String)?.hasPrefix("qwen3") ?? false }
            }
            return false
        } catch {
            return false
        }
    }

    /// Envoie un chapitre à Ollama pour injection de balises
    /// - Parameters:
    ///   - chapterText: Le texte brut du chapitre
    ///   - progressHandler: Callback pour la progression (streaming)
    /// - Returns: Le texte enrichi avec les balises
    func injectTags(
        chapterText: String,
        progressHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        let prompt = """
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
        \(chapterText)
        """

        let body: [String: Any] = [
            "model": "qwen3:30b",
            "prompt": prompt,
            "temperature": 0.3,
            "top_p": 0.9,
            "stream": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.requestFailed
        }

        var resultText = ""

        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let response = json["response"] as? String {
                resultText += response
                progressHandler?(response)
            }

            if json["done"] as? Bool == true {
                break
            }
        }

        return resultText
    }

    /// Traite tous les chapitres avec barre de progression
    func processAllChapters(
        chapters: [Chapter],
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws -> [Chapter] {
        var updatedChapters = chapters

        for (index, chapter) in chapters.enumerated() {
            guard !chapter.rawText.isEmpty else { continue }

            let taggedText = try await injectTags(chapterText: chapter.rawText)

            updatedChapters[index].taggedText = taggedText
            updatedChapters[index].status = .tagged

            await MainActor.run {
                progressHandler(index + 1, chapters.count)
            }
        }

        return updatedChapters
    }
}

// MARK: - Errors

enum OllamaError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case modelNotAvailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL Ollama invalide"
        case .requestFailed:
            return "La requête à Ollama a échoué"
        case .modelNotAvailable:
            return "Le modèle Qwen3 n'est pas disponible"
        case .timeout:
            return "La requête a expiré"
        }
    }
}
