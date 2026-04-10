import SwiftUI

@Observable
@MainActor
final class SynthEngineViewModel {
    let appState: AppState
    var trackIndex: Int

    var engineModel: Int = 0    // 0-23
    var timbre: Int = 500       // 0-1000
    var harmonics: Int = 500    // 0-1000
    var morph: Int = 500        // 0-1000
    var voiceCount: Int = 1     // 1 = mono, 4 = poly

    // DX7 patch browser state
    var dx7Files: [String] = []
    var dx7PatchNames: [String] = []
    var dx7SelectedPatch: Int? = nil
    var currentDX7File: String = ""
    var dx7Loaded: Bool = false

    private var engineTimer: Task<Void, Never>?
    private var timbreTimer: Task<Void, Never>?
    private var harmonicsTimer: Task<Void, Never>?
    private var morphTimer: Task<Void, Never>?
    private var polyCountTimer: Task<Void, Never>?

    static let engineNames: [String] = [
        "Virtual Analog", "Waveshaper", "FM", "Formant",
        "Harmonic", "Wavetable", "Chords", "Speech",
        "Granular Cloud", "Filtered Noise", "Particle", "String",
        "Modal Resonator", "Bass Drum", "Snare Drum", "Hi-Hat",
        "Classic Waveshapes + Filter", "Phase Distortion", "6-OP FM A", "6-OP FM B",
        "6-OP FM C", "Wave Terrain", "String Machine", "Chiptune"
    ]
    static let engineShort: [String] = [
        "VA", "WS", "FM", "FMT", "HRM", "WT", "CHD", "SPK",
        "GRN", "FLT", "PRT", "STR", "MOD", "BD", "SD", "HH",
        "VCF", "PD", "FMA", "FMB", "FMC", "TRN", "ENS", "CHI"
    ]
    static let engineDescriptions: [String] = [
        "Dual detuned oscillators with PWM",
        "Sine through wavefolder",
        "Two-operator frequency modulation",
        "Vocal formant synthesis",
        "Additive harmonic partials",
        "Four-bank wavetable morphing",
        "Four-note chord generator",
        "Vowel speech synthesis",
        "Granular cloud of micro-sounds",
        "Noise through resonant filter",
        "Random particle impulses",
        "Karplus-Strong string model",
        "Resonant modal body simulation",
        "Analog bass drum synthesis",
        "Analog snare drum synthesis",
        "Analog hi-hat synthesis",
        "Saw/square/tri through resonant SVF",
        "CZ-style sine with phase distortion",
        "6-op FM: 3 modulators to 1 carrier",
        "6-op FM: 2 stacked pairs",
        "6-op FM: cascade chain",
        "2D wavetable terrain synthesis",
        "Ensemble detuned saws with chorus",
        "4 square oscillators with PWM and arps"
    ]

    init(appState: AppState, trackIndex: Int) {
        self.appState = appState
        self.trackIndex = trackIndex
    }

    func setEngine(model: Int) {
        let clamped = min(max(model, 0), 23)
        engineModel = clamped
        engineTimer?.cancel()
        let t = trackIndex, v = clamped
        engineTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("ENGINE:\(t):\(v)")
        }
    }

    func setTimbre(value: Int) {
        let clamped = min(max(value, 0), 1000)
        timbre = clamped
        timbreTimer?.cancel()
        let t = trackIndex, v = clamped
        timbreTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("TIMBRE:\(t):\(v)")
        }
    }

    func setHarmonics(value: Int) {
        let clamped = min(max(value, 0), 1000)
        harmonics = clamped
        harmonicsTimer?.cancel()
        let t = trackIndex, v = clamped
        harmonicsTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("HARMONICS:\(t):\(v)")
        }
    }

    func setMorph(value: Int) {
        let clamped = min(max(value, 0), 1000)
        morph = clamped
        morphTimer?.cancel()
        let t = trackIndex, v = clamped
        morphTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("MORPH:\(t):\(v)")
        }
    }

    func setVoiceCount(_ count: Int) {
        let clamped = count <= 1 ? 1 : 4
        voiceCount = clamped
        polyCountTimer?.cancel()
        let t = trackIndex, v = clamped
        polyCountTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("POLYCOUNT:\(t):\(v)")
        }
    }

    func requestParams() {
        let t = trackIndex
        Task {
            try? await appState.serialService.send("ENGINEPARAMS:\(t)")
        }
    }

    // MARK: - DX7 Patch Support

    /// True when the current engine is a 6-OP FM engine (18, 19, or 20)
    var is6OpFM: Bool {
        engineModel >= 18 && engineModel <= 20
    }

    func requestDX7List() {
        Task {
            try? await appState.serialService.send("DX7LIST")
        }
    }

    func requestDX7Patches(filename: String) {
        currentDX7File = filename
        dx7PatchNames = []
        dx7SelectedPatch = nil
        Task {
            try? await appState.serialService.send("DX7PATCHES:\(filename)")
        }
    }

    func loadDX7Patch(patchIndex: Int) {
        guard !currentDX7File.isEmpty else { return }
        let t = trackIndex, f = currentDX7File
        dx7SelectedPatch = patchIndex
        dx7Loaded = true
        Task {
            try? await appState.serialService.send("DX7LOAD:\(t):\(patchIndex):\(f)")
        }
    }

    func clearDX7Patch() {
        let t = trackIndex
        dx7SelectedPatch = nil
        dx7Loaded = false
        Task {
            try? await appState.serialService.send("DX7CLEAR:\(t)")
        }
    }
}
