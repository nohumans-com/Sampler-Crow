import Foundation

enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

struct ConnectionStatus: Sendable {
    var serial: ConnectionState = .disconnected
    var midi: ConnectionState = .disconnected
    var audio: ConnectionState = .disconnected
}
