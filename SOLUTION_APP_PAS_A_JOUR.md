# 🔧 Solution : Application pas à jour après modifications

**Problème** : Les modifications du code ne sont pas visibles dans l'application lancée.

**Cause** : L'application `AudiobookForge.app` utilise un binaire obsolète qui n'est pas mis à jour automatiquement après `swift build`.

---

## ✅ Solution immédiate

### Méthode 1 : Utiliser le script `run.sh` (RECOMMANDÉ)

```bash
cd /Volumes/J3THext/Audiobookforge
./run.sh
```

Ce script :
1. Compile le projet (`swift build`)
2. Met à jour le bundle `.app` automatiquement
3. Lance l'application avec le nouveau binaire

### Méthode 2 : Copier manuellement le binaire

```bash
cd /Volumes/J3THext/Audiobookforge

# Compiler
swift build

# Copier le binaire dans l'app bundle
cp .build/arm64-apple-macosx/debug/AudiobookForge AudiobookForge.app/Contents/MacOS/AudiobookForge

# Lancer l'app
open AudiobookForge.app
```

### Méthode 3 : Lancer directement le binaire

```bash
cd /Volumes/J3THext/Audiobookforge
swift build
.build/arm64-apple-macosx/debug/AudiobookForge
```

---

## 🎯 Pour voir les nouveaux réglages TTS Audiobook Tool

1. **Fermer l'application** si elle est ouverte :
   ```bash
   pkill AudiobookForge
   ```

2. **Recompiler et lancer** :
   ```bash
   cd /Volumes/J3THext/Audiobookforge
   ./run.sh
   ```

3. **Dans l'application** :
   - Ouvrir ou créer un projet
   - Aller dans l'étape "Voix"
   - Cliquer sur l'icône **⚙️** (Audio Settings) en haut à droite
   - Vous devriez maintenant voir **3 providers** :
     - Local (MLX - Gratuit)
     - Fish.Audio API
     - **TTS Audiobook Tool (Local)** ⭐ NOUVEAU

4. **Sélectionner TTS Audiobook Tool** :
   - Cliquer sur "TTS Audiobook Tool (Local)"
   - Une section apparaît avec :
     - Sélecteur de modèle (Fish S2-Pro, Chatterbox, Qwen3)
     - Options avancées (STT validation, tentatives max)
     - Normalisation et upsampling
     - Paramètres de génération (temperature, top-p, top-k, seed)

---

## 📝 Pourquoi ce problème ?

Quand vous double-cliquez sur `AudiobookForge.app`, macOS lance le binaire situé dans :
```
AudiobookForge.app/Contents/MacOS/AudiobookForge
```

Mais `swift build` compile le binaire dans :
```
.build/arm64-apple-macosx/debug/AudiobookForge
```

Ces deux fichiers sont **différents** et ne sont pas synchronisés automatiquement.

---

## 🔄 Workflow recommandé

### Pour le développement

Utilisez **toujours** `./run.sh` qui gère tout automatiquement :
```bash
./run.sh
```

### Pour tester rapidement

Lancez directement le binaire compilé :
```bash
swift build && .build/arm64-apple-macosx/debug/AudiobookForge
```

### Pour distribuer

Créez un bundle propre :
```bash
./create_app_bundle.sh
```

---

## ✅ Vérification

Pour vérifier que vous utilisez la bonne version :

1. **Lancer l'app**
2. **Ouvrir un projet**
3. **Aller dans "Voix"**
4. **Cliquer sur ⚙️**
5. **Vérifier** que vous voyez 3 providers dont "TTS Audiobook Tool (Local)"

Si vous ne voyez que 2 providers (Local MLX et Fish.Audio API), c'est que vous utilisez encore l'ancien binaire.

---

## 🎉 Résultat attendu

Après avoir suivi ces étapes, vous devriez voir dans Audio Settings :

```
Provider préféré
┌─────────────────────────────────────────┐
│ ○ Local (MLX - Gratuit)                 │
│   Génération locale via MLX             │
├─────────────────────────────────────────┤
│ ○ Fish.Audio API                        │
│   API Fish.Audio ($15/1M bytes)         │
├─────────────────────────────────────────┤
│ ● TTS Audiobook Tool (Local)            │ ⭐ NOUVEAU
│   TTS Audiobook Tool (gratuit, local,   │
│   3 modèles disponibles)                │
└─────────────────────────────────────────┘

Modèle TTS
○ Fish S2-Pro (Haute qualité)
  Qualité maximale, 24GB VRAM requis
○ Chatterbox (Multilingue)
  Multilingue, rapide, 8GB VRAM
○ Qwen3-TTS (Rapide)
  Batch processing, efficace, 12GB VRAM

Options avancées
☑ Validation STT (Whisper)
Tentatives max: 3
☑ Normalisation loudness (EBU R128)
☐ Upsampling 48kHz (Sidon)

Paramètres de génération
Temperature: 0.8
☐ Top-P
☐ Top-K
☐ Seed fixe
```

---

**Date** : 18/05/2026 17:47
