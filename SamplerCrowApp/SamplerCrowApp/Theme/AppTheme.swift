import SwiftUI

enum AppTheme {
    // Use native macOS system colors
    static let background = Color(.windowBackgroundColor)
    static let panel = Color(.controlBackgroundColor)
    static let accent = Color.accentColor
    static let gridBackground = Color(.textBackgroundColor)
    static let padDefault = Color(.separatorColor)
    static let textPrimary = Color(.labelColor)
    static let textSecondary = Color(.secondaryLabelColor)
    static let border = Color(.separatorColor)
    static let consoleBackground = Color(.textBackgroundColor)

    static let msgIn = Color.green
    static let msgOut = Color.orange
    static let msgInfo = Color.cyan

    static let statusConnected = Color.green
    static let statusDisconnected = Color.red

    static let monoFont = Font.system(size: 12, design: .monospaced)
    static let monoFontSmall = Font.system(size: 11, design: .monospaced)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
