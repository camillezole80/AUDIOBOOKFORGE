import Foundation

/// Gestionnaire de projets — persistance, création, reprise
class ProjectManager: ObservableObject {
    static let shared = ProjectManager()

    @Published var projects: [Project] = []
    @Published var currentProject: Project?

    private let projectsDirectory: String
    private let pathResolver = PathResolver.shared
    private let logger = Logger.shared

    private init() {
        let baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AudiobookForge")
            .path

        projectsDirectory = "\(baseDir)/Projects"

        try? FileManager.default.createDirectory(
            atPath: projectsDirectory,
            withIntermediateDirectories: true
        )

        logger.info("ProjectManager initialized. Projects directory: \(projectsDirectory)")
        loadProjects()
    }

    // MARK: - Project CRUD

    func createProject(name: String, sourcePath: String, fileType: FileType) throws -> Project {
        let project = Project.createDefault(name: name, sourcePath: sourcePath, fileType: fileType)

        // Créer la structure de dossiers du projet
        try createProjectDirectories(project: project)

        // Copier le fichier source
        let destPath = "\(project.projectDirectory)/source.\(fileType.rawValue.lowercased())"
        let sourceURL = URL(fileURLWithPath: sourcePath)

        // Accès sécurisé au fichier (NSOpenPanel sandbox)
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        if !FileManager.default.fileExists(atPath: destPath) {
            try FileManager.default.copyItem(atPath: sourcePath, toPath: destPath)
        }

        var mutableProject = project
        mutableProject.sourceFilePath = destPath

        projects.append(mutableProject)
        saveProject(mutableProject)
        saveProjectsList()

        return mutableProject
    }

    func loadProject(_ project: Project) {
        currentProject = project
        loadProjectState(project)
    }

    func deleteProject(_ project: Project) {
        try? FileManager.default.removeItem(atPath: project.projectDirectory)
        projects.removeAll { $0.id == project.id }
        saveProjectsList()

        if currentProject?.id == project.id {
            currentProject = nil
        }
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            var updated = project
            updated.updatedAt = Date()
            projects[index] = updated
            saveProject(updated)
            saveProjectsList()

            if currentProject?.id == project.id {
                currentProject = updated
            }
        }
    }

    // MARK: - Persistence

    private func loadProjects() {
        let listPath = "\(projectsDirectory)/projects.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: listPath)),
              let decoded = try? JSONDecoder().decode([Project].self, from: data) else {
            return
        }
        projects = decoded
    }

    private func saveProjectsList() {
        let listPath = "\(projectsDirectory)/projects.json"
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: URL(fileURLWithPath: listPath))
    }

    private func saveProject(_ project: Project) {
        let projectStatePath = "\(project.projectDirectory)/project.json"
        guard let data = try? JSONEncoder().encode(project) else { return }
        try? data.write(to: URL(fileURLWithPath: projectStatePath))
    }

    private func loadProjectState(_ project: Project) {
        let projectStatePath = "\(project.projectDirectory)/project.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: projectStatePath)),
              let decoded = try? JSONDecoder().decode(Project.self, from: data) else {
            return
        }

        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = decoded
            currentProject = decoded
        }
    }

    // MARK: - Directory Structure

    private func createProjectDirectories(project: Project) throws {
        let dirs = [
            project.projectDirectory,
            "\(project.projectDirectory)/text",
            "\(project.projectDirectory)/audio",
            "\(project.projectDirectory)/audio/chunks",
            "\(project.projectDirectory)/audio/chapters",
            "\(project.projectDirectory)/export"
        ]

        for dir in dirs {
            try FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )
        }
    }

    // MARK: - Dependency Check

    struct DependencyStatus {
        let ffmpegInstalled: Bool
        let ollamaRunning: Bool
        let qwenModelAvailable: Bool
        let fishModelAvailable: Bool

        var allMet: Bool {
            ffmpegInstalled && ollamaRunning && qwenModelAvailable && fishModelAvailable
        }
    }

    func checkDependencies() async -> DependencyStatus {
        let ffmpeg = await checkFFmpeg()
        let (ollama, qwen) = await checkOllama()
        let fish = await checkFishModel()

        return DependencyStatus(
            ffmpegInstalled: ffmpeg,
            ollamaRunning: ollama,
            qwenModelAvailable: qwen,
            fishModelAvailable: fish
        )
    }

    private func checkFFmpeg() async -> Bool {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        // Dernier recours : via which
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "ffmpeg"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }


    private func checkOllama() async -> (running: Bool, modelAvailable: Bool) {
        logger.debug("Checking Ollama availability...")
        
        // D'abord, vérifier si l'API HTTP répond
        var apiRunning = false
        var hasQwenViaAPI = false
        
        if let url = URL(string: "http://localhost:11434/api/tags") {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    apiRunning = true
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let models = json["models"] as? [[String: Any]] {
                        hasQwenViaAPI = models.contains { 
                            if let name = $0["name"] as? String {
                                return name.hasPrefix("qwen2.5") || name.hasPrefix("qwen3")
                            }
                            return false
                        }
                    }
                }
            } catch {
                logger.debug("Ollama API not accessible, trying CLI...")
            }
        }

        // Fallback CLI : ollama list (marche même si l'API est boguée dans les vieilles versions)
        if !hasQwenViaAPI {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pathResolver.ollamaPath)
            process.arguments = ["list"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try? process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let hasQwen = output.contains("qwen2.5") || output.contains("qwen3")
                logger.info("Ollama check via CLI: running=true, qwen3=\(hasQwen)")
                return (true, hasQwen)
            }
        }
        
        logger.info("Ollama check: running=\(apiRunning), qwen3=\(hasQwenViaAPI)")
        return (apiRunning, hasQwenViaAPI)
    }

    private func checkFishModel() async -> Bool {
        logger.debug("Checking Fish S2 Pro model (mlx-speech)...")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pathResolver.pythonPath)
        process.arguments = ["-c", "import mlx_speech; print('OK')"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try? process.run()
        process.waitUntilExit()
        
        let available = process.terminationStatus == 0
        logger.info("Fish S2 Pro model check: \(available ? "available" : "not available")")
        return available
    }

    // MARK: - Save/Load Chapter Text

    func saveChapterText(project: Project, chapter: Chapter) throws {
        let textDir = "\(project.projectDirectory)/text"

        let rawPath = "\(textDir)/chapter_\(String(format: "%02d", chapter.index)).txt"
        try chapter.rawText.write(toFile: rawPath, atomically: true, encoding: .utf8)

        if let tagged = chapter.taggedText {
            let taggedPath = "\(textDir)/chapter_\(String(format: "%02d", chapter.index))_tagged.txt"
            try tagged.write(toFile: taggedPath, atomically: true, encoding: .utf8)
        }
    }
}
