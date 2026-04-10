#include <Audio.h>
#include <SD.h>
#include <string.h>
#include "voices.h"
#include "MultiEngine.h"

// =============================================================
// Voice objects — declared in main.cpp as externs
// =============================================================
// Track 0: Kick (sine 60Hz with fast pitch+amp env)
extern AudioSynthWaveform     v0_osc;
extern AudioEffectEnvelope    v0_ampEnv;
extern AudioEffectEnvelope    v0_pitchEnv;  // used to scale osc freq manually

// Track 1: Snare (noise + triangle tone)
extern AudioSynthNoiseWhite   v1_noise;
extern AudioSynthWaveform     v1_tone;
extern AudioMixer4            v1_mix;
extern AudioEffectEnvelope    v1_env;

// Track 2: Closed Hat (noise through high pass)
extern AudioSynthNoiseWhite   v2_noise;
extern AudioFilterStateVariable v2_hpf;
extern AudioEffectEnvelope    v2_env;

// Track 3: Open Hat (noise through high pass, longer decay)
extern AudioSynthNoiseWhite   v3_noise;
extern AudioFilterStateVariable v3_hpf;
extern AudioEffectEnvelope    v3_env;

// Track 4: Clap (bandpass noise burst)
extern AudioSynthNoiseWhite   v4_noise;
extern AudioFilterStateVariable v4_bpf;
extern AudioEffectEnvelope    v4_env;

// Track 5: Bass (saw + LPF)
extern AudioSynthWaveform     v5_osc;
extern AudioFilterStateVariable v5_lpf;
extern AudioEffectEnvelope    v5_env;

// Track 6: Lead (square + LPF, longer release)
extern AudioSynthWaveform     v6_osc;
extern AudioFilterStateVariable v6_lpf;
extern AudioEffectEnvelope    v6_env;

// Track 7: Pluck (triangle + fast decay)
extern AudioSynthWaveform     v7_osc;
extern AudioEffectEnvelope    v7_env;

// Per-voice last velocity (0.0-1.0), stored at trigger time
float lastVelocity[8] = {0};

// --- Sampler params (per-track) ---
//  gain, pitchSemi, pitchCents, sampleStart, sampleEnd, loopEnabled, loopStart, loopEnd, oneShot,
//  samplerMode, rootNote, attackMs, decayMs, sustainLevel, releaseMs,
//  grainPosition, grainWindowSize, grainSizeMs, grainCount, grainSpread, grainEnvShape,
//  chopSensitivity, chopTriggerMode
SamplerParams samplerParams[8] = {
    {1.0f, 0, 0, 0, 0, false, 0, 0, true, 0, 60, 5, 100, 1.0f, 50, 0.5f, 0.3f, 100, 4, 0.5f, 0, 0.5f, 0},
    {1.0f, 0, 0, 0, 0, false, 0, 0, true, 0, 60, 5, 100, 1.0f, 50, 0.5f, 0.3f, 100, 4, 0.5f, 0, 0.5f, 0},
    {1.0f, 0, 0, 0, 0, false, 0, 0, true, 0, 60, 5, 100, 1.0f, 50, 0.5f, 0.3f, 100, 4, 0.5f, 0, 0.5f, 0},
    {1.0f, 0, 0, 0, 0, false, 0, 0, true, 0, 60, 5, 100, 1.0f, 50, 0.5f, 0.3f, 100, 4, 0.5f, 0, 0.5f, 0},
    {1.0f, 0, 0, 0, 0, false, 0, 0, true, 0, 60, 5, 100, 1.0f, 50, 0.5f, 0.3f, 100, 4, 0.5f, 0, 0.5f, 0},
    {1.0f, 0, 0, 0, 0, false, 0, 0, true, 0, 60, 5, 100, 1.0f, 50, 0.5f, 0.3f, 100, 4, 0.5f, 0, 0.5f, 0},
    {1.0f, 0, 0, 0, 0, false, 0, 0, true, 0, 60, 5, 100, 1.0f, 50, 0.5f, 0.3f, 100, 4, 0.5f, 0, 0.5f, 0},
    {1.0f, 0, 0, 0, 0, false, 0, 0, true, 0, 60, 5, 100, 1.0f, 50, 0.5f, 0.3f, 100, 4, 0.5f, 0, 0.5f, 0},
};

// --- Chop params (per-track) ---
ChopParams chopParams[MAX_SAMPLE_TRACKS] = {};
volatile uint8_t samplePendingNote[MAX_SAMPLE_TRACKS] = {0, 0, 0, 0, 0, 0, 0, 0};

// --- Drum sample state ---
bool trackUseSample[MAX_SAMPLE_TRACKS] = {false, false, false, false, false, false, false, false};
char trackSamplePath[MAX_SAMPLE_TRACKS][64] = {"", "", "", "", "", "", "", ""};
volatile bool samplePending[MAX_SAMPLE_TRACKS] = {false, false, false, false, false, false, false, false};
volatile uint8_t samplePendingVel[MAX_SAMPLE_TRACKS] = {0, 0, 0, 0, 0, 0, 0, 0};

// --- Drum machine state ---
bool trackUseMultiEngine[MAX_SAMPLE_TRACKS] = {false, false, false, false, false, false, false, false};
bool trackIsDrumMachine[MAX_SAMPLE_TRACKS] = {false, false, false, false, false, false, false, false};
char drumPadPath[MAX_SAMPLE_TRACKS][8][64] = {{{0}}};
// drumPadParams: zero-initialized, then gain set to 1.0 and oneShot to true (remaining fields default to 0)
SamplerParams drumPadParams[MAX_SAMPLE_TRACKS][8] = {
    {{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0}},
    {{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0}},
    {{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0}},
    {{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0}},
    {{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0}},
    {{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0}},
    {{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0}},
    {{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0},{1.0f,0,0,0,0,false,0,0,true,0,60,5,100,1.0f,50,0.5f,0.3f,100,4,0.5f,0,0.5f,0}},
};
volatile bool drumPadPending[MAX_SAMPLE_TRACKS] = {false, false, false, false, false, false, false, false};
volatile uint8_t drumPadPendingPad[MAX_SAMPLE_TRACKS] = {0, 0, 0, 0, 0, 0, 0, 0};
volatile uint8_t drumPadPendingVel[MAX_SAMPLE_TRACKS] = {0, 0, 0, 0, 0, 0, 0, 0};

// drumMix submixers — declared in main.cpp
extern AudioMixer4 drumMix[8];

void voiceLoadSample(uint8_t track, const char* path) {
    if (track >= MAX_SAMPLE_TRACKS) return;
    trackUseSample[track] = true;
    strncpy(trackSamplePath[track], path, 63);
    trackSamplePath[track][63] = '\0';
    // Mute ALL inputs, enable only sample player (input 1)
    drumMix[track].gain(0, 0.0f);
    drumMix[track].gain(1, 1.0f);
    drumMix[track].gain(2, 0.0f);
    drumMix[track].gain(3, 0.0f);
}

void voiceClearSample(uint8_t track) {
    if (track >= MAX_SAMPLE_TRACKS) return;
    trackUseSample[track] = false;
    trackSamplePath[track][0] = '\0';
    // Mute all inputs — caller should enable the right mode
    drumMix[track].gain(0, 0.0f);
    drumMix[track].gain(1, 0.0f);
    drumMix[track].gain(2, 0.0f);
    drumMix[track].gain(3, 0.0f);
}

// Base amplitude per track (inherent voice level balance)
static const float voiceBaseAmp[8] = {
    0.9f,  // 0: Kick
    0.8f,  // 1: Snare (noise component; tone uses 0.6)
    0.7f,  // 2: Closed Hat
    0.6f,  // 3: Open Hat
    0.8f,  // 4: Clap
    0.7f,  // 5: Bass
    0.5f,  // 6: Lead
    0.7f   // 7: Pluck
};

// MIDI note to frequency
float noteHz(uint8_t note) {
    return 440.0f * powf(2.0f, (note - 69) / 12.0f);
}

void voicesInit() {
    // Track 0 — Kick (60Hz sine)
    v0_osc.begin(0.0f, 60.0f, WAVEFORM_SINE);
    v0_ampEnv.attack(1);
    v0_ampEnv.hold(0);
    v0_ampEnv.decay(180);
    v0_ampEnv.sustain(0);
    v0_ampEnv.release(30);

    // Track 1 — Snare
    v1_noise.amplitude(0.0f);
    v1_tone.begin(0.0f, 200.0f, WAVEFORM_TRIANGLE);
    v1_mix.gain(0, 0.7f);  // noise
    v1_mix.gain(1, 0.3f);  // tone
    v1_mix.gain(2, 0.0f);
    v1_mix.gain(3, 0.0f);
    v1_env.attack(1);
    v1_env.hold(0);
    v1_env.decay(120);
    v1_env.sustain(0);
    v1_env.release(30);

    // Track 2 — Closed Hat
    v2_noise.amplitude(0.0f);
    v2_hpf.frequency(7000);
    v2_hpf.resonance(0.8f);
    v2_env.attack(1);
    v2_env.hold(0);
    v2_env.decay(40);
    v2_env.sustain(0);
    v2_env.release(20);

    // Track 3 — Open Hat
    v3_noise.amplitude(0.0f);
    v3_hpf.frequency(5000);
    v3_hpf.resonance(0.8f);
    v3_env.attack(1);
    v3_env.hold(0);
    v3_env.decay(250);
    v3_env.sustain(0);
    v3_env.release(50);

    // Track 4 — Clap
    v4_noise.amplitude(0.0f);
    v4_bpf.frequency(1200);
    v4_bpf.resonance(2.0f);
    v4_env.attack(1);
    v4_env.hold(0);
    v4_env.decay(100);
    v4_env.sustain(0);
    v4_env.release(30);

    // Track 5 — Bass (percussive, no sustain)
    v5_osc.begin(0.0f, 55.0f, WAVEFORM_SAWTOOTH);
    v5_lpf.frequency(400);
    v5_lpf.resonance(1.5f);
    v5_env.attack(3);
    v5_env.hold(0);
    v5_env.decay(250);
    v5_env.sustain(0.0f);
    v5_env.release(50);

    // Track 6 — Lead (percussive, no sustain)
    v6_osc.begin(0.0f, 440.0f, WAVEFORM_SQUARE);
    v6_lpf.frequency(2500);
    v6_lpf.resonance(1.0f);
    v6_env.attack(5);
    v6_env.hold(0);
    v6_env.decay(300);
    v6_env.sustain(0.0f);
    v6_env.release(100);

    // Track 7 — Pluck
    v7_osc.begin(0.0f, 440.0f, WAVEFORM_TRIANGLE);
    v7_env.attack(2);
    v7_env.hold(0);
    v7_env.decay(250);
    v7_env.sustain(0);
    v7_env.release(50);
}

void voiceTrigger(uint8_t track, uint8_t note, uint8_t velocity) {
    float vel = velocity / 127.0f;
    if (track < 8) lastVelocity[track] = vel;

    // If MultiEngine mode, skip synth trigger (handled in main.cpp)
    if (trackUseMultiEngine[track]) {
        return;
    }

    // For drum tracks 0-4: if sample mode, set pending flag (serviced in loop())
    // and skip synth trigger entirely
    if (track < MAX_SAMPLE_TRACKS && trackUseSample[track]) {
        samplePendingVel[track] = velocity;
        samplePendingNote[track] = note;
        samplePending[track] = true;
        return;
    }

    switch (track) {
        case 0:  // Kick — fixed 60Hz, vel controls amplitude
            v0_osc.amplitude(vel * 0.9f);
            v0_osc.frequency(60.0f);
            v0_ampEnv.noteOn();
            break;

        case 1:  // Snare
            v1_noise.amplitude(vel * 0.8f);
            v1_tone.amplitude(vel * 0.6f);
            v1_env.noteOn();
            break;

        case 2:  // Closed Hat
            v2_noise.amplitude(vel * 0.7f);
            v2_env.noteOn();
            break;

        case 3:  // Open Hat
            v3_noise.amplitude(vel * 0.6f);
            v3_env.noteOn();
            break;

        case 4:  // Clap
            v4_noise.amplitude(vel * 0.8f);
            v4_env.noteOn();
            break;

        case 5: {  // Bass — note sets pitch
            uint8_t bassNote = note > 0 ? note : 36;  // C2 default
            v5_osc.frequency(noteHz(bassNote));
            v5_osc.amplitude(vel * 0.7f);
            v5_env.noteOn();
            break;
        }

        case 6: {  // Lead
            uint8_t leadNote = note > 0 ? note : 60;  // C4 default
            v6_osc.frequency(noteHz(leadNote));
            v6_osc.amplitude(vel * 0.5f);
            v6_env.noteOn();
            break;
        }

        case 7: {  // Pluck
            uint8_t pluckNote = note > 0 ? note : 67;  // G4 default
            v7_osc.frequency(noteHz(pluckNote));
            v7_osc.amplitude(vel * 0.7f);
            v7_env.noteOn();
            break;
        }
    }
}

void voiceSetAmplitude(uint8_t track, float volumeScale) {
    if (track >= 8) return;
    float vel = lastVelocity[track];

    switch (track) {
        case 0:  // Kick
            v0_osc.amplitude(vel * 0.9f * volumeScale);
            break;
        case 1:  // Snare (noise + tone)
            v1_noise.amplitude(vel * 0.8f * volumeScale);
            v1_tone.amplitude(vel * 0.6f * volumeScale);
            break;
        case 2:  // Closed Hat
            v2_noise.amplitude(vel * 0.7f * volumeScale);
            break;
        case 3:  // Open Hat
            v3_noise.amplitude(vel * 0.6f * volumeScale);
            break;
        case 4:  // Clap
            v4_noise.amplitude(vel * 0.8f * volumeScale);
            break;
        case 5:  // Bass
            v5_osc.amplitude(vel * 0.7f * volumeScale);
            break;
        case 6:  // Lead
            v6_osc.amplitude(vel * 0.5f * volumeScale);
            break;
        case 7:  // Pluck
            v7_osc.amplitude(vel * 0.7f * volumeScale);
            break;
    }
}

void voiceRelease(uint8_t track) {
    switch (track) {
        case 0: v0_ampEnv.noteOff(); break;
        case 1: v1_env.noteOff(); break;
        case 2: v2_env.noteOff(); break;
        case 3: v3_env.noteOff(); break;
        case 4: v4_env.noteOff(); break;
        case 5: v5_env.noteOff(); break;
        case 6: v6_env.noteOff(); break;
        case 7: v7_env.noteOff(); break;
    }
}

static const char* trackNames[8] = {
    "Kick", "Snare", "ClHat", "OpHat", "Clap", "Bass", "Lead", "Pluck"
};

const char* voiceName(uint8_t track) {
    if (track >= 8) return "?";
    return trackNames[track];
}

void voiceLoadDrumPad(uint8_t track, uint8_t pad, const char* path) {
    if (track >= MAX_SAMPLE_TRACKS || pad >= 8) return;
    strncpy(drumPadPath[track][pad], path, 63);
    drumPadPath[track][pad][63] = '\0';
    trackIsDrumMachine[track] = true;
    // Switch drumMix: mute synth (input 0), enable sample (input 1)
    drumMix[track].gain(0, 0.0f);
    drumMix[track].gain(1, 1.0f);
}

void voiceClearDrumPad(uint8_t track, uint8_t pad) {
    if (track >= MAX_SAMPLE_TRACKS || pad >= 8) return;
    drumPadPath[track][pad][0] = '\0';
}

void voiceTriggerDrumPad(uint8_t track, uint8_t pad, uint8_t velocity) {
    if (track >= MAX_SAMPLE_TRACKS || pad >= 8) return;
    drumPadPendingPad[track] = pad;
    drumPadPendingVel[track] = velocity;
    drumPadPending[track] = true;  // set last — ISR-safe flag
}

void drumPadComputeWaveform(uint8_t track, uint8_t pad) {
    if (track >= MAX_SAMPLE_TRACKS || pad >= 8) return;
    if (drumPadPath[track][pad][0] == '\0') return;

    File f = SD.open(drumPadPath[track][pad]);
    if (!f) return;

    // Skip WAV header (44 bytes standard)
    f.seek(44);
    uint32_t dataSize = f.size() - 44;
    if (dataSize < 2) { f.close(); return; }

    uint32_t totalSamples = dataSize / 2;  // 16-bit mono assumed
    uint32_t bucketSize = totalSamples / 128;
    if (bucketSize == 0) bucketSize = 1;

    uint8_t peaks[128];
    int16_t sampleBuf[256];

    for (int b = 0; b < 128; b++) {
        uint32_t startSample = b * bucketSize;
        uint32_t endSample = startSample + bucketSize;
        if (endSample > totalSamples) endSample = totalSamples;

        int16_t maxAbs = 0;
        uint32_t pos = startSample;
        while (pos < endSample) {
            uint32_t toRead = endSample - pos;
            if (toRead > 256) toRead = 256;
            f.seek(44 + pos * 2);
            size_t bytesRead = f.read(sampleBuf, toRead * 2);
            uint32_t samplesRead = bytesRead / 2;
            for (uint32_t s = 0; s < samplesRead; s++) {
                int16_t v = sampleBuf[s];
                if (v < 0) v = -v;
                if (v > maxAbs) maxAbs = v;
            }
            pos += samplesRead;
            if (samplesRead == 0) break;
        }
        // Scale to 0-255
        peaks[b] = (uint8_t)((maxAbs * 255L) / 32767);
    }
    f.close();

    // Send via direct Serial.print (too large for TX ring buffer)
    while (Serial.availableForWrite() < 20) { delayMicroseconds(100); }
    Serial.print("PADWFORM:");
    Serial.print(track);
    Serial.print(":");
    Serial.print(pad);
    Serial.print(":");
    for (int b = 0; b < 128; b++) {
        while (Serial.availableForWrite() < 10) { delayMicroseconds(100); }
        if (b > 0) Serial.print(",");
        Serial.print(peaks[b]);
    }
    while (Serial.availableForWrite() < 4) { delayMicroseconds(100); }
    Serial.println();
}

void computeSlices(uint8_t track) {
    if (track >= MAX_SAMPLE_TRACKS || !trackUseSample[track]) return;
    ChopParams& cp = chopParams[track];
    cp.sliceCount = 0;
    cp.sliceBoundaries[0] = samplerParams[track].sampleStart;
    cp.sliceCount = 1;

    File f = SD.open(trackSamplePath[track]);
    if (!f) return;
    f.seek(44); // skip WAV header

    uint32_t totalSamples = (f.size() - 44) / 2; // 16-bit mono
    float sensitivity = samplerParams[track].chopSensitivity;
    float threshold = 2.0f + sensitivity * 8.0f; // 2x-10x average
    float avgEnergy = 0.001f;
    uint32_t lastSlice = 0;
    int16_t frame[512];
    uint32_t samplePos = 0;

    while (f.available() >= 1024 && cp.sliceCount < MAX_SLICES) {
        int bytesRead = f.read((uint8_t*)frame, 1024); // 512 samples
        int samplesRead = bytesRead / 2;

        float energy = 0;
        for (int i = 0; i < samplesRead; i++) {
            float s = frame[i] / 32768.0f;
            energy += s * s;
        }
        energy = sqrtf(energy / samplesRead);

        if (energy > threshold * avgEnergy && (samplePos - lastSlice) > 2048) {
            cp.sliceBoundaries[cp.sliceCount++] = samplePos;
            lastSlice = samplePos;
        }
        avgEnergy = 0.95f * avgEnergy + 0.05f * energy;
        samplePos += samplesRead;
    }
    f.close();

    // Send slice data to app
    char buf[300];
    int pos = snprintf(buf, sizeof(buf), "CHOPSLICES:%d:%d:", track, cp.sliceCount);
    for (int i = 0; i < cp.sliceCount && pos < 280; i++) {
        if (i > 0) buf[pos++] = ',';
        pos += snprintf(buf+pos, sizeof(buf)-pos, "%lu", (unsigned long)cp.sliceBoundaries[i]);
    }
    buf[pos++] = '\n';
    Serial.write(buf, pos);
}

void samplerComputeWaveform(uint8_t track) {
    if (track >= MAX_SAMPLE_TRACKS) return;
    if (trackSamplePath[track][0] == '\0') return;

    File f = SD.open(trackSamplePath[track]);
    if (!f) return;

    // Skip WAV header (44 bytes standard)
    f.seek(44);
    uint32_t dataSize = f.size() - 44;
    if (dataSize < 2) { f.close(); return; }

    uint32_t totalSamples = dataSize / 2;  // 16-bit mono assumed
    uint32_t bucketSize = totalSamples / 128;
    if (bucketSize == 0) bucketSize = 1;

    uint8_t peaks[128];
    int16_t sampleBuf[256];

    for (int b = 0; b < 128; b++) {
        uint32_t startSample = b * bucketSize;
        uint32_t endSample = startSample + bucketSize;
        if (endSample > totalSamples) endSample = totalSamples;

        int16_t maxAbs = 0;
        uint32_t pos = startSample;
        while (pos < endSample) {
            uint32_t toRead = endSample - pos;
            if (toRead > 256) toRead = 256;
            f.seek(44 + pos * 2);
            size_t bytesRead = f.read(sampleBuf, toRead * 2);
            uint32_t samplesRead = bytesRead / 2;
            for (uint32_t s = 0; s < samplesRead; s++) {
                int16_t v = sampleBuf[s];
                if (v < 0) v = -v;
                if (v > maxAbs) maxAbs = v;
            }
            pos += samplesRead;
            if (samplesRead == 0) break;
        }
        // Scale to 0-255
        peaks[b] = (uint8_t)((maxAbs * 255L) / 32767);
    }
    f.close();

    // Send via direct Serial.print (too large for TX ring buffer)
    while (Serial.availableForWrite() < 20) { delayMicroseconds(100); }
    Serial.print("WFORM:");
    Serial.print(track);
    Serial.print(":");
    for (int b = 0; b < 128; b++) {
        while (Serial.availableForWrite() < 10) { delayMicroseconds(100); }
        if (b > 0) Serial.print(",");
        Serial.print(peaks[b]);
    }
    while (Serial.availableForWrite() < 4) { delayMicroseconds(100); }
    Serial.println();
}

// =============================================================
// Polyphonic MultiEngine voice allocation (tracks 5, 6, 7)
// =============================================================

// 32 MultiEngine instances: 8 tracks x 4 voices each (declared in main.cpp)
extern MultiEngine multiEngine[32];

SynthTrackState synthTrackState[8] = {
    {{255, 255, 255, 255}, {0, 0, 0, 0}, 0, 1},
    {{255, 255, 255, 255}, {0, 0, 0, 0}, 0, 1},
    {{255, 255, 255, 255}, {0, 0, 0, 0}, 0, 1},
    {{255, 255, 255, 255}, {0, 0, 0, 0}, 0, 1},
    {{255, 255, 255, 255}, {0, 0, 0, 0}, 0, 1},
    {{255, 255, 255, 255}, {0, 0, 0, 0}, 0, 1},
    {{255, 255, 255, 255}, {0, 0, 0, 0}, 0, 1},
    {{255, 255, 255, 255}, {0, 0, 0, 0}, 0, 1},
};

void synthNoteOn(uint8_t trackOffset, uint8_t note, float velocity) {
    if (trackOffset >= 8) return;
    SynthTrackState& st = synthTrackState[trackOffset];
    int baseVoice = trackOffset * VOICES_PER_SYNTH_TRACK;

    // Check if note is already playing (re-trigger)
    for (int i = 0; i < st.voiceCount; i++) {
        if (st.voiceNote[i] == note) {
            multiEngine[baseVoice + i].noteOn(noteHz(note), velocity);
            st.voiceAge[i] = ++st.ageCounter;
            return;
        }
    }

    // Find free voice
    for (int i = 0; i < st.voiceCount; i++) {
        if (st.voiceNote[i] == 255) {
            st.voiceNote[i] = note;
            st.voiceAge[i] = ++st.ageCounter;
            multiEngine[baseVoice + i].noteOn(noteHz(note), velocity);
            return;
        }
    }

    // Voice stealing: find oldest voice
    int oldest = 0;
    uint32_t oldestAge = st.voiceAge[0];
    for (int i = 1; i < st.voiceCount; i++) {
        if (st.voiceAge[i] < oldestAge) {
            oldestAge = st.voiceAge[i];
            oldest = i;
        }
    }
    multiEngine[baseVoice + oldest].noteOff();
    st.voiceNote[oldest] = note;
    st.voiceAge[oldest] = ++st.ageCounter;
    multiEngine[baseVoice + oldest].noteOn(noteHz(note), velocity);
}

void synthNoteOff(uint8_t trackOffset, uint8_t note) {
    if (trackOffset >= 8) return;
    SynthTrackState& st = synthTrackState[trackOffset];
    int baseVoice = trackOffset * VOICES_PER_SYNTH_TRACK;
    for (int i = 0; i < st.voiceCount; i++) {
        if (st.voiceNote[i] == note) {
            multiEngine[baseVoice + i].noteOff();
            st.voiceNote[i] = 255;
            return;
        }
    }
}

void synthAllNotesOff(uint8_t trackOffset) {
    if (trackOffset >= 8) return;
    SynthTrackState& st = synthTrackState[trackOffset];
    int baseVoice = trackOffset * VOICES_PER_SYNTH_TRACK;
    for (int i = 0; i < st.voiceCount; i++) {
        multiEngine[baseVoice + i].noteOff();
        st.voiceNote[i] = 255;
    }
}

void synthSetVoiceCount(uint8_t trackOffset, uint8_t count) {
    if (trackOffset >= 8) return;
    // Clamp to valid values: 1 or 4
    if (count > 1) count = VOICES_PER_SYNTH_TRACK;
    else count = 1;
    // Turn off any voices beyond the new count
    synthAllNotesOff(trackOffset);
    synthTrackState[trackOffset].voiceCount = count;
}
