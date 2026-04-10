import Foundation

@Observable
class TrackState {
    var index: Int
    var name: String
    var trackType: TrackType = .synth
    var samplerState = SamplerState()
    var isDrumMachine: Bool = false
    var drumPads: [DrumPadState] = (0..<8).map { DrumPadState(padIndex: $0) }
    var midiClip: MIDIClip = MIDIClip()
    var arrangementClips: [ArrangementClip] = []

    init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}
