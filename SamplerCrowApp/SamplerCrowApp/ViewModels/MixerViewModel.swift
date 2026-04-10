import SwiftUI

@Observable
@MainActor
final class MixerViewModel {
    static let trackNames = ["Kick", "Snare", "ClHat", "OpHat", "Clap", "Bass", "Lead", "Pluck"]

    var volumes: [Int] = Array(repeating: 80, count: 8)   // 0-100
    var pans: [Int] = Array(repeating: 0, count: 8)        // -100 to +100, 0=center
    var mutes: [Bool] = Array(repeating: false, count: 8)
    var solos: [Bool] = Array(repeating: false, count: 8)
    var levels: [Int] = Array(repeating: 0, count: 8)      // 0-100, from Teensy peak meters

    let appState: AppState

    // Debounce: only send when dragging pauses for 60ms (avoids flooding serial)
    private var volTimer: [Task<Void, Never>?] = Array(repeating: nil, count: 8)
    private var panTimer: [Task<Void, Never>?] = Array(repeating: nil, count: 8)

    init(appState: AppState) {
        self.appState = appState
    }

    func setVolume(_ track: Int, _ value: Int) {
        guard track >= 0 && track < 8 else { return }
        let clamped = min(max(value, 0), 100)
        volumes[track] = clamped
        volTimer[track]?.cancel()
        let t = track, v = clamped
        volTimer[track] = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("VOL:\(t):\(v)")
        }
    }

    func setPan(_ track: Int, _ value: Int) {
        guard track >= 0 && track < 8 else { return }
        let clamped = min(max(value, -100), 100)
        pans[track] = clamped
        panTimer[track]?.cancel()
        let t = track, v = clamped
        panTimer[track] = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("PAN:\(t):\(v)")
        }
    }

    func resetVolume(_ track: Int) {
        setVolume(track, 80)
    }

    func resetPan(_ track: Int) {
        setPan(track, 0)
    }

    func toggleMute(_ track: Int) {
        guard track >= 0 && track < 8 else { return }
        mutes[track].toggle()
        Task {
            try? await appState.serialService.send("MUTE:\(track)")
        }
    }

    func toggleSolo(_ track: Int) {
        guard track >= 0 && track < 8 else { return }
        solos[track].toggle()
        Task {
            try? await appState.serialService.send("SOLO:\(track)")
        }
    }

    private var levelPollTimer: Task<Void, Never>?

    func requestMixerState() {
        Task {
            try? await appState.serialService.send("MIXER")
        }
    }

    func startLevelPolling() {
        levelPollTimer?.cancel()
        levelPollTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))  // 10Hz polling
                guard !Task.isCancelled else { break }
                try? await appState.serialService.send("LVL")
            }
        }
    }

    func stopLevelPolling() {
        levelPollTimer?.cancel()
        levelPollTimer = nil
    }

    func handleMixerResponse(_ line: String) {
        let sections = line.split(separator: "|")
        guard sections.count >= 3 else { return }

        let vols = sections[0].split(separator: ",").compactMap { Int($0) }
        if vols.count == 8 { volumes = vols }

        let mts = sections[1].split(separator: ",").map { $0 == "1" }
        if mts.count == 8 { mutes = mts }

        let sls = sections[2].split(separator: ",").map { $0 == "1" }
        if sls.count == 8 { solos = sls }

        if sections.count >= 4 {
            let pns = sections[3].split(separator: ",").compactMap { Int($0) }
            if pns.count == 8 { pans = pns }
        }
    }

    func handleLevelData(_ line: String) {
        let vals = line.split(separator: ",").compactMap { Int($0) }
        if vals.count == 8 { levels = vals }
    }
}
