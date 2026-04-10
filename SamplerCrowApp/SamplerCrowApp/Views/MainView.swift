import SwiftUI

struct MainView: View {
    @State var appState = AppState()
    @State private var consoleVM: SerialConsoleViewModel?
    @State private var keyboardVM: KeyboardViewModel?
    @State private var gridVM: GridViewModel?
    @State private var mixerVM: MixerViewModel?
    @State private var fileBrowserVM: FileBrowserViewModel?
    @State private var samplerVM: SamplerViewModel?
    @State private var drumMachineVM: DrumMachineViewModel?
    @State private var clipEditorVM: ClipEditorViewModel?
    @State private var pianoRollVM: PianoRollViewModel?
    @State private var arrangementVM: ArrangementViewModel?
    @State private var synthEngineVM: SynthEngineViewModel?
    @State private var projectVM: ProjectViewModel?
    @State private var showProjectBrowser = false
    @State private var showSaveDialog = false
    @State private var saveProjectName = ""
    @State private var discovery = DeviceDiscoveryService()

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, selection: $appState.selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationTitle("Sampler-Crow")
        } detail: {
            VStack(spacing: 0) {
                // Project bar
                ProjectBarView(
                    project: appState.project,
                    onSave: {
                        saveProjectName = appState.project.name
                        showSaveDialog = true
                    },
                    onLoad: { showProjectBrowser = true },
                    onNew: { projectVM?.newProject() },
                    onExport: { projectVM?.exportToMac() }
                )

                // Top bar: status + transport
                HStack(spacing: 12) {
                    // Play/Stop button
                    Button(action: { gridVM?.togglePlayStop() }) {
                        Image(systemName: gridVM?.isPlaying == true ? "stop.fill" : "play.fill")
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                            .foregroundStyle(gridVM?.isPlaying == true ? .red : .green)
                    }
                    .buttonStyle(.plain)
                    .help("Play / Stop (Space)")

                    StatusBarView(
                        status: appState.connectionStatus,
                        cpu: appState.cpuUsage,
                        mem: appState.memUsage
                    )
                }

                Divider()

                Group {
                    switch appState.selectedTab {
                    case .console:
                        if let vm = consoleVM {
                            SerialConsoleView(viewModel: vm)
                        }
                    case .grid:
                        if let vm = gridVM {
                            GridView(viewModel: vm)
                        }
                    case .audio:
                        AudioMonitorView(audioService: appState.audioService)
                    case .mixer:
                        if let vm = mixerVM {
                            MixerView(viewModel: vm)
                        }
                    case .samples:
                        if let vm = fileBrowserVM {
                            FileBrowserView(viewModel: vm)
                        }
                    case .trackEdit:
                        if let svm = samplerVM, let dvm = drumMachineVM, let cev = clipEditorVM, let mvm = mixerVM,
                           let prvm = pianoRollVM, let avm = arrangementVM, let sevm = synthEngineVM {
                            TrackNavigatorView(
                                appState: appState,
                                tracks: appState.tracks,
                                selectedTrackIndex: $appState.selectedTrackIndex,
                                levels: mvm.levels,
                                samplerVM: svm,
                                drumVM: dvm,
                                clipVM: cev,
                                mixerVM: mvm,
                                pianoRollVM: prvm,
                                arrangementVM: avm,
                                synthEngineVM: sevm
                            )
                        } else {
                            Text("Initializing...")
                                .font(AppTheme.monoFont)
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Keyboard hint
                if true {  // always show keyboard hints, even without Teensy
                    HStack {
                        Text("Space = Play/Stop  |  A-K = keys (\(keyboardVM?.octaveDisplay ?? "C4-C5"))  |  Z/X = octave ↓/↑")
                            .font(AppTheme.monoFontSmall)
                            .foregroundStyle(AppTheme.textSecondary)

                        if let kvm = keyboardVM, !kvm.activeNotes.isEmpty {
                            Text("♪ \(kvm.activeNotes.sorted().map { SamplerViewModel.noteName(Int($0)) }.joined(separator: " "))")
                                .font(AppTheme.monoFontSmall)
                                .foregroundStyle(AppTheme.accent)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            let cvm = SerialConsoleViewModel(appState: appState)
            consoleVM = cvm
            let kvm = KeyboardViewModel(appState: appState)
            keyboardVM = kvm
            let gvm = GridViewModel(appState: appState, consoleVM: cvm)
            gridVM = gvm
            let mvm = MixerViewModel(appState: appState)
            mixerVM = mvm
            let fbvm = FileBrowserViewModel(appState: appState)
            fileBrowserVM = fbvm
            let svm = SamplerViewModel(appState: appState, trackIndex: 0)
            samplerVM = svm
            let dmvm = DrumMachineViewModel(appState: appState, trackIndex: 0)
            drumMachineVM = dmvm
            let cevm = ClipEditorViewModel(appState: appState, trackIndex: 0)
            clipEditorVM = cevm
            let prvm = PianoRollViewModel(appState: appState, trackIndex: 0)
            pianoRollVM = prvm
            let avm = ArrangementViewModel(appState: appState)
            arrangementVM = avm
            let sevm = SynthEngineViewModel(appState: appState, trackIndex: 0)
            synthEngineVM = sevm
            let pjvm = ProjectViewModel(appState: appState, mixerVM: mvm, synthEngineVM: sevm)
            pjvm.gridVM = gvm
            projectVM = pjvm
            cvm.clipEditorViewModel = cevm
            cvm.synthEngineViewModel = sevm
            cvm.gridViewModel = gvm
            cvm.mixerViewModel = mvm
            cvm.fileBrowserViewModel = fbvm

            // Spacebar → context-aware: preview on Samples tab, play/stop elsewhere
            kvm.onSpacebar = { [weak gvm, weak fbvm, weak appState] in
                if appState?.selectedTab == .samples {
                    fbvm?.spacebarAction()
                } else {
                    gvm?.togglePlayStop()
                }
            }

            cvm.log("Sampler-Crow v0.5")
            kvm.startListening()

            // Send initial FOCUS to Teensy so QWERTY keyboard targets track 0
            Task {
                try? await Task.sleep(for: .seconds(2))  // wait for serial connection
                try? await appState.serialService.send("FOCUS:0")
            }

            cvm.log("Auto-connecting...")
            cvm.connect()

            discovery.startWatching(
                onConnected: { [weak cvm] in
                    Task { @MainActor in
                        cvm?.log("Teensy detected — reconnecting...")
                        try? await Task.sleep(for: .seconds(1))
                        cvm?.connect()
                    }
                },
                onDisconnected: { [weak cvm] in
                    Task { @MainActor in
                        cvm?.log("Teensy disconnected")
                        cvm?.disconnect()
                    }
                }
            )
        }
        .onDisappear {
            keyboardVM?.stopListening()
            discovery.stopWatching()
        }
        .sheet(isPresented: $showProjectBrowser) {
            if let pjvm = projectVM {
                ProjectBrowserView(projectVM: pjvm)
            }
        }
        .alert("Save Project", isPresented: $showSaveDialog) {
            TextField("Project name", text: $saveProjectName)
            Button("Save") {
                projectVM?.saveProject(name: saveProjectName)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for this project.")
        }
    }
}
