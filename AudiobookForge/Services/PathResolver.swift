import Foundation

/// Service centralisé pour résoudre les chemins des exécutables et dossiers du projet
class PathResolver {
    static let shared = PathResolver()
    
    private init() {}
    
    // MARK: - Project Root
    
    /// Résout la racine du projet (priorité à la variable d'env, puis au bundle, puis fallback)
    var projectRoot: String {
        if let root = ProcessInfo.processInfo.environment["AUDIOBOOKFORGE_ROOT"] {
            return root
        }
        
        // Fallback : remonter depuis le bundle
        // Bundle.main.bundleURL = .../.build/debug/AudiobookForge.app
        let url = Bundle.main.bundleURL
            .deletingLastPathComponent() // .../.build/debug/
            .deletingLastPathComponent() // .../.build/
            .deletingLastPathComponent() // racine du projet
        
        let path = url.path
        if FileManager.default.fileExists(atPath: "\(path)/Package.swift") ||
           FileManager.default.fileExists(atPath: "\(path)/backend/scripts") {
            return path
        }
        
        // Dernier recours : le dossier courant
        return FileManager.default.currentDirectoryPath
    }
    
    // MARK: - Backend Scripts
    
    /// Chemin absolu vers le dossier backend/scripts
    var backendScriptsPath: String {
        let scriptsPath = "\(projectRoot)/backend/scripts"
        if FileManager.default.fileExists(atPath: scriptsPath) {
            return scriptsPath
        }
        
        // Si le dossier n'existe pas, retourner quand même le chemin
        // (l'erreur sera gérée par l'appelant)
        return scriptsPath
    }
    
    // MARK: - Python
    
    /// Chemin absolu vers l'interpréteur Python (priorité au venv du projet)
    var pythonPath: String {
        let candidates = [
            "\(projectRoot)/backend/venv/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return "/usr/bin/python3" // Fallback
    }
    
    // MARK: - FFmpeg
    
    /// Chemin absolu vers ffmpeg
    var ffmpegPath: String {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Dernier recours : via which
        if let path = findInPath("ffmpeg") {
            return path
        }
        
        return "/opt/homebrew/bin/ffmpeg" // Fallback
    }
    
    /// Chemin absolu vers ffprobe
    var ffprobePath: String {
        let candidates = [
            "/opt/homebrew/bin/ffprobe",
            "/usr/local/bin/ffprobe",
            "/usr/bin/ffprobe"
        ]
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Dernier recours : via which
        if let path = findInPath("ffprobe") {
            return path
        }
        
        return "/opt/homebrew/bin/ffprobe" // Fallback
    }
    
    // MARK: - Ollama
    
    /// Chemin absolu vers ollama
    var ollamaPath: String {
        let candidates = [
            "/opt/homebrew/bin/ollama",
            "/usr/local/bin/ollama",
            "/usr/bin/ollama"
        ]
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return "/opt/homebrew/bin/ollama" // Fallback
    }
    
    // MARK: - Helper
    
    /// Trouve un exécutable dans le PATH
    private func findInPath(_ executable: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", executable]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
}
