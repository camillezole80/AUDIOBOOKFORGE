# 🎯 Guide : Accéder aux réglages Audio Settings

**Problème** : Vous ne trouvez pas l'icône pour accéder aux réglages audio TTS Audiobook Tool.

---

## ✅ L'icône existe déjà !

L'icône **Audio Settings** est déjà présente dans l'application. Elle se trouve dans l'étape "Voix" (Voice Step).

### 📍 Où la trouver ?

1. **Ouvrir ou créer un projet** dans AudiobookForge
2. **Naviguer jusqu'à l'étape "Voix"** (3ème étape du pipeline)
3. **Regarder en haut à droite** de la fenêtre
4. **Vous verrez une icône verte** : 🔊 (speaker.wave.2.circle.fill)

```
┌─────────────────────────────────────────────────────────┐
│  🎵 Configuration de la voix              🔊 ← ICI !    │
│                                        Génération        │
│  Importez un sample vocal...           distante         │
│                                        par API           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Sample de référence                                    │
│  [Parcourir...]                                         │
│                                                          │
│  Transcription exacte du sample                         │
│  [Zone de texte]                                        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### 🖱️ Comment l'utiliser ?

1. **Cliquer sur l'icône verte 🔊** en haut à droite
2. **Une fenêtre s'ouvre** avec les réglages audio
3. **Vous verrez 3 providers** :
   - Local (MLX - Gratuit)
   - Fish.Audio API
   - **TTS Audiobook Tool (Local)** ⭐ NOUVEAU

---

## 🔍 Si vous ne voyez toujours pas l'icône

### Vérification 1 : Êtes-vous dans la bonne étape ?

L'icône n'apparaît que dans l'**étape "Voix"** (Voice Step), pas dans les autres étapes.

**Étapes du pipeline** :
1. Import (📁) - PAS d'icône audio ici
2. Balises (🏷️) - PAS d'icône audio ici
3. **Voix (🎵)** - ✅ L'icône audio est ICI
4. Génération (▶️) - PAS d'icône audio ici
5. Export (📦) - PAS d'icône audio ici

### Vérification 2 : Avez-vous un projet ouvert ?

L'icône n'apparaît que si vous avez un projet ouvert. Si vous êtes sur l'écran d'accueil (liste des projets), l'icône n'est pas visible.

**Solution** :
1. Ouvrir un projet existant OU
2. Créer un nouveau projet
3. Aller dans l'étape "Voix"

### Vérification 3 : Utilisez-vous la bonne version de l'app ?

Si vous avez lancé l'app en double-cliquant sur `AudiobookForge.app` dans le Finder, vous utilisez peut-être une ancienne version.

**Solution** :
```bash
# Fermer l'app
pkill AudiobookForge

# Lancer la version à jour
cd /Volumes/J3THext/Audiobookforge
./run.sh
```

---

## 📸 Capture d'écran de l'icône

L'icône ressemble à ceci :

```
     🔊
Génération
 distante
  par API
```

- **Couleur** : Verte
- **Taille** : Grande (40pt)
- **Position** : En haut à droite de l'étape "Voix"
- **Tooltip** : "Configurer la génération audio (Local / Fish.Audio API)"

---

## 🎉 Une fois l'icône trouvée

Cliquez dessus et vous verrez :

### Fenêtre "Configuration Audio"

```
┌─────────────────────────────────────────────────────────┐
│                  🎵 Configuration Audio                  │
│         Choisissez votre provider de génération audio   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Provider préféré                                       │
│                                                          │
│  ○ Local (MLX - Gratuit)                                │
│    Génération locale via MLX                            │
│                                                          │
│  ○ Fish.Audio API                                       │
│    API Fish.Audio ($15/1M bytes)                        │
│                                                          │
│  ● TTS Audiobook Tool (Local)  ⭐ NOUVEAU               │
│    TTS Audiobook Tool (gratuit, local, 3 modèles)      │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Modèle TTS                                      │   │
│  │ ○ Fish S2-Pro (Haute qualité)                  │   │
│  │   Qualité maximale, 24GB VRAM requis           │   │
│  │ ○ Chatterbox (Multilingue)                     │   │
│  │   Multilingue, rapide, 8GB VRAM                │   │
│  │ ○ Qwen3-TTS (Rapide)                           │   │
│  │   Batch processing, efficace, 12GB VRAM        │   │
│  │                                                 │   │
│  │ Options avancées                                │   │
│  │ ☑ Validation STT (Whisper)                     │   │
│  │ Tentatives max: 3                               │   │
│  │ ☑ Normalisation loudness (EBU R128)            │   │
│  │ ☐ Upsampling 48kHz (Sidon)                     │   │
│  │                                                 │   │
│  │ Paramètres de génération                        │   │
│  │ Temperature: 0.8                                │   │
│  │ ☐ Top-P                                         │   │
│  │ ☐ Top-K                                         │   │
│  │ ☐ Seed fixe                                     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│                    [Annuler]  [Enregistrer]             │
└─────────────────────────────────────────────────────────┘
```

---

## 🆘 Toujours pas visible ?

Si après toutes ces vérifications vous ne voyez toujours pas l'icône :

1. **Vérifiez que vous utilisez la bonne app** :
   ```bash
   # Afficher le chemin de l'app en cours d'exécution
   ps aux | grep AudiobookForge | grep -v grep
   ```

2. **Recompilez et relancez** :
   ```bash
   cd /Volumes/J3THext/Audiobookforge
   pkill AudiobookForge
   ./run.sh
   ```

3. **Vérifiez les logs** :
   ```bash
   tail -f ~/Library/Logs/AudiobookForge/audiobookforge-$(date +%Y-%m-%d).log
   ```

---

## 📝 Résumé

- **Icône** : 🔊 (verte, grande)
- **Position** : En haut à droite de l'étape "Voix"
- **Condition** : Projet ouvert + étape "Voix" active
- **Action** : Cliquer dessus pour ouvrir les réglages audio

**L'icône est déjà là, il suffit de la trouver !** 😊

---

**Date** : 18/05/2026 17:54
