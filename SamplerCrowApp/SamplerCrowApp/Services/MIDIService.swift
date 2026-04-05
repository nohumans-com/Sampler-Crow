import Foundation
import CoreMIDI

actor MIDIService {
    private var client: MIDIClientRef = 0
    private var outputPort: MIDIPortRef = 0
    private var inputPort: MIDIPortRef = 0
    private var teensySource: MIDIEndpointRef = 0
    private var teensyDestination: MIDIEndpointRef = 0
    private nonisolated(unsafe) var messageCallback: (@Sendable (UInt8, UInt8, UInt8) -> Void)?

    var isConnected: Bool { teensyDestination != 0 }

    func connect(onMessage: @escaping @Sendable (UInt8, UInt8, UInt8) -> Void) throws {
        messageCallback = onMessage

        // Create MIDI client
        var status = MIDIClientCreate("SamplerCrow" as CFString, nil, nil, &client)
        guard status == noErr else {
            throw MIDIServiceError.clientCreateFailed(status)
        }

        // Create output port
        status = MIDIOutputPortCreate(client, "Output" as CFString, &outputPort)
        guard status == noErr else {
            throw MIDIServiceError.portCreateFailed(status)
        }

        // Create input port with block-based callback
        status = MIDIInputPortCreateWithProtocol(
            client,
            "Input" as CFString,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, _ in
            self?.handleMIDIEventList(eventList)
        }
        guard status == noErr else {
            throw MIDIServiceError.portCreateFailed(status)
        }

        // Find Teensy MIDI device
        try findTeensyDevice()
    }

    private func findTeensyDevice() throws {
        // Search MIDI sources (inputs from Teensy)
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if isTeensyEndpoint(source) {
                teensySource = source
                let status = MIDIPortConnectSource(inputPort, source, nil)
                if status != noErr {
                    print("Warning: failed to connect MIDI source: \(status)")
                }
                break
            }
        }

        // Search MIDI destinations (outputs to Teensy)
        let destCount = MIDIGetNumberOfDestinations()
        for i in 0..<destCount {
            let dest = MIDIGetDestination(i)
            if isTeensyEndpoint(dest) {
                teensyDestination = dest
                break
            }
        }

        guard teensyDestination != 0 else {
            throw MIDIServiceError.deviceNotFound
        }
    }

    private func isTeensyEndpoint(_ endpoint: MIDIEndpointRef) -> Bool {
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
        let nameStr = (name?.takeRetainedValue() as String?) ?? ""

        // Check for known Teensy device names
        let teensyNames = ["teensy", "tnt control surface"]
        for candidate in teensyNames {
            if nameStr.localizedCaseInsensitiveContains(candidate) {
                return true
            }
        }
        return false
    }

    private nonisolated func handleMIDIEventList(_ eventList: UnsafePointer<MIDIEventList>) {
        let list = eventList.pointee
        withUnsafePointer(to: list.packet) { ptr in
            var packet = ptr.pointee
            for _ in 0..<list.numPackets {
                // Extract MIDI 1.0 messages from Universal MIDI Packets
                let word = packet.words.0
                let messageType = (word >> 28) & 0x0F

                if messageType == 0x2 { // MIDI 1.0 Channel Voice Message
                    let status = UInt8((word >> 16) & 0xFF)
                    let data1 = UInt8((word >> 8) & 0xFF)
                    let data2 = UInt8(word & 0xFF)
                    messageCallback?(status, data1, data2)
                }

                // Advance to next packet
                withUnsafePointer(to: packet) { pktPtr in
                    let next = MIDIEventPacketNext(pktPtr)
                    packet = next.pointee
                }
            }
        }
    }

    func sendNoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        let status: UInt8 = 0x90 | ((channel - 1) & 0x0F)
        sendMessage(status, note, velocity)
    }

    func sendNoteOff(channel: UInt8, note: UInt8) {
        let status: UInt8 = 0x80 | ((channel - 1) & 0x0F)
        sendMessage(status, note, 0)
    }

    func sendCC(channel: UInt8, cc: UInt8, value: UInt8) {
        let status: UInt8 = 0xB0 | ((channel - 1) & 0x0F)
        sendMessage(status, cc, value)
    }

    private func sendMessage(_ status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        guard teensyDestination != 0 else { return }

        // Build Universal MIDI Packet (MIDI 1.0 channel voice = message type 0x2)
        let word: UInt32 = (0x20 << 24) | (UInt32(status) << 16) | (UInt32(data1) << 8) | UInt32(data2)

        var words: [UInt32] = [word]
        var eventList = MIDIEventList()
        var packet = MIDIEventListInit(&eventList, ._1_0)
        packet = MIDIEventListAdd(&eventList, MemoryLayout<MIDIEventList>.size, packet, 0, 1, &words)

        MIDISendEventList(outputPort, teensyDestination, &eventList)
    }

    func disconnect() {
        if teensySource != 0 {
            MIDIPortDisconnectSource(inputPort, teensySource)
            teensySource = 0
        }
        teensyDestination = 0
        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }
        outputPort = 0
        inputPort = 0
        messageCallback = nil
    }
}

enum MIDIServiceError: Error, LocalizedError {
    case clientCreateFailed(OSStatus)
    case portCreateFailed(OSStatus)
    case deviceNotFound

    var errorDescription: String? {
        switch self {
        case .clientCreateFailed(let s): "Failed to create MIDI client: \(s)"
        case .portCreateFailed(let s): "Failed to create MIDI port: \(s)"
        case .deviceNotFound: "Teensy MIDI device not found"
        }
    }
}
