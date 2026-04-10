#include "sequencer.h"
#include "config.h"
#include <SD.h>

static const uint8_t trackColors[SEQ_MAX_TRACKS] = {
    5, 9, 13, 21, 37, 45, 49, 53
};

static const uint8_t defaultRootNotes[SEQ_MAX_TRACKS] = {
    36, 38, 42, 46, 39, 60, 64, 67
};

Sequencer::Sequencer()
    : _bpm(DEFAULT_BPM)
    , _playing(false)
    , _currentStep(0)
    , _pageOffset(0)
    , _stepInterval(0)
    , _noteOnCb(nullptr)
    , _noteOffCb(nullptr)
    , _gridUpdateCb(nullptr)
    , _stepAdvanced(false)
    , _gridDirty(false)
{
    updateStepInterval();
    for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
        _tracks[t].numSteps = SEQ_MAX_STEPS;
        _tracks[t].rootNote = defaultRootNotes[t];
        _tracks[t].muted = false;
        _tracks[t].color = trackColors[t];
        _activeNotes[t] = 0;
        _noteIsActive[t] = false;
        for (uint8_t s = 0; s < SEQ_MAX_STEPS; s++) {
            _tracks[t].steps[s].note = defaultRootNotes[t];
            _tracks[t].steps[s].velocity = 0;
            _tracks[t].steps[s].gate = 80;
            _tracks[t].steps[s].padIndex = 0;
        }
    }
}

void Sequencer::setBPM(float bpm) {
    if (bpm < MIN_BPM) bpm = MIN_BPM;
    if (bpm > MAX_BPM) bpm = MAX_BPM;
    _bpm = bpm;
    updateStepInterval();
}

void Sequencer::updateStepInterval() {
    float secondsPerStep = 60.0f / _bpm / 4.0f;
    _stepInterval = (unsigned long)(secondsPerStep * 1000000.0f);
}

void Sequencer::start() {
    _playing = true;
    _currentStep = 0;
    releaseActiveNotes();
    triggerStep(0);
    markGridDirty();
}

void Sequencer::stop() {
    _playing = false;
    releaseActiveNotes();
    markGridDirty();
}

void Sequencer::toggleStep(uint8_t track, uint8_t step) {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return;
    Step& s = _tracks[track].steps[step];
    if (s.velocity > 0) {
        s.velocity = 0;
    } else {
        s.velocity = 100;
        s.note = _tracks[track].rootNote;
    }
    markGridDirty();
}

void Sequencer::setStep(uint8_t track, uint8_t step, uint8_t note, uint8_t velocity) {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return;
    _tracks[track].steps[step].note = note;
    _tracks[track].steps[step].velocity = velocity;
    // Don't mark dirty during initial setup (called from setup())
}

void Sequencer::clearTrack(uint8_t track) {
    if (track >= SEQ_MAX_TRACKS) return;
    for (uint8_t s = 0; s < SEQ_MAX_STEPS; s++) {
        _tracks[track].steps[s].velocity = 0;
    }
    markGridDirty();
}

void Sequencer::clearAll() {
    for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
        clearTrack(t);
    }
}

bool Sequencer::isStepActive(uint8_t track, uint8_t step) const {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return false;
    return _tracks[track].steps[step].velocity > 0;
}

uint8_t Sequencer::getStepVelocity(uint8_t track, uint8_t step) const {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return 0;
    return _tracks[track].steps[step].velocity;
}

uint8_t Sequencer::getStepNote(uint8_t track, uint8_t step) const {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return 0;
    return _tracks[track].steps[step].note;
}

uint8_t Sequencer::getStepGate(uint8_t track, uint8_t step) const {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return 0;
    return _tracks[track].steps[step].gate;
}

void Sequencer::setStepVelocity(uint8_t track, uint8_t step, uint8_t velocity) {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return;
    _tracks[track].steps[step].velocity = velocity;
    markGridDirty();
}

void Sequencer::setStepNote(uint8_t track, uint8_t step, uint8_t note) {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return;
    _tracks[track].steps[step].note = note;
    markGridDirty();
}

void Sequencer::update() {
    // No-op: timing driven by IntervalTimer ISR via tickISR()
}

// Called DIRECTLY from IntervalTimer ISR — hardware-precise timing.
// Only modifies audio objects (ISR-safe on Teensy 4.1). NO serial or MIDI I/O.
void Sequencer::tickISR() {
    if (!_playing) return;

    releaseActiveNotes();
    _currentStep = (_currentStep + 1) % SEQ_MAX_STEPS;
    triggerStep(_currentStep);
    _stepAdvanced = true;  // signal loop() to handle UI update
}

void Sequencer::triggerStep(uint8_t step) {
    for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
        if (_tracks[t].muted) continue;
        uint8_t trackStep = step % _tracks[t].numSteps;
        const Step& s = _tracks[t].steps[trackStep];
        if (s.velocity > 0 && _noteOnCb) {
            _noteOnCb(t, s.note, s.velocity, s.padIndex);
            _activeNotes[t] = s.note;
            _noteIsActive[t] = true;
        }
    }
}

void Sequencer::releaseActiveNotes() {
    for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
        if (_noteIsActive[t] && _noteOffCb) {
            _noteOffCb(t, _activeNotes[t], 0);
            _noteIsActive[t] = false;
        }
    }
}

// --- UI methods: called from loop() only, safe for serial/MIDI ---

void Sequencer::sendStepUpdate() {
    if (Serial.availableForWrite() < 20) return;
    // Lightweight: just the step number. App handles grid animation locally.
    char buf[16];
    int n = snprintf(buf, sizeof(buf), "STEP:%d\n", _currentStep);
    Serial.write(buf, n);
}

void Sequencer::sendGridState() {
    if (Serial.availableForWrite() < 250) return;

    // Build entire GRD message in one buffer, single write. No MIDI — app mirrors to Launchpad.
    char buf[300];
    int pos = 0;
    pos += snprintf(buf + pos, sizeof(buf) - pos, "GRD:");
    for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
        for (uint8_t c = 0; c < 8; c++) {
            uint8_t step = _pageOffset + c;
            uint8_t color;
            if (step == _currentStep && _playing) {
                color = isStepActive(t, step) ? 3 : 1;
            } else if (isStepActive(t, step)) {
                color = _tracks[t].color;
            } else {
                color = 0;
            }
            if (t > 0 || c > 0) buf[pos++] = ',';
            pos += snprintf(buf + pos, sizeof(buf) - pos, "%d", color);
        }
    }
    buf[pos++] = '\n';
    Serial.write(buf, pos);

    if (_gridUpdateCb) _gridUpdateCb();
}

// --- Pattern save/load ---

bool Sequencer::saveToSD(uint8_t slot) {
    if (slot > 7) return false;

    SD.mkdir("/patterns");

    char path[20];
    snprintf(path, sizeof(path), "/patterns/P%d.bin", slot);

    File f = SD.open(path, FILE_WRITE);
    if (!f) return false;

    // Write BPM as 4-byte float
    f.write((const uint8_t*)&_bpm, sizeof(float));

    // New format: per track: 1 byte numSteps + 64 steps x 4 bytes (note, vel, gate, padIndex)
    // Total: 4 + 8*(1 + 64*4) = 4 + 8*257 = 2060 bytes
    for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
        f.write(_tracks[t].numSteps);
        for (uint8_t s = 0; s < SEQ_MAX_STEPS; s++) {
            uint8_t data[4];
            data[0] = _tracks[t].steps[s].note;
            data[1] = _tracks[t].steps[s].velocity;
            data[2] = _tracks[t].steps[s].gate;
            data[3] = _tracks[t].steps[s].padIndex;
            f.write(data, 4);
        }
    }

    f.close();
    return true;
}

bool Sequencer::loadFromSD(uint8_t slot) {
    if (slot > 7) return false;

    char path[20];
    snprintf(path, sizeof(path), "/patterns/P%d.bin", slot);

    if (!SD.exists(path)) return false;

    File f = SD.open(path, FILE_READ);
    if (!f) return false;

    uint32_t fileSize = f.size();

    // Detect format by file size
    // Old format: 4 (BPM) + 8*8*3 = 196 bytes
    // New format: 4 (BPM) + 8*(1 + 64*4) = 2060 bytes
    if (fileSize != 196 && fileSize != 2060) {
        f.close();
        return false;
    }

    // Read BPM
    float bpm;
    if (f.read((uint8_t*)&bpm, sizeof(float)) != sizeof(float)) {
        f.close();
        return false;
    }

    if (fileSize == 196) {
        // Old format: 8 tracks x 8 steps x 3 bytes (note, velocity, gate)
        for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
            _tracks[t].numSteps = 8;
            for (uint8_t s = 0; s < 8; s++) {
                uint8_t data[3];
                if (f.read(data, 3) != 3) {
                    f.close();
                    return false;
                }
                _tracks[t].steps[s].note = data[0];
                _tracks[t].steps[s].velocity = data[1];
                _tracks[t].steps[s].gate = data[2];
                _tracks[t].steps[s].padIndex = 0;
            }
            // Clear remaining steps
            for (uint8_t s = 8; s < SEQ_MAX_STEPS; s++) {
                _tracks[t].steps[s].note = _tracks[t].rootNote;
                _tracks[t].steps[s].velocity = 0;
                _tracks[t].steps[s].gate = 80;
                _tracks[t].steps[s].padIndex = 0;
            }
        }
    } else {
        // New format: per track: 1 byte numSteps + 64 steps x 4 bytes
        for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
            uint8_t ns;
            if (f.read(&ns, 1) != 1) { f.close(); return false; }
            _tracks[t].numSteps = ns;
            for (uint8_t s = 0; s < SEQ_MAX_STEPS; s++) {
                uint8_t data[4];
                if (f.read(data, 4) != 4) {
                    f.close();
                    return false;
                }
                _tracks[t].steps[s].note = data[0];
                _tracks[t].steps[s].velocity = data[1];
                _tracks[t].steps[s].gate = data[2];
                _tracks[t].steps[s].padIndex = data[3];
            }
        }
    }

    f.close();
    setBPM(bpm);
    markGridDirty();
    return true;
}

void Sequencer::setStepPadIndex(uint8_t track, uint8_t step, uint8_t padIndex) {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return;
    _tracks[track].steps[step].padIndex = padIndex;
    markGridDirty();
}

void Sequencer::sendClipData(uint8_t track) {
    if (track >= SEQ_MAX_TRACKS) return;
    // Too large for TX ring buffer — use direct Serial.print
    while (Serial.availableForWrite() < 20) { delayMicroseconds(100); }
    Serial.print("CLIP:");
    Serial.print(track);
    Serial.print(":");
    for (uint8_t s = 0; s < SEQ_MAX_STEPS; s++) {
        while (Serial.availableForWrite() < 20) { delayMicroseconds(100); }
        if (s > 0) Serial.print(";");
        const Step& st = _tracks[track].steps[s];
        Serial.print(st.note);
        Serial.print(",");
        Serial.print(st.velocity);
        Serial.print(",");
        Serial.print(st.gate);
        Serial.print(",");
        Serial.print(st.padIndex);
    }
    while (Serial.availableForWrite() < 4) { delayMicroseconds(100); }
    Serial.println();
}
