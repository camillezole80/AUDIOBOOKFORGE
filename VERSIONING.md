# Système de versioning AudiobookForge

## Version actuelle : 1.0.0

## Structure de version

AudiobookForge utilise le **Semantic Versioning** (SemVer) : `MAJOR.MINOR.PATCH`

- **MAJOR** : Changements incompatibles avec les versions précédentes
- **MINOR** : Nouvelles fonctionnalités rétrocompatibles
- **PATCH** : Corrections de bugs rétrocompatibles

## Fichiers à mettre à jour

Lors d'une nouvelle version, mettre à jour ces fichiers :

### 1. Info.plist
```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

### 2. AudiobookForge/Utilities/AppVersion.swift
```swift
struct AppVersion {
    static let current = "1.0.0"
    static let buildNumber = "1"
    
    static let changelog = """
    Version 1.0.0 - Description
    
    ✨ Nouvelles fonctionnalités :
    • Feature 1
    • Feature 2
    
    🔧 Améliorations :
    • Amélioration 1
    
    🐛 Corrections :
    • Bug fix 1
    """
}
```

## Affichage de la version

### Dans les logs (au démarrage)
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 AudiobookForge v1.0.0 (build 1)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Démarrage : 2026-05-16 07:36:00
💻 Système : macOS 14.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Dans l'interface (sidebar)
En bas de la liste des projets : `ℹ️ v1.0.0 (build 1)`

## Processus de release

### 1. Mettre à jour la version
```bash
# Éditer Info.plist
# Éditer AudiobookForge/Utilities/AppVersion.swift
```

### 2. Mettre à jour le changelog
Documenter les changements dans `AppVersion.changelog`

### 3. Compiler une nouvelle version
```bash
cd /Volumes/J3THext/Audiobookforge
./run.sh
```

### 4. Vérifier la version
- Vérifier les logs au démarrage
- Vérifier l'affichage dans la sidebar
- Vérifier que le trousseau de clés demande une nouvelle autorisation (signature changée)

### 5. Tester la nouvelle version
- Tester les nouvelles fonctionnalités
- Vérifier les corrections de bugs
- Tester la persistance des données

## Historique des versions

### v1.0.0 (2026-05-16) - Première version stable
✨ **Nouvelles fonctionnalités :**
- Support complet de Fish.Audio API pour la génération audio
- Sélection de voix prédéfinies Fish.Audio
- Configuration flexible AI (Ollama, OpenAI, Anthropic, DeepSeek)
- Workflow flexible : génération par chapitre ou complète
- Gestion intelligente de l'espace disque
- Nettoyage automatique des chunks temporaires
- Système de versioning visible

🔧 **Améliorations :**
- Logs détaillés pour le debugging
- Persistance améliorée des configurations
- Gestion d'erreurs robuste avec reprise
- Interface utilisateur optimisée

🐛 **Corrections :**
- Correction du crash Python lors de la génération audio
- Correction de la persistance des paramètres audio
- Correction du balisage avec les APIs distantes
- Amélioration de la stabilité générale

### v0.6.0 (versions précédentes)
Versions de développement non documentées

## Notes importantes

### Signature de l'application
Chaque compilation génère une **nouvelle signature** de l'application. Cela signifie que :
- Le trousseau de clés demandera une nouvelle autorisation
- C'est **normal** et attendu lors d'une mise à jour
- Si le trousseau ne demande pas d'autorisation, vous utilisez probablement une ancienne version

### Vérifier quelle version est lancée
```bash
# Vérifier la date de compilation du bundle
ls -la AudiobookForge.app/Contents/MacOS/AudiobookForge

# Vérifier les logs au démarrage
./run.sh
# Rechercher : "🎯 AudiobookForge v1.0.0"
```

### Forcer une recompilation
```bash
# Nettoyer et recompiler
rm -rf AudiobookForge.app
./run.sh
```

## Prochaines versions

### v1.1.0 (planifié)
- Support de la génération locale MLX
- Amélioration de l'interface de sélection des voix
- Export M4B avec chapitres

### v1.2.0 (planifié)
- Support de nouveaux formats d'entrée (TXT, MD)
- Éditeur de balises avancé
- Prévisualisation audio en temps réel
