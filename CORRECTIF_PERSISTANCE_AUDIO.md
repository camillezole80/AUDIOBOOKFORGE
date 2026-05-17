# Correctif : Persistance des paramètres audio

## Problème identifié

Les paramètres audio configurés dans `AudioSettingsView` ne sont pas persistés dans le fichier `project.json` après fermeture et réouverture de l'application.

### Analyse du flux de données

1. **VoiceStepView.swift (ligne 212-215)** :
```swift
AudioSettingsView(voiceConfig: Binding(
    get: { project.voiceConfig },
    set: { pipelineVM.updateVoiceConfig($0) }
))
```
✅ Le binding est correctement configuré pour appeler `updateVoiceConfig`

2. **AudioSettingsView.swift (ligne 341-363)** :
```swift
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
}
```
✅ Les paramètres sont bien sauvegardés dans le binding

3. **PipelineViewModel.swift (ligne 334-345)** :
```swift
func updateVoiceConfig(_ config: VoiceConfig) {
    guard var project = project else { return }
    project.voiceConfig = config
    projectManager.updateProject(project)
    self.project = project
    
    // DEBUG
    print("🔧 VoiceConfig mis à jour dans le projet:")
    print("  - preferredProvider: \(config.preferredProvider.rawValue)")
    print("  - forceRemote: \(config.forceRemote)")
    print("  - hasValidReference: \(config.hasValidReference)")
}
```
✅ Le ViewModel appelle bien `projectManager.updateProject()`

4. **ProjectManager.swift** :
Il faut vérifier que `updateProject()` sauvegarde bien le fichier JSON sur disque.

## Cause probable

Le problème vient probablement de `ProjectManager.updateProject()` qui ne persiste pas les changements sur disque, ou qui ne sérialise pas correctement les nouveaux champs de `VoiceConfig`.

## Solution

### Étape 1 : Vérifier ProjectManager.updateProject()

Examiner si la méthode sauvegarde bien le projet sur disque après mise à jour.

### Étape 2 : Vérifier la sérialisation de VoiceConfig

S'assurer que tous les champs de `VoiceConfig` sont bien marqués `Codable` et sérialisés dans le JSON.

### Étape 3 : Ajouter des logs de debug

Ajouter des logs pour tracer le flux de sauvegarde :
- Avant l'appel à `updateProject()`
- Après l'écriture du fichier JSON
- À la relecture du fichier JSON

## Diagnostic complet

### ✅ Vérifications effectuées

1. **ProjectManager.updateProject()** (ligne 77-89) :
   - ✅ Met à jour le projet dans le tableau `projects`
   - ✅ Appelle `saveProject(updated)` qui encode et écrit le JSON
   - ✅ Appelle `saveProjectsList()` pour la liste globale
   - **Conclusion : La sauvegarde fonctionne correctement**

2. **VoiceConfig** (Project.swift, ligne 98-120) :
   - ✅ Tous les champs sont bien déclarés
   - ✅ La structure est `Codable`
   - ✅ Les nouveaux champs sont présents :
     - `preferredProvider: AudioProvider`
     - `forceRemote: Bool`
     - `fallbackToRemote: Bool`
     - `fishAudioReferenceId: String?`
     - `selectedFishAudioVoice: String?`

3. **AudioProvider** (Project.swift, ligne 203-224) :
   - ✅ Enum conforme à `Codable`
   - ✅ Utilise `String` comme `RawValue`

### 🔍 Cause probable identifiée

Le code de persistance est **correct**. Le problème vient probablement de l'une de ces causes :

1. **Timing** : Les paramètres sont sauvegardés, mais le fichier JSON n'est pas relu au bon moment
2. **Cache** : Le `PipelineViewModel` garde une copie en mémoire qui n'est pas mise à jour
3. **Ordre des opérations** : Le binding est mis à jour après la fermeture de la sheet

### 🔧 Solution proposée

Ajouter un appel explicite à `projectManager.updateProject()` dans `AudioSettingsView.saveSettings()` pour forcer la sauvegarde immédiate, et recharger le projet depuis le disque dans `PipelineViewModel`.

## Correction à appliquer

### 1. Améliorer AudioSettingsView.saveSettings()

Ajouter un log de debug et s'assurer que le binding déclenche bien la sauvegarde.

### 2. Améliorer PipelineViewModel.updateVoiceConfig()

Ajouter un log après la sauvegarde pour confirmer que le fichier JSON a été écrit.

### 3. Vérifier le rechargement du projet

S'assurer que le projet est bien rechargé depuis le disque au démarrage de l'application.

## Test de validation

1. Configurer les paramètres audio (Fish.Audio API)
2. Fermer la fenêtre de configuration
3. Vérifier dans les logs que `updateProject()` a été appelé
4. Vérifier le contenu du fichier `project.json` sur disque
5. Relancer l'application
6. Vérifier que les paramètres sont bien chargés
