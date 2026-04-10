import SwiftUI
import AppKit

@Observable
@MainActor
final class ProjectViewModel {
    let appState: AppState
    let mixerVM: MixerViewModel
    let synthEngineVM: SynthEngineViewModel
    var gridVM: GridViewModel?

    var projectNames: [String] = []
    var isSaving: Bool = false
    var isLoading: Bool = false

    private static let projectsDirectory: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Sampler-Crow/Projects")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init(appState: AppState, mixerVM: MixerViewModel, synthEngineVM: SynthEngineViewModel) {
        self.appState = appState
        self.mixerVM = mixerVM
        self.synthEngineVM = synthEngineVM
    }

    // MARK: - Capture

    func captureProjectData() -> ProjectData {
        let bpm = gridVM?.bpm ?? 120

        let trackDatas: [TrackData] = appState.tracks.enumerated().map { i, track in
            let samplerData = captureSampler(track.samplerState)
            let drumPadDatas = track.drumPads.map { pad in
                DrumPadData(
                    padIndex: pad.padIndex,
                    samplePath: pad.samplePath,
                    sampleName: pad.sampleName,
                    params: captureSampler(pad.params)
                )
            }
            let midiClipData = captureMIDIClip(track.midiClip)
            let arrangementClipDatas = track.arrangementClips.map { clip in
                ArrangementClipData(
                    name: clip.name,
                    startBar: clip.startBar,
                    lengthBars: clip.lengthBars,
                    colorHex: clip.color.toHexString(),
                    midiClip: captureMIDIClip(clip.midiClip)
                )
            }

            let synthData: SynthEngineData
            if synthEngineVM.trackIndex == i {
                synthData = SynthEngineData(
                    engine: synthEngineVM.engineModel,
                    timbre: synthEngineVM.timbre,
                    harmonics: synthEngineVM.harmonics,
                    morph: synthEngineVM.morph
                )
            } else {
                synthData = SynthEngineData(engine: 0, timbre: 500, harmonics: 500, morph: 500)
            }

            return TrackData(
                index: i,
                name: track.name,
                trackType: track.trackType.rawValue,
                isDrumMachine: track.isDrumMachine,
                mixer: MixerData(
                    volume: mixerVM.volumes[i],
                    pan: mixerVM.pans[i],
                    mute: mixerVM.mutes[i],
                    solo: mixerVM.solos[i]
                ),
                sampler: samplerData,
                drumPads: drumPadDatas,
                synthEngine: synthData,
                midiClip: midiClipData,
                arrangementClips: arrangementClipDatas
            )
        }

        return ProjectData(
            version: 1,
            name: appState.project.name,
            bpm: bpm,
            tracks: trackDatas
        )
    }

    private func captureSampler(_ s: SamplerState) -> SamplerData {
        SamplerData(
            samplePath: s.samplePath,
            sampleName: s.sampleName,
            mode: s.samplerMode,
            gain: s.gain,
            pitchSemitones: s.pitchSemitones,
            pitchCents: s.pitchCents,
            rootNote: s.rootNote,
            sampleStart: s.sampleStart,
            sampleEnd: s.sampleEnd,
            loopEnabled: s.loopEnabled,
            loopStart: s.loopStart,
            loopEnd: s.loopEnd,
            oneShot: s.oneShot,
            attackMs: s.attackMs,
            decayMs: s.decayMs,
            sustainLevel: s.sustainLevel,
            releaseMs: s.releaseMs,
            grainPosition: s.grainPosition,
            grainWindowSize: s.grainWindowSize,
            grainSizeMs: s.grainSizeMs,
            grainCount: s.grainCount,
            grainSpread: s.grainSpread,
            grainEnvShape: s.grainEnvShape,
            chopSensitivity: s.chopSensitivity,
            chopTriggerMode: s.chopTriggerMode
        )
    }

    private func captureMIDIClip(_ clip: MIDIClip) -> MIDIClipData {
        MIDIClipData(
            name: clip.name,
            lengthBars: clip.lengthBars,
            timeSignatureNumerator: clip.timeSignature.numerator,
            timeSignatureDenominator: clip.timeSignature.denominator,
            events: clip.events.map { e in
                MIDIEventData(
                    note: e.note,
                    velocity: e.velocity,
                    startStep: e.startStep,
                    duration: e.duration,
                    channel: e.channel
                )
            },
            ccAutomation: clip.ccAutomation.map { p in
                CCPointData(step: p.step, value: p.value, cc: p.cc)
            }
        )
    }

    // MARK: - Restore

    func restoreFromProjectData(_ data: ProjectData) async {
        // Update app state
        appState.project.name = data.name

        for td in data.tracks {
            let i = td.index
            guard i >= 0 && i < appState.tracks.count else { continue }

            let track = appState.tracks[i]
            track.name = td.name
            track.trackType = TrackType(rawValue: td.trackType) ?? .synth
            track.isDrumMachine = td.isDrumMachine

            // Restore sampler state
            restoreSampler(track.samplerState, from: td.sampler)

            // Restore drum pads
            for pd in td.drumPads {
                guard pd.padIndex >= 0 && pd.padIndex < track.drumPads.count else { continue }
                let pad = track.drumPads[pd.padIndex]
                pad.samplePath = pd.samplePath
                pad.sampleName = pd.sampleName
                restoreSampler(pad.params, from: pd.params)
            }

            // Restore MIDI clip
            restoreMIDIClip(track.midiClip, from: td.midiClip)

            // Restore arrangement clips
            track.arrangementClips = td.arrangementClips.map { acd in
                let clip = ArrangementClip(
                    name: acd.name,
                    startBar: acd.startBar,
                    lengthBars: acd.lengthBars,
                    color: Color(hexString: acd.colorHex)
                )
                restoreMIDIClip(clip.midiClip, from: acd.midiClip)
                return clip
            }

            // Restore mixer
            mixerVM.volumes[i] = td.mixer.volume
            mixerVM.pans[i] = td.mixer.pan
            mixerVM.mutes[i] = td.mixer.mute
            mixerVM.solos[i] = td.mixer.solo

            // Restore synth engine for the currently selected track
            if synthEngineVM.trackIndex == i {
                synthEngineVM.engineModel = td.synthEngine.engine
                synthEngineVM.timbre = td.synthEngine.timbre
                synthEngineVM.harmonics = td.synthEngine.harmonics
                synthEngineVM.morph = td.synthEngine.morph
            }
        }

        // Restore firmware state with pacing
        let bpmInt = Int(data.bpm)
        try? await appState.serialService.send("BPM:\(bpmInt)")
        gridVM?.bpm = data.bpm
        try? await Task.sleep(for: .milliseconds(20))

        for td in data.tracks {
            let t = td.index

            try? await appState.serialService.send("VOL:\(t):\(td.mixer.volume)")
            try? await Task.sleep(for: .milliseconds(10))
            try? await appState.serialService.send("PAN:\(t):\(td.mixer.pan)")
            try? await Task.sleep(for: .milliseconds(10))

            if td.mixer.mute {
                try? await appState.serialService.send("MUTE:\(t)")
                try? await Task.sleep(for: .milliseconds(10))
            }
            if td.mixer.solo {
                try? await appState.serialService.send("SOLO:\(t)")
                try? await Task.sleep(for: .milliseconds(10))
            }

            // Load sample if present
            if !td.sampler.samplePath.isEmpty {
                try? await appState.serialService.send("LOADSAMPLE:\(t):\(td.sampler.samplePath)")
                try? await Task.sleep(for: .milliseconds(50))
            }

            // Set sampler mode
            try? await appState.serialService.send("SAMPLEPARAM:\(t):MODE:\(td.sampler.mode)")
            try? await Task.sleep(for: .milliseconds(10))

            // Set sampler params
            try? await appState.serialService.send("SAMPLEPARAM:\(t):GAIN:\(td.sampler.gain)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):PITCH:\(td.sampler.pitchSemitones)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):CENTS:\(td.sampler.pitchCents)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):ROOTNOTE:\(td.sampler.rootNote)")
            try? await Task.sleep(for: .milliseconds(10))

            try? await appState.serialService.send("SAMPLEPARAM:\(t):START:\(td.sampler.sampleStart)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):END:\(td.sampler.sampleEnd)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):LOOP:\(td.sampler.loopEnabled ? 1 : 0)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):LOOPSTART:\(td.sampler.loopStart)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):LOOPEND:\(td.sampler.loopEnd)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):ONESHOT:\(td.sampler.oneShot ? 1 : 0)")
            try? await Task.sleep(for: .milliseconds(10))

            // ADSR
            try? await appState.serialService.send("SAMPLEPARAM:\(t):ATTACK:\(td.sampler.attackMs)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):DECAY:\(td.sampler.decayMs)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):SUSTAIN:\(td.sampler.sustainLevel)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):RELEASE:\(td.sampler.releaseMs)")
            try? await Task.sleep(for: .milliseconds(10))

            // Grain params
            try? await appState.serialService.send("SAMPLEPARAM:\(t):GRAINPOS:\(td.sampler.grainPosition)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):GRAINWIN:\(td.sampler.grainWindowSize)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):GRAINSIZE:\(td.sampler.grainSizeMs)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):GRAINCOUNT:\(td.sampler.grainCount)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):GRAINSPREAD:\(td.sampler.grainSpread)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):GRAINENV:\(td.sampler.grainEnvShape)")
            try? await Task.sleep(for: .milliseconds(10))

            // Chop params
            try? await appState.serialService.send("SAMPLEPARAM:\(t):CHOPSENS:\(td.sampler.chopSensitivity)")
            try? await appState.serialService.send("SAMPLEPARAM:\(t):CHOPTRIG:\(td.sampler.chopTriggerMode)")
            try? await Task.sleep(for: .milliseconds(10))

            // Drum pads
            if td.isDrumMachine {
                try? await appState.serialService.send("SETDRUMMODE:\(t):1")
                try? await Task.sleep(for: .milliseconds(10))

                for pd in td.drumPads {
                    if !pd.samplePath.isEmpty {
                        try? await appState.serialService.send("LOADPAD:\(t):\(pd.padIndex):\(pd.samplePath)")
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                }
            }

            // Synth engine
            try? await appState.serialService.send("ENGINE:\(t):\(td.synthEngine.engine)")
            try? await Task.sleep(for: .milliseconds(10))
            try? await appState.serialService.send("TIMBRE:\(t):\(td.synthEngine.timbre)")
            try? await appState.serialService.send("HARMONICS:\(t):\(td.synthEngine.harmonics)")
            try? await appState.serialService.send("MORPH:\(t):\(td.synthEngine.morph)")
            try? await Task.sleep(for: .milliseconds(10))
        }

        appState.project.isDirty = false
    }

    private func restoreSampler(_ s: SamplerState, from d: SamplerData) {
        s.samplePath = d.samplePath
        s.sampleName = d.sampleName
        s.samplerMode = d.mode
        s.gain = d.gain
        s.pitchSemitones = d.pitchSemitones
        s.pitchCents = d.pitchCents
        s.rootNote = d.rootNote
        s.sampleStart = d.sampleStart
        s.sampleEnd = d.sampleEnd
        s.loopEnabled = d.loopEnabled
        s.loopStart = d.loopStart
        s.loopEnd = d.loopEnd
        s.oneShot = d.oneShot
        s.attackMs = d.attackMs
        s.decayMs = d.decayMs
        s.sustainLevel = d.sustainLevel
        s.releaseMs = d.releaseMs
        s.grainPosition = d.grainPosition
        s.grainWindowSize = d.grainWindowSize
        s.grainSizeMs = d.grainSizeMs
        s.grainCount = d.grainCount
        s.grainSpread = d.grainSpread
        s.grainEnvShape = d.grainEnvShape
        s.chopSensitivity = d.chopSensitivity
        s.chopTriggerMode = d.chopTriggerMode
    }

    private func restoreMIDIClip(_ clip: MIDIClip, from d: MIDIClipData) {
        clip.name = d.name
        clip.lengthBars = d.lengthBars
        clip.timeSignature = TimeSignature(
            numerator: d.timeSignatureNumerator,
            denominator: d.timeSignatureDenominator
        )
        clip.events = d.events.map { e in
            MIDIEvent(
                note: e.note,
                velocity: e.velocity,
                startStep: e.startStep,
                duration: e.duration,
                channel: e.channel
            )
        }
        clip.ccAutomation = d.ccAutomation.map { p in
            CCPoint(step: p.step, value: p.value, cc: p.cc)
        }
    }

    // MARK: - Save / Load (Mac filesystem + SD card backup)

    func saveProject(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        appState.project.name = trimmed

        let data = captureProjectData()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let jsonData = try encoder.encode(data)
            let fileURL = Self.projectsDirectory.appendingPathComponent("\(trimmed).json")
            try jsonData.write(to: fileURL, options: .atomic)

            appState.project.isDirty = false

            // Also upload to SD card as backup (fire-and-forget)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                Task {
                    try? await appState.serialService.send("MKDIR:/projects")
                    try? await Task.sleep(for: .milliseconds(20))
                    try? await appState.serialService.send("MKDIR:/projects/\(trimmed)")
                    try? await Task.sleep(for: .milliseconds(20))

                    // Upload as base64 to avoid line-ending issues
                    let b64 = jsonData.base64EncodedString()
                    try? await appState.serialService.send("UPLOAD:projects/\(trimmed)/project.json:\(b64.count)")
                    try? await Task.sleep(for: .milliseconds(10))
                    try? await appState.serialService.send(b64)
                }
            }
        } catch {
            // Save failed silently — could add error reporting later
        }

        isSaving = false
    }

    func loadProject(name: String) {
        let fileURL = Self.projectsDirectory.appendingPathComponent("\(name).json")
        isLoading = true

        do {
            let jsonData = try Data(contentsOf: fileURL)
            let data = try JSONDecoder().decode(ProjectData.self, from: jsonData)

            Task {
                await restoreFromProjectData(data)
                isLoading = false
            }
        } catch {
            isLoading = false
        }
    }

    func newProject() {
        appState.project.name = "Untitled"
        appState.project.isDirty = false

        // Reset tracks to defaults
        for (i, track) in appState.tracks.enumerated() {
            track.name = MixerViewModel.trackNames[i]
            track.trackType = .synth
            track.isDrumMachine = false
            track.samplerState = SamplerState()
            track.drumPads = (0..<8).map { DrumPadState(padIndex: $0) }
            track.midiClip = MIDIClip()
            track.arrangementClips = []
        }

        // Reset mixer
        mixerVM.volumes = Array(repeating: 80, count: 8)
        mixerVM.pans = Array(repeating: 0, count: 8)
        mixerVM.mutes = Array(repeating: false, count: 8)
        mixerVM.solos = Array(repeating: false, count: 8)

        // Reset synth engine
        synthEngineVM.engineModel = 0
        synthEngineVM.timbre = 500
        synthEngineVM.harmonics = 500
        synthEngineVM.morph = 500

        // Reset BPM
        gridVM?.bpm = 120

        // Send BPM reset to firmware
        Task {
            try? await appState.serialService.send("BPM:120")
        }
    }

    func listProjects() {
        let fm = FileManager.default
        do {
            let files = try fm.contentsOfDirectory(at: Self.projectsDirectory,
                                                    includingPropertiesForKeys: [.contentModificationDateKey],
                                                    options: .skipsHiddenFiles)
            projectNames = files
                .filter { $0.pathExtension == "json" }
                .sorted { a, b in
                    let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return da > db  // newest first
                }
                .map { $0.deletingPathExtension().lastPathComponent }
        } catch {
            projectNames = []
        }
    }

    func deleteProject(name: String) {
        let fileURL = Self.projectsDirectory.appendingPathComponent("\(name).json")
        try? FileManager.default.removeItem(at: fileURL)

        // Also delete from SD
        Task {
            try? await appState.serialService.send("DELETEFILE:/projects/\(name)/project.json")
        }

        listProjects()
    }

    // MARK: - Mac export/import

    func exportToMac() {
        let data = captureProjectData()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(data) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(appState.project.name).json"
        panel.title = "Export Project"

        if panel.runModal() == .OK, let url = panel.url {
            try? jsonData.write(to: url, options: .atomic)
        }
    }

    func importFromMac() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Import Project"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let jsonData = try Data(contentsOf: url)
                let data = try JSONDecoder().decode(ProjectData.self, from: jsonData)

                Task {
                    await restoreFromProjectData(data)
                }
            } catch {
                // Import failed silently
            }
        }
    }
}

// MARK: - Color hex conversion helpers

extension Color {
    func toHexString() -> String {
        guard let cgColor = NSColor(self).usingColorSpace(.sRGB) else { return "0000FF" }
        let r = Int(cgColor.redComponent * 255)
        let g = Int(cgColor.greenComponent * 255)
        let b = Int(cgColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }

    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let val = UInt32(hex, radix: 16) else {
            self.init(.blue)
            return
        }
        self.init(hex: val)
    }
}
