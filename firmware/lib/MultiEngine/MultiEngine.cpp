#include "MultiEngine.h"
#include <Arduino.h>
#include <math.h>
#include <string.h>

// ============================================================
// Wavetable data — 4 single-cycle waveforms, 256 samples each
// ============================================================
static const int WT_SIZE = 256;

static float wt_sine[WT_SIZE];
static float wt_triangle[WT_SIZE];
static float wt_saw[WT_SIZE];
static float wt_square[WT_SIZE];

static bool wt_initialized = false;

static void initWavetables() {
    if (wt_initialized) return;
    for (int i = 0; i < WT_SIZE; i++) {
        float p = (float)i / (float)WT_SIZE;
        wt_sine[i] = sinf(p * 2.0f * M_PI);
        wt_triangle[i] = (p < 0.5f) ? (4.0f * p - 1.0f) : (3.0f - 4.0f * p);
        wt_saw[i] = 2.0f * p - 1.0f;
        wt_square[i] = (p < 0.5f) ? 1.0f : -1.0f;
    }
    wt_initialized = true;
}

static const float* wavetables[4] = { wt_sine, wt_triangle, wt_saw, wt_square };

// ============================================================
// Constructor
// ============================================================
MultiEngine::MultiEngine() : AudioStream(0, NULL) {
    _engine = 0;
    _frequency = 440.0f;
    _amplitude = 0.0f;
    _timbre = 0.5f;
    _harmonics = 0.5f;
    _morph = 0.0f;
    _phase = 0.0f;
    _phase2 = 0.0f;
    _modPhase = 0.0f;
    _active = false;
    _noteOn = false;
    _envLevel = 0.0f;
    _pitchEnvLevel = 0.0f;
    memset(_formantBuf, 0, sizeof(_formantBuf));
    memset(_chordPhases, 0, sizeof(_chordPhases));
    memset(_grainPhases, 0, sizeof(_grainPhases));
    memset(_grainAmps, 0, sizeof(_grainAmps));
    memset(_delayLine, 0, sizeof(_delayLine));
    _delayWritePos = 0;
    _delayFeedback = 0.0f;
    memset(_modalFreqs, 0, sizeof(_modalFreqs));
    memset(_modalStates, 0, sizeof(_modalStates));
    memset(_svfState, 0, sizeof(_svfState));
    memset(_fmOpPhases, 0, sizeof(_fmOpPhases));
    memset(&_dx7Patch, 0, sizeof(_dx7Patch));
    _dx7Loaded = false;
    _chorusPhase = 0.0f;
    memset(_chipPhases, 0, sizeof(_chipPhases));
    initWavetables();
}

// ============================================================
// Setters
// ============================================================
void MultiEngine::setEngine(uint8_t engine) {
    if (engine > 23) engine = 23;
    _engine = engine;
}

void MultiEngine::setTimbre(float v) {
    _timbre = constrain(v, 0.0f, 1.0f);
}

void MultiEngine::setHarmonics(float v) {
    _harmonics = constrain(v, 0.0f, 1.0f);
}

void MultiEngine::setMorph(float v) {
    _morph = constrain(v, 0.0f, 1.0f);
}

void MultiEngine::noteOn(float freq, float amp) {
    _frequency = freq;
    _amplitude = amp;
    _noteOn = true;
    _active = true;

    // Karplus-Strong: fill delay line with noise burst
    if (_engine == 11) {
        uint16_t delayLen = (uint16_t)(AUDIO_SAMPLE_RATE_EXACT / freq);
        if (delayLen > 512) delayLen = 512;
        for (uint16_t i = 0; i < delayLen; i++) {
            _delayLine[i] = ((float)random(-32768, 32767)) / 32768.0f;
        }
        _delayWritePos = 0;
    }

    // Modal resonator: trigger exciter
    if (_engine == 12) {
        _pitchEnvLevel = 1.0f;
    }

    // Percussion engines: trigger envelope
    if (_engine >= 13 && _engine <= 15) {
        _pitchEnvLevel = 1.0f;
        _envLevel = 1.0f;
    }
}

void MultiEngine::noteOff() {
    _noteOn = false;
}

void MultiEngine::frequency(float hz) {
    _frequency = hz;
}

void MultiEngine::amplitude(float amp) {
    _amplitude = constrain(amp, 0.0f, 1.0f);
}

// ============================================================
// Engine 0 — Virtual Analog
// Two sawtooth oscillators with detune, pulse width, saw/PWM blend
// ============================================================
void MultiEngine::renderVirtualAnalog(int16_t *buf, int len) {
    float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float phaseInc2 = phaseInc * (1.0f + _timbre * 0.03f); // detune up to 30 cents
    float pw = 0.1f + _harmonics * 0.8f;
    float amp = _amplitude * _envLevel * 16000.0f;

    for (int i = 0; i < len; i++) {
        float saw1 = _phase * 2.0f - 1.0f;
        float saw2 = _phase2 * 2.0f - 1.0f;
        float pulse = (_phase < pw) ? 1.0f : -1.0f;
        float out = saw1 * (1.0f - _morph) + (saw2 + pulse) * 0.5f * _morph;
        buf[i] = (int16_t)(out * amp);
        _phase += phaseInc;
        if (_phase >= 1.0f) _phase -= 1.0f;
        _phase2 += phaseInc2;
        if (_phase2 >= 1.0f) _phase2 -= 1.0f;
    }
}

// ============================================================
// Engine 1 — Waveshaping
// Sine through wavefolder with pre-gain and blend
// ============================================================
void MultiEngine::renderWaveshaping(int16_t *buf, int len) {
    float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 16000.0f;
    float foldAmt = 1.0f + _timbre * 7.0f;
    float preGain = 1.0f + _harmonics * 3.0f;

    for (int i = 0; i < len; i++) {
        float sine = sinf(_phase * 2.0f * M_PI);
        float gained = sine * preGain;
        float folded = sinf(gained * foldAmt);
        float out = sine * (1.0f - _morph) + folded * _morph;
        buf[i] = (int16_t)(out * amp);
        _phase += phaseInc;
        if (_phase >= 1.0f) _phase -= 1.0f;
    }
}

// ============================================================
// Engine 2 — FM (2-operator)
// Timbre = mod index, Harmonics = ratio, Morph = feedback
// ============================================================
void MultiEngine::renderFM(int16_t *buf, int len) {
    static const float ratios[] = {0.5f, 1.0f, 1.5f, 2.0f, 3.0f, 4.0f, 5.0f, 7.0f};
    int ratioIdx = (int)(_harmonics * 7.99f);
    float ratio = ratios[ratioIdx];
    float modFreq = _frequency * ratio;
    float modIndex = _timbre * 8.0f;
    float carrierInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float modInc = modFreq / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 16000.0f;
    float feedback = _morph * 0.5f;
    static float prevMod = 0.0f;

    for (int i = 0; i < len; i++) {
        float mod = sinf((_modPhase + prevMod * feedback) * 2.0f * M_PI);
        prevMod = mod;
        float carrier = sinf((_phase + mod * modIndex) * 2.0f * M_PI);
        buf[i] = (int16_t)(carrier * amp);
        _phase += carrierInc;
        if (_phase >= 1.0f) _phase -= 1.0f;
        _modPhase += modInc;
        if (_modPhase >= 1.0f) _modPhase -= 1.0f;
    }
}

// ============================================================
// Engine 3 — Formant
// Pulse wave through 3 resonant bandpass filters at vowel freqs
// Timbre morphs between vowel sets, Harmonics shifts formants,
// Morph controls resonance/Q
// ============================================================
void MultiEngine::renderFormant(int16_t *buf, int len) {
    // Vowel formant frequencies (F1, F2, F3) for 5 vowels: a, e, i, o, u
    static const float vowelF1[5] = {800, 400, 350, 450, 325};
    static const float vowelF2[5] = {1150, 1600, 2100, 800, 700};
    static const float vowelF3[5] = {2800, 2700, 2700, 2830, 2530};

    // Interpolate between two vowels based on timbre (0-1 maps to 0-4 vowel index)
    float vowelPos = _timbre * 3.99f;
    int v0 = (int)vowelPos;
    int v1 = v0 + 1;
    if (v1 > 4) v1 = 4;
    float vFrac = vowelPos - v0;

    // Harmonics shifts formant center up/down (0.5-2.0x)
    float shift = 0.5f + _harmonics * 1.5f;

    float f1 = (vowelF1[v0] * (1.0f - vFrac) + vowelF1[v1] * vFrac) * shift;
    float f2 = (vowelF2[v0] * (1.0f - vFrac) + vowelF2[v1] * vFrac) * shift;
    float f3 = (vowelF3[v0] * (1.0f - vFrac) + vowelF3[v1] * vFrac) * shift;

    // Q from morph (2-20)
    float Q = 2.0f + _morph * 18.0f;

    // Compute biquad bandpass coefficients for each formant
    float formantFreqs[3] = {f1, f2, f3};
    float formantGains[3] = {1.0f, 0.7f, 0.4f}; // natural rolloff

    // Simplified 1-pole bandpass (state variable filter approach)
    float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 16000.0f;

    for (int i = 0; i < len; i++) {
        // Generate pulse/impulse train at fundamental frequency
        float pulse = (_phase < 0.1f) ? 1.0f : 0.0f;

        // Run through 3 parallel bandpass filters (simplified SVF)
        float sum = 0.0f;
        for (int f = 0; f < 3; f++) {
            float w = 2.0f * sinf(M_PI * formantFreqs[f] / AUDIO_SAMPLE_RATE_EXACT);
            float q = 1.0f / Q;
            // State variable filter bandpass
            float &bp = _formantBuf[f][0];
            float &lp = _formantBuf[f][1];
            float hp = pulse - lp - q * bp;
            bp += w * hp;
            lp += w * bp;
            sum += bp * formantGains[f];
        }

        buf[i] = (int16_t)(sum * amp);
        _phase += phaseInc;
        if (_phase >= 1.0f) _phase -= 1.0f;
    }
}

// ============================================================
// Engine 4 — Harmonic (Additive)
// 8 sine partials. Timbre = spectral tilt, Harmonics = even/odd,
// Morph = inharmonicity
// ============================================================
void MultiEngine::renderHarmonic(int16_t *buf, int len) {
    float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 2000.0f;

    for (int i = 0; i < len; i++) {
        float sum = 0;
        for (int h = 0; h < 8; h++) {
            float partialAmp = powf(1.0f - _timbre * 0.12f, h);
            // Even/odd balance: attenuate even harmonics (h=1,3,5,7 are even partials)
            if ((h % 2 == 1) && _harmonics < 0.5f) {
                partialAmp *= _harmonics * 2.0f;
            }
            // Inharmonicity from morph
            float pPhase = fmodf(_phase * (h + 1) * (1.0f + _morph * h * 0.01f), 1.0f);
            sum += sinf(pPhase * 2.0f * M_PI) * partialAmp;
        }
        buf[i] = (int16_t)(sum * amp);
        _phase += phaseInc;
        if (_phase >= 1.0f) _phase -= 1.0f;
    }
}

// ============================================================
// Engine 5 — Wavetable
// 4 waveforms with crossfade, fold, and phase distortion
// Timbre = table select/crossfade, Harmonics = fold,
// Morph = phase distortion
// ============================================================
void MultiEngine::renderWavetable(int16_t *buf, int len) {
    float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 16000.0f;

    // Timbre selects wavetable with crossfade (0-1 maps across 4 tables)
    float tablePos = _timbre * 2.99f;
    int t0 = (int)tablePos;
    int t1 = t0 + 1;
    if (t1 > 3) t1 = 3;
    float tFrac = tablePos - t0;

    float foldAmt = 1.0f + _harmonics * 4.0f;

    for (int i = 0; i < len; i++) {
        // Phase distortion from morph
        float distPhase = _phase;
        if (_morph > 0.01f) {
            // Simple phase distortion: skew the phase
            if (distPhase < 0.5f) {
                distPhase = distPhase * (1.0f + _morph) / (0.5f + _morph * 0.5f) * 0.5f;
            } else {
                distPhase = 0.5f + (distPhase - 0.5f) * (1.0f - _morph * 0.5f) / (0.5f) * 0.5f;
            }
            if (distPhase >= 1.0f) distPhase -= 1.0f;
            if (distPhase < 0.0f) distPhase = 0.0f;
        }

        // Read from wavetables with linear interpolation
        float fidx = distPhase * (float)WT_SIZE;
        int idx0 = (int)fidx;
        float frac = fidx - idx0;
        int idx1 = (idx0 + 1) & (WT_SIZE - 1);
        idx0 = idx0 & (WT_SIZE - 1);

        float s0 = wavetables[t0][idx0] * (1.0f - frac) + wavetables[t0][idx1] * frac;
        float s1 = wavetables[t1][idx0] * (1.0f - frac) + wavetables[t1][idx1] * frac;
        float sample = s0 * (1.0f - tFrac) + s1 * tFrac;

        // Apply wavefold from harmonics
        if (foldAmt > 1.01f) {
            sample = sinf(sample * foldAmt);
        }

        buf[i] = (int16_t)(sample * amp);
        _phase += phaseInc;
        if (_phase >= 1.0f) _phase -= 1.0f;
    }
}

// ============================================================
// Engine 6 — Chords
// 4-note chords using detuned saws. Timbre=chord type,
// Harmonics=inversion, Morph=saw/square crossfade
// ============================================================
void MultiEngine::renderChords(int16_t *buf, int len) {
    // 8 chord types: semitone offsets from root (root, 3rd, 5th, 7th/octave)
    static const float chordSemitones[8][4] = {
        {0, 4, 7, 12},   // Major
        {0, 3, 7, 12},   // Minor
        {0, 4, 7, 10},   // Dom7
        {0, 3, 7, 10},   // Min7
        {0, 3, 6, 12},   // Dim
        {0, 4, 8, 12},   // Aug
        {0, 5, 7, 12},   // Sus4
        {0, 2, 7, 12},   // Sus2
    };

    int chordIdx = (int)(_timbre * 7.99f);
    float amp = _amplitude * _envLevel * 4000.0f;

    // Compute note frequencies with inversion (harmonics shifts octave of lower notes)
    float noteFreqs[4];
    for (int n = 0; n < 4; n++) {
        float semi = chordSemitones[chordIdx][n];
        // Inversion: harmonics controls which notes get shifted up an octave
        int inversionLevel = (int)(_harmonics * 3.99f); // 0-3 inversions
        if (n < inversionLevel) semi += 12.0f;
        noteFreqs[n] = _frequency * powf(2.0f, semi / 12.0f);
    }

    for (int i = 0; i < len; i++) {
        float sum = 0.0f;
        for (int n = 0; n < 4; n++) {
            float phaseInc = noteFreqs[n] / AUDIO_SAMPLE_RATE_EXACT;
            float saw = _chordPhases[n] * 2.0f - 1.0f;
            float sq = (_chordPhases[n] < 0.5f) ? 1.0f : -1.0f;
            sum += saw * (1.0f - _morph) + sq * _morph;
            _chordPhases[n] += phaseInc;
            if (_chordPhases[n] >= 1.0f) _chordPhases[n] -= 1.0f;
        }
        buf[i] = (int16_t)(sum * amp);
    }
}

// ============================================================
// Engine 7 — Speech
// Vowel formant sweep with breathiness
// ============================================================
void MultiEngine::renderSpeech(int16_t *buf, int len) {
    // 5 vowels: A, E, I, O, U — each with 3 formant frequencies
    static const float vowelF1[5] = {800, 400, 350, 450, 325};
    static const float vowelF2[5] = {1150, 1600, 2100, 800, 700};
    static const float vowelF3[5] = {2800, 2700, 2700, 2830, 2530};

    // Timbre sweeps through 5 vowels
    float vowelPos = _timbre * 3.99f;
    int v0 = (int)vowelPos;
    int v1 = v0 + 1;
    if (v1 > 4) v1 = 4;
    float vFrac = vowelPos - v0;

    // Harmonics = pitch shift (0.5x to 2.0x)
    float pitchShift = 0.5f + _harmonics * 1.5f;

    float f1 = (vowelF1[v0] * (1.0f - vFrac) + vowelF1[v1] * vFrac);
    float f2 = (vowelF2[v0] * (1.0f - vFrac) + vowelF2[v1] * vFrac);
    float f3 = (vowelF3[v0] * (1.0f - vFrac) + vowelF3[v1] * vFrac);
    float formantFreqs[3] = {f1, f2, f3};
    float formantGains[3] = {1.0f, 0.7f, 0.4f};

    float phaseInc = _frequency * pitchShift / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 16000.0f;
    float Q = 8.0f; // fixed resonance for speech

    for (int i = 0; i < len; i++) {
        // Pulse train exciter
        float pulse = (_phase < 0.1f) ? 1.0f : 0.0f;
        // Add breathiness (noise mix from morph)
        float noise = ((float)random(-32768, 32767)) / 32768.0f;
        float exciter = pulse * (1.0f - _morph) + noise * _morph * 0.3f;

        float sum = 0.0f;
        for (int f = 0; f < 3; f++) {
            float w = 2.0f * sinf(M_PI * formantFreqs[f] / AUDIO_SAMPLE_RATE_EXACT);
            float q = 1.0f / Q;
            float &bp = _formantBuf[f][0];
            float &lp = _formantBuf[f][1];
            float hp = exciter - lp - q * bp;
            bp += w * hp;
            lp += w * bp;
            sum += bp * formantGains[f];
        }

        buf[i] = (int16_t)(sum * amp);
        _phase += phaseInc;
        if (_phase >= 1.0f) _phase -= 1.0f;
    }
}

// ============================================================
// Engine 8 — Granular Cloud
// 8 overlapping grains of short enveloped saws
// ============================================================
void MultiEngine::renderGranular(int16_t *buf, int len) {
    float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 4000.0f;
    // Timbre = density (rate of new grains): higher = more frequent triggers
    float density = 0.001f + _timbre * 0.05f;
    // Harmonics = pitch scatter amount
    float pitchScatter = _harmonics * 0.5f;
    // Morph = grain length (shorter to longer window)
    float grainLen = 0.01f + _morph * 0.15f; // phase units

    for (int i = 0; i < len; i++) {
        float sum = 0.0f;
        for (int g = 0; g < 8; g++) {
            if (_grainAmps[g] > 0.001f) {
                // Grain is active: generate enveloped saw
                float grainPhaseNorm = _grainPhases[g] / grainLen;
                if (grainPhaseNorm > 1.0f) {
                    _grainAmps[g] = 0.0f;
                    continue;
                }
                // Hanning-like window
                float window = sinf(grainPhaseNorm * M_PI);
                float saw = fmodf(_grainPhases[g] * (10.0f + g * 3.0f), 1.0f) * 2.0f - 1.0f;
                sum += saw * window * _grainAmps[g];
                _grainPhases[g] += phaseInc * (1.0f + pitchScatter * (g * 0.13f - 0.5f));
            } else {
                // Try to spawn a new grain
                float r = ((float)random(0, 10000)) / 10000.0f;
                if (r < density) {
                    _grainPhases[g] = 0.0f;
                    _grainAmps[g] = 0.5f + ((float)random(0, 5000)) / 10000.0f;
                }
            }
        }
        buf[i] = (int16_t)(sum * amp);
    }
}

// ============================================================
// Engine 9 — Filtered Noise
// White noise through state-variable filter
// Timbre = LP/BP/HP, Harmonics = cutoff, Morph = resonance
// ============================================================
void MultiEngine::renderFilteredNoise(int16_t *buf, int len) {
    float amp = _amplitude * _envLevel * 16000.0f;
    // Cutoff: 20Hz to 20kHz exponential mapping
    float cutoff = 20.0f * powf(1000.0f, _harmonics);
    float w = 2.0f * sinf(M_PI * cutoff / AUDIO_SAMPLE_RATE_EXACT);
    if (w > 0.99f) w = 0.99f;
    // Resonance: 0.5 to 20
    float Q = 0.5f + _morph * 19.5f;
    float q = 1.0f / Q;

    // Reuse formantBuf[0] for SVF state
    float &bp = _formantBuf[0][0];
    float &lp = _formantBuf[0][1];

    for (int i = 0; i < len; i++) {
        float noise = ((float)random(-32768, 32767)) / 32768.0f;
        float hp = noise - lp - q * bp;
        bp += w * hp;
        lp += w * bp;

        // Timbre selects output: 0=LP, 0.5=BP, 1.0=HP
        float out;
        if (_timbre < 0.5f) {
            float t = _timbre * 2.0f;
            out = lp * (1.0f - t) + bp * t;
        } else {
            float t = (_timbre - 0.5f) * 2.0f;
            out = bp * (1.0f - t) + hp * t;
        }

        buf[i] = (int16_t)(out * amp);
    }
}

// ============================================================
// Engine 10 — Particle Noise
// Random impulses through allpass filter chain
// Timbre = density, Harmonics = allpass freq, Morph = filter color
// ============================================================
void MultiEngine::renderParticle(int16_t *buf, int len) {
    float amp = _amplitude * _envLevel * 16000.0f;
    float density = 0.0005f + _timbre * 0.02f;
    float apFreq = 100.0f * powf(100.0f, _harmonics);
    float apCoeff = (1.0f - sinf(M_PI * apFreq / AUDIO_SAMPLE_RATE_EXACT));
    if (apCoeff > 0.99f) apCoeff = 0.99f;
    if (apCoeff < -0.99f) apCoeff = -0.99f;

    // Reuse modalStates for allpass state
    float &ap1_state = _modalStates[0][0];
    float &ap2_state = _modalStates[0][1];
    // Simple LP for color
    float &lpState = _modalStates[1][0];
    float colorMix = _morph; // 0 = allpass (bright), 1 = more LP (dark)

    for (int i = 0; i < len; i++) {
        // Random impulse
        float input = 0.0f;
        float r = ((float)random(0, 100000)) / 100000.0f;
        if (r < density) {
            input = ((float)random(-32768, 32767)) / 32768.0f;
        }

        // Allpass filter 1
        float ap1_out = -apCoeff * input + ap1_state;
        ap1_state = input + apCoeff * ap1_out;

        // Allpass filter 2
        float ap2_out = -apCoeff * ap1_out + ap2_state;
        ap2_state = ap1_out + apCoeff * ap2_out;

        // LP filter for color
        lpState += 0.1f * (ap2_out - lpState);
        float out = ap2_out * (1.0f - colorMix) + lpState * colorMix;

        buf[i] = (int16_t)(out * amp);
    }
}

// ============================================================
// Engine 11 — String (Karplus-Strong)
// Noise burst -> delay line with feedback + LP filter
// ============================================================
void MultiEngine::renderString(int16_t *buf, int len) {
    float amp = _amplitude * _envLevel * 16000.0f;
    uint16_t delayLen = (uint16_t)(AUDIO_SAMPLE_RATE_EXACT / _frequency);
    if (delayLen > 512) delayLen = 512;
    if (delayLen < 1) delayLen = 1;

    // Timbre = brightness (LP filter coefficient)
    float brightness = 0.2f + _timbre * 0.79f;
    // Morph = feedback/decay
    float feedback = 0.9f + _morph * 0.099f;
    // Harmonics = inharmonicity via allpass
    float apCoeff = _harmonics * 0.5f;

    float prevSample = _delayFeedback;

    for (int i = 0; i < len; i++) {
        // Read from delay line
        uint16_t readPos = (_delayWritePos + 512 - delayLen) & 511;
        float delayed = _delayLine[readPos];

        // 1-pole LP filter for brightness
        float filtered = delayed * brightness + prevSample * (1.0f - brightness);
        prevSample = filtered;

        // Allpass for inharmonicity
        float apOut = -apCoeff * filtered + _delayFeedback;
        _delayFeedback = filtered + apCoeff * apOut;
        float toWrite = apOut * feedback;

        // Write back to delay line
        _delayLine[_delayWritePos] = toWrite;
        _delayWritePos = (_delayWritePos + 1) & 511;

        buf[i] = (int16_t)(delayed * amp);
    }
}

// ============================================================
// Engine 12 — Modal Resonator
// Noise exciter -> bank of 4 resonant bandpass filters
// ============================================================
void MultiEngine::renderModal(int16_t *buf, int len) {
    float amp = _amplitude * _envLevel * 8000.0f;

    // Harmonic ratios (tuned) vs inharmonic (metallic)
    static const float harmonicRatios[4] = {1.0f, 2.0f, 3.0f, 4.0f};
    static const float inharmonicRatios[4] = {1.0f, 2.76f, 5.40f, 8.93f};

    // Harmonics morphs between harmonic and inharmonic
    float ratios[4];
    for (int r = 0; r < 4; r++) {
        ratios[r] = harmonicRatios[r] * (1.0f - _harmonics) + inharmonicRatios[r] * _harmonics;
        _modalFreqs[r] = _frequency * ratios[r];
    }

    // Morph = damping (lower = more damping)
    float damping = 0.9990f + _morph * 0.0009f;

    // Timbre = exciter brightness
    float exciterBright = 0.3f + _timbre * 0.7f;

    // Decay exciter level
    float exciterDecay = 0.995f;

    for (int i = 0; i < len; i++) {
        // Exciter: short noise burst (controlled by _pitchEnvLevel)
        float exciter = 0.0f;
        if (_pitchEnvLevel > 0.001f) {
            float noise = ((float)random(-32768, 32767)) / 32768.0f;
            exciter = noise * _pitchEnvLevel * exciterBright;
            _pitchEnvLevel *= exciterDecay;
        }

        // 4 parallel resonators (SVF bandpass)
        float sum = 0.0f;
        for (int r = 0; r < 4; r++) {
            float w = 2.0f * sinf(M_PI * _modalFreqs[r] / AUDIO_SAMPLE_RATE_EXACT);
            if (w > 0.99f) w = 0.99f;
            float q = 1.0f - (1.0f - damping) * (r + 1); // higher partials damp faster
            if (q < 0.9f) q = 0.9f;
            float qInv = 1.0f - q;

            float &bp = _modalStates[r][0];
            float &lp = _modalStates[r][1];
            float hp = exciter - lp - qInv * bp;
            bp += w * hp;
            bp *= damping;
            lp += w * bp;

            float partialAmp = 1.0f / (r + 1); // natural rolloff
            sum += bp * partialAmp;
        }

        buf[i] = (int16_t)(sum * amp);
    }
}

// ============================================================
// Engine 13 — Analog Bass Drum
// Sine with pitch sweep + distortion
// ============================================================
void MultiEngine::renderBassDrum(int16_t *buf, int len) {
    float amp = _amplitude * 16000.0f;

    // Morph = decay time
    float decayRate = 0.9990f + _morph * 0.0009f;
    // Harmonics = pitch env amount + drive
    float pitchEnvAmt = 1.0f + _harmonics * 7.0f; // 1x to 8x
    float drive = 1.0f + _harmonics * 4.0f;
    // Timbre = tone brightness (LP filter)
    float toneBright = 0.3f + _timbre * 0.7f;

    float pitchDecay = 0.997f - _morph * 0.002f;
    float prevOut = _delayFeedback; // reuse for LP state

    for (int i = 0; i < len; i++) {
        // Pitch envelope
        float currentFreq = _frequency * (1.0f + (_pitchEnvLevel * pitchEnvAmt));
        _pitchEnvLevel *= pitchDecay;

        float phaseInc = currentFreq / AUDIO_SAMPLE_RATE_EXACT;
        _phase += phaseInc;
        if (_phase >= 1.0f) _phase -= 1.0f;

        float sine = sinf(_phase * 2.0f * M_PI);

        // Distortion
        float driven = sine * drive;
        float distorted = tanhf(driven);

        // Simple LP for tone
        float out = distorted * toneBright + prevOut * (1.0f - toneBright);
        prevOut = out;

        // Amplitude envelope
        _envLevel *= decayRate;
        buf[i] = (int16_t)(out * _envLevel * amp);
    }
    _delayFeedback = prevOut;
}

// ============================================================
// Engine 14 — Analog Snare
// Dual sine tones + filtered noise
// ============================================================
void MultiEngine::renderSnare(int16_t *buf, int len) {
    float amp = _amplitude * 16000.0f;

    // Morph = decay time
    float decayRate = 0.9985f + _morph * 0.001f;
    // Timbre = tone/noise balance (0 = all tone, 1 = all noise)
    float noiseMix = _timbre;
    // Harmonics = tone frequency scaling
    float toneScale = 0.5f + _harmonics * 1.5f;
    float freq1 = 200.0f * toneScale;
    float freq2 = 350.0f * toneScale;

    float phaseInc1 = freq1 / AUDIO_SAMPLE_RATE_EXACT;
    float phaseInc2 = freq2 / AUDIO_SAMPLE_RATE_EXACT;

    // Noise BP filter state (reuse formantBuf)
    float &bp = _formantBuf[0][0];
    float &lp = _formantBuf[0][1];
    float w = 2.0f * sinf(M_PI * 3000.0f / AUDIO_SAMPLE_RATE_EXACT); // noise BP at 3kHz
    float q = 0.3f;

    for (int i = 0; i < len; i++) {
        // Two sine tones
        float tone = sinf(_phase * 2.0f * M_PI) * 0.6f + sinf(_phase2 * 2.0f * M_PI) * 0.4f;

        // Filtered noise
        float noise = ((float)random(-32768, 32767)) / 32768.0f;
        float hp = noise - lp - q * bp;
        bp += w * hp;
        lp += w * bp;
        float filteredNoise = bp;

        // Mix tone and noise
        float out = tone * (1.0f - noiseMix) + filteredNoise * noiseMix;

        _envLevel *= decayRate;
        buf[i] = (int16_t)(out * _envLevel * amp);

        _phase += phaseInc1;
        if (_phase >= 1.0f) _phase -= 1.0f;
        _phase2 += phaseInc2;
        if (_phase2 >= 1.0f) _phase2 -= 1.0f;
    }
}

// ============================================================
// Engine 15 — Analog Hi-Hat
// Multiple square oscillators + HP filtered noise
// ============================================================
void MultiEngine::renderHiHat(int16_t *buf, int len) {
    float amp = _amplitude * 12000.0f;

    // Morph = decay time
    float decayRate = 0.9970f + _morph * 0.002f;
    // Timbre = metal/noise balance
    float metalMix = 1.0f - _timbre; // 0 = noise, 1 = metallic
    // Harmonics = HP cutoff
    float hpCutoff = 2000.0f + _harmonics * 12000.0f;
    float hpW = 2.0f * sinf(M_PI * hpCutoff / AUDIO_SAMPLE_RATE_EXACT);
    if (hpW > 0.99f) hpW = 0.99f;

    // Metallic ratios x base 400Hz
    static const float metalRatios[6] = {1.0f, 1.4f, 1.7f, 2.0f, 2.4f, 2.9f};
    float baseFreq = 400.0f;

    // HP filter state (reuse formantBuf)
    float &hpBp = _formantBuf[1][0];
    float &hpLp = _formantBuf[1][1];

    for (int i = 0; i < len; i++) {
        // 6 square oscillators at metallic ratios
        float metallic = 0.0f;
        // Use _phase as master phase, derive others
        for (int s = 0; s < 6; s++) {
            float freq = baseFreq * metalRatios[s];
            float p = fmodf(_phase * freq / baseFreq, 1.0f);
            metallic += (p < 0.5f) ? 1.0f : -1.0f;
        }
        metallic /= 6.0f;

        // Noise component
        float noise = ((float)random(-32768, 32767)) / 32768.0f;

        // Mix metal and noise
        float mixed = metallic * metalMix + noise * (1.0f - metalMix);

        // HP filter (SVF)
        float hp = mixed - hpLp - 0.5f * hpBp;
        hpBp += hpW * hp;
        hpLp += hpW * hpBp;
        float out = hp;

        _envLevel *= decayRate;
        buf[i] = (int16_t)(out * _envLevel * amp);

        _phase += baseFreq / AUDIO_SAMPLE_RATE_EXACT;
        if (_phase >= 1.0f) _phase -= 1.0f;
    }
}

// ============================================================
// Engine 16 — Classic Waveshapes + Filter (VCF)
// Saw/square/tri through resonant SVF
// ============================================================
void MultiEngine::renderVCF(int16_t *buf, int len) {
    float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 16000.0f;

    // Cutoff: 20Hz-20kHz exponential
    float cutoff = 20.0f * powf(1000.0f, _timbre);
    float f = 2.0f * sinf(M_PI * cutoff / AUDIO_SAMPLE_RATE_EXACT);
    if (f > 0.99f) f = 0.99f;
    // Resonance: 0.5-20
    float q = 0.5f + _harmonics * 19.5f;
    float fb = 1.0f / q;

    for (int i = 0; i < len; i++) {
        // Generate waveform based on morph
        float waveform;
        if (_morph < 0.33f) {
            // Sawtooth
            waveform = _phase * 2.0f - 1.0f;
        } else if (_morph < 0.66f) {
            // Square
            waveform = (_phase < 0.5f) ? 1.0f : -1.0f;
        } else {
            // Triangle
            waveform = (_phase < 0.5f) ? (4.0f * _phase - 1.0f) : (3.0f - 4.0f * _phase);
        }

        // SVF filter
        float hp = waveform - _svfState[1] - _svfState[0] * fb;
        _svfState[0] += f * hp;  // bandpass
        _svfState[1] += f * _svfState[0];  // lowpass
        float out = _svfState[1]; // LP output

        buf[i] = (int16_t)(out * amp);
        _phase += phaseInc;
        if (_phase >= 1.0f) _phase -= 1.0f;
    }
}

// ============================================================
// Engine 17 — Phase Distortion
// CZ-style sine with phase distortion
// ============================================================
void MultiEngine::renderPhaseDist(int16_t *buf, int len) {
    float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 16000.0f;
    float distAmt = _timbre * 4.0f;

    for (int i = 0; i < len; i++) {
        float phase = _phase;

        // Select distortion type based on harmonics
        if (_harmonics < 0.33f) {
            // Cosine warp
            phase = phase + distAmt * sinf(phase * 2.0f * M_PI) / (2.0f * M_PI);
        } else if (_harmonics < 0.66f) {
            // Window function
            phase = powf(phase, 1.0f + distAmt * 2.0f);
        } else {
            // Half-sine rectification
            float s = sinf(phase * M_PI);
            phase = phase * (1.0f - _timbre) + fabsf(s) * _timbre;
        }

        // Morph adds additional modulation depth
        float modDepth = _morph * 0.5f;
        phase = phase * (1.0f - modDepth) + phase * phase * modDepth;

        float out = sinf(phase * 2.0f * M_PI);
        buf[i] = (int16_t)(out * amp);
        _phase += phaseInc;
        if (_phase >= 1.0f) _phase -= 1.0f;
    }
}

// ============================================================
// DX7 .syx patch loading
// ============================================================
void MultiEngine::loadDX7Patch(const uint8_t* syxData, int patchIndex) {
    // syxData points to the start of the .syx bulk dump (4104 bytes)
    // Skip 6-byte SysEx header, then 128 bytes per patch
    if (patchIndex < 0 || patchIndex > 31) return;
    const uint8_t* patch = syxData + 6 + patchIndex * 128;

    // Parse 6 operators (packed format: 17 bytes per op)
    // DX7 bulk format: OP6=bytes 0-16, OP5=17-33, OP4=34-50,
    //                  OP3=51-67, OP2=68-84, OP1=85-101
    // We store in our array: ops[0]=OP1, ops[1]=OP2, ..., ops[5]=OP6
    for (int op = 0; op < 6; op++) {
        int sysexOp = 5 - op;  // OP6 first in sysex, OP1 last
        const uint8_t* opData = patch + sysexOp * 17;

        _dx7Patch.ops[op].level = opData[14];  // Output Level 0-99

        uint8_t mode = opData[15] & 0x01;      // 0=ratio, 1=fixed
        uint8_t coarse = (opData[15] >> 1) & 0x1F;
        uint8_t fine = opData[16];              // 0-99

        _dx7Patch.ops[op].fixedFreq = (mode == 1);

        if (mode == 0) {
            // Ratio mode: coarse 0 = 0.5, 1=1, 2=2, etc.
            float ratio = (coarse == 0) ? 0.5f : (float)coarse;
            ratio += fine / 100.0f;
            _dx7Patch.ops[op].freqRatio = ratio;
        } else {
            // Fixed frequency mode: compute fixed Hz
            // coarse selects decade (0=1Hz, 1=10Hz, 2=100Hz, 3=1000Hz)
            float baseFreq = 1.0f;
            if (coarse == 1) baseFreq = 10.0f;
            else if (coarse == 2) baseFreq = 100.0f;
            else if (coarse >= 3) baseFreq = 1000.0f;
            _dx7Patch.ops[op].freqRatio = baseFreq * (1.0f + fine / 100.0f);
        }

        // Detune: bits 3-6 of byte 12, range 0-14 mapped to -7..+7
        _dx7Patch.ops[op].detune = (int8_t)((opData[12] >> 3) & 0x0F) - 7;
    }

    // Algorithm (byte 110, bits 0-4) and feedback (byte 111, bits 3-5)
    _dx7Patch.algorithm = patch[110] & 0x1F;
    _dx7Patch.feedback = (patch[111] >> 3) & 0x07;

    _dx7Loaded = true;
}

void MultiEngine::clearDX7Patch() {
    memset(&_dx7Patch, 0, sizeof(_dx7Patch));
    _dx7Loaded = false;
}

// ============================================================
// 6-OP FM shared data
// ============================================================
static const float fmRatios[6][6] = {
    {1,2,3,4,5,6}, {1,1,2,3,4,7}, {0.5f,1,1.5f,2,3,5},
    {1,2,4,6,8,10}, {1,1.41f,2,2.82f,4,5.65f}, {1,3,5,7,9,11}
};

// ============================================================
// Engine 18 — 6-OP FM A
// Ops 1,2,3 modulate op 4 (carrier). Ops 5,6 modulate op 1.
// ============================================================
void MultiEngine::renderFMA(int16_t *buf, int len) {
    float amp = _amplitude * _envLevel * 16000.0f;
    int ratioSet = (int)(_harmonics * 5.99f);
    float modIndex = _timbre * 8.0f;
    float feedback = _morph * 0.5f;
    static float prevOp6 = 0.0f;

    // DX7 patch: use operator levels as amplitude scaling, ratios from patch
    float opLevel[6];
    float opRatio[6];
    if (_dx7Loaded) {
        for (int o = 0; o < 6; o++) {
            opLevel[o] = _dx7Patch.ops[o].level / 99.0f;
            opRatio[o] = _dx7Patch.ops[o].fixedFreq
                ? _dx7Patch.ops[o].freqRatio / _frequency  // fixed: convert Hz to ratio
                : _dx7Patch.ops[o].freqRatio;
        }
        feedback = (_dx7Patch.feedback / 7.0f) * 0.5f;
        modIndex = _timbre * 8.0f;  // timbre still controls mod depth
    } else {
        for (int o = 0; o < 6; o++) {
            opLevel[o] = 1.0f;
            opRatio[o] = fmRatios[ratioSet][o];
        }
    }

    for (int i = 0; i < len; i++) {
        float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;

        // Op 6 with feedback -> Op 1
        float op6 = sinf((_fmOpPhases[5] + prevOp6 * feedback) * 2.0f * M_PI) * opLevel[5];
        prevOp6 = op6;
        float op5 = sinf(_fmOpPhases[4] * 2.0f * M_PI) * opLevel[4];

        // Op 1 modulated by ops 5,6
        float op1 = sinf((_fmOpPhases[0] + (op5 + op6) * modIndex * 0.5f) * 2.0f * M_PI) * opLevel[0];
        float op2 = sinf(_fmOpPhases[1] * 2.0f * M_PI) * opLevel[1];
        float op3 = sinf(_fmOpPhases[2] * 2.0f * M_PI) * opLevel[2];

        // Op 4 (carrier) modulated by ops 1,2,3
        float mod = (op1 + op2 + op3) * modIndex / 3.0f;
        float carrier = sinf((_fmOpPhases[3] + mod) * 2.0f * M_PI) * opLevel[3];

        buf[i] = (int16_t)(carrier * amp);

        for (int o = 0; o < 6; o++) {
            _fmOpPhases[o] += phaseInc * opRatio[o];
            if (_fmOpPhases[o] >= 1.0f) _fmOpPhases[o] -= 1.0f;
        }
    }
}

// ============================================================
// Engine 19 — 6-OP FM B
// Two stacked pairs: (ops 1->2->3) + (ops 4->5->6), summed
// ============================================================
void MultiEngine::renderFMB(int16_t *buf, int len) {
    float amp = _amplitude * _envLevel * 16000.0f;
    int ratioSet = (int)(_harmonics * 5.99f);
    float modIndex = _timbre * 8.0f;
    float feedback = _morph * 0.5f;
    static float prevOp3 = 0.0f;

    float opLevel[6];
    float opRatio[6];
    if (_dx7Loaded) {
        for (int o = 0; o < 6; o++) {
            opLevel[o] = _dx7Patch.ops[o].level / 99.0f;
            opRatio[o] = _dx7Patch.ops[o].fixedFreq
                ? _dx7Patch.ops[o].freqRatio / _frequency
                : _dx7Patch.ops[o].freqRatio;
        }
        feedback = (_dx7Patch.feedback / 7.0f) * 0.5f;
    } else {
        for (int o = 0; o < 6; o++) {
            opLevel[o] = 1.0f;
            opRatio[o] = fmRatios[ratioSet][o];
        }
    }

    for (int i = 0; i < len; i++) {
        float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;

        // Stack 1: op1 -> op2 -> op3 (with feedback on op3)
        float op1 = sinf(_fmOpPhases[0] * 2.0f * M_PI) * opLevel[0];
        float op2 = sinf((_fmOpPhases[1] + op1 * modIndex) * 2.0f * M_PI) * opLevel[1];
        float op3 = sinf((_fmOpPhases[2] + op2 * modIndex + prevOp3 * feedback) * 2.0f * M_PI) * opLevel[2];
        prevOp3 = op3;

        // Stack 2: op4 -> op5 -> op6
        float op4 = sinf(_fmOpPhases[3] * 2.0f * M_PI) * opLevel[3];
        float op5 = sinf((_fmOpPhases[4] + op4 * modIndex) * 2.0f * M_PI) * opLevel[4];
        float op6 = sinf((_fmOpPhases[5] + op5 * modIndex) * 2.0f * M_PI) * opLevel[5];

        float out = (op3 + op6) * 0.5f;
        buf[i] = (int16_t)(out * amp);

        for (int o = 0; o < 6; o++) {
            _fmOpPhases[o] += phaseInc * opRatio[o];
            if (_fmOpPhases[o] >= 1.0f) _fmOpPhases[o] -= 1.0f;
        }
    }
}

// ============================================================
// Engine 20 — 6-OP FM C
// Cascade chain: op1->op2->op3->op4->op5->op6 (output)
// ============================================================
void MultiEngine::renderFMC(int16_t *buf, int len) {
    float amp = _amplitude * _envLevel * 16000.0f;
    int ratioSet = (int)(_harmonics * 5.99f);
    float modIndex = _timbre * 8.0f;
    float feedback = _morph * 0.5f;
    static float prevOp1 = 0.0f;

    float opLevel[6];
    float opRatio[6];
    if (_dx7Loaded) {
        for (int o = 0; o < 6; o++) {
            opLevel[o] = _dx7Patch.ops[o].level / 99.0f;
            opRatio[o] = _dx7Patch.ops[o].fixedFreq
                ? _dx7Patch.ops[o].freqRatio / _frequency
                : _dx7Patch.ops[o].freqRatio;
        }
        feedback = (_dx7Patch.feedback / 7.0f) * 0.5f;
    } else {
        for (int o = 0; o < 6; o++) {
            opLevel[o] = 1.0f;
            opRatio[o] = fmRatios[ratioSet][o];
        }
    }

    for (int i = 0; i < len; i++) {
        float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;

        // Cascade: each op modulates the next
        float op1 = sinf((_fmOpPhases[0] + prevOp1 * feedback) * 2.0f * M_PI) * opLevel[0];
        prevOp1 = op1;
        float op2 = sinf((_fmOpPhases[1] + op1 * modIndex) * 2.0f * M_PI) * opLevel[1];
        float op3 = sinf((_fmOpPhases[2] + op2 * modIndex) * 2.0f * M_PI) * opLevel[2];
        float op4 = sinf((_fmOpPhases[3] + op3 * modIndex) * 2.0f * M_PI) * opLevel[3];
        float op5 = sinf((_fmOpPhases[4] + op4 * modIndex) * 2.0f * M_PI) * opLevel[4];
        float op6 = sinf((_fmOpPhases[5] + op5 * modIndex) * 2.0f * M_PI) * opLevel[5];

        buf[i] = (int16_t)(op6 * amp);

        for (int o = 0; o < 6; o++) {
            _fmOpPhases[o] += phaseInc * opRatio[o];
            if (_fmOpPhases[o] >= 1.0f) _fmOpPhases[o] -= 1.0f;
        }
    }
}

// ============================================================
// Engine 21 — Wave Terrain
// 2D wavetable lookup: x=phase, y=secondary osc
// ============================================================
void MultiEngine::renderWaveTerrain(int16_t *buf, int len) {
    float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 16000.0f;

    // Y-axis frequency ratio from harmonics
    float yRatio = 0.5f + _harmonics * 7.5f; // 0.5 to 8.0
    float yPhaseInc = phaseInc * yRatio;
    float terrainWarp = _timbre * 4.0f;
    float terrainDepth = _morph;

    for (int i = 0; i < len; i++) {
        float x = sinf(_phase * 2.0f * M_PI);
        float y = sinf(_phase2 * 2.0f * M_PI + terrainWarp * x);

        // Terrain output: blend of x*y interaction
        float terrain = x * (1.0f - terrainDepth) + x * y * terrainDepth;

        buf[i] = (int16_t)(terrain * amp);
        _phase += phaseInc;
        if (_phase >= 1.0f) _phase -= 1.0f;
        _phase2 += yPhaseInc;
        if (_phase2 >= 1.0f) _phase2 -= 1.0f;
    }
}

// ============================================================
// Engine 22 — String Machine
// 8 detuned saws through chorus effect
// ============================================================
void MultiEngine::renderStringMachine(int16_t *buf, int len) {
    float phaseInc = _frequency / AUDIO_SAMPLE_RATE_EXACT;
    float amp = _amplitude * _envLevel * 4000.0f; // lower per-voice, 8 voices
    // Timbre = detune spread (0-30 cents across 8 voices)
    float detuneCents = _timbre * 30.0f;
    float detuneRatio = powf(2.0f, detuneCents / 1200.0f) - 1.0f;
    // Harmonics = chorus LFO rate
    float chorusRate = 0.1f + _harmonics * 5.0f; // 0.1-5.1 Hz
    float chorusInc = chorusRate / AUDIO_SAMPLE_RATE_EXACT;
    // Morph = chorus depth
    float chorusDepth = _morph * 0.003f;

    for (int i = 0; i < len; i++) {
        float chorusMod = sinf(_chorusPhase * 2.0f * M_PI) * chorusDepth;
        float sum = 0.0f;

        for (int v = 0; v < 8; v++) {
            // Spread detune: voices spread from -detuneRatio to +detuneRatio
            float spread = ((float)v / 7.0f) * 2.0f - 1.0f; // -1 to +1
            float voiceInc = phaseInc * (1.0f + spread * detuneRatio + chorusMod * spread);

            // Use _grainPhases for the 8 saw voice phases
            float saw = _grainPhases[v] * 2.0f - 1.0f;
            sum += saw;

            _grainPhases[v] += voiceInc;
            if (_grainPhases[v] >= 1.0f) _grainPhases[v] -= 1.0f;
            if (_grainPhases[v] < 0.0f) _grainPhases[v] += 1.0f;
        }

        buf[i] = (int16_t)(sum * amp / 8.0f * 8.0f); // normalize
        _chorusPhase += chorusInc;
        if (_chorusPhase >= 1.0f) _chorusPhase -= 1.0f;
    }
}

// ============================================================
// Engine 23 — Chiptune
// 4 square oscillators with PWM, chord patterns, arp
// ============================================================
void MultiEngine::renderChiptune(int16_t *buf, int len) {
    float amp = _amplitude * _envLevel * 8000.0f;

    // 8 chord patterns: intervals in semitones from root
    static const float chordPatterns[8][4] = {
        {0,0,0,0},       // unison
        {0,12,0,12},     // octave
        {0,7,12,19},     // power 5th
        {0,4,7,12},      // major
        {0,3,7,12},      // minor
        {0,4,7,10},      // 7th
        {0,3,6,9},       // diminished
        {0,1,2,3}         // chromatic cluster
    };

    int chordIdx = (int)(_harmonics * 7.99f);
    float pw = 0.1f + _timbre * 0.8f; // PWM

    // Arp: morph controls arp speed (0=no arp, all voices; 1=fast arp)
    float arpRate = _morph * 20.0f; // Hz
    float arpPhaseInc = arpRate / AUDIO_SAMPLE_RATE_EXACT;

    for (int i = 0; i < len; i++) {
        float sum = 0.0f;

        // Determine which voices are active based on arp
        int activeVoice = -1; // -1 means all active
        if (_morph > 0.05f) {
            activeVoice = ((int)(_modPhase * 4.0f)) % 4;
        }

        for (int v = 0; v < 4; v++) {
            if (activeVoice >= 0 && v != activeVoice) continue;

            float semitones = chordPatterns[chordIdx][v];
            float voiceFreq = _frequency * powf(2.0f, semitones / 12.0f);
            float voiceInc = voiceFreq / AUDIO_SAMPLE_RATE_EXACT;

            // Square with PWM
            float square = (_chipPhases[v] < pw) ? 1.0f : -1.0f;
            sum += square;

            _chipPhases[v] += voiceInc;
            if (_chipPhases[v] >= 1.0f) _chipPhases[v] -= 1.0f;
        }

        float voices = (activeVoice >= 0) ? 1.0f : 4.0f;
        buf[i] = (int16_t)(sum / voices * amp);

        _modPhase += arpPhaseInc;
        if (_modPhase >= 1.0f) _modPhase -= 1.0f;
    }
}

// ============================================================
// update() — called by AudioStream at ~44100/128 = ~345 Hz
// ============================================================
void MultiEngine::update() {
    if (!_active && _envLevel < 0.001f) return;

    audio_block_t *block = allocate();
    if (!block) return;

    // Simple AR envelope (computed per-block for efficiency)
    // Percussion engines (13-15) manage their own envelope in render
    if (_engine < 13 || _engine >= 16) {
        for (int i = 0; i < AUDIO_BLOCK_SAMPLES; i++) {
            if (_noteOn && _envLevel < 1.0f) {
                _envLevel += 0.002f; // ~5ms attack
                if (_envLevel > 1.0f) _envLevel = 1.0f;
            } else if (!_noteOn && _envLevel > 0.0f) {
                _envLevel -= 0.0005f; // ~250ms release
                if (_envLevel < 0.0f) _envLevel = 0.0f;
            }
        }
    }
    if (_envLevel < 0.001f && !_noteOn) { _active = false; }

    switch (_engine) {
        case 0:  renderVirtualAnalog(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 1:  renderWaveshaping(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 2:  renderFM(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 3:  renderFormant(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 4:  renderHarmonic(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 5:  renderWavetable(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 6:  renderChords(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 7:  renderSpeech(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 8:  renderGranular(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 9:  renderFilteredNoise(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 10: renderParticle(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 11: renderString(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 12: renderModal(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 13: renderBassDrum(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 14: renderSnare(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 15: renderHiHat(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 16: renderVCF(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 17: renderPhaseDist(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 18: renderFMA(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 19: renderFMB(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 20: renderFMC(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 21: renderWaveTerrain(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 22: renderStringMachine(block->data, AUDIO_BLOCK_SAMPLES); break;
        case 23: renderChiptune(block->data, AUDIO_BLOCK_SAMPLES); break;
        default: memset(block->data, 0, AUDIO_BLOCK_SAMPLES * 2); break;
    }

    transmit(block, 0);
    release(block);
}
