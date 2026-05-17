# 🚀 Démarrage Rapide - Fish.Audio

## 📌 Résumé de la situation

Votre projet AudiobookForge est **prêt à utiliser Fish.Audio** ! Voici ce qui a été diagnostiqué :

### ✅ Ce qui fonctionne

- ✅ **Code Fish.Audio** : Service complet et fonctionnel
- ✅ **Fallback configuré** : Votre projet bascule automatiquement vers Fish.Audio
- ✅ **Audio de référence** : Configuré dans votre projet `nomduvent1`
- ✅ **Transcription** : Présente dans la configuration

### ❌ Ce qui manque

- ❌ **Modèle local MLX** : Dossier `models/` vide (normal, 30+ GB)
- ❌ **Clé API Fish.Audio** : Pas encore configurée dans le Keychain

---

## 🎯 Configuration en 3 étapes (5 minutes)

### Étape 1 : Obtenir votre clé API Fish.Audio

1. **Créer un compte** sur [https://fish.audio](https://fish.audio) (gratuit)
2. **Se connecter** et aller dans : **Settings → API Keys**
3. **Créer une nouvelle clé** et la copier (format : `fk-xxxxx...`)

### Étape 2 : Configurer la clé API

**Option A : Script automatique (RECOMMANDÉ)**

```bash
cd /Volumes/J3THext/Audiobookforge
./configure_fish_audio.sh
```

Le script va :
- ✅ Demander votre clé API
- ✅ L'ajouter dans le Keychain macOS
- ✅ Tester la connexion
- ✅ Afficher les prochaines étapes

**Option B : Configuration manuelle**

```bash
security add-generic-password \
  -a "AudiobookForge" \
  -s "fish_audio_api_key" \
  -w "VOTRE_CLE_API_ICI"
```

### Étape 3 : Tester la configuration

```bash
./test_fish_audio.sh
```

Ce script vérifie :
- ✅ Clé API dans le Keychain
- ✅ Connexion à Fish.Audio
- ✅ Configuration du projet
- ✅ Prêt pour la génération

---

## 🎬 Générer votre premier chapitre

### 1. Lancer AudiobookForge

```bash
./Lancer\ AudiobookForge.command
```

### 2. Ouvrir votre projet

- Cliquer sur **"nomduvent1"** dans la liste des projets

### 3. Aller à l'étape 4 - Génération

- Sélectionner **"Chapitre 1"** (ou un chapitre court)
- Cliquer sur **"Générer l'audio"**

### 4. Observer le processus

L'application va :
1. ✅ Détecter que le modèle local est absent
2. ✅ Basculer automatiquement vers Fish.Audio
3. ✅ Envoyer le texte + audio de référence à l'API
4. ✅ Télécharger l'audio généré
5. ✅ Sauvegarder dans `audio/Projects/nomduvent1/chunks/`

### 5. Vérifier le résultat

- Écouter l'audio généré
- Vérifier la qualité de la voix
- Ajuster les paramètres si nécessaire

---

## 💰 Coûts estimés

### Votre projet "nomduvent1"

- **Caractères** : ~1.2 million
- **Coût total** : ~18 USD
- **Par chapitre** : ~0.50 USD (moyenne)

### Tarification Fish.Audio

- **Modèle** : S2-Pro (haute qualité)
- **Prix** : 15 USD / million de caractères
- **Voice cloning** : Inclus (zero-shot)

### Conseils pour optimiser

1. **Tester d'abord** sur 1-2 chapitres courts
2. **Valider la qualité** avant de générer tout le livre
3. **Ne pas régénérer** les chapitres déjà satisfaisants

---

## 🔧 Paramètres recommandés

### Configuration par défaut (déjà optimale)

- **Temperature** : 0.8 (naturel)
- **Speed Scale** : 1.0 (vitesse normale)
- **Format** : WAV 44.1kHz
- **Sample Rate** : 44100 Hz

### Si vous voulez ajuster

**Voix plus expressive** :
- Temperature : 0.9-1.0

**Voix plus stable** :
- Temperature : 0.6-0.7

**Voix plus rapide** :
- Speed Scale : 1.1-1.2

**Voix plus lente** :
- Speed Scale : 0.8-0.9

---

## 📊 Monitoring

### Voir les logs en temps réel

**Terminal 1** : Lancer l'app
```bash
./Lancer\ AudiobookForge.command
```

**Terminal 2** : Suivre les logs Fish.Audio
```bash
tail -f ~/Library/Logs/AudiobookForge/app.log | grep -i "fish"
```

### Logs de succès

```
[INFO] Starting Fish.Audio generation...
[INFO] Using zero-shot voice cloning
[INFO] Fish.Audio generation completed successfully (XXXXX bytes)
```

### Logs d'erreur

```
[ERROR] Fish.Audio API error (401): Invalid API key
[ERROR] Fish.Audio API error (429): Rate limit exceeded
[ERROR] Missing Reference
```

---

## 🐛 Dépannage rapide

### ❌ "Missing API Key"

```bash
# Vérifier la clé
security find-generic-password -s "fish_audio_api_key" -w

# Si vide, reconfigurer
./configure_fish_audio.sh
```

### ❌ "API Error (401)"

- Clé invalide ou expirée
- Vérifier sur https://fish.audio
- Régénérer une nouvelle clé

### ❌ "API Error (429)"

- Limite de taux dépassée
- Attendre quelques minutes
- Réduire le nombre de générations simultanées

### ❌ "Missing Reference"

- Audio de référence manquant
- Aller dans **Étape 3 - Voix**
- Ajouter un audio + transcription

### ❌ Qualité audio médiocre

1. **Améliorer l'audio de référence** :
   - Audio clair, sans bruit
   - Durée : 10-30 secondes
   - Format : WAV 44.1kHz

2. **Vérifier la transcription** :
   - Doit correspondre EXACTEMENT à l'audio
   - Inclure la ponctuation

3. **Ajuster les paramètres** :
   - Temperature : 0.7-0.9
   - Speed Scale : 0.9-1.1

---

## 📚 Documentation complète

Pour plus de détails, consultez :

- **GUIDE_FISH_AUDIO.md** : Guide complet étape par étape
- **GUIDE_LANCEMENT.md** : Guide de lancement de l'application
- **WORKFLOW_FLEXIBLE.md** : Workflow complet de génération

---

## 🎯 Checklist avant de commencer

- [ ] Compte Fish.Audio créé
- [ ] Clé API obtenue
- [ ] Clé API configurée (`./configure_fish_audio.sh`)
- [ ] Test de connexion réussi (`./test_fish_audio.sh`)
- [ ] Projet `nomduvent1` ouvert dans AudiobookForge
- [ ] Audio de référence configuré
- [ ] Transcription de référence présente
- [ ] Budget confirmé (~18 USD pour le livre complet)

---

## 🚀 Commandes rapides

```bash
# Configuration initiale
./configure_fish_audio.sh

# Test de connexion
./test_fish_audio.sh

# Lancer l'application
./Lancer\ AudiobookForge.command

# Voir les logs
tail -f ~/Library/Logs/AudiobookForge/app.log | grep -i "fish"
```

---

## 💡 Pourquoi Fish.Audio ?

### Avantages

- ✅ **Rapide** : Pas de téléchargement de modèle (30+ GB)
- ✅ **Qualité** : Modèle S2-Pro professionnel
- ✅ **Voice cloning** : Clone votre voix de référence
- ✅ **Pas de GPU** : Fonctionne sur n'importe quel Mac
- ✅ **Mise à jour** : Modèle toujours à jour

### Inconvénients

- 💰 **Coût** : ~18 USD pour votre livre
- 🌐 **Internet** : Connexion requise
- ⏱️ **Limite** : Rate limiting possible

### Alternative : Modèle local MLX

Si vous générez beaucoup de contenu :
1. Télécharger le modèle (~30 GB)
2. Le placer dans `models/`
3. Désactiver le fallback
4. Utiliser le local (gratuit mais plus lent)

---

## 🎉 Vous êtes prêt !

**Temps estimé pour générer tout le livre** : 30-60 minutes

**Prochaine étape** : Lancez `./configure_fish_audio.sh` ! 🚀

---

## 📞 Support

**Problèmes avec Fish.Audio** :
- Documentation : https://fish.audio/docs
- Support : support@fish.audio

**Problèmes avec AudiobookForge** :
- Logs : `~/Library/Logs/AudiobookForge/app.log`
- Scripts de diagnostic : `./test_fish_audio.sh`

---

**Bonne génération ! 🎧**
