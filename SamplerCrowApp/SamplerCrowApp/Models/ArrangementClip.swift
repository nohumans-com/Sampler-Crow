import SwiftUI

@Observable
class ArrangementClip: Identifiable {
    let id = UUID()
    var name: String
    var startBar: Int
    var lengthBars: Int
    var color: Color
    var midiClip: MIDIClip

    init(name: String = "New Clip", startBar: Int = 0, lengthBars: Int = 4, color: Color = .blue) {
        self.name = name
        self.startBar = startBar
        self.lengthBars = lengthBars
        self.color = color
        self.midiClip = MIDIClip()
    }
}
