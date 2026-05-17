import Foundation

/// Gestionnaire de version de l'application
struct AppVersion {
    static let current = "1.0.0"
    static let buildNumber = "1"
    
    /// Version complète avec numéro de build
    static var fullVersion: String {
        "\(current) (build \(buildNumber))"
    }
    
    /// Récupère la version depuis le bundle Info.plist
    static var bundleVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (build \(build))"
    }
    
    /// Log la version au démarrage
    static func logVersion() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎯 AudiobookForge v\(bundleVersion)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📅 Démarrage : \(Date())")
        print("💻 Système : macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    /// Changelog de la version actuelle
    static let changelog = """
    Version 1.0.0 - Première version stable
    
    ✨ Nouvelles fonctionnalités :
    • Support complet de Fish.Audio API pour la génération audio
    • Sélection de voix prédéfinies Fish.Audio
    • Configuration flexible AI (Ollama, OpenAI, Anthropic, DeepSeek)
    • Workflow flexible : génération par chapitre ou complète
    • Gestion intelligente de l'espace disque
    • Nettoyage automatique des chunks temporaires
    
    🔧 Améliorations :
    • Logs détaillés pour le debugging
    • Persistance améliorée des configurations
    • Gestion d'erreurs robuste avec reprise
    • Interface utilisateur optimisée
    
    🐛 Corrections :
    • Correction du crash Python lors de la génération audio
    • Correction de la persistance des paramètres audio
    • Correction du balisage avec les APIs distantes
    • Amélioration de la stabilité générale
    """
}
