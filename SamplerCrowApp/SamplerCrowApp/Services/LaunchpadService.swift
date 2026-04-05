import Foundation
import CoreMIDI

actor LaunchpadService {
    private var client: MIDIClientRef = 0
    private var outputPort: MIDIPortRef = 0
    private var inputPort: MIDIPortRef = 0
    private var lpSource: MIDIEndpointRef = 0
    private var lpDestination: MIDIEndpointRef = 0
    private nonisolated(unsafe) var padCallback: (@Sendable (UInt8, UInt8, Bool) -> Void)?

    var isConnected: Bool { lpDestination != 0 }

    func connect(onPad: @escaping @Sendable (UInt8, UInt8, Bool) -> Void) throws {
        padCallback = onPad

        var status = MIDIClientCreate("SamplerCrowLP" as CFString, nil, nil, &client)
        guard status == noErr else { throw LaunchpadError.clientFailed }

        status = MIDIOutputPortCreate(client, "LPOut" as CFString, &outputPort)
        guard status == noErr else { throw LaunchpadError.portFailed }

        status = MIDIInputPortCreateWithProtocol(client, "LPIn" as CFString, ._1_0, &inputPort) {
            [weak self] eventList, _ in
            self?.handleEvents(eventList)
        }
        guard status == noErr else { throw LaunchpadError.portFailed }

        // Find Launchpad Mini MK3 - use the MIDI port (not DAW port)
        try findLaunchpad()

        // Enter Programmer Mode
        sendSysEx(GridNote.programmerModeSysEx)

        // Clear all LEDs
        clearAll()
    }

    private func findLaunchpad() throws {
        print("LaunchpadService: scanning \(MIDIGetNumberOfSources()) sources / \(MIDIGetNumberOfDestinations()) destinations")
        for i in 0..<MIDIGetNumberOfSources() {
            let src = MIDIGetSource(i)
            let name = getEndpointName(src)
            print("LaunchpadService: source[\(i)] = '\(name)'")
            if name.localizedCaseInsensitiveContains("LPMiniMK3 MIDI") {
                lpSource = src
                let connStatus = MIDIPortConnectSource(inputPort, src, nil)
                print("LaunchpadService: connected to source '\(name)' status=\(connStatus)")
                break
            }
        }
        for i in 0..<MIDIGetNumberOfDestinations() {
            let dst = MIDIGetDestination(i)
            let name = getEndpointName(dst)
            if name.localizedCaseInsensitiveContains("LPMiniMK3 MIDI") {
                lpDestination = dst
                break
            }
        }
        // Also try DAW ports if MIDI ports not found
        if lpDestination == 0 {
            for i in 0..<MIDIGetNumberOfDestinations() {
                let dst = MIDIGetDestination(i)
                let name = getEndpointName(dst)
                if name.localizedCaseInsensitiveContains("LPMiniMK3 DAW") {
                    lpDestination = dst
                    break
                }
            }
            for i in 0..<MIDIGetNumberOfSources() {
                let src = MIDIGetSource(i)
                let name = getEndpointName(src)
                if name.localizedCaseInsensitiveContains("LPMiniMK3 DAW") {
                    if lpSource == 0 {
                        lpSource = src
                        MIDIPortConnectSource(inputPort, src, nil)
                    }
                    break
                }
            }
        }
        guard lpDestination != 0 else { throw LaunchpadError.notFound }
    }

    private func getEndpointName(_ endpoint: MIDIEndpointRef) -> String {
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
        return (name?.takeRetainedValue() as String?) ?? ""
    }

    private nonisolated func handleEvents(_ eventList: UnsafePointer<MIDIEventList>) {
        let list = eventList.pointee
        withUnsafePointer(to: list.packet) { ptr in
            var packet = ptr.pointee
            for _ in 0..<list.numPackets {
                let word = packet.words.0
                let msgType = (word >> 28) & 0x0F
                print("LaunchpadService.midi: raw word=0x\(String(word, radix: 16)) msgType=\(msgType)")
                if msgType == 0x2 {
                    let status = UInt8((word >> 16) & 0xFF)
                    let note = UInt8((word >> 8) & 0xFF)
                    let vel = UInt8(word & 0xFF)
                    let type = status & 0xF0
                    print("LaunchpadService.midi: status=0x\(String(status, radix: 16)) note=\(note) vel=\(vel)")

                    if type == 0x90 && vel > 0 {
                        print("LaunchpadService.midi: NoteOn note=\(note) vel=\(vel) -> padCallback(pressed=true)")
                        padCallback?(note, vel, true)
                    } else if type == 0x80 || (type == 0x90 && vel == 0) {
                        print("LaunchpadService.midi: NoteOff note=\(note) -> padCallback(pressed=false)")
                        padCallback?(note, 0, false)
                    } else if type == 0xB0 {
                        // CC from top row buttons
                        print("LaunchpadService.midi: CC cc=\(note) val=\(vel)")
                        padCallback?(note, vel, vel > 0)
                    }
                }
                withUnsafePointer(to: packet) { pktPtr in
                    let next = MIDIEventPacketNext(pktPtr)
                    packet = next.pointee
                }
            }
        }
    }

    // Set a single pad LED color (velocity = palette index)
    func setPadColor(note: UInt8, color: UInt8) {
        sendNoteOn(channel: 1, note: note, velocity: color)
    }

    // Set pad LED with SysEx for static/flash/pulse
    // type: 0 = static, 1 = flash, 2 = pulse
    func setPadColorSysEx(note: UInt8, color: UInt8, type: UInt8 = 0) {
        var msg = GridNote.ledSysExHeader
        msg.append(type)
        msg.append(note)
        msg.append(color)
        msg.append(0xF7)
        sendSysEx(msg)
    }

    // Set all pads to a color (using individual Note On messages - reliable)
    func setAllPads(color: UInt8) {
        for row in 1...8 {
            for col in 1...8 {
                let note = UInt8(row * 10 + col)
                sendNoteOn(channel: 1, note: note, velocity: color)
            }
        }
    }

    func clearAll() {
        setAllPads(color: 0)
    }

    // Update entire 8x8 grid from a color array
    func updateGrid(_ colors: [[UInt8]]) {
        for row in 0..<min(colors.count, 8) {
            for col in 0..<min(colors[row].count, 8) {
                let note = GridNote.noteFor(row: row, col: col)
                sendNoteOn(channel: 1, note: note, velocity: colors[row][col])
            }
        }
    }

    private func sendNoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        guard lpDestination != 0 else { return }
        let status: UInt8 = 0x90 | ((channel - 1) & 0x0F)
        let word: UInt32 = (0x20 << 24) | (UInt32(status) << 16) | (UInt32(note) << 8) | UInt32(velocity)
        var words: [UInt32] = [word]
        var eventList = MIDIEventList()
        var packet = MIDIEventListInit(&eventList, ._1_0)
        packet = MIDIEventListAdd(&eventList, MemoryLayout<MIDIEventList>.size, packet, 0, 1, &words)
        MIDISendEventList(outputPort, lpDestination, &eventList)
    }

    private func sendSysEx(_ data: [UInt8]) {
        guard lpDestination != 0 else { return }

        // Use class-based storage so the buffer outlives the function call
        class SysExBuffer {
            let data: UnsafeMutableBufferPointer<UInt8>
            init(_ bytes: [UInt8]) {
                data = .allocate(capacity: bytes.count)
                for i in 0..<bytes.count { data[i] = bytes[i] }
            }
            deinit { data.deallocate() }
        }

        let buf = SysExBuffer(data)
        // Prevent deallocation by retaining via Unmanaged
        let retained = Unmanaged.passRetained(buf)

        var request = MIDISysexSendRequest(
            destination: lpDestination,
            data: UnsafePointer(buf.data.baseAddress!),
            bytesToSend: UInt32(data.count),
            complete: false,
            reserved: (0, 0, 0),
            completionProc: { reqPtr in
                // Release the retained buffer
                let refCon = reqPtr.pointee.completionRefCon
                if let refCon = refCon {
                    Unmanaged<SysExBuffer>.fromOpaque(refCon).release()
                }
            },
            completionRefCon: retained.toOpaque()
        )
        MIDISendSysex(&request)
        // Wait for completion
        usleep(10000)
    }

    func disconnect() {
        if lpDestination != 0 {
            clearAll()
            // Exit programmer mode (enter session mode)
            sendSysEx([0xF0, 0x00, 0x20, 0x29, 0x02, 0x0D, 0x0E, 0x00, 0xF7])
        }
        if lpSource != 0 {
            MIDIPortDisconnectSource(inputPort, lpSource)
            lpSource = 0
        }
        lpDestination = 0
        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }
        padCallback = nil
    }
}

enum LaunchpadError: Error, LocalizedError {
    case clientFailed, portFailed, notFound
    var errorDescription: String? {
        switch self {
        case .clientFailed: "Failed to create MIDI client for Launchpad"
        case .portFailed: "Failed to create MIDI port for Launchpad"
        case .notFound: "Launchpad Mini MK3 not found"
        }
    }
}
