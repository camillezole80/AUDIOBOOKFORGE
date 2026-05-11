# 🔍 Debug : Pourquoi Ollama est toujours utilisé ?

## Problème
L'enrichissement utilise toujours Ollama/Qwen au lieu de DeepSeek, même après configuration.

## Causes possibles

### 1. **Le projet n'a pas été rechargé**
Quand vous modifiez la config IA dans AISettingsView, le projet est mis à jour dans ProjectManager, mais PipelineViewModel garde l'ancienne version en mémoire.

**Solution :** Recharger le projet après avoir sauvegardé la config.

### 2. **La config par défaut est Ollama**
Dans `Project.swift`, la valeur par défaut est :
```swift
var aiConfig: AIConfig = AIConfig()  // preferredProvider = .ollama par défaut
```

**Solution :** Les projets existants ont la config par défaut (Ollama).

### 3. **Le binding ne fonctionne pas correctement**
Le binding dans ContentView pourrait ne pas propager les changements.

## 🔧 Solutions à tester

### Solution 1 : Recharger le projet après config
Ajoutez dans `AISettingsView` :
```swift
Button("Sauvegarder") {
    saveKeys()
    // Forcer le rechargement du projet
    if let updatedProject = ProjectManager.shared.projects.first(where: { $0.id == aiConfig.id }) {
        // Notifier le changement
    }
    dismiss()
}
```

### Solution 2 : Vérifier la config dans les logs
Ajoutez dans `PipelineViewModel.injectTags()` :
```swift
print("🔍 DEBUG: preferredProvider = \(aiConfig.preferredProvider)")
print("🔍 DEBUG: forceRemote = \(aiConfig.forceRemote)")
print("🔍 DEBUG: useRemote = \(useRemote)")
```

### Solution 3 : Forcer DeepSeek pour les nouveaux projets
Dans `Project.createDefault()` :
```swift
var aiConfig = AIConfig()
aiConfig.preferredProvider = .deepseek  // Par défaut DeepSeek au lieu d'Ollama
```

## 🎯 Test rapide

1. **Ouvrez les logs** (bouton dans DependencyCheckView)
2. **Lancez l'enrichissement**
3. **Cherchez** : "preferredProvider" ou "Enrichissement via"
4. **Vérifiez** quel provider est réellement utilisé

## 📊 État actuel

- ✅ Interface AISettingsView fonctionne
- ✅ Clé DeepSeek sauvegardée dans Keychain
- ✅ PipelineViewModel a la logique de sélection
- ❌ Le projet ne charge pas la nouvelle config
- ❌ Ollama est toujours utilisé

## 🚀 Prochaine étape

**Ajouter des logs de debug** pour voir exactement quelle config est chargée.
