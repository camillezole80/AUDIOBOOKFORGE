# tts-audiobook-tool pour AudiobookForge

Ce dossier contient **tts-audiobook-tool**, un outil Python professionnel pour la génération audio TTS de haute qualité, intégré dans AudiobookForge.

## 🎯 Modèles TTS disponibles

- **Fish S2-Pro** : Haute qualité, 24GB VRAM requis
- **Chatterbox** : Multilingue, rapide, 8GB VRAM
- **Qwen3-TTS** : Batch processing, efficace, 12GB VRAM

## 📦 Installation

### Prérequis

1. **Python 3.11 et 3.12** :
```bash
brew install python@3.11 python@3.12
```

2. **ffmpeg** (déjà installé normalement) :
```bash
brew install ffmpeg
```

3. **CUDA 12.8** (Windows) ou **MPS** (macOS Apple Silicon)

### Installation des environnements virtuels

```bash
cd external/tts-audiobook-tool

# Installer tous les modèles
./setup_venvs.sh all

# Ou installer un modèle spécifique
./setup_venvs.sh fish-s2
./setup_venvs.sh chatterbox
./setup_venvs.sh qwen3
```

### Authentification HuggingFace (Fish S2-Pro uniquement)

```bash
source venv-fish-s2/bin/activate
huggingface-cli login
# Entrez votre token HuggingFace
deactivate
```

Obtenez votre token sur : https://huggingface.co/settings/tokens

## 🚀 Utilisation du wrapper

Le wrapper `audiobook_tool_wrapper.py` fournit une interface CLI simple pour AudiobookForge.

### Générer de l'audio

```bash
# Activer l'environnement du modèle choisi
source venv-fish-s2/bin/activate

# Générer avec validation STT et retry
python audiobook_tool_wrapper.py generate \
  --model fish-s2 \
  --text "Texte à générer" \
  --reference-audio "/path/to/voice.mp3" \
  --reference-text "Transcription de la voix" \
  --output "/path/to/output.wav" \
  --temperature 0.8 \
  --max-retries 3 \
  --enable-stt-validation

# Désactiver l'environnement
deactivate
```

### Normaliser l'audio

```bash
source venv-fish-s2/bin/activate

python audiobook_tool_wrapper.py normalize \
  --input "/path/to/audio.wav" \
  --output "/path/to/normalized.wav"

deactivate
```

### Upsampler à 48kHz

```bash
source venv-fish-s2/bin/activate

python audiobook_tool_wrapper.py upsample \
  --input "/path/to/audio.wav" \
  --output "/path/to/upsampled.wav"

deactivate
```

## 📊 Fonctionnalités

### Validation STT automatique
- Utilise Whisper pour valider les générations
- Détecte les erreurs de transcription
- Retry automatique en cas d'erreur
- Garde la meilleure génération

### Retry intelligent
- Jusqu'à N tentatives (configurable)
- Utilise un seed aléatoire pour les retries
- Compare les résultats et garde le meilleur

### Post-processing
- **Normalisation loudness** : EBU R128 standard
- **Upsampling** : 48kHz avec Sidon
- **Trim automatique** : Suppression des silences
- **Détection de musique** : Rejette les hallucinations

## 🔧 Paramètres avancés

### Génération

- `--temperature` : Contrôle la créativité (0.0-1.0, défaut: 0.8)
- `--top-p` : Nucleus sampling (0.0-1.0)
- `--top-k` : Top-k sampling (entier)
- `--seed` : Seed pour la reproductibilité
- `--max-retries` : Nombre max de tentatives (défaut: 3)
- `--enable-stt-validation` : Active la validation STT

### Modèles spécifiques

**Fish S2-Pro** :
- Supporte les balises émotionnelles
- Torch compile pour accélération
- Temperature, top_p, top_k, seed

**Chatterbox** :
- Multilingue (détection automatique)
- Exaggeration parameter
- CFG, temperature, top_p, top_k, seed

**Qwen3-TTS** :
- Batch processing (jusqu'à x10 plus rapide)
- CustomVoice et VoiceDesign variants
- Temperature, seed

## 📝 Format de sortie JSON

Le wrapper communique via JSON sur stdout :

```json
{
  "type": "progress",
  "data": {
    "status": "generating",
    "attempt": 1,
    "max_attempts": 3
  }
}
```

```json
{
  "type": "error",
  "message": "Error description",
  "traceback": "..."
}
```

## 🐛 Dépannage

### CUDA non disponible

```bash
source venv-fish-s2/bin/activate
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
```

Si False, réinstallez PyTorch :
```bash
pip uninstall -y torch torchaudio
pip install torch==2.8.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128
```

### Out of Memory (OOM)

1. Réduire la taille des chunks de texte
2. Désactiver Whisper sur GPU (utiliser CPU)
3. Utiliser un modèle plus petit (Chatterbox au lieu de Fish S2-Pro)

### Erreurs d'import

Vérifiez que vous êtes dans le bon venv :
```bash
which python
# Devrait afficher: .../venv-fish-s2/bin/python
```

## 📚 Documentation complète

Pour plus d'informations sur tts-audiobook-tool :
- README principal : `README.md`
- Documentation : `docs/`
- Exemples : https://github.com/zeropointnine/tts-audiobook-tool

## 🔗 Intégration avec AudiobookForge

Le wrapper est appelé par `AudioGenerationService.swift` via `Process()`.

Les logs JSON sont parsés pour afficher la progression dans l'UI Swift.

Voir `PLAN_MIGRATION_TTS_AUDIOBOOK_TOOL.md` pour les détails d'implémentation.

## ⚙️ Configuration système recommandée

### Windows (cible principale)
- **OS** : Windows 11
- **RAM** : 64GB
- **GPU** : RTX 4090 (24GB VRAM)
- **CUDA** : 12.8
- **Python** : 3.11 + 3.12

### macOS (développement)
- **OS** : macOS 14.0+
- **RAM** : 16GB+
- **GPU** : Apple Silicon (MPS)
- **Python** : 3.11 + 3.12

## 📊 Performances attendues

| Modèle | GPU | Vitesse | VRAM |
|--------|-----|---------|------|
| Fish S2-Pro | RTX 4090 | ~150% realtime | 24GB |
| Chatterbox | RTX 4090 | ~190% realtime | 8GB |
| Qwen3 (batch) | RTX 4090 | ~300% realtime | 12GB |

## 🆘 Support

Pour les problèmes spécifiques à tts-audiobook-tool :
- Issues GitHub : https://github.com/zeropointnine/tts-audiobook-tool/issues

Pour les problèmes d'intégration AudiobookForge :
- Voir `PLAN_MIGRATION_TTS_AUDIOBOOK_TOOL.md`
- Contacter l'équipe AudiobookForge
