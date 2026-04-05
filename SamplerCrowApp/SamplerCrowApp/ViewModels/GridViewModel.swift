import SwiftUI

@Observable
@MainActor
final class GridViewModel {
    var padColors: [[UInt8]] = Array(repeating: Array(repeating: 0, count: 8), count: 8)
    var pressedPads: Set<String> = []
    var isPlaying = false
    var bpm: Float = 120

    private let appState: AppState
    private let consoleVM: SerialConsoleViewModel

    init(appState: AppState, consoleVM: SerialConsoleViewModel) {
        self.appState = appState
        self.consoleVM = consoleVM
    }

    // Called when a pad is pressed (from virtual grid or real Launchpad)
    func padPressed(row: Int, col: Int, velocity: UInt8 = 127) {
        guard row >= 0 && row < 8 && col >= 0 && col < 8 else {
            print("GridViewModel.padPressed: OUT OF RANGE row=\(row) col=\(col)")
            return
        }

        // Send toggle command via serial (more reliable than MIDI routing)
        let track = row   // row 0 = track 0 (top)
        let step = col    // col 0 = step 0 + pageOffset (TODO: add page support)
        print("GridViewModel.padPressed: row=\(row) col=\(col) -> TOGGLE:\(track):\(step)")
        Task {
            try? await appState.serialService.send("TOGGLE:\(track):\(step)")
        }
    }

    func padReleased(row: Int, col: Int) {
        guard row >= 0 && row < 8 && col >= 0 && col < 8 else { return }
        let note = GridNote.noteFor(row: row, col: col)
        Task {
            await appState.midiService.sendNoteOff(
                channel: KeyboardMapping.gridChannel,
                note: note
            )
        }
    }

    // Handle MIDI from Teensy — grid LED state updates
    func handleTeensyGridMIDI(status: UInt8, note: UInt8, color: UInt8) {
        let msgType = status & 0xF0
        guard msgType == 0x90 else { return }

        if let pos = GridNote.positionFor(note: note) {
            padColors[pos.row][pos.col] = color
            // Mirror to real Launchpad
            Task {
                await appState.launchpadService.setPadColor(note: note, color: color)
            }
        }
    }

    // Handle input from real Launchpad hardware
    func handleLaunchpadInput(note: UInt8, velocity: UInt8, pressed: Bool) {
        print("GridViewModel.handleLaunchpadInput: note=\(note) vel=\(velocity) pressed=\(pressed)")
        if note >= 91 && note <= 98 {
            // Top row function buttons — send as CC to Teensy
            if pressed {
                Task {
                    await appState.midiService.sendCC(
                        channel: KeyboardMapping.gridChannel,
                        cc: note,
                        value: 127
                    )
                }
                // Handle locally too
                switch note {
                case 91: togglePlayStop()
                default: break
                }
            }
            return
        }

        if let pos = GridNote.positionFor(note: note) {
            print("GridViewModel.handleLaunchpadInput: note=\(note) -> pos(row=\(pos.row), col=\(pos.col))")
            if pressed {
                padPressed(row: pos.row, col: pos.col, velocity: velocity)
            } else {
                padReleased(row: pos.row, col: pos.col)
            }
        } else {
            print("GridViewModel.handleLaunchpadInput: note=\(note) has NO grid position mapping")
        }
    }

    func togglePlayStop() {
        isPlaying.toggle()
        Task {
            if isPlaying {
                try? await appState.serialService.send("PLAY")
            } else {
                try? await appState.serialService.send("STOP")
            }
        }
    }

    func clearGrid() {
        Task {
            try? await appState.serialService.send("CLEAR")
            await appState.launchpadService.clearAll()
        }
        padColors = Array(repeating: Array(repeating: 0, count: 8), count: 8)
    }

    func requestGridState() {
        Task {
            try? await appState.serialService.send("GRID")
        }
    }
}
