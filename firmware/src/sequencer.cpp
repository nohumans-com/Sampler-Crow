#include "sequencer.h"
#include "config.h"

// Default track colors (Launchpad palette indices)
static const uint8_t trackColors[SEQ_MAX_TRACKS] = {
    5,   // Red
    9,   // Orange
    13,  // Yellow
    21,  // Green
    37,  // Cyan
    45,  // Blue
    49,  // Purple
    53   // Pink
};

// Default root notes (C2 through G2 for drums, then melodic)
static const uint8_t defaultRootNotes[SEQ_MAX_TRACKS] = {
    36, 38, 42, 46, 39, 60, 64, 67
};

Sequencer::Sequencer()
    : _bpm(DEFAULT_BPM)
    , _playing(false)
    , _currentStep(0)
    , _pageOffset(0)
    , _lastStepTime(0)
    , _stepInterval(0)
    , _noteOnCb(nullptr)
    , _noteOffCb(nullptr)
    , _gridUpdateCb(nullptr)
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
    // 16th notes at given BPM
    // 1 beat = 60/BPM seconds, 1 16th = beat/4
    float secondsPerStep = 60.0f / _bpm / 4.0f;
    _stepInterval = (unsigned long)(secondsPerStep * 1000000.0f);
}

void Sequencer::start() {
    _playing = true;
    _currentStep = 0;
    _lastStepTime = micros();
    releaseActiveNotes();
    triggerStep(0);
    sendGridState();
    Serial.println("SEQ:START");
}

void Sequencer::stop() {
    _playing = false;
    releaseActiveNotes();
    sendGridState();
    Serial.println("SEQ:STOP");
}

void Sequencer::toggleStep(uint8_t track, uint8_t step) {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return;

    Step& s = _tracks[track].steps[step];
    if (s.velocity > 0) {
        s.velocity = 0;  // Turn off
    } else {
        s.velocity = 100;  // Turn on with default velocity
        s.note = _tracks[track].rootNote;
    }
    sendGridState();
}

void Sequencer::setStep(uint8_t track, uint8_t step, uint8_t note, uint8_t velocity) {
    if (track >= SEQ_MAX_TRACKS || step >= SEQ_MAX_STEPS) return;
    _tracks[track].steps[step].note = note;
    _tracks[track].steps[step].velocity = velocity;
    sendGridState();
}

void Sequencer::clearTrack(uint8_t track) {
    if (track >= SEQ_MAX_TRACKS) return;
    for (uint8_t s = 0; s < SEQ_MAX_STEPS; s++) {
        _tracks[track].steps[s].velocity = 0;
    }
    sendGridState();
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

void Sequencer::update() {
    if (!_playing) return;

    unsigned long now = micros();
    if (now - _lastStepTime >= _stepInterval) {
        _lastStepTime += _stepInterval;
        advanceStep();
    }
}

void Sequencer::advanceStep() {
    // Release previous notes
    releaseActiveNotes();

    // Advance
    _currentStep = (_currentStep + 1) % SEQ_MAX_STEPS;

    // Trigger new notes
    triggerStep(_currentStep);

    // Update grid display
    sendGridState();
}

void Sequencer::triggerStep(uint8_t step) {
    for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
        if (_tracks[t].muted) continue;

        const Step& s = _tracks[t].steps[step];
        if (s.velocity > 0 && _noteOnCb) {
            _noteOnCb(t, s.note, s.velocity);
            _activeNotes[t] = s.note;
            _noteIsActive[t] = true;
        }
    }
}

void Sequencer::releaseActiveNotes() {
    for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
        if (_noteIsActive[t] && _noteOffCb) {
            _noteOffCb(t, _activeNotes[t]);
            _noteIsActive[t] = false;
        }
    }
}

void Sequencer::sendGridState() {
    // Send grid state via serial as compact format:
    // GRID:row0col0,row0col1,...,row7col7 (64 color values)
    // Also send via MIDI for direct Launchpad control

    Serial.print("GRD:");
    for (uint8_t t = 0; t < SEQ_MAX_TRACKS; t++) {
        for (uint8_t c = 0; c < 8; c++) {
            uint8_t step = _pageOffset + c;

            uint8_t color;
            if (step == _currentStep && _playing) {
                if (isStepActive(t, step)) {
                    color = 3;  // Bright white (active + playhead)
                } else {
                    color = 1;  // Dim white (playhead only)
                }
            } else if (isStepActive(t, step)) {
                color = _tracks[t].color;  // Track color
            } else {
                color = 0;  // Off
            }

            if (t > 0 || c > 0) Serial.print(',');
            Serial.print(color);

            // Also send via MIDI for Launchpad
            uint8_t lpNote = (SEQ_MAX_TRACKS - t) * 10 + (c + 1);
            usbMIDI.sendNoteOn(lpNote, color, SEQ_GRID_CH);
        }
    }
    Serial.println();
    usbMIDI.send_now();

    // Also send playhead position and playing state
    Serial.printf("SEQ:%d:%d:%.0f\n", _playing ? 1 : 0, _currentStep, _bpm);

    if (_gridUpdateCb) _gridUpdateCb();
}
