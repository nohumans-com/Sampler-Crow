import SwiftUI

@Observable
@MainActor
final class GridViewModel {
    var padColors: [[UInt8]] = Array(repeating: Array(repeating: 0, count: 8), count: 8)
    var pressedPads: Set<String> = []
    var isPlaying = false
    var bpm: Float = 120

    // Step editing state
    var selectedStep: (track: Int, step: Int)?
    var stepVelocity: Int = 100
    var stepNote: Int = 60

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

        let track = row   // row 0 = track 0 (top)
        let step = col    // col 0 = step 0 + pageOffset (TODO: add page support)

        // If pad is active, open step editor; if empty, toggle it on
        let colorIdx = padColors[row][col]
        let isActive = colorIdx > 1  // 0=off, 1=dim playhead, >1=has note
        if isActive {
            selectStep(track: track, step: step)
        } else {
            print("GridViewModel.padPressed: row=\(row) col=\(col) -> TOGGLE:\(track):\(step)")
            Task {
                try? await appState.serialService.send("TOGGLE:\(track):\(step)")
            }
        }
    }

    // Select a step for editing — queries firmware for current values
    func selectStep(track: Int, step: Int) {
        selectedStep = (track: track, step: step)
        Task {
            try? await appState.serialService.send("GETSTEP:\(track):\(step)")
        }
    }

    // Set velocity for the currently selected step
    func setStepVelocity(_ velocity: Int) {
        guard let sel = selectedStep else { return }
        let vel = max(0, min(127, velocity))
        stepVelocity = vel
        Task {
            try? await appState.serialService.send("SETVEL:\(sel.track):\(sel.step):\(vel)")
        }
    }

    // Set note for the currently selected step
    func setStepNote(_ note: Int) {
        guard let sel = selectedStep else { return }
        let n = max(0, min(127, note))
        stepNote = n
        Task {
            try? await appState.serialService.send("SETNOTE:\(sel.track):\(sel.step):\(n)")
        }
    }

    // Handle STEPDATA response from firmware
    func handleStepData(track: Int, step: Int, note: Int, velocity: Int, gate: Int) {
        guard let sel = selectedStep, sel.track == track, sel.step == step else { return }
        stepNote = note
        stepVelocity = velocity
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

    /// Handle lightweight STEP:N messages from Teensy (replaces full GRD: per step)
    /// Updates playhead position on the local grid and mirrors to Launchpad
    func handleStepUpdate(_ step: Int) {
        guard step >= 0 && step < 8 else { return }
        let prevStep = step == 0 ? 7 : step - 1

        // Track colors for reverting previous step
        let trackColorPalette: [UInt8] = [5, 9, 13, 21, 37, 45, 49, 53]

        for row in 0..<8 {
            // Revert previous step column
            let wasActive = padColors[row][prevStep] == 3 || padColors[row][prevStep] == 1
            if wasActive {
                // Check if this step had a pattern color before playhead
                // If the step was bright white (3), it had a note; if dim white (1), it was empty
                let hadNote = padColors[row][prevStep] == 3
                padColors[row][prevStep] = hadNote ? trackColorPalette[row] : 0
            }

            // Set current step to playhead color
            let hasNote = padColors[row][step] != 0 && padColors[row][step] != 1
            padColors[row][step] = hasNote ? 3 : 1  // bright or dim playhead
        }

        // Mirror to Launchpad
        Task {
            await appState.launchpadService.updateGrid(padColors)
        }
    }
}
