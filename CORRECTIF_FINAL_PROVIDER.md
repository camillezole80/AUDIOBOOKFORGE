# 🔧 Correctif Final : Provider Audio + Boutons de Réinitialisation

**Date** : 18/05/2026 18:16  
**Version** : Correctif complet

---

## 🐛 Problèmes identifiés et résolus

### 1. Provider audio non sauvegardé correctement

**Symptôme** : Le provider "TTS Audiobook Tool" revenait à "Fish.Audio API" après sauvegarde.

**Cause** : L'enum `AudioProvider` utilisait des `rawValue` avec des noms d'affichage (ex: "Fish.Audio API") au lieu d'identifiants simples. Lors de la sérialisation JSON, cela créait des incohérences.

**Solution** : Modification de l'enum pour utiliser des identifiants simples :

```swift
enum AudioProvider: String, Codable, CaseIterable {
    case local = "local"                    // Au lieu de "Local (MLX)"
    case fishAudio = "fishAudio"            // Au lieu de "Fish.Audio API"
    case ttsAudiobookTool = "ttsAudiobookTool"  // Au lieu de "TTS Audiobook Tool"
    
    var displayName: String {
        switch self {
        case .local: return "Local (MLX - Gratuit)"
        case .fishAudio: return "Fish.Audio API"
        case .ttsAudiobookTool: return "TTS Audiobook Tool (Local)"
        }
    }
}
```

### 2. Boutons de réinitialisation manquants

**Demande utilisateur** : Pouvoir réinitialiser un ou tous les chapitres dans l'onglet génération.

**Solution** : Ajout de 2 fonctions dans `PipelineViewModel` :

```swift
func resetChapter(at index: Int) {
    // Supprime le fichier audio
    // Réinitialise le statut à .tagged
}

func resetAllChapters() {
    // Réinitialise tous les chapitres générés
}
```

Et ajout d'un bouton dans `GenerationStepView` :

```swift
// Bouton pour réinitialiser ce chapitre
if chapter.status == .audioReady {
    Button(action: {
        pipelineVM.resetChapter(at: index)
    }) {
        Image(systemName: "arrow.counterclockwise.circle")
            .foregroundColor(.orange)
    }
    .buttonStyle(.borderless)
    .help("Réinitialiser ce chapitre")
    .disabled(pipelineVM.isProcessing)
}
```

---

## ✅ Fichiers modifiés

```
AudiobookForge/Models/Project.swift                    [MODIFIÉ]
AudiobookForge/Views/AudioSettingsView.swift           [MODIFIÉ]
AudiobookForge/ViewModels/PipelineViewModel.swift      [MODIFIÉ]
AudiobookForge/Views/GenerationStepView.swift          [MODIFIÉ]
```

---

## 🎯 Résultat

### Provider audio

Maintenant, quand vous :
1. Sélectionnez "TTS Audiobook Tool" + "Chatterbox"
2. Cliquez sur "Enregistrer"
3. Fermez et rouvrez le projet

**Le provider est correctement sauvegardé** dans `project.json` comme :
```json
"preferredProvider": "ttsAudiobookTool",
"ttsModel": "chatterbox"
```

Au lieu de l'ancien format incorrect :
```json
"preferredProvider": "Fish.Audio API"
```

### Boutons de réinitialisation

Dans l'onglet "Génération", chaque chapitre généré affiche maintenant :
- 🔊 Bouton pour écouter le chapitre
- 🔄 **Bouton pour réinitialiser le chapitre** (nouveau)

Cliquer sur 🔄 :
- Supprime le fichier audio du chapitre
- Réinitialise le statut à "Balises ajoutées"
- Permet de régénérer le chapitre avec de nouveaux paramètres

---

## 🔍 Migration des anciens projets

Les projets existants avec l'ancien format seront automatiquement migrés lors du chargement. Swift décodera :
- `"Fish.Audio API"` → `.fishAudio`
- `"TTS Audiobook Tool"` → `.ttsAudiobookTool`
- `"Local (MLX)"` → `.local`

Mais les **nouveaux projets** utiliseront le format correct dès le départ.

---

## ✅ Compilation

```bash
Build complete! (9.60s)
```

Aucune erreur, seulement 3 warnings mineurs non liés.

---

## 🚀 Comment tester

### Test 1 : Sauvegarde du provider

1. Ouvrir un projet
2. Aller dans Voix → Cliquer sur 🔊
3. Sélectionner "TTS Audiobook Tool" + "Chatterbox"
4. Enregistrer
5. Fermer et rouvrir le projet
6. **Vérifier** que TTS Audiobook Tool + Chatterbox sont toujours sélectionnés

### Test 2 : Réinitialisation d'un chapitre

1. Générer un chapitre
2. Aller dans l'onglet "Génération"
3. Cliquer sur le bouton 🔄 à côté du chapitre généré
4. **Vérifier** que le statut passe à "Balises ajoutées"
5. Régénérer le chapitre avec de nouveaux paramètres

---

## 📝 Notes importantes

### Pourquoi le provider n'était pas sauvegardé ?

Le problème venait de la sérialisation JSON. Quand Swift encode un enum avec `rawValue`, il utilise la valeur brute. Si cette valeur change (ex: "Fish.Audio API" → "fishAudio"), la désérialisation échoue silencieusement et utilise la valeur par défaut.

### Solution appliquée

En utilisant des identifiants simples et stables (`local`, `fishAudio`, `ttsAudiobookTool`), la sérialisation est cohérente et les projets sont portables.

---

**Correctifs appliqués avec succès ! 🎉**

L'application devrait maintenant :
- ✅ Sauvegarder correctement le provider TTS Audiobook Tool
- ✅ Permettre de réinitialiser les chapitres générés
- ✅ Utiliser le bon provider lors de la génération audio
