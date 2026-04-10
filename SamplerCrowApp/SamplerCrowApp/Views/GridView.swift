import SwiftUI

struct GridView: View {
    @Bindable var viewModel: GridViewModel

    private let padSize: CGFloat = 52
    private let padGap: CGFloat = 4
    private let padRadius: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with transport
            HStack {
                Button(viewModel.isPlaying ? "Stop" : "Play") {
                    viewModel.togglePlayStop()
                }
                .buttonStyle(.bordered)
                .tint(viewModel.isPlaying ? .red : .green)

                Text("Sequencer")
                    .font(AppTheme.monoFont)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Button("Request Grid") {
                    viewModel.requestGridState()
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    viewModel.clearGrid()
                }
                .buttonStyle(.bordered)
            }
            .padding(8)

            Divider()

            // 8x8 Grid
            Canvas { context, size in
                drawGrid(context: context, size: size)
            }
            .frame(
                width: CGFloat(8) * (padSize + padGap) + padGap,
                height: CGFloat(8) * (padSize + padGap) + padGap
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let (row, col) = hitTest(point: value.location) {
                            let key = "\(row),\(col)"
                            if !viewModel.pressedPads.contains(key) {
                                viewModel.pressedPads.insert(key)
                                viewModel.padPressed(row: row, col: col)
                            }
                        }
                    }
                    .onEnded { value in
                        if let (row, col) = hitTest(point: value.location) {
                            viewModel.padReleased(row: row, col: col)
                        }
                        viewModel.pressedPads.removeAll()
                    }
            )
            .padding(16)
            .popover(
                isPresented: Binding(
                    get: { viewModel.selectedStep != nil },
                    set: { if !$0 { viewModel.selectedStep = nil } }
                ),
                arrowEdge: .bottom
            ) {
                StepEditPopover(viewModel: viewModel)
            }

            // Track labels
            HStack(spacing: 0) {
                Text("Tracks: 1-8 (rows) x Steps 1-8 (cols)")
                    .font(AppTheme.monoFontSmall)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("LP top row: Play | Page | Clear | BPM-/+")
                    .font(AppTheme.monoFontSmall)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        for row in 0..<8 {
            for col in 0..<8 {
                let x = padGap + CGFloat(col) * (padSize + padGap)
                let y = padGap + CGFloat(row) * (padSize + padGap)
                let rect = CGRect(x: x, y: y, width: padSize, height: padSize)
                let path = Path(roundedRect: rect, cornerRadius: padRadius)

                let key = "\(row),\(col)"
                let isPressed = viewModel.pressedPads.contains(key)
                let colorIdx = viewModel.padColors[row][col]

                let color: Color
                if isPressed {
                    color = .white
                } else if colorIdx > 0 {
                    color = PadColor.color(forVelocity: colorIdx)
                } else {
                    color = Color(.separatorColor)
                }

                context.fill(path, with: .color(color))
                context.stroke(
                    path,
                    with: .color(isPressed ? .cyan : Color(.separatorColor).opacity(0.3)),
                    lineWidth: isPressed ? 2 : 0.5
                )
            }
        }
    }

    private func hitTest(point: CGPoint) -> (Int, Int)? {
        for row in 0..<8 {
            for col in 0..<8 {
                let x = padGap + CGFloat(col) * (padSize + padGap)
                let y = padGap + CGFloat(row) * (padSize + padGap)
                let rect = CGRect(x: x, y: y, width: padSize, height: padSize)
                if rect.contains(point) {
                    return (row, col)
                }
            }
        }
        return nil
    }
}
