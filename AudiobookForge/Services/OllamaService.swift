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
                // Chercher qwen2.5 ou qwen3
                return models.contains { 
                    if let name = $0["name"] as? String {
                        return name.hasPrefix("qwen2.5") || name.hasPrefix("qwen3")
                    }
                    return false
                }
            }
            return false
        } catch {
            return false
        }
    }

    /// Envoie un chapitre à Ollama pour injection de balises
    func analyzeChapter(chapterText: String, title: String) async throws -> ChapterArtDirection {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }
        let prompt = """
        Lis le chapitre entier avant de répondre. Analyse sa mise en scène pour une narration
        audio cohérente : paragraphes précédents et suivants, ton général, style littéraire,
        point de vue, rythme, dialogues, personnages et progression émotionnelle.

        Retourne UNIQUEMENT un objet JSON valide avec exactement ces clés :
        "overallTone", "literaryStyle", "narrativeVoice", "pacing", "emotionalArc",
        "characterDynamics", "dialogueGuidance", "restraintNotes".
        Toutes les valeurs sont des chaînes concises. N'invente aucun fait.

        Titre : \(title)
        Chapitre complet :
        \(chapterText)
        """
        let body: [String: Any] = [
            "model": "qwen2.5:7b",
            "prompt": prompt,
            "format": "json",
            "temperature": 0.2,
            "stream": false,
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["response"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw OllamaError.requestFailed
        }
        do {
            return try JSONDecoder().decode(ChapterArtDirection.self, from: contentData)
        } catch {
            throw OllamaError.invalidArtDirection
        }
    }

    /// - Parameters:
    ///   - chapterText: Le texte brut du chapitre
    ///   - densityInstruction: consigne de densité de balises (voir AIConfig.tagDensityInstruction)
    ///   - progressHandler: Callback pour la progression (streaming)
    /// - Returns: Le texte enrichi avec les balises
    func injectTags(
        chapterText: String,
        taggingMode: TaggingMode = .fishS2,
        densityInstruction: String = "balisage MODÉRÉ : environ 1 balise toutes les 3-4 phrases en moyenne",
        artDirection: ChapterArtDirection? = nil,
        progressHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        guard taggingMode.usesAI else { return chapterText }
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        let formatRules: String
        switch taggingMode {
        case .none:
            return chapterText
        case .fishS2:
            formatRules = """
            Insère uniquement ces marqueurs Fish S2 officiels entre crochets :
            [happy], [sad], [angry], [excited], [calm], [nervous], [scared], [worried],
            [surprised], [hopeful], [determined], [mysterious], [in a hurry tone],
            [shouting], [whispering], [soft tone], [laughing], [chuckling], [sighing],
            [gasping], [break], [long-break].
            Place-les au début des phrases, avec une émotion principale par phrase et au
            maximum deux marqueurs compatibles.
            """
        case .qwen3TTS:
            formatRules = """
            Insère des instructions au format exact [[qwen:instruction en français]] avant un
            segment cohérent de 1 à 3 phrases. Chaque instruction s'applique à tout ce segment.
            Décris uniquement le jeu vocal momentané, sans modifier le timbre, l'âge, le genre,
            l'accent ou l'identité de la voix. Utilise 10 mots maximum et un ou deux attributs,
            par exemple : [[qwen:Inquiet, voix basse et retenue]].
            Ne demande jamais de bruitage, de parole ajoutée, de cri ajouté ou de modification
            du texte. N'utilise aucune balise Fish.
            """
        }

        let direction = artDirection?.promptContext ?? "Aucune fiche préalable disponible."
        let prompt = """
        Tu es un directeur artistique spécialisé dans la narration d'audiobooks.
        Tu reçois un chapitre complet et sa fiche de direction artistique.
        Ta tâche est d'ajouter des indications expressives directement dans le texte.

        FICHE DE DIRECTION ARTISTIQUE :
        \(direction)

        Règles strictes :
        - Utilise les paragraphes précédents et suivants pour chaque choix
        - Respecte le ton, le style, le point de vue et l'arc émotionnel de la fiche
        - Préserve les progressions et différencie les dialogues sans caricature
        - Ne modifie JAMAIS le texte original, les mots, la ponctuation ou l'orthographe
        - \(formatRules)
        - DENSITÉ DEMANDÉE : \(densityInstruction)
        - Retourne uniquement le texte enrichi, sans commentaires ni explications

        Texte à enrichir :
        \(chapterText)
        """

        let body: [String: Any] = [
            "model": "qwen2.5:7b",  // Utiliser le modèle installé
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
    case invalidArtDirection

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
        case .invalidArtDirection:
            return "Ollama n'a pas produit une fiche de direction artistique JSON valide"
        }
    }
}
