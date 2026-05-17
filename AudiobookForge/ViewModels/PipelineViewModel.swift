import Foundation
import SwiftUI
import UserNotifications

/// ViewModel principal du pipeline de traitement
@MainActor
class PipelineViewModel: ObservableObject {
    @Published var currentStep: PipelineStep = .import_
    @Published var project: Project?
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var progressText: String = ""
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isPaused = false

    // Éditeur de balises
    @Published var selectedChapterIndex: Int = 0
    @Published var tagColors: [String: Color] = [
        "[whisper]": .purple,
        "[excited]": .orange,
        "[sad]": .blue,
        "[pause]": .gray,
        "[angry]": .red,
        "[laughing]": .yellow,
        "[chuckle]": .yellow,
        "[emphasis]": .green,
        "[clearing throat]": .brown,
        "[inhale]": .cyan,
        "[professional broadcast tone]": .indigo,
        "[warm]": .pink,
        "[tense]": .red,
        "[mysterious]": .purple
    ]

    private let textExtractor = TextExtractorService.shared
    private let ollamaService = OllamaService.shared
    private let remoteAIService = RemoteAIService.shared
    private let keychain = KeychainHelper.shared
    private let audioService = AudioGenerationService.shared
    private let exportService = ExportService.shared
    private let projectManager = ProjectManager.shared
    private let diskChecker = DiskSpaceChecker()
    private let chunkCleaner = ChunkCleaner()

    enum PipelineStep: Int, CaseIterable {
        case import_ = 0
        case tags = 1
        case voice = 2
        case generation = 3
        case export = 4

        var title: String {
            switch self {
            case .import_: "Import"
            case .tags: "Balises"
            case .voice: "Voix"
            case .generation: "Génération"
            case .export: "Export"
            }
        }

        var icon: String {
            switch self {
            case .import_: "doc.badge.plus"
            case .tags: "tag"
            case .voice: "waveform"
            case .generation: "gearshape.2"
            case .export: "square.and.arrow.up"
            }
        }
    }

    func loadProject(_ project: Project) {
        self.project = project
        updateCurrentStep()
    }

    private func updateCurrentStep() {
        guard let project = project else { return }

        switch project.status {
        case .imported:
            currentStep = .import_
        case .textExtracted:
            currentStep = .tags
        case .tagsInjected:
            currentStep = .voice
        case .audioGenerated:
            currentStep = .export
        case .exported:
            currentStep = .export
        case .error:
            break
        }
    }

    // MARK: - Étape 1: Import + Extraction

    func extractText() async {
        guard let project = project else { return }
        isProcessing = true
        progressText = "Extraction du texte..."
        errorMessage = nil

        do {
            let (chapters, metadata, coverPath) = try await textExtractor.extractText(
                from: project.sourceFilePath,
                type: project.sourceFileType
            )

            var updatedProject = project
            updatedProject.metadata.title = metadata.title
            updatedProject.metadata.author = metadata.author
            updatedProject.coverImagePath = coverPath

            // Nettoyer le texte
            var cleanedChapters: [Chapter] = []
            for (index, chapter) in chapters.enumerated() {
                var cleaned = textExtractor.cleanText(chapter.text)
                cleaned = textExtractor.removeRepeatedHeadersFooters(from: cleaned)
                cleaned = textExtractor.removeFootnotes(from: cleaned)

                let chapterObj = Chapter(
                    index: index + 1,
                    title: chapter.title.isEmpty ? "Chapitre \(index + 1)" : chapter.title,
                    rawText: cleaned,
                    status: .textReady
                )
                cleanedChapters.append(chapterObj)

                // Sauvegarder le texte
                try? projectManager.saveChapterText(project: updatedProject, chapter: chapterObj)
            }

            updatedProject.chapters = cleanedChapters
            updatedProject.status = .textExtracted

            projectManager.updateProject(updatedProject)
            self.project = updatedProject
            currentStep = .tags

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    // MARK: - Étape 2: Injection de balises

    func injectTags() async {
        guard var project = project, !project.chapters.isEmpty else { return }
        isProcessing = true
        isPaused = false
        errorMessage = nil

        do {
            // Choisir le service selon la configuration
            let aiConfig = project.aiConfig
            let useRemote = aiConfig.forceRemote || (aiConfig.preferredProvider != .ollama)
            
            // DEBUG
            print("🔍 DEBUG injectTags:")
            print("  - preferredProvider: \(aiConfig.preferredProvider.rawValue)")
            print("  - forceRemote: \(aiConfig.forceRemote)")
            print("  - useRemote: \(useRemote)")
            print("  - requiresAPIKey: \(aiConfig.preferredProvider.requiresAPIKey)")
            
            // Traiter chaque chapitre avec sauvegarde incrémentielle
            for (index, chapter) in project.chapters.enumerated() {
                // Vérifier si déjà balisé (reprise après timeout)
                if chapter.status == .tagged && chapter.taggedText != nil {
                    progress = Double(index + 1) / Double(project.chapters.count)
                    progressText = "Chapitre \(index + 1)/\(project.chapters.count) déjà enrichi (reprise)..."
                    continue
                }
                
                guard !chapter.rawText.isEmpty else { continue }
                guard !isPaused else { break }
                
                do {
                    let taggedText: String
                    
                    if useRemote && aiConfig.preferredProvider.requiresAPIKey {
                        // Utiliser l'API distante
                        guard let apiKey = keychain.get(for: aiConfig.preferredProvider) else {
                            throw RemoteAIError.missingAPIKey
                        }
                        
                        progressText = "Enrichissement chapitre \(index + 1)/\(project.chapters.count) via \(aiConfig.preferredProvider.displayName)..."
                        
                        taggedText = try await remoteAIService.injectTags(
                            text: chapter.rawText,
                            provider: aiConfig.preferredProvider,
                            apiKey: apiKey
                        )
                    } else {
                        // Utiliser Ollama local
                        progressText = "Enrichissement chapitre \(index + 1)/\(project.chapters.count) via Ollama..."
                        
                        taggedText = try await ollamaService.injectTags(
                            chapterText: chapter.rawText
                        )
                    }
                    
                    // Sauvegarder immédiatement ce chapitre
                    project.chapters[index].taggedText = taggedText
                    project.chapters[index].status = .tagged
                    
                    // Sauvegarde incrémentielle
                    try? projectManager.saveChapterText(project: project, chapter: project.chapters[index])
                    projectManager.updateProject(project)
                    self.project = project
                    
                    progress = Double(index + 1) / Double(project.chapters.count)
                    progressText = "Chapitre \(index + 1)/\(project.chapters.count) enrichi ✓"
                    
                } catch {
                    // En cas d'erreur sur un chapitre, marquer comme erreur mais continuer
                    project.chapters[index].status = .error
                    projectManager.updateProject(project)
                    self.project = project
                    
                    print("⚠️ Erreur chapitre \(index + 1): \(error.localizedDescription)")
                    progressText = "Erreur chapitre \(index + 1), passage au suivant..."
                    
                    // Attendre un peu avant de continuer
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes
                }
            }

            // Vérifier si tous les chapitres sont balisés
            let allTagged = project.chapters.allSatisfy { $0.status == .tagged }
            if allTagged {
                project.status = .tagsInjected
                projectManager.updateProject(project)
                self.project = project
                currentStep = .voice
                progressText = "Enrichissement terminé ! ✓"
            } else {
                let taggedCount = project.chapters.filter { $0.status == .tagged }.count
                progressText = "Enrichissement partiel : \(taggedCount)/\(project.chapters.count) chapitres"
            }

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    func regenerateChapter(at index: Int) async {
        guard var project = project,
              index < project.chapters.count else { return }

        isProcessing = true
        errorMessage = nil

        do {
            let aiConfig = project.aiConfig
            let useRemote = aiConfig.forceRemote || (aiConfig.preferredProvider != .ollama)
            
            let taggedText: String
            
            if useRemote && aiConfig.preferredProvider.requiresAPIKey {
                guard let apiKey = keychain.get(for: aiConfig.preferredProvider) else {
                    throw RemoteAIError.missingAPIKey
                }
                
                taggedText = try await remoteAIService.injectTags(
                    text: project.chapters[index].rawText,
                    provider: aiConfig.preferredProvider,
                    apiKey: apiKey
                )
            } else {
                taggedText = try await ollamaService.injectTags(
                    chapterText: project.chapters[index].rawText
                )
            }

            project.chapters[index].taggedText = taggedText
            project.chapters[index].status = .tagged

            try? projectManager.saveChapterText(project: project, chapter: project.chapters[index])
            projectManager.updateProject(project)
            self.project = project

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    func removeAllTags(from chapterIndex: Int) {
        guard var project = project,
              chapterIndex < project.chapters.count else { return }

        project.chapters[chapterIndex].taggedText = nil
        project.chapters[chapterIndex].status = .textReady
        projectManager.updateProject(project)
        self.project = project
    }

    // MARK: - Étape 3: Configuration voix

    func setVoiceReference(audioPath: String, transcription: String) {
        guard var project = project else { return }

        project.voiceConfig.referenceAudioPath = audioPath
        project.voiceConfig.referenceTranscription = transcription
        projectManager.updateProject(project)
        self.project = project
    }

    func updateVoiceSpeed(_ speed: Double) {
        guard var project = project else { return }
        project.voiceConfig.speedScale = speed
        projectManager.updateProject(project)
        self.project = project
    }

    func updateVoiceTemperature(_ temperature: Double) {
        guard var project = project else { return }
        project.voiceConfig.temperature = temperature
        projectManager.updateProject(project)
        self.project = project
    }
    
    func updateVoiceConfig(_ config: VoiceConfig) {
        guard var project = project else {
            print("⚠️ updateVoiceConfig: No project loaded")
            return
        }
        
        print("🔧 updateVoiceConfig called:")
        print("  - Project: \(project.name)")
        print("  - preferredProvider: \(config.preferredProvider.rawValue)")
        print("  - forceRemote: \(config.forceRemote)")
        print("  - fallbackToRemote: \(config.fallbackToRemote)")
        print("  - selectedVoice: \(config.selectedFishAudioVoice ?? "none")")
        print("  - hasValidReference: \(config.hasValidReference)")
        
        project.voiceConfig = config
        projectManager.updateProject(project)
        self.project = project
        
        print("✅ VoiceConfig updated and saved to disk")
    }

    func generateVoicePreview() async {
        guard let project = project,
              project.voiceConfig.hasValidReference,
              let firstChapter = project.chapters.first else { return }

        isProcessing = true
        progressText = "Génération du preview vocal..."
        errorMessage = nil

        let previewPath = "\(project.projectDirectory)/voice_preview.wav"

        do {
            try await audioService.generatePreview(
                text: String(firstChapter.rawText.prefix(500)),
                voiceConfig: project.voiceConfig,
                outputPath: previewPath
            )
            progressText = "Preview prêt !"
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    // MARK: - Étape 4: Génération audio

    func generateAudio() async {
        guard let project = project,
              project.voiceConfig.hasValidReference else { return }

        isProcessing = true
        isPaused = false
        errorMessage = nil

        // Vérifier l'espace disque avant de commencer
        do {
            try diskChecker.checkBeforeAudioGeneration(project: project)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isProcessing = false
            return
        }

        var updatedProject = project

        for (chapterIndex, chapter) in updatedProject.chapters.enumerated() {
            guard !isPaused else { break }
            
            // Ignorer les chapitres non balisés ou déjà générés
            if chapter.status != .tagged {
                progressText = "Chapitre \(chapterIndex + 1) ignoré (non balisé)"
                continue
            }
            
            if chapter.status == .audioReady && chapter.audioFilePath != nil {
                progressText = "Chapitre \(chapterIndex + 1) déjà généré (reprise)"
                continue
            }

            progressText = "Génération du chapitre \(chapterIndex + 1)/\(updatedProject.chapters.count)..."
            progress = Double(chapterIndex) / Double(updatedProject.chapters.count)

            do {
                let (_, chapterAudioPath) = try await audioService.generateChapterAudio(
                    chapter: chapter,
                    projectDir: updatedProject.projectDirectory,
                    voiceConfig: updatedProject.voiceConfig,
                    progressHandler: { [weak self] current, total in
                        self?.progressText = "Chunk \(current)/\(total) du chapitre \(chapterIndex + 1)"
                    }
                )

                // Normaliser
                try await audioService.normalizeAudio(filePath: chapterAudioPath)

                updatedProject.chapters[chapterIndex].audioFilePath = chapterAudioPath
                updatedProject.chapters[chapterIndex].status = .audioReady

                // Nettoyer les chunks pour économiser l'espace disque
                // (garde les chunks en mode debug si nécessaire)
                chunkCleaner.cleanAllChunks(in: updatedProject.projectDirectory, keepChunks: false)

                // Sauvegarder la progression
                projectManager.updateProject(updatedProject)

            } catch {
                updatedProject.chapters[chapterIndex].status = .error
                errorMessage = "Erreur chapitre \(chapterIndex + 1): \(error.localizedDescription)"
                showError = true
            }
        }

        if !isPaused {
            updatedProject.status = .audioGenerated
            progress = 1.0
            progressText = "Génération terminée !"
        }

        projectManager.updateProject(updatedProject)
        self.project = updatedProject

        if updatedProject.status == .audioGenerated {
            currentStep = .export
        }

        isProcessing = false
    }

    func togglePause() {
        isPaused.toggle()
    }
    
    func generateSingleChapter(at index: Int) async {
        guard let project = project,
              index < project.chapters.count,
              project.voiceConfig.hasValidReference else { return }
        
        let chapter = project.chapters[index]
        
        // Vérifier que le chapitre est balisé
        guard chapter.status == .tagged else {
            errorMessage = "Le chapitre doit être balisé avant la génération"
            showError = true
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        var updatedProject = project
        
        progressText = "Génération du chapitre \(index + 1)..."
        progress = 0
        
        do {
            let (_, chapterAudioPath) = try await audioService.generateChapterAudio(
                chapter: chapter,
                projectDir: updatedProject.projectDirectory,
                voiceConfig: updatedProject.voiceConfig,
                progressHandler: { [weak self] current, total in
                    self?.progress = Double(current) / Double(total)
                    self?.progressText = "Chunk \(current)/\(total) du chapitre \(index + 1)"
                }
            )
            
            // Normaliser
            try await audioService.normalizeAudio(filePath: chapterAudioPath)
            
            updatedProject.chapters[index].audioFilePath = chapterAudioPath
            updatedProject.chapters[index].status = .audioReady
            
            // Nettoyer les chunks
            chunkCleaner.cleanAllChunks(in: updatedProject.projectDirectory, keepChunks: false)
            
            // Sauvegarder
            projectManager.updateProject(updatedProject)
            self.project = updatedProject
            
            progress = 1.0
            progressText = "Chapitre \(index + 1) généré ✓"
            
        } catch {
            updatedProject.chapters[index].status = .error
            errorMessage = "Erreur chapitre \(index + 1): \(error.localizedDescription)"
            showError = true
            projectManager.updateProject(updatedProject)
            self.project = updatedProject
        }
        
        isProcessing = false
    }

    // MARK: - Étape 5: Export

    func exportAudio(format: ExportFormat, structure: ExportStructure) async {
        guard let project = project else { return }

        isProcessing = true
        errorMessage = nil

        do {
            let exportedFiles = try await exportService.exportProject(
                project: project,
                format: format,
                structure: structure,
                progressHandler: { [weak self] progress in
                    self?.progress = progress
                    self?.progressText = "Export : \(Int(progress * 100))%"
                }
            )

            var updatedProject = project
            updatedProject.status = .exported
            updatedProject.exportConfig.format = format
            updatedProject.exportConfig.structure = structure
            projectManager.updateProject(updatedProject)
            self.project = updatedProject

            progressText = "Export terminé ! \(exportedFiles.count) fichier(s) créé(s)"

            // Notification macOS (UserNotifications framework)
            Task {
                await sendNotification(title: "AudiobookForge", body: "Export terminé : \(exportedFiles.count) fichier(s)")
            }

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }
    
    // MARK: - Notifications
    
    private func sendNotification(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        
        // Demander la permission si nécessaire
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Notification immédiate
            )
            
            try await center.add(request)
        } catch {
            // Ignorer les erreurs de notification (non critique)
            print("Failed to send notification: \(error)")
        }
    }
    
    // MARK: - Export du texte balisé
    
    enum TextExportFormat {
        case txt
        case pdf
    }
    
    func exportTaggedText(format: TextExportFormat) async {
        guard let project = project else { return }
        
        isProcessing = true
        errorMessage = nil
        progressText = "Export du texte balisé..."
        
        // Créer le nom de fichier
        let fileName = project.metadata.title.isEmpty ? project.name : project.metadata.title
        let sanitizedName = fileName.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let ext = format == .txt ? "txt" : "pdf"
        let outputPath = "\(project.projectDirectory)/export/\(sanitizedName)_tagged.\(ext)"
        
        // Créer le dossier export si nécessaire
        try? FileManager.default.createDirectory(atPath: "\(project.projectDirectory)/export", withIntermediateDirectories: true)
        
        do {
            let textExportService = TextExportService.shared
            
            if format == .txt {
                try textExportService.exportToTXT(project: project, outputPath: outputPath)
            } else {
                try textExportService.exportToPDF(project: project, outputPath: outputPath)
            }
            
            progressText = "Export terminé : \(outputPath)"
            
            // Ouvrir le fichier dans le Finder
            NSWorkspace.shared.selectFile(outputPath, inFileViewerRootedAtPath: "")
            
            // Notification
            await sendNotification(title: "AudiobookForge", body: "Export du texte balisé terminé")
            
        } catch {
            errorMessage = "Erreur lors de l'export : \(error.localizedDescription)"
            showError = true
        }
        
        isProcessing = false
    }
}
