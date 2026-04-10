import SwiftUI

@Observable
@MainActor
final class PianoRollViewModel {
    let appState: AppState
    var trackIndex: Int

    var selectedEventIDs: Set<UUID> = []
    var horizontalZoom: CGFloat = 1.0
    var verticalZoom: CGFloat = 1.0   // 1.0 = 12px row height
    var timeSignature: TimeSignature = TimeSignature()
    var selectedCCNumber: Int = 1     // default to Mod Wheel

    // When editing an arrangement clip directly
    var editingArrangementClipID: UUID?

    init(appState: AppState, trackIndex: Int) {
        self.appState = appState
        self.trackIndex = trackIndex
    }

    var clip: MIDIClip {
        // If editing an arrangement clip, return that clip's MIDI data
        if let clipID = editingArrangementClipID {
            for track in appState.tracks {
                if let arrClip = track.arrangementClips.first(where: { $0.id == clipID }) {
                    return arrClip.midiClip
                }
            }
        }
        return appState.tracks[trackIndex].midiClip
    }

    func addNote(atStep step: Double, note: Int) {
        let cNote = min(max(note, 24), 108)
        let cStep = max(step, 0)
        let event = MIDIEvent(note: cNote, velocity: 100, startStep: cStep, duration: 1, channel: 0)
        clip.events.append(event)
        selectedEventIDs = [event.id]
    }

    func deleteNote(id: UUID) {
        clip.events.removeAll { $0.id == id }
        selectedEventIDs.remove(id)
    }

    func deleteSelected() {
        clip.events.removeAll { selectedEventIDs.contains($0.id) }
        selectedEventIDs.removeAll()
    }

    func moveNote(id: UUID, toStep: Double, toNote: Int) {
        guard let idx = clip.events.firstIndex(where: { $0.id == id }) else { return }
        clip.events[idx].startStep = max(toStep, 0)
        clip.events[idx].note = min(max(toNote, 24), 108)
    }

    func moveSelected(deltaStep: Double, deltaPitch: Int) {
        for id in selectedEventIDs {
            guard let idx = clip.events.firstIndex(where: { $0.id == id }) else { continue }
            clip.events[idx].startStep = max(clip.events[idx].startStep + deltaStep, 0)
            clip.events[idx].note = min(max(clip.events[idx].note + deltaPitch, 24), 108)
        }
    }

    func resizeNote(id: UUID, newDuration: Double) {
        guard let idx = clip.events.firstIndex(where: { $0.id == id }) else { return }
        clip.events[idx].duration = max(newDuration, 0.25)
    }

    func setVelocity(id: UUID, velocity: Int) {
        guard let idx = clip.events.firstIndex(where: { $0.id == id }) else { return }
        clip.events[idx].velocity = min(max(velocity, 1), 127)
    }

    func selectNote(id: UUID?, addToSelection: Bool = false) {
        guard let id = id else {
            if !addToSelection { selectedEventIDs.removeAll() }
            return
        }
        if addToSelection {
            if selectedEventIDs.contains(id) {
                selectedEventIDs.remove(id)
            } else {
                selectedEventIDs.insert(id)
            }
        } else {
            selectedEventIDs = [id]
        }
    }

    func selectNotes(ids: Set<UUID>) {
        selectedEventIDs = ids
    }

    func deselectAll() {
        selectedEventIDs.removeAll()
    }

    func isSelected(_ id: UUID) -> Bool {
        selectedEventIDs.contains(id)
    }

    // CC Automation
    func addCCPoint(step: Double, value: Int) {
        let point = CCPoint(step: step, value: min(max(value, 0), 127), cc: selectedCCNumber)
        clip.ccAutomation.append(point)
    }

    func moveCCPoint(id: UUID, toStep: Double, toValue: Int) {
        guard let idx = clip.ccAutomation.firstIndex(where: { $0.id == id }) else { return }
        clip.ccAutomation[idx].step = max(toStep, 0)
        clip.ccAutomation[idx].value = min(max(toValue, 0), 127)
    }

    func deleteCCPoint(id: UUID) {
        clip.ccAutomation.removeAll { $0.id == id }
    }

    var filteredCCPoints: [CCPoint] {
        clip.ccAutomation.filter { $0.cc == selectedCCNumber }.sorted { $0.step < $1.step }
    }

    func syncToTeensy() {
        let t = trackIndex
        let events = clip.events
        let maxSteps = clip.lengthSteps

        Task {
            // Clear the track first
            try? await appState.serialService.send("TRACKCLEAR:\(t)")
            try? await Task.sleep(for: .milliseconds(20))

            // For each MIDI event, set the corresponding step
            for event in events {
                let step = Int(event.startStep)
                if step >= 0 && step < maxSteps {
                    try? await appState.serialService.send("SETNOTE:\(t):\(step):\(event.note):\(event.velocity)")
                    try? await Task.sleep(for: .milliseconds(5))  // pace serial
                }
            }
        }
    }
}
