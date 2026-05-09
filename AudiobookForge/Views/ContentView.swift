import SwiftUI

/// Vue principale avec NavigationSplitView
struct ContentView: View {
    @EnvironmentObject private var projectListVM: ProjectListViewModel
    @StateObject private var pipelineVM = PipelineViewModel()
    @State private var selectedProject: Project?
    @State private var showDependencySheet = false

    var body: some View {
        NavigationSplitView {
            // Panneau gauche : liste des projets
            ProjectListView(selectedProject: $selectedProject)
                .environmentObject(projectListVM)
        } content: {
            // Panneau central : pipeline
            if let project = selectedProject {
                PipelineView()
                    .environmentObject(pipelineVM)
                    .onAppear {
                        pipelineVM.loadProject(project)
                    }
                    .onChange(of: selectedProject) { _, newProject in
                        if let newProject = newProject {
                            pipelineVM.loadProject(newProject)
                        }
                    }
            } else {
                EmptyPipelineView()
            }
        } detail: {
            // Panneau droit : paramètres contextuels
            if let project = selectedProject {
                ContextualSettingsView()
                    .environmentObject(pipelineVM)
            } else {
                EmptySettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $projectListVM.showImportSheet) {
            ImportFileView()
                .environmentObject(projectListVM)
        }
        .sheet(isPresented: $showDependencySheet) {
            DependencyCheckView()
                .environmentObject(projectListVM)
        }
        .onAppear {
            projectListVM.loadProjects()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { showDependencySheet = true }) {
                    Image(systemName: "wrench.adjustable")
                }
                .help("Vérifier les dépendances")
            }
        }
    }
}

// MARK: - Vue vide quand aucun projet n'est sélectionné

struct EmptyPipelineView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("AudiobookForge")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Sélectionnez un projet ou importez un fichier")
                .foregroundColor(.secondary)
        }
    }
}

struct EmptySettingsView: View {
    var body: some View {
        VStack {
            Image(systemName: "gearshape")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Paramètres")
                .foregroundColor(.secondary)
        }
    }
}
