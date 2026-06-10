import Foundation
import AVFoundation

class SoundManager {

    enum SoundType: String {
        case success
        case coin
        case streak
        case error
    }

    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]
    private var isLoaded = false

    init() {
        // Load bundled sounds when present; missing files simply keep the app silent.
        loadSoundIfAvailable(.success, filename: "success")
        loadSoundIfAvailable(.coin, filename: "coin")
        loadSoundIfAvailable(.streak, filename: "streak")
        loadSoundIfAvailable(.error, filename: "error")
        isLoaded = true
    }

    private func loadSoundIfAvailable(_ type: SoundType, filename: String) {
        // Try .wav first, then .mp3, then .m4a
        for ext in ["wav", "mp3", "m4a"] {
            if let url = Bundle.main.url(forResource: filename, withExtension: ext) {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    audioPlayers[type] = player
                    return
                } catch {
                    continue
                }
            }
        }
    }

    func loadSound(type: SoundType, url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayers[type] = player
        } catch {
            print("Failed to load sound: \(error)")
        }
    }

    func playSound(_ type: SoundType) {
        guard isLoaded else { return }
        guard let player = audioPlayers[type] else { return }
        player.currentTime = 0
        player.play()
    }

    func release() {
        audioPlayers.values.forEach { $0.stop() }
        audioPlayers.removeAll()
    }
}
