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
                }
                .listStyle(.sidebar)
                .safeAreaInset(edge: .bottom) {
                    ModelDownloadView()
                        .background(.bar)
                }
            }
        }
        .navigationTitle("Videos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appViewModel.selectFolder()
                } label: {
                    Label("Choose Folder", systemImage: "folder.badge.plus")
                }
                .help("Select a folder to watch for video files")
            }
        }
    }

    private var noFolderSelectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Folder Selected")
                .font(.headline)
            Text("Choose a folder containing your video files")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Choose Folder") {
                appViewModel.selectFolder()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noVideoFilesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Video Files Found")
                .font(.headline)
            if let folderName = appViewModel.watchedFolderURL?.lastPathComponent {
                Text("No video files found in \"\(folderName)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Supported formats: MP4, MOV, MKV")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
