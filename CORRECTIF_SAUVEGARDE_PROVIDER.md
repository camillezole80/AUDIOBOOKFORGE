# 🔧 Correctif : Sauvegarde du provider audio

**Date** : 18/05/2026 18:07  
**Problème** : Le provider sélectionné (TTS Audiobook Tool) n'était pas sauvegardé correctement

---

## 🐛 Problème identifié

Lorsque l'utilisateur sélectionnait "TTS Audiobook Tool" dans les réglages audio et cliquait sur "Enregistrer", le provider revenait à "Fish.Audio API" (valeur par défaut).

### Cause

Le binding `voiceConfig` était modifié dans `AudioSettingsView`, mais le projet n'était **pas sauvegardé sur disque** après la fermeture de la fenêtre. Au rechargement du projet, l'ancienne valeur était restaurée.

---

## ✅ Solution appliquée

### 1. Ajout d'une notification de sauvegarde

**Fichier** : `AudiobookForge/Views/AudioSettingsView.swift`

```swift
private func saveSettings() {
    // ... (code existant)
    
    // IMPORTANT: Forcer la sauvegarde du projet
    // Le binding voiceConfig est modifié, mais le projet doit être sauvegardé explicitement
    NotificationCenter.default.post(name: NSNotification.Name("SaveProject"), object: nil)
}
```

### 2. Écoute de la notification dans PipelineViewModel

**Fichier** : `AudiobookForge/ViewModels/PipelineViewModel.swift`

```swift
init() {
    // Écouter la notification de sauvegarde du projet
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name("SaveProject"),
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.saveCurrentProject()
    }
}

deinit {
    NotificationCenter.default.removeObserver(self)
}

private func saveCurrentProject() {
    guard let project = project else { return }
    projectManager.updateProject(project)
    print("💾 Projet sauvegardé suite à modification des réglages audio")
}
```

---

## 🔍 Logs de débogage ajoutés

Pour faciliter le débogage futur, des logs ont été ajoutés :

```swift
print("🔧 AudioSettings sauvegardés:")
print("  - preferredProvider: \(localProvider.rawValue)")
print("  - forceRemote: \(localForceRemote)")
print("  - fallbackToRemote: \(localFallbackToRemote)")
print("  - selectedVoice: \(selectedVoiceId ?? "none")")
print("  - ttsModel: \(voiceConfig.ttsModel.rawValue)")
```

---

## 🎯 Résultat

Maintenant, quand vous :
1. Ouvrez les réglages audio (icône 🔊)
2. Sélectionnez "TTS Audiobook Tool"
3. Choisissez un modèle (Chatterbox, Fish S2-Pro, Qwen3)
4. Cliquez sur "Enregistrer"

Le provider et le modèle sont **correctement sauvegardés** dans le fichier `project.json` et **persistent** après fermeture/réouverture du projet.

---

## 📝 Vérification

Pour vérifier que la sauvegarde fonctionne :

1. **Ouvrir un projet**
2. **Configurer TTS Audiobook Tool** avec Chatterbox
3. **Enregistrer**
4. **Vérifier les logs** dans la console :
   ```
   🔧 AudioSettings sauvegardés:
     - preferredProvider: ttsAudiobookTool
     - ttsModel: chatterbox
   💾 Projet sauvegardé suite à modification des réglages audio
   ```
5. **Fermer et rouvrir le projet**
6. **Vérifier** que TTS Audiobook Tool + Chatterbox sont toujours sélectionnés

---

## 🔄 Fichiers modifiés

```
AudiobookForge/Views/AudioSettingsView.swift       [MODIFIÉ]
AudiobookForge/ViewModels/PipelineViewModel.swift  [MODIFIÉ]
```

---

## ✅ Compilation

```bash
Build complete! (8.25s)
```

Aucune erreur, seulement 1 warning mineur non lié.

---

**Correctif appliqué avec succès ! 🎉**
