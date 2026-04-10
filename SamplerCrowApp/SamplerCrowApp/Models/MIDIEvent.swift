import Foundation

struct MIDIEvent: Identifiable, Equatable {
    let id: UUID
    var note: Int           // 24 (C1) to 108 (C7)
    var velocity: Int       // 1-127
    var startStep: Double   // fractional for sub-step precision
    var duration: Double    // in steps
    var channel: Int        // 0-15

    init(note: Int = 60, velocity: Int = 100, startStep: Double = 0, duration: Double = 1, channel: Int = 0) {
        self.id = UUID()
        self.note = note
        self.velocity = velocity
        self.startStep = startStep
        self.duration = duration
        self.channel = channel
    }
}
