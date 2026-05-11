import Foundation
import Security

/// Helper pour stocker et récupérer les clés API de manière sécurisée dans le Keychain
class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let service = "com.duchnouk.AudiobookForge.APIKeys"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Sauvegarde une clé API dans le Keychain (AI Provider)
    func save(key: String, for provider: AIProvider) -> Bool {
        let account = provider.rawValue
        
        // Supprimer l'ancienne clé si elle existe
        delete(for: provider)
        
        guard let data = key.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Récupère une clé API depuis le Keychain
    func get(for provider: AIProvider) -> String? {
        let account = provider.rawValue
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    /// Supprime une clé API du Keychain
    func delete(for provider: AIProvider) -> Bool {
        let account = provider.rawValue
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Vérifie si une clé existe pour un provider
    func hasKey(for provider: AIProvider) -> Bool {
        return get(for: provider) != nil
    }
    
    /// Supprime toutes les clés API
    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Audio Provider Support
    
    /// Sauvegarde une clé API dans le Keychain (Audio Provider)
    func save(key: String, for provider: AudioProvider) -> Bool {
        let account = "audio-\(provider.rawValue)"
        
        // Supprimer l'ancienne clé si elle existe
        delete(for: provider)
        
        guard let data = key.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Récupère une clé API depuis le Keychain (Audio Provider)
    func get(for provider: AudioProvider) -> String? {
        let account = "audio-\(provider.rawValue)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    /// Supprime une clé API du Keychain (Audio Provider)
    func delete(for provider: AudioProvider) -> Bool {
        let account = "audio-\(provider.rawValue)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Vérifie si une clé existe pour un provider (Audio Provider)
    func hasKey(for provider: AudioProvider) -> Bool {
        return get(for: provider) != nil
    }
}
