import Foundation

enum KeyboardMapping {
    // Computer keyboard -> MIDI note (piano layout)
    // Bottom row: A=C4, S=D4, D=E4, F=F4, G=G4, H=A4, J=B4, K=C5
    // Top row:    W=C#4, E=D#4, T=F#4, Y=G#4, U=A#4
    static let keyToNote: [String: UInt8] = [
        "a": 60,  // C4
        "w": 61,  // C#4
        "s": 62,  // D4
        "e": 63,  // D#4
        "d": 64,  // E4
        "f": 65,  // F4
        "t": 66,  // F#4
        "g": 67,  // G4
        "y": 68,  // G#4
        "h": 69,  // A4
        "u": 70,  // A#4
        "j": 71,  // B4
        "k": 72,  // C5
    ]

    static let defaultVelocity: UInt8 = 100
    static let musicalChannel: UInt8 = 1  // Channel for musical notes
    static let gridChannel: UInt8 = 16    // Channel for grid controller
}
