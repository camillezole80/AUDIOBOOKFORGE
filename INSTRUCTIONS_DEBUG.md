# 🔍 Instructions pour déboguer le problème de persistance du provider

**Date** : 18/05/2026 19:13  
**Objectif** : Identifier pourquoi le provider revient toujours à Fish.Audio API

---

## 📋 Logs de debug ajoutés

J'ai ajouté des logs détaillés dans 2 fichiers :

### 1. AudioSettingsView.swift (fonction saveSettings)

Affiche :
- Les valeurs AVANT sauvegarde dans le binding
- Les valeurs APRÈS sauvegarde dans le binding
- Confirmation de l'envoi de la notification SaveProject

### 2. PipelineViewModel.swift (fonction saveCurrentProject)

Affiche :
- Le nom du projet
- Le preferredProvider actuel
- Le ttsModel actuel
- Confirmation de l'appel à projectManager.updateProject()

---

## 🧪 Comment tester

### Étape 1 : Ouvrir la Console

1. **Ouvrir l'application Console** (dans /Applications/Utilitaires/)
2. **Filtrer** par "AudiobookForge" ou "saveSettings"

### Étape 2 : Tester le changement de provider

1. **Ouvrir votre projet** dans AudiobookForge
2. **Aller dans Voix → Cliquer sur 🔊**
3. **Changer** vers "TTS Audiobook Tool (Local)"
4. **Choisir** "Chatterbox"
5. **Cliquer sur "Enregistrer"**

### Étape 3 : Analyser les logs

Vous devriez voir dans la Console :

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 AudioSettings.saveSettings() appelé
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 Valeurs AVANT sauvegarde dans le binding:
  - voiceConfig.preferredProvider (binding): fishAudio
  - localProvider (state): ttsAudiobookTool

📝 Valeurs APRÈS sauvegarde dans le binding:
  - voiceConfig.preferredProvider: ttsAudiobookTool
  - forceRemote: false
  - fallbackToRemote: true
  - selectedVoice: none
  - ttsModel: chatterbox

📤 Envoi de la notification SaveProject...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Notification SaveProject envoyée
```

Puis :

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💾 PipelineViewModel.saveCurrentProject() appelé
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 Projet actuel:
  - Nom: nomduvent1
  - preferredProvider: ttsAudiobookTool
  - ttsModel: chatterbox

📤 Appel de projectManager.updateProject()...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ projectManager.updateProject() terminé
```

### Étape 4 : Vérifier le fichier JSON

```bash
cat /Volumes/J3THext/Audiobookforge/audio/Projects/nomduvent1/project.json | jq '.voiceConfig.preferredProvider'
```

Devrait afficher : `"ttsAudiobookTool"`

### Étape 5 : Fermer et rouvrir le projet

1. **Fermer le projet** (retour à la liste des projets)
2. **Rouvrir le projet**
3. **Aller dans Voix → Cliquer sur 🔊**
4. **Vérifier** quel provider est sélectionné

---

## 🔍 Scénarios possibles

### Scénario A : Les logs n'apparaissent pas

**Problème** : La fonction saveSettings() n'est pas appelée

**Solution** : Vérifier que le bouton "Enregistrer" est bien cliqué

### Scénario B : Les logs apparaissent mais le JSON ne change pas

**Problème** : projectManager.updateProject() ne sauvegarde pas correctement

**Solution** : Vérifier ProjectManager.swift ligne 77-90

### Scénario C : Le JSON change mais revient à l'ancienne valeur

**Problème** : Le projet est rechargé depuis le disque après sauvegarde

**Solution** : Vérifier ProjectManager.loadProjectState() ligne 132-143

### Scénario D : Le provider est correct au chargement mais change après

**Problème** : Un autre code modifie le provider

**Solution** : Chercher d'autres appels à `updateVoiceConfig()` ou `updateProject()`

---

## 📤 Ce que je dois savoir

**Copiez-collez les logs de la Console** après avoir testé, et dites-moi :

1. **Les logs apparaissent-ils ?**
2. **Quelle est la valeur de preferredProvider dans les logs ?**
3. **Le fichier JSON est-il modifié ?**
4. **Le provider persiste-t-il après fermeture/réouverture ?**

Avec ces informations, je pourrai identifier le problème exact et le corriger.

---

**L'application a été recompilée avec les logs de debug. Testez maintenant et envoyez-moi les résultats.**
