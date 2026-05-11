import Foundation
import os.log

/// Service de logging centralisé pour AudiobookForge
class Logger {
    static let shared = Logger()
    
    private let osLog: OSLog
    let logFileURL: URL  // Public pour permettre l'accès depuis les vues
    private let dateFormatter: DateFormatter
    private let fileHandle: FileHandle?
    
    private init() {
        // OSLog pour la console système
        osLog = OSLog(subsystem: "com.duchnouk.AudiobookForge", category: "general")
        
        // Fichier de log
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AudiobookForge")
        
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        let dateString = ISO8601DateFormatter().string(from: Date()).prefix(10)
        logFileURL = logsDir.appendingPathComponent("audiobookforge-\(dateString).log")
        
        // Créer le fichier s'il n'existe pas
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        info("Logger initialized. Log file: \(logFileURL.path)")
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    // MARK: - Public API
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .default, message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .fault, message: message, file: file, function: function, line: line)
    }
    
    // MARK: - Private
    
    private func log(level: OSLogType, message: String, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        let levelString = logLevelString(level)
        
        // Format: [TIMESTAMP] [LEVEL] [File:Line] Message
        let logMessage = "[\(timestamp)] [\(levelString)] [\(fileName):\(line)] \(message)"
        
        // Log vers OSLog (console système)
        os_log("%{public}@", log: osLog, type: level, logMessage)
        
        // Log vers fichier
        if let data = (logMessage + "\n").data(using: .utf8) {
            fileHandle?.write(data)
        }
    }
    
    private func logLevelString(_ level: OSLogType) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .default: return "DEFAULT"
        case .error: return "ERROR"
        case .fault: return "CRITICAL"
        default: return "UNKNOWN"
        }
    }
}

// MARK: - Convenience Extensions

extension Logger {
    /// Log une erreur Swift avec contexte
    func error(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var message = "Error: \(error.localizedDescription)"
        if let context = context {
            message = "\(context) - \(message)"
        }
        log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    /// Log le début d'une opération
    func beginOperation(_ operation: String, file: String = #file, function: String = #function, line: Int = #line) {
        info("▶️ BEGIN: \(operation)", file: file, function: function, line: line)
    }
    
    /// Log la fin d'une opération
    func endOperation(_ operation: String, duration: TimeInterval? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var message = "✅ END: \(operation)"
        if let duration = duration {
            message += " (took \(String(format: "%.2f", duration))s)"
        }
        info(message, file: file, function: function, line: line)
    }
    
    /// Log une opération qui a échoué
    func failedOperation(_ operation: String, error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        self.error("❌ FAILED: \(operation) - \(error.localizedDescription)", file: file, function: function, line: line)
    }
}
