import SwiftUI

struct SynthEngineView: View {
    let track: TrackState
    @Bindable var viewModel: SynthEngineViewModel

    private static let trackColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    private var trackColor: Color {
        Self.trackColors[track.index % Self.trackColors.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("MULTI ENGINE")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()

                // Voice count picker: MONO / 4-VOICE
                Picker("", selection: Binding(
                    get: { viewModel.voiceCount },
                    set: { viewModel.setVoiceCount($0) }
                )) {
                    Text("MONO").tag(1)
                    Text("4-VOICE").tag(4)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Button("Sync") { viewModel.requestParams() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Engine selector
            engineSelector
                .padding(.horizontal, 16)
                .padding(.top, 16)

            // Engine name and description
            Text(SynthEngineViewModel.engineNames[viewModel.engineModel])
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 6)
            Text(SynthEngineViewModel.engineDescriptions[viewModel.engineModel])
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.top, 2)

            Divider()
                .padding(.top, 12)

            // Three large knobs
            HStack(spacing: 40) {
                SynthKnobView(
                    label: "TIMBRE",
                    value: viewModel.timbre,
                    color: trackColor,
                    onChange: { viewModel.setTimbre(value: $0) },
                    onReset: { viewModel.setTimbre(value: 500) }
                )

                SynthKnobView(
                    label: "HARMONICS",
                    value: viewModel.harmonics,
                    color: trackColor,
                    onChange: { viewModel.setHarmonics(value: $0) },
                    onReset: { viewModel.setHarmonics(value: 500) }
                )

                SynthKnobView(
                    label: "MORPH",
                    value: viewModel.morph,
                    color: trackColor,
                    onChange: { viewModel.setMorph(value: $0) },
                    onReset: { viewModel.setMorph(value: 500) }
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)

            // DX7 Patch Browser — only shown for 6-OP FM engines (18, 19, 20)
            if viewModel.is6OpFM {
                Divider()
                dx7PatchSection
            }

            Spacer()
        }
        .onAppear {
            viewModel.trackIndex = track.index
            viewModel.requestParams()
        }
        .onChange(of: track.index) { _, newValue in
            viewModel.trackIndex = newValue
            viewModel.requestParams()
        }
    }

    // MARK: - DX7 Patch Browser

    private var dx7PatchSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DX7 PATCHES")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(.sRGB, red: 0.85, green: 0.65, blue: 0.13))

                Spacer()

                if viewModel.dx7Loaded {
                    Button("Clear Patch") {
                        viewModel.clearDX7Patch()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button("Browse .syx") {
                    viewModel.requestDX7List()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            // File picker (shown when files are available)
            if !viewModel.dx7Files.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(viewModel.dx7Files, id: \.self) { file in
                            Button(action: { viewModel.requestDX7Patches(filename: file) }) {
                                Text(file)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(viewModel.currentDX7File == file ? .white : AppTheme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(viewModel.currentDX7File == file ? trackColor.opacity(0.6) : Color(.controlBackgroundColor))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 4)
            }

            // Patch list (shown when a .syx file is selected)
            if !viewModel.dx7PatchNames.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(viewModel.dx7PatchNames.enumerated()), id: \.offset) { index, name in
                            Button(action: { viewModel.loadDX7Patch(patchIndex: index) }) {
                                HStack(spacing: 8) {
                                    Text(String(format: "%02d", index + 1))
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                                        .frame(width: 22)

                                    Text(name)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(viewModel.dx7SelectedPatch == index ? .white : AppTheme.textPrimary)

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(viewModel.dx7SelectedPatch == index ? trackColor.opacity(0.5) : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(.controlBackgroundColor).opacity(0.3))
                .cornerRadius(4)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Engine Selector

    private var engineSelector: some View {
        HStack(alignment: .top, spacing: 8) {
            // Column 1: Oscillator Models (0-7)
            engineColumn(
                title: "Oscillator Models",
                titleColor: .green,
                indices: Array(0..<8)
            )

            // Column 2: Noise/Physical (8-15)
            engineColumn(
                title: "Noise/Physical",
                titleColor: .pink,
                indices: Array(8..<16)
            )

            // Column 3: Synthesis Engines (16-23)
            engineColumn(
                title: "Synthesis Engines",
                titleColor: Color(.sRGB, red: 0.85, green: 0.65, blue: 0.13), // gold/amber
                indices: Array(16..<24)
            )
        }
    }

    private func engineColumn(title: String, titleColor: Color, indices: [Int]) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(titleColor)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)

            ForEach(indices, id: \.self) { idx in
                engineButton(index: idx)
            }
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppTheme.border.opacity(0.3), lineWidth: 1)
        )
    }

    private func engineButton(index: Int) -> some View {
        Button(action: { viewModel.setEngine(model: index) }) {
            Text(SynthEngineViewModel.engineShort[index])
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(viewModel.engineModel == index ? .white : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(viewModel.engineModel == index ? trackColor.opacity(0.7) : Color(.controlBackgroundColor))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Synth Knob (unipolar 0-1000)

/// Unipolar knob: 0 to 1000, center default at 500.
/// Reuses the arc/indicator pattern from PanKnobView but unipolar.
struct SynthKnobView: View {
    let label: String
    let value: Int          // 0-1000
    let color: Color
    let onChange: (Int) -> Void
    let onReset: () -> Void

    private static let startDeg: Double = 135
    private static let sweep: Double = 270

    private var currentAngle: Double {
        let norm = Double(value) / 1000.0
        return Self.startDeg + norm * Self.sweep
    }

    @GestureState private var dragStart: Int? = nil

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 4

                // Background track
                let bgPath = Path { p in
                    p.addArc(center: center, radius: radius,
                             startAngle: .degrees(Self.startDeg),
                             endAngle: .degrees(Self.startDeg + Self.sweep),
                             clockwise: false)
                }
                context.stroke(bgPath, with: .color(Color(.separatorColor).opacity(0.4)),
                              style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Value arc from start to current
                if value > 5 {
                    let valPath = Path { p in
                        p.addArc(center: center, radius: radius,
                                 startAngle: .degrees(Self.startDeg),
                                 endAngle: .degrees(currentAngle),
                                 clockwise: false)
                    }
                    context.stroke(valPath, with: .color(color.opacity(0.8)),
                                  style: StrokeStyle(lineWidth: 3, lineCap: .round))
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
                              style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                // Center dot
                let dotRect = CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.4)))
            }
            .frame(width: 56, height: 56)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($dragStart) { _, state, _ in
                        if state == nil { state = value }
                    }
                    .onChanged { drag in
                        let start = dragStart ?? value
                        // Vertical drag: up = increase, down = decrease
                        let delta = -drag.translation.height * 3
                        let newVal = Int(max(0, min(1000, Double(start) + delta)))
                        onChange(newVal)
                    }
            )
            .onTapGesture(count: 2) { onReset() }

            Text("\(value)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}
