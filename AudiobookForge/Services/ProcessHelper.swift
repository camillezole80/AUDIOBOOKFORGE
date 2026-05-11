import Foundation

/// Helper pour exécuter des Process avec timeout et gestion d'erreur robuste
class ProcessHelper {
    private let logger = Logger.shared
    
    enum ProcessError: Error, LocalizedError {
        case timeout(String)
        case executionFailed(Int32, String)
        case executableNotFound(String)
        
        var errorDescription: String? {
            switch self {
            case .timeout(let command):
                return "Timeout lors de l'exécution de: \(command)"
            case .executionFailed(let code, let error):
                return "Échec de l'exécution (code \(code)): \(error)"
            case .executableNotFound(let path):
                return "Exécutable introuvable: \(path)"
            }
        }
    }
    
    /// Exécute un process avec timeout et gestion d'erreur
    func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 300, // 5 minutes par défaut
        workingDirectory: String? = nil
    ) async throws -> (output: String, error: String) {
        
        // Vérifier que l'exécutable existe
        guard FileManager.default.fileExists(atPath: executable) else {
            logger.error("Executable not found: \(executable)")
            throw ProcessError.executableNotFound(executable)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        if let workingDir = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        logger.debug("Running: \(executable) \(arguments.joined(separator: " "))")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try process.run()
                    
                    // Créer un timer pour le timeout
                    let timer = DispatchSource.makeTimerSource(queue: .global())
                    timer.schedule(deadline: .now() + timeout)
                    timer.setEventHandler {
                        if process.isRunning {
                            self.logger.warning("Process timeout, terminating: \(executable)")
                            process.terminate()
                        }
                    }
                    timer.resume()
                    
                    // Attendre la fin du process
                    process.waitUntilExit()
                    timer.cancel()
                    
                    // Lire les sorties
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    // Vérifier le code de sortie
                    if process.terminationStatus != 0 {
                        self.logger.error("Process failed with code \(process.terminationStatus): \(error)")
                        continuation.resume(throwing: ProcessError.executionFailed(process.terminationStatus, error))
                    } else {
                        self.logger.debug("Process completed successfully")
                        continuation.resume(returning: (output, error))
                    }
                    
                } catch {
                    self.logger.error(error, context: "Process execution failed")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Exécute un process sans attendre de sortie (fire and forget)
    func runDetached(
        executable: String,
        arguments: [String],
        workingDirectory: String? = nil
    ) throws {
        guard FileManager.default.fileExists(atPath: executable) else {
            logger.error("Executable not found: \(executable)")
            throw ProcessError.executableNotFound(executable)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        if let workingDir = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }
        
        // Rediriger vers /dev/null
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        logger.debug("Running detached: \(executable) \(arguments.joined(separator: " "))")
        try process.run()
    }
}
