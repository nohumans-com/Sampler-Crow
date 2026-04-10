import SwiftUI
import AppKit

@Observable
@MainActor
final class KeyboardViewModel {
    var activeNotes: Set<UInt8> = []
    var octaveOffset: Int = 0  // -3 to +3, each step = 12 semitones
    private let appState: AppState
    private var keyMonitor: Any?
    private var keyUpMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
    }

    // Base note mapping (C4-C5 on the home row)
    private static let keyToBaseNote: [String: Int] = [
        "a": 60, "w": 61, "s": 62, "e": 63, "d": 64,
        "f": 65, "t": 66, "g": 67, "y": 68, "h": 69,
        "u": 70, "j": 71, "k": 72,
    ]

    private func noteForKey(_ key: String) -> UInt8? {
        guard let base = Self.keyToBaseNote[key] else { return nil }
        let transposed = base + (octaveOffset * 12)
        guard transposed >= 0 && transposed <= 127 else { return nil }
        return UInt8(transposed)
    }

    var octaveDisplay: String {
        let baseOctave = 4 + octaveOffset
        return "C\(baseOctave)-C\(baseOctave + 1)"
    }

    func startListening() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard !event.isARepeat else { return event }
            if let handled = self?.handleKeyDown(event), handled {
                return nil
            }
            return event
        }

        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            if let handled = self?.handleKeyUp(event), handled {
                return nil
            }
            return event
        }
    }

    func stopListening() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }
        for note in activeNotes {
            Task {
                await appState.midiService.sendNoteOff(
                    channel: KeyboardMapping.musicalChannel,
                    note: note
                )
            }
        }
        activeNotes.removeAll()
    }

    var onSpacebar: (() -> Void)?

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        if event.window?.firstResponder is NSTextView { return false }

        // Spacebar = play/stop
        if event.keyCode == 49 {
            onSpacebar?()
            return true
        }

        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }

        // Z = octave down, X = octave up
        if chars == "z" {
            if octaveOffset > -3 {
                // Release all notes at old octave before transposing
                releaseAllNotes()
                octaveOffset -= 1
            }
            return true
        }
        if chars == "x" {
            if octaveOffset < 3 {
                releaseAllNotes()
                octaveOffset += 1
            }
            return true
        }

        guard let note = noteForKey(chars) else { return false }
        guard !activeNotes.contains(note) else { return true }
        activeNotes.insert(note)

        Task {
            await appState.midiService.sendNoteOn(
                channel: KeyboardMapping.musicalChannel,
                note: note,
                velocity: KeyboardMapping.defaultVelocity
            )
        }
        return true
    }

    private func handleKeyUp(_ event: NSEvent) -> Bool {
        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }

        // Z/X are handled on keyDown only
        if chars == "z" || chars == "x" { return true }

        guard let note = noteForKey(chars) else { return false }
        guard activeNotes.contains(note) else { return false }
        activeNotes.remove(note)

        Task {
            await appState.midiService.sendNoteOff(
                channel: KeyboardMapping.musicalChannel,
                note: note
            )
        }
        return true
    }

    private func releaseAllNotes() {
        for note in activeNotes {
            Task {
                await appState.midiService.sendNoteOff(
                    channel: KeyboardMapping.musicalChannel,
                    note: note
                )
            }
        }
        activeNotes.removeAll()
    }

    deinit {}
}
