# Solution Fish.Audio - Création automatique de référence

## 🎯 Problème résolu

**Erreur initiale** : "Reference Audio is not valid" (erreur 400)

**Cause racine** : Fish.Audio API exige MessagePack (pas JSON) pour envoyer des références audio inline.

## ✅ Solution implémentée

### Approche : Création automatique de référence sauvegardée

Au lieu d'envoyer l'audio à chaque requête, le système crée maintenant automatiquement une **référence sauvegardée** sur Fish.Audio lors de la première génération.

### Workflow automatique

1. **Lors de l'upload du sample** (optionnel) :
   - Si Fish.Audio est sélectionné, `PipelineViewModel.setVoiceReference()` tente de créer une référence
   - Le `reference_id` est sauvegardé dans `project.voiceConfig.fishAudioReferenceId`

2. **Lors de la génération audio** (garantie) :
   - `AudioGenerationService.generateChunkViaFishAudio()` vérifie si `fishAudioReferenceId` existe
   - **Si absent** : Crée automatiquement une référence avec un ID unique
   - **Si présent** : Utilise le `reference_id` existant
   - Logs clairs pour indiquer ce qui se passe

### Avantages

✅ **Pas d'ordre imposé** : L'utilisateur peut uploader l'audio avant ou après avoir sélectionné Fish.Audio
✅ **Création automatique** : Si pas de `reference_id`, il est créé lors de la première génération
✅ **Réutilisation** : Le même `reference_id` est utilisé pour tous les chunks
✅ **Performance** : Pas besoin d'envoyer l'audio à chaque requête
✅ **Transparence** : Logs clairs indiquant ce qui se passe

## 📝 Modifications apportées

### 1. RemoteAudioService.swift

**Avant** :
```swift
// Tentait d'envoyer l'audio en base64 dans JSON (ne fonctionne pas)
body["references"] = [[
    "audio": base64Audio,
    "text": refText
]]
```

**Après** :
```swift
// Exige un reference_id (ou lance une erreur)
if let refId = referenceId {
    body["reference_id"] = refId
} else {
    throw RemoteAudioError.missingReference
}
```

### 2. AudioGenerationService.swift

**Ajout de la logique de création automatique** :

```swift
// Vérifier si on a déjà un reference_id
var refId = voiceConfig.fishAudioReferenceId

if refId == nil {
    // Pas de reference_id : en créer un automatiquement
    logger.info("⚠️ Aucun reference_id trouvé. Création automatique...")
    
    let referenceData = try Data(contentsOf: URL(fileURLWithPath: referenceAudio))
    let newRefId = "ref_\(UUID().uuidString)"
    
    logger.info("📤 Création de la référence Fish.Audio: \(newRefId)")
    
    try await remoteAudioService.createReference(
        id: newRefId,
        audio: referenceData,
        text: referenceText,
        apiKey: apiKey
    )
    
    refId = newRefId
    logger.info("✅ Référence Fish.Audio créée avec succès: \(newRefId)")
    logger.info("💡 Cette référence sera réutilisée pour tous les chunks suivants")
} else {
    logger.info("✅ Utilisation du reference_id existant: \(refId!)")
}
```

### 3. PipelineViewModel.swift

**Création optionnelle lors de l'upload** :

```swift
func setVoiceReference(audioPath: String, transcription: String) {
    // ... sauvegarde locale ...
    
    // Si Fish.Audio est configuré, créer automatiquement la référence
    if project.voiceConfig.preferredProvider == .fishAudio {
        Task {
            await createFishAudioReference(audioPath: audioPath, transcription: transcription)
        }
    }
}
```

## 🔍 Logs à surveiller

Lors de la génération, vous verrez :

**Si référence existante** :
```
✅ Utilisation du reference_id existant: ref_<uuid>
```

**Si création automatique** :
```
⚠️ Aucun reference_id trouvé. Création automatique d'une référence Fish.Audio...
📤 Création de la référence Fish.Audio: ref_<uuid>
✅ Référence Fish.Audio créée avec succès: ref_<uuid>
💡 Cette référence sera réutilisée pour tous les chunks suivants
```

## 🧪 Test

1. **Scénario 1 : Upload puis génération**
   - Uploader un sample audio
   - Entrer la transcription
   - Sélectionner Fish.Audio
   - Lancer la génération
   - ✅ La référence est créée lors de l'upload OU lors de la première génération

2. **Scénario 2 : Génération directe**
   - Avoir un sample audio déjà uploadé
   - Sélectionner Fish.Audio
   - Lancer la génération
   - ✅ La référence est créée automatiquement lors de la première génération

3. **Scénario 3 : Réutilisation**
   - Avoir déjà généré avec Fish.Audio
   - Relancer une génération
   - ✅ Le `reference_id` existant est réutilisé (pas de nouvelle création)

## 📊 Résultat

**Build réussi** : 3.58s ✨

L'application gère maintenant automatiquement la création de références Fish.Audio, sans imposer d'ordre spécifique à l'utilisateur.

## Date

20 mai 2026, 11:29
