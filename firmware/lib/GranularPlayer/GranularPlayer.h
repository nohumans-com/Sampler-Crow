#ifndef GRANULAR_PLAYER_H
#define GRANULAR_PLAYER_H
#include <Arduino.h>
#include <AudioStream.h>
#include <SD.h>

#define MAX_GRAINS 16
#define GRAIN_BUFFER_SAMPLES 4096  // ~93ms at 44.1kHz (8KB per player, fits in RAM)

struct Grain {
    float position;
    float rate;
    float phase;
    float phaseInc;
    int32_t startSample;
    int32_t lengthSamples;
    float amplitude;
    bool active;
};

struct GrainParams {
    float windowPosition;  // 0-1
    float windowSize;      // 0-1
    float grainSizeMs;     // 10-500
    uint8_t grainCount;    // 1-16
    float pitch;           // rate multiplier
    float spread;          // 0-1
    uint8_t envelopeShape; // 0-3
    float gain;            // 0-1
};

class GranularPlayer : public AudioStream {
public:
    GranularPlayer();
    virtual void update();
    void setParams(const GrainParams& p);
    bool loadFromFile(const char* path, uint32_t startSample, uint32_t endSample);
    void noteOn(float velocity);
    void noteOff();
    bool isActive() const { return _active; }
private:
    int16_t _buffer[GRAIN_BUFFER_SAMPLES];
    uint32_t _bufferLength;
    Grain _grains[MAX_GRAINS];
    GrainParams _params;
    bool _active;
    float _velocity;
    uint32_t _sampleCounter;
    uint32_t _spawnInterval;

    void spawnGrain(int index);
    float applyEnvelope(float phase, uint8_t shape);
    int16_t interpolate(float pos);
};
#endif
