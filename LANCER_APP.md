# 🚀 Comment lancer AudiobookForge

## 📍 Vous êtes ici
```
/Volumes/J3THext/Audiobookforge/
```

## 🎯 Méthodes pour lancer l'application

### Méthode 1: Double-clic (la plus simple)
```bash
# Dans le Finder, naviguez vers:
/Volumes/J3THext/Audiobookforge/.build/arm64-apple-macosx/debug/

# Double-cliquez sur:
AudiobookForge.app
```

### Méthode 2: Via le terminal (recommandé)
```bash
# Ouvrez un terminal et tapez:
cd /Volumes/J3THext/Audiobookforge
open .build/arm64-apple-macosx/debug/AudiobookForge.app
```

### Méthode 3: Via Xcode
```bash
# Ouvrez le projet dans Xcode:
open Package.swift

# Puis dans Xcode, appuyez sur ⌘R (ou Product > Run)
```

---

## 🔄 Recompiler l'application

Si vous avez modifié le code ou voulez la dernière version:

```bash
cd /Volumes/J3THext/Audiobookforge
swift build
```

Puis lancez avec la Méthode 1 ou 2 ci-dessus.

---

## 🛑 Arrêter l'application

### Via l'interface
- Cliquez sur "AudiobookForge" dans la barre de menus
- Sélectionnez "Quitter AudiobookForge" (⌘Q)

### Via le terminal (si bloquée)
```bash
pkill AudiobookForge
```

**Note:** N'utilisez `pkill -9` que si l'app est vraiment bloquée, car cela force l'arrêt sans nettoyage.

---

## ✅ Vérifier que l'app tourne

```bash
ps aux | grep AudiobookForge | grep -v grep
```

Si vous voyez une ligne avec `.build/arm64-apple-macosx/debug/AudiobookForge.app`, l'app tourne.

---

## 🔍 Vérifier la version

Une fois l'app lancée, vous devriez voir **v0.4.0** au centre de l'écran (si aucun projet n'est ouvert).

---

## 📊 Consulter les logs

### Pendant que l'app tourne
```bash
tail -f ~/Library/Logs/AudiobookForge/audiobookforge-$(date +%Y-%m-%d).log
```

### Ou via l'interface
1. Cliquez sur l'icône clé à molette (🔧) dans la barre d'outils
2. Cliquez sur "Ouvrir les logs"
3. Le Finder s'ouvre sur le fichier de log

---

## 🐛 En cas de problème

### L'app ne se lance pas
```bash
# Vérifiez qu'elle est bien compilée:
ls -lh .build/arm64-apple-macosx/debug/AudiobookForge.app/Contents/MacOS/AudiobookForge

# Si le fichier n'existe pas, recompilez:
swift build
```

### L'app crash au démarrage
```bash
# Consultez les logs système:
log show --predicate 'process == "AudiobookForge"' --last 5m
```

### Plusieurs instances tournent
```bash
# Tuez toutes les instances:
pkill AudiobookForge

# Attendez 2 secondes
sleep 2

# Relancez:
open .build/arm64-apple-macosx/debug/AudiobookForge.app
```

---

## 📝 Résumé rapide

**Pour lancer:**
```bash
cd /Volumes/J3THext/Audiobookforge
open .build/arm64-apple-macosx/debug/AudiobookForge.app
```

**Pour arrêter:**
```bash
pkill AudiobookForge
```

**Pour recompiler:**
```bash
swift build
```

**Pour voir les logs:**
```bash
tail -f ~/Library/Logs/AudiobookForge/audiobookforge-$(date +%Y-%m-%d).log
```

---

**Version actuelle:** 0.4.0  
**Date:** 10/05/2026
