# AudiobookForge 🎧

Application Mac native pour générer des audiobooks localement avec **Fish Audio S2 Pro** (MLX) et **Qwen3** (Ollama).

## Architecture

```
AudiobookForge/
├── AudiobookForge/          ← App SwiftUI native macOS
│   ├── Models/              ← Modèles de données (Project, Chapter, etc.)
│   ├── Services/            ← Services backend (extraction, LLM, audio, export)
│   ├── ViewModels/          ← ViewModels SwiftUI
│   ├── Views/               ← Vues SwiftUI (NavigationSplitView)
│   └── Resources/           ← Ressources de l'app
├── backend/
│   ├── scripts/
│   │   ├── extract_epub.py  ← Extraction EPUB
│   │   ├── extract_pdf.py   ← Extraction PDF
│   │   ├── extract_docx.py  ← Extraction DOCX
│   │   └── generate/
│   │       └── fish_s2_pro.py ← Génération audio MLX
│   └── requirements.txt     ← Dépendances Python
└── Package.swift            ← Package Swift
```

## Prérequis

### macOS
- **macOS 14+** (Sonoma)
- **Xcode 15+**
- **Apple Silicon** (M1/M2/M3/M4 recommandé)

### Dépendances système
```bash
# Audio
brew install ffmpeg

# LLM local
brew install ollama
ollama pull qwen3:30b

# Python
pip install -r backend/requirements.txt

# MLX Speech (Apple Silicon)
pip install mlx-speech
```

### Modèle TTS
Téléchargez le modèle **Fish Audio S2 Pro** (8bit MLX) depuis Hugging Face :
```bash
# À placer dans backend/models/fishaudio-s2-pro-8bit-mlx/
```

## Installation

1. Ouvrir le projet dans Xcode :
```bash
open AudiobookForge/Package.swift
```

2. Build et Run (⌘R)

## Utilisation

1. **Import** : Glissez-déposez un fichier EPUB/PDF/DOCX
2. **Extraction** : Le texte est extrait et nettoyé automatiquement
3. **Balises** : Qwen3 injecte des balises émotionnelles ([whisper], [sad], etc.)
4. **Voix** : Importez un sample vocal (10-30s) avec sa transcription
5. **Génération** : L'audio est généré chunk par chunk via MLX
6. **Export** : WAV / AAC / MP3 / M4B avec métadonnées

## Fonctionnalités

- ✅ 100% local — pas de cloud
- ✅ SwiftUI native — pas d'Electron
- ✅ Voice cloning via Fish S2 Pro
- ✅ Balises émotionnelles via LLM
- ✅ Éditeur de balises intégré
- ✅ Génération chunk par chunk
- ✅ Progression persistante et reprise
- ✅ Export multi-format avec métadonnées
- ✅ Vérification des dépendances au démarrage

## Stack technique

| Composant | Technologie |
|-----------|------------|
| UI | SwiftUI (NavigationSplitView) |
| LLM | Qwen3 30B via Ollama |
| TTS | Fish Audio S2 Pro via MLX |
| Extraction | ebooklib / PyMuPDF / python-docx |
| Audio | ffmpeg / pydub |
| Persistance | JSON (projets) |

## Licence

Projet personnel — usage libre
