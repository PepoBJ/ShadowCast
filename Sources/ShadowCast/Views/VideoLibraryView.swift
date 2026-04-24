import SwiftUI

struct VideoLibraryView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        @Bindable var vm = appViewModel

        Group {
            if appViewModel.watchedFolderURL == nil {
                noFolderSelectedView
            } else if appViewModel.videoFiles.isEmpty {
                noVideoFilesView
            } else {
                List(appViewModel.videoFiles, selection: $vm.selectedVideoID) { file in
                    VideoFileRow(file: file)
                        .tag(file.id)
                        .listRowBackground(
                            vm.selectedVideoID == file.id
                                ? CP.bgSelected
                                : Color.clear
                        )
                        .listRowSeparator(.hidden)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(CP.bg)
                .safeAreaInset(edge: .bottom) {
                    ModelDownloadView()
                        .background(CP.bgPanel)
                }
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appViewModel.selectFolder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                        Text("LOAD DIR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                }
                .buttonStyle(CyberpunkButtonStyle(color: CP.cyan))
                .help("Select a folder to watch for video files")
            }
        }
    }

    private var noFolderSelectedView: some View {
        ZStack {
            CP.bg
            VStack(spacing: 16) {
                Text("⬡")
                    .font(.system(size: 48, design: .monospaced))
                    .foregroundStyle(CP.cyan)
                    .neonGlow(CP.cyan, radius: 8)

                Text("NO DIRECTORY LOADED")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(CP.cyan)
                    .tracking(2)

                Text("select a folder containing\nyour audio logs")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CP.dim)
                    .multilineTextAlignment(.center)

                Button("LOAD DIRECTORY") { appViewModel.selectFolder() }
                    .buttonStyle(CyberpunkButtonStyle(color: CP.cyan))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noVideoFilesView: some View {
        ZStack {
            CP.bg
            VStack(spacing: 12) {
                Text("▣")
                    .font(.system(size: 40, design: .monospaced))
                    .foregroundStyle(CP.dim)

                Text("NO FILES FOUND")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(CP.dim)
                    .tracking(2)

                if let folderName = appViewModel.watchedFolderURL?.lastPathComponent {
                    Text("/\(folderName.uppercased())")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(CP.dimmer)
                        .lineLimit(1)
                }

                Text("SUPPORTED: MP4  MOV  MKV")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(CP.dimmer)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
