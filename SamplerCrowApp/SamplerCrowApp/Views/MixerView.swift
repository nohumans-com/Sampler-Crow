import SwiftUI

struct MixerView: View {
    @Bindable var viewModel: MixerViewModel
    private var appState: AppState { viewModel.appState }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MIXER")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("Sync") { viewModel.requestMixerState() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            HStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { track in
                    ChannelStripView(
                        track: track,
                        name: MixerViewModel.trackNames[track],
                        volume: viewModel.volumes[track],
                        pan: viewModel.pans[track],
                        level: viewModel.levels[track],
                        isMuted: viewModel.mutes[track],
                        isSoloed: viewModel.solos[track],
                        onVolumeChange: { viewModel.setVolume(track, $0) },
                        onVolumeReset: { viewModel.resetVolume(track) },
                        onPanChange: { viewModel.setPan(track, $0) },
                        onPanReset: { viewModel.resetPan(track) },
                        onMute: { viewModel.toggleMute(track) },
                        onSolo: { viewModel.toggleSolo(track) },
                        onNameTap: {
                            appState.selectedTrackIndex = track
                            appState.selectedTab = .trackEdit
                            Task { try? await appState.serialService.send("FOCUS:\(track)") }
                        }
                    )
                    if track < 7 { Divider() }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.requestMixerState()
            viewModel.startLevelPolling()
        }
        .onDisappear {
            viewModel.stopLevelPolling()
        }
    }
}

struct ChannelStripView: View {
    let track: Int
    let name: String
    let volume: Int
    let pan: Int        // -100 to +100
    let level: Int      // 0-100 from peak meter
    let isMuted: Bool
    let isSoloed: Bool
    let onVolumeChange: (Int) -> Void
    let onVolumeReset: () -> Void
    let onPanChange: (Int) -> Void
    let onPanReset: () -> Void
    let onMute: () -> Void
    let onSolo: () -> Void
    var onNameTap: (() -> Void)? = nil

    private static let trackColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    var body: some View {
        VStack(spacing: 5) {
            // Track name (clickable → opens track editor)
            Text(name)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(isMuted ? AppTheme.textSecondary.opacity(0.4) : AppTheme.textPrimary)
                .frame(height: 16)
                .underline(true, color: AppTheme.textSecondary.opacity(0.3))
                .onTapGesture { onNameTap?() }

            // Pan knob (bipolar: -100 to +100, 0=center)
            PanKnobView(value: pan, color: faderColor, onChange: onPanChange)
                .frame(width: 36, height: 48)
                .onTapGesture(count: 2) { onPanReset() }

            // Volume display
            Text("\(volume)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(height: 12)

            // Fader + meter side by side
            HStack(spacing: 3) {
                // Level meter
                GeometryReader { geo in
                    let height = geo.size.height
                    let meterH = CGFloat(level) / 100.0 * height

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.separatorColor).opacity(0.2))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(meterColor)
                            .frame(height: meterH)
                    }
                }
                .frame(width: 5)

                // Volume fader
                GeometryReader { geo in
                    let height = geo.size.height
                    let fillH = CGFloat(volume) / 100.0 * height

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.separatorColor).opacity(0.3))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(faderColor.opacity(isMuted ? 0.15 : 0.6))
                            .frame(height: fillH)
                        // Thumb
                        RoundedRectangle(cornerRadius: 1)
                            .fill(faderColor)
                            .frame(height: 4)
                            .offset(y: -(fillH - 2))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let frac = 1.0 - (value.location.y / height)
                                onVolumeChange(Int(max(0, min(1, frac)) * 100))
                            }
                    )
                    .onTapGesture(count: 2) { onVolumeReset() }
                }
                .frame(width: 24)
            }

            // Mute
            Button(action: onMute) {
                Text("M")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(width: 28, height: 22)
                    .background(isMuted ? Color.red.opacity(0.8) : Color(.controlBackgroundColor))
                    .foregroundStyle(isMuted ? .white : AppTheme.textSecondary)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)

            // Solo
            Button(action: onSolo) {
                Text("S")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(width: 28, height: 22)
                    .background(isSoloed ? Color.yellow.opacity(0.8) : Color(.controlBackgroundColor))
                    .foregroundStyle(isSoloed ? .black : AppTheme.textSecondary)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
    }

    private var faderColor: Color { Self.trackColors[track] }

    private var meterColor: Color {
        if level > 90 { return .red }
        if level > 70 { return .yellow }
        return .green
    }
}

/// Bipolar pan knob: -100 (L) to +100 (R), 0 = center.
/// Gap at bottom (6 o'clock). Indicator at 12 o'clock = center.
struct PanKnobView: View {
    let value: Int       // -100 to +100
    let color: Color
    let onChange: (Int) -> Void

    // SwiftUI angles: 0°=3 o'clock, 90°=6 o'clock, CW on screen
    // Knob: 270° sweep, gap at bottom
    // Full L = 135° (7:30), Center = 270° (12:00), Full R = 405°/45° (4:30)
    private static let startDeg: Double = 135
    private static let sweep: Double = 270

    // Map -100..+100 → angle
    private var currentAngle: Double {
        let norm = (Double(value) + 100.0) / 200.0  // 0..1
        return Self.startDeg + norm * Self.sweep
    }

    // Center angle (pan=0)
    private static let centerAngle: Double = startDeg + sweep / 2  // 270°

    private var panLabel: String {
        if value < -5 { return "L\(-value)" }
        if value > 5 { return "R\(value)" }
        return "C"
    }

    @GestureState private var dragStart: Int? = nil

    var body: some View {
        VStack(spacing: 2) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.width / 2)
                let radius = min(size.width, size.width) / 2 - 3

                // Background track (full sweep)
                let bgPath = Path { p in
                    p.addArc(center: center, radius: radius,
                             startAngle: .degrees(Self.startDeg),
                             endAngle: .degrees(Self.startDeg + Self.sweep),
                             clockwise: false)
                }
                context.stroke(bgPath, with: .color(Color(.separatorColor).opacity(0.4)),
                              style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                // Value arc: from center (270°) to current position
                let valStart = min(Self.centerAngle, currentAngle)
                let valEnd = max(Self.centerAngle, currentAngle)
                if abs(value) > 2 {
                    let valPath = Path { p in
                        p.addArc(center: center, radius: radius,
                                 startAngle: .degrees(valStart),
                                 endAngle: .degrees(valEnd),
                                 clockwise: false)
                    }
                    context.stroke(valPath, with: .color(color.opacity(0.8)),
                                  style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }

                // Indicator line
                let rad = currentAngle * .pi / 180.0
                let innerR = radius * 0.35
                let outerR = radius * 0.9
                var linePath = Path()
                linePath.move(to: CGPoint(x: center.x + cos(rad) * innerR,
                                          y: center.y + sin(rad) * innerR))
                linePath.addLine(to: CGPoint(x: center.x + cos(rad) * outerR,
                                             y: center.y + sin(rad) * outerR))
                context.stroke(linePath, with: .color(color),
                              style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Center dot
                let dotRect = CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)
                context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.4)))
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($dragStart) { _, state, _ in
                        if state == nil { state = value }
                    }
                    .onChanged { drag in
                        let start = dragStart ?? value
                        // Linear horizontal drag: right = more positive, left = more negative
                        let delta = drag.translation.width * 1.5
                        let newVal = Int(max(-100, min(100, Double(start) + delta)))
                        onChange(newVal)
                    }
            )

            Text(panLabel)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}
