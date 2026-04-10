import SwiftUI

struct SamplerView: View {
    let track: TrackState
    @Bindable var samplerVM: SamplerViewModel
    let appState: AppState

    private static let trackColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    private var trackColor: Color {
        Self.trackColors[track.index % Self.trackColors.count]
    }

    private var state: SamplerState { track.samplerState }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.sampleName.isEmpty ? "No sample" : state.sampleName)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                    if !state.samplePath.isEmpty {
                        Text(state.samplePath)
                            .font(AppTheme.monoFontSmall)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()

                Button("Browse") {
                    appState.selectedTab = .samples
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Sync") {
                    samplerVM.requestParams()
                    samplerVM.requestWaveform()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Mode picker
            HStack {
                Picker("Mode", selection: Binding(
                    get: { state.samplerMode },
                    set: { samplerVM.setMode($0) }
                )) {
                    Text("Pitch").tag(0)
                    Text("Grain").tag(1)
                    Text("Chop").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            Divider()

            // Waveform display
            waveformCanvas
                .frame(height: 200)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            // Controls section — switches by mode
            switch state.samplerMode {
            case 1:
                grainControls
            case 2:
                chopControls
            default:
                pitchControls
            }

            Spacer()
        }
        .onAppear {
            samplerVM.trackIndex = track.index
            samplerVM.requestParams()
            samplerVM.requestWaveform()
        }
        .onChange(of: track.index) { _, newValue in
            samplerVM.trackIndex = newValue
            samplerVM.requestParams()
            samplerVM.requestWaveform()
        }
    }

    // MARK: - Waveform Canvas

    private var waveformCanvas: some View {
        Canvas { context, size in
            let peaks = state.waveformPeaks
            guard !peaks.isEmpty else {
                let text = Text("No sample loaded")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }

            let count = peaks.count
            let barWidth = size.width / CGFloat(count)
            let midY = size.height / 2

            // Mode-specific overlays drawn before waveform
            switch state.samplerMode {
            case 1:
                // Grain mode: show grain window as highlighted region
                drawGrainOverlay(context: context, size: size, count: count)
            case 2:
                // Chop mode: draw slice boundary lines
                drawChopOverlay(context: context, size: size, count: count)
            default:
                // Pitch mode: trim + loop markers
                drawPitchOverlay(context: context, size: size, count: count)
            }

            // Draw waveform bars (mirrored)
            for i in 0..<count {
                let amplitude = CGFloat(peaks[i]) / 255.0
                let barH = amplitude * midY * 0.9
                let x = CGFloat(i) * barWidth

                var barPath = Path()
                barPath.addRect(CGRect(x: x, y: midY - barH, width: max(barWidth - 0.5, 1), height: barH * 2))

                context.fill(barPath, with: .color(trackColor.opacity(0.8)))
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

    private func drawPitchOverlay(context: GraphicsContext, size: CGSize, count: Int) {
        // Start trim overlay
        if state.sampleStart > 0 {
            let trimX = CGFloat(state.sampleStart) / CGFloat(count) * size.width
            let trimRect = CGRect(x: 0, y: 0, width: trimX, height: size.height)
            context.fill(Path(trimRect), with: .color(Color.gray.opacity(0.4)))
        }

        // End trim overlay
        if state.sampleEnd > 0 && state.sampleEnd < count {
            let trimX = CGFloat(state.sampleEnd) / CGFloat(count) * size.width
            let trimRect = CGRect(x: trimX, y: 0, width: size.width - trimX, height: size.height)
            context.fill(Path(trimRect), with: .color(Color.gray.opacity(0.4)))
        }

        // Loop region highlight
        if state.loopEnabled && state.loopEnd > state.loopStart {
            let lsX = CGFloat(state.loopStart) / CGFloat(count) * size.width
            let leX = CGFloat(state.loopEnd) / CGFloat(count) * size.width
            let loopRect = CGRect(x: lsX, y: 0, width: leX - lsX, height: size.height)
            context.fill(Path(loopRect), with: .color(trackColor.opacity(0.15)))

            var lsLine = Path()
            lsLine.move(to: CGPoint(x: lsX, y: 0))
            lsLine.addLine(to: CGPoint(x: lsX, y: size.height))
            context.stroke(lsLine, with: .color(trackColor.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

            var leLine = Path()
            leLine.move(to: CGPoint(x: leX, y: 0))
            leLine.addLine(to: CGPoint(x: leX, y: size.height))
            context.stroke(leLine, with: .color(trackColor.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
    }

    private func drawGrainOverlay(context: GraphicsContext, size: CGSize, count: Int) {
        let posNorm = CGFloat(state.grainPosition) / 100.0
        let winNorm = CGFloat(state.grainWindowSize) / 100.0
        let centerX = posNorm * size.width
        let halfW = (winNorm / 2.0) * size.width
        let leftX = max(0, centerX - halfW)
        let rightX = min(size.width, centerX + halfW)

        // Dim regions outside the grain window
        if leftX > 0 {
            let dimRect = CGRect(x: 0, y: 0, width: leftX, height: size.height)
            context.fill(Path(dimRect), with: .color(Color.gray.opacity(0.35)))
        }
        if rightX < size.width {
            let dimRect = CGRect(x: rightX, y: 0, width: size.width - rightX, height: size.height)
            context.fill(Path(dimRect), with: .color(Color.gray.opacity(0.35)))
        }

        // Grain window highlight
        let winRect = CGRect(x: leftX, y: 0, width: rightX - leftX, height: size.height)
        context.fill(Path(winRect), with: .color(Color.cyan.opacity(0.12)))

        // Grain window boundary lines
        var leftLine = Path()
        leftLine.move(to: CGPoint(x: leftX, y: 0))
        leftLine.addLine(to: CGPoint(x: leftX, y: size.height))
        context.stroke(leftLine, with: .color(Color.cyan.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))

        var rightLine = Path()
        rightLine.move(to: CGPoint(x: rightX, y: 0))
        rightLine.addLine(to: CGPoint(x: rightX, y: size.height))
        context.stroke(rightLine, with: .color(Color.cyan.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))

        // Center position line (solid)
        var centerLine = Path()
        centerLine.move(to: CGPoint(x: centerX, y: 0))
        centerLine.addLine(to: CGPoint(x: centerX, y: size.height))
        context.stroke(centerLine, with: .color(Color.cyan.opacity(0.9)), style: StrokeStyle(lineWidth: 1.5))
    }

    private func drawChopOverlay(context: GraphicsContext, size: CGSize, count: Int) {
        guard !state.chopSliceBoundaries.isEmpty else { return }
        let maxSample = state.sampleEnd > 0 ? state.sampleEnd : count

        for boundary in state.chopSliceBoundaries {
            let x = CGFloat(boundary) / CGFloat(maxSample) * size.width
            var sliceLine = Path()
            sliceLine.move(to: CGPoint(x: x, y: 0))
            sliceLine.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(sliceLine, with: .color(Color.orange.opacity(0.8)), style: StrokeStyle(lineWidth: 1))
        }
    }

    // MARK: - Pitch Mode Controls

    private var pitchControls: some View {
        VStack(spacing: 0) {
            // Main controls row
            HStack(spacing: 20) {
                // Gain fader
                gainFader

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
                        Button(action: { samplerVM.setPitch(state.pitchSemitones - 1) }) {
                            Text("-")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 28, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: { samplerVM.setPitch(state.pitchSemitones + 1) }) {
                            Text("+")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 28, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button("0") { samplerVM.setPitch(0) }
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
                        color: trackColor,
                        onChange: { newVal in
                            samplerVM.setCents(newVal / 2)
                        }
                    )
                    .frame(width: 36, height: 48)
                    .onTapGesture(count: 2) { samplerVM.setCents(0) }

                    Text(state.pitchCents >= 0 ? "+\(state.pitchCents)c" : "\(state.pitchCents)c")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Divider().frame(height: 120)

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
                            numericField(value: state.sampleStart, onChange: { samplerVM.setStart($0) })
                        }
                        VStack(spacing: 2) {
                            Text("END")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                            numericField(value: state.sampleEnd, onChange: { samplerVM.setEnd($0) })
                        }
                    }
                }

                Divider().frame(height: 120)

                // Loop controls
                VStack(spacing: 8) {
                    Text("LOOP")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Button(action: { samplerVM.setLoop(!state.loopEnabled) }) {
                        Text(state.loopEnabled ? "LOOP ON" : "LOOP OFF")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .frame(width: 72, height: 24)
                            .background(state.loopEnabled ? trackColor.opacity(0.7) : Color(.controlBackgroundColor))
                            .foregroundStyle(state.loopEnabled ? .white : AppTheme.textSecondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    if state.loopEnabled {
                        HStack(spacing: 8) {
                            VStack(spacing: 2) {
                                Text("L.START")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AppTheme.textSecondary)
                                numericField(value: state.loopStart, onChange: { samplerVM.setLoopStart($0) })
                            }
                            VStack(spacing: 2) {
                                Text("L.END")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AppTheme.textSecondary)
                                numericField(value: state.loopEnd, onChange: { samplerVM.setLoopEnd($0) })
                            }
                        }
                    }
                }

                Divider().frame(height: 120)

                // Mode (one-shot / gate)
                VStack(spacing: 8) {
                    Text("MODE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Button(action: { samplerVM.setOneShot(!state.oneShot) }) {
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

            Divider()

            // Root note + ADSR row
            HStack(spacing: 20) {
                // Root Note
                VStack(spacing: 4) {
                    Text("ROOT NOTE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(SamplerViewModel.noteName(state.rootNote))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 48, height: 24)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(4)

                    HStack(spacing: 4) {
                        Button(action: { samplerVM.setRootNote(state.rootNote - 1) }) {
                            Text("-")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 28, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: { samplerVM.setRootNote(state.rootNote + 1) }) {
                            Text("+")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 28, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Divider().frame(height: 100)

                // ADSR envelope
                VStack(spacing: 4) {
                    Text("ENVELOPE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: 12) {
                        adsrFader(label: "A", value: state.attackMs, max: 500, unit: "ms") { samplerVM.setAttack($0) }
                        adsrFader(label: "D", value: state.decayMs, max: 500, unit: "ms") { samplerVM.setDecay($0) }
                        adsrFader(label: "S", value: state.sustainLevel, max: 100, unit: "%") { samplerVM.setSustain($0) }
                        adsrFader(label: "R", value: state.releaseMs, max: 500, unit: "ms") { samplerVM.setRelease($0) }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Grain Mode Controls

    private var grainControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                // Gain fader (shared)
                gainFader

                Divider().frame(height: 120)

                // Position knob
                VStack(spacing: 4) {
                    Text("POSITION")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    PanKnobView(
                        value: state.grainPosition * 2 - 100,  // map 0-100 to -100..+100
                        color: .cyan,
                        onChange: { newVal in
                            samplerVM.setGrainPosition((newVal + 100) / 2)
                        }
                    )
                    .frame(width: 36, height: 48)
                    .onTapGesture(count: 2) { samplerVM.setGrainPosition(50) }

                    Text("\(state.grainPosition)%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                // Window knob
                VStack(spacing: 4) {
                    Text("WINDOW")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    PanKnobView(
                        value: state.grainWindowSize * 2 - 100,
                        color: .cyan,
                        onChange: { newVal in
                            samplerVM.setGrainWindowSize((newVal + 100) / 2)
                        }
                    )
                    .frame(width: 36, height: 48)
                    .onTapGesture(count: 2) { samplerVM.setGrainWindowSize(30) }

                    Text("\(state.grainWindowSize)%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                // Size knob
                VStack(spacing: 4) {
                    Text("SIZE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    PanKnobView(
                        value: Int((Double(state.grainSizeMs - 10) / 490.0) * 200.0 - 100.0),
                        color: .cyan,
                        onChange: { newVal in
                            let ms = Int((Double(newVal + 100) / 200.0) * 490.0 + 10.0)
                            samplerVM.setGrainSize(ms)
                        }
                    )
                    .frame(width: 36, height: 48)
                    .onTapGesture(count: 2) { samplerVM.setGrainSize(100) }

                    Text("\(state.grainSizeMs)ms")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                // Count stepper
                VStack(spacing: 4) {
                    Text("COUNT")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text("\(state.grainCount)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 36, height: 24)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(4)

                    HStack(spacing: 4) {
                        Button(action: { samplerVM.setGrainCount(state.grainCount - 1) }) {
                            Text("-")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 24, height: 20)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: { samplerVM.setGrainCount(state.grainCount + 1) }) {
                            Text("+")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 24, height: 20)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Divider().frame(height: 120)

                // Pitch (reuse semitone pattern)
                VStack(spacing: 4) {
                    Text("PITCH")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(state.pitchSemitones >= 0 ? "+\(state.pitchSemitones)" : "\(state.pitchSemitones)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 44, height: 24)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(4)

                    HStack(spacing: 4) {
                        Button(action: { samplerVM.setPitch(state.pitchSemitones - 1) }) {
                            Text("-")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 28, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: { samplerVM.setPitch(state.pitchSemitones + 1) }) {
                            Text("+")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .frame(width: 28, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button("0") { samplerVM.setPitch(0) }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                // Spread knob
                VStack(spacing: 4) {
                    Text("SPREAD")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    PanKnobView(
                        value: state.grainSpread * 2 - 100,
                        color: .cyan,
                        onChange: { newVal in
                            samplerVM.setGrainSpread((newVal + 100) / 2)
                        }
                    )
                    .frame(width: 36, height: 48)
                    .onTapGesture(count: 2) { samplerVM.setGrainSpread(50) }

                    Text("\(state.grainSpread)%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Divider().frame(height: 120)

                // Envelope shape picker
                VStack(spacing: 4) {
                    Text("ENVELOPE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Picker("", selection: Binding(
                        get: { state.grainEnvShape },
                        set: { samplerVM.setGrainEnvShape($0) }
                    )) {
                        Text("Hann").tag(0)
                        Text("Gauss").tag(1)
                        Text("Tri").tag(2)
                        Text("Tukey").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Chop Mode Controls

    private var chopControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                // Gain fader (shared)
                gainFader

                Divider().frame(height: 120)

                // Sensitivity slider
                VStack(spacing: 4) {
                    Text("SENSITIVITY")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: 8) {
                        Text("\(state.chopSensitivity)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 32)

                        GeometryReader { geo in
                            let width = geo.size.width
                            let fillW = CGFloat(state.chopSensitivity) / 100.0 * width

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.separatorColor).opacity(0.3))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.orange.opacity(0.6))
                                    .frame(width: fillW)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let frac = value.location.x / width
                                        samplerVM.setChopSensitivity(Int(max(0, min(1, frac)) * 100))
                                    }
                            )
                        }
                        .frame(width: 160, height: 20)
                    }
                }

                Divider().frame(height: 120)

                // Trigger mode
                VStack(spacing: 4) {
                    Text("TRIG MODE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Picker("", selection: Binding(
                        get: { state.chopTriggerMode },
                        set: { samplerVM.setChopTriggerMode($0) }
                    )) {
                        Text("Trigger").tag(0)
                        Text("Gate").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Slice grid
            VStack(alignment: .leading, spacing: 8) {
                Text("\(state.chopSliceCount) slices detected")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)

                if !state.chopSliceBoundaries.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.fixed(40)),
                            GridItem(.fixed(60)),
                            GridItem(.flexible())
                        ], alignment: .leading, spacing: 4) {
                            // Header
                            Text("#")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("NOTE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("POSITION")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)

                            // Rows
                            ForEach(Array(state.chopSliceBoundaries.enumerated()), id: \.offset) { idx, boundary in
                                Text("\(idx + 1)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(SamplerViewModel.noteName(36 + idx))  // Start from C2
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(trackColor)
                                Text("\(boundary)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Shared Components

    private var gainFader: some View {
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
                        .fill(trackColor.opacity(0.6))
                        .frame(height: fillH)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(trackColor)
                        .frame(height: 4)
                        .offset(y: -(fillH - 2))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let frac = 1.0 - (value.location.y / height)
                            samplerVM.setGain(Int(max(0, min(1, frac)) * 100))
                        }
                )
            }
            .frame(width: 24, height: 120)
        }
    }

    private func adsrFader(label: String, value: Int, max maxVal: Int, unit: String, onChange: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)

            GeometryReader { geo in
                let height = geo.size.height
                let fillH = CGFloat(value) / CGFloat(maxVal) * height

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.separatorColor).opacity(0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(trackColor.opacity(0.5))
                        .frame(height: fillH)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(trackColor)
                        .frame(height: 3)
                        .offset(y: -(fillH - 1.5))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { dragValue in
                            let frac = 1.0 - (dragValue.location.y / height)
                            onChange(Int(Swift.max(0, Swift.min(1, frac)) * CGFloat(maxVal)))
                        }
                )
            }
            .frame(width: 18, height: 80)

            Text("\(value)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)

            Text(unit)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
        }
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
