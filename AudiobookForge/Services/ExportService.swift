import Foundation

/// Service d'export des fichiers audio finaux.
/// Refactorisé pour utiliser ProcessRunner (drainage de pipes → plus de deadlock ffmpeg),
/// vérifier les codes de sortie, et tolérer les exports partiels.
class ExportService {
    static let shared = ExportService()

    private let pathResolver = PathResolver.shared
    private let logger = Logger.shared

    /// Erreurs d'export.
    enum ExportError: Error, LocalizedError {
        case noChaptersReady
        case ffmpegFailed(stage: String, code: Int32, stderr: String)

        var errorDescription: String? {
            switch self {
            case .noChaptersReady:
                return "Aucun chapitre n'a d'audio à exporter. Générez au moins un chapitre dans l'onglet Génération."
            case .ffmpegFailed(let stage, let code, let stderr):
                return "ffmpeg a échoué (\(stage), code \(code)) : \(stderr.suffix(300))"
            }
        }
    }

    /// Exporte un projet dans le format choisi.
    /// Tolère les exports partiels : seuls les chapitres ayant un `audioFilePath`
    /// existant sur disque sont exportés. Si aucun n'est prêt, lève `.noChaptersReady`.
    func exportProject(
        project: Project,
        format: ExportFormat,
        structure: ExportStructure,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [String] {
        let readyChapters = project.chapters.filter {
            guard let path = $0.audioFilePath else { return false }
            return FileManager.default.fileExists(atPath: path)
        }
        guard !readyChapters.isEmpty else {
            throw ExportError.noChaptersReady
        }

        logger.info("Export : \(readyChapters.count)/\(project.chapters.count) chapitres prêts à exporter")

        let exportDir = "\(project.projectDirectory)/export"
        try FileManager.default.createDirectory(atPath: exportDir, withIntermediateDirectories: true)

        switch structure {
        case .perChapter:
            return try await exportPerChapter(
                project: project,
                readyChapters: readyChapters,
                format: format,
                exportDir: exportDir,
                progressHandler: progressHandler
            )
        case .singleM4B:
            if let single = try await exportSingleM4B(
                project: project,
                readyChapters: readyChapters,
                format: format,
                exportDir: exportDir,
                progressHandler: progressHandler
            ) {
                return [single]
            }
            return []
        }
    }

    // MARK: - Per-chapter export

    private func exportPerChapter(
        project: Project,
        readyChapters: [Chapter],
        format: ExportFormat,
        exportDir: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [String] {
        var exportedFiles: [String] = []

        for (i, chapter) in readyChapters.enumerated() {
            guard let audioPath = chapter.audioFilePath else { continue }

            let chapterNum = String(format: "%02d", chapter.index)
            let safeTitle = sanitizeFilename(chapter.title)
            let outputPath = "\(exportDir)/\(chapterNum)_\(safeTitle).\(format.fileExtension)"

            try await convertAudio(
                inputPath: audioPath,
                outputPath: outputPath,
                format: format,
                metadata: project.metadata,
                chapterTitle: chapter.title,
                chapterIndex: chapter.index,
                coverPath: project.coverImagePath
            )

            exportedFiles.append(outputPath)

            await MainActor.run {
                progressHandler(Double(i + 1) / Double(readyChapters.count))
            }
        }

        return exportedFiles
    }

    // MARK: - Single M4B export

    private func exportSingleM4B(
        project: Project,
        readyChapters: [Chapter],
        format: ExportFormat,
        exportDir: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String? {
        let safeBookTitle = sanitizeFilename(
            project.metadata.title.isEmpty ? project.name : project.metadata.title
        )
        // M4B nécessite codec AAC. Même si l'utilisateur a choisi WAV ou MP3,
        // on garde l'extension M4B et on force AAC (c'est par définition).
        let outputPath = "\(exportDir)/\(safeBookTitle).m4b"

        let concatPath = "\(exportDir)/concat_list.txt"
        let metadataPath = "\(exportDir)/chapter_metadata.txt"
        defer {
            try? FileManager.default.removeItem(atPath: concatPath)
            try? FileManager.default.removeItem(atPath: metadataPath)
        }

        // Concat list
        var concatContent = ""
        for chapter in readyChapters {
            guard let path = chapter.audioFilePath else { continue }
            // Échappement des apostrophes dans le path pour la concat list ffmpeg
            let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
            concatContent += "file '\(escaped)'\n"
        }
        try concatContent.write(toFile: concatPath, atomically: true, encoding: .utf8)

        // Métadonnées des chapitres
        var metadataContent = ";FFMETADATA1\n"
        metadataContent += "title=\(project.metadata.title)\n"
        metadataContent += "artist=\(project.metadata.author)\n"

        var currentTimestamp: Int64 = 0
        for chapter in readyChapters {
            guard let audioPath = chapter.audioFilePath else { continue }
            let duration = (try? await getAudioDuration(filePath: audioPath)) ?? 0
            let durationMs = Int64(duration * 1000)

            metadataContent += "\n[CHAPTER]\n"
            metadataContent += "TIMEBASE=1/1000\n"
            metadataContent += "START=\(currentTimestamp)\n"
            metadataContent += "END=\(currentTimestamp + durationMs)\n"
            metadataContent += "title=\(chapter.title)\n"

            currentTimestamp += durationMs
        }
        try metadataContent.write(toFile: metadataPath, atomically: true, encoding: .utf8)

        // Construction propre des arguments ffmpeg.
        // Ordre des inputs (numérotés pour les -map) :
        //   0 = concat.txt (audio)
        //   1 = metadata.txt (métadonnées)
        //   2 = cover.jpg (optionnel)
        var args: [String] = [
            "-nostdin",
            "-loglevel", "error",
            "-f", "concat",
            "-safe", "0",
            "-i", concatPath,
            "-i", metadataPath
        ]

        let coverIncluded: Bool
        if let coverPath = project.coverImagePath,
           FileManager.default.fileExists(atPath: coverPath) {
            args.append(contentsOf: ["-i", coverPath])
            coverIncluded = true
        } else {
            coverIncluded = false
        }

        args.append(contentsOf: ["-map_metadata", "1"])
        // Mapping explicite pour ne pas tomber sur des warnings/erreurs ffmpeg
        args.append(contentsOf: ["-map", "0:a:0"])
        if coverIncluded {
            args.append(contentsOf: ["-map", "2:v:0", "-disposition:v:0", "attached_pic"])
        }

        // M4B = AAC obligatoire
        args.append(contentsOf: ["-c:a", "aac", "-b:a", "256k"])
        args.append(contentsOf: ["-ar", "44100"])
        args.append("-y")
        args.append(outputPath)

        let result = try await ProcessRunner.run(
            executable: pathResolver.ffmpegPath,
            arguments: args
        )

        guard result.status == 0 else {
            throw ExportError.ffmpegFailed(stage: "M4B concat", code: result.status, stderr: result.stderr)
        }

        // Validation taille
        let size = ((try? FileManager.default.attributesOfItem(atPath: outputPath))?[.size] as? Int) ?? 0
        guard size > 1024 else {
            throw ExportError.ffmpegFailed(stage: "M4B (sortie vide)", code: 0, stderr: result.stderr)
        }

        await MainActor.run { progressHandler(1.0) }
        return outputPath
    }

    // MARK: - Convert audio (single chapter)

    private func convertAudio(
        inputPath: String,
        outputPath: String,
        format: ExportFormat,
        metadata: BookMetadata,
        chapterTitle: String,
        chapterIndex: Int,
        coverPath: String?
    ) async throws {
        logger.debug("Converting: \(inputPath) → \(outputPath)")

        var args: [String] = ["-nostdin", "-loglevel", "error", "-i", inputPath]

        // Cover image (input n°1)
        let coverIncluded: Bool
        if let coverPath, FileManager.default.fileExists(atPath: coverPath) {
            args.append(contentsOf: ["-i", coverPath])
            coverIncluded = true
        } else {
            coverIncluded = false
        }

        // Mapping audio + cover
        args.append(contentsOf: ["-map", "0:a:0"])
        if coverIncluded {
            args.append(contentsOf: ["-map", "1:v:0", "-disposition:v:0", "attached_pic"])
        }

        // Métadonnées
        args.append(contentsOf: [
            "-metadata", "title=\(chapterTitle)",
            "-metadata", "artist=\(metadata.author)",
            "-metadata", "album=\(metadata.title)",
            "-metadata", "track=\(chapterIndex)",
            "-metadata", "comment=Généré par AudiobookForge"
        ])

        // Codec selon le format
        switch format {
        case .wav:
            args.append(contentsOf: ["-c:a", "pcm_s24le", "-sample_fmt", "s24"])
        case .aac:
            args.append(contentsOf: ["-c:a", "aac", "-b:a", "256k"])
        case .mp3:
            args.append(contentsOf: ["-c:a", "libmp3lame", "-b:a", "320k"])
        }

        args.append(contentsOf: ["-ar", "44100"])
        args.append("-y")
        args.append(outputPath)

        let result = try await ProcessRunner.run(
            executable: pathResolver.ffmpegPath,
            arguments: args
        )

        guard result.status == 0 else {
            throw ExportError.ffmpegFailed(stage: "convert \(chapterTitle)", code: result.status, stderr: result.stderr)
        }

        let size = ((try? FileManager.default.attributesOfItem(atPath: outputPath))?[.size] as? Int) ?? 0
        guard size > 1024 else {
            throw ExportError.ffmpegFailed(stage: "convert \(chapterTitle) (sortie vide)", code: 0, stderr: result.stderr)
        }
    }

    // MARK: - ffprobe duration

    private func getAudioDuration(filePath: String) async throws -> TimeInterval {
        let result = try await ProcessRunner.run(
            executable: pathResolver.ffprobePath,
            arguments: [
                "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                filePath
            ],
            timeoutSeconds: 30
        )
        let raw = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return TimeInterval(raw) ?? 0
    }

    // MARK: - Helpers

    /// Retire les caractères dangereux pour un nom de fichier sur tous les FS courants.
    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?*<>|\"")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "untitled" : trimmed
    }
}

// MARK: - Format Extensions

extension ExportFormat {
    var fileExtension: String {
        switch self {
        case .wav: return "wav"
        case .aac: return "m4a"
        case .mp3: return "mp3"
        }
    }
}
