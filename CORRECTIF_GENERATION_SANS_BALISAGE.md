# Correctif - Génération sans balisage obligatoire

## 🎯 Problème résolu

**Avant** : Impossible de générer l'audio si les chapitres ne sont pas balisés

**Après** : Génération possible avec le texte brut (rawText) si pas de balisage

## 📝 Modifications

### PipelineViewModel.swift (ligne 484-496)

**Avant** :
```swift
// Ignorer les chapitres non balisés ou déjà générés
if chapter.status != .tagged {
    progressText = "Chapitre \(chapterIndex + 1) ignoré (non balisé)"
    continue
}

if chapter.status == .audioReady && chapter.audioFilePath != nil {
    progressText = "Chapitre \(chapterIndex + 1) déjà généré (reprise)"
    continue
}
```

**Après** :
```swift
// Ignorer les chapitres déjà générés
if chapter.status == .audioReady && chapter.audioFilePath != nil {
    progressText = "Chapitre \(chapterIndex + 1) déjà généré (reprise)"
    continue
}

// Vérifier qu'il y a du texte (balisé ou brut)
let textToGenerate = chapter.taggedText ?? chapter.rawText
if textToGenerate.isEmpty {
    progressText = "Chapitre \(chapterIndex + 1) ignoré (vide)"
    continue
}
```

## ✅ Résultat

L'application utilise maintenant :
1. **taggedText** si disponible (texte enrichi avec balises émotionnelles)
2. **rawText** sinon (texte brut extrait du livre)

Cela permet de :
- Générer l'audio **sans passer par l'étape de balisage**
- Tester rapidement une voix
- Gagner du temps si les balises ne sont pas nécessaires

## 🧪 Test

1. **Importer un livre**
2. **Passer directement à l'étape "Voix"** (sans baliser)
3. **Configurer la voix**
4. **Lancer la génération**
5. ✅ L'audio est généré avec le texte brut !

## 📊 Build

**Build réussi** : 4.34s ✨

## Date

20 mai 2026, 12:11
