import SwiftUI

struct TranscriptView: View {
    let transcript: TranscriptDocument
    let currentWordIndex: Int
    let onWordTap: (Double) -> Void

    // Precompute flat word offset for each segment
    private var segmentOffsets: [Int] {
        var offsets: [Int] = []
        var running = 0
        for seg in transcript.segments {
            offsets.append(running)
            running += seg.words.count
        }
        return offsets
    }

    // Which segment contains the current word
    private var activeSegmentIndex: Int {
        guard currentWordIndex >= 0 else { return 0 }
        return segmentOffsets.lastIndex(where: { $0 <= currentWordIndex }) ?? 0
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(transcript.segments.enumerated()), id: \.offset) { segIdx, segment in
                        let offset = segmentOffsets.indices.contains(segIdx) ? segmentOffsets[segIdx] : 0
                        SegmentLineView(
                            segment: segment,
                            globalOffset: offset,
                            currentWordIndex: currentWordIndex,
                            onWordTap: onWordTap
                        )
                        .id(segIdx)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(CP.bg)
            .scrollContentBackground(.hidden)
            .onChange(of: activeSegmentIndex) { _, segIdx in
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(segIdx, anchor: .top)
                }
            }
        }
    }
}

private struct SegmentLineView: View {
    let segment: TranscriptSegment
    let globalOffset: Int
    let currentWordIndex: Int
    let onWordTap: (Double) -> Void

    @State private var hovered = false

    var body: some View {
        let isSegmentActive = currentWordIndex >= globalOffset &&
                              currentWordIndex < globalOffset + segment.words.count

        HStack(alignment: .firstTextBaseline, spacing: 10) {
            // Timestamp — neon cyan monospace
            Text(formatTime(segment.start))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isSegmentActive ? CP.cyan : CP.dimmer)
                .frame(width: 36, alignment: .trailing)

            // Words flow
            FlowLayout(spacing: 3) {
                ForEach(Array(segment.words.enumerated()), id: \.offset) { wordIdx, word in
                    let globalIdx = globalOffset + wordIdx
                    let isActive = globalIdx == currentWordIndex
                    Text(word.word)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(isActive ? CP.bg : Color.white.opacity(0.85))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)
                        .background(isActive ? CP.yellow : Color.clear)
                        .cornerRadius(2)
                        .shadow(color: isActive ? CP.yellow.opacity(0.8) : .clear, radius: 4)
                        .onTapGesture { onWordTap(word.start) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(isSegmentActive ? CP.cyan.opacity(0.06) : Color.clear)
        .overlay(
            isSegmentActive
                ? Rectangle().frame(width: 2).foregroundStyle(CP.cyan).neonGlow(CP.cyan, radius: 3)
                : nil,
            alignment: .leading
        )
        .cornerRadius(3)
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
