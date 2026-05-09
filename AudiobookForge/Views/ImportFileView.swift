import SwiftUI
import UniformTypeIdentifiers

/// Vue d'import de fichier (Drag & drop ou sélecteur)
struct ImportFileView: View {
    @EnvironmentObject private var projectListVM: ProjectListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)

            Text("Importer un fichier")
                .font(.title2)
                .fontWeight(.semibold)

            Text("EPUB, PDF ou DOCX")
                .foregroundColor(.secondary)

            // Zone de drop
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isTargeted ? Color.accentColor : Color.gray.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .frame(width: 300, height: 150)

                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc")
                        .font(.largeTitle)
                        .foregroundColor(isTargeted ? .accentColor : .secondary)

                    Text("Glissez-déposez un fichier ici")
                        .foregroundColor(.secondary)

                    Text("ou")
                        .foregroundColor(.secondary)

                    Button("Parcourir...") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [
                            UTType(filenameExtension: "epub") ?? .data,
                            UTType(filenameExtension: "pdf") ?? .data,
                            UTType(filenameExtension: "docx") ?? .data
                        ]
                        panel.allowsMultipleSelection = false

                        if panel.runModal() == .OK, let url = panel.url {
                            projectListVM.importFile(url: url)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }

            if projectListVM.isImporting {
                ProgressView("Import en cours...")
            }

            if let error = projectListVM.importError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
            }

            Button("Annuler") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding(40)
        .frame(width: 400)
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                projectListVM.importFile(url: url)
                if projectListVM.importError == nil {
                    dismiss()
                }
            }
        }
    }
}
