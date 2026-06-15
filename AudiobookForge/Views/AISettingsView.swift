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
    @State private var localDeepSeekModel: String
    
    @State private var openaiKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var deepseekKey: String = ""
    
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false
    @State private var showDeepSeekKey = false
    
    @State private var isTestingConnection = false
    @State private var testResult: String?
    @State private var estimatedCost: (tokens: Int, cost: Double)?
    @State private var saveStatus: String?  // feedback inline après clic sur "Sauvegarder"
    @State private var saveStatusColor: Color = .green
    
    private let keychain = KeychainHelper.shared
    private let remoteAI = RemoteAIService.shared
    
    init(aiConfig: Binding<AIConfig>) {
        self._aiConfig = aiConfig
        // Initialiser les @State avec les valeurs actuelles
        self._localProvider = State(initialValue: aiConfig.wrappedValue.preferredProvider)
        self._localForceRemote = State(initialValue: aiConfig.wrappedValue.forceRemote)
        self._localFallbackToRemote = State(initialValue: aiConfig.wrappedValue.fallbackToRemote)
        self._localShowCostEstimate = State(initialValue: aiConfig.wrappedValue.showCostEstimate)
        self._localDeepSeekModel = State(initialValue: aiConfig.wrappedValue.deepseekModel)
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

                            if localProvider == .deepseek {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Modèle DeepSeek")
                                        .font(.subheadline)
                                    TextField("deepseek-v4-flash", text: $localDeepSeekModel)
                                        .textFieldStyle(.roundedBorder)
                                    Text("Modèle recommandé : deepseek-v4-flash")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
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
                    if commitChanges() {
                        // On dismiss seulement si tout s'est bien passé.
                        // Sinon on garde la sheet ouverte avec le message d'erreur visible.
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)

                Button("Annuler") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }

            // Feedback inline après tentative de sauvegarde
            if let status = saveStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(saveStatusColor)
                    .padding(.top, 4)
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
    
    /// Sauvegarde toutes les clés API non vides dans le Keychain.
    /// Retourne la liste des providers dont la sauvegarde a ÉCHOUÉ (à signaler à l'utilisateur).
    private func saveKeys() -> [AIProvider] {
        var failed: [AIProvider] = []

        func saveIfNonEmpty(_ key: String, for provider: AIProvider) {
            guard !key.isEmpty else { return }
            let ok = keychain.save(key: key, for: provider)
            if !ok {
                failed.append(provider)
                print("❌ Échec keychain.save pour \(provider.rawValue)")
            } else {
                // Vérification post-write : on relit immédiatement pour s'assurer
                // que la clé est bien lisible (utile pour diagnostiquer les bugs
                // de Keychain dans une app non signée).
                let retrieved = keychain.get(for: provider)
                if retrieved != key {
                    failed.append(provider)
                    print("❌ keychain.save pour \(provider.rawValue) : SecItemAdd OK mais lecture incorrecte (\(retrieved?.prefix(10) ?? "nil"))")
                } else {
                    print("✅ Clé sauvegardée pour \(provider.rawValue) (\(key.count) caractères)")
                }
            }
        }

        saveIfNonEmpty(openaiKey, for: .openai)
        saveIfNonEmpty(anthropicKey, for: .anthropic)
        saveIfNonEmpty(deepseekKey, for: .deepseek)

        return failed
    }

    /// Sauvegarde + persiste l'AIConfig en UNE seule écriture du binding.
    /// Retourne true si tout est OK et la sheet peut être dismissée.
    private func commitChanges() -> Bool {
        // 1. Sauvegarder les clés (retourne ceux qui ont échoué)
        let failedProviders = saveKeys()

        // 2. Vérifier qu'on a bien la clé pour le provider sélectionné si nécessaire
        if localProvider.requiresAPIKey {
            let currentKey = getCurrentAPIKey()
            if currentKey.isEmpty {
                saveStatus = "⚠️ La clé API pour \(localProvider.displayName) est vide. Saisissez-la avant de sauvegarder."
                saveStatusColor = .orange
                return false
            }
            if failedProviders.contains(localProvider) {
                saveStatus = "❌ Impossible de sauvegarder la clé \(localProvider.displayName) dans le Trousseau macOS. Vérifiez les permissions de l'app."
                saveStatusColor = .red
                return false
            }
        }

        // 3. Single-write : on regroupe les 4 mutations en un seul commit du binding.
        // Sinon chaque `aiConfig.X = Y` lit l'aiConfig, modifie un champ, écrit le tout —
        // ce qui dans certaines configurations de binding peut perdre les mutations
        // précédentes. Une écriture unique est sûre.
        var newConfig = aiConfig
        newConfig.preferredProvider = localProvider
        newConfig.forceRemote = localForceRemote
        newConfig.fallbackToRemote = localFallbackToRemote
        newConfig.showCostEstimate = localShowCostEstimate
        newConfig.deepseekModel = localDeepSeekModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "deepseek-v4-flash"
            : localDeepSeekModel.trimmingCharacters(in: .whitespacesAndNewlines)
        aiConfig = newConfig

        // Log de confirmation
        print("✅ AIConfig persisté : provider=\(newConfig.preferredProvider.rawValue), forceRemote=\(newConfig.forceRemote), fallback=\(newConfig.fallbackToRemote)")

        if !failedProviders.isEmpty {
            saveStatus = "⚠️ Clés sauvegardées sauf : \(failedProviders.map { $0.displayName }.joined(separator: ", "))"
            saveStatusColor = .orange
            // On laisse la sheet ouverte pour que l'utilisateur voie le message
            return false
        }

        return true
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
        
        let success: Bool
        if localProvider == .deepseek {
            success = await remoteAI.testDeepSeekConnection(apiKey: key)
        } else {
            success = await remoteAI.testConnection(provider: localProvider, apiKey: key)
        }

        await MainActor.run {
            testResult = success ? "✅" : "❌"
            isTestingConnection = false
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
