#include <Audio.h>
#include "voices.h"

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

// MIDI note to frequency
static float noteHz(uint8_t note) {
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

    switch (track) {
        case 0:  // Kick — fixed 60Hz, vel controls amplitude. Pitch env via manual freq sweep would need scheduling; use simple amp env for now.
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
