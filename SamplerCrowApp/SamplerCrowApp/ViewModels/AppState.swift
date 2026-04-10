import SwiftUI

@Observable
@MainActor
final class AppState {
    var connectionStatus = ConnectionStatus()
    var cpuUsage: String = "--"
    var memUsage: String = "--"
    var selectedTab: SidebarTab = .trackEdit
    var selectedTrackIndex: Int? = 0  // auto-select track 1 so Navigator shows content immediately
    var project = Project()

    var tracks: [TrackState] = MixerViewModel.trackNames.enumerated().map { i, name in
        TrackState(index: i, name: name)
    }

    let serialService = SerialService()
    let midiService = MIDIService()
    let audioService = AudioService()
    let launchpadService = LaunchpadService()
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case trackEdit = "Navigator"
    case mixer = "Mixer"
    case samples = "Samples"
    case audio = "Audio"
    case grid = "Launchpad"
    case console = "Console"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .grid: "square.grid.3x3.fill"
        case .audio: "waveform"
        case .console: "terminal"
        case .mixer: "slider.horizontal.3"
        case .samples: "sdcard"
        case .trackEdit: "rectangle.split.3x3"
        }
    }
}
