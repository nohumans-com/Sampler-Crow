import Foundation

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let type: LogType
    let timestamp: Date

    enum LogType: Sendable {
        case incoming   // from Teensy
        case outgoing   // to Teensy
        case info       // system messages
    }

    init(_ text: String, type: LogType = .info) {
        self.text = text
        self.type = type
        self.timestamp = Date()
    }
}
