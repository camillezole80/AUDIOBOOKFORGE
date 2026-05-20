import Foundation
import AVFoundation
import Combine

/// Joue un extrait audio (mp3/wav) hébergé par Fish.Audio pour permettre à
/// l'utilisateur d'écouter une voix avant de la sélectionner.
///
/// Une seule voix joue à la fois ; relancer sur une autre voix coupe la précédente.
/// La sheet `AudioSettingsView` détient une instance via `@StateObject` ; à la
/// fermeture, `deinit` arrête tout son en cours.
@MainActor
final class VoicePreviewPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    /// ID de la voix actuellement en cours de lecture (nil = silence).
    @Published private(set) var playingVoiceId: String? = nil
    /// ID de la voix en cours de téléchargement (avant lecture).
    @Published private(set) var loadingVoiceId: String? = nil

    private var player: AVAudioPlayer?
    private var currentTask: Task<Void, Never>?
    /// Cache simple ID → data, pour ne pas redownloader pendant la session.
    private var cache: [String: Data] = [:]

    deinit {
        // deinit n'est pas isolé sur le main actor : on touche directement à l'AVPlayer
        // sans toucher aux @Published (qui de toute façon seront déalloués).
        player?.stop()
        player = nil
    }

    /// Bouton play/stop d'une voix : si elle joue déjà → stop, sinon lance la lecture.
    func toggle(voice: FishAudioVoice) {
        if playingVoiceId == voice.id || loadingVoiceId == voice.id {
            stop()
            return
        }
        play(voice: voice)
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        player?.stop()
        player = nil
        playingVoiceId = nil
        loadingVoiceId = nil
    }

    private func play(voice: FishAudioVoice) {
        guard let url = voice.previewURL else {
            print("⚠️ VoicePreviewPlayer: pas de sample pour la voix \(voice.id)")
            return
        }

        // Couper toute lecture précédente
        currentTask?.cancel()
        player?.stop()
        player = nil
        playingVoiceId = nil
        loadingVoiceId = voice.id

        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let data: Data
                if let cached = self.cache[voice.id] {
                    data = cached
                } else {
                    let (downloaded, _) = try await URLSession.shared.data(from: url)
                    self.cache[voice.id] = downloaded
                    data = downloaded
                }

                guard !Task.isCancelled else { return }

                let newPlayer = try AVAudioPlayer(data: data)
                newPlayer.delegate = self
                newPlayer.prepareToPlay()
                self.player = newPlayer
                self.loadingVoiceId = nil
                self.playingVoiceId = voice.id
                newPlayer.play()
            } catch {
                if !Task.isCancelled {
                    print("❌ VoicePreviewPlayer: \(error.localizedDescription)")
                    self.loadingVoiceId = nil
                }
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate (non-isolé)

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.player = nil
            self?.playingVoiceId = nil
        }
    }
}
