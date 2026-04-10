#ifndef MULTI_ENGINE_H
#define MULTI_ENGINE_H
#include <Arduino.h>
#include <AudioStream.h>

// DX7 patch data (simplified — store key parameters per operator)
struct DX7Patch {
    uint8_t algorithm;           // 0-31 (routing topology, DX7 algorithms 1-32)
    uint8_t feedback;            // 0-7
    struct {
        uint8_t level;           // 0-99 (operator output level)
        float freqRatio;         // computed from coarse/fine settings
        bool fixedFreq;          // fixed vs ratio mode
        int8_t detune;           // -7 to +7
    } ops[6];
};

class MultiEngine : public AudioStream {
public:
    MultiEngine();
    virtual void update();

    void setEngine(uint8_t engine);  // 0-23
    void setTimbre(float v);         // 0.0-1.0
    void setHarmonics(float v);      // 0.0-1.0
    void setMorph(float v);          // 0.0-1.0
    void noteOn(float frequency, float amplitude);
    void noteOff();
    void frequency(float hz);
    void amplitude(float amp);
    uint8_t getEngine() const { return _engine; }
    float getTimbre() const { return _timbre; }
    float getHarmonics() const { return _harmonics; }
    float getMorph() const { return _morph; }

    void loadDX7Patch(const uint8_t* patchData, int patchIndex); // patchIndex 0-31
    void clearDX7Patch();
    bool isDX7Loaded() const { return _dx7Loaded; }
    const DX7Patch& getDX7Patch() const { return _dx7Patch; }

private:
    audio_block_t *inputQueueArray[1]; // AudioStream requires at least [1]
    uint8_t _engine;
    float _frequency, _amplitude, _timbre, _harmonics, _morph;
    float _phase, _phase2, _modPhase;
    bool _active, _noteOn;
    float _envLevel;

    // Formant filter state
    float _formantBuf[3][2]; // 3 bandpass filters, each with 2 state variables

    // Chords state
    float _chordPhases[4];

    // Granular state
    float _grainPhases[8];
    float _grainAmps[8];

    // String (Karplus-Strong) state
    float _delayLine[512];
    uint16_t _delayWritePos;
    float _delayFeedback;

    // Modal resonator state
    float _modalFreqs[4];
    float _modalStates[4][2]; // 4 resonators, each with 2 state vars

    // Percussion pitch envelope
    float _pitchEnvLevel;

    // VCF (Engine 16) filter state
    float _svfState[2]; // LP state, BP state

    // 6-op FM (Engines 18-20) operator phases
    float _fmOpPhases[6];

    // DX7 patch state
    DX7Patch _dx7Patch;
    bool _dx7Loaded;

    // String Machine (Engine 22) chorus phase
    float _chorusPhase;

    // Chiptune (Engine 23) 4 square voice phases
    float _chipPhases[4];

    void renderVirtualAnalog(int16_t *buf, int len);
    void renderWaveshaping(int16_t *buf, int len);
    void renderFM(int16_t *buf, int len);
    void renderFormant(int16_t *buf, int len);
    void renderHarmonic(int16_t *buf, int len);
    void renderWavetable(int16_t *buf, int len);
    void renderChords(int16_t *buf, int len);
    void renderSpeech(int16_t *buf, int len);
    void renderGranular(int16_t *buf, int len);
    void renderFilteredNoise(int16_t *buf, int len);
    void renderParticle(int16_t *buf, int len);
    void renderString(int16_t *buf, int len);
    void renderModal(int16_t *buf, int len);
    void renderBassDrum(int16_t *buf, int len);
    void renderSnare(int16_t *buf, int len);
    void renderHiHat(int16_t *buf, int len);
    void renderVCF(int16_t *buf, int len);
    void renderPhaseDist(int16_t *buf, int len);
    void renderFMA(int16_t *buf, int len);
    void renderFMB(int16_t *buf, int len);
    void renderFMC(int16_t *buf, int len);
    void renderWaveTerrain(int16_t *buf, int len);
    void renderStringMachine(int16_t *buf, int len);
    void renderChiptune(int16_t *buf, int len);
};
#endif
