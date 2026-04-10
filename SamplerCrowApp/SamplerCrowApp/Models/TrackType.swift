import Foundation

enum TrackType: String, CaseIterable, Identifiable {
    case sampler = "Sampler"
    case drumMachine = "Drum Machine"
    case synth = "Synth"
    case audio = "Audio"
    case midi = "MIDI"
    var id: String { rawValue }
}
