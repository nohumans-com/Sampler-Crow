import SwiftUI

@Observable
@MainActor
final class AppState {
    var connectionStatus = ConnectionStatus()
    var cpuUsage: String = "--"
    var memUsage: String = "--"
    var selectedTab: SidebarTab = .console

    let serialService = SerialService()
    let midiService = MIDIService()
    let audioService = AudioService()
    let launchpadService = LaunchpadService()
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case grid = "Launchpad"
    case audio = "Audio"
    case console = "Console"
    case mixer = "Mixer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .grid: "square.grid.3x3.fill"
        case .audio: "waveform"
        case .console: "terminal"
        case .mixer: "slider.horizontal.3"
        }
    }
}
