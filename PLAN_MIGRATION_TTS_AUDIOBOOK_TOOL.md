# Plan de Migration vers tts-audiobook-tool

## 📋 Décisions prises

### Modèles TTS sélectionnés
- **Fish S2-Pro** : Haute qualité, 24GB VRAM
- **Chatterbox** : Multilingue, rapide
- **Qwen3-TTS** : Batch processing, efficace

### Configuration cible
- **Plateforme principale** : Windows 11 (64GB RAM + RTX 4090)
- **Plateforme secondaire** : macOS (compatibilité maintenue)
- **Priorité** : Qualité maximale (validation STT, retry, normalisation)
- **Architecture** : Option 1 - Intégration complète

---

## 🎯 Objectifs de la migration

### Fonctionnalités à intégrer
1. ✅ **Validation STT automatique** avec Whisper
2. ✅ **Système de retry intelligent** (garde la meilleure génération)
3. ✅ **Détection de musique/hallucinations**
4. ✅ **Normalisation loudness** (EBU R128)
5. ✅ **Upsampling 48kHz** avec Sidon
6. ✅ **Trim automatique** des silences
7. ✅ **Batch processing** (Qwen3)
8. ✅ **Support multi-modèles** (Fish, Chatterbox, Qwen3)

### Complexité du projet
**Impact : MOYEN**

**Avantages** :
- Code Python déjà écrit et testé
- Architecture modulaire bien conçue
- Réduction du code custom (moins de maintenance)
- Qualité audio professionnelle

**Défis** :
- Gestion de 3 environnements virtuels Python
- Adaptation de l'interface Swift
- Mapping des configurations
- Tests multi-modèles

**Estimation** : 3-4 jours de développement + 1 jour de tests

---

## 🏗️ Architecture proposée

```
AudiobookForge (Swift/SwiftUI)
    │
    ├── AudioGenerationService.swift (interface)
    │   └── Appelle → audiobook_tool_wrapper.py
    │
    └── tts-audiobook-tool/ (submodule Git)
        ├── venv-fish-s2/
        ├── venv-chatterbox/
        ├── venv-qwen3tts/
        └── audiobook_tool_wrapper.py (nouveau)
```

---

## 📝 Plan d'implémentation détaillé

### Phase 1 : Préparation (Jour 1)

#### 1.1 Intégrer tts-audiobook-tool comme submodule
```bash
cd /Volumes/J3THext/Audiobookforge
git submodule add https://github.com/zeropointnine/tts-audiobook-tool.git external/tts-audiobook-tool
```

#### 1.2 Créer les environnements virtuels
```bash
cd external/tts-audiobook-tool

# Fish S2-Pro (Python 3.12)
python3.12 -m venv venv-fish-s2
source venv-fish-s2/bin/activate  # macOS
# venv-fish-s2\Scripts\activate.bat  # Windows
pip install -r requirements-fish-s2.txt
pip uninstall -y torch torchaudio
pip install torch==2.8.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128
hf auth login  # Authentification HuggingFace

# Chatterbox (Python 3.11)
python3.11 -m venv venv-chatterbox
source venv-chatterbox/bin/activate
pip install -r requirements-chatterbox.txt
pip uninstall -y torch torchaudio
pip install torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124

# Qwen3-TTS (Python 3.12)
python3.12 -m venv venv-qwen3tts
source venv-qwen3tts/bin/activate
pip install -r requirements-qwen3tts.txt
pip uninstall -y torch torchaudio
pip install torch==2.8.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128
pip install flash-attn==2.8.3 --no-build-isolation  # Optionnel mais recommandé
```

#### 1.3 Tester les installations
```bash
# Test Fish S2-Pro
source venv-fish-s2/bin/activate
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

# Test Chatterbox
source venv-chatterbox/bin/activate
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

# Test Qwen3
source venv-qwen3tts/bin/activate
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

---

### Phase 2 : Wrapper Python (Jour 1-2)

#### 2.1 Créer `audiobook_tool_wrapper.py`

**Fonctionnalités** :
- Interface CLI simple pour AudiobookForge
- Gestion de projet compatible
- Support des 3 modèles (Fish, Chatterbox, Qwen3)
- Callbacks de progression (JSON sur stdout)
- Validation STT avec retry
- Normalisation et post-processing

**API proposée** :
```bash
# Générer un chunk
python audiobook_tool_wrapper.py generate \
  --model fish-s2 \
  --text "Texte à générer" \
  --reference-audio "path/to/voice.mp3" \
  --reference-text "Transcription de la voix" \
  --output "path/to/output.wav" \
  --temperature 0.8 \
  --max-retries 3 \
  --enable-stt-validation

# Normaliser un fichier
python audiobook_tool_wrapper.py normalize \
  --input "path/to/audio.wav" \
  --output "path/to/normalized.wav"

# Upsampler avec Sidon
python audiobook_tool_wrapper.py upsample \
  --input "path/to/audio.wav" \
  --output "path/to/upsampled.wav"
```

#### 2.2 Structure du wrapper

```python
# audiobook_tool_wrapper.py
import sys
import json
import argparse
from pathlib import Path

# Import des modules tts-audiobook-tool
from tts_audiobook_tool.tts_model.fish_s2_model import FishS2Model
from tts_audiobook_tool.tts_model.chatterbox_model import ChatterboxModel
from tts_audiobook_tool.tts_model.qwen3_model import Qwen3Model
from tts_audiobook_tool.stt import Stt
from tts_audiobook_tool.validate_util import ValidateUtil
from tts_audiobook_tool.loudness_normalization_util import LoudnessNormalizationUtil
from tts_audiobook_tool.sidon_util import SidonUtil

class AudiobookToolWrapper:
    def __init__(self, model_name: str):
        self.model_name = model_name
        self.model = self._load_model()
        
    def _load_model(self):
        if self.model_name == "fish-s2":
            return FishS2Model()
        elif self.model_name == "chatterbox":
            return ChatterboxModel()
        elif self.model_name == "qwen3":
            return Qwen3Model()
        else:
            raise ValueError(f"Unknown model: {self.model_name}")
    
    def generate(self, text, reference_audio, reference_text, output, **kwargs):
        # Génération avec validation STT et retry
        pass
    
    def normalize(self, input_path, output_path):
        # Normalisation loudness
        pass
    
    def upsample(self, input_path, output_path):
        # Upsampling Sidon
        pass

def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest='command')
    
    # Commande generate
    gen_parser = subparsers.add_parser('generate')
    gen_parser.add_argument('--model', required=True)
    gen_parser.add_argument('--text', required=True)
    gen_parser.add_argument('--reference-audio', required=True)
    gen_parser.add_argument('--reference-text', required=True)
    gen_parser.add_argument('--output', required=True)
    gen_parser.add_argument('--temperature', type=float, default=0.8)
    gen_parser.add_argument('--max-retries', type=int, default=3)
    gen_parser.add_argument('--enable-stt-validation', action='store_true')
    
    # Commande normalize
    norm_parser = subparsers.add_parser('normalize')
    norm_parser.add_argument('--input', required=True)
    norm_parser.add_argument('--output', required=True)
    
    # Commande upsample
    up_parser = subparsers.add_parser('upsample')
    up_parser.add_argument('--input', required=True)
    up_parser.add_argument('--output', required=True)
    
    args = parser.parse_args()
    
    if args.command == 'generate':
        wrapper = AudiobookToolWrapper(args.model)
        wrapper.generate(
            text=args.text,
            reference_audio=args.reference_audio,
            reference_text=args.reference_text,
            output=args.output,
            temperature=args.temperature,
            max_retries=args.max_retries,
            enable_stt_validation=args.enable_stt_validation
        )
    elif args.command == 'normalize':
        wrapper = AudiobookToolWrapper('fish-s2')  # Model doesn't matter
        wrapper.normalize(args.input, args.output)
    elif args.command == 'upsample':
        wrapper = AudiobookToolWrapper('fish-s2')
        wrapper.upsample(args.input, args.output)

if __name__ == '__main__':
    main()
```

---

### Phase 3 : Adaptation Swift (Jour 2-3)

#### 3.1 Modifier `AudioGenerationService.swift`

**Changements principaux** :
- Remplacer les appels directs par des appels au wrapper
- Ajouter support multi-modèles
- Gérer les callbacks de progression
- Parser les résultats JSON

#### 3.2 Créer `TtsModelType` enum

```swift
enum TtsModelType: String, Codable, CaseIterable {
    case fishS2Pro = "fish-s2"
    case chatterbox = "chatterbox"
    case qwen3 = "qwen3"
    
    var displayName: String {
        switch self {
        case .fishS2Pro: return "Fish S2-Pro (Haute qualité)"
        case .chatterbox: return "Chatterbox (Multilingue)"
        case .qwen3: return "Qwen3-TTS (Rapide)"
        }
    }
    
    var requiresVRAM: Int {
        switch self {
        case .fishS2Pro: return 24
        case .chatterbox: return 8
        case .qwen3: return 12
        }
    }
}
```

#### 3.3 Mettre à jour `VoiceConfig`

```swift
struct VoiceConfig: Codable {
    // Existant
    var referenceAudioPath: String = ""
    var referenceTranscription: String = ""
    var speedScale: Double = 1.0
    var temperature: Double = 0.8
    
    // Nouveau
    var ttsModel: TtsModelType = .fishS2Pro
    var enableSttValidation: Bool = true
    var maxRetries: Int = 3
    var enableUpsampling: Bool = false
    var enableNormalization: Bool = true
}
```

---

### Phase 4 : Interface utilisateur (Jour 3)

#### 4.1 Ajouter sélecteur de modèle dans `AudioSettingsView`

```swift
Picker("Modèle TTS", selection: $voiceConfig.ttsModel) {
    ForEach(TtsModelType.allCases, id: \.self) { model in
        VStack(alignment: .leading) {
            Text(model.displayName)
            Text("VRAM requis: \(model.requiresVRAM)GB")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .tag(model)
    }
}

Toggle("Validation STT (Whisper)", isOn: $voiceConfig.enableSttValidation)
    .help("Valide automatiquement les générations et réessaie en cas d'erreur")

Stepper("Tentatives max: \(voiceConfig.maxRetries)", 
        value: $voiceConfig.maxRetries, in: 1...10)

Toggle("Upsampling 48kHz (Sidon)", isOn: $voiceConfig.enableUpsampling)
    .help("Améliore la qualité audio")

Toggle("Normalisation loudness", isOn: $voiceConfig.enableNormalization)
    .help("Normalise le volume selon EBU R128")
```

---

### Phase 5 : Tests et validation (Jour 4)

#### 5.1 Tests unitaires
- Test de chaque modèle individuellement
- Test de la validation STT
- Test du retry
- Test de la normalisation
- Test de l'upsampling

#### 5.2 Tests d'intégration
- Génération d'un chapitre complet
- Génération avec différents modèles
- Test de la persistance des configurations
- Test de la reprise après interruption

#### 5.3 Tests de performance
- Mesurer la vitesse de génération
- Mesurer l'utilisation VRAM
- Comparer avec l'ancien système

---

## 📊 Comparaison Avant/Après

### Avant (système actuel)
- ❌ 1 seul modèle (Fish S2-Pro)
- ❌ Pas de validation automatique
- ❌ Pas de retry
- ❌ Normalisation basique
- ❌ Pas d'upsampling
- ✅ Simple à maintenir

### Après (avec tts-audiobook-tool)
- ✅ 3 modèles (Fish, Chatterbox, Qwen3)
- ✅ Validation STT automatique
- ✅ Retry intelligent (garde la meilleure)
- ✅ Normalisation professionnelle (EBU R128)
- ✅ Upsampling 48kHz (Sidon)
- ✅ Détection de musique/hallucinations
- ✅ Batch processing (Qwen3)
- ⚠️ Plus complexe (3 venvs)

---

## 🚀 Prochaines étapes

1. **Valider ce plan** avec vous
2. **Créer une branche Git** : `feature/tts-audiobook-tool-integration`
3. **Commencer Phase 1** : Préparation des environnements
4. **Développer Phase 2** : Wrapper Python
5. **Adapter Phase 3** : Code Swift
6. **Tester Phase 5** : Validation complète
7. **Merger** et déployer

---

## ⚠️ Points d'attention

### VRAM
- Fish S2-Pro : 24GB (OK avec RTX 4090)
- Chatterbox : 8GB (OK)
- Qwen3 : 12GB (OK)
- Whisper : 2-4GB (concurrent)

**Total max** : ~28GB → OK avec 4090 (24GB) si on désactive Whisper sur GPU

### Dépendances
- ffmpeg (déjà installé)
- Python 3.11 et 3.12
- CUDA 12.8 (pour torch 2.8)
- HuggingFace CLI (pour authentification)

### Compatibilité macOS
- Tous les modèles fonctionnent sur MPS (Apple Silicon)
- Performances réduites (~10-20% realtime)
- Pas de CUDA évidemment

---

Êtes-vous d'accord avec ce plan ? Voulez-vous que je commence l'implémentation ?
