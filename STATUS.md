# Sampler-Crow — Project Status

**Last updated:** 2026-04-05
**Current phase:** Phase 7b complete, ready for Phase 7c or 8

A portable music workstation (Dirtywave M8 / OP-XY / SP-404 style) built on Teensy 4.1, with a native macOS SwiftUI host app for development, monitoring, and control.

## What works today

### Hardware
- **Teensy 4.1** — bare board, micro-USB to Mac, SD card inserted, no PSRAM yet
- **Novation Launchpad Mini MK3** — connected via Mac USB (temporary; future: via Teensy USB host)
- **Audio I/O** — Teensy USB Audio routed to any class-compliant interface on the Mac (UAD Apollo verified)

### Teensy Firmware (`firmware/`)
- Composite USB device: **Serial + MIDI + Audio**
- **8-voice multi-timbral synth**:
  - Track 0: Kick (60Hz sine + amp env)
  - Track 1: Snare (noise + triangle tone)
  - Track 2: Closed Hat (HPF noise, short)
  - Track 3: Open Hat (HPF noise, longer)
  - Track 4: Clap (BPF noise burst)
  - Track 5: Bass (saw + LPF, percussive)
  - Track 6: Lead (square + LPF, percussive, also external MIDI input)
  - Track 7: Pluck (triangle + fast decay)
- **Sequencer engine**: 8 tracks × 8 steps, BPM clock, swing-ready, demo beat pre-programmed
- **Serial protocol**: `PING`, `NOTE_ON`, `NOTE_OFF`, `TRIG:track:note:vel`, `PLAY`, `STOP`, `CLEAR`, `BPM`, `TOGGLE:track:step`, `STATUS`, `GRID`, `VOL:track:0-100`, `MUTE:track`, `SOLO:track`, `MIXER`
- **Mixer engine**: per-track volume faders (0-100), mute, solo with proper solo-override logic. Gains computed as `defaultGain[track] * trackVolume[track]` with mute/solo override
- **Grid state** emitted via serial `GRD:c0,c1,...,c63` and MIDI ch16 for Launchpad LEDs

### macOS Host App (`SamplerCrowApp/`)
Built in **SwiftUI, Swift 6, macOS 15+**. Deployed to `/Applications/Sampler Crow.app`.
- **SerialService** — POSIX `/dev/cu.usbmodem*`, async line reader, IOKit-based Teensy discovery by vendor ID 0x16C0
- **MIDIService** — CoreMIDI, routes grid messages to GridViewModel
- **AudioService** — **raw CoreAudio AUHAL input capture** (`CoreAudioInputCapture`), captures from specific Teensy device independently of system default. Separate `AVAudioEngine` output with `AVAudioSourceNode` at 44.1kHz → auto sample-rate conversion via mainMixerNode → any output device (built-in, UAD, Loopback, etc.)
- **LaunchpadService** — USB MIDI, finds "LPMiniMK3 MIDI", enters programmer mode, LED control via Note On velocity = palette color
- **DeviceDiscoveryService** — IOKit USB hotplug, auto-reconnect on firmware upload
- **GridViewModel** — sends `TOGGLE:track:step` over serial, receives `GRD:` updates from Teensy, mirrors to both virtual grid and real Launchpad
- **Views**:
  - **Launchpad tab**: 8×8 Canvas-drawn grid with Play/Stop transport
  - **Audio tab**: real-time waveform + L/R meters, output device picker, Test Tone, Reconnect Audio, tap call counter
  - **Console tab**: serial log with command input, filters POT/CPU/MEM noise
  - **Mixer tab**: 8 channel strips with per-track volume faders, mute (M) and solo (S) buttons, color-coded per track, syncs state from Teensy via `MIXER` command

### Verified end-to-end
- Teensy produces audio (peak ~20k/32k verified via ffmpeg)
- App captures Teensy audio (Tap calls counting, waveform visible, meters working)
- Audio routes to UAD Apollo (48kHz) with auto sample-rate conversion from Teensy's 44.1kHz
- Real Launchpad LEDs mirror virtual grid, pad presses toggle sequencer steps
- Sequencer plays back a demo drum beat

## Known limitations / TODO
- **Engine: stopped** indicator is stale (we bypassed AVAudioEngine input for raw CoreAudio)
- No PSRAM → capped at 4 concurrent tracks if we scale up, currently all 8 fit
- No SD card file loading yet (samples)
- Bass/Lead voices are percussive; they need sustain+release for proper melodic playing but we disabled it to prevent stuck notes
- External MIDI (KeyStep, etc.) triggers Track 6 (Lead) hardcoded
- No persistence (patterns reset on reboot)
- Launchpad connects via Mac USB, not yet via Teensy USB Host

## Roadmap — what's next

### ~~Phase 7b — Functional Mixer~~ DONE
- Per-track volume faders (0-100, draggable)
- Mute/solo buttons with proper solo-override logic
- UI tab: 8 color-coded channel strips with fader + M/S buttons
- Firmware: `VOL:track:value`, `MUTE:track`, `SOLO:track`, `MIXER` commands
- Teensy responds with `MIX:vol0,vol1,...|mute0,...|solo0,...`

### Phase 7c — Velocity/Pitch per step
- Hold a Launchpad pad + turn virtual knob → set step velocity
- Shift-hold → set step pitch
- Launchpad LED brightness reflects velocity

### Phase 8 — Drum Sampler (biggest leap)
- Port the `DrumMode` from `/Users/levperrey/Documents/Claude/new_hits`
- Load WAV files from Teensy SD card (built-in slot)
- `AudioPlaySdWav` per drum pad
- Replace synthesized drums with real samples
- This is when it becomes SP-404-like

### Phase 9 — Pattern save/load
- Write patterns to SD card as JSON
- `SAVE:slot` / `LOAD:slot` commands
- Survives power cycles

### Phase 10 — Plaits synth
- Vendor Mutable Instruments Plaits DSP
- 16-engine macro oscillator on one of the synth tracks
- Full Eurorack-quality synthesis

### Later phases (see `.planning/refactored-hatching-treasure.md`)
- Chord progression sequencer (Sinfonion-style)
- Scale quantizer
- 5 sampler modes (Pitch/Grain/Chop/Drum/Multi) from new_hits
- USB Host hub for Launchpad + class-compliant audio interface
- CrowPanel 5" touchscreen UI (ESP32-S3)
- Effects per track + AUX sends
- Live looping
- PSRAM upgrade → 8 full tracks

## Build & deploy

### Firmware (Teensy)
```bash
cd ~/Documents/Claude/Sampler-Crow
pio run
# Upload: put Teensy in bootloader mode (press button), then:
~/.platformio/packages/tool-teensy/teensy_loader_cli --mcu=TEENSY41 -w -v .pio/build/teensy41/firmware.hex
```

### macOS App
```bash
cd ~/Documents/Claude/Sampler-Crow/SamplerCrowApp
swift build -c release
cp .build/release/SamplerCrowApp "/Applications/Sampler Crow.app/Contents/MacOS/Sampler Crow"
xattr -cr "/Applications/Sampler Crow.app"
codesign --force --sign - "/Applications/Sampler Crow.app/Contents/MacOS/Sampler Crow"
open "/Applications/Sampler Crow.app"
```

The app bundle at `/Applications/Sampler Crow.app` contains the `Info.plist` and icon scaffolding but the code is all under `SamplerCrowApp/`. Rebuild replaces the binary in-place.

## Project structure

```
Sampler-Crow/
├── STATUS.md                    # this file
├── HARDWARE_DESIGN.md           # original hardware planning doc
├── SOFTWARE_DESIGN.md           # original software planning doc
├── platformio.ini               # Teensy build config
├── firmware/                    # Teensy 4.1 firmware
│   └── src/
│       ├── main.cpp             # entry point, audio graph, MIDI routing
│       ├── config.h             # pins, feature flags, constants
│       ├── sequencer.h/.cpp     # 8-track step sequencer engine
│       └── voices.h/.cpp        # 8 synth voices (drums + bass/lead/pluck)
├── SamplerCrowApp/              # macOS SwiftUI host app
│   ├── Package.swift            # Swift Package Manager config
│   └── SamplerCrowApp/
│       ├── SamplerCrowApp.swift # @main entry
│       ├── Models/              # ConnectionStatus, LogEntry, PadColor, GridNote, KeyboardMapping
│       ├── Services/            # Serial, MIDI, Audio, Launchpad, DeviceDiscovery
│       ├── ViewModels/          # AppState, GridVM, SerialConsoleVM, KeyboardVM, MixerVM
│       ├── Views/               # MainView, GridView, AudioMonitorView, SerialConsoleView, MixerView, StatusBarView
│       └── Theme/AppTheme.swift
├── esp32/                       # CrowPanel 5" firmware (Phase 13, not started)
└── chrome-emulator/             # deprecated web UI (kept for reference)
```

## Continuing on another machine

1. `git clone` this repo
2. Install PlatformIO: `pip install platformio` (use Python 3.13, NOT 3.14 — has a known SCons bug)
3. Connect Teensy via micro-USB
4. `cd Sampler-Crow && pio run -t upload` (press Teensy button when prompted)
5. `cd SamplerCrowApp && swift build -c release`
6. Deploy app (see commands above)
7. Launch app, plug in Novation Launchpad Mini MK3, select your audio interface in the Audio tab

**Important caveat on macOS 26 / Swift 6**: all audio callbacks must be in `nonisolated static` methods. Swift 6 strict concurrency enforces actor isolation at runtime, and audio callbacks run on real-time threads that will crash if they touch `@MainActor` state. See `AudioService.swift` for the pattern.

## Reference project
The sampler engine will be ported from `/Users/levperrey/Documents/Claude/new_hits` (a JUCE plugin with Pitch/Grain/Chop/Drum/Multi modes). Start with DrumMode for Phase 8.
