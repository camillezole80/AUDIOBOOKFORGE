# Analyse du problème : MLX utilisé au lieu de Fish.Audio API

## Logs observés

```
🔧 AudioSettings sauvegardés:
  - preferredProvider: Fish.Audio API
  - forceRemote: true
  - fallbackToRemote: true
  - selectedVoice: none

Génération audio via mlx-speech fish-s2-pro...
```

## Problème identifié

Malgré la configuration `Fish.Audio API` + `forceRemote: true`, le système utilise **MLX local**.

## Analyse du code

### AudioGenerationService.swift (lignes 60-96)

```swift
func generateChunkAudio(..., voiceConfig: VoiceConfig) async throws {
    // Déterminer le provider à utiliser
    let provider = voiceConfig.preferredProvider
    let useRemote = voiceConfig.forceRemote || (provider == .fishAudio)
    
    if useRemote && provider.requiresAPIKey {
        // Utiliser Fish.Audio API
        try await generateChunkViaFishAudio(...)
    } else {
        // Utiliser MLX local
        try await generateChunkViaMLX(...)
    }
}
```

### Logique actuelle

```
useRemote = forceRemote || (provider == .fishAudio)
useRemote = true || (Fish.Audio API == .fishAudio)
useRemote = true ✅

provider.requiresAPIKey = Fish.Audio API.requiresAPIKey
provider.requiresAPIKey = true ✅

Condition: useRemote && provider.requiresAPIKey
Condition: true && true = true ✅
```

**La logique devrait fonctionner !**

## Hypothèses

### Hypothèse 1 : Problème de persistance (CONFIRMÉE)
Les logs montrent :
```
🔧 updateVoiceConfig called:
  - preferredProvider: Local (MLX)
  - forceRemote: false
```

Puis plus tard :
```
🔧 AudioSettings sauvegardés:
  - preferredProvider: Fish.Audio API
  - forceRemote: true
```

**Il y a plusieurs appels à `updateVoiceConfig` avec des valeurs différentes !**

### Hypothèse 2 : Ordre des opérations
1. L'utilisateur ouvre les paramètres audio
2. Les paramètres sont chargés depuis le projet (anciennes valeurs)
3. L'utilisateur modifie les paramètres
4. Les paramètres sont sauvegardés
5. **MAIS** le projet en mémoire n'est pas rechargé

### Hypothèse 3 : Le binding ne fonctionne pas correctement
Le binding dans `VoiceStepView.swift` :
```swift
AudioSettingsView(voiceConfig: Binding(
    get: { project.voiceConfig },
    set: { pipelineVM.updateVoiceConfig($0) }
))
```

Le `get` retourne toujours les **anciennes valeurs** du projet en mémoire, même après sauvegarde.

## Solution proposée

### Option 1 : Recharger le projet après sauvegarde
Dans `PipelineViewModel.updateVoiceConfig()`, recharger le projet depuis le disque après sauvegarde.

### Option 2 : Forcer la mise à jour du binding
Dans `AudioSettingsView`, forcer la mise à jour du binding avant de fermer la fenêtre.

### Option 3 : Ajouter des logs de debug
Ajouter des logs dans `generateChunkAudio` pour voir exactement quelle configuration est utilisée.

## Prochaines étapes

1. Ajouter des logs détaillés dans `generateChunkAudio` pour voir la configuration reçue
2. Vérifier que `PipelineViewModel.project` est bien mis à jour après `updateVoiceConfig`
3. Vérifier que le binding dans `VoiceStepView` retourne bien les nouvelles valeurs
