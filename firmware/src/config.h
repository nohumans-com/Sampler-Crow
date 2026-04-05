#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// =============================================================
// Sampler-Crow Configuration
// =============================================================

// --- Feature flags ---
// #define HAS_PSRAM          // Uncomment when PSRAM is soldered
// #define HAS_AUDIO_SHIELD   // Uncomment when Audio Shield is connected
// #define HAS_USB_HOST       // Uncomment when USB Host pads are soldered

#ifdef HAS_PSRAM
  #define MAX_TRACKS      8
  #define MAX_FX_SLOTS    3
  #define MAX_GRAIN_POOL  32
  #define AUDIO_MEM_BLOCKS 200
#else
  #define MAX_TRACKS      4
  #define MAX_FX_SLOTS    1
  #define MAX_GRAIN_POOL  16
  #define AUDIO_MEM_BLOCKS 100
#endif

// --- Audio Settings ---
#define SAMPLE_RATE         44100
#define AUDIO_BLOCK_SAMPLES 128
#define MAX_PLAITS_VOICES   4
#define MAX_SAMPLER_VOICES  8
#define MAX_SAMPLE_SLOTS    8

// --- Analog Inputs (Potentiometers) ---
#define POT_1_PIN   A2   // Pin 16 - Cutoff / Param A
#define POT_2_PIN   A3   // Pin 17 - Resonance / Param B
#define POT_3_PIN   A4   // Pin 24 - Attack/Decay / Param C
#define POT_4_PIN   A5   // Pin 25 - Volume / Mix
#define NUM_POTS    4

// --- Digital Inputs (Buttons) ---
#define BTN_PLAY_PIN    2    // Play / Trigger
#define BTN_REC_PIN     6    // Record
#define BTN_MODE_PIN    9    // Mode / Preset
#define BTN_SHIFT_PIN   14   // Shift / Function
#define NUM_BTNS        4

// --- Serial to CrowPanel ESP32-S3 ---
#define CROWPANEL_SERIAL  Serial1  // Pins 0 (RX) and 1 (TX)
#define CROWPANEL_BAUD    115200

// --- Sequencer Defaults ---
#define DEFAULT_BPM       120.0f
#define MIN_BPM           40.0f
#define MAX_BPM           300.0f
#define DEFAULT_STEPS     16
#define MAX_STEPS         64
#define MAX_CLIPS_PER_TRACK 8

// --- Track Types ---
enum TrackType {
    TRACK_EMPTY = 0,
    TRACK_SYNTH,       // Mutable Instruments Plaits
    TRACK_SAMPLER,     // Pitch/Grain/Chop/Drum/Multi modes
    TRACK_AUDIO        // Live input record/playback
};

// --- Sampler Modes ---
enum SamplerMode {
    SAMPLER_PITCH = 0,
    SAMPLER_GRAIN,
    SAMPLER_CHOP,
    SAMPLER_DRUM,
    SAMPLER_MULTI
};

// --- Grid Controller ---
#define GRID_ROWS    9   // 8 pad rows + 1 top function row
#define GRID_COLS    9   // 8 pad cols + 1 right function col
#define GRID_MIDI_CH 16  // MIDI channel for Chrome grid communication (1-indexed)

// --- Operating Modes ---
enum OperatingMode {
    MODE_SESSION,    // Clip launcher view
    MODE_SEQUENCER,  // Step sequencer
    MODE_MIXER,      // Mixer / levels
    MODE_TRACK_EDIT  // Per-track parameters
};

#endif
