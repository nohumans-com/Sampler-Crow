import SwiftUI
import AppKit

@Observable
@MainActor
final class KeyboardViewModel {
    var activeNotes: Set<UInt8> = []
    private let appState: AppState
    private var keyMonitor: Any?
    private var keyUpMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
    }

    func startListening() {
        // Monitor key down events
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard !event.isARepeat else { return event }
            if let handled = self?.handleKeyDown(event), handled {
                return nil // consume the event
            }
            return event
        }

        // Monitor key up events
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
        // Release all active notes
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

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Don't intercept if a text field is focused
        if event.window?.firstResponder is NSTextView { return false }

        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              let note = KeyboardMapping.keyToNote[chars] else {
            return false
        }

        guard !activeNotes.contains(note) else { return true } // already playing
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
        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              let note = KeyboardMapping.keyToNote[chars] else {
            return false
        }

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

    deinit {
        // Can't call stopListening from deinit in actor context,
        // but monitors will be cleaned up when the app exits
    }
}
