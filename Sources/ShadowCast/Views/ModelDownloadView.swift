import SwiftUI

struct ModelDownloadView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        @Bindable var vm = appViewModel
        VStack(spacing: 8) {
            HStack {
                Text("Whisper Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Model", selection: $vm.selectedModelSize) {
                    ForEach(WhisperModelSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            if appViewModel.isDownloadingModel {
                VStack(spacing: 4) {
                    ProgressView(value: appViewModel.modelDownloadProgress)
                    Text("Downloading model… \(Int(appViewModel.modelDownloadProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
