import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// ViewModel pour l'écran d'accueil (liste des projets)
@MainActor
class ProjectListViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var showImportSheet = false
    @Published var isImporting = false
    @Published var importError: String?
    @Published var showDependencyCheck = false
    @Published var dependencyStatus: ProjectManager.DependencyStatus?

    private let projectManager = ProjectManager.shared

    func loadProjects() {
        projects = projectManager.projects
    }

    @Published var lastImportedProject: Project?

    func importFile(url: URL) {
        isImporting = true
        importError = nil

        let fileType: FileType
        switch url.pathExtension.lowercased() {
        case "epub":
            fileType = .epub
        case "pdf":
            fileType = .pdf
        case "docx":
            fileType = .docx
        default:
            importError = "Format de fichier non supporté. Utilisez EPUB, PDF ou DOCX."
            isImporting = false
            return
        }

        let projectName = url.deletingPathExtension().lastPathComponent

        do {
            let project = try projectManager.createProject(
                name: projectName,
                sourcePath: url.path,
                fileType: fileType
            )
            projects.append(project)
            lastImportedProject = project
            isImporting = false
        } catch {
            print("❌ IMPORT ERROR: \(error)")
            importError = "Erreur lors de l'import : \(error.localizedDescription)"
            isImporting = false
        }
    }

    func deleteProject(_ project: Project) {
        projectManager.deleteProject(project)
        loadProjects()
    }

    func checkDependencies() async {
        dependencyStatus = await projectManager.checkDependencies()
        showDependencyCheck = true
    }
}
