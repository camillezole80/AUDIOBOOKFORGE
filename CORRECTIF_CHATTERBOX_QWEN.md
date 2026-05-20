# Correctif Chatterbox et Qwen3 - Résumé

## Problème identifié

Les modèles Chatterbox et Qwen3 ne fonctionnaient pas correctement car le wrapper Python `audiobook_tool_wrapper.py` utilisait des noms de champs génériques (`voice_reference_path`, `temperature`, etc.) au lieu des noms de champs spécifiques à chaque modèle dans la classe `Project` de tts-audiobook-tool.

## Solution appliquée

### 1. Identification des bons noms de champs

Commande utilisée pour lister tous les champs disponibles :
```bash
cd /Volumes/J3THext/Audiobookforge/external/tts-audiobook-tool
./venv-chatterbox/bin/python -c "from tts_audiobook_tool.project import Project; print(list(Project.model_fields.keys()))"
```

**Champs identifiés pour Chatterbox :**
- `chatterbox_voice_file_name` (au lieu de voice_reference_path)
- `chatterbox_temperature`
- `chatterbox_top_p`
- `chatterbox_seed`

**Champs identifiés pour Fish-S2 :**
- `fish_s2_voice_file_name`
- `fish_s2_voice_transcript`
- `fish_s2_temperature`
- `fish_s2_top_p`
- `fish_s2_top_k`
- `fish_s2_seed`

**Champs identifiés pour Qwen3 :**
- `qwen3_voice_file_name`
- `qwen3_voice_transcript`
- `qwen3_temperature`
- `qwen3_top_p`
- `qwen3_top_k`
- `qwen3_seed`

### 2. Correction de la méthode `_create_project()`

Fichier modifié : `external/tts-audiobook-tool/audiobook_tool_wrapper.py`

**Avant :**
```python
def _create_project(...) -> Project:
    project = Project()
    project.voice_reference_path = reference_audio
    project.voice_reference_text = reference_text
    project.temperature = temperature
    # ...
```

**Après :**
```python
def _create_project(...) -> Project:
    project = Project()
    
    # Set model-specific fields based on the model name
    if self.model_name == "chatterbox":
        project.chatterbox_voice_file_name = reference_audio
        project.chatterbox_temperature = temperature
        if top_p is not None:
            project.chatterbox_top_p = top_p
        if seed is not None:
            project.chatterbox_seed = seed
    elif self.model_name == "fish-s2":
        project.fish_s2_voice_file_name = reference_audio
        project.fish_s2_voice_transcript = reference_text
        project.fish_s2_temperature = temperature
        if top_p is not None:
            project.fish_s2_top_p = top_p
        if top_k is not None:
            project.fish_s2_top_k = top_k
        if seed is not None:
            project.fish_s2_seed = seed
    elif self.model_name == "qwen3":
        project.qwen3_voice_file_name = reference_audio
        project.qwen3_voice_transcript = reference_text
        project.qwen3_temperature = temperature
        if top_p is not None:
            project.qwen3_top_p = top_p
        if top_k is not None:
            project.qwen3_top_k = top_k
        if seed is not None:
            project.qwen3_seed = seed
    
    return project
```

## État actuel

✅ **Correctifs appliqués :**
- Méthode `_create_project()` corrigée avec les bons noms de champs
- Support pour Chatterbox, Fish-S2 et Qwen3
- Gestion conditionnelle des paramètres optionnels (top_p, top_k, seed)

⚠️ **Test en attente :**
Le test nécessite un fichier audio de référence valide. L'erreur actuelle est normale :
```
FileNotFoundError: [Errno 2] No such file or directory: '/tmp/test_ref.wav'
```

## Prochaines étapes

Pour tester complètement :
1. Créer un projet dans AudiobookForge
2. Ajouter un fichier audio de référence
3. Lancer la génération avec Chatterbox ou Qwen3
4. Vérifier que les chunks audio sont générés correctement

## Notes importantes

- **Chatterbox** : Ne nécessite PAS de transcription (pas de champ `chatterbox_voice_transcript`)
- **Fish-S2 et Qwen3** : Nécessitent une transcription via les champs `*_voice_transcript`
- **SoX** : Déjà installé pour Qwen3 (requis pour le resampling audio)

## Date

19 mai 2026, 10:47
