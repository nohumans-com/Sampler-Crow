import Foundation

struct ProjectData: Codable {
    var version: Int = 1
    var name: String
    var bpm: Float
    var tracks: [TrackData]
}

struct TrackData: Codable {
    var index: Int
    var name: String
    var trackType: String
    var isDrumMachine: Bool
    var mixer: MixerData
    var sampler: SamplerData
    var drumPads: [DrumPadData]
    var synthEngine: SynthEngineData
    var midiClip: MIDIClipData
    var arrangementClips: [ArrangementClipData]
}

struct MixerData: Codable {
    var volume: Int
    var pan: Int
    var mute: Bool
    var solo: Bool
}

struct SamplerData: Codable {
    var samplePath: String
    var sampleName: String
    var mode: Int
    var gain: Int
    var pitchSemitones: Int
    var pitchCents: Int
    var rootNote: Int
    var sampleStart: Int
    var sampleEnd: Int
    var loopEnabled: Bool
    var loopStart: Int
    var loopEnd: Int
    var oneShot: Bool
    var attackMs: Int
    var decayMs: Int
    var sustainLevel: Int
    var releaseMs: Int
    var grainPosition: Int
    var grainWindowSize: Int
    var grainSizeMs: Int
    var grainCount: Int
    var grainSpread: Int
    var grainEnvShape: Int
    var chopSensitivity: Int
    var chopTriggerMode: Int
}

struct DrumPadData: Codable {
    var padIndex: Int
    var samplePath: String
    var sampleName: String
    var params: SamplerData
}

struct SynthEngineData: Codable {
    var engine: Int
    var timbre: Int
    var harmonics: Int
    var morph: Int
}

struct MIDIClipData: Codable {
    var name: String
    var lengthBars: Int
    var timeSignatureNumerator: Int
    var timeSignatureDenominator: Int
    var events: [MIDIEventData]
    var ccAutomation: [CCPointData]
}

struct MIDIEventData: Codable {
    var note: Int
    var velocity: Int
    var startStep: Double
    var duration: Double
    var channel: Int
}

struct CCPointData: Codable {
    var step: Double
    var value: Int
    var cc: Int
}

struct ArrangementClipData: Codable {
    var name: String
    var startBar: Int
    var lengthBars: Int
    var colorHex: String
    var midiClip: MIDIClipData
}
