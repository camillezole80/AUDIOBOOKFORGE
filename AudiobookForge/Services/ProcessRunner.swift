import Foundation

/// Lance un sous-processus (ffmpeg, ffprobe, Python…) sans risque de deadlock
/// par pipe pleine.
///
/// Anti-pattern qui a déjà fait planter l'app : créer un `Process` avec `Pipe()`
/// sur stdout/stderr, puis appeler `process.waitUntilExit()` SANS drainer les
/// pipes en parallèle. La pipe macOS a un buffer de ~64 Ko ; ffmpeg/Python
/// écrivent plus que ça → le sous-processus bloque sur `write()` → Swift bloque
/// sur `waitUntilExit()` → `isProcessing` reste à `true` → l'UI gèle.
///
/// Ce helper :
/// - branche stdin sur `/dev/null` (pas d'attente d'input)
/// - draine stderr/stdout en continu via `readabilityHandler`
/// - impose un timeout dur en sécurité (kill du processus si dépassé)
enum ProcessRunner {

    struct Result {
        let status: Int32
        let stderr: String
        let stdout: String
    }

    /// Erreur quand le sous-processus ne sort pas dans les délais.
    enum RunError: Error, LocalizedError {
        case timeout(String)
        case launchFailed(String)

        var errorDescription: String? {
            switch self {
            case .timeout(let cmd):
                return "Le sous-processus a dépassé son délai et a été tué : \(cmd)"
            case .launchFailed(let cmd):
                return "Impossible de lancer le sous-processus : \(cmd)"
            }
        }
    }

    /// Lance `executable` avec `arguments`. Retourne le code de sortie et les sorties capturées.
    /// - Parameter stdoutHandler: si fourni, appelé à chaque chunk de stdout en plus de l'accumulation.
    static func run(
        executable: String,
        arguments: [String],
        timeoutSeconds: Double = 300,
        stdoutHandler: (@Sendable (Data) -> Void)? = nil
    ) async throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stderrPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = stdoutPipe
        process.standardInput = FileHandle.nullDevice

        // Box thread-safe pour accumuler les flux pendant l'exécution.
        final class OutBox: @unchecked Sendable {
            private let lock = NSLock()
            private var data = Data()
            func append(_ d: Data) { lock.lock(); data.append(d); lock.unlock() }
            func snapshot() -> String { lock.lock(); defer { lock.unlock() }; return String(data: data, encoding: .utf8) ?? "" }
        }
        let stderrBox = OutBox()
        let stdoutBox = OutBox()

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty { handle.readabilityHandler = nil; return }
            stderrBox.append(chunk)
        }
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty { handle.readabilityHandler = nil; return }
            stdoutBox.append(chunk)
            stdoutHandler?(chunk)
        }

        do {
            try process.run()
        } catch {
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            throw RunError.launchFailed("\(executable) (\(error.localizedDescription))")
        }

        let waitTask = Task<Void, Never> { process.waitUntilExit() }
        let timeoutTask = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            if process.isRunning {
                process.terminate()
            }
        }
        await waitTask.value
        timeoutTask.cancel()

        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdoutPipe.fileHandleForReading.readabilityHandler = nil

        return Result(
            status: process.terminationStatus,
            stderr: stderrBox.snapshot(),
            stdout: stdoutBox.snapshot()
        )
    }
}
