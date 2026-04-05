#ifndef VOICES_H
#define VOICES_H

#include <Arduino.h>

// 8 tracks, each with its own synth voice:
// Track 0: Kick      (sine + pitch env)
// Track 1: Snare     (noise + tone)
// Track 2: Hat       (filtered noise, short)
// Track 3: Open Hat  (filtered noise, longer)
// Track 4: Clap      (noise + env)
// Track 5: Bass      (saw + LP filter)
// Track 6: Lead      (saw + HP filter)
// Track 7: Pluck     (triangle + fast decay)

// Trigger a voice on a track. note/velocity come from the sequencer.
// For drum tracks, note is ignored and fixed pitch is used.
// For melodic tracks (5,6,7), note sets the pitch.
void voiceTrigger(uint8_t track, uint8_t note, uint8_t velocity);
void voiceRelease(uint8_t track);

// Initialize all voices — call once in setup() after AudioMemory()
void voicesInit();

// Get track name (for debug/UI)
const char* voiceName(uint8_t track);

#endif
