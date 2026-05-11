# Debug : Problème de sélection Fish.Audio

## 🐛 Problème rapporté

1. Sélection de Fish.Audio dans les paramètres audio
2. Test de connexion : ✅ OK
3. Activation de "Forcer le rendu distant"
4. Retour à l'étape "Voix" : Bouton "Passer à la génération" grisé
5. Retour dans les paramètres audio : Fish.Audio n'est plus sélectionné

## 🔍 Logs de debug ajoutés

### Dans AudioSettingsView.saveSettings()
```swift
print("🔧 AudioSettings sauvegardés:")
print("  - preferredProvider: \(localProvider.rawValue)")
print("  - forceRemote: \(localForceRemote)")
print("  - fallbackToRemote: \(localFallbackToRemote)")
```

### Dans PipelineViewModel.updateVoiceConfig()
```swift
print("🔧 VoiceConfig mis à jour dans le projet:")
print("  - preferredProvider: \(config.preferredProvider.rawValue)")
print("  - forceRemote: \(config.forceRemote)")
print("  - hasValidReference: \(config.hasValidReference)")
```

## 📋 Procédure de test

### 1. Ouvrir la Console
1. Ouvrez l'application **Console** (dans `/Applications/Utilitaires/`)
2. Dans la barre de recherche, tapez : `AudiobookForge`
3. Filtrez les logs pour voir uniquement ceux de l'app

### 2. Tester la configuration Fish.Audio
1. **Lancez AudiobookForge**
2. **Ouvrez un projet** et allez à l'étape "Voix"
3. **Cliquez sur l'icône verte** (haut-parleur) pour ouvrir les paramètres audio
4. **Sélectionnez Fish.Audio**
5. **Activez "Forcer l'utilisation de l'API distante"**
6. **Cliquez sur "Enregistrer"**

### 3. Vérifier les logs
Dans la Console, vous devriez voir :
```
🔧 AudioSettings sauvegardés:
  - preferredProvider: Fish.Audio API
  - forceRemote: true
  - fallbackToRemote: false
```

Puis :
```
🔧 VoiceConfig mis à jour dans le projet:
  - preferredProvider: Fish.Audio API
  - forceRemote: true
  - hasValidReference: true
```

### 4. Vérifier le bouton "Passer à la génération"
- Si `hasValidReference: true` → Le bouton devrait être **actif**
- Si `hasValidReference: false` → Le bouton est **grisé**

### 5. Rouvrir les paramètres audio
1. **Cliquez à nouveau sur l'icône verte**
2. **Vérifiez** que Fish.Audio est toujours sélectionné
3. **Vérifiez** les logs dans la Console

## 🔧 Causes possibles

### Cause 1 : Le binding ne se propage pas
**Symptôme** : Les logs montrent que `saveSettings()` est appelé, mais `updateVoiceConfig()` n'est pas appelé.

**Solution** : Le binding dans `VoiceStepView` ne fonctionne pas correctement.

### Cause 2 : Le projet n'est pas sauvegardé
**Symptôme** : `updateVoiceConfig()` est appelé, mais au rechargement, les paramètres sont perdus.

**Solution** : Vérifier que `projectManager.updateProject()` sauvegarde bien le fichier JSON.

### Cause 3 : hasValidReference retourne false
**Symptôme** : Le bouton reste grisé même si Fish.Audio est configuré.

**Solution** : Vérifier la logique de `hasValidReference` dans `Project.swift`.

## ✅ Logique actuelle de hasValidReference

```swift
var hasValidReference: Bool {
    // Si Fish.Audio est configuré, pas besoin de référence locale
    if preferredProvider == .fishAudio {
        return true
    }
    // Sinon, vérifier la référence locale
    return !referenceAudioPath.isEmpty && !referenceTranscription.isEmpty
}
```

**Cette logique devrait permettre de passer à la génération avec Fish.Audio sans clonage vocal.**

## 🚀 Prochaines étapes

1. **Lancez l'app** avec la Console ouverte
2. **Suivez la procédure de test** ci-dessus
3. **Copiez les logs** de la Console
4. **Partagez les logs** pour identifier le problème exact

## 📝 Informations à collecter

- [ ] Logs de `AudioSettings sauvegardés`
- [ ] Logs de `VoiceConfig mis à jour dans le projet`
- [ ] Valeur de `hasValidReference` après sauvegarde
- [ ] État du bouton "Passer à la génération" (actif/grisé)
- [ ] État de la sélection Fish.Audio après réouverture

**Build réussi (3.15s)** ✅
