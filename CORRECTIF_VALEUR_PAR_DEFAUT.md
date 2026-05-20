
**Date** : 18/05/2026 18:36  
**Problème critique identifié** : La valeur par défaut du provider était `.fishAudio`

---

## 🐛 Problème racine

Dans `AudiobookForge/Models/Project.swift`, ligne 106 :

```swift
var preferredProvider: AudioProvider = .fishAudio  // ❌ MAUVAISE VALEUR PAR DÉFAUT
```

**Conséquence** : 
- Chaque **nouveau projet** créé utilisait automatiquement Fish.Audio API
- Même après avoir changé pour TTS Audiobook Tool dans les réglages, la création d'un nouveau projet réinitialisait à Fish.Audio
- Les projets existants gardaient leur ancienne valeur (fishAudio)

---

## ✅ Solution appliquée

Changement de la valeur par défaut :

```swift
var preferredProvider: AudioProvider = .ttsAudiobookTool  // ✅ NOUVELLE VALEUR PAR DÉFAUT
```

---

## 🎯 Impact

### Pour les nouveaux projets

Maintenant, quand vous créez un **nouveau projet** :
- Le provider par défaut sera **TTS Audiobook Tool**
- Le modèle par défaut sera **Fish S2-Pro**
- Vous n'aurez plus besoin de changer manuellement le provider

### Pour les projets existants

Les projets existants **conservent** leur configuration actuelle :
- Si le projet utilisait `fishAudio`, il continuera à l'utiliser
- Vous devez **manuellement** changer le provider dans les réglages audio

---

## 🔄 Comment tester

### Test 1 : Nouveau projet

1. **Créer un nouveau projet**
2. **Aller dans Voix → Cliquer sur 🔊**
3. **Vérifier** que "TTS Audiobook Tool (Local)" est sélectionné par défaut
4. **Vérifier** que "Fish S2-Pro" est sélectionné par défaut

### Test 2 : Projet existant

1. **Ouvrir votre projet existant**
2. **Aller dans Voix → Cliquer sur 🔊**
3. **Changer** vers "TTS Audiobook Tool (Local)"
4. **Choisir** "Chatterbox"
5. **Enregistrer**
6. **Fermer et rouvrir le projet**
7. **Vérifier** que TTS Audiobook Tool + Chatterbox sont toujours sélectionnés

---

## 📝 Vérification dans le fichier JSON

### Nouveau projet

```bash
cat /Volumes/J3THext/Audiobookforge/audio/Projects/NOUVEAU_PROJET/project.json | jq '.voiceConfig.preferredProvider'
```

Devrait afficher : `"ttsAudiobookTool"`

### Projet existant (après changement manuel)

```bash
cat /Volumes/J3THext/Audiobookforge/audio/Projects/PROJET_EXISTANT/project.json | jq '.voiceConfig.preferredProvider'
```

Devrait afficher : `"ttsAudiobookTool"` (après avoir changé dans l'app)

---

## 🚀 Prochaines étapes

1. **Relancer l'application** :
   ```bash
   open /Volumes/J3THext/Audiobookforge/AudiobookForge.app
   ```

2. **Pour votre projet existant** :
   - Ouvrir le projet
   - Aller dans Voix → 🔊
   - Changer vers "TTS Audiobook Tool (Local)"
   - Choisir "Chatterbox"
   - **Enregistrer**

3. **Tester la génération** :
   - Aller dans l'onglet "Génération"
   - Générer un chapitre
   - Vérifier qu'il utilise TTS Audiobook Tool (pas Fish.Audio API)

---

## 🔍 Logs de débogage

Pour vérifier quel provider est utilisé lors de la génération :

```bash
tail -f ~/Library/Logs/AudiobookForge/audiobookforge-$(date +%Y-%m-%d).log | grep "preferredProvider"
```

Vous devriez voir :
```
🔍 DEBUG generateChunkAudio:
  - preferredProvider: ttsAudiobookTool
  - provider: ttsAudiobookTool
  ✅ Utilisation de TTS Audiobook Tool
```

---

## ✅ Résumé des changements

| Avant | Après |
|-------|-------|
| `preferredProvider = .fishAudio` | `preferredProvider = .ttsAudiobookTool` |
| Nouveaux projets → Fish.Audio API | Nouveaux projets → TTS Audiobook Tool |
| Fallback vers Fish.Audio | Fallback vers TTS Audiobook Tool |

---

**Correctif appliqué ! L'application a été recompilée et mise à jour.** 🎉

**IMPORTANT** : Pour votre projet existant, vous devez **manuellement** changer le provider dans les réglages audio, car il conserve l'ancienne valeur `fishAudio`.
