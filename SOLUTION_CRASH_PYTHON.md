# 🔧 Solution au crash Python lors de la génération audio

## 📋 Problème identifié

Le crash Python se produit car :

1. **Le projet est configuré avec `preferredProvider = .local`** (génération locale via MLX)
2. **Mais le script Python `fish_s2_pro.py` est appelé** au lieu du script MLX local
3. **Le script Fish Audio nécessite une clé API** qui n'est pas fournie
4. **Résultat : crash avec l'erreur "API key is required"**

## 🔍 Analyse du code

### Dans `AudioGenerationService.swift` (ligne 89-107)

```swift
private func generateAudioChunk(text: String, chunkIndex: Int, config: VoiceConfig) async throws -> URL {
    // Déterminer le provider effectif
    let effectiveProvider: AudioProvider
    if config.forceRemote {
        effectiveProvider = .fishAudio
    } else if config.preferredProvider == .local {
        // ⚠️ PROBLÈME ICI : On vérifie MLX mais on appelle fish_s2_pro.py
        if await checkMLXAvailability() {
            effectiveProvider = .local
        } else if config.fallbackToRemote {
            effectiveProvider = .fishAudio
        } else {
            throw AudioGenerationError.mlxNotAvailable
        }
    } else {
        effectiveProvider = config.preferredProvider
    }
    
    // ⚠️ PROBLÈME : On appelle toujours generateWithPython
    // qui utilise fish_s2_pro.py au lieu d'un script MLX
    return try await generateWithPython(...)
}
```

### Dans `generateWithPython` (ligne 109-180)

```swift
private func generateWithPython(...) async throws -> URL {
    // ⚠️ PROBLÈME : Toujours fish_s2_pro.py
    let scriptPath = "\(backendPath)/scripts/generate/fish_s2_pro.py"
    
    // Le script nécessite une clé API Fish.Audio
    // Mais si provider = .local, on n'en a pas !
}
```

## ✅ Solutions possibles

### Solution 1 : Créer un script MLX séparé (RECOMMANDÉ)

Créer `backend/scripts/generate/mlx_local.py` pour la génération locale :

```python
#!/usr/bin/env python3
"""
Génération audio locale via MLX (Apple Silicon)
"""
import sys
import json
from pathlib import Path

def generate_audio_mlx(text: str, reference_audio: str, reference_text: str, output_path: str):
    """Génère l'audio en utilisant MLX localement"""
    # TODO: Implémenter la génération MLX
    # Utiliser un modèle TTS local optimisé pour Apple Silicon
    pass

if __name__ == "__main__":
    config = json.loads(sys.argv[1])
    generate_audio_mlx(
        text=config["text"],
        reference_audio=config["reference_audio"],
        reference_text=config["reference_text"],
        output_path=config["output_path"]
    )
```

Puis modifier `AudioGenerationService.swift` :

```swift
private func generateWithPython(...) async throws -> URL {
    // Choisir le bon script selon le provider
    let scriptName = provider == .local ? "mlx_local.py" : "fish_s2_pro.py"
    let scriptPath = "\(backendPath)/scripts/generate/\(scriptName)"
    
    // Pour Fish.Audio, récupérer la clé API
    if provider == .fishAudio {
        guard let apiKey = KeychainHelper.shared.get(for: .fishAudio) else {
            throw AudioGenerationError.missingAPIKey
        }
        config["api_key"] = apiKey
    }
    
    // ...
}
```

### Solution 2 : Désactiver temporairement le mode local

Modifier `Project.swift` pour forcer Fish.Audio par défaut :

```swift
struct VoiceConfig: Codable {
    var preferredProvider: AudioProvider = .fishAudio  // Au lieu de .local
    var forceRemote: Bool = false
    var fallbackToRemote: Bool = true
    // ...
}
```

### Solution 3 : Améliorer la détection MLX

Modifier `checkMLXAvailability()` pour retourner `false` si MLX n'est pas vraiment disponible :

```swift
private func checkMLXAvailability() async -> Bool {
    // Vérifier que le script MLX existe
    let mlxScriptPath = "\(backendPath)/scripts/generate/mlx_local.py"
    guard FileManager.default.fileExists(atPath: mlxScriptPath) else {
        print("⚠️ Script MLX non trouvé, fallback vers Fish.Audio")
        return false
    }
    
    // Vérifier que MLX est installé
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = ["-c", "import mlx; print('OK')"]
    
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        print("⚠️ MLX non disponible: \(error)")
        return false
    }
}
```

## 🎯 Solution immédiate recommandée

**Pour débloquer immédiatement l'utilisateur :**

1. **Modifier le provider par défaut** dans `Project.swift` :
   ```swift
   var preferredProvider: AudioProvider = .fishAudio
   ```

2. **Ajouter un message clair** dans `VoiceStepView.swift` :
   ```swift
   Text("⚠️ La génération locale (MLX) n'est pas encore implémentée. Utilisez Fish.Audio API.")
       .foregroundColor(.orange)
       .font(.caption)
   ```

3. **Guider l'utilisateur** vers la configuration Fish.Audio dans `AudioSettingsView`

## 📝 TODO pour implémenter MLX

- [ ] Créer `backend/scripts/generate/mlx_local.py`
- [ ] Installer les dépendances MLX : `pip install mlx mlx-lm`
- [ ] Télécharger un modèle TTS compatible MLX
- [ ] Implémenter la génération audio dans le script Python
- [ ] Tester sur Apple Silicon (M1/M2/M3)
- [ ] Mettre à jour `checkMLXAvailability()` pour vérifier réellement MLX
- [ ] Documenter le processus dans `GUIDE_MLX_LOCAL.md`

## 🔗 Liens utiles

- [MLX Documentation](https://ml-explore.github.io/mlx/)
- [Fish.Audio API](https://fish.audio/docs)
- [Apple Silicon TTS Models](https://huggingface.co/models?pipeline_tag=text-to-speech&library=mlx)
