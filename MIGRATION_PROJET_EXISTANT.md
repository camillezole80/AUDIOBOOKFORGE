# 🔄 Migration du projet existant vers le nouveau format

**Date** : 18/05/2026 18:22  
**Problème** : Le projet existant utilise l'ancien format de provider

---

## ✅ Migration effectuée

Le fichier `project.json` de votre projet a été migré du format :
```json
"preferredProvider": "Fish.Audio API"
```

Vers le nouveau format :
```json
"preferredProvider": "fishAudio"
```

---

## 🎯 Prochaines étapes

### 1. Fermer et rouvrir l'application

```bash
pkill AudiobookForge
open /Volumes/J3THext/Audiobookforge/AudiobookForge.app
```

### 2. Ouvrir votre projet

Le projet devrait maintenant charger correctement avec le provider `fishAudio`.

### 3. Changer pour TTS Audiobook Tool

1. Aller dans l'étape "Voix"
2. Cliquer sur l'icône 🔊 (Audio Settings)
3. Sélectionner "TTS Audiobook Tool (Local)"
4. Choisir "Chatterbox"
5. **Enregistrer**

Cette fois, le provider sera sauvegardé comme :
```json
"preferredProvider": "ttsAudiobookTool",
"ttsModel": "chatterbox"
```

---

## 📝 Vérification

Pour vérifier que tout fonctionne :

```bash
# Vérifier le provider dans le projet
cat /Volumes/J3THext/Audiobookforge/audio/Projects/*/project.json | jq '.voiceConfig.preferredProvider'
```

Devrait afficher : `"ttsAudiobookTool"` (après avoir changé dans l'app)

---

## 🐛 Si le problème persiste

Si vous voyez toujours l'erreur Fish.Audio API, c'est que :

1. **L'application n'a pas rechargé le projet** : Fermez complètement l'app et rouvrez-la
2. **Le projet n'a pas été sauvegardé** : Ouvrez les Audio Settings, changez le provider, et cliquez sur "Enregistrer"
3. **Cache de l'application** : Supprimez le cache :
   ```bash
   rm -rf ~/Library/Caches/AudiobookForge
   ```

---

## 🔍 Logs de débogage

Pour voir ce qui se passe lors de la génération :

```bash
tail -f ~/Library/Logs/AudiobookForge/audiobookforge-$(date +%Y-%m-%d).log
```

Vous devriez voir :
```
🔍 DEBUG generateChunkAudio:
  - preferredProvider: ttsAudiobookTool
  - provider: ttsAudiobookTool
  ✅ Utilisation de TTS Audiobook Tool
```

Au lieu de :
```
  - preferredProvider: fishAudio
  ✅ Utilisation de Fish.Audio API
```

---

**Migration terminée ! Relancez l'application et testez.** 🎉
