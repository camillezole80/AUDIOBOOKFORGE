import Foundation

enum AudioSpeedProcessor {
    static func apply(speed: Double, to filePath: String) async throws {
        guard abs(speed - 1.0) > 0.001 else { return }

        let resolvedSpeed = min(max(speed, 0.5), 2.0)
        let temporaryPath = "\(filePath).speed-\(UUID().uuidString).wav"
        defer { try? FileManager.default.removeItem(atPath: temporaryPath) }

        let result = try await ProcessRunner.run(
            executable: PathResolver.shared.ffmpegPath,
            arguments: [
                "-nostdin",
                "-loglevel", "error",
                "-i", filePath,
                "-af", "atempo=\(String(format: "%.3f", resolvedSpeed))",
                "-c:a", "pcm_s16le",
                "-y",
                temporaryPath,
            ],
            timeoutSeconds: 120
        )

        guard result.status == 0,
              let attributes = try? FileManager.default.attributesOfItem(atPath: temporaryPath),
              (attributes[.size] as? Int ?? 0) > 1024 else {
            throw SpeedError.processingFailed(result.stderr)
        }

        let source = URL(fileURLWithPath: temporaryPath)
        let destination = URL(fileURLWithPath: filePath)
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: source)
    }

    enum SpeedError: LocalizedError {
        case processingFailed(String)

        var errorDescription: String? {
            switch self {
            case .processingFailed(let details):
                return "Impossible d'appliquer la vitesse de lecture : \(details.suffix(200))"
            }
        }
    }
}
