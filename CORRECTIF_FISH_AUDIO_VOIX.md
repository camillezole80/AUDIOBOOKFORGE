# Correctif Fish.Audio - Sélection de voix

## 🎯 Problèmes résolus

### 1. La voix ne reste pas sélectionnée après réouverture
**Cause** : `selectedVoiceId` n'était pas rechargé depuis `voiceConfig.selectedFishAudioVoice` dans `onAppear`

**Solution** : Ajout du chargement dans `onAppear` :
```swift
.onAppear {
    // ...
    // Charger la voix sélectionnée
    if let savedVoiceId = voiceConfig.selectedFishAudioVoice {
        selectedVoiceId = savedVoiceId
        print("🔄 Chargement de la voix sauvegardée: \(savedVoiceId)")
    }
}
```

### 2. Erreur "Reference not found" (400)

**Problème** : Vous avez sélectionné "pierre" qui est le **nom** de la voix, pas son **ID**.

Fish.Audio utilise des IDs uniques pour identifier les voix, par exemple :
- Nom affiché : "Pierre"
- ID réel : `7a2e8b3c-4d5f-6g7h-8i9j-0k1l2m3n4o5p` (UUID)

**Ce qui se passe** :
1. Vous sélectionnez "Pierre" dans l'interface
2. L'app sauvegarde l'ID de cette voix (ex: `7a2e8b3c...`)
3. Lors de la génération, l'app envoie cet ID à Fish.Audio
4. Si l'ID n'existe pas ou n'est pas valide → erreur 400 "Reference not found"

## ✅ Solution

### Vérifier l'ID sauvegardé

1. **Relancer l'app** (build réussi 4.92s)
2. **Ouvrir les réglages audio**
3. **Charger les voix** (bouton "Charger les voix")
4. **Sélectionner "Pierre"**
5. **Cliquer sur "Enregistrer"**
6. **Regarder les logs** :

```
💾 Sauvegarde de selectedFishAudioVoice: <ID_DE_LA_VOIX>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 AudioSettings.saveSettings() appelé
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 Valeurs sauvegardées:
  - selectedFishAudioVoice: <ID_DE_LA_VOIX>
```

7. **Copier l'ID** affiché dans les logs
8. **Vérifier dans le project.json** :

```bash
cat audio/Projects/<votre_projet>/project.json | jq '.voiceConfig.selectedFishAudioVoice'
```

### Si l'ID est invalide

Si vous voyez `"pierre"` au lieu d'un UUID, c'est que l'ID n'a pas été correctement sauvegardé.

**Solutions** :
1. **Recharger les voix** et resélectionner "Pierre"
2. **Vérifier que le bouton "Charger les voix" fonctionne** (doit afficher la liste)
3. **Si la liste est vide** : Vérifier votre clé API Fish.Audio

### Si l'ID est correct mais l'erreur persiste

L'ID sauvegardé peut être :
- Un ID de voix qui n'existe plus sur Fish.Audio
- Un ID de voix privée (créée par un autre utilisateur)
- Un ID de référence personnelle (créée avec votre compte)

**Solution** : Utiliser une voix publique de Fish.Audio :
1. Charger les voix disponibles
2. Sélectionner une voix dans la liste
3. Sauvegarder

## 🧪 Test complet

1. **Relancer l'app**
2. **Ouvrir les réglages audio** (icône 🔊)
3. **Sélectionner "Fish.Audio API"**
4. **Entrer votre clé API**
5. **Cliquer sur "Charger les voix"**
6. **Attendre que la liste apparaisse**
7. **Sélectionner une voix** (ex: "Pierre")
8. **Cliquer sur "Enregistrer"**
9. **Fermer et rouvrir les réglages**
10. **Vérifier que "Pierre" est toujours sélectionné** ✅
11. **Lancer un preview**
12. **Vérifier qu'il n'y a pas d'erreur** ✅

## 📊 Résultat

**Build réussi** : 4.92s ✨

La voix sélectionnée devrait maintenant :
- Rester sélectionnée après fermeture/réouverture
- Fonctionner lors de la génération (si l'ID est valide)

## Date

20 mai 2026, 11:51
