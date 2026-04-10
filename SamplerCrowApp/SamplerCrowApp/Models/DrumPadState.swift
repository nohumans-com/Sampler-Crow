import Foundation

@Observable
class DrumPadState {
    var padIndex: Int
    var samplePath: String = ""
    var sampleName: String = ""
    var params: SamplerState = SamplerState()
    var waveformPeaks: [UInt8] = []

    init(padIndex: Int) {
        self.padIndex = padIndex
    }
}
