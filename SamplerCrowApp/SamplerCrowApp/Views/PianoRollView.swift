import SwiftUI

struct PianoRollView: View {
    let track: TrackState
    @Bindable var viewModel: PianoRollViewModel

    private static let trackColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    private var trackColor: Color {
        Self.trackColors[track.index % Self.trackColors.count]
    }

    // Layout constants
    private let noteCount = 84          // C1 (24) to B6 (107) = 84 notes
    private let lowestNote = 24         // C1
    private let baseRowHeight: CGFloat = 12
    private let stepWidth: CGFloat = 20
    private let pianoKeyWidth: CGFloat = 60
    private let velocityLaneHeight: CGFloat = 60
    private let ccLaneHeight: CGFloat = 60
    private let resizeHandleWidth: CGFloat = 6

    private var rowHeight: CGFloat { baseRowHeight * viewModel.verticalZoom }
    private var totalHeight: CGFloat { CGFloat(noteCount) * rowHeight }
    private var totalWidth: CGFloat { CGFloat(viewModel.clip.lengthSteps) * stepWidth * viewModel.horizontalZoom }

    private var stepsPerBar: Int { viewModel.timeSignature.stepsPerBar }
    private var stepsPerBeat: Int { viewModel.timeSignature.stepsPerBeat }

    // Drag state
    @State private var dragMode: DragMode = .none
    @State private var dragEventID: UUID?
    @State private var dragOriginStep: Double = 0
    @State private var dragOriginNote: Int = 0

    // Multi-select drag offsets (for moving multiple notes)
    @State private var multiDragOrigins: [(id: UUID, step: Double, note: Int)] = []

    // Marquee selection
    @State private var isMarqueeSelecting = false
    @State private var marqueeStart: CGPoint = .zero
    @State private var marqueeEnd: CGPoint = .zero

    // Velocity drag
    @State private var velocityDragEventID: UUID?
    @State private var velocityDragValue: Int?

    // CC drag
    @State private var ccDragPointID: UUID?

    // Custom time signature editing
    @State private var showCustomTimeSig = false
    @State private var customNumerator: Int = 4
    @State private var customDenominator: Int = 4

    private enum DragMode {
        case none, move, resize, drawVelocity, marquee
    }

    private static let ccNames: [(Int, String)] = [
        (1, "Mod Wheel"), (7, "Volume"), (10, "Pan"), (11, "Expression"),
        (64, "Sustain"), (71, "Resonance"), (74, "Filter"), (91, "Reverb"),
        (93, "Chorus")
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            // Main editor area
            HStack(spacing: 0) {
                // Piano keys column
                pianoKeysView
                    .frame(width: pianoKeyWidth)

                Divider()

                // Grid + velocity + CC in a single ScrollView
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Note grid
                        noteGridCanvas
                            .frame(width: totalWidth, height: totalHeight)

                        Divider()

                        // Velocity lane
                        velocityCanvas
                            .frame(width: totalWidth, height: velocityLaneHeight)

                        Divider()

                        // CC automation lane
                        ccAutomationCanvas
                            .frame(width: totalWidth, height: ccLaneHeight)
                    }
                }
            }
        }
        .onAppear {
            viewModel.trackIndex = track.index
            viewModel.timeSignature = viewModel.clip.timeSignature
        }
        .onChange(of: track.index) { _, newValue in
            viewModel.trackIndex = newValue
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("PIANO ROLL")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            // Time signature menu
            timeSignatureMenu

            // Bar length menu
            barLengthMenu

            // Horizontal zoom
            horizontalZoomControls

            // Vertical zoom
            verticalZoomControls

            // Clip info
            Text("\(viewModel.clip.lengthSteps) steps")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)

            Button("Send") {
                viewModel.syncToTeensy()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var timeSignatureMenu: some View {
        Menu {
            ForEach(TimeSignature.common, id: \.0) { (label, num, den) in
                Button(label) {
                    let ts = TimeSignature(numerator: num, denominator: den)
                    viewModel.timeSignature = ts
                    viewModel.clip.timeSignature = ts
                }
            }

            Divider()

            Button("Custom...") {
                customNumerator = viewModel.timeSignature.numerator
                customDenominator = viewModel.timeSignature.denominator
                showCustomTimeSig = true
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.timeSignature.display)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(trackColor.opacity(0.6))
            .cornerRadius(4)
        }
        .popover(isPresented: $showCustomTimeSig) {
            VStack(spacing: 12) {
                Text("Custom Time Signature")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))

                HStack(spacing: 8) {
                    Stepper("Beats: \(customNumerator)", value: $customNumerator, in: 1...16)
                        .font(.system(size: 11, design: .monospaced))

                }

                HStack(spacing: 8) {
                    Text("Beat unit:")
                        .font(.system(size: 11, design: .monospaced))
                    Picker("", selection: $customDenominator) {
                        Text("4 (quarter)").tag(4)
                        Text("8 (eighth)").tag(8)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }

                Button("Apply") {
                    let ts = TimeSignature(numerator: customNumerator, denominator: customDenominator)
                    viewModel.timeSignature = ts
                    viewModel.clip.timeSignature = ts
                    showCustomTimeSig = false
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
            .frame(width: 260)
        }
    }

    private var barLengthMenu: some View {
        Menu {
            ForEach(1...16, id: \.self) { bars in
                Button("\(bars) bar\(bars == 1 ? "" : "s")") {
                    viewModel.clip.lengthBars = bars
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("Bars: \(viewModel.clip.lengthBars)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppTheme.border.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var horizontalZoomControls: some View {
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
            .frame(width: 60)

            Button(action: { viewModel.horizontalZoom = min(4.0, viewModel.horizontalZoom + 0.25) }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)

            Text("\(Int(viewModel.horizontalZoom * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 36)
        }
    }

    private var verticalZoomControls: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.and.down")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)

            Slider(
                value: $viewModel.verticalZoom,
                in: 0.67...1.67,   // ~8px to ~20px row height
                step: 0.1
            )
            .frame(width: 40)
        }
    }

    // MARK: - Piano Keys (realistic layout)

    private static let blackKeyNotes: Set<Int> = [1, 3, 6, 8, 10]  // C#, D#, F#, G#, A#
    private static let noteLabels = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    private var pianoKeysView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Canvas { context, size in
                let blackKeyW = pianoKeyWidth * 0.6
                let whiteKeyW = pianoKeyWidth

                // First pass: draw all white keys (full row height, full width)
                for i in 0..<noteCount {
                    let noteNum = lowestNote + (noteCount - 1 - i)
                    let pc = noteNum % 12
                    let isBlack = Self.blackKeyNotes.contains(pc)
                    let y = CGFloat(i) * rowHeight

                    if !isBlack {
                        // White key
                        let rect = CGRect(x: 0, y: y, width: whiteKeyW, height: rowHeight)
                        context.fill(Path(rect), with: .color(Color(hex: 0xD4D4D8)))

                        // Subtle border between white keys
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: y + rowHeight))
                        line.addLine(to: CGPoint(x: whiteKeyW, y: y + rowHeight))
                        context.stroke(line, with: .color(Color(hex: 0x9E9EA3).opacity(0.5)), style: StrokeStyle(lineWidth: 0.5))

                        // Note name on C notes
                        if pc == 0 {
                            let octave = noteNum / 12 - 1
                            let text = Text("C\(octave)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: 0x3C3C43))
                            context.draw(context.resolve(text), at: CGPoint(x: whiteKeyW - 8, y: y + rowHeight / 2), anchor: .trailing)
                        }
                    }
                }

                // Second pass: draw black keys on top (shorter, narrower, left-aligned)
                for i in 0..<noteCount {
                    let noteNum = lowestNote + (noteCount - 1 - i)
                    let pc = noteNum % 12
                    let isBlack = Self.blackKeyNotes.contains(pc)
                    let y = CGFloat(i) * rowHeight

                    if isBlack {
                        let rect = CGRect(x: 0, y: y, width: blackKeyW, height: rowHeight)
                        context.fill(Path(rect), with: .color(Color(hex: 0x2C2C2E)))

                        // Subtle highlight line at top of black key
                        var hl = Path()
                        hl.move(to: CGPoint(x: 0, y: y))
                        hl.addLine(to: CGPoint(x: blackKeyW, y: y))
                        context.stroke(hl, with: .color(Color(hex: 0x48484A)), style: StrokeStyle(lineWidth: 0.5))
                    }
                }

                // Third pass: draw right edge line for the entire keyboard
                var edge = Path()
                edge.move(to: CGPoint(x: whiteKeyW - 0.5, y: 0))
                edge.addLine(to: CGPoint(x: whiteKeyW - 0.5, y: size.height))
                context.stroke(edge, with: .color(AppTheme.border.opacity(0.4)), style: StrokeStyle(lineWidth: 1))
            }
            .frame(width: pianoKeyWidth, height: totalHeight)
        }
    }

    // MARK: - Note Grid Canvas

    // Redraw triggers: accessed outside Canvas to ensure SwiftUI tracks changes
    private var eventRedrawID: Int {
        var hasher = Hasher()
        for e in viewModel.clip.events {
            hasher.combine(e.id)
            hasher.combine(e.startStep)
            hasher.combine(e.note)
            hasher.combine(e.duration)
            hasher.combine(e.velocity)
        }
        hasher.combine(viewModel.selectedEventIDs.count)
        return hasher.finalize()
    }

    private var noteGridCanvas: some View {
        let events = viewModel.clip.events
        let selectedIDs = viewModel.selectedEventIDs
        let clipLengthSteps = viewModel.clip.lengthSteps

        return Canvas { context, size in
            let zoom = viewModel.horizontalZoom
            let sw = stepWidth * zoom
            let steps = clipLengthSteps
            let spBar = stepsPerBar
            let spBeat = stepsPerBeat

            // Draw row backgrounds: black key rows are darker (standard DAW piano roll)
            for i in 0..<noteCount {
                let noteNum = lowestNote + (noteCount - 1 - i)
                let pc = noteNum % 12
                let y = CGFloat(i) * rowHeight
                let isBlack = Self.blackKeyNotes.contains(pc)
                if isBlack {
                    let rowRect = CGRect(x: 0, y: y, width: size.width, height: rowHeight)
                    context.fill(Path(rowRect), with: .color(Color.white.opacity(0.03)))
                }
                // Subtle horizontal line for C notes (octave boundary)
                if pc == 0 {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y + rowHeight))
                    line.addLine(to: CGPoint(x: size.width, y: y + rowHeight))
                    context.stroke(line, with: .color(AppTheme.border.opacity(0.15)), style: StrokeStyle(lineWidth: 0.5))
                }
            }

            // Draw vertical grid lines
            for step in 0...steps {
                let x = CGFloat(step) * sw
                let isBar = step % spBar == 0
                let isBeat = step % spBeat == 0

                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))

                if isBar {
                    context.stroke(line, with: .color(AppTheme.border.opacity(0.5)), style: StrokeStyle(lineWidth: 1))
                } else if isBeat {
                    context.stroke(line, with: .color(AppTheme.border.opacity(0.25)), style: StrokeStyle(lineWidth: 0.5))
                } else {
                    context.stroke(line, with: .color(AppTheme.border.opacity(0.1)), style: StrokeStyle(lineWidth: 0.5))
                }
            }

            // Horizontal row lines
            for i in 0...noteCount {
                let y = CGFloat(i) * rowHeight
                let noteNum = lowestNote + (noteCount - 1 - i)
                let pc = (noteNum + 12) % 12
                let isC = pc == 0

                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))

                let opacity: Double = isC ? 0.3 : 0.08
                context.stroke(line, with: .color(AppTheme.border.opacity(opacity)), style: StrokeStyle(lineWidth: isC ? 1 : 0.5))

                if i < noteCount {
                    let rowNote = lowestNote + (noteCount - 1 - i)
                    let rowPc = rowNote % 12
                    if [1, 3, 6, 8, 10].contains(rowPc) {
                        let rowRect = CGRect(x: 0, y: y, width: size.width, height: rowHeight)
                        context.fill(Path(rowRect), with: .color(Color.black.opacity(0.06)))
                    }
                }
            }

            // Draw notes
            for event in events {
                let noteRow = noteCount - 1 - (event.note - lowestNote)
                guard noteRow >= 0 && noteRow < noteCount else { continue }

                let x = CGFloat(event.startStep) * sw
                let y = CGFloat(noteRow) * rowHeight
                let w = CGFloat(event.duration) * sw
                let noteRect = CGRect(x: x, y: y + 1, width: max(w, 4), height: rowHeight - 2)

                let velOpacity = 0.4 + Double(event.velocity) / 127.0 * 0.6
                context.fill(
                    Path(roundedRect: noteRect, cornerRadius: 2),
                    with: .color(trackColor.opacity(velOpacity))
                )

                if selectedIDs.contains(event.id) {
                    context.stroke(
                        Path(roundedRect: noteRect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2),
                        with: .color(Color.white.opacity(0.8)),
                        style: StrokeStyle(lineWidth: 1.5)
                    )
                    let handleRect = CGRect(x: noteRect.maxX - resizeHandleWidth, y: noteRect.minY, width: resizeHandleWidth, height: noteRect.height)
                    context.fill(Path(handleRect), with: .color(Color.white.opacity(0.3)))
                }
            }

            // Marquee selection rectangle
            if isMarqueeSelecting {
                let rect = marqueeRect
                if rect.width > 0 && rect.height > 0 {
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.1)))
                    context.stroke(Path(rect), with: .color(Color.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                }
            }
        }
        .id(eventRedrawID)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in handleGridDrag(value, phase: .changed) }
                .onEnded { value in handleGridDrag(value, phase: .ended) }
        )
        .onKeyPress(.delete) {
            viewModel.deleteSelected()
            return .handled
        }
    }

    private var marqueeRect: CGRect {
        let x = min(marqueeStart.x, marqueeEnd.x)
        let y = min(marqueeStart.y, marqueeEnd.y)
        let w = abs(marqueeEnd.x - marqueeStart.x)
        let h = abs(marqueeEnd.y - marqueeStart.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Velocity Canvas

    private var velocityCanvas: some View {
        let events = viewModel.clip.events
        let selectedIDs = viewModel.selectedEventIDs

        return ZStack {
            Canvas { context, size in
                let zoom = viewModel.horizontalZoom
                let sw = stepWidth * zoom

                // Background
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(.textBackgroundColor).opacity(0.3)))

                // Label
                let label = Text("VEL")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                context.draw(context.resolve(label), at: CGPoint(x: 4, y: 8), anchor: .topLeading)

                // Draw velocity bars for each note at its horizontal position
                for event in events {
                    let x = CGFloat(event.startStep) * sw
                    let velFrac = CGFloat(event.velocity) / 127.0
                    let barH = velFrac * (size.height - 4)
                    let barW = max(CGFloat(event.duration) * sw - 2, 3)
                    let barRect = CGRect(x: x + 1, y: size.height - barH - 2, width: barW, height: barH)

                    let isSelected = selectedIDs.contains(event.id)
                    let barColor = isSelected ? Color.white : trackColor
                    context.fill(Path(roundedRect: barRect, cornerRadius: 1), with: .color(barColor.opacity(0.7)))

                    // Show velocity value on selected notes
                    if isSelected || velocityDragEventID == event.id {
                        let valText = Text("\(event.velocity)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        context.draw(context.resolve(valText), at: CGPoint(x: x + barW / 2, y: barRect.minY - 2), anchor: .bottom)
                    }
                }
            }
            .id(eventRedrawID)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in handleVelocityDrag(value) }
                    .onEnded { _ in velocityDragEventID = nil; velocityDragValue = nil }
            )
        }
    }

    // MARK: - CC Automation Canvas

    private var ccAutomationCanvas: some View {
        VStack(spacing: 0) {
            // CC lane header
            HStack(spacing: 4) {
                Menu {
                    ForEach(Self.ccNames, id: \.0) { (num, name) in
                        Button("\(name) (\(num))") {
                            viewModel.selectedCCNumber = num
                        }
                    }
                    Divider()
                    ForEach(0..<128, id: \.self) { num in
                        if !Self.ccNames.contains(where: { $0.0 == num }) {
                            Button("CC \(num)") {
                                viewModel.selectedCCNumber = num
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(ccDisplayName(viewModel.selectedCCNumber))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(3)
                }

                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .frame(height: 16)

            Canvas { context, size in
                let zoom = viewModel.horizontalZoom
                let sw = stepWidth * zoom
                let points = viewModel.filteredCCPoints

                // Background
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(.textBackgroundColor).opacity(0.2)))

                // Grid lines at bar boundaries
                let steps = viewModel.clip.lengthSteps
                let spBar = stepsPerBar
                for step in stride(from: 0, through: steps, by: spBar) {
                    let x = CGFloat(step) * sw
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 0))
                    line.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(line, with: .color(AppTheme.border.opacity(0.2)), style: StrokeStyle(lineWidth: 0.5))
                }

                // Draw automation line
                if points.count >= 2 {
                    var linePath = Path()
                    for (i, point) in points.enumerated() {
                        let x = CGFloat(point.step) * sw
                        let y = size.height - (CGFloat(point.value) / 127.0 * size.height)
                        if i == 0 {
                            linePath.move(to: CGPoint(x: x, y: y))
                        } else {
                            linePath.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.stroke(linePath, with: .color(trackColor.opacity(0.8)), style: StrokeStyle(lineWidth: 1.5))
                }

                // Draw breakpoints
                for point in points {
                    let x = CGFloat(point.step) * sw
                    let y = size.height - (CGFloat(point.value) / 127.0 * size.height)
                    let dotRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: dotRect), with: .color(trackColor))
                    context.stroke(Path(ellipseIn: dotRect), with: .color(Color.white.opacity(0.6)), style: StrokeStyle(lineWidth: 1))
                }
            }
            .frame(height: ccLaneHeight - 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in handleCCDrag(value, phase: .changed) }
                    .onEnded { value in handleCCDrag(value, phase: .ended) }
            )
        }
    }

    private func ccDisplayName(_ cc: Int) -> String {
        if let entry = Self.ccNames.first(where: { $0.0 == cc }) {
            return "\(entry.1) (\(cc))"
        }
        return "CC \(cc)"
    }

    // MARK: - Grid Interaction

    private enum DragPhase { case changed, ended }

    private func handleGridDrag(_ value: DragGesture.Value, phase: DragPhase) {
        let zoom = viewModel.horizontalZoom
        let sw = stepWidth * zoom

        let step = Double(value.location.x) / Double(sw)
        let row = Int(value.location.y / rowHeight)
        let note = lowestNote + (noteCount - 1 - row)

        guard note >= lowestNote && note < lowestNote + noteCount else { return }

        if phase == .ended {
            if dragMode == .marquee {
                // Finish marquee: select notes in rect
                let rect = marqueeRect
                var ids = Set<UUID>()
                for event in viewModel.clip.events {
                    let noteRow = noteCount - 1 - (event.note - lowestNote)
                    guard noteRow >= 0 && noteRow < noteCount else { continue }
                    let ex = CGFloat(event.startStep) * sw
                    let ey = CGFloat(noteRow) * rowHeight
                    let ew = max(CGFloat(event.duration) * sw, 4)
                    let eventRect = CGRect(x: ex, y: ey, width: ew, height: rowHeight)
                    if rect.intersects(eventRect) {
                        ids.insert(event.id)
                    }
                }
                viewModel.selectNotes(ids: ids)
                isMarqueeSelecting = false
                dragMode = .none
                return
            }

            if dragMode == .none {
                if let event = hitTestEvent(x: value.location.x, y: value.location.y) {
                    let shiftHeld = NSEvent.modifierFlags.contains(.shift)
                    if !shiftHeld && viewModel.isSelected(event.id) {
                        viewModel.deleteNote(id: event.id)
                    } else {
                        viewModel.selectNote(id: event.id, addToSelection: shiftHeld)
                    }
                } else {
                    let snappedStep = floor(step)
                    viewModel.addNote(atStep: snappedStep, note: note)
                }
            }

            dragMode = .none
            dragEventID = nil
            multiDragOrigins = []
            return
        }

        if phase == .changed {
            if dragMode == .none {
                if let event = hitTestEvent(x: value.startLocation.x, y: value.startLocation.y) {
                    // Check resize vs move
                    let eventRight = CGFloat(event.startStep + event.duration) * sw
                    let clickX = value.startLocation.x
                    if viewModel.isSelected(event.id) && abs(clickX - eventRight) < resizeHandleWidth + 2 {
                        dragMode = .resize
                        dragEventID = event.id
                        dragOriginStep = event.startStep
                        dragOriginNote = event.note
                    } else {
                        dragMode = .move
                        dragEventID = event.id
                        // If note not in selection, make it the sole selection
                        if !viewModel.isSelected(event.id) {
                            viewModel.selectNote(id: event.id)
                        }
                        // Record origins for all selected notes
                        multiDragOrigins = viewModel.clip.events
                            .filter { viewModel.isSelected($0.id) }
                            .map { (id: $0.id, step: $0.startStep, note: $0.note) }
                        dragOriginStep = event.startStep
                        dragOriginNote = event.note
                    }
                } else {
                    // Empty space: only start marquee if actually dragging (distance > 3px)
                    let dist = hypot(value.translation.width, value.translation.height)
                    if dist > 3 {
                        dragMode = .marquee
                        isMarqueeSelecting = true
                        marqueeStart = value.startLocation
                        marqueeEnd = value.location
                    }
                    // If dist <= 3, keep dragMode = .none so .onEnded creates a note
                    return
                }
            }

            if dragMode == .marquee {
                marqueeEnd = value.location
                return
            }

            guard let eid = dragEventID else { return }

            switch dragMode {
            case .move:
                let deltaStepPx = value.translation.width
                let deltaRowPx = value.translation.height
                let deltaSteps = Double(deltaStepPx) / Double(sw)
                let deltaRows = Int(deltaRowPx / rowHeight)

                // Move all selected notes together
                for origin in multiDragOrigins {
                    let newStep = max(floor(origin.step + deltaSteps), 0)
                    let newNote = origin.note - deltaRows
                    viewModel.moveNote(id: origin.id, toStep: newStep, toNote: newNote)
                }

            case .resize:
                guard let event = viewModel.clip.events.first(where: { $0.id == eid }) else { return }
                let mouseStep = Double(value.location.x) / Double(sw)
                let newDur = mouseStep - event.startStep
                viewModel.resizeNote(id: eid, newDuration: newDur)

            default:
                break
            }
        }
    }

    private func hitTestEvent(x: CGFloat, y: CGFloat) -> MIDIEvent? {
        let zoom = viewModel.horizontalZoom
        let sw = stepWidth * zoom

        for event in viewModel.clip.events {
            let noteRow = noteCount - 1 - (event.note - lowestNote)
            guard noteRow >= 0 && noteRow < noteCount else { continue }

            let ex = CGFloat(event.startStep) * sw
            let ey = CGFloat(noteRow) * rowHeight
            let ew = max(CGFloat(event.duration) * sw, 4)
            let rect = CGRect(x: ex, y: ey, width: ew, height: rowHeight)

            if rect.contains(CGPoint(x: x, y: y)) {
                return event
            }
        }
        return nil
    }

    // MARK: - Velocity Lane Interaction

    private func handleVelocityDrag(_ value: DragGesture.Value) {
        let zoom = viewModel.horizontalZoom
        let sw = stepWidth * zoom

        let clickStep = Double(value.location.x) / Double(sw)
        var closest: MIDIEvent?
        var closestDist = Double.infinity

        for event in viewModel.clip.events {
            let center = event.startStep + event.duration / 2
            let dist = abs(center - clickStep)
            if dist < closestDist && dist < Double(event.duration) / 2 + 0.5 {
                closestDist = dist
                closest = event
            }
        }

        if let event = closest {
            let velFrac = 1.0 - (value.location.y / velocityLaneHeight)
            let vel = Int(max(1, min(127, velFrac * 127)))
            viewModel.setVelocity(id: event.id, velocity: vel)
            viewModel.selectNote(id: event.id)
            velocityDragEventID = event.id
            velocityDragValue = vel
        }
    }

    // MARK: - CC Automation Interaction

    private func handleCCDrag(_ value: DragGesture.Value, phase: DragPhase) {
        let zoom = viewModel.horizontalZoom
        let sw = stepWidth * zoom
        let laneH = ccLaneHeight - 16  // subtract header

        let clickStep = Double(value.location.x) / Double(sw)
        let valFrac = 1.0 - (Double(value.location.y) / Double(laneH))
        let clickVal = Int(max(0, min(127, valFrac * 127)))

        if phase == .ended {
            if ccDragPointID == nil {
                // Click to add a new breakpoint
                viewModel.addCCPoint(step: clickStep, value: clickVal)
            }
            ccDragPointID = nil
            return
        }

        if phase == .changed {
            // Check if dragging an existing point
            if ccDragPointID == nil {
                let points = viewModel.filteredCCPoints
                for point in points {
                    let px = CGFloat(point.step) * sw
                    let py = laneH - (CGFloat(point.value) / 127.0 * laneH)
                    let dist = hypot(value.startLocation.x - px, value.startLocation.y - py)
                    if dist < 8 {
                        ccDragPointID = point.id
                        break
                    }
                }
            }

            if let pointID = ccDragPointID {
                viewModel.moveCCPoint(id: pointID, toStep: max(clickStep, 0), toValue: clickVal)
            }
        }
    }
}
