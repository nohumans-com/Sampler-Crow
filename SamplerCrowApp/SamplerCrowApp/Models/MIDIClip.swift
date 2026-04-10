import SwiftUI

struct TimeSignature: Equatable, Sendable {
    var numerator: Int = 4    // beats per bar
    var denominator: Int = 4  // beat unit (4=quarter, 8=eighth)

    var stepsPerBeat: Int { denominator >= 8 ? 2 : 4 }  // 16th note steps for quarter, 8th for eighth
    var stepsPerBar: Int { numerator * stepsPerBeat }

    var display: String { "\(numerator)/\(denominator)" }

    static let common: [(String, Int, Int)] = [
        ("4/4", 4, 4), ("3/4", 3, 4), ("6/8", 6, 8), ("5/8", 5, 8),
        ("2/4", 2, 4), ("7/8", 7, 8), ("5/4", 5, 4), ("12/8", 12, 8)
    ]

    init(numerator: Int = 4, denominator: Int = 4) {
        self.numerator = numerator
        self.denominator = denominator
    }

    static let fourFour = TimeSignature(numerator: 4, denominator: 4)
    static let threeFour = TimeSignature(numerator: 3, denominator: 4)
    static let sixEight = TimeSignature(numerator: 6, denominator: 8)
    static let fiveEight = TimeSignature(numerator: 5, denominator: 8)
}

struct CCPoint: Identifiable, Equatable, Sendable {
    let id = UUID()
    var step: Double    // fractional step position
    var value: Int      // 0-127
    var cc: Int         // CC number 0-127
}

@Observable
class MIDIClip {
    var events: [MIDIEvent] = []
    var ccAutomation: [CCPoint] = []
    var lengthBars: Int = 4       // 1-16
    var timeSignature: TimeSignature = TimeSignature()
    var name: String = "Clip"

    var lengthSteps: Int {
        lengthBars * timeSignature.stepsPerBar
    }
}
