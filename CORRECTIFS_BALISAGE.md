# Correctifs du système de balisage

## 🐛 Problèmes identifiés et résolus

### 1. Sélection du provider AI ignorée
**Problème** : Même en sélectionnant DeepSeek, c'était Ollama qui était utilisé (ventilateur du MacBook qui tourne).

**Cause** : La logique utilisait `processAllChapters()` d'OllamaService qui traitait tous les chapitres en batch, même pour les APIs distantes.

**Solution** : 
- Traitement chapitre par chapitre avec vérification du provider à chaque itération
- Utilisation correcte de `remoteAIService.injectTags()` pour DeepSeek/OpenAI/Anthropic
- Utilisation de `ollamaService.injectTags()` uniquement pour Ollama local

### 2. Timeout et perte de progression
**Problème** : En cas de timeout, tout le balisage recommençait de zéro.

**Solution** : **Sauvegarde incrémentielle**
- Chaque chapitre est sauvegardé immédiatement après balisage
- En cas de reprise, les chapitres déjà balisés sont détectés et ignorés
- Le balisage reprend au premier chapitre non balisé

## ✅ Améliorations implémentées

### Sauvegarde incrémentielle
```swift
// Vérifier si déjà balisé (reprise après timeout)
if chapter.status == .tagged && chapter.taggedText != nil {
    progress = Double(index + 1) / Double(project.chapters.count)
    progressText = "Chapitre \(index + 1)/\(project.chapters.count) déjà enrichi (reprise)..."
    continue
}
```

### Gestion des erreurs par chapitre
```swift
} catch {
    // En cas d'erreur sur un chapitre, marquer comme erreur mais continuer
    project.chapters[index].status = .error
    projectManager.updateProject(project)
    self.project = project
    
    print("⚠️ Erreur chapitre \(index + 1): \(error.localizedDescription)")
    progressText = "Erreur chapitre \(index + 1), passage au suivant..."
    
    // Attendre un peu avant de continuer
    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes
}
```

### Sauvegarde immédiate après chaque chapitre
```swift
// Sauvegarder immédiatement ce chapitre
project.chapters[index].taggedText = taggedText
project.chapters[index].status = .tagged

// Sauvegarde incrémentielle
try? projectManager.saveChapterText(project: project, chapter: project.chapters[index])
projectManager.updateProject(project)
self.project = project
```

### Vérification finale
```swift
// Vérifier si tous les chapitres sont balisés
let allTagged = project.chapters.allSatisfy { $0.status == .tagged }
if allTagged {
    project.status = .tagsInjected
    projectManager.updateProject(project)
    self.project = project
    currentStep = .voice
    progressText = "Enrichissement terminé ! ✓"
} else {
    let taggedCount = project.chapters.filter { $0.status == .tagged }.count
    progressText = "Enrichissement partiel : \(taggedCount)/\(project.chapters.count) chapitres"
}
```

## 🎯 Comportement attendu maintenant

### Avec DeepSeek sélectionné
1. ✅ L'API DeepSeek est utilisée (pas Ollama local)
2. ✅ Le ventilateur du MacBook ne tourne pas
3. ✅ Message : "Enrichissement chapitre X/Y via DeepSeek..."

### En cas de timeout
1. ✅ Les chapitres déjà balisés sont conservés
2. ✅ Message : "Chapitre X/Y déjà enrichi (reprise)..."
3. ✅ Le balisage reprend au premier chapitre non balisé

### En cas d'erreur sur un chapitre
1. ✅ Le chapitre est marqué en erreur
2. ✅ Le balisage continue avec le chapitre suivant
3. ✅ Pause de 2 secondes avant de continuer
4. ✅ Message final : "Enrichissement partiel : X/Y chapitres"

## 🔍 Debug

Les logs de debug sont toujours actifs :
```
🔍 DEBUG injectTags:
  - preferredProvider: deepseek
  - forceRemote: false
  - useRemote: true
  - requiresAPIKey: true
```

Vérifiez ces logs dans la console pour confirmer que le bon provider est utilisé.

## 📝 Fichiers modifiés

- `AudiobookForge/ViewModels/PipelineViewModel.swift` : Fonction `injectTags()` complètement refactorisée

## 🚀 Pour tester

1. Sélectionnez DeepSeek dans les paramètres AI
2. Lancez le balisage
3. Vérifiez dans les logs que "DeepSeek" apparaît
4. En cas d'interruption, relancez le balisage
5. Les chapitres déjà balisés seront ignorés

**Build réussi (4.56s)** ✅
