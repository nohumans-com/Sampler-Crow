import SwiftUI
import CoreAudio

struct AudioMonitorView: View {
    @ObservedObject var audioService: AudioService

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Audio Monitor")
                    .font(AppTheme.monoFont)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                if audioService.isConnected {
                    Text("Teensy USB Audio")
                        .font(AppTheme.monoFontSmall)
                        .foregroundStyle(AppTheme.statusConnected)
                }

                if let err = audioService.errorMessage {
                    Text(err)
                        .font(AppTheme.monoFontSmall)
                        .foregroundStyle(.red)
                }
            }
            .padding(8)

            // Output device picker
            HStack(spacing: 8) {
                Text("Output:")
                    .font(AppTheme.monoFontSmall)
                    .foregroundStyle(AppTheme.textSecondary)

                Picker("", selection: Binding<AudioDeviceID>(
                    get: { audioService.selectedOutputDeviceID },
                    set: { newID in
                        try? audioService.setOutputDevice(newID)
                    }
                )) {
                    Text("None").tag(AudioDeviceID(0))
                    ForEach(audioService.outputDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)

                if audioService.isOutputActive {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(AppTheme.statusConnected)
                        .font(.caption)
                }

                Spacer()

                Button("Reconnect Audio") {
                    audioService.disconnect()
                    Task { @MainActor in
                        _ = await audioService.requestMicrophonePermission()
                        try? audioService.connect()
                        audioService.listOutputDevices()
                    }
                }
                .buttonStyle(.bordered)
                .help("Reconnect to Teensy audio (use after firmware upload)")

                Button(audioService.isTestTonePlaying ? "Stop Tone" : "Play Test Tone") {
                    if audioService.isTestTonePlaying {
                        audioService.stopTestTone()
                    } else {
                        try? audioService.playTestTone()
                    }
                }
                .buttonStyle(.bordered)
                .help("Play a 440Hz sine wave through the selected output device")

                Button {
                    audioService.listOutputDevices()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Refresh output devices")
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .onAppear {
                audioService.listOutputDevices()
            }

            Divider()

            // Waveform
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                Canvas { context, size in
                    drawWaveform(context: context, size: size)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color(.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(8)

            // Levels
            HStack(spacing: 16) {
                LevelMeter(label: "L", level: audioService.levelLeft)
                LevelMeter(label: "R", level: audioService.levelRight)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            // Debug: tap callback counter + engine running state
            HStack(spacing: 12) {
                Text("Tap calls: \(audioService.tapCallCount)")
                    .font(AppTheme.monoFontSmall)
                    .foregroundStyle(audioService.tapCallCount > 0 ? AppTheme.statusConnected : .red)
                Text("Engine: \(audioService.engineRunning ? "running" : "stopped")")
                    .font(AppTheme.monoFontSmall)
                    .foregroundStyle(audioService.engineRunning ? AppTheme.statusConnected : AppTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            Spacer()
        }
    }

    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let samples = audioService.waveformSamples
        guard !samples.isEmpty else { return }
        let midY = size.height / 2.0

        // Center line
        var centerLine = Path()
        centerLine.move(to: CGPoint(x: 0, y: midY))
        centerLine.addLine(to: CGPoint(x: size.width, y: midY))
        context.stroke(centerLine, with: .color(Color(.separatorColor)), lineWidth: 0.5)

        // Waveform
        var path = Path()
        let sliceWidth = size.width / CGFloat(samples.count)
        for (i, sample) in samples.enumerated() {
            let x = CGFloat(i) * sliceWidth
            let y = midY - CGFloat(sample) * midY * 0.9
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(.cyan), lineWidth: 1.5)
    }
}

struct LevelMeter: View {
    let label: String
    let level: Float

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(AppTheme.monoFontSmall)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.separatorColor))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(meterColor)
                        .frame(width: max(0, geo.size.width * CGFloat(min(level, 1.0))))
                }
            }
            .frame(height: 8)

            Text(String(format: "%.1f", level * 100))
                .font(AppTheme.monoFontSmall)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var meterColor: Color {
        if level > 0.9 { return .red }
        if level > 0.7 { return .yellow }
        return .green
    }
}
