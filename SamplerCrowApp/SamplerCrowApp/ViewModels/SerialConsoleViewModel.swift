import SwiftUI

@Observable
@MainActor
final class SerialConsoleViewModel {
    var entries: [LogEntry] = []
    var commandText: String = ""
    var commandHistory: [String] = []
    private var historyIndex: Int = -1

    private let appState: AppState
    private let maxEntries = 500
    var gridViewModel: GridViewModel?
    var mixerViewModel: MixerViewModel?
    var fileBrowserViewModel: FileBrowserViewModel?
    var clipEditorViewModel: ClipEditorViewModel?
    var synthEngineViewModel: SynthEngineViewModel?

    init(appState: AppState) {
        self.appState = appState
    }

    func log(_ text: String, type: LogEntry.LogType = .info) {
        entries.append(LogEntry(text, type: type))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func handleIncomingLine(_ line: String) {
        // Parse known status messages and update AppState silently
        if line.hasPrefix("CPU:") {
            appState.cpuUsage = String(line.dropFirst(4)) + "%"
            return
        }
        if line.hasPrefix("MEM:") {
            appState.memUsage = String(line.dropFirst(4))
            return
        }
        // Parse grid state: GRD:c0,c1,...,c63
        if line.hasPrefix("GRD:") {
            let data = String(line.dropFirst(4))
            let colors = data.split(separator: ",").compactMap { UInt8($0) }
            if colors.count == 64 {
                for row in 0..<8 {
                    for col in 0..<8 {
                        gridViewModel?.padColors[row][col] = colors[row * 8 + col]
                    }
                }
                // Also mirror to real Launchpad
                if let gvm = gridViewModel {
                    Task {
                        await appState.launchpadService.updateGrid(gvm.padColors)
                    }
                }
            }
            return
        }
        // Parse sequencer state: SEQ:playing:step:bpm
        if line.hasPrefix("SEQ:") {
            let parts = String(line.dropFirst(4)).split(separator: ":")
            if parts.count >= 3 {
                gridViewModel?.isPlaying = parts[0] == "1"
                if let bpm = Float(parts[2]) {
                    gridViewModel?.bpm = bpm
                }
            }
            return
        }
        // Parse step update: STEP:N
        if line.hasPrefix("STEP:") {
            if let step = Int(line.dropFirst(5)) {
                gridViewModel?.handleStepUpdate(step)
            }
            return
        }
        // Parse mixer state: MIX:vol0,vol1,...|mute0,...|solo0,...
        if line.hasPrefix("MIX:") {
            let data = String(line.dropFirst(4))
            mixerViewModel?.handleMixerResponse(data)
            return
        }
        // Parse level meters: LVL:l0,l1,...,l7
        if line.hasPrefix("LVL:") {
            let data = String(line.dropFirst(4))
            mixerViewModel?.handleLevelData(data)
            return
        }
        // Parse step data: STEPDATA:track:step:note:velocity:gate
        if line.hasPrefix("STEPDATA:") {
            let parts = String(line.dropFirst(9)).split(separator: ":")
            if parts.count >= 5,
               let track = Int(parts[0]),
               let step = Int(parts[1]),
               let note = Int(parts[2]),
               let velocity = Int(parts[3]),
               let gate = Int(parts[4]) {
                gridViewModel?.handleStepData(track: track, step: step, note: note, velocity: velocity, gate: gate)
            }
            return
        }
        // Directory listing responses
        if line.hasPrefix("DIRLIST:") {
            fileBrowserViewModel?.handleDirList(String(line.dropFirst(8)))
            return
        }
        if line.hasPrefix("F:") {
            let parts = String(line.dropFirst(2)).split(separator: ":", maxSplits: 1)
            if parts.count == 2, let size = Int(parts[1]) {
                fileBrowserViewModel?.handleFileEntry(String(parts[0]), size: size)
            }
            return
        }
        if line.hasPrefix("D:") {
            fileBrowserViewModel?.handleDirEntry(String(line.dropFirst(2)))
            return
        }
        if line == "ENDDIR" {
            fileBrowserViewModel?.handleEndDir()
            return
        }
        // Chop slice data: CHOPSLICES:track:count:b0,b1,b2,...
        if line.hasPrefix("CHOPSLICES:") {
            let parts = String(line.dropFirst(11)).split(separator: ":")
            if parts.count >= 3,
               let track = Int(parts[0]),
               let count = Int(parts[1]) {
                let boundaries = parts[2].split(separator: ",").compactMap { Int($0) }
                if track >= 0 && track < appState.tracks.count {
                    appState.tracks[track].samplerState.chopSliceCount = count
                    appState.tracks[track].samplerState.chopSliceBoundaries = boundaries
                }
            }
            return
        }
        // Sampler params response: SPARAMS:track:gain:pitch:cents:start:end:loop:ls:le:oneshot[:mode:rootnote:attack:decay:sustain:release:grainpos:grainwin:grainsize:graincount:grainspread:grainenv:chopsens:choptrig]
        if line.hasPrefix("SPARAMS:") {
            let parts = String(line.dropFirst(8)).split(separator: ":").compactMap { Int($0) }
            if parts.count >= 10 {
                let track = parts[0]
                if track >= 0 && track < appState.tracks.count {
                    let s = appState.tracks[track].samplerState
                    s.gain = parts[1]
                    s.pitchSemitones = parts[2]
                    s.pitchCents = parts[3]
                    s.sampleStart = parts[4]
                    s.sampleEnd = parts[5]
                    s.loopEnabled = parts[6] != 0
                    s.loopStart = parts[7]
                    s.loopEnd = parts[8]
                    s.oneShot = parts[9] != 0
                    // Extended fields
                    if parts.count >= 11 { s.samplerMode = parts[10] }
                    if parts.count >= 12 { s.rootNote = parts[11] }
                    if parts.count >= 13 { s.attackMs = parts[12] }
                    if parts.count >= 14 { s.decayMs = parts[13] }
                    if parts.count >= 15 { s.sustainLevel = parts[14] }
                    if parts.count >= 16 { s.releaseMs = parts[15] }
                    if parts.count >= 17 { s.grainPosition = parts[16] }
                    if parts.count >= 18 { s.grainWindowSize = parts[17] }
                    if parts.count >= 19 { s.grainSizeMs = parts[18] }
                    if parts.count >= 20 { s.grainCount = parts[19] }
                    if parts.count >= 21 { s.grainSpread = parts[20] }
                    if parts.count >= 22 { s.grainEnvShape = parts[21] }
                    if parts.count >= 23 { s.chopSensitivity = parts[22] }
                    if parts.count >= 24 { s.chopTriggerMode = parts[23] }
                }
            }
            return
        }
        // Waveform data: WFORM:track:p0,p1,...,p127
        if line.hasPrefix("WFORM:") {
            let payload = String(line.dropFirst(6))
            let colonIdx = payload.firstIndex(of: ":")
            if let ci = colonIdx,
               let track = Int(payload[payload.startIndex..<ci]) {
                let peakStr = payload[payload.index(after: ci)...]
                let peaks = peakStr.split(separator: ",").compactMap { UInt8($0) }
                if track >= 0 && track < appState.tracks.count && peaks.count == 128 {
                    appState.tracks[track].samplerState.waveformPeaks = peaks
                }
            }
            return
        }
        // Pad params response: PPARAMS:track:pad:gain:pitch:cents:start:end:loop:ls:le:oneshot
        if line.hasPrefix("PPARAMS:") {
            let parts = String(line.dropFirst(8)).split(separator: ":").compactMap { Int($0) }
            if parts.count >= 11 {
                let track = parts[0], pad = parts[1]
                if track >= 0 && track < appState.tracks.count && pad >= 0 && pad < 8 {
                    let p = appState.tracks[track].drumPads[pad].params
                    p.gain = parts[2]
                    p.pitchSemitones = parts[3]
                    p.pitchCents = parts[4]
                    p.sampleStart = parts[5]
                    p.sampleEnd = parts[6]
                    p.loopEnabled = parts[7] != 0
                    p.loopStart = parts[8]
                    p.loopEnd = parts[9]
                    p.oneShot = parts[10] != 0
                }
            }
            return
        }
        // Pad waveform data: PADWFORM:track:pad:p0,p1,...,p127
        if line.hasPrefix("PADWFORM:") {
            let payload = String(line.dropFirst(9))
            let parts = payload.split(separator: ":", maxSplits: 2)
            if parts.count >= 3,
               let track = Int(parts[0]),
               let pad = Int(parts[1]) {
                let peaks = parts[2].split(separator: ",").compactMap { UInt8($0) }
                if track >= 0 && track < appState.tracks.count && pad >= 0 && pad < 8 {
                    appState.tracks[track].drumPads[pad].waveformPeaks = peaks
                }
            }
            return
        }
        // Clip data response: CLIP:track:n,v,g,p;n,v,g,p;...
        if line.hasPrefix("CLIP:") {
            let payload = String(line.dropFirst(5))
            if let colonIdx = payload.firstIndex(of: ":"),
               let track = Int(payload[payload.startIndex..<colonIdx]) {
                let data = String(payload[payload.index(after: colonIdx)...])
                if track >= 0 && track < appState.tracks.count {
                    clipEditorViewModel?.handleClipResponse(data)
                }
            }
            return
        }
        // Engine params response: EPARAMS:track:engine:timbre:harmonics:morph:enabled:voiceCount
        if line.hasPrefix("EPARAMS:") {
            let parts = String(line.dropFirst(8)).split(separator: ":").compactMap { Int($0) }
            if parts.count >= 5 {
                let track = parts[0]
                if track >= 0 && track < appState.tracks.count {
                    if synthEngineViewModel?.trackIndex == track {
                        synthEngineViewModel?.engineModel = parts[1]
                        synthEngineViewModel?.timbre = parts[2]
                        synthEngineViewModel?.harmonics = parts[3]
                        synthEngineViewModel?.morph = parts[4]
                        if parts.count >= 7 {
                            synthEngineViewModel?.voiceCount = parts[6]
                        }
                    }
                }
            }
            return
        }
        // DX7 file list: DX7FILES:file1.syx,file2.syx,...
        if line.hasPrefix("DX7FILES:") {
            let data = String(line.dropFirst(9))
            let files = data.split(separator: ",").map { String($0) }
            synthEngineViewModel?.dx7Files = files
            return
        }
        // DX7 patch names: DX7NAMES:name1,name2,...,name32
        if line.hasPrefix("DX7NAMES:") {
            let data = String(line.dropFirst(9))
            let names = data.split(separator: ",").map { String($0) }
            synthEngineViewModel?.dx7PatchNames = names
            return
        }
        // Sampler param acknowledgments — silent
        if line.hasPrefix("ACK:SAMPLEPARAM:") || line.hasPrefix("ACK:LOADPAD:") || line.hasPrefix("ACK:CLEARPAD:") || line.hasPrefix("ACK:SETDRUMMODE:") || line.hasPrefix("ACK:DX7LOAD:") || line.hasPrefix("ACK:DX7CLEAR:") || line.hasPrefix("ACK:DX7UPLOAD:") || line.hasPrefix("ACK:MKDIR") || line.hasPrefix("ACK:DELETEFILE") || line.hasPrefix("ACK:UPLOAD") {
            return
        }
        // Mixer command acknowledgments — show in console for verification
        if line.hasPrefix("ACK:") {
            log("< \(line)", type: .incoming)
            return
        }
        // Filter out noisy POT readings (floating pins)
        if line.hasPrefix("POT:") {
            return
        }
        if line.hasPrefix("BTN:") {
            return
        }

        log("< \(line)", type: .incoming)
    }

    func sendCommand() {
        let command = commandText.trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty else { return }

        log("> \(command)", type: .outgoing)
        commandHistory.append(command)
        historyIndex = -1
        commandText = ""

        Task {
            do {
                try await appState.serialService.send(command)
            } catch {
                log("Error: \(error.localizedDescription)", type: .info)
            }
        }
    }

    func connect() {
        Task {
            guard let path = SerialService.findTeensySerialPort() else {
                log("No Teensy serial port found", type: .info)
                appState.connectionStatus.serial = .error("Not found")
                return
            }

            log("Connecting to \(path)...", type: .info)
            appState.connectionStatus.serial = .connecting

            do {
                try await appState.serialService.connect(path: path) { [weak self] line in
                    Task { @MainActor in
                        self?.handleIncomingLine(line)
                    }
                }
                appState.connectionStatus.serial = .connected
                log("Serial connected", type: .info)

                // Send PING to verify
                try await appState.serialService.send("PING")

                // Also connect MIDI
                do {
                    try await appState.midiService.connect { [weak self] status, data1, data2 in
                        Task { @MainActor in
                            self?.handleMIDIMessage(status, data1, data2)
                        }
                    }
                    appState.connectionStatus.midi = .connected
                    log("MIDI connected", type: .info)
                } catch {
                    appState.connectionStatus.midi = .error(error.localizedDescription)
                    log("MIDI: \(error.localizedDescription)", type: .info)
                }

                // Also connect Audio — request mic permission first (async, non-blocking)
                let micGranted = await appState.audioService.requestMicrophonePermission()
                if !micGranted {
                    log("Audio: microphone permission not granted — capture will be silent. Enable in System Settings > Privacy & Security > Microphone.", type: .info)
                }
                do {
                    try appState.audioService.connect()
                    appState.connectionStatus.audio = .connected
                    log("Audio connected", type: .info)
                } catch {
                    appState.connectionStatus.audio = .error(error.localizedDescription)
                    log("Audio: \(error.localizedDescription)", type: .info)
                }

                // Connect Launchpad hardware
                do {
                    try await appState.launchpadService.connect { [weak self] note, vel, pressed in
                        Task { @MainActor in
                            self?.gridViewModel?.handleLaunchpadInput(note: note, velocity: vel, pressed: pressed)
                        }
                    }
                    log("Launchpad connected!", type: .info)
                    gridViewModel?.requestGridState()
                } catch {
                    log("Launchpad: \(error.localizedDescription)", type: .info)
                }
            } catch {
                appState.connectionStatus.serial = .error(error.localizedDescription)
                log("Serial error: \(error.localizedDescription)", type: .info)
            }
        }
    }

    func disconnect() {
        Task {
            await appState.serialService.disconnect()
            await appState.midiService.disconnect()
            appState.audioService.disconnect()
            await appState.launchpadService.disconnect()
            appState.connectionStatus.serial = .disconnected
            appState.connectionStatus.midi = .disconnected
            appState.connectionStatus.audio = .disconnected
            log("Disconnected", type: .info)
        }
    }

    func handleMIDIMessage(_ status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        let channel = (status & 0x0F) + 1
        let msgType = status & 0xF0

        // Route grid channel to GridViewModel
        if channel == KeyboardMapping.gridChannel {
            gridViewModel?.handleTeensyGridMIDI(status: status, note: data1, color: data2)
            return
        }

        switch msgType {
        case 0x90 where data2 > 0:
            log("< MIDI NoteOn ch\(channel) note=\(data1) vel=\(data2)", type: .incoming)
        case 0x80, 0x90:
            log("< MIDI NoteOff ch\(channel) note=\(data1)", type: .incoming)
        case 0xB0:
            log("< MIDI CC ch\(channel) cc=\(data1) val=\(data2)", type: .incoming)
        default:
            break
        }
    }

    func historyUp() {
        guard !commandHistory.isEmpty else { return }
        if historyIndex < 0 {
            historyIndex = commandHistory.count - 1
        } else if historyIndex > 0 {
            historyIndex -= 1
        }
        commandText = commandHistory[historyIndex]
    }

    func historyDown() {
        guard historyIndex >= 0 else { return }
        historyIndex += 1
        if historyIndex >= commandHistory.count {
            historyIndex = -1
            commandText = ""
        } else {
            commandText = commandHistory[historyIndex]
        }
    }
}
