import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox

// Thread-safe ring buffer written from input tap, read by output source node
final class AudioTapBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var _samples = [Float](repeating: 0, count: 1024)
    private var _peakL: Float = 0
    private var _peakR: Float = 0
    private var _hasNew = false
    // Diagnostic counter — atomic-ish increment under the lock
    private var _tapCallCount: Int = 0

    func incrementTapCount() -> Int {
        lock.lock()
        _tapCallCount += 1
        let v = _tapCallCount
        lock.unlock()
        return v
    }

    func tapCallCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return _tapCallCount
    }

    func resetTapCount() {
        lock.lock()
        _tapCallCount = 0
        lock.unlock()
    }

    // Ring buffer for output routing (stereo interleaved)
    private let ringCapacity = 88200  // ~1 second at 44100Hz stereo
    private var ringBuffer: [Float]
    private var writePos = 0
    private var readPos = 0
    private var ringCount = 0

    init() {
        ringBuffer = [Float](repeating: 0, count: ringCapacity)
    }

    func write(samples: [Float], peakL: Float, peakR: Float) {
        lock.lock()
        _samples = samples
        _peakL = peakL
        _peakR = peakR
        _hasNew = true
        lock.unlock()
    }

    // Write interleaved stereo frames to ring buffer (called from input tap)
    func writeRing(left: UnsafePointer<Float>, right: UnsafePointer<Float>?, frameCount: Int) {
        lock.lock()
        for i in 0..<frameCount {
            ringBuffer[writePos] = left[i]
            writePos = (writePos + 1) % ringCapacity
            ringBuffer[writePos] = right?[i] ?? left[i]
            writePos = (writePos + 1) % ringCapacity
        }
        ringCount = min(ringCount + frameCount * 2, ringCapacity)
        lock.unlock()
    }

    // Read interleaved stereo frames from ring buffer (called from output source node)
    func readRing(into buffer: UnsafeMutablePointer<Float>, frameCount: Int) -> Int {
        lock.lock()
        let samplesToRead = min(frameCount * 2, ringCount)
        for i in 0..<samplesToRead {
            buffer[i] = ringBuffer[readPos]
            readPos = (readPos + 1) % ringCapacity
        }
        ringCount -= samplesToRead
        // Fill remaining with silence
        if samplesToRead < frameCount * 2 {
            for i in samplesToRead..<(frameCount * 2) {
                buffer[i] = 0
            }
        }
        lock.unlock()
        return samplesToRead / 2
    }

    func read() -> (samples: [Float], peakL: Float, peakR: Float)? {
        lock.lock()
        defer { lock.unlock() }
        guard _hasNew else { return nil }
        _hasNew = false
        return (_samples, _peakL, _peakR)
    }
}

struct AudioOutputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
}

// ============================================================
// Raw CoreAudio AUHAL Input Capture
// Replaces AVAudioEngine.inputNode which doesn't reliably honor
// device-specific routing on macOS — it ties to the system default.
// This class creates a HAL output unit (kAudioUnitSubType_HALOutput)
// configured in input-only mode for a specific AudioDeviceID.
// ============================================================
final class CoreAudioInputCapture: @unchecked Sendable {
    private var audioUnit: AudioUnit?
    private var isRunning = false
    private let buffer: AudioTapBuffer
    private var inputBufferList: UnsafeMutablePointer<AudioBufferList>?
    private var sampleBufferStorage: UnsafeMutableRawPointer?
    private var maxFrames: UInt32 = 1024
    private var channelCount: UInt32 = 2

    init(buffer: AudioTapBuffer) {
        self.buffer = buffer
    }

    deinit {
        stop()
    }

    func start(deviceID: AudioDeviceID) throws {
        stop()

        // 1. Find the HAL Output AudioComponent
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let comp = AudioComponentFindNext(nil, &desc) else {
            throw AudioServiceError.noAudioUnit
        }

        var unit: AudioUnit?
        var status = AudioComponentInstanceNew(comp, &unit)
        guard status == noErr, let unit = unit else {
            print("CoreAudioInputCapture: AudioComponentInstanceNew failed: \(status)")
            throw AudioServiceError.setDeviceFailed(status)
        }
        self.audioUnit = unit

        // 2. Enable input on element 1, disable output on element 0
        var enable: UInt32 = 1
        status = AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input, 1,
            &enable, UInt32(MemoryLayout<UInt32>.size)
        )
        print("CoreAudioInputCapture: EnableIO(input)=1 status=\(status)")
        guard status == noErr else { throw AudioServiceError.setDeviceFailed(status) }

        var disable: UInt32 = 0
        status = AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output, 0,
            &disable, UInt32(MemoryLayout<UInt32>.size)
        )
        print("CoreAudioInputCapture: EnableIO(output)=0 status=\(status)")
        guard status == noErr else { throw AudioServiceError.setDeviceFailed(status) }

        // 3. Set the device
        var devID = deviceID
        status = AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0,
            &devID, UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        print("CoreAudioInputCapture: CurrentDevice=\(deviceID) status=\(status)")
        guard status == noErr else { throw AudioServiceError.setDeviceFailed(status) }

        // 4. Get the device's native format on the input scope (what the device produces)
        var deviceFormat = AudioStreamBasicDescription()
        var fmtSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioUnitGetProperty(
            unit, kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input, 1,
            &deviceFormat, &fmtSize
        )
        print("CoreAudioInputCapture: device format sr=\(deviceFormat.mSampleRate) ch=\(deviceFormat.mChannelsPerFrame) bits=\(deviceFormat.mBitsPerChannel)")
        guard status == noErr else { throw AudioServiceError.setDeviceFailed(status) }

        // 5. Set our desired output format on the AU (element 1, output scope = what the AU gives us)
        // Interleaved float32 stereo at the device's sample rate
        let channels: UInt32 = max(deviceFormat.mChannelsPerFrame, 2)
        self.channelCount = channels
        var outFormat = AudioStreamBasicDescription(
            mSampleRate: deviceFormat.mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        status = AudioUnitSetProperty(
            unit, kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output, 1,
            &outFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        print("CoreAudioInputCapture: set StreamFormat status=\(status)")
        guard status == noErr else { throw AudioServiceError.setDeviceFailed(status) }

        // 6. Install input callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var cb = AURenderCallbackStruct(
            inputProc: { (refCon, flags, timestamp, bus, frames, _) -> OSStatus in
                let this = Unmanaged<CoreAudioInputCapture>.fromOpaque(refCon).takeUnretainedValue()
                return this.renderCallback(flags: flags, timestamp: timestamp, bus: bus, frames: frames)
            },
            inputProcRefCon: selfPtr
        )
        status = AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_SetInputCallback,
            kAudioUnitScope_Global, 0,
            &cb, UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )
        print("CoreAudioInputCapture: SetInputCallback status=\(status)")
        guard status == noErr else { throw AudioServiceError.setDeviceFailed(status) }

        // 7. Allocate buffer list for reading
        let bufListSize = MemoryLayout<AudioBufferList>.size + Int(channels - 1) * MemoryLayout<AudioBuffer>.size
        let bufList = UnsafeMutableRawPointer.allocate(byteCount: bufListSize, alignment: MemoryLayout<AudioBufferList>.alignment).assumingMemoryBound(to: AudioBufferList.self)
        bufList.pointee.mNumberBuffers = channels
        let storageSize = Int(maxFrames) * Int(channels) * MemoryLayout<Float>.size
        let storage = UnsafeMutableRawPointer.allocate(byteCount: storageSize, alignment: 16)
        let buffers = UnsafeMutableAudioBufferListPointer(bufList)
        for i in 0..<Int(channels) {
            let offset = i * Int(maxFrames) * MemoryLayout<Float>.size
            buffers[i] = AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(Int(maxFrames) * MemoryLayout<Float>.size),
                mData: storage.advanced(by: offset)
            )
        }
        self.inputBufferList = bufList
        self.sampleBufferStorage = storage

        // 8. Initialize and start
        status = AudioUnitInitialize(unit)
        print("CoreAudioInputCapture: AudioUnitInitialize status=\(status)")
        guard status == noErr else { throw AudioServiceError.setDeviceFailed(status) }

        status = AudioOutputUnitStart(unit)
        print("CoreAudioInputCapture: AudioOutputUnitStart status=\(status)")
        guard status == noErr else { throw AudioServiceError.setDeviceFailed(status) }

        isRunning = true
        print("CoreAudioInputCapture: Started successfully")
    }

    private func renderCallback(flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, timestamp: UnsafePointer<AudioTimeStamp>, bus: UInt32, frames: UInt32) -> OSStatus {
        guard let unit = audioUnit, let bufList = inputBufferList else { return noErr }

        // Reset buffer sizes for each call
        let bufs = UnsafeMutableAudioBufferListPointer(bufList)
        for i in 0..<bufs.count {
            bufs[i].mDataByteSize = frames * UInt32(MemoryLayout<Float>.size)
        }

        let status = AudioUnitRender(unit, flags, timestamp, bus, frames, bufList)
        if status != noErr { return status }

        // Increment tap counter
        _ = buffer.incrementTapCount()

        // Extract samples for waveform and levels
        let frameCount = Int(frames)
        let ch0 = bufs[0].mData?.assumingMemoryBound(to: Float.self)
        let ch1 = bufs.count > 1 ? bufs[1].mData?.assumingMemoryBound(to: Float.self) : ch0

        guard let left = ch0 else { return noErr }
        let right = ch1 ?? left

        let sampleCount = min(frameCount, 1024)
        var samples = [Float](repeating: 0, count: sampleCount)
        var peakL: Float = 0
        var peakR: Float = 0
        for i in 0..<frameCount {
            let l = left[i]
            let r = right[i]
            if i < sampleCount { samples[i] = l }
            peakL = max(peakL, abs(l))
            peakR = max(peakR, abs(r))
        }
        buffer.write(samples: samples, peakL: peakL, peakR: peakR)
        buffer.writeRing(left: left, right: right, frameCount: frameCount)
        return noErr
    }

    func stop() {
        if let unit = audioUnit {
            if isRunning {
                AudioOutputUnitStop(unit)
                AudioUnitUninitialize(unit)
                isRunning = false
            }
            AudioComponentInstanceDispose(unit)
            audioUnit = nil
        }
        if let bufList = inputBufferList {
            UnsafeMutableRawPointer(bufList).deallocate()
            inputBufferList = nil
        }
        if let storage = sampleBufferStorage {
            storage.deallocate()
            sampleBufferStorage = nil
        }
    }
}

@MainActor
final class AudioService: ObservableObject {
    private var engine: AVAudioEngine?
    private var teensyDeviceID: AudioDeviceID = 0
    private let tapBuffer = AudioTapBuffer()
    private var pollTimer: Timer?
    private var inputCapture: CoreAudioInputCapture?

    // Output routing
    private var outputEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    // Test tone engine (independent of Teensy capture)
    private var testToneEngine: AVAudioEngine?
    private var testToneNode: AVAudioSourceNode?

    @Published var waveformSamples: [Float] = Array(repeating: 0, count: 1024)
    @Published var levelLeft: Float = 0
    @Published var levelRight: Float = 0
    @Published var isConnected = false
    @Published var errorMessage: String?
    @Published var outputDevices: [AudioOutputDevice] = []
    @Published var selectedOutputDeviceID: AudioDeviceID = 0
    @Published var isOutputActive = false
    @Published var isTestTonePlaying = false
    @Published var tapCallCount: Int = 0
    @Published var engineRunning: Bool = false

    // Read current tap-call count from the shared buffer (for UI debug display)
    func currentTapCount() -> Int { tapBuffer.tapCallCount() }

    /// Request microphone permission asynchronously. Must be called before connect().
    func requestMicrophonePermission() async -> Bool {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("AudioService: Mic permission current status = \(currentStatus.rawValue) (\(Self.authStatusName(currentStatus)))")
        switch currentStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            print("AudioService: Mic permission request result = \(granted)")
            return granted
        case .denied, .restricted:
            print("AudioService: Mic permission DENIED/RESTRICTED — user must enable in System Settings")
            return false
        @unknown default:
            return false
        }
    }

    private static func authStatusName(_ s: AVAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }

    func connect() throws {
        print("AudioService: === connect() begin ===")

        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("AudioService: Mic authorization = \(Self.authStatusName(authStatus)) (\(authStatus.rawValue))")

        // Ensure clean state
        if isConnected {
            print("AudioService: already connected; disconnecting first")
            disconnect()
        }

        tapBuffer.resetTapCount()

        guard let deviceID = Self.findTeensyInputDevice() else {
            print("AudioService: ERROR — Teensy input device NOT FOUND")
            throw AudioServiceError.deviceNotFound
        }
        teensyDeviceID = deviceID
        let deviceName = Self.getDeviceName(deviceID)
        print("AudioService: Found device: '\(deviceName)' (ID: \(deviceID))")

        // Use raw CoreAudio AUHAL for input capture — AVAudioEngine doesn't reliably
        // honor device-specific routing and ties to the system default input.
        let capture = CoreAudioInputCapture(buffer: tapBuffer)
        do {
            try capture.start(deviceID: deviceID)
        } catch {
            print("AudioService: ERROR — CoreAudioInputCapture.start failed: \(error)")
            throw error
        }
        self.inputCapture = capture
        engineRunning = true

        isConnected = true
        errorMessage = nil

        // Poll the tap buffer from main thread at 30fps; also surface tap counter for UI debug
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollAudioData()
            }
        }

        // One-shot diagnostic: after 1s, report how many tap calls happened
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                guard let self = self else { return }
                let c = self.tapBuffer.tapCallCount()
                print("AudioService: [1s after start] tap call count = \(c), engine.isRunning = \(self.engine?.isRunning ?? false)")
                if c == 0 {
                    print("AudioService: WARNING — tap callback has NOT fired. Check mic permission, device routing, or format mismatch.")
                }
            }
        }

        print("AudioService: === connect() complete ===")
    }

    // Static + nonisolated so the closure doesn't inherit @MainActor
    private nonisolated static func installTap(on node: AVAudioInputNode, format: AVAudioFormat, buffer: AudioTapBuffer) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { pcmBuffer, _ in
            let count = buffer.incrementTapCount()
            if count == 1 || count % 30 == 0 {
                print("AudioService.tap: callback #\(count) frames=\(pcmBuffer.frameLength) ch=\(pcmBuffer.format.channelCount) sr=\(pcmBuffer.format.sampleRate)")
            }
            guard let channelData = pcmBuffer.floatChannelData else {
                if count <= 5 { print("AudioService.tap: floatChannelData is nil") }
                return
            }
            let frameCount = Int(pcmBuffer.frameLength)
            guard frameCount > 0 else {
                if count <= 5 { print("AudioService.tap: frameCount == 0") }
                return
            }

            let sampleCount = min(frameCount, 1024)
            var samples = [Float](repeating: 0, count: sampleCount)
            for i in 0..<sampleCount {
                samples[i] = channelData[0][i]
            }

            var peakL: Float = 0
            var peakR: Float = 0
            for i in 0..<frameCount {
                peakL = max(peakL, abs(channelData[0][i]))
            }
            let rightChannel: UnsafePointer<Float>?
            if pcmBuffer.format.channelCount > 1 {
                for i in 0..<frameCount {
                    peakR = max(peakR, abs(channelData[1][i]))
                }
                rightChannel = UnsafePointer(channelData[1])
            } else {
                peakR = peakL
                rightChannel = nil
            }

            buffer.write(samples: samples, peakL: peakL, peakR: peakR)
            // Also feed ring buffer for output routing
            buffer.writeRing(left: channelData[0], right: rightChannel, frameCount: frameCount)
        }
    }

    // Static + nonisolated so the render closure doesn't inherit @MainActor
    private nonisolated static func createSourceNode(buffer: AudioTapBuffer, sampleRate: Double, channels: UInt32) -> AVAudioSourceNode {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            // Read interleaved stereo from ring buffer into a temp buffer
            var interleaved = [Float](repeating: 0, count: frames * 2)
            _ = buffer.readRing(into: &interleaved, frameCount: frames)

            // Deinterleave into output buffers
            for bufIdx in 0..<ablPointer.count {
                if let data = ablPointer[bufIdx].mData?.assumingMemoryBound(to: Float.self) {
                    let channelOffset = bufIdx % 2
                    for i in 0..<frames {
                        data[i] = interleaved[i * 2 + channelOffset]
                    }
                }
            }
            return noErr
        }
    }

    // MARK: - Output Device Routing

    func listOutputDevices() {
        var propSize: UInt32 = 0
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &propSize)
        let count = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &propSize, &devices)

        var result: [AudioOutputDevice] = []
        for dev in devices {
            let outputCh = Self.getChannelCount(dev, scope: kAudioDevicePropertyScopeOutput)
            if outputCh > 0 {
                let name = Self.getDeviceName(dev)
                result.append(AudioOutputDevice(id: dev, name: name))
            }
        }
        outputDevices = result

        // Auto-select default output if none selected, AND actually start routing to it
        if selectedOutputDeviceID == 0, let first = result.first {
            let defaultID = Self.getDefaultOutputDevice() ?? first.id
            do {
                try setOutputDevice(defaultID)
                print("AudioService: Auto-started output routing to device \(defaultID)")
            } catch {
                print("AudioService: Auto-start output routing failed: \(error)")
                selectedOutputDeviceID = defaultID
            }
        } else if selectedOutputDeviceID != 0 && !isOutputActive && isConnected {
            // Output was selected but engine isn't running — start it
            do {
                try setOutputDevice(selectedOutputDeviceID)
                print("AudioService: Restarted output routing")
            } catch {
                print("AudioService: Restart output routing failed: \(error)")
            }
        }
    }

    private static func getDefaultOutputDevice() -> AudioDeviceID? {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    func setOutputDevice(_ deviceID: AudioDeviceID) throws {
        // Stop existing output engine
        stopOutput()

        selectedOutputDeviceID = deviceID
        guard isConnected else { return }

        // Create a separate output engine
        let outEngine = AVAudioEngine()

        // Set output device on the engine's output node
        let outputNode = outEngine.outputNode
        guard let outAU = outputNode.audioUnit else {
            throw AudioServiceError.noAudioUnit
        }

        var devID = deviceID
        let status = AudioUnitSetProperty(
            outAU,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioServiceError.setDeviceFailed(status)
        }

        // Get output device format (may be 48kHz for UAD, 44.1kHz for built-in, etc.)
        let outFormat = outputNode.outputFormat(forBus: 0)
        let deviceSampleRate = outFormat.sampleRate > 0 ? outFormat.sampleRate : 44100.0
        print("AudioService: Output device sample rate = \(deviceSampleRate)Hz, channels=\(outFormat.channelCount)")

        // IMPORTANT: Source node MUST produce samples at the TEENSY's input rate (44.1kHz),
        // not the output device rate. AVAudioEngine will insert an AVAudioConverter
        // automatically when we connect the source (44.1kHz) to the mainMixerNode (device rate).
        // This is what makes the app work with 48kHz/96kHz audio interfaces.
        let teensyRate: Double = 44100.0
        let srcChannels: UInt32 = 2

        guard let sourceFormat = AVAudioFormat(
            standardFormatWithSampleRate: teensyRate,
            channels: srcChannels
        ) else {
            throw AudioServiceError.invalidFormat
        }

        // Create source node at Teensy rate (44.1kHz stereo)
        let srcNode = Self.createSourceNode(buffer: tapBuffer, sampleRate: teensyRate, channels: srcChannels)

        outEngine.attach(srcNode)
        // Connect source(44.1kHz) → mainMixer — engine auto-inserts SRC to match the mixer's rate
        outEngine.connect(srcNode, to: outEngine.mainMixerNode, format: sourceFormat)

        outEngine.prepare()
        try outEngine.start()

        self.outputEngine = outEngine
        self.sourceNode = srcNode
        self.isOutputActive = true

        let deviceName = Self.getDeviceName(deviceID)
        print("AudioService: Output routing to \(deviceName) — source 44100Hz → device \(deviceSampleRate)Hz (auto SRC)")
    }

    func stopOutput() {
        if let srcNode = sourceNode, let outEngine = outputEngine {
            outEngine.stop()
            outEngine.detach(srcNode)
        }
        outputEngine = nil
        sourceNode = nil
        isOutputActive = false
    }

    private func pollAudioData() {
        // Always surface tap counter + engine running state so the UI can show progress even when silent
        tapCallCount = tapBuffer.tapCallCount()
        engineRunning = engine?.isRunning ?? false

        guard let data = tapBuffer.read() else { return }
        waveformSamples = data.samples
        levelLeft = data.peakL
        levelRight = data.peakR
    }

    // MARK: - Test Tone (440Hz sine wave, independent of Teensy)

    func playTestTone() throws {
        if isTestTonePlaying {
            stopTestTone()
            return
        }
        print("AudioService: playTestTone() begin")

        let engine = AVAudioEngine()
        let outputNode = engine.outputNode
        let hwFormat = outputNode.outputFormat(forBus: 0)
        let sampleRate = hwFormat.sampleRate > 0 ? hwFormat.sampleRate : 44100.0
        let channels: UInt32 = 2
        print("AudioService: test tone using sampleRate=\(sampleRate) channels=\(channels)")

        // Route to selected output device if set
        if selectedOutputDeviceID != 0, let au = outputNode.audioUnit {
            var devID = selectedOutputDeviceID
            let status = AudioUnitSetProperty(
                au,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &devID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            print("AudioService: test tone set output device \(selectedOutputDeviceID) status=\(status)")
        }

        let src = Self.createSineSourceNode(sampleRate: sampleRate, channels: channels, frequency: 440.0, amplitude: 0.2)
        engine.attach(src)

        guard let renderFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels) else {
            throw AudioServiceError.invalidFormat
        }
        engine.connect(src, to: engine.mainMixerNode, format: renderFormat)
        engine.prepare()
        try engine.start()
        print("AudioService: test tone engine started, isRunning=\(engine.isRunning)")

        self.testToneEngine = engine
        self.testToneNode = src
        self.isTestTonePlaying = true
    }

    func stopTestTone() {
        print("AudioService: stopTestTone()")
        if let node = testToneNode, let eng = testToneEngine {
            eng.stop()
            eng.detach(node)
        }
        testToneEngine = nil
        testToneNode = nil
        isTestTonePlaying = false
    }

    // Nonisolated static: render block must not inherit @MainActor
    private nonisolated static func createSineSourceNode(sampleRate: Double, channels: UInt32, frequency: Double, amplitude: Float) -> AVAudioSourceNode {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        let phaseIncrement = 2.0 * Double.pi * frequency / sampleRate
        // Use a class reference to mutate phase safely across render callbacks
        final class PhaseBox: @unchecked Sendable { var phase: Double = 0 }
        let box = PhaseBox()
        return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            var phase = box.phase
            for frame in 0..<Int(frameCount) {
                let sample = Float(sin(phase)) * amplitude
                for b in 0..<abl.count {
                    if let data = abl[b].mData?.assumingMemoryBound(to: Float.self) {
                        data[frame] = sample
                    }
                }
                phase += phaseIncrement
                if phase >= 2.0 * .pi { phase -= 2.0 * .pi }
            }
            box.phase = phase
            return noErr
        }
    }

    func disconnect() {
        print("AudioService: disconnect()")
        pollTimer?.invalidate()
        pollTimer = nil
        stopOutput()
        stopTestTone()
        inputCapture?.stop()
        inputCapture = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isConnected = false
        engineRunning = false
        waveformSamples = Array(repeating: 0, count: 1024)
        levelLeft = 0
        levelRight = 0
    }

    static func findTeensyInputDevice() -> AudioDeviceID? {
        var propSize: UInt32 = 0
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &propSize)
        let count = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &propSize, &devices)

        for dev in devices {
            let name = getDeviceName(dev)
            let inputCh = getChannelCount(dev, scope: kAudioDevicePropertyScopeInput)
            if inputCh > 0 && (name.localizedCaseInsensitiveContains("teensy") || name.localizedCaseInsensitiveContains("tnt")) {
                return dev
            }
        }
        return nil
    }

    static func getDeviceName(_ deviceID: AudioDeviceID) -> String {
        var size: UInt32 = UInt32(MemoryLayout<CFString>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        _ = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, ptr)
        }
        return name as String
    }

    private static func getChannelCount(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size)
        guard size > 0 else { return 0 }
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferList.deallocate() }
        AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, bufferList)
        var channels = 0
        let bufs = UnsafeMutableAudioBufferListPointer(bufferList)
        for buf in bufs { channels += Int(buf.mNumberChannels) }
        return channels
    }
}

enum AudioServiceError: Error, LocalizedError {
    case deviceNotFound
    case setDeviceFailed(OSStatus)
    case invalidFormat
    case noAudioUnit

    var errorDescription: String? {
        switch self {
        case .deviceNotFound: "Teensy Audio device not found"
        case .setDeviceFailed(let s): "Failed to set audio input device: \(s)"
        case .invalidFormat: "Invalid audio format from device"
        case .noAudioUnit: "Failed to get audio unit"
        }
    }
}
