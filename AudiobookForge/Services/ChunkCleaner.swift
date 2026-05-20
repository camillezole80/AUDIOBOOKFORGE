import Foundation

/// Service pour nettoyer les fichiers chunks après assemblage
class ChunkCleaner {
    private let logger = Logger.shared
    
    /// Nettoie les chunks d'un chapitre après assemblage
    /// - Parameters:
    ///   - chunks: Liste des chunks à nettoyer
    ///   - keepChunks: Si true, garde les chunks (pour debugging)
    func cleanChunks(_ chunks: [Chunk], keepChunks: Bool = false) {
        guard !keepChunks else {
            logger.debug("Keeping chunks for debugging")
            return
        }
        
        logger.info("Cleaning \(chunks.count) chunk files...")
        var deletedCount = 0
        var failedCount = 0
        
        for chunk in chunks {
            guard let path = chunk.audioFilePath else { continue }
            
            do {
                if FileManager.default.fileExists(atPath: path) {
                    try FileManager.default.removeItem(atPath: path)
                    deletedCount += 1
                    logger.debug("Deleted chunk: \(path)")
                }
            } catch {
                failedCount += 1
                logger.warning("Failed to delete chunk \(path): \(error.localizedDescription)")
            }
        }
        
        logger.info("Chunk cleanup complete: deleted=\(deletedCount), failed=\(failedCount)")
    }
    
    /// Nettoie les chunks d'UN chapitre précis (préfixe `chunk_<chapterIndex>_`).
    /// Beaucoup plus sûr que `cleanAllChunks` pendant une génération multi-chapitres
    /// car ça ne touche pas aux chunks en cours/à venir d'autres chapitres.
    func cleanChunksForChapter(in projectDir: String, chapterIndex: Int, keepChunks: Bool = false) {
        guard !keepChunks else {
            logger.debug("Keeping chunks for debugging (chapter \(chapterIndex))")
            return
        }

        let chunksDir = "\(projectDir)/audio/chunks"
        guard FileManager.default.fileExists(atPath: chunksDir) else { return }

        let prefix = "chunk_\(chapterIndex)_"
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: chunksDir)
            var deleted = 0
            for file in files where file.hasPrefix(prefix) && file.hasSuffix(".wav") {
                let path = "\(chunksDir)/\(file)"
                try? FileManager.default.removeItem(atPath: path)
                deleted += 1
            }
            logger.info("Chunks nettoyés pour chapitre \(chapterIndex) : \(deleted) fichiers")
        } catch {
            logger.error(error, context: "Failed to clean chunks for chapter \(chapterIndex)")
        }
    }

    /// Nettoie tous les chunks d'un projet
    /// - Parameters:
    ///   - projectDir: Dossier du projet
    ///   - keepChunks: Si true, garde les chunks
    func cleanAllChunks(in projectDir: String, keepChunks: Bool = false) {
        guard !keepChunks else {
            logger.debug("Keeping all chunks for debugging")
            return
        }
        
        let chunksDir = "\(projectDir)/audio/chunks"
        
        guard FileManager.default.fileExists(atPath: chunksDir) else {
            logger.debug("No chunks directory to clean")
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: chunksDir)
            logger.info("Cleaning \(files.count) chunk files from \(chunksDir)...")
            
            var deletedCount = 0
            for file in files where file.hasSuffix(".wav") {
                let filePath = "\(chunksDir)/\(file)"
                try? FileManager.default.removeItem(atPath: filePath)
                deletedCount += 1
            }
            
            logger.info("Cleaned \(deletedCount) chunk files")
        } catch {
            logger.error(error, context: "Failed to clean chunks directory")
        }
    }
    
    /// Calcule l'espace disque utilisé par les chunks
    /// - Parameter projectDir: Dossier du projet
    /// - Returns: Taille totale en bytes
    func getChunksSize(in projectDir: String) -> Int64 {
        let chunksDir = "\(projectDir)/audio/chunks"
        
        guard FileManager.default.fileExists(atPath: chunksDir) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: chunksDir)
            
            for file in files where file.hasSuffix(".wav") {
                let filePath = "\(chunksDir)/\(file)"
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        } catch {
            logger.error(error, context: "Failed to calculate chunks size")
        }
        
        return totalSize
    }
}
