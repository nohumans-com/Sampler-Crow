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
