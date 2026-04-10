import Foundation

@Observable
class SamplerState {
    var samplePath: String = ""
    var sampleName: String = ""
    var gain: Int = 80          // 0-100
    var pitchSemitones: Int = 0 // -24 to +24
    var pitchCents: Int = 0     // -50 to +50
    var sampleStart: Int = 0
    var sampleEnd: Int = 0
    var loopEnabled: Bool = false
    var loopStart: Int = 0
    var loopEnd: Int = 0
    var oneShot: Bool = true
    var waveformPeaks: [UInt8] = []  // 128 values

    // Mode
    var samplerMode: Int = 0  // 0=Pitch, 1=Grain, 2=Chop

    // Pitch mode additions
    var rootNote: Int = 60
    var attackMs: Int = 5
    var decayMs: Int = 100
    var sustainLevel: Int = 100  // 0-100 (mapped to 0.0-1.0)
    var releaseMs: Int = 50

    // Grain mode
    var grainPosition: Int = 50    // 0-100
    var grainWindowSize: Int = 30  // 0-100
    var grainSizeMs: Int = 100     // 10-500
    var grainCount: Int = 4        // 1-16
    var grainSpread: Int = 50      // 0-100
    var grainEnvShape: Int = 0     // 0=Hann, 1=Gaussian, 2=Triangle, 3=Tukey

    // Chop mode
    var chopSensitivity: Int = 50  // 0-100
    var chopTriggerMode: Int = 0   // 0=Trigger, 1=Gate
    var chopSliceCount: Int = 0
    var chopSliceBoundaries: [Int] = []
}
