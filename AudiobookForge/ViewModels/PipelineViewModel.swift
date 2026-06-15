import Foundation
import SwiftUI

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
        "[whispering]": .purple,
        "[excited]": .orange,
        "[sad]": .blue,
        "[break]": .gray,
        "[long-break]": .gray,
        "[angry]": .red,
        "[laughing]": .yellow,
        "[chuckling]": .yellow,
        "[sighing]": .cyan,
        "[gasping]": .cyan,
        "[soft tone]": .pink,
        "[in a hurry tone]": .red,
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
    
    init() {
        // Écouter la notification de sauvegarde du projet
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SaveProject"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveCurrentProject()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func saveCurrentProject() {
        guard let project = project else {
            print("⚠️ saveCurrentProject: Aucun projet chargé")
            return
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("💾 PipelineViewModel.saveCurrentProject() appelé")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📝 Projet actuel:")
        print("  - Nom: \(project.name)")
        print("  - preferredProvider: \(project.voiceConfig.preferredProvider.rawValue)")
        print("  - ttsModel: \(project.voiceConfig.ttsModel.rawValue)")
        print("")
        print("📤 Appel de projectManager.updateProject()...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        projectManager.updateProject(project)
        
        print("✅ projectManager.updateProject() terminé")
    }

    enum PipelineStep: Int, CaseIterable {
        case import_   = 0
        case voice     = 1
        case tags      = 2  // ⚠️ Étape conditionnelle : visible seulement si voiceConfig.engineSupportsTags
        case generation = 3
        case export    = 4

        var title: String {
            switch self {
            case .import_: "Import"
            case .voice: "Voix"
            case .tags: "Balises"
            case .generation: "Génération"
            case .export: "Export"
            }
        }

        var icon: String {
            switch self {
            case .import_: "doc.badge.plus"
            case .voice: "waveform"
            case .tags: "tag"
            case .generation: "gearshape.2"
            case .export: "square.and.arrow.up"
            }
        }
    }

    /// Le sélecteur de mode reste accessible dans l'étape Balises, même en mode Aucun.
    var visibleSteps: [PipelineStep] {
        PipelineStep.allCases
    }

    func loadProject(_ project: Project) {
        self.project = project
        updateCurrentStep()
    }

    private func updateCurrentStep() {
        guard let project = project else { return }

        // Nouveau flux : Import → Voix → Balises (cond.) → Génération → Export.
        // Pour les projets legacy avec status .tagsInjected (créés sous l'ancien ordre),
        // on garde leur taggedText et on les place sur Voix pour qu'ils confirment le moteur.
        switch project.status {
        case .imported:
            currentStep = .import_
        case .textExtracted:
            currentStep = .voice
        case .tagsInjected:
            // Projet legacy : balises déjà injectées. On les conserve (migration 2.A).
            // On envoie sur Voix car le moteur reste à confirmer.
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
            // Nouveau flux : après l'import, on configure d'abord la voix
            // (l'étape Balises est conditionnelle au moteur choisi).
            currentStep = .voice

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    // MARK: - Étape 2: Injection de balises

    func updateTaggingMode(_ mode: TaggingMode) {
        guard var project = project, project.aiConfig.taggingMode != mode else { return }

        project.aiConfig.taggingMode = mode
        switch mode {
        case .fishS2:
            project.voiceConfig.preferredProvider = .ttsAudiobookTool
            project.voiceConfig.ttsModel = .fishS2Pro
        case .qwen3TTS:
            project.voiceConfig.preferredProvider = .ttsAudiobookTool
            project.voiceConfig.ttsModel = .qwen3
            if project.voiceConfig.resolvedQwenVoiceMode == .voiceClone,
               project.voiceConfig.hasValidReference {
                project.voiceConfig.qwenModelPath = VoiceConfig.defaultQwenVoiceCloneModelPath
            } else if project.voiceConfig.resolvedQwenVoiceMode == .voiceDesign,
                      project.voiceConfig.qwenVoiceDesignDescription?.isEmpty == false {
                project.voiceConfig.qwenModelPath = VoiceConfig.defaultQwenVoiceDesignModelPath
            } else {
                project.voiceConfig.qwenVoiceMode = .customVoice
                project.voiceConfig.qwenModelPath = VoiceConfig.defaultQwenModelPath
                project.voiceConfig.qwenSpeakerId = "ryan"
            }
            project.voiceConfig.qwenLanguage = project.metadata.language
            project.voiceConfig.enableSttValidation = true
            project.voiceConfig.maxRetries = max(project.voiceConfig.maxRetries, 3)
        case .none:
            break
        }
        for index in project.chapters.indices {
            project.chapters[index].taggedText = nil
            if project.chapters[index].status == .tagged || project.chapters[index].status == .error {
                project.chapters[index].status = .textReady
            }
        }
        if project.status == .tagsInjected {
            project.status = .textExtracted
        }

        projectManager.updateProject(project)
        self.project = project
        switch mode {
        case .none:
            progressText = "Balisage désactivé : le texte original sera utilisé."
        case .fishS2:
            progressText = "Fish S2 sélectionné pour le balisage et le rendu."
        case .qwen3TTS:
            progressText = project.voiceConfig.resolvedQwenVoiceMode == .voiceDesign
                ? "Qwen3-TTS VoiceDesign sélectionné pour le balisage et le rendu."
                : "Qwen3-TTS CustomVoice sélectionné pour le balisage et le rendu."
        }
    }

    func injectTags() async {
        guard var project = project, !project.chapters.isEmpty else { return }
        guard project.aiConfig.taggingMode.usesAI else {
            currentStep = .generation
            progressText = "Balisage désactivé : passage direct à la génération."
            return
        }
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
                if chapter.status == .tagged,
                   chapter.taggedText != nil,
                   chapter.artDirection != nil {
                    progress = Double(index + 1) / Double(project.chapters.count)
                    progressText = "Chapitre \(index + 1)/\(project.chapters.count) déjà enrichi (reprise)..."
                    continue
                }
                
                guard !chapter.rawText.isEmpty else { continue }
                guard !isPaused, !Task.isCancelled else {
                    progressText = "Enrichissement interrompu."
                    break
                }
                
                do {
                    let artDirection: ChapterArtDirection
                    let taggedText: String
                    
                    if useRemote && aiConfig.preferredProvider.requiresAPIKey {
                        // Utiliser l'API distante
                        guard let apiKey = keychain.get(for: aiConfig.preferredProvider) else {
                            throw RemoteAIError.missingAPIKey
                        }

                        if let savedDirection = project.chapters[index].artDirection {
                            artDirection = savedDirection
                        } else {
                            progressText = "Analyse artistique chapitre \(index + 1)/\(project.chapters.count) via \(aiConfig.preferredProvider.displayName)..."
                            artDirection = try await remoteAIService.analyzeChapter(
                                text: chapter.rawText,
                                title: chapter.title,
                                provider: aiConfig.preferredProvider,
                                apiKey: apiKey,
                                model: modelName(for: aiConfig)
                            )
                            project.chapters[index].artDirection = artDirection
                            projectManager.updateProject(project)
                            self.project = project
                        }

                        progressText = "Balisage chapitre \(index + 1)/\(project.chapters.count) via \(aiConfig.preferredProvider.displayName)..."
                        taggedText = try await remoteAIService.injectTags(
                            text: chapter.rawText,
                            provider: aiConfig.preferredProvider,
                            apiKey: apiKey,
                            model: modelName(for: aiConfig),
                            taggingMode: aiConfig.taggingMode,
                            densityInstruction: aiConfig.tagDensityInstruction,
                            artDirection: artDirection
                        )
                    } else {
                        // Utiliser Ollama local
                        if let savedDirection = project.chapters[index].artDirection {
                            artDirection = savedDirection
                        } else {
                            progressText = "Analyse artistique chapitre \(index + 1)/\(project.chapters.count) via Ollama..."
                            artDirection = try await ollamaService.analyzeChapter(
                                chapterText: chapter.rawText,
                                title: chapter.title
                            )
                            project.chapters[index].artDirection = artDirection
                            projectManager.updateProject(project)
                            self.project = project
                        }

                        progressText = "Balisage chapitre \(index + 1)/\(project.chapters.count) via Ollama..."
                        taggedText = try await ollamaService.injectTags(
                            chapterText: chapter.rawText,
                            taggingMode: aiConfig.taggingMode,
                            densityInstruction: aiConfig.tagDensityInstruction,
                            artDirection: artDirection
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
                // Nouveau flux : après balisage, on va à la Génération (Voix a déjà été configurée).
                currentStep = .generation
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
            
            let artDirection: ChapterArtDirection
            let taggedText: String
            
            if useRemote && aiConfig.preferredProvider.requiresAPIKey {
                guard let apiKey = keychain.get(for: aiConfig.preferredProvider) else {
                    throw RemoteAIError.missingAPIKey
                }

                if let savedDirection = project.chapters[index].artDirection {
                    artDirection = savedDirection
                } else {
                    progressText = "Analyse artistique du chapitre via \(aiConfig.preferredProvider.displayName)…"
                    artDirection = try await remoteAIService.analyzeChapter(
                        text: project.chapters[index].rawText,
                        title: project.chapters[index].title,
                        provider: aiConfig.preferredProvider,
                        apiKey: apiKey,
                        model: modelName(for: aiConfig)
                    )
                    project.chapters[index].artDirection = artDirection
                    projectManager.updateProject(project)
                    self.project = project
                }
                progressText = "Application de la direction artistique…"
                taggedText = try await remoteAIService.injectTags(
                    text: project.chapters[index].rawText,
                    provider: aiConfig.preferredProvider,
                    apiKey: apiKey,
                    model: modelName(for: aiConfig),
                    taggingMode: aiConfig.taggingMode,
                    densityInstruction: aiConfig.tagDensityInstruction,
                    artDirection: artDirection
                )
            } else {
                if let savedDirection = project.chapters[index].artDirection {
                    artDirection = savedDirection
                } else {
                    progressText = "Analyse artistique du chapitre via Ollama…"
                    artDirection = try await ollamaService.analyzeChapter(
                        chapterText: project.chapters[index].rawText,
                        title: project.chapters[index].title
                    )
                    project.chapters[index].artDirection = artDirection
                    projectManager.updateProject(project)
                    self.project = project
                }
                progressText = "Application de la direction artistique…"
                taggedText = try await ollamaService.injectTags(
                    chapterText: project.chapters[index].rawText,
                    taggingMode: aiConfig.taggingMode,
                    densityInstruction: aiConfig.tagDensityInstruction,
                    artDirection: artDirection
                )
            }

            project.chapters[index].artDirection = artDirection
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

    private func modelName(for config: AIConfig) -> String {
        switch config.preferredProvider {
        case .openai: return config.openaiModel
        case .anthropic: return config.anthropicModel
        case .deepseek: return config.deepseekModel
        case .ollama: return ""
        }
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

        // Note Fish.Audio : on n'auto-crée plus de référence ici. L'API publique JSON
        // ne supporte pas POST /v1/references/add (404). Pour utiliser Fish.Audio,
        // l'utilisateur sélectionne un modèle public via Réglages audio → Charger
        // les voix (GET /model). L'audio local sert uniquement aux providers locaux
        // (MLX, TTS Audiobook Tool).

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
            print("⚠️ updateVoiceConfig: aucun projet chargé")
            return
        }

        print("🔧 updateVoiceConfig : provider=\(config.preferredProvider.rawValue), voice=\(config.selectedFishAudioVoice ?? "—"), ttsModel=\(config.ttsModel.rawValue), valid=\(config.hasValidReference)")

        project.voiceConfig = config
        projectManager.updateProject(project)
        self.project = project
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
        guard let project = project else { return }

        // Validation pré-vol : on refuse de démarrer la boucle si la config est incomplète.
        // Sinon on génère 100 chunks qui échouent tous avec la même erreur, et l'utilisateur
        // voit un "Aucun chunk valide" générique au lieu de la vraie cause.
        guard project.voiceConfig.hasValidReference else {
            errorMessage = project.voiceConfig.missingReferenceHint
                ?? "Configuration audio incomplète. Vérifiez l'onglet Voix."
            showError = true
            return
        }

        // Validation supplémentaire pour Fish.Audio : la clé API doit être dans le Keychain
        if project.voiceConfig.preferredProvider == .fishAudio,
           keychain.get(for: AudioProvider.fishAudio) == nil {
            errorMessage = "Clé API Fish.Audio manquante. Ouvrez les Réglages audio (icône 🔊) pour la saisir."
            showError = true
            return
        }

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

        // Reset des chapitres .error avant la boucle : on les remet dans leur état
        // pré-génération (textReady ou tagged selon qu'ils ont du taggedText).
        // Sans ça, l'UI conserverait le badge rouge "Erreur" pendant toute la durée
        // de la régénération, faisant croire à un nouvel échec.
        for i in updatedProject.chapters.indices where updatedProject.chapters[i].status == .error {
            updatedProject.chapters[i].status = updatedProject.chapters[i].taggedText != nil ? .tagged : .textReady
        }
        self.project = updatedProject  // refresh UI immédiat

        for (chapterIndex, chapter) in updatedProject.chapters.enumerated() {
            guard !isPaused, !Task.isCancelled else {
                progressText = "Génération interrompue."
                break
            }

            // Ignorer les chapitres déjà générés
            if chapter.status == .audioReady && chapter.audioFilePath != nil {
                progressText = "Chapitre \(chapterIndex + 1) déjà généré (reprise)"
                continue
            }

            // Vérifier qu'il y a du texte (balisé ou brut)
            let textToGenerate = chapter.taggedText ?? chapter.rawText
            if textToGenerate.isEmpty {
                progressText = "Chapitre \(chapterIndex + 1) ignoré (vide)"
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

                // Normalisation : si elle échoue, on garde l'audio non normalisé
                // (le swap atomique de normalizeAudio garantit que l'original reste valide).
                do {
                    try await audioService.normalizeAudio(filePath: chapterAudioPath)
                } catch {
                    Logger.shared.warning("Normalisation échouée pour chapitre \(chapterIndex + 1) : \(error.localizedDescription). Audio conservé non normalisé.")
                }

                updatedProject.chapters[chapterIndex].audioFilePath = chapterAudioPath
                updatedProject.chapters[chapterIndex].status = .audioReady

                // Nettoyage ciblé : uniquement les chunks de CE chapitre.
                chunkCleaner.cleanChunksForChapter(
                    in: updatedProject.projectDirectory,
                    chapterIndex: chapter.index,
                    keepChunks: false
                )

                // Persistance + refresh UI immédiats après chaque chapitre
                projectManager.updateProject(updatedProject)
                self.project = updatedProject

            } catch {
                updatedProject.chapters[chapterIndex].status = .error
                updatedProject.chapters[chapterIndex].audioFilePath = nil
                errorMessage = "Erreur chapitre \(chapterIndex + 1) : \(error.localizedDescription)"
                showError = true
                // IMPORTANT : persister + refresh même en cas d'erreur, sinon la
                // reprise au prochain lancement ne saura pas que ce chapitre a échoué
                // (Trou #3 de l'audit).
                projectManager.updateProject(updatedProject)
                self.project = updatedProject
            }
        }

        if !isPaused && !Task.isCancelled {
            let errorChapters = updatedProject.chapters.filter { $0.status == .error }.count
            let allOK = errorChapters == 0
                && updatedProject.chapters.allSatisfy { $0.status == .audioReady || $0.rawText.isEmpty }

            if allOK {
                updatedProject.status = .audioGenerated
                progress = 1.0
                progressText = "Génération terminée ✓"
                errorMessage = nil  // efface toute trace d'erreur passée
            } else if errorChapters > 0 {
                progressText = "Génération partielle : \(errorChapters) chapitre(s) en erreur"
            }
        }

        projectManager.updateProject(updatedProject)
        self.project = updatedProject

        if updatedProject.status == .audioGenerated {
            currentStep = .export
        }

        isProcessing = false

        // Fin de génération projet → libère le modèle (~17 Go) de la RAM.
        // Le daemon se relancera tout seul à la prochaine génération.
        Task { await TTSDaemon.shared.stop() }
    }

    func togglePause() {
        isPaused.toggle()
    }

    /// Force la fin d'une opération bloquée. Sert de "ceinture de sécurité"
    /// si jamais l'UI se retrouve coincée en `isProcessing=true` après un
    /// événement imprévu (sous-processus tué, deadlock pipe, etc.).
    func cancelCurrentOperation() {
        isProcessing = false
        // On DOIT passer isPaused à true, sinon les boucles de génération
        // continuent en arrière-plan sans libérer le CPU/Disque
        isPaused = true
        progressText = "Opération annulée"
        Logger.shared.warning("cancelCurrentOperation : reset manuel de isProcessing")
        // Libère le modèle TTS du daemon — sinon il reste résident jusqu'à l'idle timeout
        Task { await TTSDaemon.shared.stop() }
    }


    func generateSingleChapter(at index: Int) async {
        guard let project = project,
              index < project.chapters.count,
              project.voiceConfig.hasValidReference else { return }
        
        let chapter = project.chapters[index]
        
        // Vérifier qu'il y a du texte (balisé ou brut)
        let textToGenerate = chapter.taggedText ?? chapter.rawText
        guard !textToGenerate.isEmpty else {
            errorMessage = "Le chapitre est vide"
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
            
            // Normalisation : si elle échoue on garde l'audio non normalisé
            do {
                try await audioService.normalizeAudio(filePath: chapterAudioPath)
            } catch {
                Logger.shared.warning("Normalisation échouée pour chapitre \(index + 1) : \(error.localizedDescription). Audio conservé non normalisé.")
            }

            updatedProject.chapters[index].audioFilePath = chapterAudioPath
            updatedProject.chapters[index].status = .audioReady

            // Nettoyage ciblé (uniquement les chunks de ce chapitre)
            chunkCleaner.cleanChunksForChapter(
                in: updatedProject.projectDirectory,
                chapterIndex: chapter.index,
                keepChunks: false
            )

            // Sauvegarder
            projectManager.updateProject(updatedProject)
            self.project = updatedProject

            progress = 1.0
            progressText = "Chapitre \(index + 1) généré ✓"
            errorMessage = nil  // efface une éventuelle erreur précédente sur ce chapitre
            
        } catch {
            updatedProject.chapters[index].status = .error
            errorMessage = "Erreur chapitre \(index + 1): \(error.localizedDescription)"
            showError = true
            projectManager.updateProject(updatedProject)
            self.project = updatedProject
        }
        
        isProcessing = false
    }
    
    func resetChapter(at index: Int) {
        guard var project = project,
              index < project.chapters.count else { return }
        
        // Supprimer le fichier audio si il existe
        if let audioPath = project.chapters[index].audioFilePath {
            try? FileManager.default.removeItem(atPath: audioPath)
        }
        
        // Réinitialiser le statut
        project.chapters[index].audioFilePath = nil
        project.chapters[index].status = .tagged
        
        projectManager.updateProject(project)
        self.project = project
        
        print("🔄 Chapitre \(index + 1) réinitialisé")
    }
    
    func resetAllChapters() {
        guard var project = project else { return }
        
        for index in 0..<project.chapters.count {
            if let audioPath = project.chapters[index].audioFilePath {
                try? FileManager.default.removeItem(atPath: audioPath)
            }
            
            if project.chapters[index].status == .audioReady {
                project.chapters[index].audioFilePath = nil
                project.chapters[index].status = .tagged
            }
        }
        
        projectManager.updateProject(project)
        self.project = project
        
        print("🔄 Tous les chapitres réinitialisés")
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
            // Note : on N'utilise PAS UNUserNotificationCenter ici. Dans une app
            // Swift buildée via `swift build` (pas Xcode signed), l'appel à
            // requestAuthorization bloque le thread principal jusqu'au crash
            // par watchdog macOS. Le feedback UI dans ExportStepView (statut
            // "Projet exporté avec succès !") est largement suffisant.

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
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

            // Ouvrir le fichier dans le Finder (le feedback visuel est suffisant,
            // pas besoin de notification système qui crashe dans cette build).
            NSWorkspace.shared.selectFile(outputPath, inFileViewerRootedAtPath: "")

        } catch {
            errorMessage = "Erreur lors de l'export : \(error.localizedDescription)"
            showError = true
        }
        
        isProcessing = false
    }
}
