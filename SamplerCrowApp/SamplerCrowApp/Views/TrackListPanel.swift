import SwiftUI

struct TrackListPanel: View {
    let tracks: [TrackState]
    let selectedTrack: Int?
    let levels: [Int]
    let volumes: [Int]
    let mutes: [Bool]
    let onSelect: (Int) -> Void
    let onVolumeChange: (Int, Int) -> Void
    let onMute: (Int) -> Void
    let onRename: (Int, String) -> Void

    @State private var editingTrackIndex: Int? = nil
    @State private var editingName: String = ""

    private static let trackColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    var body: some View {
        VStack(spacing: 4) {
            Text("TRACKS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(0..<8, id: \.self) { idx in
                trackButton(idx)
            }

            Spacer()
        }
        .frame(width: 180)
        .background(Color(.controlBackgroundColor).opacity(0.3))
    }

    private func trackButton(_ idx: Int) -> some View {
        let track = tracks[idx]
        let isSelected = selectedTrack == idx
        let color = Self.trackColors[idx]
        let level = idx < levels.count ? levels[idx] : 0
        let isMuted = idx < mutes.count ? mutes[idx] : false
        let volume = idx < volumes.count ? volumes[idx] : 80

        return Button(action: { onSelect(idx) }) {
            HStack(spacing: 6) {
                // Colored left border for selected
                RoundedRectangle(cornerRadius: 1)
                    .fill(isSelected ? color : Color.clear)
                    .frame(width: 3)

                // Type icon
                Image(systemName: trackTypeIcon(track.trackType))
                    .font(.system(size: 12))
                    .foregroundStyle(color.opacity(isSelected ? 1.0 : 0.6))
                    .frame(width: 14)

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    if editingTrackIndex == idx {
                        TextField("Name", text: $editingName, onCommit: {
                            onRename(idx, editingName)
                            editingTrackIndex = nil
                        })
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .textFieldStyle(.plain)
                        .frame(maxWidth: 60)
                    } else {
                        Text("\(idx + 1). \(track.name)")
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                            .lineLimit(1)
                            .onTapGesture(count: 2) {
                                editingName = track.name
                                editingTrackIndex = idx
                            }
                    }

                    Text(track.trackType.rawValue)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                }

                Spacer()

                // Volume slider
                Slider(
                    value: Binding(
                        get: { Double(volume) },
                        set: { onVolumeChange(idx, Int($0)) }
                    ),
                    in: 0...100
                )
                .frame(width: 40)

                // Mute button
                Button(action: { onMute(idx) }) {
                    Text("M")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(isMuted ? .white : AppTheme.textSecondary)
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isMuted ? Color.red : Color(.controlBackgroundColor))
                        )
                }
                .buttonStyle(.plain)

                // Mini level meter
                GeometryReader { geo in
                    let height = geo.size.height
                    let meterH = CGFloat(level) / 100.0 * height

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(.separatorColor).opacity(0.2))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(meterColor(level))
                            .frame(height: meterH)
                    }
                }
                .frame(width: 5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private func trackTypeIcon(_ type: TrackType) -> String {
        switch type {
        case .sampler: return "waveform"
        case .drumMachine: return "square.grid.2x2"
        case .synth: return "waveform.path"
        case .audio: return "speaker.wave.2"
        case .midi: return "pianokeys"
        }
    }

    private func meterColor(_ level: Int) -> Color {
        if level > 90 { return .red }
        if level > 70 { return .yellow }
        return .green
    }
}
