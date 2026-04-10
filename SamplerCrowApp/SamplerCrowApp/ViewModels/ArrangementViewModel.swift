import SwiftUI

@Observable
@MainActor
final class ArrangementViewModel {
    let appState: AppState
    var selectedClipID: UUID?
    var horizontalZoom: CGFloat = 1.0

    // Track which clip is being edited in the piano roll
    var editingClipID: UUID?
    var editingClipTrackIndex: Int?

    private static let clipColors: [Color] = [
        .red, .orange, .yellow, .green,
        .cyan, .blue, .purple, .pink
    ]

    init(appState: AppState) {
        self.appState = appState
    }

    func addClip(trackIndex: Int, atBar: Int) {
        guard trackIndex >= 0 && trackIndex < appState.tracks.count else { return }
        let color = Self.clipColors[trackIndex % Self.clipColors.count]
        let clip = ArrangementClip(
            name: "Clip \(appState.tracks[trackIndex].arrangementClips.count + 1)",
            startBar: atBar,
            lengthBars: 4,
            color: color
        )
        appState.tracks[trackIndex].arrangementClips.append(clip)
        selectedClipID = clip.id
    }

    func deleteClip(trackIndex: Int, clipID: UUID) {
        guard trackIndex >= 0 && trackIndex < appState.tracks.count else { return }
        appState.tracks[trackIndex].arrangementClips.removeAll { $0.id == clipID }
        if selectedClipID == clipID {
            selectedClipID = nil
        }
        if editingClipID == clipID {
            editingClipID = nil
            editingClipTrackIndex = nil
        }
    }

    func moveClip(trackIndex: Int, clipID: UUID, toBar: Int) {
        guard trackIndex >= 0 && trackIndex < appState.tracks.count else { return }
        guard let idx = appState.tracks[trackIndex].arrangementClips.firstIndex(where: { $0.id == clipID }) else { return }
        appState.tracks[trackIndex].arrangementClips[idx].startBar = max(toBar, 0)
    }

    func resizeClip(trackIndex: Int, clipID: UUID, newLength: Int) {
        guard trackIndex >= 0 && trackIndex < appState.tracks.count else { return }
        guard let idx = appState.tracks[trackIndex].arrangementClips.firstIndex(where: { $0.id == clipID }) else { return }
        appState.tracks[trackIndex].arrangementClips[idx].lengthBars = max(newLength, 1)
    }

    func duplicateClip(trackIndex: Int, clipID: UUID) {
        guard trackIndex >= 0 && trackIndex < appState.tracks.count else { return }
        guard let original = appState.tracks[trackIndex].arrangementClips.first(where: { $0.id == clipID }) else { return }
        let copy = ArrangementClip(
            name: original.name + " copy",
            startBar: original.startBar + original.lengthBars,
            lengthBars: original.lengthBars,
            color: original.color
        )
        for event in original.midiClip.events {
            copy.midiClip.events.append(MIDIEvent(
                note: event.note,
                velocity: event.velocity,
                startStep: event.startStep,
                duration: event.duration,
                channel: event.channel
            ))
        }
        copy.midiClip.lengthBars = original.midiClip.lengthBars
        copy.midiClip.timeSignature = original.midiClip.timeSignature
        appState.tracks[trackIndex].arrangementClips.append(copy)
        selectedClipID = copy.id
    }
}
