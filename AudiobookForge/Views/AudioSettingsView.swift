import SwiftUI

/// Vue de configuration des paramètres audio (Local MLX vs Fish.Audio API)
struct AudioSettingsView: View {
    @Binding var voiceConfig: VoiceConfig
    @Environment(\.dismiss) private var dismiss
    
    // Utiliser @State local pour éviter les problèmes de binding
    @State private var localProvider: AudioProvider
    @State private var localForceRemote: Bool
    @State private var localFallbackToRemote: Bool
    
    @State private var fishAudioKey: String = ""
    @State private var showFishAudioKey = false
    
    @State private var isTestingConnection = false
    @State private var testResult: String?
    @State private var estimatedCost: (bytes: Int, cost: Double)?
    
    @State private var showCreateReferenceSheet = false
    @State private var referenceId: String = ""
    
    // Sélecteur de voix Fish.Audio
    @State private var availableVoices: [FishAudioVoice] = []
    @State private var isLoadingVoices = false
    @State private var selectedVoiceId: String?
    @State private var voiceSearchText: String = ""
    @State private var selectedLanguageFilter: String = "Toutes"
    @State private var selectedGenderFilter: String = "Tous"
    
    private let keychain = KeychainHelper.shared
    private let remoteAudio = RemoteAudioService.shared
    
    init(voiceConfig: Binding<VoiceConfig>) {
        self._voiceConfig = voiceConfig
        // Initialiser les @State avec les valeurs actuelles
        self._localProvider = State(initialValue: voiceConfig.wrappedValue.preferredProvider)
        self._localForceRemote = State(initialValue: voiceConfig.wrappedValue.forceRemote)
        self._localFallbackToRemote = State(initialValue: voiceConfig.wrappedValue.fallbackToRemote)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // En-tête
            VStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                
                Text("Configuration Audio")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choisissez votre provider de génération audio")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView {
                VStack(spacing: 20) {
                    // Sélection du provider
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Provider préféré")
                            .font(.headline)
                        
                        ForEach(AudioProvider.allCases, id: \.self) { provider in
                            AudioProviderRow(
                                provider: provider,
                                isSelected: localProvider == provider,
                                action: { localProvider = provider }
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Clé API Fish.Audio
                    if localProvider.requiresAPIKey {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Clé API Fish.Audio")
                                .font(.headline)
                            
                            HStack {
                                if showFishAudioKey {
                                    TextField("sk-...", text: $fishAudioKey)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("sk-...", text: $fishAudioKey)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                Button(action: { showFishAudioKey.toggle() }) {
                                    Image(systemName: showFishAudioKey ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Button("Sauvegarder") {
                                    if !fishAudioKey.isEmpty {
                                        _ = keychain.save(key: fishAudioKey, for: .fishAudio)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(fishAudioKey.isEmpty)
                                
                                Button("Tester la connexion") {
                                    testConnection()
                                }
                                .buttonStyle(.bordered)
                                .disabled(fishAudioKey.isEmpty || isTestingConnection)
                            }
                            
                            if let result = testResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundColor(result.contains("✅") ? .green : .red)
                            }
                            
                            Text("Obtenez votre clé API sur fish.audio")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                    }
                    
                    // Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Options")
                            .font(.headline)
                        
                        Toggle("Forcer l'utilisation de l'API distante", isOn: $localForceRemote)
                            .disabled(localProvider == .local)
                        
                        Toggle("Fallback automatique vers l'API si local échoue", isOn: $localFallbackToRemote)
                            .disabled(localProvider == .fishAudio)
                        
                        Text("Si activé, l'app utilisera automatiquement Fish.Audio API si la génération locale échoue.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Sélecteur de voix Fish.Audio
                    if localProvider == .fishAudio {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Sélection de voix")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if !fishAudioKey.isEmpty {
                                    Button(action: { loadVoices() }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text(isLoadingVoices ? "Chargement..." : "Charger les voix")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(isLoadingVoices)
                                }
                            }
                            
                            if !availableVoices.isEmpty {
                                // Barre de recherche
                                TextField("🔍 Rechercher une voix...", text: $voiceSearchText)
                                    .textFieldStyle(.roundedBorder)
                                
                                // Filtres
                                HStack {
                                    Picker("Langue", selection: $selectedLanguageFilter) {
                                        Text("Toutes").tag("Toutes")
                                        ForEach(uniqueLanguages, id: \.self) { lang in
                                            Text(lang).tag(lang)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    
                                    Picker("Genre", selection: $selectedGenderFilter) {
                                        Text("Tous").tag("Tous")
                                        ForEach(uniqueGenders, id: \.self) { gender in
                                            Text(gender).tag(gender)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                // Liste des voix
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(filteredVoices) { voice in
                                            VoiceRow(
                                                voice: voice,
                                                isSelected: selectedVoiceId == voice.id,
                                                action: { selectedVoiceId = voice.id }
                                            )
                                        }
                                    }
                                }
                                .frame(height: 200)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                                
                                // Voix sélectionnée
                                if let selectedVoice = availableVoices.first(where: { $0.id == selectedVoiceId }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Voix sélectionnée : \(selectedVoice.name)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        if let description = selectedVoice.description {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            } else if fishAudioKey.isEmpty {
                                Text("Entrez votre clé API et testez la connexion pour charger les voix disponibles.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Voix sauvegardée
                    if localProvider == .fishAudio {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Voix sauvegardée (optionnel)")
                                .font(.headline)
                            
                            if let refId = voiceConfig.fishAudioReferenceId {
                                HStack {
                                    Text("ID : \(refId)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Supprimer") {
                                        voiceConfig.fishAudioReferenceId = nil
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            } else {
                                Button("Créer une voix sauvegardée") {
                                    showCreateReferenceSheet = true
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Text("Sauvegarder votre voix sur Fish.Audio permet d'économiser de la bande passante (pas besoin d'envoyer l'audio de référence à chaque chunk).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                    }
                    
                    // Estimation des coûts
                    if localProvider == .fishAudio {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Estimation des coûts")
                                .font(.headline)
                            
                            Text("$15 par million de bytes UTF-8")
                                .font(.subheadline)
                            
                            Text("≈ $7.50 pour un livre de 500 000 caractères")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let cost = estimatedCost {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Estimation pour ce projet :")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("\(cost.bytes) bytes → $\(String(format: "%.2f", cost.cost))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
            }
            
            // Boutons d'action
            HStack {
                Button("Annuler") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Enregistrer") {
                    saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
        .onAppear {
            loadAPIKeys()
            // Recharger les valeurs depuis le binding au cas où elles auraient changé
            localProvider = voiceConfig.preferredProvider
            localForceRemote = voiceConfig.forceRemote
            localFallbackToRemote = voiceConfig.fallbackToRemote
        }
        .sheet(isPresented: $showCreateReferenceSheet) {
            CreateReferenceView(
                voiceConfig: $voiceConfig,
                referenceId: $referenceId
            )
        }
    }
    
    // MARK: - Actions
    
    private func loadAPIKeys() {
        fishAudioKey = keychain.get(for: .fishAudio) ?? ""
    }
    
    private func saveSettings() {
        // Sauvegarder les paramètres locaux dans le binding
        voiceConfig.preferredProvider = localProvider
        voiceConfig.forceRemote = localForceRemote
        voiceConfig.fallbackToRemote = localFallbackToRemote
        
        // Sauvegarder la voix sélectionnée
        if let voiceId = selectedVoiceId {
            voiceConfig.selectedFishAudioVoice = voiceId
        }
        
        // Sauvegarder la clé API dans le keychain
        if !fishAudioKey.isEmpty {
            _ = keychain.save(key: fishAudioKey, for: .fishAudio)
        }
        
        // DEBUG
        print("🔧 AudioSettings sauvegardés:")
        print("  - preferredProvider: \(localProvider.rawValue)")
        print("  - forceRemote: \(localForceRemote)")
        print("  - fallbackToRemote: \(localFallbackToRemote)")
        print("  - selectedVoice: \(selectedVoiceId ?? "none")")
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        Task {
            do {
                let success = await remoteAudio.testConnection(apiKey: fishAudioKey)
                
                await MainActor.run {
                    testResult = success ? "✅ Connexion réussie" : "❌ Échec de la connexion"
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Échec de la connexion: \(error.localizedDescription)"
                    isTestingConnection = false
                    print("❌ Test de connexion Fish.Audio échoué: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadVoices() {
        isLoadingVoices = true
        
        Task {
            do {
                print("🔍 Chargement des voix Fish.Audio...")
                let voices = try await remoteAudio.fetchAvailableVoices(apiKey: fishAudioKey)
                
                await MainActor.run {
                    availableVoices = voices
                    isLoadingVoices = false
                    
                    print("✅ \(voices.count) voix chargées")
                    
                    // Charger la voix sélectionnée si elle existe
                    if let savedVoiceId = voiceConfig.selectedFishAudioVoice {
                        selectedVoiceId = savedVoiceId
                    }
                    
                    // Afficher un message si aucune voix n'est disponible
                    if voices.isEmpty {
                        testResult = "⚠️ Aucune voix disponible"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingVoices = false
                    testResult = "❌ Erreur: \(error.localizedDescription)"
                    print("❌ Erreur lors du chargement des voix: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var uniqueLanguages: [String] {
        Array(Set(availableVoices.map { $0.language })).sorted()
    }
    
    private var uniqueGenders: [String] {
        Array(Set(availableVoices.map { $0.gender })).sorted()
    }
    
    private var filteredVoices: [FishAudioVoice] {
        availableVoices.filter { voice in
            let matchesSearch = voiceSearchText.isEmpty || 
                voice.name.localizedCaseInsensitiveContains(voiceSearchText) ||
                (voice.description?.localizedCaseInsensitiveContains(voiceSearchText) ?? false)
            
            let matchesLanguage = selectedLanguageFilter == "Toutes" || voice.language == selectedLanguageFilter
            let matchesGender = selectedGenderFilter == "Tous" || voice.gender == selectedGenderFilter
            
            return matchesSearch && matchesLanguage && matchesGender
        }
    }
}

// MARK: - Voice Row

struct VoiceRow: View {
    let voice: FishAudioVoice
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Text(voice.gender)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(voice.language)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let style = voice.style {
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text(style)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Audio Provider Row

struct AudioProviderRow: View {
    let provider: AudioProvider
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(providerDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var providerDescription: String {
        switch provider {
        case .local:
            return "Génération locale via MLX (gratuit, nécessite un Mac avec GPU)"
        case .fishAudio:
            return "API Fish.Audio ($15/1M bytes, rapide, qualité constante)"
        }
    }
}

// MARK: - Create Reference View

struct CreateReferenceView: View {
    @Binding var voiceConfig: VoiceConfig
    @Binding var referenceId: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    private let keychain = KeychainHelper.shared
    private let remoteAudio = RemoteAudioService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Créer une voix sauvegardée")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Cela va uploader votre audio de référence sur Fish.Audio pour réutilisation.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("ID de la voix (ex: ma-voix-fr)", text: $referenceId)
                .textFieldStyle(.roundedBorder)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack {
                Button("Annuler") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Créer") {
                    createReference()
                }
                .buttonStyle(.borderedProminent)
                .disabled(referenceId.isEmpty || isCreating)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func createReference() {
        guard let apiKey = keychain.get(for: .fishAudio) else {
            errorMessage = "Clé API manquante"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let audioData = try Data(contentsOf: URL(fileURLWithPath: voiceConfig.referenceAudioPath))
                
                try await remoteAudio.createReference(
                    id: referenceId,
                    audio: audioData,
                    text: voiceConfig.referenceTranscription,
                    apiKey: apiKey
                )
                
                await MainActor.run {
                    voiceConfig.fishAudioReferenceId = referenceId
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}
