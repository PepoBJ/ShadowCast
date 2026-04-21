import AVFoundation
import AVKit
import Observation
import Combine
import Foundation

/// Wrapper to make the opaque time observer token accessible from nonisolated deinit.
private final class TokenBox: @unchecked Sendable {
    var token: Any?
    var player: AVPlayer?
    init(token: Any?, player: AVPlayer) {
        self.token = token
        self.player = player
    }
}

@Observable
@MainActor
final class PlayerViewModel {
    private(set) var player: AVPlayer
    private(set) var currentWordIndex: Int = -1
    var isPlaying: Bool = false
    var playbackRate: Float = 1.0
    private(set) var transcript: TranscriptDocument?
    @ObservationIgnored private var words: [WordTiming]
    @ObservationIgnored private var statusCancellable: AnyCancellable?
    // TokenBox is Sendable, safe for nonisolated deinit (COMMON-1 cleanup)
    @ObservationIgnored private let tokenBox: TokenBox

    /// - transcriptURL: override where to load the transcript from.
    ///   Pass the original file's transcriptURL when `file` points to a remuxed cache copy.
    init(file: VideoFile, transcriptURL: URL? = nil) {
        let sidecar = transcriptURL ?? file.transcriptURL
        if let data = try? Data(contentsOf: sidecar),
           let doc = try? JSONDecoder().decode(TranscriptDocument.self, from: data) {
            self.transcript = doc
            self.words = doc.allWords
        } else {
            self.transcript = nil
            self.words = []
        }

        let item = AVPlayerItem(url: file.url)
        let avPlayer = AVPlayer(playerItem: item)
        self.player = avPlayer
        self.tokenBox = TokenBox(token: nil, player: avPlayer)

        self.statusCancellable = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak avPlayer] status in
                if status == .failed { avPlayer?.pause() }
            }

        // COMMON-1: [weak self] prevents retain cycle
        let box = self.tokenBox
        let token = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.updateHighlight(at: time.seconds)
            }
        }
        box.token = token
    }

    deinit {
        // Remove time observer on main queue synchronously to avoid isolation assertion crash.
        // DispatchSource callbacks asserting MainActor isolation can fire during deinit
        // if deinit happens off-main (e.g. triggered by SwiftUI view teardown).
        let box = tokenBox
        if Thread.isMainThread {
            if let token = box.token { box.player?.removeTimeObserver(token) }
            box.player?.pause()
        } else {
            DispatchQueue.main.sync {
                if let token = box.token { box.player?.removeTimeObserver(token) }
                box.player?.pause()
            }
        }
    }

    // MARK: - Transcript Reload

    /// Reload transcript from disk without recreating AVPlayer.
    /// Called after transcription completes for the currently playing video.
    func reloadTranscript(from url: URL) {
        if let data = try? Data(contentsOf: url),
           let doc = try? JSONDecoder().decode(TranscriptDocument.self, from: data) {
            transcript = doc
            words = doc.allWords
            currentWordIndex = -1
        }
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        if player.rate != 0 {
            player.pause()
            isPlaying = false
        } else {
            player.rate = playbackRate
            isPlaying = true
        }
    }

    // MARK: - Seek (COMMON-3: .zero tolerance)

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seekRelative(by delta: Double) {
        let current = player.currentTime().seconds
        seek(to: max(0, current + delta))
    }

    // MARK: - Speed (D-59)

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        // Apply immediately if playing; AVPlayer.rate drives playback speed directly
        if player.rate != 0 {
            player.rate = rate
        }
    }

    // MARK: - Highlight (D-51)

    private func updateHighlight(at currentTime: Double) {
        // Keep isPlaying in sync with actual player state
        isPlaying = player.rate != 0
        guard transcript != nil else { return }
        if let idx = transcript?.wordIndex(at: currentTime, in: words) {
            currentWordIndex = idx
        }
    }
}
