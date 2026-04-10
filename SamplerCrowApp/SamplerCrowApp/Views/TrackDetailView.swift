import SwiftUI

struct TrackDetailView: View {
    let track: TrackState
    let samplerVM: SamplerViewModel?
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TRACK \(track.index): \(track.name)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Picker("Type", selection: Binding(
                    get: { track.trackType },
                    set: { track.trackType = $0 }
                )) {
                    Text("Sampler").tag(TrackType.sampler)
                    Text("Synth").tag(TrackType.synth)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Content based on track type
            Group {
                switch track.trackType {
                case .sampler:
                    if let vm = samplerVM {
                        SamplerView(track: track, samplerVM: vm, appState: appState)
                    } else {
                        Text("Sampler not initialized")
                            .font(AppTheme.monoFont)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .drumMachine:
                    Text("Use Navigator tab for Drum Machine")
                        .font(AppTheme.monoFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .synth:
                    Text("Synth parameters")
                        .font(AppTheme.monoFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .audio, .midi:
                    Text("Coming soon")
                        .font(AppTheme.monoFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
