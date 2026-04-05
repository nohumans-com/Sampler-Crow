#ifndef SEQUENCER_H
#define SEQUENCER_H

#include <Arduino.h>

#define SEQ_MAX_TRACKS  8
#define SEQ_MAX_STEPS   8
#define SEQ_GRID_CH     16  // MIDI channel for grid LED updates (1-indexed)

struct Step {
    uint8_t note;      // MIDI note (0-127)
    uint8_t velocity;  // 0 = off, 1-127 = on
    uint8_t gate;      // Gate length as percentage (1-100)
};

struct Track {
    Step steps[SEQ_MAX_STEPS];
    uint8_t numSteps;
    uint8_t rootNote;     // Default note for this track
    bool muted;
    uint8_t color;        // LP color palette index for this track
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

    // Call from loop() — advances the sequencer based on elapsed time
    void update();

    // Get current state for grid display
    uint8_t getCurrentStep() const { return _currentStep; }
    uint8_t getPageOffset() const { return _pageOffset; }
    void setPageOffset(uint8_t offset) { _pageOffset = offset; }

    // Get step state (for grid LED display)
    bool isStepActive(uint8_t track, uint8_t step) const;
    uint8_t getStepVelocity(uint8_t track, uint8_t step) const;

    // Track access
    Track& getTrack(uint8_t track) { return _tracks[track]; }

    // Callbacks — set these to connect to audio engine
    typedef void (*NoteOnCallback)(uint8_t track, uint8_t note, uint8_t velocity);
    typedef void (*NoteOffCallback)(uint8_t track, uint8_t note);
    typedef void (*GridUpdateCallback)();

    void setNoteOnCallback(NoteOnCallback cb) { _noteOnCb = cb; }
    void setNoteOffCallback(NoteOffCallback cb) { _noteOffCb = cb; }
    void setGridUpdateCallback(GridUpdateCallback cb) { _gridUpdateCb = cb; }

    // Send current grid state as MIDI to update Launchpad/app
    void sendGridState();

private:
    Track _tracks[SEQ_MAX_TRACKS];
    float _bpm;
    bool _playing;
    uint8_t _currentStep;
    uint8_t _pageOffset;     // Which 8-step page we're viewing
    unsigned long _lastStepTime;
    unsigned long _stepInterval;  // microseconds per step

    // Track which notes are currently sounding (for note-off)
    uint8_t _activeNotes[SEQ_MAX_TRACKS];
    bool _noteIsActive[SEQ_MAX_TRACKS];

    NoteOnCallback _noteOnCb;
    NoteOffCallback _noteOffCb;
    GridUpdateCallback _gridUpdateCb;

    void advanceStep();
    void triggerStep(uint8_t step);
    void releaseActiveNotes();
    void updateStepInterval();
};

#endif
