# 🔍 Audit complet de l'application AudiobookForge

**Date** : 18/05/2026 19:05  
**Objectif** : Identifier TOUS les problèmes liés au provider audio et à l'ancien pipeline MLX

---

## 📋 Checklist d'audit

### ✅ Problèmes déjà corrigés

1. **Enum AudioProvider** : rawValue simples (`fishAudio`, `ttsAudiobookTool`, `local`) ✅
2. **Valeur par défaut** : `.ttsAudiobookTool` au lieu de `.fishAudio` ✅
3. **Chargement des projets** : Scan automatique des dossiers ✅
4. **Message MLX dans VoiceStepView** : Supprimé ✅
5. **Boutons de réinitialisation** : Ajoutés ✅

### 🔍 Points à vérifier

#### 1. Fichiers de configuration existants

```bash
# Vérifier le contenu actuel du project.json
cat /Volumes/J3THext/Audiobookforge/audio/Projects/nomduvent1/project.json | jq '.voiceConfig'
```

**Question** : Le provider est-il toujours `fishAudio` après tous les correctifs ?

#### 2. Workflow de sauvegarde

**Fichiers concernés** :
- `AudiobookForge/Views/AudioSettingsView.swift` : Bouton "Enregistrer"
- `AudiobookForge/ViewModels/PipelineViewModel.swift` : Fonction `updateVoiceConfig()`
- `AudiobookForge/Services/ProjectManager.swift` : Fonction `updateProject()`

**Question** : La sauvegarde est-elle bien déclenchée ?

#### 3. Références à MLX dans le code

**Recherche effectuée** : 21 occurrences trouvées

**Fichiers à auditer** :
1. `AudiobookForge/Services/ProjectManager.swift` : Vérification `mlx_speech`
2. `AudiobookForge/Services/AudioGenerationService.swift` : Fonction `generateChunkViaMLX()`
3. `AudiobookForge/Views/GenerationStepView.swift` : Texte "Fish S2 Pro MLX"
4. `AudiobookForge/Views/DependencyCheckView.swift` : "Fish S2 Pro MLX"
5. `AudiobookForge/Views/ContextualSettingsView.swift` : "Fish Audio S2 Pro via MLX"

#### 4. Logique de sélection du provider

**Fichier** : `AudiobookForge/Services/AudioGenerationService.swift`

**Code actuel** (lignes 78-100) :
```swift
switch provider {
case .fishAudio:
    // Utiliser Fish.Audio API
    try await generateChunkViaFishAudio(...)
    
case .ttsAudiobookTool:
    // Utiliser TTS Audiobook Tool
    try await generateChunkViaTtsAudiobookTool(...)
    
case .local:
    // Utiliser MLX local (code original)
    try await generateChunkViaMLX(...)
}
```

**Question** : Le case `.local` est-il toujours accessible ? Devrait-il être supprimé ?

---

## 🎯 Plan d'action complet

### Phase 1 : Vérification de l'état actuel

1. **Tester l'application** :
   - Ouvrir un projet
   - Aller dans Voix → 🔊
   - Changer vers TTS Audiobook Tool + Chatterbox
   - Enregistrer
   - Fermer et rouvrir le projet
   - **Vérifier** si le provider persiste

2. **Vérifier les logs** :
   ```bash
   tail -f ~/Library/Logs/AudiobookForge/audiobookforge-$(date +%Y-%m-%d).log
   ```

3. **Vérifier le JSON** :
   ```bash
   cat /Volumes/J3THext/Audiobookforge/audio/Projects/nomduvent1/project.json | jq '.voiceConfig.preferredProvider'
   ```

### Phase 2 : Corrections supplémentaires si nécessaire

#### Si le provider ne persiste toujours pas :

**Hypothèse 1** : Le bouton "Enregistrer" ne déclenche pas la sauvegarde
- Vérifier `AudioSettingsView.swift` ligne ~500
- Ajouter des logs de debug

**Hypothèse 2** : La notification n'est pas reçue
- Vérifier `PipelineViewModel.swift` ligne ~60
- Vérifier que `NotificationCenter` fonctionne

**Hypothèse 3** : Le projet est rechargé depuis le disque après sauvegarde
- Vérifier `ProjectManager.loadProjectState()`
- S'assurer que la version en mémoire est utilisée

#### Si des messages MLX apparaissent encore :

**Action** : Rechercher et supprimer toutes les références visibles à MLX
- `GenerationStepView.swift` : Ligne 17 "Fish S2 Pro MLX"
- `DependencyCheckView.swift` : Ligne avec "Fish S2 Pro MLX"
- `ContextualSettingsView.swift` : Ligne avec "Fish Audio S2 Pro via MLX"

### Phase 3 : Nettoyage complet

1. **Supprimer le case `.local`** de l'enum `AudioProvider` (si non utilisé)
2. **Supprimer la fonction `generateChunkViaMLX()`** (si non utilisée)
3. **Mettre à jour tous les commentaires** faisant référence à MLX

---

## 🚨 Questions critiques à répondre

1. **Le provider persiste-t-il après fermeture/réouverture du projet ?**
   - [ ] Oui → Problème résolu
   - [ ] Non → Continuer l'audit

2. **Des messages MLX apparaissent-ils encore dans l'interface ?**
   - [ ] Non → Problème résolu
   - [ ] Oui → Identifier et supprimer

3. **La génération audio utilise-t-elle le bon provider ?**
   - [ ] Oui → Problème résolu
   - [ ] Non → Vérifier `AudioGenerationService.swift`

---

## 📝 Prochaines étapes

**AVANT de dire que tout est résolu, je dois** :

1. ✅ Corriger l'enum AudioProvider
2. ✅ Changer la valeur par défaut
3. ✅ Ajouter le scan des projets
4. ✅ Supprimer le message MLX dans VoiceStepView
5. ⏳ **TESTER RÉELLEMENT** que le provider persiste
6. ⏳ **VÉRIFIER** qu'aucun message MLX n'apparaît
7. ⏳ **CONFIRMER** que la génération utilise le bon provider

**Je ne peux pas affirmer que tout est résolu sans avoir testé ces 3 points.**

---

## 🔧 Actions immédiates

**Vous devez maintenant** :

1. **Tester l'application** avec les correctifs appliqués
2. **Me dire** si :
   - Le provider persiste après fermeture/réouverture
   - Des messages MLX apparaissent encore
   - La génération utilise le bon provider

**Ensuite, je pourrai** :
- Corriger les problèmes restants
- Nettoyer le code
- Confirmer que tout fonctionne

---

**Je m'excuse d'avoir annoncé trop tôt que tout était résolu. Je vais maintenant attendre vos retours de test avant de conclure.**
