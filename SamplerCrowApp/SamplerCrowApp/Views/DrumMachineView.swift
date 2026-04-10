import SwiftUI

struct DrumMachineView: View {
    let track: TrackState
    @Bindable var drumVM: DrumMachineViewModel
    let appState: AppState

    private static let trackColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    private var trackColor: Color {
        Self.trackColors[track.index % Self.trackColors.count]
    }

    private static let padColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("DRUM MACHINE - TRACK \(track.index + 1)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Button("Sync") {
                    drumVM.syncSelectedPad()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Pad Grid: 2 rows x 4 columns
            padGrid
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // Selected pad parameters
            if drumVM.selectedPad >= 0 && drumVM.selectedPad < 8 {
                padParamEditor
            }

            Spacer()
        }
        .onAppear {
            drumVM.trackIndex = track.index
            drumVM.syncSelectedPad()
        }
        .onChange(of: track.index) { _, newValue in
            drumVM.trackIndex = newValue
            drumVM.syncSelectedPad()
        }
    }

    // MARK: - Pad Grid

    private var padGrid: some View {
        VStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { col in
                        let padIdx = row * 4 + col
                        padButton(padIdx)
                    }
                }
            }
        }
    }

    private func padButton(_ padIdx: Int) -> some View {
        let pad = track.drumPads[padIdx]
        let isSelected = drumVM.selectedPad == padIdx
        let hasContent = !pad.sampleName.isEmpty

        return VStack(spacing: 4) {
            Text("\(padIdx + 1)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? Self.padColors[padIdx] : AppTheme.textSecondary)

            Text(hasContent ? pad.sampleName : "Empty")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(hasContent ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.5))
                .lineLimit(1)
                .truncationMode(.middle)

            if isSelected {
                Circle()
                    .fill(Self.padColors[padIdx])
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Self.padColors[padIdx].opacity(0.1) : Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Self.padColors[padIdx].opacity(0.8) : AppTheme.border.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            drumVM.selectedPad = padIdx
            drumVM.syncSelectedPad()
        }
        .onTapGesture(count: 2) {
            // Double-click: open file browser targeting this pad
            drumVM.selectedPad = padIdx
            if let fbvm = findFileBrowserVM() {
                fbvm.targetTrack = track.index
                fbvm.targetPad = padIdx
            }
            appState.selectedTab = .samples
        }
    }

    private func findFileBrowserVM() -> FileBrowserViewModel? {
        // Navigate through the app to find the FileBrowserViewModel
        // This is set up via MainView's initialization
        return nil
    }

    // MARK: - Pad Parameter Editor

    private var padParamEditor: some View {
        let pad = drumVM.selectedPad
        let padState = track.drumPads[pad]
        let state = padState.params
        let padColor = Self.padColors[pad]

        return VStack(spacing: 0) {
            // Pad waveform
            padWaveformCanvas(pad: pad, padColor: padColor)
                .frame(height: 120)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            // Controls row
            HStack(spacing: 20) {
                // Gain fader
                VStack(spacing: 4) {
                    Text("GAIN")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text("\(state.gain)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(height: 12)

                    GeometryReader { geo in
                        let height = geo.size.height
                        let fillH = CGFloat(state.gain) / 100.0 * height

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.separatorColor).opacity(0.3))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(padColor.opacity(0.6))
                                .frame(height: fillH)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(padColor)
                                .frame(height: 4)
                                .offset(y: -(fillH - 2))
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let frac = 1.0 - (value.location.y / height)
                                    drumVM.setPadGain(pad, Int(max(0, min(1, frac)) * 100))
                                }
                        )
                    }
                    .frame(width: 24, height: 100)
                }

                // Pitch Coarse
                VStack(spacing: 4) {
                    Text("SEMI")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(state.pitchSemitones >= 0 ? "+\(state.pitchSemitones)" : "\(state.pitchSemitones)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 44, height: 24)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(4)

                    HStack(spacing: 4) {
                        Button(action: { drumVM.setPadPitch(pad, state.pitchSemitones - 1) }) {
                            Text("-")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 28, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: { drumVM.setPadPitch(pad, state.pitchSemitones + 1) }) {
                            Text("+")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 28, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button("0") { drumVM.setPadPitch(pad, 0) }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                // Pitch Fine (cents)
                VStack(spacing: 4) {
                    Text("CENTS")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    PanKnobView(
                        value: state.pitchCents * 2,
                        color: padColor,
                        onChange: { newVal in
                            drumVM.setPadCents(pad, newVal / 2)
                        }
                    )
                    .frame(width: 36, height: 48)
                    .onTapGesture(count: 2) { drumVM.setPadCents(pad, 0) }

                    Text(state.pitchCents >= 0 ? "+\(state.pitchCents)c" : "\(state.pitchCents)c")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Divider().frame(height: 100)

                // Start / End
                VStack(spacing: 8) {
                    Text("RANGE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: 8) {
                        VStack(spacing: 2) {
                            Text("START")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                            numericField(value: state.sampleStart, onChange: { drumVM.setPadStart(pad, $0) })
                        }
                        VStack(spacing: 2) {
                            Text("END")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                            numericField(value: state.sampleEnd, onChange: { drumVM.setPadEnd(pad, $0) })
                        }
                    }
                }

                Divider().frame(height: 100)

                // Mode
                VStack(spacing: 8) {
                    Text("MODE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Button(action: { drumVM.setPadOneShot(pad, !state.oneShot) }) {
                        Text(state.oneShot ? "ONE SHOT" : "GATE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .frame(width: 72, height: 24)
                            .background(state.oneShot ? Color.orange.opacity(0.7) : Color(.controlBackgroundColor))
                            .foregroundStyle(state.oneShot ? .white : AppTheme.textSecondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Pad Waveform Canvas

    private func padWaveformCanvas(pad: Int, padColor: Color) -> some View {
        let peaks = track.drumPads[pad].waveformPeaks
        let padParams = track.drumPads[pad].params

        return Canvas { context, size in
            guard !peaks.isEmpty else {
                let text = Text("Pad \(pad + 1) - No sample")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }

            let count = peaks.count
            let barWidth = size.width / CGFloat(count)
            let midY = size.height / 2

            // Draw waveform bars (mirrored)
            for i in 0..<count {
                let amplitude = CGFloat(peaks[i]) / 255.0
                let barH = amplitude * midY * 0.9
                let x = CGFloat(i) * barWidth

                var barPath = Path()
                barPath.addRect(CGRect(x: x, y: midY - barH, width: max(barWidth - 0.5, 1), height: barH * 2))

                context.fill(barPath, with: .color(padColor.opacity(0.8)))
            }

            // Center line
            var centerLine = Path()
            centerLine.move(to: CGPoint(x: 0, y: midY))
            centerLine.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(centerLine, with: .color(AppTheme.textSecondary.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5))
        }
        .background(Color(.textBackgroundColor).opacity(0.3))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppTheme.border.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Numeric Field

    private func numericField(value: Int, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 2) {
            Button(action: { onChange(max(value - 1, 0)) }) {
                Image(systemName: "minus")
                    .font(.system(size: 8))
                    .frame(width: 16, height: 20)
            }
            .buttonStyle(.plain)

            Text("\(value)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 48, height: 20)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(3)

            Button(action: { onChange(value + 1) }) {
                Image(systemName: "plus")
                    .font(.system(size: 8))
                    .frame(width: 16, height: 20)
            }
            .buttonStyle(.plain)
        }
    }
}
