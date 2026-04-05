import SwiftUI

enum PadColor {
    // Launchpad Mini MK3 color palette (velocity values 0-127)
    // Each velocity maps to a specific color in the hardware palette
    static let palette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0,0,0), (28,28,28), (124,124,124), (252,252,252),       // 0-3
        (255,76,76), (254,13,0), (89,0,0), (25,0,0),             // 4-7
        (255,189,108), (255,84,0), (89,29,0), (39,27,0),         // 8-11
        (255,255,76), (255,255,0), (89,89,0), (25,25,0),         // 12-15
        (136,255,76), (84,255,0), (29,89,0), (20,43,0),          // 16-19
        (76,255,76), (0,255,0), (0,89,0), (0,25,0),              // 20-23
        (76,255,94), (0,255,25), (0,89,13), (0,25,4),            // 24-27
        (76,255,136), (0,255,85), (0,89,29), (0,25,20),          // 28-31
        (76,255,183), (0,255,153), (0,89,53), (0,25,15),         // 32-35
        (76,252,255), (0,229,255), (0,81,83), (0,24,25),         // 36-39
        (76,136,255), (0,85,255), (0,29,89), (0,8,25),           // 40-43
        (76,76,255), (0,0,255), (0,0,89), (0,0,25),              // 44-47
        (135,76,255), (84,0,255), (25,0,100), (15,0,48),         // 48-51
        (255,76,255), (255,0,255), (89,0,89), (25,0,25),         // 52-55
        (255,76,135), (255,0,84), (89,0,29), (34,0,19),          // 56-59
        (255,21,0), (153,53,0), (121,81,0), (67,100,0),          // 60-63
        (3,57,0), (0,87,53), (0,84,127), (0,0,255),              // 64-67
        (0,69,79), (37,0,204), (127,0,255), (178,26,125),        // 68-71
        (64,33,0), (255,74,0), (136,225,6), (114,255,21),        // 72-75
        (0,255,135), (0,169,255), (0,42,255), (102,0,161),       // 76-79
    ]

    static func color(forVelocity vel: UInt8) -> Color {
        let idx = Int(vel) % palette.count
        let c = palette[idx]
        if c.r == 0 && c.g == 0 && c.b == 0 {
            return Color(.separatorColor)  // Dark pad for "off"
        }
        return Color(
            red: Double(c.r) / 255.0,
            green: Double(c.g) / 255.0,
            blue: Double(c.b) / 255.0
        )
    }

    // Common color indices
    static let off: UInt8 = 0
    static let white: UInt8 = 3
    static let red: UInt8 = 5
    static let orange: UInt8 = 9
    static let yellow: UInt8 = 13
    static let green: UInt8 = 21
    static let cyan: UInt8 = 37
    static let blue: UInt8 = 45
    static let purple: UInt8 = 49
    static let pink: UInt8 = 53
    static let dimWhite: UInt8 = 1
}
