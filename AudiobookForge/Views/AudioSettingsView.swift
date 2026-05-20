import SwiftUI

/// Vue de configuration des paramètres audio (Local MLX vs Fish.Audio API)
struct AudioSettingsView: View {
    @Binding var voiceConfig: VoiceConfig
    @Environment(\.dismiss) private var dismiss
    
    // Utiliser @State local pour éviter les problèmes de binding
    @State private var localProvider: AudioProvider

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
    @State private var includeOwnVoices: Bool = false
    /// IDs des voix appartenant à l'utilisateur (récupérées via self=true)
    @State private var ownVoiceIds: Set<String> = []
    /// Lecteur d'extraits audio Fish.Audio (un seul à la fois).
    @StateObject private var previewPlayer = VoicePreviewPlayer()
    /// Code de langue ISO envoyé à l'API Fish.Audio (`""` = toutes les langues)
    @State private var voiceLanguageCode: String

    /// Langues proposées dans le Picker.
    /// La paire (code, libellé) — `""` signifie "pas de filtre langue".
    private let voiceLanguageOptions: [(code: String, label: String)] = [
        ("",  "Toutes les langues"),
        ("fr", "Français"),
        ("en", "Anglais"),
        ("es", "Espagnol"),
        ("de", "Allemand"),
        ("it", "Italien"),
        ("pt", "Portugais"),
        ("zh", "Chinois"),
        ("ja", "Japonais"),
        ("ko", "Coréen"),
        ("ru", "Russe")
    ]
    
    private let keychain = KeychainHelper.shared
    private let remoteAudio = RemoteAudioService.shared
    
    init(voiceConfig: Binding<VoiceConfig>, defaultLanguage: String = "fr") {
        self._voiceConfig = voiceConfig
        self._localProvider = State(initialValue: voiceConfig.wrappedValue.preferredProvider)
        // Code ISO court, ex: "fr-FR" → "fr". Vide si l'appelant veut le top mondial.
        let normalized = String(defaultLanguage.prefix(2)).lowercased()
        self._voiceLanguageCode = State(initialValue: normalized)
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
                    
                    // Configuration TTS Audiobook Tool
                    if localProvider == .ttsAudiobookTool {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Modèle TTS")
                                .font(.headline)

                            Picker("Modèle", selection: $voiceConfig.ttsModel) {
                                ForEach(TtsModelType.allCases, id: \.self) { model in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(model.displayName)
                                                .font(.body)
                                            if model.supportsEmotionalTags {
                                                Label("balises", systemImage: "tag.fill")
                                                    .labelStyle(.iconOnly)
                                                    .foregroundColor(.green)
                                                    .font(.caption)
                                                    .help("Lit les balises émotionnelles [whisper], [excited]…")
                                            }
                                        }
                                        Text(model.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .tag(model)
                                }
                            }
                            .pickerStyle(.radioGroup)

                            // Avertissement si le modèle choisi ignore les balises
                            if !voiceConfig.ttsModel.supportsEmotionalTags {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.orange)
                                    Text("Ce modèle ne lit pas les balises émotionnelles : elles seront supprimées du texte avant la génération.")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(6)
                            }
                            
                            Divider()
                            
                            Text("Options avancées")
                                .font(.headline)
                            
                            Toggle("Validation STT (Whisper)", isOn: $voiceConfig.enableSttValidation)
                                .help("Valide automatiquement les générations et réessaie en cas d'erreur")
                            
                            HStack {
                                Text("Tentatives max:")
                                Stepper("\(voiceConfig.maxRetries)", value: $voiceConfig.maxRetries, in: 1...10)
                            }
                            
                            Toggle("Normalisation loudness (EBU R128)", isOn: $voiceConfig.enableNormalization)
                                .help("Normalise le volume selon le standard EBU R128")
                            
                            Toggle("Upsampling 48kHz (Sidon)", isOn: $voiceConfig.enableUpsampling)
                                .help("Améliore la qualité audio en upsamplant à 48kHz")
                            
                            Divider()
                            
                            Text("Paramètres de génération")
                                .font(.headline)
                            
                            HStack {
                                Text("Temperature:")
                                Slider(value: $voiceConfig.temperature, in: 0.0...1.0, step: 0.1)
                                Text(String(format: "%.1f", voiceConfig.temperature))
                                    .frame(width: 30)
                            }
                            
                            // Top-P (optionnel)
                            HStack {
                                Toggle("Top-P", isOn: Binding(
                                    get: { voiceConfig.topP != nil },
                                    set: { enabled in
                                        voiceConfig.topP = enabled ? 0.9 : nil
                                    }
                                ))
                                
                                if voiceConfig.topP != nil {
                                    Slider(value: Binding(
                                        get: { voiceConfig.topP ?? 0.9 },
                                        set: { voiceConfig.topP = $0 }
                                    ), in: 0.0...1.0, step: 0.05)
                                    Text(String(format: "%.2f", voiceConfig.topP ?? 0.9))
                                        .frame(width: 40)
                                }
                            }
                            
                            // Top-K (optionnel)
                            HStack {
                                Toggle("Top-K", isOn: Binding(
                                    get: { voiceConfig.topK != nil },
                                    set: { enabled in
                                        voiceConfig.topK = enabled ? 50 : nil
                                    }
                                ))
                                
                                if voiceConfig.topK != nil {
                                    Stepper("\(voiceConfig.topK ?? 50)", value: Binding(
                                        get: { voiceConfig.topK ?? 50 },
                                        set: { voiceConfig.topK = $0 }
                                    ), in: 1...100)
                                }
                            }
                            
                            // Seed (optionnel)
                            HStack {
                                Toggle("Seed fixe", isOn: Binding(
                                    get: { voiceConfig.seed != nil },
                                    set: { enabled in
                                        voiceConfig.seed = enabled ? 42 : nil
                                    }
                                ))
                                
                                if voiceConfig.seed != nil {
                                    TextField("Seed", value: Binding(
                                        get: { voiceConfig.seed ?? 42 },
                                        set: { voiceConfig.seed = $0 }
                                    ), format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                }
                            }
                            .help("Utilisez un seed fixe pour des résultats reproductibles")
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        
                        Divider()
                    }
                    
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

                            // Filtre langue côté API : envoyé directement à GET /model?language=fr.
                            // Sans ce filtre, l'API renvoie le top mondial (zh/en majoritaires),
                            // ce qui donne 3-5 voix françaises sur 200.
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .foregroundColor(.secondary)
                                Text("Langue à charger :")
                                    .font(.subheadline)
                                Picker("", selection: $voiceLanguageCode) {
                                    ForEach(voiceLanguageOptions, id: \.code) { option in
                                        Text(option.label).tag(option.code)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .onChange(of: voiceLanguageCode) { _, _ in
                                    // Recharger si une liste est déjà affichée
                                    if !availableVoices.isEmpty {
                                        loadVoices()
                                    }
                                }
                            }

                            // Inclure les voix personnelles (clonées sur fish.audio)
                            if !fishAudioKey.isEmpty {
                                Toggle(isOn: $includeOwnVoices) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Inclure mes voix (clonage perso)")
                                            .font(.subheadline)
                                        Text("Charge aussi vos modèles créés sur fish.audio (badge ★).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                                .onChange(of: includeOwnVoices) { _, _ in
                                    // Recharger si une liste est déjà affichée
                                    if !availableVoices.isEmpty {
                                        loadVoices()
                                    }
                                }
                            }
                            
                            // Afficher l'ID sauvegardé dans le projet
                            if let savedId = voiceConfig.selectedFishAudioVoice {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ID sauvegardé dans le projet :")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(savedId)
                                        .font(.caption)
                                        .foregroundColor(savedId.count >= 3 ? .green : .red)
                                        .textSelection(.enabled)
                                    if savedId.count < 3 {
                                        Text("⚠️ Cet ID semble invalide (trop court). Rechargez les voix et resélectionnez.")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            if !availableVoices.isEmpty {
                                // Barre de recherche (plus visible avec icône système + clear + compteur)
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.secondary)
                                    TextField("Rechercher une voix par nom…", text: $voiceSearchText)
                                        .textFieldStyle(.plain)
                                    if !voiceSearchText.isEmpty {
                                        Button(action: { voiceSearchText = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Text("\(filteredVoices.count) / \(availableVoices.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(6)

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
                                                isOwn: ownVoiceIds.contains(voice.id),
                                                isPlaying: previewPlayer.playingVoiceId == voice.id,
                                                isLoading: previewPlayer.loadingVoiceId == voice.id,
                                                onPreviewToggle: { previewPlayer.toggle(voice: voice) },
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
                                        Text("ID : \(selectedVoice.id)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)
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
                    
                    // Voix sauvegardée (legacy) : on conserve l'affichage / la suppression
                    // d'un reference_id déjà stocké, mais on retire le bouton "Créer" qui
                    // reposait sur un endpoint Fish.Audio inexistant (POST /v1/references/add).
                    if localProvider == .fishAudio, let refId = voiceConfig.fishAudioReferenceId {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Voix sauvegardée (legacy)")
                                .font(.headline)

                            HStack {
                                Text("ID : \(refId)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)

                                Spacer()

                                Button("Supprimer") {
                                    voiceConfig.fishAudioReferenceId = nil
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Text("Pour utiliser votre propre voix, créez le modèle directement sur fish.audio puis sélectionnez-le dans la liste ci-dessus.")
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
                    previewPlayer.stop()
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Enregistrer") {
                    previewPlayer.stop()
                    saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
        .onDisappear { previewPlayer.stop() }
        .onAppear {
            loadAPIKeys()
            // Recharger les valeurs depuis le binding au cas où elles auraient changé
            localProvider = voiceConfig.preferredProvider

            // Charger la voix sélectionnée
            if let savedVoiceId = voiceConfig.selectedFishAudioVoice {
                selectedVoiceId = savedVoiceId
                print("🔄 Chargement de la voix sauvegardée: \(savedVoiceId)")
            }
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
        // On regroupe TOUTES les mutations en un seul commit du binding.
        var newConfig = voiceConfig
        newConfig.preferredProvider = localProvider
        if let voiceId = selectedVoiceId {
            newConfig.selectedFishAudioVoice = voiceId
        }
        voiceConfig = newConfig

        if !fishAudioKey.isEmpty {
            _ = keychain.save(key: fishAudioKey, for: .fishAudio)
        }

        print("🔧 AudioSettings.saveSettings() : provider=\(voiceConfig.preferredProvider.rawValue), voice=\(voiceConfig.selectedFishAudioVoice ?? "nil"), ttsModel=\(voiceConfig.ttsModel.rawValue)")

        // Filet de sécurité : forcer la persistance du projet
        NotificationCenter.default.post(name: NSNotification.Name("SaveProject"), object: nil)
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

        let languageFilter: String? = voiceLanguageCode.isEmpty ? nil : voiceLanguageCode

        Task {
            do {
                print("🔍 Chargement des voix Fish.Audio (lang=\(languageFilter ?? "toutes"), perso=\(includeOwnVoices))...")
                let voices = try await remoteAudio.fetchAvailableVoices(
                    apiKey: fishAudioKey,
                    language: languageFilter,
                    includeOwn: includeOwnVoices
                )

                // Calcul des IDs "perso" : seulement si la toggle est cochée. On compare
                // contre la liste publique de la MÊME langue pour rester cohérent.
                var ownIds: Set<String> = []
                if includeOwnVoices {
                    let publicOnly = try await remoteAudio.fetchAvailableVoices(
                        apiKey: fishAudioKey,
                        language: languageFilter,
                        includeOwn: false
                    )
                    let publicIds = Set(publicOnly.map { $0.id })
                    ownIds = Set(voices.map { $0.id }).subtracting(publicIds)
                }

                await MainActor.run {
                    availableVoices = voices
                    ownVoiceIds = ownIds
                    isLoadingVoices = false

                    print("✅ \(voices.count) voix chargées (\(ownIds.count) perso)")

                    if let savedVoiceId = voiceConfig.selectedFishAudioVoice {
                        selectedVoiceId = savedVoiceId
                    }

                    if voices.isEmpty {
                        testResult = "⚠️ Aucune voix disponible pour cette langue"
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
    let isOwn: Bool
    let isPlaying: Bool
    let isLoading: Bool
    let onPreviewToggle: () -> Void
    let action: () -> Void

    private var hasPreview: Bool { voice.previewURL != nil }

    var body: some View {
        Button(action: action) {
            HStack {
                // Mini-player Fish.Audio (à gauche, indépendant du clic de sélection)
                Group {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else if hasPreview {
                        Button(action: onPreviewToggle) {
                            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(isPlaying ? .red : .accentColor)
                        }
                        .buttonStyle(.plain)
                        .help(isPlaying ? "Arrêter l'écoute" : "Écouter un extrait")
                    } else {
                        Image(systemName: "play.slash.fill")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.4))
                            .help("Aucun extrait disponible")
                    }
                }
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if isOwn {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                                .help("Voix personnelle (clonage)")
                        }
                        Text(voice.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

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
        case .fishAudio:
            return "API Fish.Audio ($15/1M bytes, lit les balises émotionnelles, qualité constante)"
        case .ttsAudiobookTool:
            return "TTS Audiobook Tool (gratuit, local — Fish S2-Pro / Chatterbox / Qwen3)"
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
