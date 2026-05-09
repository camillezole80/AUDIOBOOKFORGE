import Foundation

/// Gestionnaire de projets — persistance, création, reprise
class ProjectManager: ObservableObject {
    static let shared = ProjectManager()

    @Published var projects: [Project] = []
    @Published var currentProject: Project?

    private let projectsDirectory: String

    private init() {
        let baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AudiobookForge")
            .path

        projectsDirectory = "\(baseDir)/Projects"

        try? FileManager.default.createDirectory(
            atPath: projectsDirectory,
            withIntermediateDirectories: true
        )

        loadProjects()
    }

    // MARK: - Project CRUD

    func createProject(name: String, sourcePath: String, fileType: FileType) throws -> Project {
        let project = Project.createDefault(name: name, sourcePath: sourcePath, fileType: fileType)

        // Créer la structure de dossiers du projet
        try createProjectDirectories(project: project)

        // Copier le fichier source
        let destPath = "\(project.projectDirectory)/source.\(fileType.rawValue.lowercased())"
        try FileManager.default.copyItem(atPath: sourcePath, toPath: destPath)

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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try? process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }

    private func checkOllama() async -> (running: Bool, modelAvailable: Bool) {
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            return (false, false)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return (false, false)
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let models = json?["models"] as? [[String: Any]] {
                let hasQwen = models.contains { ($0["name"] as? String)?.hasPrefix("qwen3") ?? false }
                return (true, hasQwen)
            }
            return (true, false)
        } catch {
            return (false, false)
        }
    }

    private func checkFishModel() async -> Bool {
        // Chercher le modèle dans le dossier backend/models/
        let bundlePath = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        let modelPath = "\(bundlePath)/backend/models/fishaudio-s2-pro-8bit-mlx"
        return FileManager.default.fileExists(atPath: modelPath)
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
