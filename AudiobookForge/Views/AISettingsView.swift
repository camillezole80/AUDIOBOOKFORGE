import SwiftUI

/// Vue de configuration des paramètres IA (Ollama local vs API distantes)
struct AISettingsView: View {
    @Binding var aiConfig: AIConfig
    @Environment(\.dismiss) private var dismiss
    
    // Utiliser @State local pour éviter les problèmes de binding
    @State private var localProvider: AIProvider
    @State private var localForceRemote: Bool
    @State private var localFallbackToRemote: Bool
    @State private var localShowCostEstimate: Bool
    
    @State private var openaiKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var deepseekKey: String = ""
    
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false
    @State private var showDeepSeekKey = false
    
    @State private var isTestingConnection = false
    @State private var testResult: String?
    @State private var estimatedCost: (tokens: Int, cost: Double)?
    
    private let keychain = KeychainHelper.shared
    private let remoteAI = RemoteAIService.shared
    
    init(aiConfig: Binding<AIConfig>) {
        self._aiConfig = aiConfig
        // Initialiser les @State avec les valeurs actuelles
        self._localProvider = State(initialValue: aiConfig.wrappedValue.preferredProvider)
        self._localForceRemote = State(initialValue: aiConfig.wrappedValue.forceRemote)
        self._localFallbackToRemote = State(initialValue: aiConfig.wrappedValue.fallbackToRemote)
        self._localShowCostEstimate = State(initialValue: aiConfig.wrappedValue.showCostEstimate)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // En-tête
            VStack(spacing: 8) {
                Image(systemName: "brain")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                
                Text("Configuration IA")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choisissez votre provider d'enrichissement")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView {
                VStack(spacing: 20) {
                    // Sélection du provider
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Provider préféré")
                            .font(.headline)
                        
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            ProviderRow(
                                provider: provider,
                                isSelected: localProvider == provider,
                                action: { localProvider = provider }
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Clés API
                    if localProvider.requiresAPIKey {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Clés API")
                                .font(.headline)
                            
                            APIKeyField(
                                provider: .openai,
                                key: $openaiKey,
                                showKey: $showOpenAIKey,
                                isActive: localProvider == .openai
                            )
                            
                            APIKeyField(
                                provider: .anthropic,
                                key: $anthropicKey,
                                showKey: $showAnthropicKey,
                                isActive: localProvider == .anthropic
                            )
                            
                            APIKeyField(
                                provider: .deepseek,
                                key: $deepseekKey,
                                showKey: $showDeepSeekKey,
                                isActive: localProvider == .deepseek
                            )
                        }
                        
                        Divider()
                    }
                    
                    // Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Options")
                            .font(.headline)
                        
                        Toggle("Forcer l'enrichissement distant", isOn: $localForceRemote)
                            .help("Utiliser uniquement l'API distante, même si Ollama est disponible")
                        
                        Toggle("Fallback automatique", isOn: $localFallbackToRemote)
                            .help("Basculer automatiquement sur l'API distante si Ollama échoue")
                            .disabled(localForceRemote)
                        
                        Toggle("Afficher l'estimation des coûts", isOn: $localShowCostEstimate)
                    }
                    
                    // Estimation des coûts
                    if localShowCostEstimate && localProvider != .ollama {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Estimation des coûts")
                                .font(.headline)
                            
                            HStack {
                                Image(systemName: "dollarsign.circle")
                                    .foregroundColor(.orange)
                                Text("\(localProvider.costPer1KTokens, specifier: "%.3f")$ / 1K tokens")
                                    .font(.caption)
                            }
                            
                            Text("Pour un livre de 500K tokens : ~\(localProvider.costPer1KTokens * 500, specifier: "%.2f")$")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Test de connexion
                    if testResult != nil {
                        HStack {
                            Image(systemName: testResult == "✅" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(testResult == "✅" ? .green : .red)
                            Text(testResult == "✅" ? "Connexion réussie" : "Échec de la connexion")
                                .font(.caption)
                        }
                        .padding()
                        .background(testResult == "✅" ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            // Boutons d'action
            HStack(spacing: 16) {
                if localProvider.requiresAPIKey {
                    Button("Tester la connexion") {
                        Task {
                            await testConnection()
                        }
                    }
                    .disabled(isTestingConnection || getCurrentAPIKey().isEmpty)
                    .buttonStyle(.bordered)
                }
                
                Button("Sauvegarder") {
                    saveKeys()
                    // Appliquer les changements
                    aiConfig.preferredProvider = localProvider
                    aiConfig.forceRemote = localForceRemote
                    aiConfig.fallbackToRemote = localFallbackToRemote
                    aiConfig.showCostEstimate = localShowCostEstimate
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Annuler") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
        }
        .padding(30)
        .frame(width: 550, height: 650)
        .onAppear {
            loadKeys()
        }
    }
    
    // MARK: - Helpers
    
    private func loadKeys() {
        openaiKey = keychain.get(for: .openai) ?? ""
        anthropicKey = keychain.get(for: .anthropic) ?? ""
        deepseekKey = keychain.get(for: .deepseek) ?? ""
    }
    
    private func saveKeys() {
        if !openaiKey.isEmpty {
            _ = keychain.save(key: openaiKey, for: .openai)
        }
        if !anthropicKey.isEmpty {
            _ = keychain.save(key: anthropicKey, for: .anthropic)
        }
        if !deepseekKey.isEmpty {
            _ = keychain.save(key: deepseekKey, for: .deepseek)
        }
    }
    
    private func getCurrentAPIKey() -> String {
        switch localProvider {
        case .openai: return openaiKey
        case .anthropic: return anthropicKey
        case .deepseek: return deepseekKey
        case .ollama: return ""
        }
    }
    
    private func testConnection() async {
        isTestingConnection = true
        testResult = nil
        
        let key = getCurrentAPIKey()
        
        do {
            let success = await remoteAI.testConnection(provider: localProvider, apiKey: key)
            
            await MainActor.run {
                testResult = success ? "✅" : "❌"
                isTestingConnection = false
            }
        } catch {
            await MainActor.run {
                testResult = "❌"
                isTestingConnection = false
                print("❌ Test de connexion échoué: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Provider Row

struct ProviderRow: View {
    let provider: AIProvider
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if provider != .ollama {
                    Text("\(provider.costPer1KTokens, specifier: "%.3f")$ / 1K tokens")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Gratuit - Local")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            if provider == .deepseek {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

// MARK: - API Key Field

struct APIKeyField: View {
    let provider: AIProvider
    @Binding var key: String
    @Binding var showKey: Bool
    let isActive: Bool
    
    private let keychain = KeychainHelper.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(provider.displayName)
                    .font(.subheadline)
                    .fontWeight(isActive ? .semibold : .regular)
                
                if keychain.hasKey(for: provider) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            HStack {
                if showKey {
                    TextField("Clé API", text: $key)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Clé API", text: $key)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help(showKey ? "Masquer" : "Révéler")
            }
        }
        .opacity(isActive ? 1.0 : 0.6)
    }
}
