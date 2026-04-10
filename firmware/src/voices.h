#ifndef VOICES_H
#define VOICES_H

#include <Arduino.h>

// 8 tracks, each with its own synth voice:
// Track 0: Kick      (sine + pitch env)
// Track 1: Snare     (noise + tone)
// Track 2: Hat       (filtered noise, short)
// Track 3: Open Hat  (filtered noise, longer)
// Track 4: Clap      (noise + env)
// Track 5: Bass      (saw + LP filter)
// Track 6: Lead      (saw + HP filter)
// Track 7: Pluck     (triangle + fast decay)

// --- Drum sample playback (Phase 8) ---
// Tracks 0-4 can optionally play WAV samples from SD instead of synth voices.
// Tracks 5-7 remain synth-only.
#define MAX_SAMPLE_TRACKS 8

struct SamplerParams {
    float gain;            // 0.0-1.0
    int8_t pitchSemitones; // -24 to +24
    int8_t pitchCents;     // -50 to +50
    uint32_t sampleStart;  // sample offset
    uint32_t sampleEnd;    // 0 = full length
    bool loopEnabled;
    uint32_t loopStart;
    uint32_t loopEnd;
    bool oneShot;
    uint8_t samplerMode;     // 0=Pitch, 1=Grain, 2=Chop
    uint8_t rootNote;        // default 60 (C4)
    uint16_t attackMs;       // ADSR attack (default 5)
    uint16_t decayMs;        // ADSR decay (default 100)
    float sustainLevel;      // ADSR sustain (default 1.0)
    uint16_t releaseMs;      // ADSR release (default 50)
    // Grain params
    float grainPosition;     // 0.0-1.0 normalized window center
    float grainWindowSize;   // 0.0-1.0 normalized
    uint16_t grainSizeMs;    // 10-500ms per grain
    uint8_t grainCount;      // 1-16 simultaneous grains
    float grainSpread;       // 0.0-1.0 position randomization
    uint8_t grainEnvShape;   // 0=Hann, 1=Gaussian, 2=Triangle, 3=Tukey
    // Chop params
    float chopSensitivity;   // 0.0-1.0 detection threshold
    uint8_t chopTriggerMode; // 0=Trigger, 1=Gate
};

extern SamplerParams samplerParams[8];
void samplerComputeWaveform(uint8_t track);

#define MAX_SLICES 36
struct ChopParams {
    uint32_t sliceBoundaries[MAX_SLICES];
    uint8_t sliceCount;
};
extern ChopParams chopParams[MAX_SAMPLE_TRACKS];

void computeSlices(uint8_t track);
extern volatile uint8_t samplePendingNote[MAX_SAMPLE_TRACKS];

extern bool trackUseSample[MAX_SAMPLE_TRACKS];    // true = play WAV, false = synth
extern char trackSamplePath[MAX_SAMPLE_TRACKS][64]; // SD file path

// ISR-safe pending flags: set in voiceTrigger (ISR), serviced in loop()
extern volatile bool samplePending[MAX_SAMPLE_TRACKS];
extern volatile uint8_t samplePendingVel[MAX_SAMPLE_TRACKS];

void voiceLoadSample(uint8_t track, const char* path);  // set sample path for a track
void voiceClearSample(uint8_t track);                    // revert to synth

// Trigger a voice on a track. note/velocity come from the sequencer.
// For drum tracks, note is ignored and fixed pitch is used.
// For melodic tracks (5,6,7), note sets the pitch.
void voiceTrigger(uint8_t track, uint8_t note, uint8_t velocity);
void voiceRelease(uint8_t track);

// Set oscillator amplitude for a track based on lastVelocity * baseAmp * volumeScale
void voiceSetAmplitude(uint8_t track, float volumeScale);

// Initialize all voices — call once in setup() after AudioMemory()
void voicesInit();

// Get track name (for debug/UI)
const char* voiceName(uint8_t track);

// Per-voice last velocity (0.0-1.0), stored at trigger time
extern float lastVelocity[8];

// --- Drum machine mode (per-track, 8 pads each) ---
extern bool trackUseMultiEngine[MAX_SAMPLE_TRACKS];
extern bool trackIsDrumMachine[MAX_SAMPLE_TRACKS];
extern char drumPadPath[MAX_SAMPLE_TRACKS][8][64];
extern SamplerParams drumPadParams[MAX_SAMPLE_TRACKS][8];
extern volatile bool drumPadPending[MAX_SAMPLE_TRACKS];
extern volatile uint8_t drumPadPendingPad[MAX_SAMPLE_TRACKS];
extern volatile uint8_t drumPadPendingVel[MAX_SAMPLE_TRACKS];

// MIDI note to frequency (used by main.cpp for MultiEngine)
float noteHz(uint8_t note);

void voiceLoadDrumPad(uint8_t track, uint8_t pad, const char* path);
void voiceClearDrumPad(uint8_t track, uint8_t pad);
void voiceTriggerDrumPad(uint8_t track, uint8_t pad, uint8_t velocity);
void drumPadComputeWaveform(uint8_t track, uint8_t pad);

// --- Polyphonic MultiEngine voice allocation (any track 0-7) ---
#define VOICES_PER_SYNTH_TRACK 4

struct SynthTrackState {
    uint8_t voiceNote[VOICES_PER_SYNTH_TRACK]; // 255 = free
    uint32_t voiceAge[VOICES_PER_SYNTH_TRACK];
    uint32_t ageCounter;
    uint8_t voiceCount; // 1 or 4
};

extern SynthTrackState synthTrackState[8]; // all 8 tracks

void synthNoteOn(uint8_t trackOffset, uint8_t note, float velocity);
void synthNoteOff(uint8_t trackOffset, uint8_t note);
void synthAllNotesOff(uint8_t trackOffset);
void synthSetVoiceCount(uint8_t trackOffset, uint8_t count);

#endif
