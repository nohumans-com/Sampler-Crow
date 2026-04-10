#include <Arduino.h>
#include <Audio.h>
#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include <TeensyVariablePlayback.h>
#include "config.h"
#include "sequencer.h"
#include "voices.h"

// =============================================================
// Sampler-Crow v0.5 — Drum sampler (Phase 8)
// Key design: ISR-driven sequencer, non-blocking serial I/O,
// byte-budgeted input, TX ring buffer, no heap allocation
// =============================================================

// --- Voices (declared here, used by voices.cpp via extern) ---
AudioSynthWaveform     v0_osc;
AudioEffectEnvelope    v0_ampEnv;
AudioEffectEnvelope    v0_pitchEnv;
AudioConnection        v0c1(v0_osc, 0, v0_ampEnv, 0);

AudioSynthNoiseWhite   v1_noise;
AudioSynthWaveform     v1_tone;
AudioMixer4            v1_mix;
AudioEffectEnvelope    v1_env;
AudioConnection        v1c1(v1_noise, 0, v1_mix, 0);
AudioConnection        v1c2(v1_tone,  0, v1_mix, 1);
AudioConnection        v1c3(v1_mix,   0, v1_env, 0);

AudioSynthNoiseWhite   v2_noise;
AudioFilterStateVariable v2_hpf;
AudioEffectEnvelope    v2_env;
AudioConnection        v2c1(v2_noise, 0, v2_hpf, 0);
AudioConnection        v2c2(v2_hpf,   2, v2_env, 0);

AudioSynthNoiseWhite   v3_noise;
AudioFilterStateVariable v3_hpf;
AudioEffectEnvelope    v3_env;
AudioConnection        v3c1(v3_noise, 0, v3_hpf, 0);
AudioConnection        v3c2(v3_hpf,   2, v3_env, 0);

AudioSynthNoiseWhite   v4_noise;
AudioFilterStateVariable v4_bpf;
AudioEffectEnvelope    v4_env;
AudioConnection        v4c1(v4_noise, 0, v4_bpf, 0);
AudioConnection        v4c2(v4_bpf,   1, v4_env, 0);

AudioSynthWaveform     v5_osc;
AudioFilterStateVariable v5_lpf;
AudioEffectEnvelope    v5_env;
AudioConnection        v5c1(v5_osc, 0, v5_lpf, 0);
AudioConnection        v5c2(v5_lpf, 0, v5_env, 0);

AudioSynthWaveform     v6_osc;
AudioFilterStateVariable v6_lpf;
AudioEffectEnvelope    v6_env;
AudioConnection        v6c1(v6_osc, 0, v6_lpf, 0);
AudioConnection        v6c2(v6_lpf, 0, v6_env, 0);

AudioSynthWaveform     v7_osc;
AudioEffectEnvelope    v7_env;
AudioConnection        v7c1(v7_osc, 0, v7_env, 0);

// --- Sample players (variable-rate) + submixers for all 8 tracks ---
AudioPlaySdResmp       sdPlayer[8];
AudioMixer4            drumMix[8];

// Synth voice -> drumMix input 0
AudioConnection        dm0s(v0_ampEnv, 0, drumMix[0], 0);
AudioConnection        dm1s(v1_env,    0, drumMix[1], 0);
AudioConnection        dm2s(v2_env,    0, drumMix[2], 0);
AudioConnection        dm3s(v3_env,    0, drumMix[3], 0);
AudioConnection        dm4s(v4_env,    0, drumMix[4], 0);
AudioConnection        dm5s(v5_env,    0, drumMix[5], 0);
AudioConnection        dm6s(v6_env,    0, drumMix[6], 0);
AudioConnection        dm7s(v7_env,    0, drumMix[7], 0);

// SD WAV player -> drumMix input 1
AudioConnection        dm0w(sdPlayer[0], 0, drumMix[0], 1);
AudioConnection        dm1w(sdPlayer[1], 0, drumMix[1], 1);
AudioConnection        dm2w(sdPlayer[2], 0, drumMix[2], 1);
AudioConnection        dm3w(sdPlayer[3], 0, drumMix[3], 1);
AudioConnection        dm4w(sdPlayer[4], 0, drumMix[4], 1);
AudioConnection        dm5w(sdPlayer[5], 0, drumMix[5], 1);
AudioConnection        dm6w(sdPlayer[6], 0, drumMix[6], 1);
AudioConnection        dm7w(sdPlayer[7], 0, drumMix[7], 1);

// --- MultiEngine synthesizers: 4-voice polyphony per track (all 8 tracks) ---
#include "MultiEngine.h"
MultiEngine             multiEngine[32]; // 8 tracks x 4 voices each
AudioMixer4             polyMix[8];      // one mixer per track

// Track 0: voices 0-3 -> polyMix[0]
AudioConnection        me0(multiEngine[0],  0, polyMix[0], 0);
AudioConnection        me1(multiEngine[1],  0, polyMix[0], 1);
AudioConnection        me2(multiEngine[2],  0, polyMix[0], 2);
AudioConnection        me3(multiEngine[3],  0, polyMix[0], 3);
// Track 1: voices 4-7 -> polyMix[1]
AudioConnection        me4(multiEngine[4],  0, polyMix[1], 0);
AudioConnection        me5(multiEngine[5],  0, polyMix[1], 1);
AudioConnection        me6(multiEngine[6],  0, polyMix[1], 2);
AudioConnection        me7(multiEngine[7],  0, polyMix[1], 3);
// Track 2: voices 8-11 -> polyMix[2]
AudioConnection        me8(multiEngine[8],  0, polyMix[2], 0);
AudioConnection        me9(multiEngine[9],  0, polyMix[2], 1);
AudioConnection        me10(multiEngine[10], 0, polyMix[2], 2);
AudioConnection        me11(multiEngine[11], 0, polyMix[2], 3);
// Track 3: voices 12-15 -> polyMix[3]
AudioConnection        me12(multiEngine[12], 0, polyMix[3], 0);
AudioConnection        me13(multiEngine[13], 0, polyMix[3], 1);
AudioConnection        me14(multiEngine[14], 0, polyMix[3], 2);
AudioConnection        me15(multiEngine[15], 0, polyMix[3], 3);
// Track 4: voices 16-19 -> polyMix[4]
AudioConnection        me16(multiEngine[16], 0, polyMix[4], 0);
AudioConnection        me17(multiEngine[17], 0, polyMix[4], 1);
AudioConnection        me18(multiEngine[18], 0, polyMix[4], 2);
AudioConnection        me19(multiEngine[19], 0, polyMix[4], 3);
// Track 5: voices 20-23 -> polyMix[5]
AudioConnection        me20(multiEngine[20], 0, polyMix[5], 0);
AudioConnection        me21(multiEngine[21], 0, polyMix[5], 1);
AudioConnection        me22(multiEngine[22], 0, polyMix[5], 2);
AudioConnection        me23(multiEngine[23], 0, polyMix[5], 3);
// Track 6: voices 24-27 -> polyMix[6]
AudioConnection        me24(multiEngine[24], 0, polyMix[6], 0);
AudioConnection        me25(multiEngine[25], 0, polyMix[6], 1);
AudioConnection        me26(multiEngine[26], 0, polyMix[6], 2);
AudioConnection        me27(multiEngine[27], 0, polyMix[6], 3);
// Track 7: voices 28-31 -> polyMix[7]
AudioConnection        me28(multiEngine[28], 0, polyMix[7], 0);
AudioConnection        me29(multiEngine[29], 0, polyMix[7], 1);
AudioConnection        me30(multiEngine[30], 0, polyMix[7], 2);
AudioConnection        me31(multiEngine[31], 0, polyMix[7], 3);

// Route poly mixers to drumMix input 2 for all 8 tracks
AudioConnection        meConn0(polyMix[0], 0, drumMix[0], 2);
AudioConnection        meConn1(polyMix[1], 0, drumMix[1], 2);
AudioConnection        meConn2(polyMix[2], 0, drumMix[2], 2);
AudioConnection        meConn3(polyMix[3], 0, drumMix[3], 2);
AudioConnection        meConn4(polyMix[4], 0, drumMix[4], 2);
AudioConnection        meConn5(polyMix[5], 0, drumMix[5], 2);
AudioConnection        meConn6(polyMix[6], 0, drumMix[6], 2);
AudioConnection        meConn7(polyMix[7], 0, drumMix[7], 2);

// --- Granular synthesizers (for all 8 tracks, input 3 on drumMix) ---
#include "GranularPlayer.h"
// 2 shared grain players to conserve RAM (~8KB each with 4096-sample buffer)
#define NUM_GRAIN_PLAYERS 2
GranularPlayer          grainPlayer[NUM_GRAIN_PLAYERS];
AudioConnection        gp0(grainPlayer[0], 0, drumMix[0], 3);
AudioConnection        gp1(grainPlayer[1], 0, drumMix[4], 3);

// --- Per-track peak meters (all from drumMix outputs) ---
AudioAnalyzePeak       peak[8];
AudioConnection        pk0(drumMix[0], 0, peak[0], 0);
AudioConnection        pk1(drumMix[1], 0, peak[1], 0);
AudioConnection        pk2(drumMix[2], 0, peak[2], 0);
AudioConnection        pk3(drumMix[3], 0, peak[3], 0);
AudioConnection        pk4(drumMix[4], 0, peak[4], 0);
AudioConnection        pk5(drumMix[5], 0, peak[5], 0);
AudioConnection        pk6(drumMix[6], 0, peak[6], 0);
AudioConnection        pk7(drumMix[7], 0, peak[7], 0);

// --- Stereo mix (L/R for pan, volume at oscillator level) ---
// All 8 tracks route through drumMix submixers
AudioMixer4            mixL_A, mixL_B, mixR_A, mixR_B;
AudioMixer4            mixMasterL, mixMasterR;

AudioConnection        mcL0(drumMix[0], 0, mixL_A, 0);
AudioConnection        mcL1(drumMix[1], 0, mixL_A, 1);
AudioConnection        mcL2(drumMix[2], 0, mixL_A, 2);
AudioConnection        mcL3(drumMix[3], 0, mixL_A, 3);
AudioConnection        mcL4(drumMix[4], 0, mixL_B, 0);
AudioConnection        mcL5(drumMix[5], 0, mixL_B, 1);
AudioConnection        mcL6(drumMix[6], 0, mixL_B, 2);
AudioConnection        mcL7(drumMix[7], 0, mixL_B, 3);
AudioConnection        mcR0(drumMix[0], 0, mixR_A, 0);
AudioConnection        mcR1(drumMix[1], 0, mixR_A, 1);
AudioConnection        mcR2(drumMix[2], 0, mixR_A, 2);
AudioConnection        mcR3(drumMix[3], 0, mixR_A, 3);
AudioConnection        mcR4(drumMix[4], 0, mixR_B, 0);
AudioConnection        mcR5(drumMix[5], 0, mixR_B, 1);
AudioConnection        mcR6(drumMix[6], 0, mixR_B, 2);
AudioConnection        mcR7(drumMix[7], 0, mixR_B, 3);
AudioConnection        mmL0(mixL_A, 0, mixMasterL, 0);
AudioConnection        mmL1(mixL_B, 0, mixMasterL, 1);
AudioConnection        mmR0(mixR_A, 0, mixMasterR, 0);
AudioConnection        mmR1(mixR_B, 0, mixMasterR, 1);

// --- Preview player (for auditioning samples from file browser) ---
AudioPlaySdResmp       previewPlayer;
AudioConnection        prevL(previewPlayer, 0, mixMasterL, 2);
AudioConnection        prevR(previewPlayer, 1, mixMasterR, 2);
static bool            previewLooping = false;
static char            previewPath[64] = "";

AudioOutputUSB         usbAudioOut;
AudioConnection        usbL(mixMasterL, 0, usbAudioOut, 0);
AudioConnection        usbR(mixMasterR, 0, usbAudioOut, 1);

#ifdef HAS_AUDIO_SHIELD
AudioOutputI2S         i2sOut;
AudioControlSGTL5000   codec;
AudioConnection        i2sL(mixMasterL, 0, i2sOut, 0);
AudioConnection        i2sR(mixMasterR, 0, i2sOut, 1);
#endif

// --- Sequencer ---
Sequencer seq;
IntervalTimer stepTimer;

// =============================================================
// Non-blocking TX ring buffer — all serial output goes through here
// =============================================================
static char txBuf[512];
static volatile uint16_t txHead = 0, txTail = 0;

static void txEnqueue(const char* msg, int len) {
    for (int i = 0; i < len; i++) {
        uint16_t next = (txHead + 1) % sizeof(txBuf);
        if (next == txTail) return;  // full — drop silently
        txBuf[txHead] = msg[i];
        txHead = next;
    }
}

static void txPrint(const char* msg) {
    txEnqueue(msg, strlen(msg));
}

// Drain up to 64 bytes per loop() call — never blocks
static void drainSerialTx() {
    int written = 0;
    while (txHead != txTail && written < 64 && Serial.availableForWrite() > 0) {
        Serial.write(txBuf[txTail]);
        txTail = (txTail + 1) % sizeof(txBuf);
        written++;
    }
}

// =============================================================
// Mixer state — volatile for ISR safety
// =============================================================
static volatile float trackVolume[8]  = { 0.8f, 0.8f, 0.8f, 0.8f, 0.8f, 0.8f, 0.8f, 0.8f };
static volatile float trackPan[8]     = { 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f };
static volatile bool  trackMute[8]    = { false };
static volatile bool  trackSolo[8]    = { false };
static volatile bool  anySolo          = false;
static float trackPeakLevel[8]        = { 0 };
static bool  mixerDirty                = false;

static const float baseGain[8] = {
    0.8f, 0.6f, 0.5f, 0.4f,
    0.5f, 0.7f, 0.5f, 0.5f
};

// Pan-only mixer gains (no volume — that's at the oscillator)
static void applyPanGains() {
    for (int i = 0; i < 8; i++) {
        float panNorm = (trackPan[i] + 1.0f) * 0.5f;
        float gainL = baseGain[i] * cosf(panNorm * (float)M_PI_2);
        float gainR = baseGain[i] * sinf(panNorm * (float)M_PI_2);
        if (i < 4) { mixL_A.gain(i, gainL); mixR_A.gain(i, gainR); }
        else       { mixL_B.gain(i-4, gainL); mixR_B.gain(i-4, gainR); }
    }
}

// Update oscillator amplitudes for volume/mute/solo
static void updateAllVoiceAmplitudes() {
    anySolo = false;
    for (int i = 0; i < 8; i++) {
        if (trackSolo[i]) { anySolo = true; break; }
    }
    for (int i = 0; i < 8; i++) {
        float vol = trackVolume[i];
        if (trackMute[i]) vol = 0.0f;
        if (anySolo && !trackSolo[i]) vol = 0.0f;
        voiceSetAmplitude(i, vol);
    }
}

// Apply all deferred mixer changes (called once per loop, not per command)
static void applyMixerIfDirty() {
    if (!mixerDirty) return;
    mixerDirty = false;
    updateAllVoiceAmplitudes();
    applyPanGains();
}

// =============================================================
// Sequencer callbacks — called from ISR, must be ISR-safe
// =============================================================
void onSeqNoteOn(uint8_t track, uint8_t note, uint8_t velocity, uint8_t padIndex) {
    if (trackMute[track]) return;
    if (anySolo && !trackSolo[track]) return;
    float vol = trackVolume[track];
    uint8_t scaledVel = (uint8_t)(velocity * vol);
    if (scaledVel == 0) return;
    // MultiEngine handles any track when enabled (polyphonic voice allocation)
    if (trackUseMultiEngine[track]) {
        synthNoteOn(track, note, scaledVel / 127.0f);
        return;
    }
    if (trackIsDrumMachine[track]) {
        voiceTriggerDrumPad(track, padIndex, scaledVel);
    } else if (trackUseSample[track]) {
        // Sampler mode — defer to loop() via pending flag (ISR-safe)
        samplePendingNote[track] = note;
        samplePendingVel[track] = scaledVel;
        samplePending[track] = true;
    } else {
        // Basic synth voice (legacy, only used if no other mode is active)
        voiceTrigger(track, note, scaledVel);
    }
}

void onSeqNoteOff(uint8_t track, uint8_t note, uint8_t padIndex) {
    if (trackUseMultiEngine[track]) {
        synthNoteOff(track, note);
        return;
    }
    voiceRelease(track);
}

// ISR — calls sequencer directly for hardware-precise timing
void stepTimerISR() {
    seq.tickISR();
}

// =============================================================
// USB MIDI handlers — external controller routes to focused track
// =============================================================
static uint8_t focusedTrack = 0;  // which track receives external MIDI (set via FOCUS:track)

void handleMidiNoteOn(uint8_t channel, uint8_t note, uint8_t velocity) {
    if (channel == GRID_MIDI_CH) {
        uint8_t lpRow = note / 10;
        uint8_t lpCol = (note % 10) - 1;
        if (lpRow >= 1 && lpRow <= 8 && lpCol < 8) {
            uint8_t track = SEQ_MAX_TRACKS - lpRow;
            uint8_t step = seq.getPageOffset() + lpCol;
            seq.toggleStep(track, step);
        }
        return;
    }

    // Route to focused track's sub-engine
    uint8_t t = focusedTrack;
    if (trackUseMultiEngine[t]) {
        // Synth: polyphonic note on
        synthNoteOn(t, note, velocity / 127.0f);
    } else if (trackIsDrumMachine[t]) {
        // Drum machine: map note to pad index (note - 36 = pad 0-7)
        uint8_t pad = (note >= 36) ? (note - 36) : 0;
        if (pad < 8) voiceTriggerDrumPad(t, pad, velocity);
    } else if (trackUseSample[t]) {
        // Sampler: trigger with MIDI note for pitch
        samplePendingNote[t] = note;
        samplePendingVel[t] = velocity;
        samplePending[t] = true;
    } else {
        // Basic synth voice
        voiceTrigger(t, note, velocity);
    }
}

void handleMidiNoteOff(uint8_t channel, uint8_t note, uint8_t velocity) {
    if (channel == GRID_MIDI_CH) return;

    uint8_t t = focusedTrack;
    if (trackUseMultiEngine[t]) {
        synthNoteOff(t, note);
    } else {
        voiceRelease(t);
    }
}

void handleMidiCC(uint8_t channel, uint8_t cc, uint8_t value) {
    if (channel == GRID_MIDI_CH) {
        if (cc == 91 && value > 0) {
            if (seq.isPlaying()) { stepTimer.end(); seq.stop(); }
            else { seq.start(); stepTimer.begin(stepTimerISR, seq.getStepIntervalUs()); }
        }
        else if (cc == 93 && value > 0) { seq.clearAll(); }
        else if (cc == 94 && value > 0) {
            seq.setBPM(seq.getBPM() - 5.0f);
            if (seq.isPlaying()) stepTimer.update(seq.getStepIntervalUs());
        }
        else if (cc == 95 && value > 0) {
            seq.setBPM(seq.getBPM() + 5.0f);
            if (seq.isPlaying()) stepTimer.update(seq.getStepIntervalUs());
        }
        return;
    }
    if (cc == 7) {
        float v = value / 127.0f;
        mixMasterL.gain(0, v); mixMasterL.gain(1, v);
        mixMasterR.gain(0, v); mixMasterR.gain(1, v);
    }
}

// =============================================================
// Serial I/O — zero-allocation, byte-budgeted, non-blocking
// =============================================================
static char serialBuf[130];
static uint8_t serialBufLen = 0;

// Fast command parser — no String, no heap allocation
static void processCommand(const char* cmd, uint8_t len) {
    const char* colon = (const char*)memchr(cmd, ':', len);
    int cmdLen = colon ? (int)(colon - cmd) : len;
    const char* params = colon ? (colon + 1) : nullptr;

    if (cmdLen == 4 && memcmp(cmd, "PING", 4) == 0) {
        txPrint("PONG:SAMPLER_CROW:1.1\n");
    }
    else if (cmdLen == 4 && memcmp(cmd, "PLAY", 4) == 0) {
        seq.start();
        stepTimer.begin(stepTimerISR, seq.getStepIntervalUs());
    }
    else if (cmdLen == 4 && memcmp(cmd, "STOP", 4) == 0) {
        stepTimer.end();
        seq.stop();
    }
    else if (cmdLen == 5 && memcmp(cmd, "CLEAR", 5) == 0) {
        seq.clearAll();
    }
    else if (cmdLen == 4 && memcmp(cmd, "GRID", 4) == 0) {
        seq.markGridDirty();
    }
    else if (cmdLen == 3 && memcmp(cmd, "BPM", 3) == 0 && params) {
        seq.setBPM(atof(params));
        if (seq.isPlaying()) stepTimer.update(seq.getStepIntervalUs());
        char buf[16]; int n = snprintf(buf, sizeof(buf), "BPM:%.0f\n", seq.getBPM());
        txEnqueue(buf, n);
    }
    else if (cmdLen == 6 && memcmp(cmd, "TOGGLE", 6) == 0 && params) {
        const char* sep = strchr(params, ':');
        if (sep) {
            seq.toggleStep(atoi(params), atoi(sep + 1));
        }
    }
    else if (cmdLen == 3 && memcmp(cmd, "VOL", 3) == 0 && params) {
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            int val = atoi(sep + 1);
            if (track < 8) {
                trackVolume[track] = constrain(val, 0, 100) / 100.0f;
                mixerDirty = true;
            }
        }
    }
    else if (cmdLen == 4 && memcmp(cmd, "MUTE", 4) == 0 && params) {
        uint8_t track = atoi(params);
        if (track < 8) {
            trackMute[track] = !trackMute[track];
            mixerDirty = true;
            if (trackMute[track]) voiceRelease(track);
            char buf[20]; int n = snprintf(buf, sizeof(buf), "ACK:MUTE:%d:%d\n", track, trackMute[track]?1:0);
            txEnqueue(buf, n);
        }
    }
    else if (cmdLen == 4 && memcmp(cmd, "SOLO", 4) == 0 && params) {
        uint8_t track = atoi(params);
        if (track < 8) {
            trackSolo[track] = !trackSolo[track];
            mixerDirty = true;
            char buf[20]; int n = snprintf(buf, sizeof(buf), "ACK:SOLO:%d:%d\n", track, trackSolo[track]?1:0);
            txEnqueue(buf, n);
        }
    }
    else if (cmdLen == 3 && memcmp(cmd, "PAN", 3) == 0 && params) {
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            int val = atoi(sep + 1);
            if (track < 8) {
                trackPan[track] = constrain(val, -100, 100) / 100.0f;
                mixerDirty = true;
            }
        }
    }
    else if (cmdLen == 7 && memcmp(cmd, "NOTE_ON", 7) == 0 && params) {
        const char* sep = strchr(params, ':');
        if (sep) voiceTrigger(6, atoi(params), atoi(sep + 1));
    }
    else if (cmdLen == 8 && memcmp(cmd, "NOTE_OFF", 8) == 0) {
        voiceRelease(6);
    }
    else if (cmdLen == 4 && memcmp(cmd, "TRIG", 4) == 0 && params) {
        const char* s1 = strchr(params, ':');
        if (s1) {
            const char* s2 = strchr(s1 + 1, ':');
            if (s2) voiceTrigger(atoi(params), atoi(s1+1), atoi(s2+1));
        }
    }
    else if (cmdLen == 6 && memcmp(cmd, "STATUS", 6) == 0) {
        char buf[80];
        int n = snprintf(buf, sizeof(buf), "STATUS:cpu=%.1f:mem=%d:bpm=%.0f:playing=%d:step=%d\n",
            AudioProcessorUsage(), AudioMemoryUsage(),
            seq.getBPM(), seq.isPlaying() ? 1 : 0, seq.getCurrentStep());
        txEnqueue(buf, n);
    }
    else if (cmdLen == 5 && memcmp(cmd, "MIXER", 5) == 0) {
        // Single snprintf, single write — no chained Serial.print()
        char buf[200];
        int pos = 0;
        pos += snprintf(buf+pos, sizeof(buf)-pos, "MIX:");
        for (int i = 0; i < 8; i++) pos += snprintf(buf+pos, sizeof(buf)-pos, "%s%d", i?",":"", (int)(trackVolume[i]*100));
        pos += snprintf(buf+pos, sizeof(buf)-pos, "|");
        for (int i = 0; i < 8; i++) pos += snprintf(buf+pos, sizeof(buf)-pos, "%s%d", i?",":"", trackMute[i]?1:0);
        pos += snprintf(buf+pos, sizeof(buf)-pos, "|");
        for (int i = 0; i < 8; i++) pos += snprintf(buf+pos, sizeof(buf)-pos, "%s%d", i?",":"", trackSolo[i]?1:0);
        pos += snprintf(buf+pos, sizeof(buf)-pos, "|");
        for (int i = 0; i < 8; i++) pos += snprintf(buf+pos, sizeof(buf)-pos, "%s%d", i?",":"", (int)(trackPan[i]*100));
        buf[pos++] = '\n';
        txEnqueue(buf, pos);
    }
    else if (cmdLen == 3 && memcmp(cmd, "LVL", 3) == 0) {
        // Polling model: app requests levels, firmware responds once
        for (int i = 0; i < 8; i++) {
            if (peak[i].available()) {
                float raw = peak[i].read();
                float vol = trackVolume[i];
                if (trackMute[i]) vol = 0.0f;
                if (anySolo && !trackSolo[i]) vol = 0.0f;
                trackPeakLevel[i] = raw * vol;
            }
        }
        char buf[60];
        int n = snprintf(buf, sizeof(buf), "LVL:%d,%d,%d,%d,%d,%d,%d,%d\n",
            (int)(trackPeakLevel[0]*100), (int)(trackPeakLevel[1]*100),
            (int)(trackPeakLevel[2]*100), (int)(trackPeakLevel[3]*100),
            (int)(trackPeakLevel[4]*100), (int)(trackPeakLevel[5]*100),
            (int)(trackPeakLevel[6]*100), (int)(trackPeakLevel[7]*100));
        txEnqueue(buf, n);
    }
    else if (cmdLen == 6 && memcmp(cmd, "RENAME", 6) == 0 && params) {
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            if (track < 8) {
                // Just ACK — names stored on app side
                char buf[30];
                int n = snprintf(buf, sizeof(buf), "ACK:RENAME:%d\n", track);
                txEnqueue(buf, n);
            }
        }
    }
    else if (cmdLen == 10 && memcmp(cmd, "LOADSAMPLE", 10) == 0 && params) {
        // LOADSAMPLE:track:filename
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            const char* filename = sep + 1;
            if (track < MAX_SAMPLE_TRACKS && strlen(filename) > 0) {
                voiceLoadSample(track, filename);
                char buf[80]; int n = snprintf(buf, sizeof(buf), "ACK:LOADSAMPLE:%d:%s\n", track, filename);
                txEnqueue(buf, n);
            } else {
                txPrint("ERR:LOADSAMPLE:PARAM\n");
            }
        }
    }
    else if (cmdLen == 11 && memcmp(cmd, "CLEARSAMPLE", 11) == 0 && params) {
        // CLEARSAMPLE:track
        uint8_t track = atoi(params);
        if (track < MAX_SAMPLE_TRACKS) {
            voiceClearSample(track);
            char buf[30]; int n = snprintf(buf, sizeof(buf), "ACK:CLEARSAMPLE:%d\n", track);
            txEnqueue(buf, n);
        }
    }
    else if (cmdLen == 10 && memcmp(cmd, "SAMPLELIST", 10) == 0) {
        // List .WAV files on SD card root
        char buf[300];
        int pos = snprintf(buf, sizeof(buf), "SAMPLES:");
        File root = SD.open("/");
        bool first = true;
        if (root) {
            while (File entry = root.openNextFile()) {
                const char* name = entry.name();
                size_t nlen = strlen(name);
                // Check for .wav or .WAV extension
                if (nlen > 4 &&
                    (name[nlen-4] == '.') &&
                    ((name[nlen-3] == 'w' || name[nlen-3] == 'W') &&
                     (name[nlen-2] == 'a' || name[nlen-2] == 'A') &&
                     (name[nlen-1] == 'v' || name[nlen-1] == 'V'))) {
                    if (!first && pos < (int)sizeof(buf) - 2) buf[pos++] = ',';
                    first = false;
                    int remain = sizeof(buf) - pos - 2;
                    if ((int)nlen < remain) {
                        memcpy(buf + pos, name, nlen);
                        pos += nlen;
                    }
                }
                entry.close();
            }
            root.close();
        }
        buf[pos++] = '\n';
        txEnqueue(buf, pos);
    }
    else if (cmdLen == 10 && memcmp(cmd, "SAMPLEINFO", 10) == 0) {
        // Show which tracks have samples loaded
        char buf[200];
        int pos = snprintf(buf, sizeof(buf), "SINFO:");
        for (int i = 0; i < MAX_SAMPLE_TRACKS; i++) {
            if (i > 0) buf[pos++] = ',';
            if (trackUseSample[i]) {
                pos += snprintf(buf + pos, sizeof(buf) - pos, "%d:%s", i, trackSamplePath[i]);
            } else {
                pos += snprintf(buf + pos, sizeof(buf) - pos, "%d:", i);
            }
        }
        buf[pos++] = '\n';
        txEnqueue(buf, pos);
    }
    else if (cmdLen == 7 && memcmp(cmd, "PREVIEW", 7) == 0 && params) {
        // PREVIEW:filepath — play sample once for auditioning
        previewPlayer.stop();
        strncpy(previewPath, params, sizeof(previewPath) - 1);
        previewPath[sizeof(previewPath) - 1] = '\0';
        previewLooping = false;
        previewPlayer.playWav(previewPath);
        txPrint("ACK:PREVIEW\n");
    }
    else if (cmdLen == 11 && memcmp(cmd, "PREVIEWLOOP", 11) == 0 && params) {
        // PREVIEWLOOP:filepath — play sample in loop for auditioning
        previewPlayer.stop();
        strncpy(previewPath, params, sizeof(previewPath) - 1);
        previewPath[sizeof(previewPath) - 1] = '\0';
        previewLooping = true;
        previewPlayer.playWav(previewPath);
        txPrint("ACK:PREVIEWLOOP\n");
    }
    else if (cmdLen == 11 && memcmp(cmd, "PREVIEWSTOP", 11) == 0) {
        previewPlayer.stop();
        previewLooping = false;
        previewPath[0] = '\0';
        txPrint("ACK:PREVIEWSTOP\n");
    }
    else if (cmdLen == 4 && memcmp(cmd, "SAVE", 4) == 0 && params) {
        uint8_t slot = atoi(params);
        if (slot > 7) {
            txPrint("ERR:SAVE:SLOT\n");
        } else if (seq.saveToSD(slot)) {
            char buf[20]; int n = snprintf(buf, sizeof(buf), "ACK:SAVE:%d\n", slot);
            txEnqueue(buf, n);
        } else {
            txPrint("ERR:SAVE:SD\n");
        }
    }
    else if (cmdLen == 4 && memcmp(cmd, "LOAD", 4) == 0 && params) {
        uint8_t slot = atoi(params);
        if (slot > 7) {
            txPrint("ERR:LOAD:SLOT\n");
        } else {
            // Stop sequencer if playing
            if (seq.isPlaying()) {
                stepTimer.end();
                seq.stop();
            }
            if (seq.loadFromSD(slot)) {
                char buf[20]; int n = snprintf(buf, sizeof(buf), "ACK:LOAD:%d\n", slot);
                txEnqueue(buf, n);
            } else {
                txPrint("ERR:LOAD:NOFILE\n");
            }
        }
    }
    else if (cmdLen == 8 && memcmp(cmd, "PATTERNS", 8) == 0) {
        char buf[24];
        int pos = snprintf(buf, sizeof(buf), "PATS:");
        for (uint8_t i = 0; i < 8; i++) {
            char path[20];
            snprintf(path, sizeof(path), "/patterns/P%d.bin", i);
            if (i > 0) buf[pos++] = ',';
            buf[pos++] = SD.exists(path) ? '1' : '0';
        }
        buf[pos++] = '\n';
        txEnqueue(buf, pos);
    }
    else if (cmdLen == 6 && memcmp(cmd, "SETVEL", 6) == 0 && params) {
        // SETVEL:track:step:velocity
        const char* s1 = strchr(params, ':');
        if (s1) {
            const char* s2 = strchr(s1 + 1, ':');
            if (s2) {
                uint8_t track = atoi(params);
                uint8_t step = atoi(s1 + 1);
                uint8_t vel = atoi(s2 + 1);
                if (track < SEQ_MAX_TRACKS && step < SEQ_MAX_STEPS && vel <= 127) {
                    seq.setStepVelocity(track, step, vel);
                }
            }
        }
    }
    else if (cmdLen == 7 && memcmp(cmd, "SETNOTE", 7) == 0 && params) {
        // SETNOTE:track:step:note:velocity (velocity optional, defaults to 100)
        const char* s1 = strchr(params, ':');
        if (s1) {
            const char* s2 = strchr(s1 + 1, ':');
            if (s2) {
                uint8_t track = atoi(params);
                uint8_t step = atoi(s1 + 1);
                uint8_t note = atoi(s2 + 1);
                uint8_t vel = 100;  // default
                const char* s3 = strchr(s2 + 1, ':');
                if (s3) vel = atoi(s3 + 1);
                if (track < SEQ_MAX_TRACKS && step < SEQ_MAX_STEPS && note <= 127) {
                    seq.setStep(track, step, note, vel);
                }
            }
        }
    }
    else if (cmdLen == 10 && memcmp(cmd, "TRACKCLEAR", 10) == 0 && params) {
        uint8_t track = atoi(params);
        if (track < SEQ_MAX_TRACKS) {
            seq.clearTrack(track);
            txPrint("ACK:TRACKCLEAR\n");
        }
    }
    else if (cmdLen == 11 && memcmp(cmd, "ENABLESYNTH", 11) == 0 && params) {
        // ENABLESYNTH:track:0/1 — enable/disable MultiEngine for a track
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            uint8_t enable = atoi(sep + 1);
            if (track < 8) {
                trackUseMultiEngine[track] = (enable > 0);
                if (enable) {
                    // Switch drumMix routing to MultiEngine (input 2)
                    drumMix[track].gain(0, 0.0f);  // mute synth
                    drumMix[track].gain(1, 0.0f);  // mute sample
                    drumMix[track].gain(2, 1.0f);  // enable MultiEngine
                    drumMix[track].gain(3, 0.0f);  // mute grain
                } else {
                    // Disable MultiEngine — mute all, let caller enable the right mode
                    drumMix[track].gain(0, 0.0f);
                    drumMix[track].gain(1, 0.0f);
                    drumMix[track].gain(2, 0.0f);
                    drumMix[track].gain(3, 0.0f);
                }
                char buf[25]; int n = snprintf(buf, sizeof(buf), "ACK:ENABLESYNTH:%d:%d\n", track, enable);
                txEnqueue(buf, n);
            }
        }
    }
    else if (cmdLen == 10 && memcmp(cmd, "BATCHNOTES", 10) == 0 && params) {
        // BATCHNOTES:track:n,v;n,v;n,v;... (semicolon-separated step data for all steps)
        // First clear the track, then populate from the batch
        uint8_t track = atoi(params);
        if (track < SEQ_MAX_TRACKS) {
            const char* data = strchr(params, ':');
            if (data) {
                data++; // skip the colon after track number
                seq.clearTrack(track);
                int step = 0;
                const char* p = data;
                while (*p && step < SEQ_MAX_STEPS) {
                    int note = atoi(p);
                    const char* comma = strchr(p, ',');
                    int vel = 0;
                    if (comma) {
                        vel = atoi(comma + 1);
                        p = strchr(comma + 1, ';');
                        if (p) p++; else break;
                    } else {
                        break;
                    }
                    if (vel > 0 && note <= 127) {
                        seq.setStep(track, step, note, vel);
                    }
                    step++;
                }
                seq.markGridDirty();
                txPrint("ACK:BATCHNOTES\n");
            }
        }
    }
    else if (cmdLen == 7 && memcmp(cmd, "GETSTEP", 7) == 0 && params) {
        // GETSTEP:track:step -> STEPDATA:track:step:note:velocity:gate
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            uint8_t step = atoi(sep + 1);
            if (track < SEQ_MAX_TRACKS && step < SEQ_MAX_STEPS) {
                char buf[40];
                int n = snprintf(buf, sizeof(buf), "STEPDATA:%d:%d:%d:%d:%d\n",
                    track, step,
                    seq.getStepNote(track, step),
                    seq.getStepVelocity(track, step),
                    seq.getStepGate(track, step));
                txEnqueue(buf, n);
            }
        }
    }
    else if (cmdLen == 3 && memcmp(cmd, "DIR", 3) == 0) {
        // DIR or DIR:/path — list directory contents
        // Uses direct Serial.print (not txEnqueue) because directory listings
        // can exceed the 512-byte TX ring buffer. This is an interactive command
        // so brief blocking is acceptable. Sequencer is ISR-driven and unaffected.
        const char* dirPath = (params && strlen(params) > 0) ? params : "/";
        Serial.printf("DIRLIST:%s\n", dirPath);

        File dir = SD.open(dirPath);
        if (dir && dir.isDirectory()) {
            while (File entry = dir.openNextFile()) {
                // Wait for serial buffer space before each entry
                while (Serial.availableForWrite() < 80) { delayMicroseconds(100); }
                if (entry.isDirectory()) {
                    Serial.printf("D:%s\n", entry.name());
                } else {
                    Serial.printf("F:%s:%lu\n", entry.name(), (unsigned long)entry.size());
                }
                entry.close();
            }
            dir.close();
        }
        while (Serial.availableForWrite() < 20) { delayMicroseconds(100); }
        Serial.println("ENDDIR");
    }
    else if (cmdLen == 6 && memcmp(cmd, "UPLOAD", 6) == 0 && params) {
        // UPLOAD:filename:size — receive raw bytes over serial and write to SD
        const char* sep = strchr(params, ':');
        if (sep) {
            const char* filename = params;
            int fnLen = (int)(sep - params);
            uint32_t fileSize = strtoul(sep + 1, nullptr, 10);

            char path[72];
            snprintf(path, sizeof(path), "/%.*s", fnLen, filename);

            SD.remove(path);  // overwrite if exists
            File f = SD.open(path, FILE_WRITE);
            if (!f) {
                txPrint("ERR:UPLOAD:OPEN\n");
            } else {
                // Signal ready — app should send exactly fileSize raw bytes
                Serial.print("READY\n");
                Serial.flush();

                uint32_t received = 0;
                unsigned long timeout = millis() + 10000;  // 10s timeout
                while (received < fileSize && millis() < timeout) {
                    if (Serial.available()) {
                        uint8_t b = Serial.read();
                        f.write(b);
                        received++;
                        timeout = millis() + 5000;  // reset timeout on activity
                    }
                }
                f.close();

                if (received == fileSize) {
                    char buf[80];
                    int n = snprintf(buf, sizeof(buf), "ACK:UPLOAD:%.*s:%lu\n", fnLen, filename, (unsigned long)fileSize);
                    txEnqueue(buf, n);
                } else {
                    SD.remove(path);  // incomplete, delete
                    txPrint("ERR:UPLOAD:INCOMPLETE\n");
                }
            }
        }
    }
    else if (cmdLen == 11 && memcmp(cmd, "SAMPLEPARAM", 11) == 0 && params) {
        // SAMPLEPARAM:track:param:value
        const char* s1 = strchr(params, ':');
        if (s1) {
            uint8_t track = atoi(params);
            const char* s2 = strchr(s1 + 1, ':');
            if (s2 && track < MAX_SAMPLE_TRACKS) {
                int paramLen = (int)(s2 - s1 - 1);
                const char* paramName = s1 + 1;
                float val = atof(s2 + 1);
                SamplerParams& p = samplerParams[track];
                if (paramLen == 4 && memcmp(paramName, "gain", 4) == 0) p.gain = val / 100.0f;
                else if (paramLen == 5 && memcmp(paramName, "pitch", 5) == 0) p.pitchSemitones = (int8_t)val;
                else if (paramLen == 5 && memcmp(paramName, "cents", 5) == 0) p.pitchCents = (int8_t)val;
                else if (paramLen == 5 && memcmp(paramName, "start", 5) == 0) p.sampleStart = (uint32_t)val;
                else if (paramLen == 3 && memcmp(paramName, "end", 3) == 0) p.sampleEnd = (uint32_t)val;
                else if (paramLen == 4 && memcmp(paramName, "loop", 4) == 0) p.loopEnabled = (val > 0);
                else if (paramLen == 9 && memcmp(paramName, "loopstart", 9) == 0) p.loopStart = (uint32_t)val;
                else if (paramLen == 7 && memcmp(paramName, "loopend", 7) == 0) p.loopEnd = (uint32_t)val;
                else if (paramLen == 7 && memcmp(paramName, "oneshot", 7) == 0) p.oneShot = (val > 0);
                else if (paramLen == 4 && memcmp(paramName, "mode", 4) == 0) {
                    uint8_t oldMode = p.samplerMode;
                    p.samplerMode = (uint8_t)val;
                    if ((uint8_t)val == 1 && oldMode != 1) {
                        // Switching to Grain mode: load sample into grain buffer
                        GrainParams gp;
                        gp.windowPosition = p.grainPosition;
                        gp.windowSize = p.grainWindowSize;
                        gp.grainSizeMs = p.grainSizeMs;
                        gp.grainCount = p.grainCount;
                        gp.pitch = powf(2.0f, p.pitchSemitones / 12.0f);
                        gp.spread = p.grainSpread;
                        gp.envelopeShape = p.grainEnvShape;
                        gp.gain = p.gain;
                        grainPlayer[track].setParams(gp);
                        grainPlayer[track].loadFromFile(trackSamplePath[track], p.sampleStart, p.sampleEnd);
                        // Switch drumMix routing
                        drumMix[track].gain(1, 0.0f); // mute sdPlayer
                        drumMix[track].gain(3, 1.0f); // enable grainPlayer
                    } else if (oldMode == 1 && (uint8_t)val != 1) {
                        // Switching away from Grain mode
                        drumMix[track].gain(3, 0.0f); // mute grainPlayer
                        drumMix[track].gain(1, 1.0f); // re-enable sdPlayer
                    }
                }
                else if (paramLen == 8 && memcmp(paramName, "rootnote", 8) == 0) p.rootNote = (uint8_t)val;
                else if (paramLen == 6 && memcmp(paramName, "attack", 6) == 0) p.attackMs = (uint16_t)val;
                else if (paramLen == 5 && memcmp(paramName, "decay", 5) == 0) p.decayMs = (uint16_t)val;
                else if (paramLen == 7 && memcmp(paramName, "sustain", 7) == 0) p.sustainLevel = val / 100.0f;
                else if (paramLen == 7 && memcmp(paramName, "release", 7) == 0) p.releaseMs = (uint16_t)val;
                else if (paramLen == 8 && memcmp(paramName, "grainpos", 8) == 0) {
                    p.grainPosition = val / 100.0f;
                    if (p.samplerMode == 1) {
                        GrainParams gp;
                        gp.windowPosition = p.grainPosition; gp.windowSize = p.grainWindowSize;
                        gp.grainSizeMs = p.grainSizeMs; gp.grainCount = p.grainCount;
                        gp.pitch = powf(2.0f, p.pitchSemitones / 12.0f);
                        gp.spread = p.grainSpread; gp.envelopeShape = p.grainEnvShape; gp.gain = p.gain;
                        grainPlayer[track].setParams(gp);
                    }
                }
                else if (paramLen == 8 && memcmp(paramName, "grainwin", 8) == 0) {
                    p.grainWindowSize = val / 100.0f;
                    if (p.samplerMode == 1) {
                        GrainParams gp;
                        gp.windowPosition = p.grainPosition; gp.windowSize = p.grainWindowSize;
                        gp.grainSizeMs = p.grainSizeMs; gp.grainCount = p.grainCount;
                        gp.pitch = powf(2.0f, p.pitchSemitones / 12.0f);
                        gp.spread = p.grainSpread; gp.envelopeShape = p.grainEnvShape; gp.gain = p.gain;
                        grainPlayer[track].setParams(gp);
                    }
                }
                else if (paramLen == 9 && memcmp(paramName, "grainsize", 9) == 0) {
                    p.grainSizeMs = (uint16_t)val;
                    if (p.samplerMode == 1) {
                        GrainParams gp;
                        gp.windowPosition = p.grainPosition; gp.windowSize = p.grainWindowSize;
                        gp.grainSizeMs = p.grainSizeMs; gp.grainCount = p.grainCount;
                        gp.pitch = powf(2.0f, p.pitchSemitones / 12.0f);
                        gp.spread = p.grainSpread; gp.envelopeShape = p.grainEnvShape; gp.gain = p.gain;
                        grainPlayer[track].setParams(gp);
                    }
                }
                else if (paramLen == 10 && memcmp(paramName, "graincount", 10) == 0) {
                    p.grainCount = (uint8_t)val;
                    if (p.samplerMode == 1) {
                        GrainParams gp;
                        gp.windowPosition = p.grainPosition; gp.windowSize = p.grainWindowSize;
                        gp.grainSizeMs = p.grainSizeMs; gp.grainCount = p.grainCount;
                        gp.pitch = powf(2.0f, p.pitchSemitones / 12.0f);
                        gp.spread = p.grainSpread; gp.envelopeShape = p.grainEnvShape; gp.gain = p.gain;
                        grainPlayer[track].setParams(gp);
                    }
                }
                else if (paramLen == 10 && memcmp(paramName, "grainpitch", 10) == 0) {
                    // grainpitch sets pitch multiplier for grain engine (value in semitones)
                    if (p.samplerMode == 1) {
                        GrainParams gp;
                        gp.windowPosition = p.grainPosition; gp.windowSize = p.grainWindowSize;
                        gp.grainSizeMs = p.grainSizeMs; gp.grainCount = p.grainCount;
                        gp.pitch = powf(2.0f, val / 12.0f);
                        gp.spread = p.grainSpread; gp.envelopeShape = p.grainEnvShape; gp.gain = p.gain;
                        grainPlayer[track].setParams(gp);
                    }
                }
                else if (paramLen == 11 && memcmp(paramName, "grainspread", 11) == 0) {
                    p.grainSpread = val / 100.0f;
                    if (p.samplerMode == 1) {
                        GrainParams gp;
                        gp.windowPosition = p.grainPosition; gp.windowSize = p.grainWindowSize;
                        gp.grainSizeMs = p.grainSizeMs; gp.grainCount = p.grainCount;
                        gp.pitch = powf(2.0f, p.pitchSemitones / 12.0f);
                        gp.spread = p.grainSpread; gp.envelopeShape = p.grainEnvShape; gp.gain = p.gain;
                        grainPlayer[track].setParams(gp);
                    }
                }
                else if (paramLen == 8 && memcmp(paramName, "grainenv", 8) == 0) {
                    p.grainEnvShape = (uint8_t)val;
                    if (p.samplerMode == 1) {
                        GrainParams gp;
                        gp.windowPosition = p.grainPosition; gp.windowSize = p.grainWindowSize;
                        gp.grainSizeMs = p.grainSizeMs; gp.grainCount = p.grainCount;
                        gp.pitch = powf(2.0f, p.pitchSemitones / 12.0f);
                        gp.spread = p.grainSpread; gp.envelopeShape = p.grainEnvShape; gp.gain = p.gain;
                        grainPlayer[track].setParams(gp);
                    }
                }
                else if (paramLen == 8 && memcmp(paramName, "chopsens", 8) == 0) {
                    p.chopSensitivity = val / 100.0f;
                    computeSlices(track);
                }
                else if (paramLen == 8 && memcmp(paramName, "choptrig", 8) == 0) p.chopTriggerMode = (uint8_t)val;
            }
        }
    }
    else if (cmdLen == 12 && memcmp(cmd, "SAMPLEPARAMS", 12) == 0 && params) {
        uint8_t track = atoi(params);
        if (track < MAX_SAMPLE_TRACKS) {
            SamplerParams& p = samplerParams[track];
            char buf[250];
            int n = snprintf(buf, sizeof(buf),
                "SPARAMS:%d:%d:%d:%d:%lu:%lu:%d:%lu:%lu:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d\n",
                track, (int)(p.gain*100), p.pitchSemitones, p.pitchCents,
                (unsigned long)p.sampleStart, (unsigned long)p.sampleEnd,
                p.loopEnabled?1:0, (unsigned long)p.loopStart, (unsigned long)p.loopEnd,
                p.oneShot?1:0,
                p.samplerMode, p.rootNote, p.attackMs, p.decayMs,
                (int)(p.sustainLevel*100), p.releaseMs,
                (int)(p.grainPosition*100), (int)(p.grainWindowSize*100),
                p.grainSizeMs, p.grainCount, (int)(p.grainSpread*100), p.grainEnvShape,
                (int)(p.chopSensitivity*100), p.chopTriggerMode);
            txEnqueue(buf, n);
        }
    }
    else if (cmdLen == 8 && memcmp(cmd, "WAVEFORM", 8) == 0 && params) {
        uint8_t track = atoi(params);
        if (track < MAX_SAMPLE_TRACKS) {
            samplerComputeWaveform(track);
        }
    }
    else if (cmdLen == 11 && memcmp(cmd, "SETDRUMMODE", 11) == 0 && params) {
        // SETDRUMMODE:track:0/1
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            int val = atoi(sep + 1);
            if (track < MAX_SAMPLE_TRACKS) {
                trackIsDrumMachine[track] = (val > 0);
                // Mute all inputs, then enable the right one
                drumMix[track].gain(0, 0.0f);
                drumMix[track].gain(1, 0.0f);
                drumMix[track].gain(2, 0.0f);
                drumMix[track].gain(3, 0.0f);
                if (trackIsDrumMachine[track]) {
                    drumMix[track].gain(1, 1.0f);  // enable sample player for drum pads
                }
                char buf[30]; int n = snprintf(buf, sizeof(buf), "ACK:SETDRUMMODE:%d:%d\n", track, val?1:0);
                txEnqueue(buf, n);
            }
        }
    }
    else if (cmdLen == 7 && memcmp(cmd, "LOADPAD", 7) == 0 && params) {
        // LOADPAD:track:pad:filepath
        const char* s1 = strchr(params, ':');
        if (s1) {
            const char* s2 = strchr(s1 + 1, ':');
            if (s2) {
                uint8_t track = atoi(params);
                uint8_t pad = atoi(s1 + 1);
                const char* filepath = s2 + 1;
                if (track < MAX_SAMPLE_TRACKS && pad < 8 && strlen(filepath) > 0) {
                    voiceLoadDrumPad(track, pad, filepath);
                    char buf[80]; int n = snprintf(buf, sizeof(buf), "ACK:LOADPAD:%d:%d:%s\n", track, pad, filepath);
                    txEnqueue(buf, n);
                } else {
                    txPrint("ERR:LOADPAD:PARAM\n");
                }
            }
        }
    }
    else if (cmdLen == 8 && memcmp(cmd, "CLEARPAD", 8) == 0 && params) {
        // CLEARPAD:track:pad
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            uint8_t pad = atoi(sep + 1);
            if (track < MAX_SAMPLE_TRACKS && pad < 8) {
                voiceClearDrumPad(track, pad);
                char buf[30]; int n = snprintf(buf, sizeof(buf), "ACK:CLEARPAD:%d:%d\n", track, pad);
                txEnqueue(buf, n);
            }
        }
    }
    else if (cmdLen == 8 && memcmp(cmd, "PADPARAM", 8) == 0 && params) {
        // PADPARAM:track:pad:param:value
        const char* s1 = strchr(params, ':');
        if (s1) {
            const char* s2 = strchr(s1 + 1, ':');
            if (s2) {
                const char* s3 = strchr(s2 + 1, ':');
                if (s3) {
                    uint8_t track = atoi(params);
                    uint8_t pad = atoi(s1 + 1);
                    int paramLen = (int)(s3 - s2 - 1);
                    const char* paramName = s2 + 1;
                    float val = atof(s3 + 1);
                    if (track < MAX_SAMPLE_TRACKS && pad < 8) {
                        SamplerParams& p = drumPadParams[track][pad];
                        if (paramLen == 4 && memcmp(paramName, "gain", 4) == 0) p.gain = val / 100.0f;
                        else if (paramLen == 5 && memcmp(paramName, "pitch", 5) == 0) p.pitchSemitones = (int8_t)val;
                        else if (paramLen == 5 && memcmp(paramName, "cents", 5) == 0) p.pitchCents = (int8_t)val;
                        else if (paramLen == 5 && memcmp(paramName, "start", 5) == 0) p.sampleStart = (uint32_t)val;
                        else if (paramLen == 3 && memcmp(paramName, "end", 3) == 0) p.sampleEnd = (uint32_t)val;
                        else if (paramLen == 4 && memcmp(paramName, "loop", 4) == 0) p.loopEnabled = (val > 0);
                        else if (paramLen == 9 && memcmp(paramName, "loopstart", 9) == 0) p.loopStart = (uint32_t)val;
                        else if (paramLen == 7 && memcmp(paramName, "loopend", 7) == 0) p.loopEnd = (uint32_t)val;
                        else if (paramLen == 7 && memcmp(paramName, "oneshot", 7) == 0) p.oneShot = (val > 0);
                    }
                }
            }
        }
    }
    else if (cmdLen == 9 && memcmp(cmd, "PADPARAMS", 9) == 0 && params) {
        // PADPARAMS:track:pad
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            uint8_t pad = atoi(sep + 1);
            if (track < MAX_SAMPLE_TRACKS && pad < 8) {
                SamplerParams& p = drumPadParams[track][pad];
                char buf[120];
                int n = snprintf(buf, sizeof(buf), "PPARAMS:%d:%d:%d:%d:%d:%lu:%lu:%d:%lu:%lu:%d\n",
                    track, pad, (int)(p.gain*100), p.pitchSemitones, p.pitchCents,
                    (unsigned long)p.sampleStart, (unsigned long)p.sampleEnd,
                    p.loopEnabled?1:0, (unsigned long)p.loopStart, (unsigned long)p.loopEnd,
                    p.oneShot?1:0);
                txEnqueue(buf, n);
            }
        }
    }
    else if (cmdLen == 11 && memcmp(cmd, "PADWAVEFORM", 11) == 0 && params) {
        // PADWAVEFORM:track:pad
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            uint8_t pad = atoi(sep + 1);
            if (track < MAX_SAMPLE_TRACKS && pad < 8) {
                drumPadComputeWaveform(track, pad);
            }
        }
    }
    else if (cmdLen == 8 && memcmp(cmd, "SETSTEPS", 8) == 0 && params) {
        // SETSTEPS:track:N
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            int n = atoi(sep + 1);
            if (track < SEQ_MAX_TRACKS) {
                // Clamp to valid step counts
                if (n <= 8) n = 8;
                else if (n <= 16) n = 16;
                else if (n <= 32) n = 32;
                else n = 64;
                seq.getTrack(track).numSteps = n;
                seq.markGridDirty();
                char buf[30]; int nb = snprintf(buf, sizeof(buf), "ACK:SETSTEPS:%d:%d\n", track, n);
                txEnqueue(buf, nb);
            }
        }
    }
    else if (cmdLen == 9 && memcmp(cmd, "SETPADIDX", 9) == 0 && params) {
        // SETPADIDX:track:step:pad
        const char* s1 = strchr(params, ':');
        if (s1) {
            const char* s2 = strchr(s1 + 1, ':');
            if (s2) {
                uint8_t track = atoi(params);
                uint8_t step = atoi(s1 + 1);
                uint8_t pad = atoi(s2 + 1);
                if (track < SEQ_MAX_TRACKS && step < SEQ_MAX_STEPS && pad < 8) {
                    seq.setStepPadIndex(track, step, pad);
                }
            }
        }
    }
    else if (cmdLen == 8 && memcmp(cmd, "CLIPDATA", 8) == 0 && params) {
        // CLIPDATA:track
        uint8_t track = atoi(params);
        if (track < SEQ_MAX_TRACKS) {
            seq.sendClipData(track);
        }
    }
    else if (cmdLen == 6 && memcmp(cmd, "ENGINE", 6) == 0 && params) {
        // ENGINE:track:model — set MultiEngine model for any track
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            uint8_t model = atoi(sep + 1);
            if (track < 8 && model <= 23) {
                trackUseMultiEngine[track] = true;
                int base = track * VOICES_PER_SYNTH_TRACK;
                for (int v = 0; v < VOICES_PER_SYNTH_TRACK; v++) {
                    multiEngine[base + v].setEngine(model);
                }
                // Route drumMix: mute synth (0) and sample (1), enable MultiEngine (2)
                drumMix[track].gain(0, 0.0f);
                drumMix[track].gain(1, 0.0f);
                drumMix[track].gain(2, 1.0f);
                char buf[30]; int n = snprintf(buf, sizeof(buf), "ACK:ENGINE:%d:%d\n", track, model);
                txEnqueue(buf, n);
            }
        }
    }
    else if (cmdLen == 6 && memcmp(cmd, "TIMBRE", 6) == 0 && params) {
        // TIMBRE:track:value (0-1000)
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            int val = atoi(sep + 1);
            if (track < 8) {
                int base = track * VOICES_PER_SYNTH_TRACK;
                for (int v = 0; v < VOICES_PER_SYNTH_TRACK; v++) {
                    multiEngine[base + v].setTimbre(val / 1000.0f);
                }
            }
        }
    }
    else if (cmdLen == 9 && memcmp(cmd, "HARMONICS", 9) == 0 && params) {
        // HARMONICS:track:value (0-1000)
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            int val = atoi(sep + 1);
            if (track < 8) {
                int base = track * VOICES_PER_SYNTH_TRACK;
                for (int v = 0; v < VOICES_PER_SYNTH_TRACK; v++) {
                    multiEngine[base + v].setHarmonics(val / 1000.0f);
                }
            }
        }
    }
    else if (cmdLen == 5 && memcmp(cmd, "MORPH", 5) == 0 && params) {
        // MORPH:track:value (0-1000)
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            int val = atoi(sep + 1);
            if (track < 8) {
                int base = track * VOICES_PER_SYNTH_TRACK;
                for (int v = 0; v < VOICES_PER_SYNTH_TRACK; v++) {
                    multiEngine[base + v].setMorph(val / 1000.0f);
                }
            }
        }
    }
    else if (cmdLen == 12 && memcmp(cmd, "ENGINEPARAMS", 12) == 0 && params) {
        // ENGINEPARAMS:track — respond with engine/timbre/harmonics/morph
        uint8_t track = atoi(params);
        if (track < 8) {
            int base = track * VOICES_PER_SYNTH_TRACK;
            MultiEngine& me = multiEngine[base]; // voice 0 is representative
            char buf[80];
            int n = snprintf(buf, sizeof(buf), "EPARAMS:%d:%d:%d:%d:%d:%d:%d\n",
                track, me.getEngine(),
                (int)(me.getTimbre() * 1000), (int)(me.getHarmonics() * 1000),
                (int)(me.getMorph() * 1000), trackUseMultiEngine[track] ? 1 : 0,
                synthTrackState[track].voiceCount);
            txEnqueue(buf, n);
        }
    }
    else if (cmdLen == 7 && memcmp(cmd, "DX7LIST", 7) == 0) {
        // List .syx files on SD card root
        char buf[300];
        int pos = snprintf(buf, sizeof(buf), "DX7FILES:");
        File root = SD.open("/");
        bool first = true;
        if (root) {
            while (File entry = root.openNextFile()) {
                const char* name = entry.name();
                size_t nlen = strlen(name);
                if (nlen > 4 &&
                    (name[nlen-4] == '.') &&
                    ((name[nlen-3] == 's' || name[nlen-3] == 'S') &&
                     (name[nlen-2] == 'y' || name[nlen-2] == 'Y') &&
                     (name[nlen-1] == 'x' || name[nlen-1] == 'X'))) {
                    if (!first && pos < (int)sizeof(buf) - 2) buf[pos++] = ',';
                    first = false;
                    int remain = sizeof(buf) - pos - 2;
                    if ((int)nlen < remain) {
                        memcpy(buf + pos, name, nlen);
                        pos += nlen;
                    }
                }
                entry.close();
            }
            root.close();
        }
        buf[pos++] = '\n';
        txEnqueue(buf, pos);
    }
    else if (cmdLen == 10 && memcmp(cmd, "DX7PATCHES", 10) == 0 && params) {
        // DX7PATCHES:filename — list 32 patch names from a .syx file
        // Uses direct Serial.print because response can be large
        char path[72];
        snprintf(path, sizeof(path), "/%s", params);
        File f = SD.open(path);
        if (f && f.size() >= 4104) {
            uint8_t header[6];
            f.read(header, 6);
            Serial.print("DX7NAMES:");
            for (int p = 0; p < 32; p++) {
                // Seek to patch start + 117 (name offset within 128-byte patch)
                f.seek(6 + p * 128 + 117);
                char name[11];
                f.read((uint8_t*)name, 10);
                name[10] = '\0';
                // Trim trailing spaces
                for (int t = 9; t >= 0 && name[t] == ' '; t--) name[t] = '\0';
                // Replace any commas in name to avoid parsing issues
                for (int t = 0; t < 10 && name[t]; t++) {
                    if (name[t] == ',') name[t] = '_';
                }
                if (p > 0) Serial.print(",");
                while (Serial.availableForWrite() < 20) { delayMicroseconds(100); }
                Serial.print(name);
            }
            Serial.println();
            f.close();
        } else {
            if (f) f.close();
            txPrint("ERR:DX7PATCHES:INVALID\n");
        }
    }
    else if (cmdLen == 7 && memcmp(cmd, "DX7LOAD", 7) == 0 && params) {
        // DX7LOAD:track:patchIndex:filename — load a DX7 patch from SD .syx file
        const char* s1 = strchr(params, ':');
        if (s1) {
            uint8_t track = atoi(params);
            const char* s2 = strchr(s1 + 1, ':');
            if (s2) {
                int patchIdx = atoi(s1 + 1);
                const char* filename = s2 + 1;
                if (track < 8 && patchIdx >= 0 && patchIdx < 32 && strlen(filename) > 0) {
                    char path[72];
                    snprintf(path, sizeof(path), "/%s", filename);
                    File f = SD.open(path);
                    if (f && f.size() >= 4104) {
                        uint8_t syxBuf[4104];
                        f.read(syxBuf, 4104);
                        f.close();
                        int base = track * VOICES_PER_SYNTH_TRACK;
                        for (int v = 0; v < VOICES_PER_SYNTH_TRACK; v++) {
                            multiEngine[base + v].loadDX7Patch(syxBuf, patchIdx);
                        }
                        char buf[60];
                        int n = snprintf(buf, sizeof(buf), "ACK:DX7LOAD:%d:%d:%s\n", track, patchIdx, filename);
                        txEnqueue(buf, n);
                    } else {
                        if (f) f.close();
                        txPrint("ERR:DX7LOAD:FILE\n");
                    }
                } else {
                    txPrint("ERR:DX7LOAD:PARAM\n");
                }
            }
        }
    }
    else if (cmdLen == 9 && memcmp(cmd, "DX7UPLOAD", 9) == 0 && params) {
        // DX7UPLOAD:track — receive 128-byte DX7 patch over serial
        uint8_t track = atoi(params);
        if (track < 8) {
            Serial.print("READY\n");
            Serial.flush();

            // Build a minimal syx-like buffer: 6-byte header + 128-byte patch
            // We only need the patch data, so just read 128 bytes and wrap it
            uint8_t syxBuf[134];  // 6 header + 128 patch
            memset(syxBuf, 0, 6);
            uint32_t received = 0;
            unsigned long timeout = millis() + 5000;
            while (received < 128 && millis() < timeout) {
                if (Serial.available()) {
                    syxBuf[6 + received] = Serial.read();
                    received++;
                    timeout = millis() + 3000;
                }
            }
            if (received == 128) {
                int base = track * VOICES_PER_SYNTH_TRACK;
                for (int v = 0; v < VOICES_PER_SYNTH_TRACK; v++) {
                    multiEngine[base + v].loadDX7Patch(syxBuf, 0);
                }
                char buf[30]; int n = snprintf(buf, sizeof(buf), "ACK:DX7UPLOAD:%d\n", track);
                txEnqueue(buf, n);
            } else {
                txPrint("ERR:DX7UPLOAD:INCOMPLETE\n");
            }
        } else {
            txPrint("ERR:DX7UPLOAD:TRACK\n");
        }
    }
    else if (cmdLen == 8 && memcmp(cmd, "DX7CLEAR", 8) == 0 && params) {
        // DX7CLEAR:track — clear DX7 patch, revert to default FM ratios
        uint8_t track = atoi(params);
        if (track < 8) {
            int base = track * VOICES_PER_SYNTH_TRACK;
            for (int v = 0; v < VOICES_PER_SYNTH_TRACK; v++) {
                multiEngine[base + v].clearDX7Patch();
            }
            char buf[30]; int n = snprintf(buf, sizeof(buf), "ACK:DX7CLEAR:%d\n", track);
            txEnqueue(buf, n);
        }
    }
    else if (cmdLen == 9 && memcmp(cmd, "POLYCOUNT", 9) == 0 && params) {
        // POLYCOUNT:track:count — set polyphonic voice count (1 or 4) for any track
        const char* sep = strchr(params, ':');
        if (sep) {
            uint8_t track = atoi(params);
            uint8_t count = atoi(sep + 1);
            if (track < 8) {
                synthSetVoiceCount(track, count);
                char buf[30]; int n = snprintf(buf, sizeof(buf), "ACK:POLYCOUNT:%d:%d\n", track, synthTrackState[track].voiceCount);
                txEnqueue(buf, n);
            }
        }
    }
    else if (cmdLen == 5 && memcmp(cmd, "FOCUS", 5) == 0 && params) {
        // FOCUS:track — set which track receives external MIDI input
        uint8_t track = atoi(params);
        if (track < 8) {
            focusedTrack = track;
            char buf[20]; int n = snprintf(buf, sizeof(buf), "ACK:FOCUS:%d\n", track);
            txEnqueue(buf, n);
        }
    }
    else if (cmdLen == 10 && memcmp(cmd, "DELETEFILE", 10) == 0 && params) {
        if (SD.exists(params)) {
            SD.remove(params);
            char buf[30];
            int n = snprintf(buf, sizeof(buf), "ACK:DELETEFILE\n");
            txEnqueue(buf, n);
        } else {
            txPrint("ERR:DELETEFILE:NOFILE\n");
        }
    }
    else if (cmdLen == 5 && memcmp(cmd, "MKDIR", 5) == 0 && params) {
        SD.mkdir(params);
        txPrint("ACK:MKDIR\n");
    }
    else if (cmdLen == 8 && memcmp(cmd, "DOWNLOAD", 8) == 0 && params) {
        // DOWNLOAD:filepath — read file from SD and send contents
        File f = SD.open(params, FILE_READ);
        if (!f) {
            txPrint("ERR:DOWNLOAD:NOFILE\n");
        } else {
            uint32_t fileSize = f.size();
            // Send header with size so app knows how many bytes to expect
            Serial.printf("FILEDATA:%lu\n", (unsigned long)fileSize);
            Serial.flush();
            // Send raw file bytes
            uint8_t readBuf[256];
            while (f.available()) {
                while (Serial.availableForWrite() < 256) { delayMicroseconds(100); }
                int n = f.read(readBuf, sizeof(readBuf));
                Serial.write(readBuf, n);
            }
            f.close();
            Serial.flush();
            txPrint("ACK:DOWNLOAD\n");
        }
    }
    else {
        char buf[40];
        int n = snprintf(buf, sizeof(buf), "UNKNOWN:%.30s\n", cmd);
        txEnqueue(buf, n);
    }
}

// Read at most 128 bytes per loop() — prevents serial storms from stalling the engine
static void processSerialInput() {
    int bytesRead = 0;
    while (Serial.available() && bytesRead < 128) {
        char c = Serial.read();
        bytesRead++;
        if (c == '\n') {
            serialBuf[serialBufLen] = '\0';
            processCommand(serialBuf, serialBufLen);
            serialBufLen = 0;
        } else if (c != '\r' && serialBufLen < sizeof(serialBuf) - 2) {
            serialBuf[serialBufLen++] = c;
        }
    }
}

// =============================================================
// Controls
// =============================================================
static const int potPins[NUM_POTS] = { POT_1_PIN, POT_2_PIN, POT_3_PIN, POT_4_PIN };
static int potValues[NUM_POTS] = {0};
static int lastPotValues[NUM_POTS] = {0};
static const int POT_THRESHOLD = 4;
static const int btnPins[NUM_BTNS] = { BTN_PLAY_PIN, BTN_REC_PIN, BTN_MODE_PIN, BTN_SHIFT_PIN };
static bool btnStates[NUM_BTNS] = {false};
static bool lastBtnStates[NUM_BTNS] = {false};
static unsigned long lastDebounce[NUM_BTNS] = {0};

void updateControls() {
    for (int i = 0; i < NUM_POTS; i++) {
        potValues[i] = analogRead(potPins[i]);
        if (abs(potValues[i] - lastPotValues[i]) > POT_THRESHOLD) {
            lastPotValues[i] = potValues[i];
        }
    }
    for (int i = 0; i < NUM_BTNS; i++) {
        bool reading = !digitalRead(btnPins[i]);
        if (reading != lastBtnStates[i]) lastDebounce[i] = millis();
        if ((millis() - lastDebounce[i]) > 30) {
            if (reading != btnStates[i]) btnStates[i] = reading;
        }
        lastBtnStates[i] = reading;
    }
}

// =============================================================
// Setup
// =============================================================
void setup() {
    Serial.begin(115200);
    AudioMemory(AUDIO_MEM_BLOCKS);
    voicesInit();

    // Initialize all 8 drum submixers: ALL inputs muted
    // Each track starts silent until a mode is explicitly enabled
    // Input 0 = old synth voice, Input 1 = sample player, Input 2 = MultiEngine, Input 3 = grain
    for (int i = 0; i < 8; i++) {
        drumMix[i].gain(0, 0.0f);
        drumMix[i].gain(1, 0.0f);
        drumMix[i].gain(2, 0.0f);
        drumMix[i].gain(3, 0.0f);
    }

    // Initialize poly voice mixers: equal gain for 4 voices per synth track
    for (int i = 0; i < 8; i++) {
        for (int v = 0; v < VOICES_PER_SYNTH_TRACK; v++) {
            polyMix[i].gain(v, 0.25f);
        }
    }

    applyPanGains();
    updateAllVoiceAmplitudes();
    mixMasterL.gain(0, 0.8f); mixMasterL.gain(1, 0.8f);
    mixMasterR.gain(0, 0.8f); mixMasterR.gain(1, 0.8f);
    mixMasterL.gain(2, 0.8f); // preview player L
    mixMasterR.gain(2, 0.8f); // preview player R

    #ifdef HAS_AUDIO_SHIELD
    codec.enable(); codec.volume(0.7f);
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

    SD.begin(BUILTIN_SDCARD);

    seq.setNoteOnCallback(onSeqNoteOn);
    seq.setNoteOffCallback(onSeqNoteOff);
    usbMIDI.setHandleNoteOn(handleMidiNoteOn);
    usbMIDI.setHandleNoteOff(handleMidiNoteOff);
    usbMIDI.setHandleControlChange(handleMidiCC);

    // Sequencer starts empty — patterns loaded via app or SD

    txPrint("=== Sampler-Crow v0.5 ===\n");
    seq.markGridDirty();
}

// =============================================================
// Main Loop — fast, non-blocking, deterministic
// =============================================================
static unsigned long lastMeterTime = 0;
static unsigned long lastGridSendTime = 0;

void loop() {
    // 1. Drain TX buffer (max 64 bytes, non-blocking)
    drainSerialTx();

    // 2. Read MIDI (non-blocking)
    usbMIDI.read();

    // 3. Read serial (max 128 bytes per iteration)
    processSerialInput();

    // 4. Apply coalesced mixer changes (once, not per-command)
    applyMixerIfDirty();

    // 4b. Preview loop restart (if looping and playback finished, restart)
    if (previewLooping && previewPath[0] != '\0' && !previewPlayer.isPlaying()) {
        previewPlayer.playWav(previewPath);
    }

    // 4c. Service pending sample triggers (set by ISR, played here in loop context)
    for (int i = 0; i < MAX_SAMPLE_TRACKS; i++) {
        if (samplePending[i]) {
            samplePending[i] = false;
            if (trackUseSample[i] && trackSamplePath[i][0] != '\0') {
                SamplerParams& p = samplerParams[i];

                if (p.samplerMode == 1) {
                    // Grain mode
                    grainPlayer[i].noteOn(samplePendingVel[i] / 127.0f);
                } else if (p.samplerMode == 2) {
                    // Chop mode
                    uint8_t note = samplePendingNote[i];
                    uint8_t sliceIdx = (note >= 36) ? (note - 36) : 0;
                    ChopParams& cp = chopParams[i];
                    if (sliceIdx < cp.sliceCount) {
                        float rate = powf(2.0f, (p.pitchSemitones + p.pitchCents / 100.0f) / 12.0f);
                        sdPlayer[i].setPlaybackRate(rate);
                        sdPlayer[i].setLoopType(looptype_none);
                        sdPlayer[i].playWav(trackSamplePath[i]);
                        // TODO: seek to slice start position
                    }
                } else {
                    // Pitch mode (mode 0, default)
                    float rate = powf(2.0f, (p.pitchSemitones + p.pitchCents / 100.0f) / 12.0f);
                    sdPlayer[i].setPlaybackRate(rate);
                    if (p.loopEnabled) {
                        sdPlayer[i].setLoopType(looptype_repeat);
                        if (p.loopStart > 0) sdPlayer[i].setLoopStart(p.loopStart);
                        if (p.loopEnd > 0) sdPlayer[i].setLoopFinish(p.loopEnd);
                    } else {
                        sdPlayer[i].setLoopType(looptype_none);
                    }
                    sdPlayer[i].playWav(trackSamplePath[i]);
                }
            }
        }
    }

    // 4d. Service pending drum pad triggers (set by ISR, played here in loop context)
    for (int i = 0; i < MAX_SAMPLE_TRACKS; i++) {
        if (drumPadPending[i]) {
            drumPadPending[i] = false;
            uint8_t pad = drumPadPendingPad[i];
            uint8_t vel = drumPadPendingVel[i];
            if (trackIsDrumMachine[i] && drumPadPath[i][pad][0] != '\0') {
                SamplerParams& p = drumPadParams[i][pad];
                float rate = powf(2.0f, (p.pitchSemitones + p.pitchCents / 100.0f) / 12.0f);
                sdPlayer[i].setPlaybackRate(rate);
                sdPlayer[i].setLoopType(looptype_none);
                sdPlayer[i].playWav(drumPadPath[i][pad]);
            }
        }
    }

    // 5. Handle sequencer UI updates
    unsigned long now = millis();
    if (seq.consumeStepAdvanced()) {
        seq.sendStepUpdate();
    }
    // Rate-limit full grid sends to max 20Hz (50ms) to prevent serial floods during rapid toggles
    if (seq.consumeGridDirty()) {
        if (now - lastGridSendTime >= 50) {
            lastGridSendTime = now;
            seq.sendGridState();
        } else {
            seq.markGridDirty();  // re-mark, will send on next eligible loop
        }
    }

    // 6. Physical controls
    updateControls();

    // 7. CPU/MEM at 2Hz (low priority, through TX buffer)
    if (now - lastMeterTime > 500) {
        lastMeterTime = now;
        char buf[40];
        int n = snprintf(buf, sizeof(buf), "CPU:%.1f\nMEM:%d/%d\n",
            AudioProcessorUsage(), AudioMemoryUsage(), AudioMemoryUsageMax());
        txEnqueue(buf, n);
    }
}
