import SwiftUI

enum NavigatorSubTab: String, CaseIterable {
    case machine = "MACHINE"
    case fx = "FX"
    case mix = "MIX"
    case seq = "SEQ"
    case arrange = "ARRANGE"
}

struct TrackNavigatorView: View {
    let appState: AppState
    let tracks: [TrackState]
    @Binding var selectedTrackIndex: Int?
    let levels: [Int]

    let samplerVM: SamplerViewModel
    let drumVM: DrumMachineViewModel
    let clipVM: ClipEditorViewModel
    let mixerVM: MixerViewModel
    let pianoRollVM: PianoRollViewModel
    let arrangementVM: ArrangementViewModel
    let synthEngineVM: SynthEngineViewModel

    @State private var subTab: NavigatorSubTab = .machine

    private static let trackColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    private var selectedIdx: Int {
        selectedTrackIndex ?? 0
    }

    private var selectedTrack: TrackState {
        tracks[selectedIdx]
    }

    private var trackColor: Color {
        Self.trackColors[selectedIdx % Self.trackColors.count]
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar: track list
            TrackListPanel(
                tracks: tracks,
                selectedTrack: selectedTrackIndex,
                levels: levels,
                volumes: mixerVM.volumes,
                mutes: mixerVM.mutes,
                onSelect: { idx in
                    selectedTrackIndex = idx
                    samplerVM.trackIndex = idx
                    drumVM.trackIndex = idx
                    clipVM.trackIndex = idx
                    pianoRollVM.trackIndex = idx
                    synthEngineVM.trackIndex = idx
                    // Send FOCUS to Teensy so external MIDI controllers play this track
                    Task { try? await appState.serialService.send("FOCUS:\(idx)") }
                },
                onVolumeChange: { track, value in
                    mixerVM.setVolume(track, value)
                },
                onMute: { track in
                    mixerVM.toggleMute(track)
                },
                onRename: { idx, newName in
                    renameTrack(idx, newName)
                }
            )

            Divider()

            // Right content area
            VStack(spacing: 0) {
                // Sub-tab bar
                subTabBar

                Divider()

                // Content based on sub-tab
                Group {
                    switch subTab {
                    case .machine:
                        machineContent
                    case .fx:
                        fxPlaceholder
                    case .mix:
                        mixContent
                    case .seq:
                        seqContent
                    case .arrange:
                        arrangeContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if selectedTrackIndex == nil {
                selectedTrackIndex = 0
            }
        }
    }

    // MARK: - Rename

    private func renameTrack(_ idx: Int, _ newName: String) {
        guard idx >= 0 && idx < appState.tracks.count else { return }
        appState.tracks[idx].name = newName
        Task {
            try? await appState.serialService.send("RENAME:\(idx):\(newName)")
        }
    }

    // MARK: - Sub-Tab Bar

    private var subTabBar: some View {
        HStack(spacing: 0) {
            // Track header
            HStack(spacing: 8) {
                Text("TRACK \(selectedIdx + 1): \(selectedTrack.name)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)

                // Type picker
                Picker("", selection: Binding(
                    get: { selectedTrack.trackType },
                    set: { newType in
                        selectedTrack.trackType = newType
                        let idx = selectedTrack.index

                        // Configure firmware for the selected mode
                        Task {
                            // Disable all modes first
                            try? await appState.serialService.send("SETDRUMMODE:\(idx):0")
                            try? await appState.serialService.send("ENABLESYNTH:\(idx):0")
                            try? await Task.sleep(for: .milliseconds(10))

                            // Enable the selected mode
                            switch newType {
                            case .drumMachine:
                                selectedTrack.isDrumMachine = true
                                try? await appState.serialService.send("SETDRUMMODE:\(idx):1")
                            case .synth:
                                selectedTrack.isDrumMachine = false
                                try? await appState.serialService.send("ENABLESYNTH:\(idx):1")
                            default:
                                selectedTrack.isDrumMachine = false
                                // Sampler/Audio/MIDI — basic mode, no special enable needed
                            }
                        }
                    }
                )) {
                    Text("Sampler").tag(TrackType.sampler)
                    Text("Drums").tag(TrackType.drumMachine)
                    Text("Synth").tag(TrackType.synth)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            Spacer()

            // Sub-tab picker — all tabs always enabled
            HStack(spacing: 0) {
                ForEach(NavigatorSubTab.allCases, id: \.rawValue) { tab in
                    Button(action: { subTab = tab }) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(subTab == tab ? .white : AppTheme.textSecondary)
                            .frame(width: 70, height: 26)
                            .background(subTab == tab ? trackColor.opacity(0.6) : Color(.controlBackgroundColor))
                    }
                    .buttonStyle(.plain)
                }
            }
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppTheme.border.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Machine Content

    @ViewBuilder
    private var machineContent: some View {
        switch selectedTrack.trackType {
        case .drumMachine:
            DrumMachineView(track: selectedTrack, drumVM: drumVM, appState: appState)
        case .sampler:
            SamplerView(track: selectedTrack, samplerVM: samplerVM, appState: appState)
        case .synth:
            SynthEngineView(track: selectedTrack, viewModel: synthEngineVM)
        default:
            Text("\(selectedTrack.trackType.rawValue) parameters")
                .font(AppTheme.monoFont)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - FX Placeholder

    private var fxPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.3))
            Text("Effects - Coming Soon")
                .font(AppTheme.monoFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Mix Content (single track strip)

    private var mixContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRACK \(selectedIdx + 1) MIX")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            HStack(spacing: 0) {
                ChannelStripView(
                    track: selectedIdx,
                    name: selectedTrack.name,
                    volume: mixerVM.volumes[selectedIdx],
                    pan: mixerVM.pans[selectedIdx],
                    level: mixerVM.levels[selectedIdx],
                    isMuted: mixerVM.mutes[selectedIdx],
                    isSoloed: mixerVM.solos[selectedIdx],
                    onVolumeChange: { mixerVM.setVolume(selectedIdx, $0) },
                    onVolumeReset: { mixerVM.resetVolume(selectedIdx) },
                    onPanChange: { mixerVM.setPan(selectedIdx, $0) },
                    onPanReset: { mixerVM.resetPan(selectedIdx) },
                    onMute: { mixerVM.toggleMute(selectedIdx) },
                    onSolo: { mixerVM.toggleSolo(selectedIdx) }
                )
                .frame(width: 80)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Spacer()
        }
    }

    // MARK: - Sequencer Content

    @ViewBuilder
    private var seqContent: some View {
        if selectedTrack.trackType == .drumMachine {
            DrumSequencerView(track: selectedTrack, clipVM: clipVM)
        } else {
            VStack(spacing: 0) {
                // Clip selector header
                HStack {
                    Text("CLIP:")
                        .font(AppTheme.monoFontSmall)
                        .foregroundStyle(AppTheme.textSecondary)

                    // If editing an arrangement clip, show its name
                    if let clipID = pianoRollVM.editingArrangementClipID,
                       let clip = selectedTrack.arrangementClips.first(where: { $0.id == clipID }) {
                        TextField("Clip name", text: Binding(
                            get: { clip.name },
                            set: { clip.name = $0 }
                        ))
                        .font(AppTheme.monoFont)
                        .frame(width: 120)
                        .textFieldStyle(.plain)
                    } else {
                        Text("Track \(selectedIdx + 1) default")
                            .font(AppTheme.monoFont)
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Spacer()

                    // Clip picker menu (all arrangement clips for this track)
                    if !selectedTrack.arrangementClips.isEmpty {
                        Menu("Clips") {
                            Button("Default (track clip)") {
                                pianoRollVM.editingArrangementClipID = nil
                            }
                            Divider()
                            ForEach(selectedTrack.arrangementClips) { clip in
                                Button(clip.name) {
                                    pianoRollVM.editingArrangementClipID = clip.id
                                    pianoRollVM.trackIndex = selectedIdx
                                }
                            }
                        }
                        .controlSize(.small)
                    }

                    Button("Sync to Teensy") {
                        pianoRollVM.syncToTeensy()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                PianoRollView(track: selectedTrack, viewModel: pianoRollVM)
            }
        }
    }

    // MARK: - Arrange Content

    private var arrangeContent: some View {
        ArrangementView(
            appState: appState,
            viewModel: arrangementVM,
            selectedTrackIndex: $selectedTrackIndex,
            onEditClip: { trackIdx in
                // When double-clicking a clip in arrangement, switch to SEQ and set up piano roll
                selectedTrackIndex = trackIdx
                pianoRollVM.trackIndex = trackIdx
                if let clipID = arrangementVM.editingClipID {
                    pianoRollVM.editingArrangementClipID = clipID
                }
                subTab = .seq
            }
        )
    }
}
