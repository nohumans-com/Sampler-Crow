import SwiftUI

struct ArrangementView: View {
    let appState: AppState
    @Bindable var viewModel: ArrangementViewModel
    @Binding var selectedTrackIndex: Int?
    var onEditClip: ((Int) -> Void)?     // callback to switch to SEQ tab

    private static let trackColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    private let trackLaneHeight: CGFloat = 44
    private let barWidth: CGFloat = 80
    private let totalBars = 32               // visible arrangement length
    private let rulerHeight: CGFloat = 24

    private var zoom: CGFloat { viewModel.horizontalZoom }
    private var totalWidth: CGFloat { CGFloat(totalBars) * barWidth * zoom }

    @State private var dragClipID: UUID?
    @State private var dragTrackIndex: Int?
    @State private var dragStartBar: Int?
    @State private var lastTapClipID: UUID?
    @State private var lastTapTime: Date = .distantPast

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            // Scrollable arrangement area (no left label column — TrackListPanel provides context)
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(spacing: 0) {
                    // Bar ruler
                    barRulerCanvas
                        .frame(width: totalWidth, height: rulerHeight)

                    Divider()

                    // Track lanes
                    ForEach(0..<8, id: \.self) { trackIdx in
                        trackLaneCanvas(trackIdx: trackIdx)
                            .frame(width: totalWidth, height: trackLaneHeight)

                        if trackIdx < 7 { Divider() }
                    }
                }
            }

            // Bottom bar: selected clip info and rename
            if let selectedID = viewModel.selectedClipID,
               let (trackIdx, clip) = findClip(id: selectedID) {
                Divider()
                HStack(spacing: 12) {
                    Text("Track \(trackIdx + 1)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    TextField("Clip name", text: Binding(
                        get: { clip.name },
                        set: { clip.name = $0 }
                    ))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .textFieldStyle(.plain)
                    .frame(width: 140)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)

                    Text("Bar \(clip.startBar + 1), \(clip.lengthBars) bar\(clip.lengthBars == 1 ? "" : "s")")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)

                    Spacer()

                    Button("Edit in Piano Roll") {
                        selectedTrackIndex = trackIdx
                        viewModel.editingClipID = clip.id
                        viewModel.editingClipTrackIndex = trackIdx
                        onEditClip?(trackIdx)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    /// Find a clip by ID across all tracks, returning the track index and clip
    private func findClip(id: UUID) -> (Int, ArrangementClip)? {
        for trackIdx in 0..<appState.tracks.count {
            if let clip = appState.tracks[trackIdx].arrangementClips.first(where: { $0.id == id }) {
                return (trackIdx, clip)
            }
        }
        return nil
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("ARRANGEMENT")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            // Zoom controls with slider
            HStack(spacing: 4) {
                Button(action: { viewModel.horizontalZoom = max(0.5, viewModel.horizontalZoom - 0.25) }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Slider(
                    value: $viewModel.horizontalZoom,
                    in: 0.5...4.0,
                    step: 0.25
                )
                .frame(width: 80)

                Button(action: { viewModel.horizontalZoom = min(4.0, viewModel.horizontalZoom + 0.25) }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Text("\(Int(zoom * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 36)
            }
        }
    }

    // MARK: - Bar Ruler

    private var barRulerCanvas: some View {
        Canvas { context, size in
            let bw = barWidth * zoom

            for bar in 0..<totalBars {
                let x = CGFloat(bar) * bw

                let text = Text("\(bar + 1)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
                context.draw(context.resolve(text), at: CGPoint(x: x + 4, y: size.height / 2), anchor: .leading)

                var line = Path()
                line.move(to: CGPoint(x: x, y: size.height - 6))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(AppTheme.border.opacity(0.5)), style: StrokeStyle(lineWidth: 1))
            }
        }
    }

    // MARK: - Track Lane

    private func trackLaneCanvas(trackIdx: Int) -> some View {
        let clips = appState.tracks[trackIdx].arrangementClips
        let color = Self.trackColors[trackIdx]

        return Canvas { context, size in
            let bw = barWidth * zoom

            // Grid lines at bar boundaries
            for bar in 0...totalBars {
                let x = CGFloat(bar) * bw
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(AppTheme.border.opacity(bar % 4 == 0 ? 0.3 : 0.1)), style: StrokeStyle(lineWidth: 0.5))
            }

            // Draw clips
            for clip in clips {
                let x = CGFloat(clip.startBar) * bw
                let w = CGFloat(clip.lengthBars) * bw
                let clipRect = CGRect(x: x + 1, y: 2, width: max(w - 2, 8), height: size.height - 4)

                context.fill(
                    Path(roundedRect: clipRect, cornerRadius: 4),
                    with: .color(color.opacity(0.5))
                )

                let nameText = Text(clip.name)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                context.draw(
                    context.resolve(nameText),
                    at: CGPoint(x: clipRect.minX + 4, y: clipRect.midY),
                    anchor: .leading
                )

                if viewModel.selectedClipID == clip.id {
                    context.stroke(
                        Path(roundedRect: clipRect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 4),
                        with: .color(Color.white.opacity(0.8)),
                        style: StrokeStyle(lineWidth: 1.5)
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in handleLaneDrag(trackIdx: trackIdx, value: value, phase: .changed) }
                .onEnded { value in handleLaneDrag(trackIdx: trackIdx, value: value, phase: .ended) }
        )
        .contextMenu {
            if let selectedID = viewModel.selectedClipID,
               appState.tracks[trackIdx].arrangementClips.contains(where: { $0.id == selectedID }) {
                Button("Duplicate") {
                    viewModel.duplicateClip(trackIndex: trackIdx, clipID: selectedID)
                }
                Button("Delete", role: .destructive) {
                    viewModel.deleteClip(trackIndex: trackIdx, clipID: selectedID)
                }
            }
        }
    }

    // MARK: - Lane Interaction

    private enum DragPhase { case changed, ended }

    private func handleLaneDrag(trackIdx: Int, value: DragGesture.Value, phase: DragPhase) {
        let bw = barWidth * zoom
        let clickBar = max(Int(value.location.x / bw), 0)

        if phase == .ended && dragClipID == nil {
            if let clip = hitTestClip(trackIdx: trackIdx, x: value.location.x) {
                let now = Date()
                // Detect double-click: same clip tapped within 0.4s
                if lastTapClipID == clip.id && now.timeIntervalSince(lastTapTime) < 0.4 {
                    // Double-click: open clip in piano roll
                    selectedTrackIndex = trackIdx
                    viewModel.selectedClipID = clip.id
                    viewModel.editingClipID = clip.id
                    viewModel.editingClipTrackIndex = trackIdx
                    onEditClip?(trackIdx)
                    lastTapClipID = nil
                    lastTapTime = .distantPast
                } else {
                    // Single click: select/deselect
                    if viewModel.selectedClipID == clip.id {
                        viewModel.selectedClipID = nil
                    } else {
                        viewModel.selectedClipID = clip.id
                    }
                    lastTapClipID = clip.id
                    lastTapTime = now
                }
            } else {
                viewModel.addClip(trackIndex: trackIdx, atBar: clickBar)
                lastTapClipID = nil
                lastTapTime = .distantPast
            }
            dragClipID = nil
            dragTrackIndex = nil
            dragStartBar = nil
            return
        }

        if phase == .changed {
            if dragClipID == nil {
                if let clip = hitTestClip(trackIdx: trackIdx, x: value.startLocation.x) {
                    dragClipID = clip.id
                    dragTrackIndex = trackIdx
                    dragStartBar = clip.startBar
                    viewModel.selectedClipID = clip.id
                } else {
                    return
                }
            }

            if let eid = dragClipID, let origBar = dragStartBar {
                let deltaBarsPx = value.translation.width
                let deltaBars = Int(deltaBarsPx / bw)
                let newBar = max(origBar + deltaBars, 0)
                viewModel.moveClip(trackIndex: trackIdx, clipID: eid, toBar: newBar)
            }
        }

        if phase == .ended {
            dragClipID = nil
            dragTrackIndex = nil
            dragStartBar = nil
        }
    }

    private func hitTestClip(trackIdx: Int, x: CGFloat) -> ArrangementClip? {
        let bw = barWidth * zoom
        for clip in appState.tracks[trackIdx].arrangementClips {
            let cx = CGFloat(clip.startBar) * bw
            let cw = CGFloat(clip.lengthBars) * bw
            if x >= cx && x < cx + cw {
                return clip
            }
        }
        return nil
    }
}
