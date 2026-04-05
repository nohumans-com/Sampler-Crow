import Foundation
import IOKit
import IOKit.usb

final class DeviceDiscoveryService: @unchecked Sendable {
    private var notifyPort: IONotificationPortRef?
    private var addIterator: io_iterator_t = 0
    private var removeIterator: io_iterator_t = 0
    private var onTeensyConnected: (() -> Void)?
    private var onTeensyDisconnected: (() -> Void)?

    // PJRC (Teensy) USB Vendor ID
    private static let teensyVendorID: Int = 0x16C0

    func startWatching(
        onConnected: @escaping () -> Void,
        onDisconnected: @escaping () -> Void
    ) {
        onTeensyConnected = onConnected
        onTeensyDisconnected = onDisconnected

        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort else { return }

        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        // Watch for USB device additions
        let matchDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        matchDict[kUSBVendorID] = Self.teensyVendorID

        // Need a second copy for removal (IOKit consumes the dict)
        let matchDictRemove = matchDict.mutableCopy() as! NSMutableDictionary

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Add notification
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOMatchedNotification,
            matchDict,
            { refCon, iterator in
                let svc = Unmanaged<DeviceDiscoveryService>.fromOpaque(refCon!).takeUnretainedValue()
                // Drain the iterator
                while IOIteratorNext(iterator) != 0 {}
                svc.onTeensyConnected?()
            },
            selfPtr,
            &addIterator
        )
        // Drain initial matches
        while IOIteratorNext(addIterator) != 0 {}

        // Remove notification
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            matchDictRemove,
            { refCon, iterator in
                let svc = Unmanaged<DeviceDiscoveryService>.fromOpaque(refCon!).takeUnretainedValue()
                while IOIteratorNext(iterator) != 0 {}
                svc.onTeensyDisconnected?()
            },
            selfPtr,
            &removeIterator
        )
        while IOIteratorNext(removeIterator) != 0 {}
    }

    func stopWatching() {
        if addIterator != 0 { IOObjectRelease(addIterator); addIterator = 0 }
        if removeIterator != 0 { IOObjectRelease(removeIterator); removeIterator = 0 }
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
        onTeensyConnected = nil
        onTeensyDisconnected = nil
    }
}
