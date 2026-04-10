#ifndef SEQUENCER_H
#define SEQUENCER_H

#include <Arduino.h>

#define SEQ_MAX_TRACKS  8
#define SEQ_MAX_STEPS   64
#define SEQ_GRID_CH     16

struct Step {
    uint8_t note;
    uint8_t velocity;
    uint8_t gate;
    uint8_t padIndex;
};

struct Track {
    Step steps[SEQ_MAX_STEPS];
    uint8_t numSteps;
    uint8_t rootNote;
    bool muted;
    uint8_t color;
};

class Sequencer {
public:
    Sequencer();

    void setBPM(float bpm);
    float getBPM() const { return _bpm; }

    void start();
    void stop();
    bool isPlaying() const { return _playing; }

    void toggleStep(uint8_t track, uint8_t step);
    void setStep(uint8_t track, uint8_t step, uint8_t note, uint8_t velocity);
    void clearTrack(uint8_t track);
    void clearAll();

    // Called DIRECTLY from IntervalTimer ISR — triggers notes with hardware precision.
    // Only calls voiceTrigger/voiceRelease which are ISR-safe on Teensy 4.1.
    // Does NO serial or MIDI I/O.
    void tickISR();

    // Called from loop() — does nothing (timing is ISR-driven)
    void update();

    uint8_t getCurrentStep() const { return _currentStep; }
    uint8_t getPageOffset() const { return _pageOffset; }
    void setPageOffset(uint8_t offset) { _pageOffset = offset; }
    unsigned long getStepIntervalUs() const { return _stepInterval; }

    bool isStepActive(uint8_t track, uint8_t step) const;
    uint8_t getStepVelocity(uint8_t track, uint8_t step) const;
    uint8_t getStepNote(uint8_t track, uint8_t step) const;
    uint8_t getStepGate(uint8_t track, uint8_t step) const;
    void setStepVelocity(uint8_t track, uint8_t step, uint8_t velocity);
    void setStepNote(uint8_t track, uint8_t step, uint8_t note);

    Track& getTrack(uint8_t track) { return _tracks[track]; }

    void setStepPadIndex(uint8_t track, uint8_t step, uint8_t padIndex);
    void sendClipData(uint8_t track);

    // Pattern save/load to SD card
    bool saveToSD(uint8_t slot);
    bool loadFromSD(uint8_t slot);

    // Callbacks
    typedef void (*NoteOnCallback)(uint8_t track, uint8_t note, uint8_t velocity, uint8_t padIndex);
    typedef void (*NoteOffCallback)(uint8_t track, uint8_t note, uint8_t padIndex);
    typedef void (*GridUpdateCallback)();

    void setNoteOnCallback(NoteOnCallback cb) { _noteOnCb = cb; }
    void setNoteOffCallback(NoteOffCallback cb) { _noteOffCb = cb; }
    void setGridUpdateCallback(GridUpdateCallback cb) { _gridUpdateCb = cb; }

    // UI update methods — called from loop() only, never from ISR
    void sendGridState();
    void sendStepUpdate();

    // Dirty flags — ISR sets, loop() consumes
    bool consumeStepAdvanced() {
        if (_stepAdvanced) { _stepAdvanced = false; return true; }
        return false;
    }
    bool consumeGridDirty() {
        if (_gridDirty) { _gridDirty = false; return true; }
        return false;
    }
    void markGridDirty() { _gridDirty = true; }

private:
    Track _tracks[SEQ_MAX_TRACKS];
    float _bpm;
    volatile bool _playing;
    volatile uint8_t _currentStep;
    uint8_t _pageOffset;
    unsigned long _stepInterval;

    uint8_t _activeNotes[SEQ_MAX_TRACKS];
    bool _noteIsActive[SEQ_MAX_TRACKS];

    NoteOnCallback _noteOnCb;
    NoteOffCallback _noteOffCb;
    GridUpdateCallback _gridUpdateCb;

    volatile bool _stepAdvanced;
    volatile bool _gridDirty;

    void triggerStep(uint8_t step);
    void releaseActiveNotes();
    void updateStepInterval();
};

#endif
