import Foundation

/// Utilitaire pour vérifier l'espace disque disponible
class DiskSpaceChecker {
    private let logger = Logger.shared
    
    /// Vérifie si l'espace disque est suffisant pour une opération
    /// - Parameters:
    ///   - requiredBytes: Espace requis en bytes
    ///   - path: Chemin où l'espace est nécessaire (par défaut: home directory)
    /// - Returns: true si l'espace est suffisant
    func hasEnoughSpace(requiredBytes: Int64, at path: String? = nil) -> Bool {
        let targetPath = path ?? FileManager.default.homeDirectoryForCurrentUser.path
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: targetPath)
            
            if let freeSpace = attributes[.systemFreeSize] as? Int64 {
                let hasSpace = freeSpace >= requiredBytes
                
                if !hasSpace {
                    logger.warning("Insufficient disk space: required=\(formatBytes(requiredBytes)), available=\(formatBytes(freeSpace))")
                } else {
                    logger.debug("Disk space check OK: required=\(formatBytes(requiredBytes)), available=\(formatBytes(freeSpace))")
                }
                
                return hasSpace
            }
        } catch {
            logger.error(error, context: "Failed to check disk space")
        }
        
        return false
    }
    
    /// Estime l'espace nécessaire pour générer l'audio d'un projet
    /// - Parameters:
    ///   - textLength: Longueur totale du texte en caractères
    ///   - format: Format audio (WAV = ~10MB/min, MP3 = ~1MB/min)
    /// - Returns: Espace estimé en bytes
    func estimateAudioSize(textLength: Int, format: AudioFormat = .wav) -> Int64 {
        // Estimation: ~150 mots/minute de lecture
        // ~5 caractères par mot en moyenne
        let estimatedMinutes = Double(textLength) / (150.0 * 5.0)
        
        let bytesPerMinute: Int64
        switch format {
        case .wav:
            bytesPerMinute = 10 * 1024 * 1024 // 10 MB/min
        case .mp3:
            bytesPerMinute = 1 * 1024 * 1024 // 1 MB/min
        case .aac:
            bytesPerMinute = 2 * 1024 * 1024 // 2 MB/min
        }
        
        // Ajouter 50% de marge pour les chunks temporaires
        let estimatedSize = Int64(estimatedMinutes * Double(bytesPerMinute) * 1.5)
        
        logger.debug("Estimated audio size: \(formatBytes(estimatedSize)) for \(textLength) characters")
        
        return estimatedSize
    }
    
    /// Obtient l'espace disque disponible
    /// - Parameter path: Chemin à vérifier
    /// - Returns: Espace disponible en bytes, ou nil en cas d'erreur
    func getAvailableSpace(at path: String? = nil) -> Int64? {
        let targetPath = path ?? FileManager.default.homeDirectoryForCurrentUser.path
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: targetPath)
            return attributes[.systemFreeSize] as? Int64
        } catch {
            logger.error(error, context: "Failed to get available space")
            return nil
        }
    }
    
    /// Formate un nombre de bytes en format lisible
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    enum AudioFormat {
        case wav
        case mp3
        case aac
    }
}

/// Extension pour faciliter l'utilisation
extension DiskSpaceChecker {
    /// Vérifie l'espace avant de générer l'audio d'un projet
    func checkBeforeAudioGeneration(project: Project) throws {
        let totalTextLength = project.chapters.reduce(0) { $0 + $1.rawText.count }
        let requiredSpace = estimateAudioSize(textLength: totalTextLength, format: .wav)
        
        guard hasEnoughSpace(requiredBytes: requiredSpace, at: project.projectDirectory) else {
            throw DiskSpaceError.insufficientSpace(
                required: requiredSpace,
                available: getAvailableSpace(at: project.projectDirectory) ?? 0
            )
        }
    }
}

enum DiskSpaceError: Error, LocalizedError {
    case insufficientSpace(required: Int64, available: Int64)
    
    var errorDescription: String? {
        switch self {
        case .insufficientSpace(let required, let available):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB]
            formatter.countStyle = .file
            let reqStr = formatter.string(fromByteCount: required)
            let availStr = formatter.string(fromByteCount: available)
            return "Espace disque insuffisant. Requis: \(reqStr), Disponible: \(availStr)"
        }
    }
}
