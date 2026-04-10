import SwiftUI

@Observable
@MainActor
final class DrumMachineViewModel {
    let appState: AppState
    var trackIndex: Int
    var selectedPad: Int = 0

    private var padParamTimers: [String: Task<Void, Never>] = [:]

    init(appState: AppState, trackIndex: Int) {
        self.appState = appState
        self.trackIndex = trackIndex
    }

    private var track: TrackState {
        appState.tracks[trackIndex]
    }

    // MARK: - Pad Operations

    func loadPad(_ pad: Int, path: String) {
        let t = trackIndex
        Task {
            try? await appState.serialService.send("LOADPAD:\(t):\(pad):\(path)")
        }
    }

    func clearPad(_ pad: Int) {
        guard pad >= 0 && pad < 8 else { return }
        track.drumPads[pad].samplePath = ""
        track.drumPads[pad].sampleName = ""
        track.drumPads[pad].waveformPeaks = []
        track.drumPads[pad].params = SamplerState()
        let t = trackIndex
        Task {
            try? await appState.serialService.send("CLEARPAD:\(t):\(pad)")
        }
    }

    func setPadParam(_ pad: Int, param: String, value: Int) {
        guard pad >= 0 && pad < 8 else { return }
        let key = "\(pad):\(param)"
        padParamTimers[key]?.cancel()
        let t = trackIndex, p = pad, v = value
        padParamTimers[key] = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("PADPARAM:\(t):\(p):\(param):\(v)")
        }
    }

    func requestPadParams(_ pad: Int) {
        let t = trackIndex
        Task {
            try? await appState.serialService.send("PADPARAMS:\(t):\(pad)")
        }
    }

    func requestPadWaveform(_ pad: Int) {
        let t = trackIndex
        Task {
            try? await appState.serialService.send("PADWAVEFORM:\(t):\(pad)")
        }
    }

    func setDrumMode(enabled: Bool) {
        track.isDrumMachine = enabled
        // Don't override trackType here — the caller (TrackNavigatorView picker) already set it
        let t = trackIndex, v = enabled ? 1 : 0
        Task {
            try? await appState.serialService.send("SETDRUMMODE:\(t):\(v)")
        }
    }

    // MARK: - Pad Parameter Setters (debounced)

    func setPadGain(_ pad: Int, _ value: Int) {
        guard pad >= 0 && pad < 8 else { return }
        let clamped = min(max(value, 0), 100)
        track.drumPads[pad].params.gain = clamped
        setPadParam(pad, param: "gain", value: clamped)
    }

    func setPadPitch(_ pad: Int, _ semitones: Int) {
        guard pad >= 0 && pad < 8 else { return }
        let clamped = min(max(semitones, -24), 24)
        track.drumPads[pad].params.pitchSemitones = clamped
        setPadParam(pad, param: "pitch", value: clamped)
    }

    func setPadCents(_ pad: Int, _ cents: Int) {
        guard pad >= 0 && pad < 8 else { return }
        let clamped = min(max(cents, -50), 50)
        track.drumPads[pad].params.pitchCents = clamped
        setPadParam(pad, param: "cents", value: clamped)
    }

    func setPadStart(_ pad: Int, _ value: Int) {
        guard pad >= 0 && pad < 8 else { return }
        let clamped = max(value, 0)
        track.drumPads[pad].params.sampleStart = clamped
        setPadParam(pad, param: "start", value: clamped)
    }

    func setPadEnd(_ pad: Int, _ value: Int) {
        guard pad >= 0 && pad < 8 else { return }
        let clamped = max(value, 0)
        track.drumPads[pad].params.sampleEnd = clamped
        setPadParam(pad, param: "end", value: clamped)
    }

    func setPadLoop(_ pad: Int, _ enabled: Bool) {
        guard pad >= 0 && pad < 8 else { return }
        track.drumPads[pad].params.loopEnabled = enabled
        setPadParam(pad, param: "loop", value: enabled ? 1 : 0)
    }

    func setPadLoopStart(_ pad: Int, _ value: Int) {
        guard pad >= 0 && pad < 8 else { return }
        let clamped = max(value, 0)
        track.drumPads[pad].params.loopStart = clamped
        setPadParam(pad, param: "loopstart", value: clamped)
    }

    func setPadLoopEnd(_ pad: Int, _ value: Int) {
        guard pad >= 0 && pad < 8 else { return }
        let clamped = max(value, 0)
        track.drumPads[pad].params.loopEnd = clamped
        setPadParam(pad, param: "loopend", value: clamped)
    }

    func setPadOneShot(_ pad: Int, _ enabled: Bool) {
        guard pad >= 0 && pad < 8 else { return }
        track.drumPads[pad].params.oneShot = enabled
        setPadParam(pad, param: "oneshot", value: enabled ? 1 : 0)
    }

    func syncSelectedPad() {
        requestPadParams(selectedPad)
        requestPadWaveform(selectedPad)
    }
}
