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
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            // Timestamp — subtle, fixed width
            Text(formatTime(segment.start))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)

            // Words flow
            FlowLayout(spacing: 2) {
                ForEach(Array(segment.words.enumerated()), id: \.offset) { wordIdx, word in
                    let globalIdx = globalOffset + wordIdx
                    let isActive = globalIdx == currentWordIndex
                    Text(word.word)
                        .font(.system(size: 16))
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                        .background(isActive ? Color.yellow.opacity(0.5) : Color.clear)
                        .cornerRadius(3)
                        .onTapGesture { onWordTap(word.start) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            currentWordIndex >= globalOffset &&
            currentWordIndex < globalOffset + segment.words.count
                ? Color.primary.opacity(0.05)
                : Color.clear
        )
        .cornerRadius(4)
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
