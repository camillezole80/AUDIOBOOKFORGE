# 🐟 Guide de Configuration Fish.Audio

## 📋 Prérequis

Avant de commencer, assurez-vous d'avoir :
- ✅ Un compte Fish.Audio (gratuit pour commencer)
- ✅ Une clé API Fish.Audio
- ✅ Une connexion internet stable

---

## 🔑 Étape 1 : Obtenir votre clé API Fish.Audio

### Si vous n'avez PAS encore de compte :

1. **Créer un compte** sur [https://fish.audio](https://fish.audio)
2. **Se connecter** à votre compte
3. **Aller dans** : Settings → API Keys
4. **Cliquer sur** "Create New API Key"
5. **Copier** la clé générée (format : `fk-xxxxx...`)

### Si vous avez DÉJÀ un compte :

1. **Se connecter** sur [https://fish.audio](https://fish.audio)
2. **Aller dans** : Settings → API Keys
3. **Copier** votre clé existante ou en créer une nouvelle

⚠️ **IMPORTANT** : Gardez cette clé secrète ! Ne la partagez jamais.

---

## 🔧 Étape 2 : Configurer la clé API dans AudiobookForge

### Option A : Via l'interface graphique (RECOMMANDÉ)

1. **Lancer AudiobookForge**
   ```bash
   cd /Volumes/J3THext/Audiobookforge
   ./Lancer\ AudiobookForge.command
   ```

2. **Aller dans** : Paramètres → Audio Settings

3. **Section "Remote Audio (Fish.Audio)"** :
   - Cocher ☑️ "Enable Remote Audio"
   - Cliquer sur "Configure API Key"
   - Coller votre clé API Fish.Audio
   - Cliquer sur "Test Connection"

4. **Vérifier** que le test affiche : ✅ "Connection successful"

### Option B : Via le terminal (AVANCÉ)

Si l'interface ne fonctionne pas, vous pouvez configurer manuellement :

```bash
# Ajouter la clé dans le Keychain macOS
security add-generic-password \
  -a "AudiobookForge" \
  -s "fish_audio_api_key" \
  -w "VOTRE_CLE_API_ICI"
```

---

## 🎯 Étape 3 : Configurer votre projet pour utiliser Fish.Audio

### Vérifier la configuration du projet

Votre projet `nomduvent1` est déjà configuré ! Vérifiez simplement :

1. **Ouvrir le projet** dans AudiobookForge
2. **Aller dans** : Étape 3 - Voix
3. **Vérifier** :
   - ☑️ "Fallback to Remote" est coché
   - ☑️ Audio de référence est configuré
   - ☑️ Transcription de référence est présente

### Configuration manuelle (si nécessaire)

Si vous créez un nouveau projet :

1. **Étape 3 - Voix** :
   - Provider : "Local (MLX)" (avec fallback activé)
   - ☑️ Cocher "Fallback to Remote if local fails"
   - Ajouter un audio de référence (MP3/WAV)
   - Ajouter la transcription de l'audio de référence

2. **Paramètres avancés** :
   - Temperature : 0.8 (par défaut)
   - Speed Scale : 1.0 (par défaut)

---

## 🚀 Étape 4 : Tester la génération audio

### Test rapide

1. **Ouvrir votre projet** `nomduvent1`
2. **Aller à** : Étape 4 - Génération
3. **Sélectionner** un chapitre court (ex: "Chapitre 1")
4. **Cliquer sur** "Générer l'audio"

### Ce qui va se passer :

```
1. AudiobookForge détecte que le modèle local est absent
2. Bascule automatiquement vers Fish.Audio
3. Envoie le texte + audio de référence à l'API
4. Télécharge l'audio généré
5. Sauvegarde dans : audio/Projects/nomduvent1/chunks/
```

### Vérifier les logs

Ouvrez la console pour voir les logs en temps réel :

```bash
# Dans un terminal séparé
tail -f ~/Library/Logs/AudiobookForge/app.log
```

Vous devriez voir :
```
[INFO] Starting Fish.Audio generation...
[INFO] Using zero-shot voice cloning
[INFO] Fish.Audio generation completed successfully (XXXXX bytes)
```

---

## 💰 Étape 5 : Comprendre les coûts

### Tarification Fish.Audio (S2-Pro)

- **Coût** : ~15 USD / million de caractères
- **Votre projet** : ~1.2 million de caractères
- **Estimation** : ~18 USD pour tout le livre

### Calculer le coût d'un chapitre

L'app affiche automatiquement l'estimation avant génération :

```
Chapitre 1 : 5,234 caractères
Coût estimé : ~0.08 USD
```

### Optimiser les coûts

1. **Tester d'abord** sur 1-2 chapitres courts
2. **Valider la qualité** avant de générer tout le livre
3. **Utiliser le cache** : ne régénérez pas les chapitres déjà OK

---

## 🔍 Étape 6 : Dépannage

### ❌ Erreur : "Missing API Key"

**Solution** :
```bash
# Vérifier que la clé est dans le Keychain
security find-generic-password -s "fish_audio_api_key" -w
```

Si vide, ajoutez-la :
```bash
security add-generic-password \
  -a "AudiobookForge" \
  -s "fish_audio_api_key" \
  -w "VOTRE_CLE_API_ICI"
```

### ❌ Erreur : "API Error (401)"

**Cause** : Clé API invalide ou expirée

**Solution** :
1. Vérifier votre clé sur fish.audio
2. Régénérer une nouvelle clé si nécessaire
3. Mettre à jour dans AudiobookForge

### ❌ Erreur : "API Error (429)"

**Cause** : Limite de taux dépassée

**Solution** :
1. Attendre quelques minutes
2. Réduire le nombre de générations simultanées
3. Vérifier votre quota sur fish.audio

### ❌ Erreur : "Missing Reference"

**Cause** : Audio de référence ou transcription manquante

**Solution** :
1. Aller dans Étape 3 - Voix
2. Ajouter un audio de référence (MP3/WAV)
3. Ajouter la transcription exacte de cet audio

### ❌ Qualité audio médiocre

**Solutions** :
1. **Améliorer l'audio de référence** :
   - Utiliser un audio clair, sans bruit de fond
   - Durée : 10-30 secondes minimum
   - Format : WAV 44.1kHz recommandé

2. **Ajuster la transcription** :
   - Doit correspondre EXACTEMENT à l'audio
   - Inclure la ponctuation
   - Respecter les pauses

3. **Ajuster les paramètres** :
   - Temperature : 0.7-0.9 (0.8 par défaut)
   - Speed Scale : 0.9-1.1 (1.0 par défaut)

---

## 📊 Étape 7 : Monitoring et logs

### Voir les logs en temps réel

```bash
# Terminal 1 : Lancer l'app
cd /Volumes/J3THext/Audiobookforge
./Lancer\ AudiobookForge.command

# Terminal 2 : Suivre les logs
tail -f ~/Library/Logs/AudiobookForge/app.log | grep -i "fish"
```

### Logs importants à surveiller

```
✅ Succès :
[INFO] Fish.Audio generation completed successfully

❌ Erreurs :
[ERROR] Fish.Audio API error (401): Invalid API key
[ERROR] Fish.Audio API error (429): Rate limit exceeded
[ERROR] Fish.Audio connection test failed
```

---

## 🎓 Étape 8 : Workflow complet

### Génération d'un livre complet

1. **Préparer le projet** :
   - ✅ Texte extrait et nettoyé
   - ✅ Balises injectées
   - ✅ Audio de référence configuré
   - ✅ Clé API Fish.Audio configurée

2. **Tester sur 1 chapitre** :
   - Générer le Chapitre 1
   - Écouter le résultat
   - Ajuster les paramètres si nécessaire

3. **Générer par lots** :
   - Sélectionner 5-10 chapitres
   - Lancer la génération
   - Surveiller les logs

4. **Vérifier la qualité** :
   - Écouter quelques chapitres aléatoires
   - Vérifier la cohérence de la voix
   - Régénérer si nécessaire

5. **Exporter** :
   - Aller à Étape 5 - Export
   - Choisir le format (M4B recommandé)
   - Exporter le livre complet

---

## 🔄 Étape 9 : Passer au modèle local plus tard

Si vous voulez installer le modèle local après :

1. **Télécharger le modèle** (~30 GB)
2. **Le placer dans** `/Volumes/J3THext/Audiobookforge/models/`
3. **Désactiver** "Fallback to Remote"
4. **Utiliser** le modèle local pour les nouveaux projets

L'avantage : vous gardez Fish.Audio comme backup !

---

## 📞 Support

### Problèmes avec Fish.Audio

- **Documentation** : https://fish.audio/docs
- **Support** : support@fish.audio
- **Status** : https://status.fish.audio

### Problèmes avec AudiobookForge

- **Logs** : `~/Library/Logs/AudiobookForge/app.log`
- **Issues** : Vérifier les fichiers `DEBUG_*.md` dans le projet

---

## ✅ Checklist finale

Avant de générer votre livre complet :

- [ ] Clé API Fish.Audio configurée et testée
- [ ] Audio de référence de bonne qualité (10-30s)
- [ ] Transcription exacte de l'audio de référence
- [ ] Test réussi sur 1 chapitre
- [ ] Qualité audio validée
- [ ] Budget confirmé (~18 USD pour votre livre)
- [ ] Connexion internet stable

**Vous êtes prêt ! 🚀**

---

## 🎯 Prochaines étapes

1. **Configurer votre clé API** (5 min)
2. **Tester sur le Chapitre 1** (2 min)
3. **Valider la qualité** (5 min)
4. **Générer tout le livre** (30-60 min)
5. **Exporter en M4B** (10 min)

**Temps total estimé : ~1h30**

Bonne génération ! 🎧
