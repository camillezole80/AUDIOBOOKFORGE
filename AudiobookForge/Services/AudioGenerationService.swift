import Foundation

/// Service de génération audio via mlx-speech (Fish Audio S2 Pro) ou Fish.Audio API
class AudioGenerationService {
    static let shared = AudioGenerationService()

    private let pathResolver = PathResolver.shared
    private let logger = Logger.shared
    private let remoteAudioService = RemoteAudioService.shared
    private let keychain = KeychainHelper.shared

    private init() {
        logger.info("AudioGenerationService initialized")
    }

    /// Normalise un fragment de texte avant l'envoi au moteur TTS :
    /// - collapse tous les espaces et sauts de ligne en un espace unique,
    /// - trim,
    /// - retire les ZWSP et autres caractères invisibles courants.
    /// Sans ça, Fish.Audio reçoit parfois `"…\n\n"` ou `". —"` et synthétise un
    /// glissando "Fooooo" (note par défaut quand il manque de phonèmes).
    static func sanitizeForTTS(_ text: String) -> String {
        let zeroWidth = ["\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}"]
        var cleaned = text
        for zw in zeroWidth { cleaned = cleaned.replacingOccurrences(of: zw, with: "") }
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Le chunk contient-il assez de matière lexicale pour valoir une synthèse TTS ?
    /// On exige au moins 3 lettres unicode — élimine `"…"`, `". —"`, `"« »"`, etc.
    static func hasReadableContent(_ text: String, minLetters: Int = 3) -> Bool {
        var count = 0
        for scalar in text.unicodeScalars where CharacterSet.letters.contains(scalar) {
            count += 1
            if count >= minLetters { return true }
        }
        return false
    }

    /// Découpe le texte en chunks de maximum 200 mots
    /// Préserve la ponctuation originale en utilisant une regex pour détecter les fins de phrase.
    /// Les chunks vides ou réduits à de la ponctuation sont éliminés en post-traitement.
    func chunkText(_ text: String, maxWords: Int = 200) -> [String] {
        return chunkPlainText(text, maxWords: maxWords)
    }

    private func chunkPlainText(_ text: String, maxWords: Int) -> [String] {
        // Utiliser une regex pour capturer les phrases avec leur ponctuation
        let pattern = "(?:(?!([.!?…]\\s|\\n))[^.!?…\\n])+[.!?…]?"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex?.matches(in: text, options: [], range: nsRange) ?? []

        let sentences: [String] = matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return sentence.isEmpty ? nil : sentence
        }

        // Fallback si la regex ne trouve rien
        let finalSentences = sentences.isEmpty ?
            [text.trimmingCharacters(in: .whitespacesAndNewlines)] : sentences

        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentWordCount = 0

        for sentence in finalSentences {
            let words = sentence.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let wordCount = words.count

            if currentWordCount + wordCount > maxWords && !currentChunk.isEmpty {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = [sentence]
                currentWordCount = wordCount
            } else {
                currentChunk.append(sentence)
                currentWordCount += wordCount
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }

        // Sanitize + filtre des chunks "garbage" qui font hallucinier Fish.Audio.
        return chunks
            .map(Self.sanitizeForTTS)
            .filter { Self.hasReadableContent($0) }
    }

    /// Supprime les balises émotionnelles type `[whispering]`, `[excited]`, `[break]`, etc.
    /// utilisées pour Fish S2-Pro. Sans ce filtrage, Chatterbox/Qwen3 prononceraient
    /// ces marqueurs comme du texte ou hallucineraient.
    static func stripEmotionalTags(_ text: String) -> String {
        let pattern = "\\[[^\\]\\n]{1,40}\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let stripped = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        // Collapse les doubles espaces générés par la suppression
        return stripped
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: " ,", with: ",")
            .replacingOccurrences(of: " .", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extrait les annotations internes `[[qwen:...]]`.
    /// Elles ne doivent jamais être prononcées : le texte nettoyé part au TTS et
    /// les instructions sont transmises séparément aux variantes Qwen compatibles.
    static func extractQwenInstructions(from text: String) -> (text: String, instruction: String?) {
        let segments = extractQwenInstructionSegments(from: text)
        let cleanedText = Self.sanitizeForTTS(
            segments.map(\.text).joined(separator: " ")
        )
        let directions = segments.compactMap { segment -> String? in
            guard let instruction = segment.instruction,
                  Self.hasReadableContent(segment.text) else {
                return nil
            }
            let anchor = segment.text
                .split(whereSeparator: \.isWhitespace)
                .prefix(7)
                .joined(separator: " ")
            return "Au passage commençant par « \(anchor) » : \(instruction)"
        }
        guard !directions.isEmpty else {
            return (cleanedText, nil)
        }

        let performancePlan = """
        Conserver exactement le même locuteur, le même timbre, la même hauteur de voix, \
        le même âge vocal et le même accent pendant tout le passage. Lire le texte en une \
        seule prise continue. Faire varier uniquement l'émotion, l'intensité et le rythme, \
        avec des transitions progressives et naturelles. \(directions.joined(separator: ". ")).
        """
        return (cleanedText, Self.sanitizeForTTS(performancePlan))
    }

    /// Découpe un texte balisé Qwen en segments parlés. Chaque instruction
    /// `[[qwen:...]]` s'applique au texte qui la suit, jusqu'à la suivante.
    static func extractQwenInstructionSegments(
        from text: String
    ) -> [(text: String, instruction: String?)] {
        let pattern = "\\[\\[qwen:(.*?)\\]\\]"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return [(Self.sanitizeForTTS(text), nil)]
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else {
            return [(Self.sanitizeForTTS(text), nil)]
        }

        var segments: [(text: String, instruction: String?)] = []
        var cursor = text.startIndex
        var activeInstruction: String?

        for match in matches {
            guard let markerRange = Range(match.range, in: text) else { continue }
            let spokenText = Self.sanitizeForTTS(String(text[cursor..<markerRange.lowerBound]))
            if Self.hasReadableContent(spokenText) {
                segments.append((spokenText, activeInstruction))
            }

            if match.numberOfRanges > 1,
               let instructionRange = Range(match.range(at: 1), in: text) {
                let instruction = String(text[instructionRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                activeInstruction = instruction.isEmpty ? nil : instruction
            }
            cursor = markerRange.upperBound
        }

        let trailingText = Self.sanitizeForTTS(String(text[cursor...]))
        if Self.hasReadableContent(trailingText) {
            segments.append((trailingText, activeInstruction))
        }
        return segments
    }

    /// Texte à envoyer au moteur TTS pour la config voiceConfig donnée.
    /// Si le provider/modèle ne supporte pas les balises, on les retire.
    func textForEngine(_ text: String, voiceConfig: VoiceConfig) -> String {
        let providerSupports = voiceConfig.preferredProvider.supportsEmotionalTags
        let modelSupports: Bool = {
            switch voiceConfig.preferredProvider {
            case .fishAudio, .mlxFishS2:
                return true  // Fish-S2 (cloud ou MLX local) supporte nativement
            case .ttsAudiobookTool:
                return voiceConfig.ttsModel.supportsEmotionalTags
            }
        }()
        return (providerSupports || modelSupports) ? text : Self.stripEmotionalTags(text)
    }

    /// Génère l'audio pour un chunk via le provider configuré.
    func generateChunkAudio(
        text: String,
        referenceAudio: String,
        referenceText: String,
        outputPath: String,
        chunkIndex: Int,
        voiceConfig: VoiceConfig
    ) async throws {
        let qwenAnnotation = Self.extractQwenInstructions(from: text)

        // 1) Strip balises si le moteur cible ne les comprend pas
        let stripped = textForEngine(qwenAnnotation.text, voiceConfig: voiceConfig)
        if stripped.count != text.count {
            logger.debug("Chunk \(chunkIndex): \(text.count - stripped.count) caractères de balises supprimés (moteur incompatible)")
        }

        // 2) Sanitize (collapse whitespace, trim, retire les invisibles)
        let engineText = Self.sanitizeForTTS(stripped)

        // 3) Filet de sécurité : si après stripping le chunk n'a plus de matière lisible,
        //    on refuse de l'envoyer au TTS. Sinon Fish.Audio (et d'autres moteurs)
        //    génèrent un glissando "Fooooo" caractéristique sur du quasi-vide.
        guard Self.hasReadableContent(engineText) else {
            logger.info("Chunk \(chunkIndex) ignoré (texte vide ou non-lisible après nettoyage)")
            throw AudioGenerationError.chunkSkippedEmpty(chunkIndex)
        }

        switch voiceConfig.preferredProvider {
        case .fishAudio:
            try await generateChunkViaFishAudio(
                text: engineText,
                referenceAudio: referenceAudio,
                referenceText: referenceText,
                outputPath: outputPath,
                chunkIndex: chunkIndex,
                voiceConfig: voiceConfig
            )

        case .mlxFishS2:
            try await generateChunkViaMLX(
                text: engineText,
                referenceAudio: referenceAudio,
                referenceText: referenceText,
                outputPath: outputPath,
                chunkIndex: chunkIndex,
                voiceConfig: voiceConfig
            )

        case .ttsAudiobookTool:
            try await generateChunkViaTtsAudiobookTool(
                text: engineText,
                referenceAudio: referenceAudio,
                referenceText: referenceText,
                outputPath: outputPath,
                chunkIndex: chunkIndex,
                voiceConfig: voiceConfig,
                qwenInstruction: qwenAnnotation.instruction
            )
        }
    }

    /// Génère un chunk audio via MLX Fish-S2-Pro INT8 (local, Apple Silicon).
    /// L'alias `"fish-s2-pro"` de mlx-speech mappe vers le repo HuggingFace
    /// `appautomaton/fishaudio-s2-pro-8bit-mlx` (INT8 par défaut).
    ///
    /// Passe par `TTSDaemon` : un seul process Python long-vivant pour tout le
    /// projet (le modèle ~17 Go reste résident entre les chunks au lieu d'être
    /// rechargé à chaque fois).
    private func generateChunkViaMLX(
        text: String,
        referenceAudio: String,
        referenceText: String,
        outputPath: String,
        chunkIndex: Int,
        voiceConfig: VoiceConfig
    ) async throws {
        logger.info("Generating chunk \(chunkIndex) via MLX Fish-S2 INT8 (daemon)…")

        // max_new_tokens=1024 (≈30s d'audio) au lieu de 2048 : un chunk fait
        // 200 mots max, donc 1024 est largement suffisant et divise par 2 la
        // taille du cache KV. Avec 2048, MLX réclamait un buffer Metal de
        // >16 Go qui dépasse la limite hardware (14,3 Go) sur Apple Silicon.
        do {
            try await TTSDaemon.shared.mlxGenerate(
                text: text,
                referenceAudio: referenceAudio,
                referenceText: referenceText,
                output: outputPath,
                maxNewTokens: 1024,
                temperature: voiceConfig.ttsModel == .qwen3 ? -1 : voiceConfig.temperature,
                lengthScale: voiceConfig.speedScale,
                timeoutSeconds: 600
            )
        } catch let err as TTSDaemon.DaemonError {
            // Erreurs de lancement / installation : remontées en ttsToolNotInstalled
            switch err {
            case .launchFailed(let m):
                throw AudioGenerationError.ttsToolNotInstalled(m)
            default:
                throw AudioGenerationError.chunkGenerationFailed(chunkIndex, err.localizedDescription)
            }
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputPath))?[.size] as? Int ?? 0
        guard fileSize > 1024 else {
            throw AudioGenerationError.chunkGenerationFailed(chunkIndex, "fichier MLX trop petit (\(fileSize) o)")
        }
        logger.info("✅ Chunk \(chunkIndex) généré via MLX Fish-S2 (\(fileSize) o)")
    }
    
    /// Génère l'audio via Fish.Audio API
    private func generateChunkViaFishAudio(
        text: String,
        referenceAudio: String,
        referenceText: String,
        outputPath: String,
        chunkIndex: Int,
        voiceConfig: VoiceConfig
    ) async throws {
        logger.info("Generating chunk \(chunkIndex) via Fish.Audio API...")
        
        guard let apiKey = keychain.get(for: .fishAudio) else {
            throw AudioGenerationError.missingAPIKey
        }
        
        // Fish.Audio n'a pas d'endpoint pour créer des références sauvegardées
        // On doit utiliser MessagePack pour envoyer l'audio inline
        // Pour l'instant, on utilise un model ID public ou on lance une erreur
        
        let refId = voiceConfig.fishAudioReferenceId ?? voiceConfig.selectedFishAudioVoice
        
        if refId == nil {
            logger.error("❌ Fish.Audio nécessite soit:")
            logger.error("   1. Un model ID public (sélectionné dans les réglages)")
            logger.error("   2. MessagePack pour zero-shot cloning (non implémenté)")
            throw AudioGenerationError.missingFishAudioReference
        }
        
        logger.info("✅ Utilisation du model Fish.Audio: \(refId!)")
        
        // Appeler l'API avec le reference_id
        let audioData = try await remoteAudioService.generateAudio(
            text: text,
            referenceAudio: nil,
            referenceText: nil,
            referenceId: refId,
            apiKey: apiKey,
            voiceConfig: voiceConfig
        )
        
        // Sauvegarder le WAV
        try audioData.write(to: URL(fileURLWithPath: outputPath))
        
        logger.info("Chunk \(chunkIndex) generated successfully via Fish.Audio API")
    }
    
    /// Génère l'audio via TTS Audiobook Tool en passant par le daemon.
    /// Le modèle (fish-s2 / chatterbox / qwen3) reste chargé entre les chunks.
    private func generateChunkViaTtsAudiobookTool(
        text: String,
        referenceAudio: String,
        referenceText: String,
        outputPath: String,
        chunkIndex: Int,
        voiceConfig: VoiceConfig,
        qwenInstruction: String?
    ) async throws {
        logger.info("Generating chunk \(chunkIndex) via TTS Audiobook Tool (daemon)…")

        let model = voiceConfig.ttsModel.rawValue  // "fish-s2" / "chatterbox" / "qwen3"
        let resolvedInstruction = voiceConfig.ttsModel == .qwen3
            ? voiceConfig.resolvedQwenInstruction(expressiveInstruction: qwenInstruction)
            : nil
        let usesQwen = voiceConfig.ttsModel == .qwen3
        let usesQwenClone = usesQwen && voiceConfig.resolvedQwenVoiceMode == .voiceClone

        do {
            try await TTSDaemon.shared.ttsToolGenerate(
                model: model,
                text: text,
                referenceAudio: usesQwenClone ? voiceConfig.referenceAudioPath : (usesQwen ? "" : referenceAudio),
                referenceText: usesQwenClone ? voiceConfig.referenceTranscription : (usesQwen ? "" : referenceText),
                output: outputPath,
                temperature: voiceConfig.ttsModel == .qwen3 ? -1 : voiceConfig.temperature,
                maxRetries: voiceConfig.maxRetries,
                enableSttValidation: voiceConfig.enableSttValidation,
                topP: voiceConfig.topP,
                topK: voiceConfig.topK,
                seed: voiceConfig.resolvedQwenSeed,
                qwenInstruction: resolvedInstruction,
                qwenModelPath: voiceConfig.ttsModel == .qwen3 ? voiceConfig.resolvedQwenModelPath : nil,
                qwenSpeakerId: voiceConfig.ttsModel == .qwen3
                    && voiceConfig.resolvedQwenVoiceMode == .customVoice
                    ? voiceConfig.resolvedQwenSpeakerId
                    : nil,
                qwenLanguage: voiceConfig.ttsModel == .qwen3 ? voiceConfig.resolvedQwenLanguage : nil,
                timeoutSeconds: 600
            )
        } catch let err as TTSDaemon.DaemonError {
            switch err {
            case .launchFailed(let m):
                throw AudioGenerationError.ttsToolNotInstalled(m)
            default:
                throw AudioGenerationError.chunkGenerationFailed(chunkIndex, err.localizedDescription)
            }
        }

        let fileExists = FileManager.default.fileExists(atPath: outputPath)
        guard fileExists else {
            throw AudioGenerationError.chunkGenerationFailed(chunkIndex, "fichier de sortie absent après génération")
        }

        if usesQwen && abs(voiceConfig.speedScale - 1.0) > 0.001 {
            logger.debug("Applying Qwen speed \(voiceConfig.speedScale)x to chunk \(chunkIndex)…")
            try await AudioSpeedProcessor.apply(speed: voiceConfig.speedScale, to: outputPath)
        }

        // Post-processing optionnel — passe aussi par le daemon (pas de relance Python)
        if voiceConfig.enableNormalization {
            logger.debug("Normalizing chunk \(chunkIndex)…")
            try await TTSDaemon.shared.ttsToolNormalize(input: outputPath, output: outputPath, model: model)
        }

        if voiceConfig.enableUpsampling {
            logger.debug("Upsampling chunk \(chunkIndex)…")
            try await TTSDaemon.shared.ttsToolUpsample(input: outputPath, output: outputPath, model: model)
        }

        logger.info("Chunk \(chunkIndex) generated successfully via TTS Audiobook Tool")
    }
    
    /// Politique de retry centralisée pour un chunk en échec.
    /// - Respecte le `Retry-After` de Fish.Audio sur 429.
    /// - 5xx serveur : backoff exponentiel modéré.
    /// - Erreurs réseau (pas de connexion) : abandon immédiat (l'utilisateur doit agir).
    /// - Erreurs de config (clé API, voix, outil non installé) : abandon immédiat.
    private func retryDecision(for error: Error, attempt: Int, maxAttempts: Int) -> (shouldRetry: Bool, wait: Double) {
        // 1) Erreurs de config — pas de retry
        if let agError = error as? AudioGenerationError {
            switch agError {
            case .missingAPIKey, .missingFishAudioReference, .ttsToolNotInstalled:
                return (false, 0)
            default:
                break
            }
        }

        // 2) Erreurs Fish.Audio spécifiques
        if let remoteError = error as? RemoteAudioError {
            switch remoteError {
            case .rateLimited(let retryAfter):
                // On retente toujours, même si attempt == maxAttempts (le 429 n'est
                // pas notre "faute", c'est juste un délai imposé par le serveur).
                let wait = retryAfter ?? Double(attempt * 3)
                return (true, wait)
            case .networkUnavailable, .missingAPIKey, .missingReference, .referenceCreationUnsupported:
                return (false, 0)
            case .apiError(let code, _) where (500...599).contains(code):
                // 5xx : backoff exponentiel, retry tant qu'on a des tentatives
                return (attempt < maxAttempts, Double(attempt) * 2.0)
            case .apiError(let code, _) where (400...499).contains(code):
                // 4xx (sauf 429 traité plus haut) : erreur client, abandon
                _ = code  // silence "unused"
                return (false, 0)
            default:
                break
            }
        }

        // 3) Cas générique : retry simple avec délai linéaire
        return (attempt < maxAttempts, Double(attempt) * 1.5)
    }

    /// Génère tous les chunks d'un chapitre.
    /// - Réutilise les chunks WAV déjà présents sur disque (reprise après crash).
    /// - Retente chaque chunk jusqu'à `maxChunkAttempts` fois (avec un délai croissant).
    /// - Si TOUS les chunks échouent, propage la *vraie* première erreur, pas un message générique.
    func generateChapterAudio(
        chapter: Chapter,
        projectDir: String,
        voiceConfig: VoiceConfig,
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws -> (chunks: [Chunk], chapterAudioPath: String) {
        let text = chapter.taggedText ?? chapter.rawText
        let chunkTexts = chunkText(text)

        let chunksDir = "\(projectDir)/audio/chunks"
        let chaptersDir = "\(projectDir)/audio/chapters"

        try FileManager.default.createDirectory(atPath: chunksDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: chaptersDir, withIntermediateDirectories: true)

        let maxChunkAttempts = 3
        var chunks: [Chunk] = []
        var firstFailure: Error?

        for (index, chunkText) in chunkTexts.enumerated() {
            let chunkPath = "\(chunksDir)/chunk_\(chapter.index)_\(index).wav"

            var chunk = Chunk(
                index: index,
                chapterIndex: chapter.index,
                text: chunkText,
                status: .pending,
                audioFilePath: chunkPath
            )

            // Reprise : si le fichier est déjà sur disque et non vide, on le réutilise.
            if let attrs = try? FileManager.default.attributesOfItem(atPath: chunkPath),
               let size = attrs[.size] as? Int, size > 1024 {
                chunk.status = .done
                logger.info("⏭️  Chunk \(index) déjà présent sur disque (\(size) o), réutilisé")
                chunks.append(chunk)
                await MainActor.run { progressHandler(index + 1, chunkTexts.count) }
                continue
            }

            // Tentatives successives
            var lastError: Error?
            for attempt in 1...maxChunkAttempts {
                do {
                    try await generateChunkAudio(
                        text: chunkText,
                        referenceAudio: voiceConfig.referenceAudioPath,
                        referenceText: voiceConfig.referenceTranscription,
                        outputPath: chunkPath,
                        chunkIndex: index,
                        voiceConfig: voiceConfig
                    )
                    chunk.status = .done
                    if attempt > 1 {
                        logger.info("✅ Chunk \(index) généré au tentative \(attempt)/\(maxChunkAttempts)")
                    } else {
                        logger.info("✅ Chunk \(index) généré")
                    }
                    break
                } catch AudioGenerationError.chunkSkippedEmpty {
                    logger.info("⏭️  Chunk \(index) sauté (vide après nettoyage)")
                    chunk.status = .done
                    chunk.audioFilePath = nil
                    break
                } catch {
                    lastError = error
                    // Décision : on retente, on attend combien, on abandonne ?
                    let decision = retryDecision(for: error, attempt: attempt, maxAttempts: maxChunkAttempts)
                    logger.error("❌ Chunk \(index) tentative \(attempt)/\(maxChunkAttempts) : \(error.localizedDescription)\(decision.wait > 0 ? " — attente \(Int(decision.wait))s" : "")")
                    if !decision.shouldRetry { break }
                    if decision.wait > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(decision.wait * 1_000_000_000))
                    }
                }
            }

            if chunk.status != .done {
                chunk.status = .error
                chunk.errorMessage = lastError?.localizedDescription
                if firstFailure == nil { firstFailure = lastError }
            }

            chunks.append(chunk)
            await MainActor.run { progressHandler(index + 1, chunkTexts.count) }
        }

        // Bilan
        let chapterAudioPath = "\(chaptersDir)/chapter_\(chapter.index).wav"
        // Un chunk est utilisable pour l'assemblage seulement s'il a un fichier WAV
        // (les chunks "skipped empty" sont marqués done mais sans audioFilePath).
        let validChunks = chunks.filter { $0.status == .done && $0.audioFilePath != nil }
        let errorCount = chunks.filter { $0.status == .error }.count
        let skippedCount = chunks.filter { $0.status == .done && $0.audioFilePath == nil }.count
        logger.info("📊 Chapitre \(chapter.index) : \(validChunks.count) OK, \(skippedCount) sautés, \(errorCount) en erreur")

        if validChunks.isEmpty {
            // ⚠️ Surface la VRAIE cause (ex: voix Fish.Audio non sélectionnée),
            // au lieu du générique "noValidChunks" qui ne dit rien à l'utilisateur.
            if let underlying = firstFailure {
                logger.error("❌ Aucun chunk valide. Cause racine : \(underlying.localizedDescription)")
                throw underlying
            }
            throw AudioGenerationError.noValidChunks
        }

        if errorCount > 0 {
            logger.warning("⚠️ \(errorCount) chunk(s) manquant(s) dans le chapitre \(chapter.index) — audio assemblé partiel")
        }

        try await assembleChunks(chunks: validChunks, outputPath: chapterAudioPath)
        return (chunks, chapterAudioPath)
    }

    /// Assemble les chunks audio en un seul fichier via ffmpeg
    private func assembleChunks(chunks: [Chunk], outputPath: String) async throws {
        guard !chunks.isEmpty else {
            throw AudioGenerationError.noValidChunks
        }

        // Créer le fichier liste ffmpeg (et ne garder que les chunks ayant un fichier sur disque)
        let listPath = "\(outputPath).list"
        var listContent = ""
        var validEntries = 0
        for chunk in chunks.sorted(by: { $0.index < $1.index }) {
            guard let path = chunk.audioFilePath else { continue }
            guard FileManager.default.fileExists(atPath: path) else { continue }
            listContent += "file '\(path)'\n"
            validEntries += 1
        }

        guard validEntries > 0 else {
            throw AudioGenerationError.noValidChunks
        }

        try listContent.write(toFile: listPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: listPath) }

        let tempPath = "\(outputPath).concat.wav"
        try? FileManager.default.removeItem(atPath: tempPath)

        // -loglevel error et -nostdin garantissent que ffmpeg n'écrit presque rien
        // sur stderr et ne lit pas stdin. Combiné avec le draining asynchrone de la
        // pipe, ça élimine le risque de deadlock par pipe pleine.
        let result = try await runFFmpeg(arguments: [
            "-nostdin",
            "-loglevel", "error",
            "-f", "concat",
            "-safe", "0",
            "-i", listPath,
            "-c", "copy",
            "-y",
            tempPath
        ])

        guard result.status == 0 else {
            try? FileManager.default.removeItem(atPath: tempPath)
            logger.error("❌ assembleChunks ffmpeg code \(result.status) : \(result.stderr.suffix(400))")
            throw AudioGenerationError.chunkGenerationFailed(-1, "ffmpeg concat a échoué : \(result.stderr.suffix(200))")
        }

        // Validation taille minimale (1 chunk WAV mono fait au moins ~20 Ko)
        let size = ((try? FileManager.default.attributesOfItem(atPath: tempPath))?[.size] as? Int) ?? 0
        guard size > 1024 else {
            try? FileManager.default.removeItem(atPath: tempPath)
            throw AudioGenerationError.chunkGenerationFailed(-1, "fichier assemblé trop petit (\(size) o)")
        }

        // Swap atomique vers la destination finale
        let src = URL(fileURLWithPath: tempPath)
        let dst = URL(fileURLWithPath: outputPath)
        if FileManager.default.fileExists(atPath: outputPath) {
            _ = try FileManager.default.replaceItemAt(dst, withItemAt: src)
        } else {
            try FileManager.default.moveItem(at: src, to: dst)
        }

        logger.info("✅ assembleChunks: \(validEntries) chunks → \(outputPath) (\(size) o)")
    }

    /// Normalise le volume d'un fichier audio à -1 dBFS.
    /// Échec ffmpeg = on garde l'original intact (jamais de perte).
    func normalizeAudio(filePath: String) async throws {
        logger.debug("Normalizing audio: \(filePath)")

        let tempPath = "\(filePath).normalizing.wav"
        try? FileManager.default.removeItem(atPath: tempPath)

        let result = try await runFFmpeg(arguments: [
            "-nostdin",
            "-loglevel", "error",
            "-i", filePath,
            "-af", "loudnorm=I=-1:LRA=11:TP=-1",
            "-ar", "44100",
            "-sample_fmt", "s24le",
            "-y",
            tempPath
        ])

        guard result.status == 0 else {
            try? FileManager.default.removeItem(atPath: tempPath)
            logger.error("❌ normalizeAudio ffmpeg code \(result.status) : \(result.stderr.suffix(400))")
            throw AudioGenerationError.normalizationFailed("ffmpeg code \(result.status). Le fichier original est préservé.")
        }

        let attrs = (try? FileManager.default.attributesOfItem(atPath: tempPath))
        let size = (attrs?[.size] as? Int) ?? 0
        guard size > 1024 else {
            try? FileManager.default.removeItem(atPath: tempPath)
            logger.error("❌ normalizeAudio : sortie absente/trop petite (\(size) o). Original préservé.")
            throw AudioGenerationError.normalizationFailed("sortie ffmpeg invalide. Le fichier original est préservé.")
        }

        let src = URL(fileURLWithPath: tempPath)
        let dst = URL(fileURLWithPath: filePath)
        _ = try FileManager.default.replaceItemAt(dst, withItemAt: src)

        logger.debug("✅ normalizeAudio: \(filePath) (\(size) o)")
    }

    /// Wrapper ffmpeg sur ProcessRunner (drainage de pipe garanti, voir ProcessRunner.swift).
    private func runFFmpeg(arguments: [String], timeoutSeconds: Double = 300) async throws -> ProcessRunner.Result {
        return try await ProcessRunner.run(
            executable: pathResolver.ffmpegPath,
            arguments: arguments,
            timeoutSeconds: timeoutSeconds
        )
    }

    /// Pour les autres binaires (Python wrappers, etc.) — alias vers ProcessRunner.run.
    private func runProcess(
        executable: String,
        arguments: [String],
        timeoutSeconds: Double = 300,
        stdoutHandler: (@Sendable (Data) -> Void)? = nil
    ) async throws -> ProcessRunner.Result {
        return try await ProcessRunner.run(
            executable: executable,
            arguments: arguments,
            timeoutSeconds: timeoutSeconds,
            stdoutHandler: stdoutHandler
        )
    }

    /// Génère un preview de 30 secondes
    func generatePreview(
        text: String,
        voiceConfig: VoiceConfig,
        outputPath: String
    ) async throws {
        // Prendre les premiers ~30 secondes de texte
        let previewText = String(text.prefix(500))

        try await generateChunkAudio(
            text: previewText,
            referenceAudio: voiceConfig.referenceAudioPath,
            referenceText: voiceConfig.referenceTranscription,
            outputPath: outputPath,
            chunkIndex: 0,
            voiceConfig: voiceConfig
        )
    }
}

// MARK: - Errors

enum AudioGenerationError: Error, LocalizedError {
    case chunkGenerationFailed(Int, String)
    case chunkSkippedEmpty(Int)
    case noValidChunks
    case ffmpegNotFound
    case normalizationFailed(String)
    case missingAPIKey
    case missingFishAudioReference
    case ttsToolNotInstalled(String)

    var errorDescription: String? {
        switch self {
        case .chunkGenerationFailed(let index, let message):
            return "Échec de la génération du chunk \(index) : \(message)"
        case .chunkSkippedEmpty(let index):
            return "Chunk \(index) ignoré (vide / ponctuation seule)"
        case .noValidChunks:
            return "Aucun chunk valide à assembler"
        case .ffmpegNotFound:
            return "ffmpeg n'est pas installé. Installez-le avec : brew install ffmpeg"
        case .normalizationFailed(let message):
            return "Échec de la normalisation : \(message)"
        case .missingAPIKey:
            return "Clé API Fish.Audio manquante"
        case .missingFishAudioReference:
            return "Fish.Audio nécessite un model ID public. Sélectionnez une voix dans les réglages audio."
        case .ttsToolNotInstalled(let venvName):
            return "TTS Audiobook Tool non installé. Environnement manquant : \(venvName). Exécutez : cd external/tts-audiobook-tool && ./setup_venvs.sh"
        }
    }
}
