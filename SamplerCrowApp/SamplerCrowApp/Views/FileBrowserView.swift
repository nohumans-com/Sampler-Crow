import SwiftUI

struct FileBrowserView: View {
    @Bindable var viewModel: FileBrowserViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("SD CARD")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Text("Track \(viewModel.targetTrack):")
                    .font(AppTheme.monoFontSmall)
                    .foregroundStyle(AppTheme.textSecondary)
                Picker("", selection: Binding(
                    get: { viewModel.targetTrack },
                    set: { viewModel.targetTrack = $0 }
                )) {
                    ForEach(0..<8, id: \.self) { i in
                        Text(MixerViewModel.trackNames[i]).tag(i)
                    }
                }
                .frame(width: 80)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Navigation bar
            HStack(spacing: 8) {
                Button(action: { viewModel.navigateBack() }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.pathHistory.count <= 1)

                Button(action: { viewModel.navigateToRoot() }) {
                    Image(systemName: "house")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text(viewModel.currentPath)
                    .font(AppTheme.monoFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // File list
            List(viewModel.entries, selection: Binding(
                get: { viewModel.selectedEntry?.id },
                set: { id in
                    viewModel.selectedEntry = viewModel.entries.first { $0.id == id }
                }
            )) { entry in
                HStack {
                    Image(systemName: entry.isDirectory ? "folder.fill" : "waveform")
                        .foregroundStyle(entry.isDirectory ? .yellow : AppTheme.accent)
                        .frame(width: 20)

                    Text(entry.name)
                        .font(AppTheme.monoFont)
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    if let size = entry.size {
                        Text(formatSize(size))
                            .font(AppTheme.monoFontSmall)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if entry.isDirectory {
                        viewModel.navigateInto(entry)
                    } else {
                        viewModel.selectEntry(entry)
                        viewModel.loadSelectedSample()
                    }
                }
                .onTapGesture(count: 1) {
                    viewModel.selectEntry(entry)
                }
            }
            .listStyle(.inset)

            Divider()

            // Bottom bar: preview controls + load
            HStack(spacing: 12) {
                if let selected = viewModel.selectedEntry {
                    if selected.isDirectory {
                        Button("Open Folder") {
                            viewModel.navigateInto(selected)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        // Preview controls
                        HStack(spacing: 6) {
                            // Play once
                            Button(action: {
                                if viewModel.isPreviewPlaying && !viewModel.isPreviewLooping {
                                    viewModel.previewStop()
                                } else {
                                    viewModel.previewSelected()
                                }
                            }) {
                                Image(systemName: viewModel.isPreviewPlaying && !viewModel.isPreviewLooping ? "stop.fill" : "play.fill")
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(viewModel.isPreviewPlaying && !viewModel.isPreviewLooping ? .red : .green)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Preview (Space)")

                            // Loop
                            Button(action: {
                                if viewModel.isPreviewLooping {
                                    viewModel.previewStop()
                                } else {
                                    viewModel.previewLoopSelected()
                                }
                            }) {
                                Image(systemName: "repeat")
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(viewModel.isPreviewLooping ? .orange : AppTheme.textSecondary)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Loop Preview")

                            // Stop
                            if viewModel.isPreviewPlaying {
                                Button(action: { viewModel.previewStop() }) {
                                    Image(systemName: "stop.fill")
                                        .frame(width: 28, height: 28)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        Text(selected.name)
                            .font(AppTheme.monoFont)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Button("Load to \(MixerViewModel.trackNames[viewModel.targetTrack])") {
                            viewModel.loadSelectedSample()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                } else {
                    Text("Select a sample to preview or load  |  Space = Play/Stop preview")
                        .font(AppTheme.monoFontSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.requestDirectory("/")
        }
        .onDisappear {
            // Stop preview when leaving tab
            if viewModel.isPreviewPlaying {
                viewModel.previewStop()
            }
        }
    }

    private func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }
}
