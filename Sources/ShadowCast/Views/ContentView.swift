import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        @Bindable var vm = appViewModel
        NavigationSplitView {
            VideoLibraryView()
        } detail: {
            if let playerVM = appViewModel.playerViewModel,
               let selectedID = appViewModel.selectedVideoID {
                PlayerView(viewModel: playerVM)
                    .id(selectedID)  // force full recreation on video change
            } else if let id = appViewModel.selectedVideoID,
                      let file = appViewModel.videoFiles.first(where: { $0.id == id }) {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(file.displayName)
                        .font(.title2)
                    Text(file.formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if file.isMKV && !file.isReadyForPlayback {
                        VStack(spacing: 10) {
                            Text("MKV files need a one-time conversion to MP4 before playback.\nThis is fast (stream copy, no quality loss).")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Convert & Play") {
                                appViewModel.convertAndPlay(file: file)
                            }
                            .buttonStyle(.borderedProminent)
                            Text("Or click Transcribe — conversion happens automatically.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Text("Click play to watch. Transcribe to add synchronized transcript.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WelcomeDetailView()
            }
        }
        .onChange(of: vm.selectedVideoID) { _, newID in
            appViewModel.selectVideo(id: newID)
        }
        .frame(minWidth: 1000, minHeight: 680)
    }
}
