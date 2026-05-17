# Test de persistance des paramètres audio

## Modifications apportées

### 1. ProjectManager.saveProject() - Logs détaillés
- ✅ Ajout de logs pour tracer l'encodage et l'écriture du fichier JSON
- ✅ Affichage de la taille du fichier sauvegardé
- ✅ Logs des paramètres audio (provider, forceRemote, fallbackToRemote)
- ✅ Gestion des erreurs avec messages explicites

### 2. PipelineViewModel.updateVoiceConfig() - Logs améliorés
- ✅ Vérification que le projet est chargé
- ✅ Logs détaillés des paramètres reçus
- ✅ Confirmation de la sauvegarde sur disque

## Procédure de test

### Étape 1 : Lancer l'application
```bash
cd /Volumes/J3THext/Audiobookforge
./run.sh
```

### Étape 2 : Ouvrir un projet existant
- Ouvrir le projet "test"
- Aller à l'étape "Voix"

### Étape 3 : Configurer les paramètres audio
1. Cliquer sur l'icône de configuration audio (haut-parleur vert)
2. Sélectionner "Fish.Audio API" comme provider
3. Activer "Forcer l'utilisation de l'API distante"
4. Cliquer sur "Enregistrer"

### Étape 4 : Vérifier les logs dans la console
Rechercher dans les logs :
```
🔧 updateVoiceConfig called:
  - Project: test
  - preferredProvider: Fish.Audio API
  - forceRemote: true
  - fallbackToRemote: true
  - selectedVoice: none
  - hasValidReference: true
✅ VoiceConfig updated and saved to disk

✅ Project saved: test (XXXX bytes)
  - Audio provider: Fish.Audio API
  - Force remote: true
  - Fallback to remote: true
```

### Étape 5 : Vérifier le fichier JSON sur disque
```bash
cat "/Volumes/J3THext/Audiobookforge/audio/Projects/test/project.json" | jq '.voiceConfig'
```

Vérifier que les champs sont présents :
```json
{
  "preferredProvider": "Fish.Audio API",
  "forceRemote": true,
  "fallbackToRemote": true,
  "referenceAudioPath": "...",
  "referenceTranscription": "...",
  "speedScale": 1.0,
  "temperature": 0.8
}
```

### Étape 6 : Relancer l'application
1. Quitter l'application (Cmd+Q)
2. Relancer avec `./run.sh`
3. Ouvrir le projet "test"
4. Aller à l'étape "Voix"
5. Cliquer sur l'icône de configuration audio

### Étape 7 : Vérifier que les paramètres sont chargés
- ✅ "Fish.Audio API" doit être sélectionné
- ✅ "Forcer l'utilisation de l'API distante" doit être activé
- ✅ "Fallback automatique" doit être activé

## Résultats attendus

Si tout fonctionne correctement :
1. Les logs confirment la sauvegarde
2. Le fichier JSON contient les bons paramètres
3. Les paramètres sont rechargés au redémarrage

## En cas de problème

### Si les logs ne s'affichent pas
- Vérifier que l'application est lancée depuis le terminal
- Vérifier que Logger.shared est bien configuré

### Si le fichier JSON n'est pas mis à jour
- Vérifier les permissions d'écriture sur `/Volumes/J3THext/Audiobookforge/audio/Projects/`
- Vérifier que le disque externe est bien monté

### Si les paramètres ne sont pas rechargés
- Vérifier que `ProjectManager.loadProjectState()` est appelé au démarrage
- Vérifier que le décodage JSON fonctionne (pas d'erreur de désérialisation)

## Diagnostic supplémentaire

Si le problème persiste, ajouter des logs dans :
1. `ProjectManager.loadProjectState()` pour voir si le projet est bien rechargé
2. `AudioSettingsView.onAppear()` pour voir si les valeurs sont bien initialisées
3. `PipelineViewModel.loadProject()` pour voir si le projet est bien chargé dans le ViewModel
