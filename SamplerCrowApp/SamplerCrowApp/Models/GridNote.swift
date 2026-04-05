import Foundation

enum GridNote {
    // Launchpad Mini MK3 Programmer Mode note mapping
    // Note = (row+1)*10 + (col+1)
    // Row 1 = bottom, Row 8 = top, Row 9 = top function buttons
    // Col 1 = left, Col 8 = right, Col 9 = right scene buttons

    // Grid dimensions (8x8 pads + function row/col)
    static let padRows = 8
    static let padCols = 8

    // Convert grid position (0-indexed, row 0 = top) to Launchpad note
    static func noteFor(row: Int, col: Int) -> UInt8 {
        // In our UI: row 0 = top = LP row 8, row 7 = bottom = LP row 1
        let lpRow = padRows - row  // 8 down to 1
        let lpCol = col + 1       // 1 to 8
        return UInt8(lpRow * 10 + lpCol)
    }

    // Convert Launchpad note to grid position (0-indexed, row 0 = top)
    static func positionFor(note: UInt8) -> (row: Int, col: Int)? {
        let n = Int(note)
        let lpRow = n / 10  // 1-9
        let lpCol = n % 10  // 1-9
        guard lpRow >= 1 && lpRow <= 8 && lpCol >= 1 && lpCol <= 8 else {
            return nil
        }
        let row = padRows - lpRow  // Convert to 0-indexed top-down
        let col = lpCol - 1
        return (row, col)
    }

    // Top function row notes (CC 91-98 on LP, but in programmer mode these are notes 91-98)
    static func topButtonNote(col: Int) -> UInt8 {
        return UInt8(91 + col)
    }

    // Right scene button notes (19, 29, 39, ... 89)
    static func rightButtonNote(row: Int) -> UInt8 {
        let lpRow = padRows - row
        return UInt8(lpRow * 10 + 9)
    }

    // SysEx for entering Programmer Mode on LP Mini MK3
    static let programmerModeSysEx: [UInt8] = [
        0xF0, 0x00, 0x20, 0x29, 0x02, 0x0D, 0x0E, 0x01, 0xF7
    ]

    // SysEx header for setting LED color (type 0 = static)
    // Full message: F0 00 20 29 02 0D 03 [type] [note] [color] F7
    static let ledSysExHeader: [UInt8] = [
        0xF0, 0x00, 0x20, 0x29, 0x02, 0x0D, 0x03
    ]
}
