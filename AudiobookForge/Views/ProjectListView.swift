import SwiftUI

/// Panneau gauche : liste des projets
struct ProjectListView: View {
    @EnvironmentObject private var projectListVM: ProjectListViewModel
    @Binding var selectedProject: Project?

    var body: some View {
        List(selection: $selectedProject) {
            ForEach(projectListVM.projects) { project in
                ProjectRowView(project: project)
                    .tag(project)
                    .contextMenu {
                        Button("Ouvrir") {
                            selectedProject = project
                        }
                        Divider()
                        Button("Supprimer", role: .destructive) {
                            projectListVM.deleteProject(project)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Projets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { projectListVM.showImportSheet = true }) {
                    Image(systemName: "plus")
                }
                .help("Nouveau projet")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                projectListVM.importFile(url: url)
            }
        }
    }
}

/// Ligne d'un projet dans la liste
struct ProjectRowView: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            // Icône du type de fichier
            Image(systemName: fileTypeIcon)
                .font(.title3)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.metadata.title.isEmpty ? project.name : project.metadata.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(project.sourceFileType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)

                    Text(project.status.rawValue)
                        .font(.caption)
                        .foregroundColor(statusColor)

                    if project.progressPercentage > 0 {
                        Text("\(Int(project.progressPercentage))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Barre de progression
            if project.progressPercentage > 0 && project.progressPercentage < 100 {
                ProgressView(value: project.progressPercentage / 100)
                    .frame(width: 40)
            } else if project.progressPercentage >= 100 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var fileTypeIcon: String {
        switch project.sourceFileType {
        case .epub: return "book"
        case .pdf: return "doc.richtext"
        case .docx: return "doc.text"
        }
    }

    private var statusColor: Color {
        switch project.status {
        case .error: return .red
        case .exported: return .green
        default: return .secondary
        }
    }
}
