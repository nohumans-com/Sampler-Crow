import SwiftUI

@Observable
@MainActor
final class SamplerViewModel {
    let appState: AppState
    var trackIndex: Int

    private var gainTimer: Task<Void, Never>?
    private var pitchTimer: Task<Void, Never>?
    private var centsTimer: Task<Void, Never>?
    private var startTimer: Task<Void, Never>?
    private var endTimer: Task<Void, Never>?
    private var loopStartTimer: Task<Void, Never>?
    private var loopEndTimer: Task<Void, Never>?
    private var attackTimer: Task<Void, Never>?
    private var decayTimer: Task<Void, Never>?
    private var sustainTimer: Task<Void, Never>?
    private var releaseTimer: Task<Void, Never>?
    private var grainPosTimer: Task<Void, Never>?
    private var grainWinTimer: Task<Void, Never>?
    private var grainSizeTimer: Task<Void, Never>?
    private var grainCountTimer: Task<Void, Never>?
    private var grainSpreadTimer: Task<Void, Never>?
    private var chopSensTimer: Task<Void, Never>?

    static let noteNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
    static func noteName(_ note: Int) -> String {
        let octave = (note / 12) - 1
        let name = noteNames[note % 12]
        return "\(name)\(octave)"
    }

    init(appState: AppState, trackIndex: Int) {
        self.appState = appState
        self.trackIndex = trackIndex
    }

    private var state: SamplerState {
        appState.tracks[trackIndex].samplerState
    }

    func setGain(_ value: Int) {
        let clamped = min(max(value, 0), 100)
        state.gain = clamped
        gainTimer?.cancel()
        let t = trackIndex, v = clamped
        gainTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):gain:\(v)")
        }
    }

    func setPitch(_ semitones: Int) {
        let clamped = min(max(semitones, -24), 24)
        state.pitchSemitones = clamped
        pitchTimer?.cancel()
        let t = trackIndex, v = clamped
        pitchTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):pitch:\(v)")
        }
    }

    func setCents(_ cents: Int) {
        let clamped = min(max(cents, -50), 50)
        state.pitchCents = clamped
        centsTimer?.cancel()
        let t = trackIndex, v = clamped
        centsTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):cents:\(v)")
        }
    }

    func setStart(_ value: Int) {
        let clamped = max(value, 0)
        state.sampleStart = clamped
        startTimer?.cancel()
        let t = trackIndex, v = clamped
        startTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):start:\(v)")
        }
    }

    func setEnd(_ value: Int) {
        let clamped = max(value, 0)
        state.sampleEnd = clamped
        endTimer?.cancel()
        let t = trackIndex, v = clamped
        endTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):end:\(v)")
        }
    }

    func setLoop(_ enabled: Bool) {
        state.loopEnabled = enabled
        let t = trackIndex, v = enabled ? 1 : 0
        Task {
            try? await appState.serialService.send("SAMPLEPARAM:\(t):loop:\(v)")
        }
    }

    func setLoopStart(_ value: Int) {
        let clamped = max(value, 0)
        state.loopStart = clamped
        loopStartTimer?.cancel()
        let t = trackIndex, v = clamped
        loopStartTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):loopstart:\(v)")
        }
    }

    func setLoopEnd(_ value: Int) {
        let clamped = max(value, 0)
        state.loopEnd = clamped
        loopEndTimer?.cancel()
        let t = trackIndex, v = clamped
        loopEndTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):loopend:\(v)")
        }
    }

    func setOneShot(_ enabled: Bool) {
        state.oneShot = enabled
        let t = trackIndex, v = enabled ? 1 : 0
        Task {
            try? await appState.serialService.send("SAMPLEPARAM:\(t):oneshot:\(v)")
        }
    }

    func setMode(_ mode: Int) {
        let clamped = min(max(mode, 0), 2)
        state.samplerMode = clamped
        let t = trackIndex, v = clamped
        Task {
            try? await appState.serialService.send("SAMPLEPARAM:\(t):mode:\(v)")
        }
    }

    func setRootNote(_ note: Int) {
        let clamped = min(max(note, 0), 127)
        state.rootNote = clamped
        let t = trackIndex, v = clamped
        Task {
            try? await appState.serialService.send("SAMPLEPARAM:\(t):rootnote:\(v)")
        }
    }

    func setAttack(_ ms: Int) {
        let clamped = min(max(ms, 0), 500)
        state.attackMs = clamped
        attackTimer?.cancel()
        let t = trackIndex, v = clamped
        attackTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):attack:\(v)")
        }
    }

    func setDecay(_ ms: Int) {
        let clamped = min(max(ms, 0), 500)
        state.decayMs = clamped
        decayTimer?.cancel()
        let t = trackIndex, v = clamped
        decayTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):decay:\(v)")
        }
    }

    func setSustain(_ level: Int) {
        let clamped = min(max(level, 0), 100)
        state.sustainLevel = clamped
        sustainTimer?.cancel()
        let t = trackIndex, v = clamped
        sustainTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):sustain:\(v)")
        }
    }

    func setRelease(_ ms: Int) {
        let clamped = min(max(ms, 0), 500)
        state.releaseMs = clamped
        releaseTimer?.cancel()
        let t = trackIndex, v = clamped
        releaseTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):release:\(v)")
        }
    }

    func setGrainPosition(_ val: Int) {
        let clamped = min(max(val, 0), 100)
        state.grainPosition = clamped
        grainPosTimer?.cancel()
        let t = trackIndex, v = clamped
        grainPosTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):grainpos:\(v)")
        }
    }

    func setGrainWindowSize(_ val: Int) {
        let clamped = min(max(val, 0), 100)
        state.grainWindowSize = clamped
        grainWinTimer?.cancel()
        let t = trackIndex, v = clamped
        grainWinTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):grainwin:\(v)")
        }
    }

    func setGrainSize(_ ms: Int) {
        let clamped = min(max(ms, 10), 500)
        state.grainSizeMs = clamped
        grainSizeTimer?.cancel()
        let t = trackIndex, v = clamped
        grainSizeTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):grainsize:\(v)")
        }
    }

    func setGrainCount(_ count: Int) {
        let clamped = min(max(count, 1), 16)
        state.grainCount = clamped
        grainCountTimer?.cancel()
        let t = trackIndex, v = clamped
        grainCountTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):graincount:\(v)")
        }
    }

    func setGrainSpread(_ val: Int) {
        let clamped = min(max(val, 0), 100)
        state.grainSpread = clamped
        grainSpreadTimer?.cancel()
        let t = trackIndex, v = clamped
        grainSpreadTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):grainspread:\(v)")
        }
    }

    func setGrainEnvShape(_ shape: Int) {
        let clamped = min(max(shape, 0), 3)
        state.grainEnvShape = clamped
        let t = trackIndex, v = clamped
        Task {
            try? await appState.serialService.send("SAMPLEPARAM:\(t):grainenv:\(v)")
        }
    }

    func setChopSensitivity(_ val: Int) {
        let clamped = min(max(val, 0), 100)
        state.chopSensitivity = clamped
        chopSensTimer?.cancel()
        let t = trackIndex, v = clamped
        chopSensTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SAMPLEPARAM:\(t):chopsens:\(v)")
        }
    }

    func setChopTriggerMode(_ mode: Int) {
        let clamped = min(max(mode, 0), 1)
        state.chopTriggerMode = clamped
        let t = trackIndex, v = clamped
        Task {
            try? await appState.serialService.send("SAMPLEPARAM:\(t):choptrig:\(v)")
        }
    }

    func requestParams() {
        let t = trackIndex
        Task {
            try? await appState.serialService.send("SAMPLEPARAMS:\(t)")
        }
    }

    func requestWaveform() {
        let t = trackIndex
        Task {
            try? await appState.serialService.send("WAVEFORM:\(t)")
        }
    }
}
