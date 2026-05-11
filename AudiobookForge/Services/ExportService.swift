import Foundation

/// Service d'export des fichiers audio finaux
class ExportService {
    static let shared = ExportService()
    
    private let pathResolver = PathResolver.shared
    private let logger = Logger.shared

    /// Exporte un projet dans le format choisi
    func exportProject(
        project: Project,
        format: ExportFormat,
        structure: ExportStructure,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [String] {
        let exportDir = "\(project.projectDirectory)/export"
        try FileManager.default.createDirectory(atPath: exportDir, withIntermediateDirectories: true)

        var exportedFiles: [String] = []

        switch structure {
        case .perChapter:
            exportedFiles = try await exportPerChapter(
                project: project,
                format: format,
                exportDir: exportDir,
                progressHandler: progressHandler
            )
        case .singleM4B:
            if let singleFile = try await exportSingleM4B(
                project: project,
                format: format,
                exportDir: exportDir,
                progressHandler: progressHandler
            ) {
                exportedFiles = [singleFile]
            }
        }

        return exportedFiles
    }

    /// Exporte un fichier par chapitre
    private func exportPerChapter(
        project: Project,
        format: ExportFormat,
        exportDir: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [String] {
        var exportedFiles: [String] = []

        for (index, chapter) in project.chapters.enumerated() {
            guard let audioPath = chapter.audioFilePath,
                  FileManager.default.fileExists(atPath: audioPath) else { continue }

            let chapterNum = String(format: "%02d", index + 1)
            let safeTitle = chapter.title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let extension_ = format.fileExtension
            let outputPath = "\(exportDir)/\(chapterNum)_\(safeTitle).\(extension_)"

            try await convertAudio(
                inputPath: audioPath,
                outputPath: outputPath,
                format: format,
                metadata: project.metadata,
                chapterTitle: chapter.title,
                chapterIndex: index + 1,
                coverPath: project.coverImagePath
            )

            exportedFiles.append(outputPath)

            await MainActor.run {
                progressHandler(Double(index + 1) / Double(project.chapters.count))
            }
        }

        return exportedFiles
    }

    /// Exporte un fichier M4B unique avec marqueurs de chapitres
    private func exportSingleM4B(
        project: Project,
        format: ExportFormat,
        exportDir: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String? {
        guard !project.chapters.isEmpty else { return nil }

        let outputPath = "\(exportDir)/\(project.metadata.title).m4b"

        // Créer un fichier de concaténation avec les chapitres
        let concatPath = "\(exportDir)/concat_list.txt"
        var concatContent = ""

        for chapter in project.chapters {
            guard let audioPath = chapter.audioFilePath,
                  FileManager.default.fileExists(atPath: audioPath) else { continue }
            concatContent += "file '\(audioPath)'\n"
        }

        try concatContent.write(toFile: concatPath, atomically: true, encoding: .utf8)

        // Créer le fichier de métadonnées des chapitres
        let metadataPath = "\(exportDir)/chapter_metadata.txt"
        var metadataContent = ";FFMETADATA1\n"
        metadataContent += "title=\(project.metadata.title)\n"
        metadataContent += "artist=\(project.metadata.author)\n"

        // Calculer les timestamps pour chaque chapitre
        var currentTimestamp: Int64 = 0
        for chapter in project.chapters {
            guard let audioPath = chapter.audioFilePath,
                  FileManager.default.fileExists(atPath: audioPath) else { continue }

            // Obtenir la durée du fichier audio
            let duration = try await getAudioDuration(filePath: audioPath)
            let durationMs = Int64(duration * 1000)

            metadataContent += "\n[CHAPTER]\n"
            metadataContent += "TIMEBASE=1/1000\n"
            metadataContent += "START=\(currentTimestamp)\n"
            metadataContent += "END=\(currentTimestamp + durationMs)\n"
            metadataContent += "title=\(chapter.title)\n"

            currentTimestamp += durationMs
        }

        try metadataContent.write(toFile: metadataPath, atomically: true, encoding: .utf8)

        // Concaténer et appliquer les métadonnées
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pathResolver.ffmpegPath)

        // Paramètres de codec selon le format choisi
        var codecArgs: [String]
        switch format {
        case .wav:
            codecArgs = ["-c:a", "pcm_s24le", "-sample_fmt", "s24"]
        case .aac:
            codecArgs = ["-c:a", "aac", "-b:a", "256k"]
        case .mp3:
            codecArgs = ["-c:a", "libmp3lame", "-b:a", "320k"]
        }

        process.arguments = [
            "-f", "concat",
            "-safe", "0",
            "-i", concatPath,
            "-i", metadataPath,
            "-map_metadata", "1",
        ] + codecArgs + [
            "-ar", "44100",
            outputPath,
            "-y"
        ]

        if let coverPath = project.coverImagePath,
           FileManager.default.fileExists(atPath: coverPath) {
            // Insérer les arguments de couverture après les arguments de base
            var args = process.arguments ?? []
            args.insert(contentsOf: ["-i", coverPath, "-map", "0:a:0", "-map", "2:v:0"], at: 2)
            process.arguments = args
        }

        try process.run()
        process.waitUntilExit()

        // Nettoyer
        try? FileManager.default.removeItem(atPath: concatPath)
        try? FileManager.default.removeItem(atPath: metadataPath)

        await MainActor.run {
            progressHandler(1.0)
        }

        return outputPath
    }

    /// Convertit un fichier audio dans le format cible
    private func convertAudio(
        inputPath: String,
        outputPath: String,
        format: ExportFormat,
        metadata: BookMetadata,
        chapterTitle: String,
        chapterIndex: Int,
        coverPath: String?
    ) async throws {
        logger.debug("Converting audio: \(inputPath) -> \(outputPath)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pathResolver.ffmpegPath)

        var arguments: [String] = [
            "-i", inputPath,
            "-ar", "44100"
        ]

        // Ajouter la couverture si disponible
        if let coverPath = coverPath, FileManager.default.fileExists(atPath: coverPath) {
            arguments.append(contentsOf: ["-i", coverPath])
        }

        // Métadonnées
        arguments.append(contentsOf: [
            "-metadata", "title=\(chapterTitle)",
            "-metadata", "artist=\(metadata.author)",
            "-metadata", "album=\(metadata.title)",
            "-metadata", "track=\(chapterIndex)",
            "-metadata", "comment=Généré par AudiobookForge + Fish S2 Pro"
        ])

        // Paramètres de codec selon le format
        switch format {
        case .wav:
            arguments.append(contentsOf: [
                "-c:a", "pcm_s24le",
                "-sample_fmt", "s24"
            ])
        case .aac:
            arguments.append(contentsOf: [
                "-c:a", "aac",
                "-b:a", "256k"
            ])
        case .mp3:
            arguments.append(contentsOf: [
                "-c:a", "libmp3lame",
                "-b:a", "320k"
            ])
        }

        arguments.append(contentsOf: [outputPath, "-y"])

        try process.run()
        process.waitUntilExit()
    }

    /// Obtient la durée d'un fichier audio via ffprobe
    private func getAudioDuration(filePath: String) async throws -> TimeInterval {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pathResolver.ffprobePath)
        process.arguments = [
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            filePath
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let outputString = String(data: outputData, encoding: .utf8) ?? "0"
        return TimeInterval(outputString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
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
