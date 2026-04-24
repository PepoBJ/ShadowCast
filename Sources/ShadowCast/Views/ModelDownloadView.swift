import SwiftUI

struct ModelDownloadView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        @Bindable var vm = appViewModel
        VStack(spacing: 6) {
            HStack {
                Text("MODEL")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CP.dimmer)
                    .tracking(2)
                Spacer()
                Picker("", selection: $vm.selectedModelSize) {
                    ForEach(WhisperModelSize.allCases, id: \.self) { size in
                        Text(size.displayName)
                            .font(.system(size: 10, design: .monospaced))
                            .tag(size)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }

            if appViewModel.isDownloadingModel {
                VStack(spacing: 4) {
                    ProgressView(value: appViewModel.modelDownloadProgress)
                        .tint(CP.cyan)
                        .background(CP.border.opacity(0.3))
                    Text("DOWNLOADING  \(Int(appViewModel.modelDownloadProgress * 100))%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(CP.cyan)
                        .neonGlow(CP.cyan, radius: 2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(CP.bgPanel)
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(CP.border),
            alignment: .top
        )
    }
}
