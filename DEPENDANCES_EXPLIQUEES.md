# 📋 Dépendances AudiobookForge - Explications

## ❓ Pourquoi Qwen et Fish ne sont pas dans requirements.txt ?

### C'est NORMAL et VOULU ! Voici pourquoi:

---

## 1. 🤖 Qwen (LLM pour les balises émotionnelles)

### Installation
```bash
# Qwen est installé via Ollama (pas pip)
brew install ollama
ollama pull qwen2.5:7b
```

### Vérification
```bash
$ ollama list
NAME          ID              SIZE      MODIFIED
qwen2.5:7b    845dbda0ea48    4.7 GB    About an hour ago
```

### Pourquoi pas dans requirements.txt ?
- ✅ **Ollama** est un **service système** séparé (comme un serveur)
- ✅ Il gère les LLM de manière optimisée (quantization, cache, etc.)
- ✅ L'application Swift communique avec Ollama via **HTTP API** (localhost:11434)
- ✅ Ollama peut servir plusieurs applications en même temps
- ✅ Plus efficace que d'embarquer le modèle dans Python

### Comment ça marche ?
```
AudiobookForge (Swift)
    ↓ HTTP Request
Ollama Service (localhost:11434)
    ↓ Load Model
Qwen2.5:7b (4.7 GB)
    ↓ Generate
Texte avec balises émotionnelles
```

---

## 2. 🎤 Fish S2 Pro (TTS pour la génération audio)

### Installation
```bash
# Fish S2 Pro est installé via mlx-speech
pip install mlx-speech
```

### Vérification
```bash
$ backend/venv/bin/python3 -c "import mlx_speech; print('OK')"
✅ mlx-speech OK
```

### Pourquoi "Fish" n'apparaît pas directement ?
- ✅ **mlx-speech** est la bibliothèque qui **contient** Fish S2 Pro
- ✅ Le modèle Fish S2 Pro est téléchargé **automatiquement** depuis HuggingFace
- ✅ Pas besoin de l'installer séparément
- ✅ mlx-speech gère tout (téléchargement, cache, inférence)

### Comment ça marche ?
```
AudiobookForge (Swift)
    ↓ Execute Python script
backend/scripts/generate/fish_s2_pro.py
    ↓ Import mlx_speech
mlx_speech.tts.load("appautomaton/fishaudio-s2-pro-8bit-mlx")
    ↓ Download from HuggingFace (première fois seulement)
~/.cache/huggingface/hub/models--appautomaton--fishaudio-s2-pro-8bit-mlx/
    ↓ Generate audio
Fichier WAV
```

---

## 3. 📦 Ce qui EST dans requirements.txt

```txt
# Extraction de texte
ebooklib>=0.18          # EPUB
beautifulsoup4>=4.12    # HTML parsing
pymupdf>=1.23           # PDF
python-docx>=1.1        # DOCX

# Génération audio (contient Fish S2 Pro)
mlx-speech>=0.4         # ← Fish S2 Pro est ICI !
numpy>=2.0              # Calculs numériques
soundfile>=0.13         # Lecture/écriture WAV

# Communication
httpx>=0.27             # HTTP client (pour Ollama)
```

---

## 4. ✅ Vérification complète

### Commande unique pour tout vérifier
```bash
cd /Volumes/J3THext/Audiobookforge

echo "1. FFmpeg:"
which ffmpeg

echo "2. Ollama:"
which ollama
pgrep -f "ollama serve"

echo "3. Qwen:"
ollama list | grep qwen

echo "4. Python + venv:"
python3 --version
ls backend/venv/bin/python3

echo "5. mlx-speech (Fish S2 Pro):"
backend/venv/bin/python3 -c "import mlx_speech; print('✅ OK')"

echo "6. Toutes les dépendances Python:"
backend/venv/bin/pip list | grep -E "(mlx|ebooklib|pymupdf|docx|soundfile)"
```

---

## 5. 🎯 Résumé

| Dépendance | Où ? | Pourquoi ? |
|------------|------|------------|
| **Qwen** | Ollama (service système) | LLM optimisé, API HTTP, multi-apps |
| **Fish S2 Pro** | mlx-speech (pip) | Inclus dans mlx-speech, auto-download |
| **FFmpeg** | Homebrew | Conversion audio |
| **Python libs** | requirements.txt | Extraction texte, audio, etc. |

---

## 6. 🔍 Où sont les modèles ?

### Qwen (via Ollama)
```bash
~/.ollama/models/manifests/registry.ollama.ai/library/qwen2.5/7b
```

### Fish S2 Pro (via mlx-speech)
```bash
~/.cache/huggingface/hub/models--appautomaton--fishaudio-s2-pro-8bit-mlx/
```

**Taille totale:** ~12-15 GB (Qwen 4.7 GB + Fish 8 GB)

---

## 7. 💡 Pourquoi cette architecture ?

### Avantages
- ✅ **Séparation des responsabilités** (LLM vs TTS)
- ✅ **Ollama optimisé** pour les LLM (quantization, cache)
- ✅ **mlx-speech optimisé** pour Apple Silicon (Neural Engine)
- ✅ **Pas de duplication** (un seul Ollama pour toutes les apps)
- ✅ **Mises à jour faciles** (ollama pull, pip install -U)

### Inconvénients
- ⚠️ Deux systèmes à gérer (Ollama + Python)
- ⚠️ Peut sembler "manquant" dans requirements.txt

---

## 8. 🚀 Pour vérifier que tout fonctionne

### Test Qwen
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:7b",
  "prompt": "Hello",
  "stream": false
}'
```

### Test Fish S2 Pro
```bash
backend/venv/bin/python3 backend/scripts/generate/fish_s2_pro.py \
  --text "Hello world" \
  --reference-audio test.wav \
  --reference-text "Test" \
  --output output.wav
```

---

**Conclusion:** Qwen et Fish S2 Pro sont bien installés, juste pas au même endroit ! 🎉
