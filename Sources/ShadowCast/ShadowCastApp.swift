import SwiftUI

@main
struct ShadowCastApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appViewModel)
                .task {
                    appViewModel.restorePersistedFolder()
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: NSApplication.willTerminateNotification)
                ) { _ in
                    // Persist the current folder bookmark before quit
                    appViewModel.saveCurrentFolderBookmark()
                    appViewModel.stopWatching()
                }
        }
        .defaultSize(width: 1280, height: 860)
    }
}
