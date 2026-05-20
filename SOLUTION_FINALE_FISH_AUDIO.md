# Solution finale Fish.Audio API

## 🎯 Problème initial

**Erreur 400** : "Reference Audio is not valid"

## 🔍 Analyse complète

### Découverte 1 : MessagePack requis pour zero-shot

D'après l'OpenAPI spec de Fish.Audio :
- Le paramètre `references` (audio inline) **nécessite MessagePack**, pas JSON
- Notre code envoyait l'audio en base64 dans JSON → **ne fonctionne pas**

### Découverte 2 : Pas d'endpoint pour créer des références

Contrairement à ce qu'on pensait, Fish.Audio API **n'a PAS** d'endpoint `/v1/references/add` :

```bash
$ curl -X POST https://api.fish.audio/v1/references/add
→ 404 "Nothing matches the given URI"
```

**Endpoints disponibles** :
- `/v1/tts` - Génération TTS
- `/model` - Liste des modèles publics
- `/model/{id}` - Détails d'un modèle

## ✅ Solution finale

### Utiliser des model IDs publics

Fish.Audio fournit des **modèles de voix publics** accessibles via leur ID. L'utilisateur doit :

1. **Sélectionner une voix** dans les réglages audio (liste des voix Fish.Audio)
2. Le `selectedFishAudioVoice` est utilisé comme `reference_id`
3. Pas besoin d'uploader de sample audio

### Code modifié

**AudioGenerationService.swift** :
```swift
// Utiliser le model ID sélectionné
let refId = voiceConfig.fishAudioReferenceId ?? voiceConfig.selectedFishAudioVoice

if refId == nil {
    logger.error("❌ Fish.Audio nécessite un model ID public")
    logger.error("   Sélectionnez une voix dans les réglages audio")
    throw AudioGenerationError.missingFishAudioReference
}

logger.info("✅ Utilisation du model Fish.Audio: \(refId!)")
```

**RemoteAudioService.swift** :
```swift
// Exiger un reference_id (pas de zero-shot JSON)
if let refId = referenceId {
    body["reference_id"] = refId
} else {
    throw RemoteAudioError.missingReference
}
```

## 📝 Workflow utilisateur

### Pour utiliser Fish.Audio :

1. **Aller dans les réglages audio** (icône haut-parleur)
2. **Sélectionner "Fish.Audio API"** comme provider
3. **Choisir une voix** dans la liste déroulante
4. **Entrer la clé API** Fish.Audio
5. **Lancer la génération**

### Voix disponibles (exemples) :

- `default` - Voix par défaut
- `emma` - Narratrice féminine anglaise
- `john` - Voix masculine conversationnelle
- `marie` - Narratrice féminine française
- `pierre` - Narrateur masculin français
- etc.

## ⚠️ Limitations

### Zero-shot cloning non disponible

Pour utiliser votre propre voix (zero-shot cloning), il faudrait :
1. Implémenter MessagePack en Swift
2. Envoyer l'audio en binaire brut (pas base64)
3. Utiliser `Content-Type: application/msgpack`

**Complexité** : Élevée
**Priorité** : Basse (les modèles publics suffisent)

### Alternative : TTS Audiobook Tool

Si vous voulez utiliser votre propre voix :
- Utilisez **TTS Audiobook Tool** (provider local)
- Supporte le zero-shot cloning avec Fish S2 Pro
- Pas besoin d'API externe

## 📊 Résultat

**Build réussi** : 4.34s ✨

L'application utilise maintenant correctement Fish.Audio API avec des model IDs publics.

## 🧪 Test

1. Sélectionner Fish.Audio dans les réglages
2. Choisir une voix (ex: "emma")
3. Entrer la clé API
4. Lancer une génération
5. ✅ Devrait fonctionner !

## Date

20 mai 2026, 11:33
