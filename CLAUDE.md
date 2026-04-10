# Sampler-Crow — Claude Code Guidelines

## Build & Deploy

**IMPORTANT**: After making changes to firmware OR app code, ALWAYS build and deploy automatically. Do NOT wait for the user to ask.

### Deploy script
```bash
./deploy.sh          # build + flash firmware + build + deploy app
./deploy.sh firmware # firmware only (build + flash Teensy)
./deploy.sh app      # app only (build + deploy to /Applications)
```

### Manual commands (if deploy.sh fails)
```bash
# Firmware
export PATH="$PATH:/Users/lev/Library/Python/3.9/bin"
pio run                    # compile
pio run -t upload          # compile + flash Teensy (press button if needed)

# App
cd SamplerCrowApp && swift build -c release
cp .build/release/SamplerCrowApp "/Applications/Sampler Crow.app/Contents/MacOS/Sampler Crow"
codesign --force --sign - "/Applications/Sampler Crow.app/Contents/MacOS/Sampler Crow"
```

### Rules
- `pio run` only COMPILES. It does NOT upload. Always use `pio run -t upload` or `./deploy.sh` to flash the Teensy.
- After editing firmware files (`firmware/src/*`), you MUST flash the Teensy — the user should never have to ask for this.
- After editing app files (`SamplerCrowApp/**/*.swift`), you MUST rebuild and deploy to `/Applications/Sampler Crow.app`.
- If both firmware and app changed, deploy both.
- The user can launch the app with: `open "/Applications/Sampler Crow.app"`

## Architecture

### Teensy 4.1 Firmware (`firmware/src/`)
- C++ with Arduino framework + Teensy Audio Library
- PlatformIO build system (`platformio.ini`)
- USB composite device: Serial + MIDI + Audio
- Serial at USB speed (baud rate setting is ignored for USB serial)
- **IntervalTimer** drives sequencer step timing (hardware timer ISR)
- Audio graph: 8 voices → L/R mixer pairs (pan) → stereo master → USB Audio Out
- Volume/mute/solo controlled at the voice oscillator level, NOT mixer gains

### macOS App (`SamplerCrowApp/`)
- SwiftUI, Swift 6, macOS 15+, Swift Package Manager
- Services (actors): SerialService, MIDIService, AudioService, LaunchpadService
- ViewModels (@Observable, @MainActor): AppState, GridViewModel, MixerViewModel, SerialConsoleViewModel, KeyboardViewModel
- Serial communication: POSIX fd, blocking reads in Task.detached, writes via actor method
- Audio: Raw CoreAudio AUHAL input capture → ring buffer → AVAudioSourceNode output

### Serial Protocol (App ↔ Teensy)
Commands from app: PING, NOTE_ON, NOTE_OFF, TRIG, BPM, PLAY, STOP, CLEAR, STATUS, GRID, TOGGLE, VOL, MUTE, SOLO, PAN, MIXER
Responses from Teensy: PONG, GRD, SEQ, STEP, CPU, MEM, LVL, MIX, ACK, BPM, UNKNOWN

### Critical constraints
- **USB bandwidth**: Serial, MIDI, and Audio share one USB bus. Heavy serial traffic during fader drags can disrupt USB audio. Keep serial output minimal during real-time interaction.
- **Swift 6 concurrency**: Audio callbacks must be `nonisolated static` — never touch @MainActor state from real-time audio threads.
- **Teensy Audio ISR**: Voice trigger/release functions are ISR-safe. Serial.print is NOT ISR-safe.
- **Serial output**: Always guard with `Serial.availableForWrite()` to prevent blocking when USB TX buffer is full (e.g., when app is backgrounded).

## Testing
- Connect Teensy via micro-USB
- Launch app — auto-connects to Teensy serial, MIDI, and audio
- Spacebar = play/stop sequencer
- Console tab shows serial traffic for debugging
- ACK messages verify commands reached the Teensy
