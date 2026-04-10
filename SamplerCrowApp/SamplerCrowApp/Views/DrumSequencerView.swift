import SwiftUI

struct DrumSequencerView: View {
    let track: TrackState
    @Bindable var clipVM: ClipEditorViewModel

    private static let padColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    private static let trackColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    private var trackColor: Color {
        Self.trackColors[track.index % Self.trackColors.count]
    }

    private let cellSize: CGFloat = 24
    private let cellGap: CGFloat = 2
    private let labelWidth: CGFloat = 60

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            // Sequencer grid
            sequencerGrid
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            // Velocity editor for selected step
            velocityEditor
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Spacer()
        }
        .onAppear {
            clipVM.trackIndex = track.index
            clipVM.requestClipData()
        }
        .onChange(of: track.index) { _, newValue in
            clipVM.trackIndex = newValue
            clipVM.requestClipData()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("SEQUENCER")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            // Step count selector
            HStack(spacing: 0) {
                ForEach([8, 16, 32, 64], id: \.self) { count in
                    Button(action: { clipVM.setStepCount(count) }) {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(clipVM.stepCount == count ? .white : AppTheme.textSecondary)
                            .frame(width: 36, height: 24)
                            .background(clipVM.stepCount == count ? trackColor.opacity(0.7) : Color(.controlBackgroundColor))
                    }
                    .buttonStyle(.plain)
                }
            }
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppTheme.border.opacity(0.3), lineWidth: 1)
            )

            Button("Sync") {
                clipVM.requestClipData()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Sequencer Grid

    private var sequencerGrid: some View {
        HStack(alignment: .top, spacing: 0) {
            // Pad labels column
            VStack(spacing: cellGap) {
                ForEach(0..<8, id: \.self) { padIdx in
                    let padName = track.drumPads[padIdx].sampleName.isEmpty
                        ? "Pad \(padIdx + 1)"
                        : track.drumPads[padIdx].sampleName
                    Text(padName)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Self.padColors[padIdx])
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: labelWidth, height: cellSize, alignment: .trailing)
                }
            }
            .padding(.trailing, 4)

            // Scrollable grid
            ScrollView(.horizontal, showsIndicators: true) {
                Canvas { context, size in
                    let steps = clipVM.stepCount
                    let totalWidth = CGFloat(steps) * (cellSize + cellGap)

                    // Draw grid cells
                    for padIdx in 0..<8 {
                        let y = CGFloat(padIdx) * (cellSize + cellGap)

                        for step in 0..<steps {
                            let x = CGFloat(step) * (cellSize + cellGap)
                            let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)

                            // Background
                            let isPlayhead = step == clipVM.currentPlayStep
                            let bgColor: Color = isPlayhead
                                ? Color.white.opacity(0.1)
                                : (step % 4 == 0 ? Color(.separatorColor).opacity(0.15) : Color(.separatorColor).opacity(0.08))
                            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(bgColor))

                            // Active cell
                            let stepData = clipVM.steps[step]
                            if stepData.isActive && stepData.padIndex == padIdx {
                                let velOpacity = Double(stepData.velocity) / 127.0
                                let padColor = Self.padColors[padIdx]
                                context.fill(
                                    Path(roundedRect: rect, cornerRadius: 3),
                                    with: .color(padColor.opacity(0.3 + velOpacity * 0.7))
                                )
                            }

                            // Selected step border
                            if let sel = clipVM.selectedStep, sel == step {
                                context.stroke(
                                    Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 3),
                                    with: .color(Color.white.opacity(0.6)),
                                    style: StrokeStyle(lineWidth: 1.5)
                                )
                            }
                        }
                    }

                    // Playhead line
                    if clipVM.currentPlayStep >= 0 && clipVM.currentPlayStep < steps {
                        let phX = CGFloat(clipVM.currentPlayStep) * (cellSize + cellGap) + cellSize / 2
                        var phLine = Path()
                        phLine.move(to: CGPoint(x: phX, y: 0))
                        phLine.addLine(to: CGPoint(x: phX, y: size.height))
                        context.stroke(phLine, with: .color(Color.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1))
                    }
                }
                .frame(
                    width: CGFloat(clipVM.stepCount) * (cellSize + cellGap),
                    height: 8 * (cellSize + cellGap) - cellGap
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let step = Int(value.location.x / (cellSize + cellGap))
                            let padIdx = Int(value.location.y / (cellSize + cellGap))
                            guard step >= 0 && step < clipVM.stepCount && padIdx >= 0 && padIdx < 8 else { return }
                            clipVM.selectedStep = step
                            clipVM.toggleStep(step, padIndex: padIdx)
                        }
                )
            }
        }
    }

    // MARK: - Velocity Editor

    private var velocityEditor: some View {
        HStack(spacing: 12) {
            if let step = clipVM.selectedStep, clipVM.steps[step].isActive {
                let stepData = clipVM.steps[step]
                Text("STEP \(step + 1)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)

                if stepData.padIndex >= 0 && stepData.padIndex < 8 {
                    Text("Pad \(stepData.padIndex + 1)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Self.padColors[stepData.padIndex])
                }

                Text("VEL")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)

                Slider(
                    value: Binding(
                        get: { Double(stepData.velocity) },
                        set: { clipVM.setStepVelocity(step, Int($0)) }
                    ),
                    in: 1...127,
                    step: 1
                )
                .frame(width: 200)
                .tint(trackColor)

                Text("\(stepData.velocity)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 32)
            } else {
                Text("Click a cell to add/remove a step")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
            }

            Spacer()
        }
    }
}
