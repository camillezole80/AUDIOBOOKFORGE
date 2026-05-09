import SwiftUI

/// Panneau central : pipeline en étapes
struct PipelineView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Barre d'étapes horizontale
            StepBarView(currentStep: pipelineVM.currentStep)

            // Contenu de l'étape active
            ScrollView {
                VStack(spacing: 20) {
                    switch pipelineVM.currentStep {
                    case .import_:
                        ImportStepView()
                    case .tags:
                        TagsStepView()
                    case .voice:
                        VoiceStepView()
                    case .generation:
                        GenerationStepView()
                    case .export:
                        ExportStepView()
                    }

                    // Logs rétractables
                    if pipelineVM.progressText != "" || pipelineVM.errorMessage != nil {
                        LogPanelView()
                    }
                }
                .padding()
            }
        }
        .alert("Erreur", isPresented: $pipelineVM.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pipelineVM.errorMessage ?? "Erreur inconnue")
        }
    }
}

// MARK: - Barre d'étapes

struct StepBarView: View {
    let currentStep: PipelineViewModel.PipelineStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PipelineViewModel.PipelineStep.allCases, id: \.self) { step in
                StepItemView(
                    step: step,
                    isActive: step == currentStep,
                    isCompleted: step.rawValue < currentStep.rawValue,
                    isBlocked: step.rawValue > currentStep.rawValue + 1
                )

                if step.rawValue < PipelineViewModel.PipelineStep.allCases.count - 1 {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? Color.green : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 30)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct StepItemView: View {
    let step: PipelineViewModel.PipelineStep
    let isActive: Bool
    let isCompleted: Bool
    let isBlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: step.icon)
                        .font(.caption)
                        .foregroundColor(iconColor)
                }
            }

            Text(step.title)
                .font(.caption2)
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var backgroundColor: Color {
        if isCompleted { return .green }
        if isActive { return Color.accentColor }
        return Color.gray.opacity(0.2)
    }

    private var iconColor: Color {
        if isActive { return .white }
        return .secondary
    }
}

// MARK: - Panneau de logs

struct LogPanelView: View {
    @EnvironmentObject private var pipelineVM: PipelineViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "terminal")
                    Text("Logs")
                        .font(.caption)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if !pipelineVM.progressText.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(pipelineVM.progressText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if pipelineVM.isProcessing {
                        ProgressView(value: pipelineVM.progress)
                            .progressViewStyle(.linear)
                    }

                    if let error = pipelineVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
