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

    /// Découpe le texte en chunks de maximum 200 mots
    /// Préserve la ponctuation originale en utilisant une regex pour détecter les fins de phrase
    func chunkText(_ text: String, maxWords: Int = 200) -> [String] {
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

        return chunks
    }

    /// Génère l'audio pour un chunk (local MLX ou Fish.Audio API)
    func generateChunkAudio(
        text: String,
        referenceAudio: String,
        referenceText: String,
        outputPath: String,
        chunkIndex: Int,
        voiceConfig: VoiceConfig
    ) async throws {
        logger.debug("Generating chunk \(chunkIndex): \(text.prefix(50))...")
        
        // DEBUG: Afficher la configuration reçue
        print("🔍 DEBUG generateChunkAudio:")
        print("  - preferredProvider: \(voiceConfig.preferredProvider.rawValue)")
        print("  - forceRemote: \(voiceConfig.forceRemote)")
        print("  - fallbackToRemote: \(voiceConfig.fallbackToRemote)")
        print("  - requiresAPIKey: \(voiceConfig.preferredProvider.requiresAPIKey)")
        
        // Déterminer le provider à utiliser
        let provider = voiceConfig.preferredProvider
        
        print("  - provider: \(provider.rawValue)")
        
        switch provider {
        case .fishAudio:
            // Utiliser Fish.Audio API
            print("  ✅ Utilisation de Fish.Audio API")
            try await generateChunkViaFishAudio(
                text: text,
                referenceAudio: referenceAudio,
                referenceText: referenceText,
                outputPath: outputPath,
                chunkIndex: chunkIndex,
                voiceConfig: voiceConfig
            )
            
        case .ttsAudiobookTool:
            // Utiliser TTS Audiobook Tool
            print("  ✅ Utilisation de TTS Audiobook Tool")
            try await generateChunkViaTtsAudiobookTool(
                text: text,
                referenceAudio: referenceAudio,
                referenceText: referenceText,
                outputPath: outputPath,
                chunkIndex: chunkIndex,
                voiceConfig: voiceConfig
            )
            
        case .local:
            // Utiliser MLX local (code original)
            print("  ⚠️ Utilisation de MLX local (fallback)")
            try await generateChunkViaMLX(
                text: text,
                referenceAudio: referenceAudio,
                referenceText: referenceText,
                outputPath: outputPath,
                chunkIndex: chunkIndex,
                voiceConfig: voiceConfig
            )
        }
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
    
    /// Génère l'audio via TTS Audiobook Tool
    private func generateChunkViaTtsAudiobookTool(
        text: String,
        referenceAudio: String,
        referenceText: String,
        outputPath: String,
        chunkIndex: Int,
        voiceConfig: VoiceConfig
    ) async throws {
        logger.info("Generating chunk \(chunkIndex) via TTS Audiobook Tool...")
        
        // Déterminer le venv à utiliser selon le modèle
        let venvName: String
        switch voiceConfig.ttsModel {
        case .fishS2Pro:
            venvName = "venv-fish-s2"
        case .chatterbox:
            venvName = "venv-chatterbox"
        case .qwen3:
            venvName = "venv-qwen3tts"
        }
        
        let wrapperPath = "/Volumes/J3THext/Audiobookforge/external/tts-audiobook-tool/audiobook_tool_wrapper.py"
        let pythonPath = "/Volumes/J3THext/Audiobookforge/external/tts-audiobook-tool/\(venvName)/bin/python"
        
        // Vérifier que le venv existe
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            throw AudioGenerationError.ttsToolNotInstalled(venvName)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        
        var arguments = [
            wrapperPath,
            "generate",
            "--model", voiceConfig.ttsModel.rawValue,
            "--text", text,
            "--reference-audio", referenceAudio,
            "--reference-text", referenceText,
            "--output", outputPath,
            "--temperature", "\(voiceConfig.temperature)",
            "--max-retries", "\(voiceConfig.maxRetries)"
        ]
        
        // Ajouter les paramètres optionnels
        if voiceConfig.enableSttValidation {
            arguments.append("--enable-stt-validation")
        }
        
        if let topP = voiceConfig.topP {
            arguments.append(contentsOf: ["--top-p", "\(topP)"])
        }
        
        if let topK = voiceConfig.topK {
            arguments.append(contentsOf: ["--top-k", "\(topK)"])
        }
        
        if let seed = voiceConfig.seed {
            arguments.append(contentsOf: ["--seed", "\(seed)"])
        }
        
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Parser les logs JSON pour la progression
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let line = String(data: data, encoding: .utf8) {
                // Parser les lignes JSON
                for jsonLine in line.components(separatedBy: "\n") {
                    guard !jsonLine.isEmpty else { continue }
                    
                    if let jsonData = jsonLine.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        
                        if let type = json["type"] as? String {
                            if type == "progress", let data = json["data"] as? [String: Any] {
                                if let status = data["status"] as? String {
                                    self.logger.debug("TTS Tool: \(status)")
                                }
                            } else if type == "error", let message = json["message"] as? String {
                                self.logger.error("TTS Tool Error: \(message)")
                            }
                        }
                    }
                }
            }
        }
        
        try process.run()
        process.waitUntilExit()
        
        outputHandle.readabilityHandler = nil
        
        // Toujours vérifier si le fichier a été créé, même si terminationStatus != 0
        // Car Python peut retourner un code d'erreur même avec juste des warnings
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        // Vérifier si le fichier audio a été créé
        let fileExists = FileManager.default.fileExists(atPath: outputPath)
        
        if process.terminationStatus != 0 && !fileExists {
            // Vraie erreur : pas de fichier créé
            logger.error("❌ TTS Tool failed: \(errorOutput)")
            throw AudioGenerationError.chunkGenerationFailed(chunkIndex, errorOutput)
        }
        
        // Si le fichier existe, ignorer les warnings Python
        if !errorOutput.isEmpty && fileExists {
            logger.debug("⚠️ TTS Tool warnings (ignored): \(errorOutput.prefix(200))...")
        }
        
        // Post-processing optionnel
        if voiceConfig.enableNormalization {
            logger.debug("Normalizing chunk \(chunkIndex)...")
            try await normalizeViaTtsAudiobookTool(inputPath: outputPath, outputPath: outputPath, venvName: venvName)
        }
        
        if voiceConfig.enableUpsampling {
            logger.debug("Upsampling chunk \(chunkIndex)...")
            try await upsampleViaTtsAudiobookTool(inputPath: outputPath, outputPath: outputPath, venvName: venvName)
        }
        
        logger.info("Chunk \(chunkIndex) generated successfully via TTS Audiobook Tool")
    }
    
    /// Normalise l'audio via TTS Audiobook Tool
    private func normalizeViaTtsAudiobookTool(inputPath: String, outputPath: String, venvName: String) async throws {
        let wrapperPath = "/Volumes/J3THext/Audiobookforge/external/tts-audiobook-tool/audiobook_tool_wrapper.py"
        let pythonPath = "/Volumes/J3THext/Audiobookforge/external/tts-audiobook-tool/\(venvName)/bin/python"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [
            wrapperPath,
            "normalize",
            "--input", inputPath,
            "--output", outputPath
        ]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw AudioGenerationError.normalizationFailed("TTS Tool normalization failed")
        }
    }
    
    /// Upsample l'audio via TTS Audiobook Tool
    private func upsampleViaTtsAudiobookTool(inputPath: String, outputPath: String, venvName: String) async throws {
        let wrapperPath = "/Volumes/J3THext/Audiobookforge/external/tts-audiobook-tool/audiobook_tool_wrapper.py"
        let pythonPath = "/Volumes/J3THext/Audiobookforge/external/tts-audiobook-tool/\(venvName)/bin/python"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [
            wrapperPath,
            "upsample",
            "--input", inputPath,
            "--output", outputPath
        ]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw AudioGenerationError.normalizationFailed("TTS Tool upsampling failed")
        }
    }
    
    /// Génère l'audio via MLX local (code original)
    private func generateChunkViaMLX(
        text: String,
        referenceAudio: String,
        referenceText: String,
        outputPath: String,
        chunkIndex: Int,
        voiceConfig: VoiceConfig
    ) async throws {
        logger.info("Generating chunk \(chunkIndex) via MLX local...")
        
        let scriptPath = "\(pathResolver.backendScriptsPath)/generate/fish_s2_pro.py"
        let pythonPath = pathResolver.pythonPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)

        // Utiliser le repo HuggingFace par défaut au lieu d'un chemin local
        process.arguments = [
            scriptPath,
            "--text", text,
            "--reference-audio", referenceAudio,
            "--reference-text", referenceText,
            "--output", outputPath,
            "--max-new-tokens", "2048"
        ]

        // Ajouter les paramètres optionnels
        if voiceConfig.speedScale != 1.0 {
            process.arguments?.append(contentsOf: ["--length-scale", "\(voiceConfig.speedScale)"])
        }
        if voiceConfig.temperature != 0.8 {
            process.arguments?.append(contentsOf: ["--temperature", "\(voiceConfig.temperature)"])
        }

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Erreur inconnue"
            throw AudioGenerationError.chunkGenerationFailed(chunkIndex, errorMessage)
        }
        
        logger.info("Chunk \(chunkIndex) generated successfully via MLX local")
    }

    /// Génère tous les chunks d'un chapitre
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

        var chunks: [Chunk] = []

        for (index, chunkText) in chunkTexts.enumerated() {
            let chunkPath = "\(chunksDir)/chunk_\(chapter.index)_\(index).wav"

            let chunk = Chunk(
                index: index,
                chapterIndex: chapter.index,
                text: chunkText,
                status: .pending,
                audioFilePath: chunkPath
            )
            chunks.append(chunk)

            do {
                try await generateChunkAudio(
                    text: chunkText,
                    referenceAudio: voiceConfig.referenceAudioPath,
                    referenceText: voiceConfig.referenceTranscription,
                    outputPath: chunkPath,
                    chunkIndex: index,
                    voiceConfig: voiceConfig
                )
                chunks[index].status = .done
                logger.info("✅ Chunk \(index) généré avec succès")
            } catch {
                chunks[index].status = .error
                chunks[index].errorMessage = error.localizedDescription
                logger.error("❌ Chunk \(index) échoué: \(error.localizedDescription)")
            }

            await MainActor.run {
                progressHandler(index + 1, chunkTexts.count)
            }
        }

        // Assembler les chunks en un fichier chapitre
        let chapterAudioPath = "\(chaptersDir)/chapter_\(chapter.index).wav"
        let validChunks = chunks.filter { $0.status == .done }
        
        logger.info("📊 Chunks générés: \(chunks.count), valides: \(validChunks.count)")
        
        if validChunks.isEmpty {
            logger.error("❌ Aucun chunk valide généré pour le chapitre \(chapter.index)")
            throw AudioGenerationError.noValidChunks
        }
        
        try await assembleChunks(chunks: validChunks, outputPath: chapterAudioPath)

        return (chunks, chapterAudioPath)
    }

    /// Assemble les chunks audio en un seul fichier via ffmpeg
    private func assembleChunks(chunks: [Chunk], outputPath: String) async throws {
        guard !chunks.isEmpty else {
            throw AudioGenerationError.noValidChunks
        }

        // Créer un fichier liste pour ffmpeg
        let listPath = "\(outputPath).list"
        var listContent = ""

        for chunk in chunks.sorted(by: { $0.index < $1.index }) {
            guard let path = chunk.audioFilePath else { continue }
            listContent += "file '\(path)'\n"
        }

        try listContent.write(toFile: listPath, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pathResolver.ffmpegPath)
        process.arguments = [
            "-f", "concat",
            "-safe", "0",
            "-i", listPath,
            "-c", "copy",
            outputPath
        ]

        try process.run()
        process.waitUntilExit()

        // Nettoyer le fichier liste
        try? FileManager.default.removeItem(atPath: listPath)
    }

    /// Normalise le volume d'un fichier audio à -1 dBFS
    func normalizeAudio(filePath: String) async throws {
        logger.debug("Normalizing audio: \(filePath)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pathResolver.ffmpegPath)
        process.arguments = [
            "-i", filePath,
            "-af", "loudnorm=I=-1:LRA=11:TP=-1",
            "-ar", "44100",
            "-sample_fmt", "s24le",
            "\(filePath)_normalized.wav",
            "-y"
        ]

        try process.run()
        process.waitUntilExit()

        // Remplacer l'original par le normalisé
        try FileManager.default.removeItem(atPath: filePath)
        try FileManager.default.moveItem(atPath: "\(filePath)_normalized.wav", toPath: filePath)
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
