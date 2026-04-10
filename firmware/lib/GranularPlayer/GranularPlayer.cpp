#include "GranularPlayer.h"
#include <math.h>

GranularPlayer::GranularPlayer() : AudioStream(0, NULL) {
    memset(_buffer, 0, sizeof(_buffer));
    _bufferLength = 0;
    memset(_grains, 0, sizeof(_grains));
    memset(&_params, 0, sizeof(_params));
    _params.windowPosition = 0.5f;
    _params.windowSize = 0.3f;
    _params.grainSizeMs = 100.0f;
    _params.grainCount = 4;
    _params.pitch = 1.0f;
    _params.spread = 0.5f;
    _params.envelopeShape = 0;
    _params.gain = 1.0f;
    _active = false;
    _velocity = 0.0f;
    _sampleCounter = 0;
    _spawnInterval = 0;
}

bool GranularPlayer::loadFromFile(const char* path, uint32_t startSample, uint32_t endSample) {
    File f = SD.open(path);
    if (!f) return false;

    // Skip WAV header
    f.seek(44);
    uint32_t totalFileSamples = (f.size() - 44) / 2; // 16-bit mono

    if (startSample >= totalFileSamples) { f.close(); return false; }
    if (endSample == 0 || endSample > totalFileSamples) endSample = totalFileSamples;
    if (startSample >= endSample) { f.close(); return false; }

    uint32_t regionLength = endSample - startSample;
    uint32_t samplesToRead = (regionLength < GRAIN_BUFFER_SAMPLES) ? regionLength : GRAIN_BUFFER_SAMPLES;

    f.seek(44 + startSample * 2);
    size_t bytesRead = f.read((uint8_t*)_buffer, samplesToRead * 2);
    _bufferLength = bytesRead / 2;
    f.close();

    return (_bufferLength > 0);
}

void GranularPlayer::setParams(const GrainParams& p) {
    _params = p;
    if (_params.grainCount < 1) _params.grainCount = 1;
    if (_params.grainCount > MAX_GRAINS) _params.grainCount = MAX_GRAINS;
    if (_params.grainSizeMs < 10.0f) _params.grainSizeMs = 10.0f;
    if (_params.grainSizeMs > 500.0f) _params.grainSizeMs = 500.0f;
    // Compute spawn interval: distribute grains evenly across grain size
    _spawnInterval = (uint32_t)((_params.grainSizeMs * 44.1f) / _params.grainCount);
    if (_spawnInterval < 1) _spawnInterval = 1;
}

void GranularPlayer::noteOn(float velocity) {
    _active = true;
    _velocity = velocity;
    _sampleCounter = 0;
    // Spawn initial grains
    int count = (_params.grainCount < MAX_GRAINS) ? _params.grainCount : MAX_GRAINS;
    for (int i = 0; i < count; i++) {
        spawnGrain(i);
    }
}

void GranularPlayer::noteOff() {
    _active = false;
    // Grains fade out naturally
}

void GranularPlayer::spawnGrain(int index) {
    if (index < 0 || index >= MAX_GRAINS || _bufferLength == 0) return;
    Grain& g = _grains[index];

    float windowCenter = _params.windowPosition * _bufferLength;
    float windowHalf = _params.windowSize * _bufferLength * 0.5f;

    // Random spread offset
    float spreadOffset = 0.0f;
    if (_params.spread > 0.0f) {
        // Simple pseudo-random: use micros() seeded approach
        float r = ((float)(random(-1000, 1000)) / 1000.0f); // -1.0 to 1.0
        spreadOffset = r * _params.spread * windowHalf;
    }

    float pos = windowCenter + spreadOffset;
    if (pos < 0) pos = 0;
    if (pos >= _bufferLength) pos = _bufferLength - 1;

    g.startSample = (int32_t)pos;
    g.lengthSamples = (int32_t)(_params.grainSizeMs * 44.1f);
    if (g.lengthSamples < 1) g.lengthSamples = 1;
    g.rate = _params.pitch;
    g.phase = 0.0f;
    g.phaseInc = 1.0f / (float)g.lengthSamples;
    g.amplitude = _velocity * _params.gain;
    g.position = (float)g.startSample;
    g.active = true;
}

float GranularPlayer::applyEnvelope(float phase, uint8_t shape) {
    // phase goes 0..1 over grain lifetime
    switch (shape) {
        case 0: // Hann
            return 0.5f * (1.0f - cosf(2.0f * (float)M_PI * phase));
        case 1: { // Gaussian
            float x = (phase - 0.5f) / 0.15f;
            return expf(-0.5f * x * x);
        }
        case 2: // Triangle
            return 1.0f - fabsf(2.0f * phase - 1.0f);
        case 3: { // Tukey (cos-taper edges, flat middle)
            float alpha = 0.5f; // taper fraction
            if (phase < alpha * 0.5f) {
                return 0.5f * (1.0f - cosf(2.0f * (float)M_PI * phase / alpha));
            } else if (phase > (1.0f - alpha * 0.5f)) {
                return 0.5f * (1.0f - cosf(2.0f * (float)M_PI * (1.0f - phase) / alpha));
            }
            return 1.0f;
        }
        default:
            return 1.0f;
    }
}

int16_t GranularPlayer::interpolate(float pos) {
    if (_bufferLength == 0) return 0;
    int32_t idx = (int32_t)pos;
    float frac = pos - idx;
    // Clamp
    if (idx < 0) return _buffer[0];
    if (idx >= (int32_t)_bufferLength - 1) return _buffer[_bufferLength - 1];
    // Linear interpolation
    float s0 = _buffer[idx];
    float s1 = _buffer[idx + 1];
    return (int16_t)(s0 + frac * (s1 - s0));
}

void GranularPlayer::update() {
    audio_block_t* block = allocate();
    if (!block) return;

    // Zero the block
    memset(block->data, 0, AUDIO_BLOCK_SAMPLES * 2);

    if (_bufferLength == 0) {
        transmit(block);
        release(block);
        return;
    }

    for (int s = 0; s < AUDIO_BLOCK_SAMPLES; s++) {
        float accum = 0.0f;

        // Process all active grains
        for (int g = 0; g < MAX_GRAINS; g++) {
            if (!_grains[g].active) continue;
            Grain& gr = _grains[g];

            // Get envelope
            float env = applyEnvelope(gr.phase, _params.envelopeShape);

            // Read interpolated sample
            float sampleVal = (float)interpolate(gr.position);

            // Accumulate
            accum += (sampleVal / 32768.0f) * env * gr.amplitude;

            // Advance grain
            gr.position += gr.rate;
            gr.phase += gr.phaseInc;

            // Deactivate if phase complete
            if (gr.phase >= 1.0f) {
                gr.active = false;
            }
        }

        // Clamp and write
        if (accum > 1.0f) accum = 1.0f;
        if (accum < -1.0f) accum = -1.0f;
        block->data[s] = (int16_t)(accum * 32767.0f);

        // Spawn new grains if active
        _sampleCounter++;
        if (_active && _spawnInterval > 0 && (_sampleCounter % _spawnInterval) == 0) {
            // Find an inactive grain slot
            for (int g = 0; g < MAX_GRAINS; g++) {
                if (!_grains[g].active) {
                    spawnGrain(g);
                    break;
                }
            }
        }
    }

    transmit(block);
    release(block);
}
