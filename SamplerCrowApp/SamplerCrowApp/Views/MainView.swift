import SwiftUI

struct MainView: View {
    @State var appState = AppState()
    @State private var consoleVM: SerialConsoleViewModel?
    @State private var keyboardVM: KeyboardViewModel?
    @State private var gridVM: GridViewModel?
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
                StatusBarView(
                    status: appState.connectionStatus,
                    cpu: appState.cpuUsage,
                    mem: appState.memUsage
                )

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
                        Text("Mixer — coming soon")
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Keyboard hint
                if appState.connectionStatus.midi.isConnected {
                    HStack {
                        Text("Keyboard: A-K = piano keys (C4-C5)")
                            .font(AppTheme.monoFontSmall)
                            .foregroundStyle(AppTheme.textSecondary)

                        if let kvm = keyboardVM, !kvm.activeNotes.isEmpty {
                            Text("Playing: \(kvm.activeNotes.sorted().map { String($0) }.joined(separator: ", "))")
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
            keyboardVM = KeyboardViewModel(appState: appState)
            gridVM = GridViewModel(appState: appState, consoleVM: cvm)
            cvm.gridViewModel = gridVM

            cvm.log("Sampler-Crow v0.1")
            keyboardVM?.startListening()

            // Auto-connect on launch
            cvm.log("Auto-connecting...")
            cvm.connect()

            // Watch for Teensy hotplug
            discovery.startWatching(
                onConnected: { [weak cvm] in
                    Task { @MainActor in
                        cvm?.log("Teensy detected — reconnecting...")
                        try? await Task.sleep(for: .seconds(1)) // Wait for USB enumeration
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
    }
}
