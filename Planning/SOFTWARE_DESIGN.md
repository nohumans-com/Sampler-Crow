# Sampler-Crow: Software Design Document (v2)

## Overview

The software runs on **three processors**:

1. **Teensy 4.1** — Audio DSP brain. Synthesis, sampling, effects, MIDI, USB MIDI Host, physical controls. C++ with Arduino + Teensy Audio Library.
2. **CrowPanel ESP32-S3** — Touch UI brain. Menus, virtual keyboard, parameter display. C++ with Arduino + TFT_eSPI/LVGL.
3. **ESP32-S3 Dev Board** — USB Audio bridge (experimental). Receives audio from USB interface, passes to Teensy via I2S. C with ESP-IDF.

```
┌──────────────┐  Serial UART  ┌──────────────────┐  I2S2 Bus  ┌──────────────┐
│  CrowPanel   │ ◄────────────►│   Teensy 4.1     │ ◄──────────│  ESP32-S3    │
│  ESP32-S3    │  Commands &   │                   │  Audio     │  Audio       │
│              │  Status       │  Audio Library    │  Data      │  Bridge      │
│  LVGL UI     │               │  USB Host (MIDI)  │            │  USB Audio   │
│  Touch Input │               │  Serial MIDI I/O  │  Serial8   │  Host        │
│  Menus       │               │  Pots / Buttons   │ ◄──────────│  (ESP-IDF)   │
└──────────────┘               └──────────────────┘  Control    └──────────────┘
```

---

## Development Environment

### Teensy 4.1
- **Arduino IDE 2.x** + **Teensyduino** add-on
- Board: "Teensy 4.1", CPU: "600 MHz", USB Type: "Serial + MIDI"

### CrowPanel ESP32-S3
- **Arduino IDE 2.x** with ESP32-S3 board package
- Board: "ESP32S3 Dev Module"

### ESP32-S3 Audio Bridge (Phase 9+)
- **ESP-IDF v5.x** (NOT Arduino — required for USB Audio host)
- Uses `usb_stream` component from esp-iot-solution
- This is the only part that requires ESP-IDF

---

## Serial Communication Protocol

### Message Format
```
COMMAND:PARAM1:PARAM2\n
```
All serial links run at **115200 baud** (increase to 921600 once stable).

### ESP32 → Teensy (UI commands)

| Command | Example | Description |
|---------|---------|-------------|
| `NOTE_ON` | `NOTE_ON:60:127` | Play MIDI note, velocity |
| `NOTE_OFF` | `NOTE_OFF:60` | Stop MIDI note |
| `PATCH` | `PATCH:3` | Load preset #3 |
| `PARAM` | `PARAM:CUTOFF:0.75` | Set parameter |
| `MODE` | `MODE:SYNTH` | Switch operating mode |
| `REC_START` | `REC_START` | Begin recording |
| `REC_STOP` | `REC_STOP` | Stop recording |
| `PLAY_SAMPLE` | `PLAY_SAMPLE:0` | Play sample slot |
| `FX` | `FX:REVERB:0.5` | Set effect level |
| `MIDI_THRU` | `MIDI_THRU:ON` | Enable MIDI thru |
| `USB_AUDIO` | `USB_AUDIO:ENABLE` | Switch I2S2 to USB audio input |
| `MIC` | `MIC:ENABLE` | Switch I2S2 to mic input |

### Teensy → ESP32 (Status updates)

| Message | Example | Description |
|---------|---------|-------------|
| `POT` | `POT:0:512` | Pot value changed |
| `BTN` | `BTN:1:PRESS` | Button pressed |
| `LEVEL` | `LEVEL:0.45:0.52` | Audio levels L/R |
| `STATE` | `STATE:RECORDING` | State change |
| `MIDI_IN` | `MIDI_IN:NOTE_ON:60:100:1` | MIDI received (from DIN or USB) |
| `USB_MIDI` | `USB_MIDI:CONNECTED` | Launchpad connected |
| `USB_AUDIO` | `USB_AUDIO:ACTIVE` | Audio bridge streaming |

### ESP32-S3 Audio Bridge → Teensy (Serial8)

| Message | Example | Description |
|---------|---------|-------------|
| `AUD_READY` | `AUD_READY:44100:16:2` | Audio stream info (rate, bits, channels) |
| `AUD_START` | `AUD_START` | Audio streaming began |
| `AUD_STOP` | `AUD_STOP` | Audio streaming stopped |
| `AUD_ERR` | `AUD_ERR:NO_DEVICE` | Error message |

---

## Teensy 4.1 Software Architecture

### File Structure

```
sampler-crow-teensy/
├── sampler-crow-teensy.ino    # Main entry point
├── config.h                   # Pin definitions, constants
├── audio_engine.h/.cpp        # Audio graph setup
├── synth_voice.h/.cpp         # Oscillator + envelope + filter voices
├── sampler.h/.cpp             # Sample record/playback from SD
├── effects.h/.cpp             # Reverb, delay, filter chain
├── controls.h/.cpp            # Pot and button reading with debounce
├── serial_comms.h/.cpp        # UART protocol (ESP32 UI)
├── midi_handler.h/.cpp        # DIN MIDI (Serial3) + USB MIDI Host
├── usb_host.h/.cpp            # USB Host setup (Launchpad)
├── audio_bridge.h/.cpp        # I2S2 input management (mic vs USB audio)
└── patches/
    └── default_patches.h
```

### config.h

```cpp
#ifndef CONFIG_H
#define CONFIG_H

// --- Analog Inputs (Potentiometers) ---
#define POT_1_PIN   A2   // Pin 16 - Cutoff
#define POT_2_PIN   A3   // Pin 17 - Resonance
#define POT_3_PIN   A4   // Pin 24 - Attack/Decay
#define POT_4_PIN   A5   // Pin 25 - Volume/Mix
#define NUM_POTS    4

// --- Digital Inputs (Buttons) ---
#define BTN_1_PIN   2    // Play/Trigger
#define BTN_2_PIN   6    // Record
#define BTN_3_PIN   9    // Mode
#define BTN_4_PIN   22   // Shift/Function
#define NUM_BTNS    4

// --- Serial Ports ---
#define ESP_SERIAL       Serial1   // Pins 0,1 → CrowPanel
#define MIDI_SERIAL      Serial3   // Pins 14,15 → ubld.it MIDI breakout
#define BRIDGE_SERIAL    Serial8   // Pins 34,35 → ESP32-S3 Audio Bridge
#define ESP_BAUD         115200
#define BRIDGE_BAUD      115200

// --- Audio Settings ---
#define SAMPLE_RATE     44100
#define MAX_POLYPHONY   4
#define MAX_SAMPLES     16
#define MAX_SAMPLE_SEC  5

// --- Operating Modes ---
enum OperatingMode {
    MODE_SYNTH,
    MODE_SAMPLER,
    MODE_EFFECTS,
    MODE_LOOPER
};

// --- I2S2 Input Source ---
enum I2S2Source {
    I2S2_MIC,          // INMP441 microphone
    I2S2_USB_AUDIO     // ESP32-S3 Audio Bridge
};

#endif
```

### USB MIDI Host (Launchpad Support)

```cpp
// usb_host.h
#include <USBHost_t36.h>

// USB Host objects
USBHost myusb;
USBHub hub1(myusb);
MIDIDevice usbMidi(myusb);

void initUSBHost() {
    myusb.begin();
}

void updateUSBHost() {
    myusb.Task();

    // Check for USB MIDI messages from Launchpad
    if (usbMidi.read()) {
        byte type = usbMidi.getType();
        byte channel = usbMidi.getChannel();
        byte data1 = usbMidi.getData1();
        byte data2 = usbMidi.getData2();

        // Forward to audio engine
        handleMidiMessage(type, channel, data1, data2);

        // Forward to ESP32 for UI display
        ESP_SERIAL.print("MIDI_IN:USB:");
        ESP_SERIAL.print(type);
        ESP_SERIAL.print(":");
        ESP_SERIAL.print(data1);
        ESP_SERIAL.print(":");
        ESP_SERIAL.println(data2);
    }
}
```

### Hardware MIDI (DIN via ubld.it)

```cpp
// midi_handler.h
#include <MIDI.h>

MIDI_CREATE_INSTANCE(HardwareSerial, Serial3, dinMidi);

void initMidi() {
    dinMidi.begin(MIDI_CHANNEL_OMNI);
    dinMidi.turnThruOff();  // We handle routing manually
}

void updateMidi() {
    if (dinMidi.read()) {
        byte type = dinMidi.getType();
        byte channel = dinMidi.getChannel();
        byte data1 = dinMidi.getData1();
        byte data2 = dinMidi.getData2();

        // Forward to audio engine
        handleMidiMessage(type, channel, data1, data2);

        // Forward to ESP32 for UI display
        ESP_SERIAL.print("MIDI_IN:DIN:");
        ESP_SERIAL.print(type);
        ESP_SERIAL.print(":");
        ESP_SERIAL.print(data1);
        ESP_SERIAL.print(":");
        ESP_SERIAL.println(data2);
    }
}

// Send MIDI out (e.g., from sequencer or clock)
void sendMidiNoteOn(byte note, byte velocity, byte channel) {
    dinMidi.sendNoteOn(note, velocity, channel);
}

void sendMidiClock() {
    dinMidi.sendRealTime(midi::Clock);
}
```

### Unified MIDI Handler

```cpp
// Called from both USB MIDI and DIN MIDI
void handleMidiMessage(byte type, byte channel, byte data1, byte data2) {
    switch (type) {
        case midi::NoteOn:
            if (data2 > 0) {
                triggerNote(data1, data2);  // Play synth voice or sample
            } else {
                releaseNote(data1);
            }
            break;
        case midi::NoteOff:
            releaseNote(data1);
            break;
        case midi::ControlChange:
            handleCC(data1, data2, channel);
            break;
        case midi::ProgramChange:
            loadPatch(data1);
            break;
    }

    // MIDI Thru: forward DIN input to USB output and vice versa
    if (midiThruEnabled) {
        dinMidi.send((midi::MidiType)type, data1, data2, channel);
    }
}
```

### Audio Engine (Expanded for v2)

```cpp
// audio_engine.h - Key additions for v2
#include <Audio.h>

// --- Synth Voices (4-voice poly) ---
AudioSynthWaveform       osc[8];        // 2 oscillators × 4 voices
AudioMixer4              oscMix[4];      // Mix 2 oscs per voice
AudioFilterStateVariable filter[4];      // Filter per voice
AudioEffectEnvelope      env[4];         // ADSR per voice
AudioMixer4              voiceMixer;      // Mix all 4 voices

// --- Sampler ---
AudioPlaySdWav           samplePlayer;
AudioRecordQueue         recorder;

// --- Effects ---
AudioEffectFreeverbStereo reverb;
AudioEffectDelay         delayL, delayR;
AudioMixer4              fxMixL, fxMixR;

// --- I/O ---
AudioInputI2S            lineInput;       // Audio Shield line in
AudioOutputI2S           audioOutput;     // Audio Shield line out
AudioInputI2S2           i2s2Input;       // INMP441 mic OR USB Audio Bridge

// --- Monitoring ---
AudioAnalyzePeak         peakL, peakR;

// --- Master ---
AudioMixer4              masterMixL, masterMixR;

AudioControlSGTL5000     codec;
```

### Main Loop

```cpp
void setup() {
    AudioMemory(60);

    codec.enable();
    codec.volume(0.7);
    codec.inputSelect(AUDIO_INPUT_LINEIN);
    codec.lineInLevel(5);
    codec.lineOutLevel(13);

    initControls();
    initMidi();
    initUSBHost();

    ESP_SERIAL.begin(ESP_BAUD);
    BRIDGE_SERIAL.begin(BRIDGE_BAUD);

    if (!SD.begin(10)) {
        ESP_SERIAL.println("ERROR:SD_FAIL");
    }
}

void loop() {
    updateControls();       // Read pots + buttons
    updateMidi();           // Check DIN MIDI
    updateUSBHost();        // Check USB MIDI (Launchpad)
    processSerialCommands();// Commands from CrowPanel
    processBridgeSerial();  // Status from Audio Bridge
    updateMeters();         // Send audio levels to UI
}
```

---

## CrowPanel ESP32-S3 Software (UI)

### File Structure

```
sampler-crow-ui/
├── sampler-crow-ui.ino
├── config.h
├── ui_manager.h/.cpp      # Screen management
├── serial_comms.h/.cpp    # UART to Teensy
├── screens/
│   ├── screen_synth.h     # Synth controls + virtual piano
│   ├── screen_sampler.h   # Sample browser + waveform
│   ├── screen_mixer.h     # Effects + levels
│   ├── screen_midi.h      # MIDI monitor + routing
│   └── screen_settings.h  # Config, MIDI channel, USB audio
└── widgets/
    ├── knob_widget.h      # Virtual rotary knob
    ├── level_meter.h      # VU meter
    ├── keyboard_widget.h  # Touch piano
    └── midi_monitor.h     # MIDI activity display
```

### UI Screens

```
TAB BAR: [SYNTH] [SAMPLER] [MIXER] [MIDI] [SETTINGS]

SYNTH SCREEN:
┌────────────────────────────────────┐
│ [CUT] [RES] [ATK] [VOL]  knobs    │
│ Wave: [SAW] [SQR] [TRI] [SIN]     │
│ ┌──────────────────────────────┐   │
│ │  Waveform Display            │   │
│ └──────────────────────────────┘   │
│ ┌──────────────────────────────┐   │
│ │  Touch Piano Keyboard        │   │
│ └──────────────────────────────┘   │
│ [PLAY] [REC]  L ████  R ████      │
└────────────────────────────────────┘

MIDI SCREEN (new):
┌────────────────────────────────────┐
│ USB MIDI: ● Connected (Launchpad)  │
│ DIN MIDI: ● Active                 │
│                                    │
│ MIDI Monitor:                      │
│  IN  Ch1 NoteOn  C4  vel:100      │
│  IN  Ch1 CC#1    val:64           │
│  OUT Ch1 Clock                     │
│                                    │
│ Routing: [DIN→SYNTH] [USB→SAMPLE] │
│ Thru: [ON/OFF]  Channel: [OMNI]   │
└────────────────────────────────────┘

SETTINGS SCREEN (expanded):
┌────────────────────────────────────┐
│ USB Audio Bridge: [ENABLE/DISABLE] │
│ Audio Source: [LINE IN] [MIC] [USB]│
│ MIDI Channel: [1-16 / OMNI]       │
│ MIDI Thru: [ON / OFF]             │
│ Display Brightness: [slider]       │
│ Sample Rate: 44100 Hz              │
│ CPU Usage: 45%  Memory: 32/60      │
└────────────────────────────────────┘
```

---

## ESP32-S3 Audio Bridge Software (Experimental)

### Overview

This runs on a separate ESP32-S3 dev board using **ESP-IDF** (not Arduino). It:
1. Enumerates a class-compliant USB audio interface via USB OTG
2. Reads audio samples from the USB audio stream
3. Outputs them via I2S to the Teensy's I2S2 bus
4. Reports status to Teensy via Serial (UART)

### ESP-IDF Project Structure

```
sampler-crow-audio-bridge/
├── CMakeLists.txt
├── sdkconfig
├── main/
│   ├── CMakeLists.txt
│   ├── main.c
│   ├── usb_audio_host.c    # USB Audio Class host
│   ├── usb_audio_host.h
│   ├── i2s_output.c        # I2S output to Teensy
│   ├── i2s_output.h
│   ├── serial_status.c     # UART status to Teensy
│   └── serial_status.h
└── components/
    └── usb_stream/          # Espressif's USB stream component
```

### Key Code Sketch

```c
// main.c (ESP-IDF)
#include "usb_stream.h"
#include "driver/i2s_std.h"
#include "driver/uart.h"

#define I2S_BCK_PIN     12
#define I2S_WS_PIN      11
#define I2S_DOUT_PIN    10
#define UART_TX_PIN     17

static i2s_chan_handle_t i2s_tx_handle;

// USB Audio callback — called when audio data arrives
static void usb_audio_rx_callback(uint8_t *data, size_t len, void *arg) {
    size_t bytes_written;
    // Write received USB audio directly to I2S output → Teensy
    i2s_channel_write(i2s_tx_handle, data, len, &bytes_written, portMAX_DELAY);
}

void app_main(void) {
    // Initialize I2S output (to Teensy I2S2)
    i2s_std_config_t i2s_config = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(44100),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(16, I2S_SLOT_MODE_STEREO),
        .gpio_cfg = {
            .bclk = I2S_BCK_PIN,
            .ws = I2S_WS_PIN,
            .dout = I2S_DOUT_PIN,
        },
    };
    // ... (I2S init code)

    // Initialize USB Host for Audio Class
    uac_config_t uac_config = {
        .mic_samples_frequence = 44100,
        .mic_bit_resolution = 16,
        .mic_cb = usb_audio_rx_callback,
        .mic_cb_arg = NULL,
    };
    // ... (USB host init)

    // Report ready via UART
    uart_write_bytes(UART_NUM_1, "AUD_READY:44100:16:2\n", 21);

    // Main loop — USB task runs in background
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
```

**Important caveats:**
- The ESP-IDF `usb_stream` component is experimental
- Not all USB audio interfaces are supported
- Latency depends on USB polling interval (typically 1ms for audio)
- This is a Phase 9 feature — build everything else first

---

## Incremental Claude Code Development Plan

### Phase 1: Hello Tone
**Prompt:** *"Write a Teensy 4.1 sketch using the Audio Library that plays a 440Hz sawtooth wave through the Audio Shield. Include SGTL5000 codec setup."*

### Phase 2: Pot Controls Frequency
**Prompt:** *"Add analog reading of pin A2 and map it to oscillator frequency from 100Hz to 2000Hz."*

### Phase 3: Button Triggers Envelope
**Prompt:** *"Add an ADSR envelope. Button on pin D2 triggers noteOn on press and noteOff on release."*

### Phase 4: Full Synth Voice
**Prompt:** *"Create a 2-oscillator synth voice with sawtooth + square, lowpass filter, ADSR envelope. Map A2→cutoff, A3→resonance, A4→attack, A5→volume."*

### Phase 5: Serial Communication
**Prompt:** *"Add Serial1 communication with ESP32. Teensy sends POT:0:512 and BTN:0:PRESS. Parse incoming NOTE_ON:60:127 to trigger notes."*

### Phase 6: CrowPanel Basic UI
**Prompt:** *"Write ESP32-S3 sketch for Elecrow CrowPanel 3.5" with parameter display and touch piano keyboard. Send NOTE_ON/NOTE_OFF over Serial1."*

### Phase 7: Hardware MIDI I/O
**Prompt:** *"Add MIDI library on Serial3 (pins 14,15) for the ubld.it breakout. Receive MIDI notes and forward to synth engine. Send MIDI clock out."*

### Phase 8: USB MIDI Host (Launchpad)
**Prompt:** *"Add USBHost_t36 with hub support. Detect USB MIDI device (Novation Launchpad). Forward received MIDI notes to synth. Map Launchpad pads to sample triggers."*

### Phase 9: Audio Input + Recording
**Prompt:** *"Add line-in pass-through from Audio Shield. Record to SD card as WAV. Button 2 starts/stops recording. 5-second max."*

### Phase 10: Sample Playback
**Prompt:** *"Play recorded samples from SD card. Button 1 triggers playback. Pot 1 controls playback pitch."*

### Phase 11: INMP441 Microphone
**Prompt:** *"Add INMP441 on I2S2 bus (pins D3,D4,D5). Allow switching between line-in and mic for recording source."*

### Phase 12: Effects Chain
**Prompt:** *"Add stereo reverb and delay. CrowPanel sends FX:REVERB:0.5 and FX:DELAY:0.3 to control dry/wet."*

### Phase 13: 4-Voice Polyphony
**Prompt:** *"Expand to 4-voice polyphony with voice stealing. Oldest voice gets reassigned when all busy."*

### Phase 14: Preset System
**Prompt:** *"Save/load synth patches to JSON files on SD. Button 3 cycles presets. CrowPanel shows preset name."*

### Phase 15: MIDI Screen on CrowPanel
**Prompt:** *"Add a MIDI tab to the CrowPanel UI. Show MIDI monitor (incoming notes/CCs), USB MIDI connection status, MIDI thru toggle, channel selector."*

### Phase 16: ESP32-S3 Audio Bridge (Experimental)
**Prompt:** *"Set up ESP-IDF project for ESP32-S3 audio bridge. Use usb_stream component to receive USB Audio Class input. Output via I2S to Teensy I2S2 bus. Report status via UART."*

### Phase 17: Advanced UI (LVGL)
**Prompt:** *"Upgrade CrowPanel to LVGL with tabbed screens, real-time waveform display, VU meters, and USB audio source selector."*

---

## Key Libraries & References

### Teensy
- **Audio System Design Tool:** https://www.pjrc.com/teensy/gui/
- **Audio Library Docs:** https://www.pjrc.com/teensy/td_libs_Audio.html
- **USBHost_t36 (USB MIDI):** https://github.com/PaulStoffregen/USBHost_t36
- **MIDI Library:** https://www.pjrc.com/teensy/td_libs_MIDI.html
- **Teensy 4.1 Pinout:** https://www.pjrc.com/store/teensy41.html

### ESP32-S3
- **ESP-IDF USB Stream:** https://github.com/espressif/esp-iot-solution/tree/master/components/usb/usb_stream
- **Elecrow CrowPanel Wiki:** https://www.elecrow.com/wiki
- **TFT_eSPI:** https://github.com/Bodmer/TFT_eSPI
- **LVGL:** https://docs.lvgl.io

### MIDI
- **MIDI TRS Type A Standard:** https://minimidi.world/
- **ubld.it MIDI Breakout:** https://ubld.it
