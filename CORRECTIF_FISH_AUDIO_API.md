# Correctif Fish.Audio API - Erreur 400 "Reference Audio is not valid"

## ⚠️ PROBLÈME IDENTIFIÉ - SOLUTION TROUVÉE

L'utilisateur obtient une erreur 400 lors de l'utilisation de Fish.Audio API :
```
{"message":"Reference Audio is not valid, please check your reference audio","status":400}
```

Fichier audio testé : WAV 16-bit 44kHz, 18 secondes, avec transcription exacte.

## 🔍 Analyse de la documentation officielle

D'après l'OpenAPI spec de Fish.Audio (https://api.fish.audio/openapi.json) :

### Le problème : JSON vs MessagePack

**DÉCOUVERTE CRITIQUE** : La documentation indique clairement :

> **"references"**: "Inline voice references for zero-shot cloning. **Requires MessagePack (not JSON)**."

Notre code actuel utilise JSON (`Content-Type: application/json`), mais Fish.Audio **EXIGE MessagePack** pour envoyer des références audio inline !

### Structure correcte selon la doc

```json
{
  "text": "Hello! Welcome to Fish Audio.",
  "reference_id": "model-id",  // ← Utiliser ceci avec JSON
  "temperature": 0.7,
  "format": "wav",
  "sample_rate": 44100
}
```

Pour le zero-shot cloning avec `references`, il faut :
1. Utiliser `Content-Type: application/msgpack`
2. Encoder le body en MessagePack au lieu de JSON
3. L'audio doit être en format binaire brut (pas base64)

## ✅ SOLUTION RECOMMANDÉE

**Option A : Utiliser reference_id (PLUS SIMPLE)**

Au lieu d'envoyer l'audio à chaque fois, créer d'abord une référence sauvegardée :

1. Appeler `/v1/references/add` pour créer une voix
2. Récupérer le `reference_id`
3. Utiliser ce `reference_id` dans les requêtes TTS (avec JSON)

**Option B : Implémenter MessagePack (COMPLEXE)**

Nécessite :
- Ajouter une bibliothèque MessagePack pour Swift
- Changer le Content-Type
- Encoder les données en MessagePack
- Envoyer l'audio en binaire brut

## 🎯 Action immédiate

**Je recommande l'Option A** : Modifier le workflow pour :
1. Créer une référence sauvegardée lors de l'upload du sample
2. Stocker le `reference_id` dans le projet
3. Utiliser ce `reference_id` pour toutes les générations

Cela évite d'implémenter MessagePack et réduit la taille des requêtes.

## Date

20 mai 2026, 10:19
