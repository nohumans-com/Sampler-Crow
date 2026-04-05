#include <Arduino.h>
#include <Audio.h>
#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include "config.h"
#include "sequencer.h"
#include "voices.h"

// =============================================================
// Sampler-Crow — Teensy 4.1 Music Workstation Firmware
// 8-voice multi-timbral: kick, snare, hats, clap, bass, lead, pluck
// =============================================================

// --- Voice 0: Kick ---
AudioSynthWaveform     v0_osc;
AudioEffectEnvelope    v0_ampEnv;
AudioEffectEnvelope    v0_pitchEnv;  // reserved for future use
AudioConnection        v0c1(v0_osc, 0, v0_ampEnv, 0);

// --- Voice 1: Snare ---
AudioSynthNoiseWhite   v1_noise;
AudioSynthWaveform     v1_tone;
AudioMixer4            v1_mix;
AudioEffectEnvelope    v1_env;
AudioConnection        v1c1(v1_noise, 0, v1_mix, 0);
AudioConnection        v1c2(v1_tone,  0, v1_mix, 1);
AudioConnection        v1c3(v1_mix,   0, v1_env, 0);

// --- Voice 2: Closed Hat ---
AudioSynthNoiseWhite   v2_noise;
AudioFilterStateVariable v2_hpf;
AudioEffectEnvelope    v2_env;
AudioConnection        v2c1(v2_noise, 0, v2_hpf, 0);
AudioConnection        v2c2(v2_hpf,   2, v2_env, 0);  // output 2 = high-pass

// --- Voice 3: Open Hat ---
AudioSynthNoiseWhite   v3_noise;
AudioFilterStateVariable v3_hpf;
AudioEffectEnvelope    v3_env;
AudioConnection        v3c1(v3_noise, 0, v3_hpf, 0);
AudioConnection        v3c2(v3_hpf,   2, v3_env, 0);

// --- Voice 4: Clap ---
AudioSynthNoiseWhite   v4_noise;
AudioFilterStateVariable v4_bpf;
AudioEffectEnvelope    v4_env;
AudioConnection        v4c1(v4_noise, 0, v4_bpf, 0);
AudioConnection        v4c2(v4_bpf,   1, v4_env, 0);  // output 1 = band-pass

// --- Voice 5: Bass ---
AudioSynthWaveform     v5_osc;
AudioFilterStateVariable v5_lpf;
AudioEffectEnvelope    v5_env;
AudioConnection        v5c1(v5_osc, 0, v5_lpf, 0);
AudioConnection        v5c2(v5_lpf, 0, v5_env, 0);    // output 0 = low-pass

// --- Voice 6: Lead ---
AudioSynthWaveform     v6_osc;
AudioFilterStateVariable v6_lpf;
AudioEffectEnvelope    v6_env;
AudioConnection        v6c1(v6_osc, 0, v6_lpf, 0);
AudioConnection        v6c2(v6_lpf, 0, v6_env, 0);

// --- Voice 7: Pluck ---
AudioSynthWaveform     v7_osc;
AudioEffectEnvelope    v7_env;
AudioConnection        v7c1(v7_osc, 0, v7_env, 0);

// --- Master mix (8 voices → 2 mixers → stereo output) ---
// AudioMixer4 has 4 inputs, so we use two stages
AudioMixer4            mixA;  // voices 0-3
AudioMixer4            mixB;  // voices 4-7
AudioMixer4            mixMaster;
AudioConnection        mc0(v0_ampEnv, 0, mixA, 0);
AudioConnection        mc1(v1_env,    0, mixA, 1);
AudioConnection        mc2(v2_env,    0, mixA, 2);
AudioConnection        mc3(v3_env,    0, mixA, 3);
AudioConnection        mc4(v4_env,    0, mixB, 0);
AudioConnection        mc5(v5_env,    0, mixB, 1);
AudioConnection        mc6(v6_env,    0, mixB, 2);
AudioConnection        mc7(v7_env,    0, mixB, 3);
AudioConnection        mm0(mixA,      0, mixMaster, 0);
AudioConnection        mm1(mixB,      0, mixMaster, 1);

// --- USB Audio Output ---
AudioOutputUSB         usbAudioOut;
AudioConnection        usbL(mixMaster, 0, usbAudioOut, 0);
AudioConnection        usbR(mixMaster, 0, usbAudioOut, 1);

#ifdef HAS_AUDIO_SHIELD
AudioOutputI2S         i2sOut;
AudioControlSGTL5000   codec;
AudioConnection        i2sL(mixMaster, 0, i2sOut, 0);
AudioConnection        i2sR(mixMaster, 0, i2sOut, 1);
#endif

// --- Sequencer ---
Sequencer seq;

// --- State ---
static float currentVolume = 0.7f;
static unsigned long lastMeterTime = 0;

// --- Pot/Button reading ---
static const int potPins[NUM_POTS] = { POT_1_PIN, POT_2_PIN, POT_3_PIN, POT_4_PIN };
static int potValues[NUM_POTS] = {0};
static int lastPotValues[NUM_POTS] = {0};
static const int POT_THRESHOLD = 4;

static const int btnPins[NUM_BTNS] = { BTN_PLAY_PIN, BTN_REC_PIN, BTN_MODE_PIN, BTN_SHIFT_PIN };
static bool btnStates[NUM_BTNS] = {false};
static bool lastBtnStates[NUM_BTNS] = {false};
static unsigned long lastDebounce[NUM_BTNS] = {0};
static const int DEBOUNCE_MS = 30;

// --- Sequencer callbacks ---
void onSeqNoteOn(uint8_t track, uint8_t note, uint8_t velocity) {
    voiceTrigger(track, note, velocity);
}

void onSeqNoteOff(uint8_t track, uint8_t note) {
    voiceRelease(track);
}

// --- Handle incoming USB MIDI ---
void handleMidiNoteOn(uint8_t channel, uint8_t note, uint8_t velocity) {
    if (channel == GRID_MIDI_CH) {
        // Grid pad press — toggle step in sequencer
        // Note format: (row)*10 + col, row 1-8, col 1-8
        uint8_t lpRow = note / 10;
        uint8_t lpCol = (note % 10) - 1;

        if (lpRow >= 1 && lpRow <= 8 && lpCol < 8) {
            uint8_t track = SEQ_MAX_TRACKS - lpRow;  // Row 8 = track 0 (top)
            uint8_t step = seq.getPageOffset() + lpCol;
            seq.toggleStep(track, step);
        }
        return;
    }

    // Musical MIDI — trigger lead voice (track 6) for external keyboards
    voiceTrigger(6, note, velocity);
}

void handleMidiNoteOff(uint8_t channel, uint8_t note, uint8_t velocity) {
    if (channel == GRID_MIDI_CH) return;
    voiceRelease(6);
}

void handleMidiCC(uint8_t channel, uint8_t cc, uint8_t value) {
    if (channel == GRID_MIDI_CH) {
        // CC 91-98 = top row function buttons on Launchpad
        // Use CC 91 = Play/Stop toggle
        if (cc == 91 && value > 0) {
            if (seq.isPlaying()) {
                seq.stop();
            } else {
                seq.start();
            }
        }
        // CC 93 = Clear all
        else if (cc == 93 && value > 0) {
            seq.clearAll();
        }
        // CC 94 = BPM down
        else if (cc == 94 && value > 0) {
            seq.setBPM(seq.getBPM() - 5.0f);
            Serial.printf("BPM:%.0f\n", seq.getBPM());
            seq.sendGridState();
        }
        // CC 95 = BPM up
        else if (cc == 95 && value > 0) {
            seq.setBPM(seq.getBPM() + 5.0f);
            Serial.printf("BPM:%.0f\n", seq.getBPM());
            seq.sendGridState();
        }
        return;
    }

    float normalized = value / 127.0f;
    switch (cc) {
        case 7:
            currentVolume = normalized;
            mixMaster.gain(0, normalized);
            mixMaster.gain(1, normalized);
            break;
    }
}

// --- Serial commands ---
void processCommand(const String& cmd);
String serialBuffer = "";

void processSerialInput() {
    while (Serial.available()) {
        char c = Serial.read();
        if (c == '\n') {
            processCommand(serialBuffer);
            serialBuffer = "";
        } else if (serialBuffer.length() < 128) {
            serialBuffer += c;
        }
    }
}

void processCommand(const String& cmd) {
    int firstColon = cmd.indexOf(':');
    String command = (firstColon > 0) ? cmd.substring(0, firstColon) : cmd;
    String params = (firstColon > 0) ? cmd.substring(firstColon + 1) : "";

    if (command == "PING") {
        Serial.println("PONG:SAMPLER_CROW:1.0");
    }
    else if (command == "NOTE_ON") {
        int sep = params.indexOf(':');
        uint8_t note = params.substring(0, sep).toInt();
        uint8_t vel = params.substring(sep + 1).toInt();
        // Trigger lead voice (track 6) for manual notes
        voiceTrigger(6, note, vel);
    }
    else if (command == "NOTE_OFF") {
        voiceRelease(6);
    }
    else if (command == "TRIG") {
        // TRIG:track:note:velocity — trigger any voice manually (for testing)
        int s1 = params.indexOf(':');
        int s2 = params.indexOf(':', s1 + 1);
        uint8_t tr = params.substring(0, s1).toInt();
        uint8_t nt = params.substring(s1 + 1, s2).toInt();
        uint8_t vl = params.substring(s2 + 1).toInt();
        voiceTrigger(tr, nt, vl);
    }
    else if (command == "BPM") {
        seq.setBPM(params.toFloat());
        Serial.printf("BPM:%.0f\n", seq.getBPM());
    }
    else if (command == "PLAY") {
        seq.start();
    }
    else if (command == "STOP") {
        seq.stop();
    }
    else if (command == "CLEAR") {
        seq.clearAll();
    }
    else if (command == "STATUS") {
        Serial.printf("STATUS:cpu=%.1f:mem=%d:bpm=%.0f:playing=%d:step=%d\n",
            AudioProcessorUsage(),
            AudioMemoryUsage(),
            seq.getBPM(),
            seq.isPlaying() ? 1 : 0,
            seq.getCurrentStep());
    }
    else if (command == "GRID") {
        seq.sendGridState();
    }
    else if (command == "TOGGLE") {
        int sep = params.indexOf(':');
        uint8_t track = params.substring(0, sep).toInt();
        uint8_t step = params.substring(sep + 1).toInt();
        seq.toggleStep(track, step);
    }
    else {
        Serial.printf("UNKNOWN:%s\n", cmd.c_str());
    }
}

// --- Read physical controls ---
void updateControls() {
    for (int i = 0; i < NUM_POTS; i++) {
        potValues[i] = analogRead(potPins[i]);
        if (abs(potValues[i] - lastPotValues[i]) > POT_THRESHOLD) {
            lastPotValues[i] = potValues[i];
        }
    }
    for (int i = 0; i < NUM_BTNS; i++) {
        bool reading = !digitalRead(btnPins[i]);
        if (reading != lastBtnStates[i]) {
            lastDebounce[i] = millis();
        }
        if ((millis() - lastDebounce[i]) > DEBOUNCE_MS) {
            if (reading != btnStates[i]) {
                btnStates[i] = reading;
                Serial.printf("BTN:%d:%s\n", i, reading ? "PRESS" : "RELEASE");
            }
        }
        lastBtnStates[i] = reading;
    }
}

void sendMeterData() {
    Serial.printf("CPU:%.1f\n", AudioProcessorUsage());
    Serial.printf("MEM:%d/%d\n", AudioMemoryUsage(), AudioMemoryUsageMax());
}

// =============================================================
// Setup
// =============================================================
void setup() {
    Serial.begin(115200);
    AudioMemory(AUDIO_MEM_BLOCKS);

    // Initialize all 8 voices (kick, snare, hats, clap, bass, lead, pluck)
    voicesInit();

    // Master mix — balance the 8 voices
    mixA.gain(0, 0.8f);  // kick
    mixA.gain(1, 0.6f);  // snare
    mixA.gain(2, 0.5f);  // closed hat
    mixA.gain(3, 0.4f);  // open hat
    mixB.gain(0, 0.5f);  // clap
    mixB.gain(1, 0.7f);  // bass
    mixB.gain(2, 0.5f);  // lead
    mixB.gain(3, 0.5f);  // pluck
    mixMaster.gain(0, 0.8f);
    mixMaster.gain(1, 0.8f);

    #ifdef HAS_AUDIO_SHIELD
    codec.enable();
    codec.volume(0.7f);
    #endif

    for (int i = 0; i < NUM_POTS; i++) {
        pinMode(potPins[i], INPUT);
        potValues[i] = analogRead(potPins[i]);
        lastPotValues[i] = potValues[i];
    }
    for (int i = 0; i < NUM_BTNS; i++) {
        pinMode(btnPins[i], INPUT_PULLUP);
        btnStates[i] = !digitalRead(btnPins[i]);
        lastBtnStates[i] = btnStates[i];
    }

    if (SD.begin(BUILTIN_SDCARD)) {
        Serial.println("SD card initialized");
    }

    // Sequencer callbacks
    seq.setNoteOnCallback(onSeqNoteOn);
    seq.setNoteOffCallback(onSeqNoteOff);

    // USB MIDI handlers
    usbMIDI.setHandleNoteOn(handleMidiNoteOn);
    usbMIDI.setHandleNoteOff(handleMidiNoteOff);
    usbMIDI.setHandleControlChange(handleMidiCC);

    // Pre-program a simple kick pattern on track 0 for demo (8 steps)
    // Demo pattern: kick on 1/3, snare on 2/4, hats on offbeats
    seq.setStep(0, 0, 36, 110);   // Kick
    seq.setStep(0, 4, 36, 110);
    seq.setStep(1, 2, 38, 100);   // Snare
    seq.setStep(1, 6, 38, 100);
    seq.setStep(2, 1, 42, 80);    // Closed hat
    seq.setStep(2, 3, 42, 80);
    seq.setStep(2, 5, 42, 80);
    seq.setStep(2, 7, 42, 80);
    seq.setStep(5, 0, 36, 100);   // Bass on 1
    seq.setStep(5, 4, 43, 100);   // Bass note on 3

    Serial.println("=== Sampler-Crow v0.2 ===");
    Serial.println("Sequencer ready. Send PLAY to start.");
    Serial.printf("BPM: %.0f, Steps: %d\n", seq.getBPM(), SEQ_MAX_STEPS);

    // Send initial grid state
    seq.sendGridState();
}

// =============================================================
// Main Loop
// =============================================================
void loop() {
    usbMIDI.read();
    processSerialInput();
    updateControls();
    seq.update();

    if (millis() - lastMeterTime > 50) {
        lastMeterTime = millis();
        sendMeterData();
    }
}
