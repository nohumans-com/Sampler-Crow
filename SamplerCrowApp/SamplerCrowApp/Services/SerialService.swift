import Foundation
import IOKit
import IOKit.serial

actor SerialService {
    private var fileDescriptor: Int32 = -1
    private var readTask: Task<Void, Never>?
    private var lineCallback: (@Sendable (String) -> Void)?

    var isConnected: Bool { fileDescriptor >= 0 }

    func connect(path: String, onLine: @escaping @Sendable (String) -> Void) throws {
        disconnect()
        lineCallback = onLine

        let fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else {
            throw SerialError.openFailed(path, errno)
        }

        // Configure termios: 115200 baud, 8N1, raw mode
        var tty = termios()
        guard tcgetattr(fd, &tty) == 0 else {
            close(fd)
            throw SerialError.configFailed
        }

        cfmakeraw(&tty)
        cfsetispeed(&tty, speed_t(B115200))
        cfsetospeed(&tty, speed_t(B115200))

        // VMIN=1: read returns after at least 1 byte
        // VTIME=1: 100ms timeout between bytes
        withUnsafeMutablePointer(to: &tty.c_cc) { ptr in
            let cc = ptr.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { $0 }
            cc[Int(VMIN)] = 1
            cc[Int(VTIME)] = 1
        }

        guard tcsetattr(fd, TCSANOW, &tty) == 0 else {
            close(fd)
            throw SerialError.configFailed
        }

        // Clear O_NONBLOCK for blocking reads in the read task
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)

        fileDescriptor = fd

        // Start reading in background
        let callback = lineCallback
        readTask = Task.detached { [fd] in
            var buffer = Data(capacity: 1024)
            let readBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 256)
            defer { readBuf.deallocate() }

            while !Task.isCancelled {
                let bytesRead = read(fd, readBuf, 256)
                if bytesRead <= 0 {
                    if errno == EINTR { continue }
                    break
                }

                buffer.append(readBuf, count: bytesRead)

                // Extract complete lines
                while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    let lineData = buffer[buffer.startIndex..<newlineIndex]
                    buffer.removeSubrange(buffer.startIndex...newlineIndex)

                    if let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .carriageReturns) {
                        if !line.isEmpty {
                            callback?(line)
                        }
                    }
                }
            }
        }
    }

    func send(_ command: String) throws {
        guard fileDescriptor >= 0 else {
            throw SerialError.notConnected
        }
        let data = (command + "\n").data(using: .utf8)!
        let result = data.withUnsafeBytes { ptr in
            write(fileDescriptor, ptr.baseAddress, ptr.count)
        }
        if result < 0 {
            throw SerialError.writeFailed
        }
    }

    func disconnect() {
        readTask?.cancel()
        readTask = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        lineCallback = nil
    }

    static func findTeensySerialPort() -> String? {
        // Use IOKit to find the serial port belonging to a PJRC (Teensy) device
        // PJRC Vendor ID = 0x16C0
        let devDir = "/dev"
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: devDir) else {
            return nil
        }
        let usbModems = entries
            .filter { $0.hasPrefix("cu.usbmodem") }
            .sorted()

        // Try to identify Teensy by probing each port with PING
        // The Teensy port typically has a higher number in the device path
        // For now, try to find it via IOKit USB vendor matching
        if let teensyPort = findPortByVendor(vendorId: 0x16C0, ports: usbModems) {
            return "\(devDir)/\(teensyPort)"
        }

        // Fallback: return all available ports for user to choose
        return usbModems.last.map { "\(devDir)/\($0)" }
    }

    static func listSerialPorts() -> [String] {
        let devDir = "/dev"
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: devDir) else {
            return []
        }
        return entries
            .filter { $0.hasPrefix("cu.usbmodem") }
            .sorted()
            .map { "\(devDir)/\($0)" }
    }

    private static func findPortByVendor(vendorId: Int, ports: [String]) -> String? {
        // Use IOKit to match USB serial devices by vendor ID
        guard let matchDict = IOServiceMatching(kIOSerialBSDServiceValue) else { return nil }

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        guard kr == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var teensyDialin: String?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            // Get the callout device path
            guard let calloutCF = IORegistryEntryCreateCFProperty(
                service, "IOCalloutDevice" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? String else { continue }

            // Walk up the registry to find the USB device parent with our vendor ID
            var parent: io_object_t = 0
            var current = service
            IOObjectRetain(current)

            for _ in 0..<10 {
                let result = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
                IOObjectRelease(current)
                if result != KERN_SUCCESS { break }
                current = parent

                if let vidCF = IORegistryEntryCreateCFProperty(
                    current, "idVendor" as CFString, kCFAllocatorDefault, 0
                )?.takeRetainedValue() as? Int, vidCF == vendorId {
                    teensyDialin = calloutCF
                    IOObjectRelease(current)
                    break
                }
            }

            if teensyDialin != nil { break }
        }

        // Return just the filename portion to match against our port list
        if let path = teensyDialin {
            return (path as NSString).lastPathComponent
        }
        return nil
    }
}

enum SerialError: Error, LocalizedError {
    case openFailed(String, Int32)
    case configFailed
    case notConnected
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .openFailed(let path, let err): "Failed to open \(path): errno \(err)"
        case .configFailed: "Failed to configure serial port"
        case .notConnected: "Serial port not connected"
        case .writeFailed: "Failed to write to serial port"
        }
    }
}

private extension CharacterSet {
    static let carriageReturns = CharacterSet(charactersIn: "\r")
}
