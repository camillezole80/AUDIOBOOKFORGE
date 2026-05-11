import SwiftUI

/// Vue principale avec NavigationSplitView
struct ContentView: View {
    @EnvironmentObject private var projectListVM: ProjectListViewModel
    @StateObject private var pipelineVM = PipelineViewModel()
    @State private var selectedProject: Project?
    @State private var showDependencySheet = false
    @State private var showAISettingsSheet = false

    var body: some View {
        NavigationSplitView {
            // Panneau gauche : liste des projets
            ProjectListView(selectedProject: $selectedProject)
                .environmentObject(projectListVM)
        } content: {
            // Panneau central : pipeline
            if selectedProject != nil {
                PipelineView()
                    .environmentObject(pipelineVM)
                    .onAppear {
                        if let project = selectedProject {
                            pipelineVM.loadProject(project)
                        }
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
            if selectedProject != nil {
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
        .sheet(isPresented: $showAISettingsSheet) {
            if var project = selectedProject {
                AISettingsView(aiConfig: Binding(
                    get: { project.aiConfig },
                    set: { newConfig in
                        project.aiConfig = newConfig
                        ProjectManager.shared.updateProject(project)
                        selectedProject = project
                    }
                ))
            }
        }
        .onAppear {
            projectListVM.loadProjects()
        }
        .onChange(of: projectListVM.lastImportedProject) { _, newProject in
            if let newProject = newProject {
                selectedProject = newProject
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { showDependencySheet = true }) {
                    Image(systemName: "wrench.adjustable")
                }
                .help("Vérifier les dépendances")
            }
            
            ToolbarItem(placement: .navigation) {
                Button(action: { showAISettingsSheet = true }) {
                    Image(systemName: "brain")
                }
                .help("Configuration IA")
                .disabled(selectedProject == nil)
            }
        }
    }
}

// MARK: - Vue vide quand aucun projet n'est sélectionné

struct EmptyPipelineView: View {
    @EnvironmentObject private var projectListVM: ProjectListViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("AudiobookForge")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("v0.6.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Text("Créez votre premier audiobook")
                .foregroundColor(.secondary)
            
            Button(action: { projectListVM.showImportSheet = true }) {
                Label("Nouveau projet", systemImage: "plus.circle.fill")
                    .font(.title2)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("ou glissez-déposez un fichier EPUB/PDF/DOCX")
                .font(.caption)
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
