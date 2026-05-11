# AudiobookForge - Analyse complète et corrections nécessaires

## 📋 Résumé exécutif

L'application AudiobookForge est une application macOS native en SwiftUI pour générer des audiobooks localement. Après analyse complète du code, voici les bugs, problèmes et optimisations identifiés.

---

## 🐛 BUGS CRITIQUES

### 1. **NSUserNotification API dépréciée (macOS 11+)**
**Fichier:** `AudiobookForge/ViewModels/PipelineViewModel.swift:365-368`

**Problème:**
```swift
let notification = NSUserNotification()
notification.title = "AudiobookForge"
notification.informativeText = "Export terminé : \(exportedFiles.count) fichier(s)"
NSUserNotificationCenter.default.deliver(notification)
```

`NSUserNotification` est **déprécié depuis macOS 11** et ne fonctionne plus sur macOS 14+.

**Solution:** Utiliser `UNUserNotificationCenter` (UserNotifications framework)

---

### 2. **Chemin ffmpeg hardcodé incorrect**
**Fichiers:** 
- `AudiobookForge/Services/AudioGenerationService.swift:220, 239`
- `AudiobookForge/Services/ExportService.swift:133, 191, 240`

**Problème:**
```swift
process.executableURL = URL(fileURLWithPath: "/usr/bin/ffmpeg")
```

Sur macOS avec Homebrew (Apple Silicon), ffmpeg est installé dans `/opt/homebrew/bin/ffmpeg`, pas `/usr/bin/ffmpeg`.

**Solution:** Utiliser une fonction de résolution dynamique comme pour Python/Ollama

---

### 3. **Chemin ffprobe hardcodé**
**Fichier:** `AudiobookForge/Services/ExportService.swift:240`

**Problème:**
```swift
process.executableURL = URL(fileURLWithPath: "/usr/bin/ffprobe")
```

Même problème que ffmpeg.

---

### 4. **Fallback hardcodé dans TextExtractorService**
**Fichier:** `AudiobookForge/Services/TextExtractorService.swift:35`

**Problème:**
```swift
backendScriptsPath = "/Volumes/J3THext/Audiobookforge/backend/scripts"
```

Ce chemin est spécifique à votre machine et ne fonctionnera pas sur d'autres systèmes.

**Solution:** Supprimer ce fallback ou utiliser un chemin relatif au bundle

---

### 5. **Même problème dans AudioGenerationService**
**Fichier:** `AudiobookForge/Services/AudioGenerationService.swift:34`

```swift
backendScriptsPath = "/Volumes/J3THext/Audiobookforge/backend/scripts"
```

---

### 6. **Docker volumes hardcodés**
**Fichier:** `docker-compose.yml:51-57`

**Problème:**
```yaml
driver_opts:
  type: none
  device: /Volumes/EXTERNAL_DRIVE/audiobookforge/ollama
  o: bind
```

Le chemin `/Volumes/EXTERNAL_DRIVE` est un placeholder qui ne fonctionnera pas.

**Solution:** Utiliser des volumes Docker normaux ou documenter la configuration

---

### 7. **Modèle Fish S2 Pro hardcodé**
**Fichier:** `AudiobookForge/Services/AudioGenerationService.swift:116`

**Problème:**
```swift
"--model-dir", "models/fishaudio-s2-pro-8bit-mlx",
```

Le chemin est relatif et ne pointe pas vers le bon emplacement. Le script Python attend un chemin absolu ou un repo HuggingFace.

**Solution:** Utiliser le repo HF par défaut ou résoudre le chemin absolu

---

## ⚠️ PROBLÈMES MAJEURS

### 8. **Architecture hybride confuse (Docker + Native)**
**Fichiers:** `docker-compose.yml`, `backend/api.py`, tous les services Swift

**Problème:**
- Le `docker-compose.yml` définit des services backend et Ollama
- Mais le code Swift appelle directement les scripts Python locaux (pas via Docker)
- L'API FastAPI dans `backend/api.py` n'est jamais utilisée par l'app Swift
- Ollama est censé tourner en natif (via brew) mais aussi en Docker

**Impact:** Architecture incohérente, confusion sur ce qui tourne où

**Solution:** Choisir une architecture claire :
- **Option A:** Tout en natif (supprimer Docker)
- **Option B:** Backend en Docker, app Swift communique via HTTP
- **Option C:** Documenter clairement que Docker est optionnel

---

### 9. **mlx-speech ne peut pas tourner dans Docker**
**Fichier:** `Dockerfile.backend`, `docker-compose.yml:42-43`

**Problème:**
```yaml
# mlx-speech nécessite un environnement Mac natif, pas Docker
# Ce container sert surtout pour l'extraction de texte
```

Le commentaire l'admet : **mlx-speech ne fonctionne pas dans Docker** car il nécessite l'accès direct au GPU Apple Silicon (MPS).

**Impact:** Le container backend ne peut pas faire de génération audio, seulement de l'extraction de texte.

**Solution:** Documenter clairement que la génération audio doit être native

---

### 10. **Gestion d'erreur manquante dans les Process**
**Fichiers:** Tous les services qui utilisent `Process()`

**Problème:**
```swift
try process.run()
process.waitUntilExit()
```

Aucune gestion du timeout, aucun kill du process si l'app se ferme.

**Solution:** Ajouter des timeouts et cleanup dans `deinit`

---

### 11. **Pas de vérification de l'espace disque**
**Problème:** La génération audio peut créer des dizaines de Go de fichiers WAV sans vérifier l'espace disponible.

**Solution:** Vérifier l'espace disque avant de commencer la génération

---

### 12. **Chunks non nettoyés après assemblage**
**Fichier:** `AudiobookForge/Services/AudioGenerationService.swift:196-197`

**Problème:** Les fichiers chunks individuels ne sont jamais supprimés après l'assemblage du chapitre.

**Solution:** Ajouter un nettoyage optionnel des chunks

---

## 🔧 OPTIMISATIONS

### 13. **Regex de chunking inefficace**
**Fichier:** `AudiobookForge/Services/AudioGenerationService.swift:42-43`

**Problème:**
```swift
let pattern = "(?:(?!([.!?…]\\s|\\n))[^.!?…\\n])+[.!?…]?"
```

Cette regex est complexe et peut être lente sur de gros textes.

**Solution:** Utiliser une approche plus simple avec `components(separatedBy:)`

---

### 14. **Pas de cache pour les modèles**
**Problème:** Le modèle Fish S2 Pro est rechargé à chaque chunk (très lent).

**Solution:** Garder le modèle en mémoire entre les chunks d'un même chapitre

---

### 15. **Normalisation audio séquentielle**
**Fichier:** `AudiobookForge/ViewModels/PipelineViewModel.swift:301`

**Problème:** La normalisation est faite après chaque chapitre, ce qui ralentit le pipeline.

**Solution:** Normaliser en batch à la fin ou en parallèle

---

### 16. **Pas de parallélisation**
**Problème:** Tout est séquentiel (extraction, tagging, génération).

**Solution:** Paralléliser les chapitres indépendants (surtout pour le tagging Ollama)

---

### 17. **Pas de reprise après erreur**
**Problème:** Si un chunk échoue, tout le chapitre échoue. Si un chapitre échoue, la génération continue mais l'état n'est pas bien géré.

**Solution:** Implémenter une vraie reprise avec sauvegarde de l'état des chunks

---

## 📝 PROBLÈMES DE CODE

### 18. **Duplication de code**
**Fichiers:** `ProjectManager.swift`, `TextExtractorService.swift`, `AudioGenerationService.swift`

**Problème:** La fonction `resolveProjectRoot()` et `resolvePythonPath()` sont dupliquées dans 3 fichiers.

**Solution:** Créer un service `PathResolver` partagé

---

### 19. **Pas de logging structuré**
**Problème:** Les erreurs sont juste affichées dans l'UI, pas de logs persistants.

**Solution:** Implémenter un système de logging (fichier + console)

---

### 20. **Pas de tests**
**Problème:** Aucun test unitaire ou d'intégration.

**Solution:** Ajouter des tests au moins pour les fonctions critiques (chunking, extraction, etc.)

---

### 21. **Hardcoded strings partout**
**Problème:** Les messages d'erreur, les prompts Ollama, etc. sont hardcodés.

**Solution:** Externaliser dans des fichiers de configuration ou des constantes

---

### 22. **Prompt Ollama dupliqué**
**Fichiers:** `backend/api.py:137-154`, `AudiobookForge/Services/OllamaService.swift:54-73`

**Problème:** Le même prompt est défini en Python et en Swift.

**Solution:** Centraliser dans un fichier de config

---

## 🔒 PROBLÈMES DE SÉCURITÉ

### 23. **Pas de validation des entrées utilisateur**
**Problème:** Les chemins de fichiers, les textes, etc. ne sont pas validés avant d'être passés aux scripts Python.

**Solution:** Ajouter des validations (taille max, caractères interdits, etc.)

---

### 24. **Injection de commande potentielle**
**Fichier:** `AudiobookForge/Services/AudioGenerationService.swift:113-129`

**Problème:** Les arguments sont construits directement depuis les inputs utilisateur.

**Solution:** Échapper les arguments ou utiliser une API plus sûre

---

## 📚 PROBLÈMES DE DOCUMENTATION

### 25. **README incomplet**
**Problème:** Le README ne mentionne pas :
- Que Docker est optionnel
- Que mlx-speech ne fonctionne pas dans Docker
- Les limitations de l'architecture

---

### 26. **Pas de documentation API**
**Problème:** Aucune documentation des fonctions, des paramètres, des retours.

**Solution:** Ajouter des docstrings partout

---

### 27. **Scripts d'installation contradictoires**
**Fichiers:** `install_external.sh`, `setup_ai_models.sh`, `start.sh`

**Problème:** 3 scripts différents qui font des choses similaires mais pas identiques.

**Solution:** Unifier en un seul script d'installation

---

## 🎨 PROBLÈMES D'UX

### 28. **Pas de preview avant génération**
**Problème:** L'utilisateur ne peut pas écouter un sample avant de lancer la génération complète.

**Solution:** Implémenter un vrai preview (déjà prévu dans le code mais pas utilisé)

---

### 29. **Pas d'estimation de temps**
**Problème:** Aucune indication du temps restant pour la génération.

**Solution:** Calculer une estimation basée sur la vitesse des chunks précédents

---

### 30. **Pas d'annulation propre**
**Problème:** Le bouton pause existe mais l'annulation complète n'est pas implémentée.

**Solution:** Ajouter un bouton "Annuler" qui kill les process en cours

---

## 🔍 PROBLÈMES DE CONFIGURATION

### 31. **Package.swift minimal**
**Fichier:** `Package.swift`

**Problème:** Aucune dépendance externe, tout est fait à la main.

**Solution:** Utiliser des packages Swift pour HTTP, JSON, etc.

---

### 32. **Info.plist incomplet**
**Fichier:** `AudiobookForge/Info.plist`

**Problème:** Manque les permissions (microphone pour le sample vocal, fichiers, etc.)

**Solution:** Ajouter les clés NSMicrophoneUsageDescription, etc.

---

### 33. **AppIcon.png non déclaré**
**Warning du build:**
```
warning: found 1 file(s) which are unhandled; explicitly declare them as resources
    /Volumes/J3THext/Audiobookforge/AudiobookForge/AppIcon.png
```

**Solution:** Ajouter dans Package.swift comme resource ou exclure

---

## 🚀 AMÉLIORATIONS SUGGÉRÉES

### 34. **Ajouter un système de plugins pour les voix**
Permettre d'ajouter plusieurs profils vocaux et de les sélectionner par chapitre.

---

### 35. **Ajouter un éditeur de texte intégré**
Pour corriger les erreurs d'extraction avant le tagging.

---

### 36. **Ajouter un visualiseur de waveform**
Pour voir l'audio généré directement dans l'app.

---

### 37. **Ajouter un système de templates pour les prompts**
Permettre à l'utilisateur de personnaliser le prompt Ollama.

---

### 38. **Ajouter un mode "rapide" avec moins de qualité**
Pour tester rapidement sans attendre des heures.

---

### 39. **Ajouter un export vers des plateformes**
(Audible, Apple Books, etc.)

---

### 40. **Ajouter un système de backup automatique**
Pour ne pas perdre des heures de génération en cas de crash.

---

## 📊 PRIORITÉS DE CORRECTION

### 🔴 CRITIQUE (à corriger immédiatement)
1. NSUserNotification déprécié → UNUserNotificationCenter
2. Chemins ffmpeg/ffprobe hardcodés → Résolution dynamique
3. Fallbacks hardcodés spécifiques à votre machine → Supprimer
4. Modèle Fish S2 Pro hardcodé → Utiliser repo HF par défaut

### 🟠 IMPORTANT (à corriger rapidement)
5. Architecture Docker/Native confuse → Documenter ou simplifier
6. Gestion d'erreur manquante dans Process → Ajouter timeouts
7. Chunks non nettoyés → Ajouter cleanup
8. Duplication de code → Créer PathResolver service
9. Pas de logging → Implémenter système de logs

### 🟡 MOYEN (à corriger quand possible)
10. Regex de chunking inefficace → Simplifier
11. Pas de cache pour les modèles → Implémenter
12. Pas de parallélisation → Ajouter pour tagging
13. Pas de reprise après erreur → Implémenter état des chunks
14. Prompt Ollama dupliqué → Centraliser

### 🟢 MINEUR (nice to have)
15. Pas de tests → Ajouter tests unitaires
16. Documentation incomplète → Améliorer README
17. Scripts d'installation contradictoires → Unifier
18. Pas d'estimation de temps → Calculer ETA
19. AppIcon.png warning → Déclarer comme resource

---

## 🛠️ PLAN D'ACTION RECOMMANDÉ

### Phase 1 : Corrections critiques (1-2 jours)
- [ ] Remplacer NSUserNotification par UNUserNotificationCenter
- [ ] Créer PathResolver service pour ffmpeg/ffprobe/python
- [ ] Supprimer tous les fallbacks hardcodés
- [ ] Fixer le chemin du modèle Fish S2 Pro

### Phase 2 : Stabilisation (3-5 jours)
- [ ] Ajouter gestion d'erreur et timeouts dans tous les Process
- [ ] Implémenter système de logging
- [ ] Nettoyer les chunks après assemblage
- [ ] Documenter l'architecture (Docker optionnel)

### Phase 3 : Optimisations (1 semaine)
- [ ] Simplifier le chunking
- [ ] Ajouter cache pour les modèles
- [ ] Paralléliser le tagging Ollama
- [ ] Implémenter reprise après erreur

### Phase 4 : Qualité (1 semaine)
- [ ] Ajouter tests unitaires
- [ ] Améliorer la documentation
- [ ] Unifier les scripts d'installation
- [ ] Ajouter estimation de temps

---

## 📝 NOTES FINALES

L'application est **fonctionnelle** mais souffre de plusieurs problèmes de robustesse et de portabilité. Les corrections critiques sont nécessaires pour qu'elle fonctionne sur d'autres machines que la vôtre.

Le code Swift est globalement bien structuré (MVVM, services séparés), mais manque de gestion d'erreur et de logging. Le code Python est simple et efficace.

L'architecture hybride Docker/Native est le plus gros problème conceptuel : il faut choisir une direction claire.

**Estimation totale pour corriger tous les problèmes critiques et importants : 1-2 semaines de développement.**
