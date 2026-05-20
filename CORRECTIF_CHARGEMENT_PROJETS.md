# 🔧 Correctif : Chargement des projets + Provider par défaut

**Date** : 18/05/2026 18:46  
**Problèmes résolus** : 
1. Projets qui disparaissent au relancement
2. Provider qui revient toujours à Fish.Audio

---

## 🐛 Problèmes identifiés

### 1. Projets qui disparaissent

**Cause** : Le `ProjectManager` chargeait uniquement depuis `~/Library/Application Support/AudiobookForge/Projects/projects.json`, mais les projets réels sont dans `/Volumes/J3THext/Audiobookforge/audio/Projects/`.

Si le fichier `projects.json` était corrompu ou contenait un ancien format incompatible, les projets n'étaient pas chargés.

### 2. Provider qui revient à Fish.Audio

**Cause** : La valeur par défaut dans `VoiceConfig` était `.fishAudio` au lieu de `.ttsAudiobookTool`.

---

## ✅ Solutions appliquées

### 1. Système de scan automatique des projets

Ajout d'une fonction `scanProjectDirectories()` dans `ProjectManager` :

```swift
private func scanProjectDirectories() {
    // Scanner le dossier /Volumes/J3THext/Audiobookforge/audio/Projects
    let audioProjectsDir = "/Volumes/J3THext/Audiobookforge/audio/Projects"
    
    guard let contents = try? FileManager.default.contentsOfDirectory(atPath: audioProjectsDir) else {
        logger.warning("Could not scan audio projects directory")
        return
    }
    
    var scannedProjects: [Project] = []
    
    for projectName in contents {
        let projectPath = "\(audioProjectsDir)/\(projectName)"
        let projectJsonPath = "\(projectPath)/project.json"
        
        guard FileManager.default.fileExists(atPath: projectJsonPath) else {
            continue
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: projectJsonPath)) else {
            logger.warning("Could not read project.json for \(projectName)")
            continue
        }
        
        let decoder = JSONDecoder()
        do {
            let project = try decoder.decode(Project.self, from: data)
            scannedProjects.append(project)
            logger.info("✅ Scanned project: \(project.name)")
        } catch {
            logger.error("❌ Failed to decode project \(projectName): \(error.localizedDescription)")
        }
    }
    
    projects = scannedProjects
    logger.info("✅ Scanned \(projects.count) projects from directories")
    
    // Sauvegarder la liste pour la prochaine fois
    saveProjectsList()
}
```

**Comportement** :
- Si `projects.json` n'existe pas → scan automatique
- Si `projects.json` est corrompu → scan automatique avec log d'erreur
- Les projets sont toujours chargés, même si le format JSON a changé

### 2. Changement de la valeur par défaut du provider

Dans `AudiobookForge/Models/Project.swift` :

```swift
// AVANT
var preferredProvider: AudioProvider = .fishAudio

// APRÈS
var preferredProvider: AudioProvider = .ttsAudiobookTool
```

---

## 🎯 Résultat

### Chargement des projets

Maintenant, au lancement de l'application :

1. **Tentative de chargement depuis projects.json**
2. **Si échec** → Scan automatique de `/Volumes/J3THext/Audiobookforge/audio/Projects/`
3. **Chargement de tous les projets trouvés**
4. **Sauvegarde de la liste mise à jour**

### Provider par défaut

- **Nouveaux projets** : TTS Audiobook Tool par défaut
- **Projets existants** : Conservent leur configuration (fishAudio si c'était l'ancienne valeur)

---

## 🔄 Comment tester

### Test 1 : Vérifier que les projets sont chargés

1. **Relancer l'application**
2. **Vérifier** que vos 2 projets apparaissent dans la liste
3. **Ouvrir un projet**
4. **Vérifier** qu'il charge correctement

### Test 2 : Changer le provider

1. **Ouvrir votre projet existant**
2. **Aller dans Voix → Cliquer sur 🔊**
3. **Changer** vers "TTS Audiobook Tool (Local)"
4. **Choisir** "Chatterbox"
5. **Enregistrer**
6. **Fermer et rouvrir le projet**
7. **Vérifier** que TTS Audiobook Tool + Chatterbox sont toujours sélectionnés

### Test 3 : Créer un nouveau projet

1. **Créer un nouveau projet**
2. **Aller dans Voix → Cliquer sur 🔊**
3. **Vérifier** que "TTS Audiobook Tool (Local)" est sélectionné par défaut
4. **Vérifier** que "Fish S2-Pro" est sélectionné par défaut

---

## 📝 Vérification dans les logs

Pour voir ce qui se passe au chargement :

```bash
tail -f ~/Library/Logs/AudiobookForge/audiobookforge-$(date +%Y-%m-%d).log | grep -E "ProjectManager|Scanned|Loaded"
```

Vous devriez voir :
```
ProjectManager initialized. Projects directory: ...
No projects list found, scanning project directories...
✅ Scanned project: nomduvent1
✅ Scanned project: adler_le_sens_de_la_vie
✅ Scanned 2 projects from directories
```

Ou si `projects.json` existe et est valide :
```
ProjectManager initialized. Projects directory: ...
✅ Loaded 2 projects from list
```

---

## 🔍 Vérification du provider dans le JSON

```bash
cat /Volumes/J3THext/Audiobookforge/audio/Projects/nomduvent1/project.json | jq '.voiceConfig.preferredProvider'
```

**Avant changement** : `"fishAudio"`  
**Après changement dans l'app** : `"ttsAudiobookTool"`

---

## ✅ Résumé des correctifs

| Problème | Solution | Fichier modifié |
|----------|----------|-----------------|
| Projets disparaissent | Scan automatique des dossiers | `ProjectManager.swift` |
| Erreur de décodage JSON | Gestion d'erreur + fallback | `ProjectManager.swift` |
| Provider par défaut = fishAudio | Changé vers ttsAudiobookTool | `Project.swift` |

---

**Correctifs appliqués ! L'application devrait maintenant :**
- ✅ Charger tous vos projets au démarrage
- ✅ Utiliser TTS Audiobook Tool par défaut pour les nouveaux projets
- ✅ Persister correctement le provider choisi

**IMPORTANT** : Pour votre projet existant, vous devez **manuellement** changer le provider dans les réglages audio, car il conserve l'ancienne valeur `fishAudio`.
