import AVKit
import SwiftUI

// Custom AVPlayerView subclass that doesn't suppress the resize cursor on split-view dividers.
// Without this, AVPlayerView resets the cursor to the arrow, hiding the resize feedback.
private class PassthroughAVPlayerView: AVPlayerView {
    override func resetCursorRects() {
        // Do not add any cursor rects — let the split view divider own cursor changes
    }
}

struct AVPlayerWrapper: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = PassthroughAVPlayerView()
        view.player = player                      // Set ONCE here — NEVER in updateNSView (COMMON-2)
        view.controlsStyle = .default
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Only update when the player instance actually changes (different video selected).
        // Guarding by identity prevents the seek-order bug from re-assigning mid-playback.
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
