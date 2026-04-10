# Sampler-Crow: Hardware Design Document (v2)

## Project Overview

A DIY sampler/synthesizer with MIDI I/O, USB MIDI host, and experimental USB Audio support. The system uses a **triple-processor architecture**:

1. **Elecrow CrowPanel ESP32-S3** — Touchscreen UI brain
2. **Teensy 4.1 + Audio Shield** — Audio DSP brain + USB MIDI Host (for Launchpad)
3. **ESP32-S3 Dev Board** — USB Audio bridge (experimental, connects class-compliant audio interfaces)

All three communicate over serial UART and I2S buses.

---

## Architecture Diagram

```
                    ┌──────────────────────────────┐
                    │   Elecrow CrowPanel 3.5"     │
                    │   (ESP32-S3)                  │
USB-C ◄──────────── │   Touch UI / Menus           │
(programming/       │                               │
 power)             │   TX (GPIO 10) ──┐            │
                    │   RX (GPIO  9) ─┐│            │
                    │   GND ─────────┐││            │
                    └────────────────┼┼┼────────────┘
                                     │││
                                     │││ Serial UART
                                     │││
┌────────────────────────────────────┼┼┼────────────────────┐
│   Teensy 4.1 + Audio Shield       │││                     │
│   (ARM M7 @ 600MHz)               │││                     │
│                                    │││                     │
│   GND ─────────────────────────────┘││                     │
│   RX (Pin 0) ───────────────────────┘│                     │
│   TX (Pin 1) ────────────────────────┘                     │
│                                                             │
│   ┌─────────────────────┐   ┌─────────────┐               │
│   │  Audio Shield       │   │  USB Host   │               │
│   │  (SGTL5000)         │   │  (5-pin)    │               │
│   │                     │   │             │               │
│   │  LINE OUT → TRS Out │   │  → USB Hub  │               │
│   │  LINE IN  ← TRS In  │   │    ├ Launchpad (MIDI)      │
│   │  HP OUT   → TRS HP  │   │    └ (future devices)      │
│   │  MIC IN   ← INMP441 │   └─────────────┘               │
│   └─────────────────────┘                                   │
│                                                             │
│   MIDI OUT (Serial3 TX, Pin 14) → ubld.it → TRS MIDI Out  │
│   MIDI IN  (Serial3 RX, Pin 15) ← ubld.it ← TRS MIDI In  │
│                                                             │
│   A2-A5 ← 4 Potentiometers                                │
│   D2,D6,D9,D22 ← 4 Buttons                                │
│                                                             │
│   I2S2 Bus ←──────────────── ESP32-S3 Audio Bridge         │
└─────────────────────────────────────────────────────────────┘
                                        │
                    ┌───────────────────┼────────────────────┐
                    │   ESP32-S3 Dev Board                   │
                    │   (USB Audio Bridge - Experimental)    │
                    │                                        │
USB-C ◄──────────── │   USB OTG Host → Class-compliant       │
(audio interface)   │   audio interface                      │
                    │                                        │
                    │   I2S OUT → Teensy I2S2 (audio data)   │
                    │   Serial → Teensy Serial4 (control)    │
                    └────────────────────────────────────────┘

USB-C ◄──────────── Teensy micro-USB (programming + USB Device to computer)
(host computer)     (via micro-USB to USB-C panel adapter)
```

---

## Bill of Materials (BOM)

### Core Components

| # | Component | Product (Amazon) | Est. Price | Link |
|---|-----------|-----------------|------------|------|
| 1 | **Teensy 4.1 (with Pins)** | PJRC Teensy 4.1 ARM Cortex-M7 600MHz | ~$49 | [amazon.com/dp/B08CTM3279](https://www.amazon.com/dp/B08CTM3279) |
| 2 | **Teensy Audio Shield Rev D** | Teensy 4 Audio Shield (SGTL5000) | ~$14 | [amazon.com/dp/B07Z6NW913](https://www.amazon.com/dp/B07Z6NW913) |
| 3 | **Elecrow CrowPanel 3.5"** | ESP32-S3 480x320 TFT Touch | ~$36 | [amazon.com/dp/B0FXLB5CFL](https://www.amazon.com/dp/B0FXLB5CFL) |
| 4 | **ESP32-S3 Dev Board** | ESP32-S3-DevKitC (USB OTG) for audio bridge | ~$10 | [amazon.com/dp/B0CDWXWXCG](https://www.amazon.com/dp/B0CDWXWXCG) |
| 5 | **INMP441 MEMS Mic (5-pack)** | AITRIP I2S MEMS Microphone | ~$12 | [amazon.com/dp/B092HWW4RS](https://www.amazon.com/dp/B092HWW4RS) |

### MIDI I/O

| # | Component | Product | Est. Price | Link |
|---|-----------|---------|------------|------|
| 6 | **ubld.it MIDI Breakout MV** | Pre-built MIDI IN + OUT, 3.3V/5V, optically isolated | ~$25 | [amazon.com/dp/B0BYMC926Z](https://www.amazon.com/dp/B0BYMC926Z) |

### USB & Connectivity

| # | Component | Product | Est. Price | Link |
|---|-----------|---------|------------|------|
| 7 | **USB Host Cable for Teensy** | 5-pin header to USB-A female (from SparkFun/PJRC) | ~$4 | [sparkfun.com](https://www.sparkfun.com/usb-host-cable-for-teensy-4-1-and-teensy-3-6.html) |
| 8 | **USB 2.0 Hub (compact)** | Small 4-port USB hub for Launchpad + expansion | ~$8 | [amazon.com/dp/B00XNX0FL0](https://www.amazon.com/dp/B00XNX0FL0) |
| 9 | **USB-C Panel Mount (3-pack)** | USB-C male-to-female panel mount adapter cables | ~$10 | [amazon.com/dp/B08HS6X44P](https://www.amazon.com/dp/B08HS6X44P) |

### Audio Jacks & Controls

| # | Component | Product | Est. Price | Link |
|---|-----------|---------|------------|------|
| 10 | **3.5mm TRS Jacks (5-pack)** | Ancable panel mount stereo jacks | ~$7 | [amazon.com/dp/B07JNC4P7Y](https://www.amazon.com/dp/B07JNC4P7Y) |
| 11 | **B10K Potentiometers (20-pack)** | Linear pots + knobs | ~$9 | [amazon.com/dp/B06WWQP12J](https://www.amazon.com/dp/B06WWQP12J) |
| 12 | **Tactile Buttons + Caps (25-pack)** | 12mm momentary push buttons | ~$7 | [amazon.com/dp/B0798HZ8WB](https://www.amazon.com/dp/B0798HZ8WB) |

### Prototyping & Wiring

| # | Component | Product | Est. Price | Link |
|---|-----------|---------|------------|------|
| 13 | **22AWG Hookup Wire (6 colors)** | TUOFENG solid core | ~$10 | [amazon.com/dp/B07TX6BX47](https://www.amazon.com/dp/B07TX6BX47) |
| 14 | **Dupont Jumper Wires (120-pack)** | ELEGOO breadboard wires | ~$7 | [amazon.com/dp/B01EV70C78](https://www.amazon.com/dp/B01EV70C78) |
| 15 | **Perfboard Kit (32-pack)** | Double-sided prototype PCB | ~$8 | [amazon.com/dp/B07W83VJGV](https://www.amazon.com/dp/B07W83VJGV) |
| 16 | **MicroSD Card 32GB** | SanDisk Ultra | ~$8 | [amazon.com/dp/B08GY9NYRM](https://www.amazon.com/dp/B08GY9NYRM) |

### Estimated Total: ~$214

(Within budget if you skip the USB hub for initial prototyping and add it later)

---

## External Ports (Panel Layout)

The final product will have these panel-mount connectors:

```
┌──────────────────────────────────────────────────────────────┐
│                         FRONT PANEL                          │
│                                                              │
│  [DISPLAY]  [POT1] [POT2] [POT3] [POT4]  [BTN1-4]         │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│                          REAR PANEL                          │
│                                                              │
│  USB-C    USB-C      USB-C     LINE  LINE  HEAD  MIDI MIDI  │
│  HOST     LAUNCH     AUDIO     IN    OUT   PHONE OUT  IN    │
│  (PC)     (PAD)      (I/F)                                  │
│                                                              │
│  ◯        ◯          ◯         ◯     ◯     ◯     ◯    ◯    │
└──────────────────────────────────────────────────────────────┘
```

**Port descriptions:**
1. **USB-C HOST** — Connects to computer (Teensy device port via micro-USB adapter)
2. **USB-C LAUNCHPAD** — Connects Novation Launchpad or other USB MIDI controller (via USB hub to Teensy Host)
3. **USB-C AUDIO** — Connects class-compliant USB audio interface (to ESP32-S3 Audio Bridge)
4. **LINE IN** — 3.5mm TRS stereo input (Audio Shield)
5. **LINE OUT** — 3.5mm TRS stereo output (Audio Shield)
6. **HEADPHONE** — 3.5mm TRS headphone output (Audio Shield)
7. **MIDI OUT** — 3.5mm TRS Type A MIDI output
8. **MIDI IN** — 3.5mm TRS Type A MIDI input

---

## Wiring Guide

### Step 1: Teensy 4.1 + Audio Shield (No Soldering)

Stack the Audio Shield onto the Teensy 4.1. It uses these pins automatically:

| Function | Teensy Pin |
|----------|-----------|
| I2S BCLK | 7 |
| I2S LRCLK | 8 |
| I2S TX | 20 |
| I2S RX | 21 |
| I2S MCLK | 23 |
| I2C SCL | 18 |
| I2C SDA | 19 |
| SD Card (SPI) | 10, 11, 12, 13 |

### Step 2: Wire 4 Potentiometers

```
    [Shaft]
  ┌─────────┐
  │  1 2 3  │
  └─────────┘
  Pin 1 → GND  |  Pin 2 → Teensy analog  |  Pin 3 → 3.3V
```

| Pot # | Function | Teensy Pin |
|-------|----------|-----------|
| 1 | Cutoff | A2 (Pin 16) |
| 2 | Resonance | A3 (Pin 17) |
| 3 | Attack/Decay | A4 (Pin 24) |
| 4 | Volume/Mix | A5 (Pin 25) |

**Use 3.3V, not 5V.** Common GND bus and common 3.3V bus.

### Step 3: Wire 4 Buttons

Each button: Teensy digital pin → [Button] → GND. Use `INPUT_PULLUP` in software.

| Button # | Function | Teensy Pin |
|----------|----------|-----------|
| 1 | Play/Trigger | D2 |
| 2 | Record | D6 |
| 3 | Mode/Preset | D9 |
| 4 | Shift/Function | D22 |

### Step 4: Wire TRS Audio Jacks to Audio Shield

**Line Output:** Audio Shield LINE OUT L → Tip, R → Ring, GND → Sleeve
**Line Input:** Tip → Audio Shield LINE IN L, Ring → LINE IN R, Sleeve → GND
**Headphone:** Audio Shield HP OUT L → Tip, R → Ring, GND → Sleeve

### Step 5: Wire INMP441 MEMS Microphone

Connect to Teensy's second I2S bus (I2S2):

| INMP441 Pin | Teensy Pin | Notes |
|-------------|-----------|-------|
| VDD | 3.3V | Power |
| GND | GND | Ground |
| WS | D3 | I2S2 LRCLK |
| SCK | D4 | I2S2 BCLK |
| SD | D5 | I2S2 DATA |
| L/R | GND | Left channel |

### Step 6: Wire ubld.it MIDI Breakout Board

The ubld.it MIDI 2.0 Breakout Board MV has screw terminals or header pins. Set the voltage switch to **3.3V**.

| ubld.it Pin | Teensy Pin | Notes |
|-------------|-----------|-------|
| TX (MIDI OUT data) | Pin 14 (Serial3 TX) | Teensy sends MIDI out |
| RX (MIDI IN data) | Pin 15 (Serial3 RX) | Teensy receives MIDI in |
| VCC | 3.3V | Power |
| GND | GND | Ground |

The ubld.it board handles all optocoupler isolation, resistors, and protection internally. Connect two 3.5mm TRS jacks to the board's MIDI IN and MIDI OUT connectors.

**MIDI TRS Type A Standard (used by the ubld.it board):**
- Tip = Current Source (Pin 4 on DIN)
- Ring = Current Sink (Pin 5 on DIN)
- Sleeve = Ground (Pin 2 on DIN)

### Step 7: Wire CrowPanel ESP32-S3 to Teensy

Serial UART link (3 wires):

| CrowPanel | Teensy | Notes |
|-----------|--------|-------|
| TX (GPIO 10) | RX (Pin 0) | UI commands to Teensy |
| RX (GPIO 9) | TX (Pin 1) | Status from Teensy |
| GND | GND | Common ground |

### Step 8: Teensy USB Host Setup

1. Solder the 5-pin USB Host header to the bottom of the Teensy 4.1
2. Connect the SparkFun/PJRC USB Host Cable to these pins
3. Plug the compact USB hub into the USB Host Cable's female USB-A connector
4. The Launchpad (or other USB MIDI controllers) plugs into the hub

**Note:** The USB hub should be a **powered** hub for reliability, especially if the Launchpad draws significant current.

### Step 9: ESP32-S3 Audio Bridge (Experimental — Later Phase)

This is a separate ESP32-S3 dev board that acts as a USB Audio host:

| ESP32-S3 Bridge Pin | Connect To | Notes |
|--------------------|-----------|-------|
| USB-C port | Class-compliant audio interface | USB OTG Host mode |
| GPIO 12 (I2S BCLK) | Teensy Pin 4 (I2S2 BCLK)* | Shared I2S2 clock |
| GPIO 11 (I2S LRCLK) | Teensy Pin 3 (I2S2 LRCLK)* | Shared I2S2 frame |
| GPIO 10 (I2S DOUT) | Teensy Pin 5 (I2S2 DATA)* | Audio data to Teensy |
| GPIO 17 (Serial TX) | Teensy Pin 34 (Serial8 RX) | Control messages |
| GND | Teensy GND | Common ground |
| 3.3V | Teensy 3.3V | Or power via USB |

*\*Note: The INMP441 mic and ESP32-S3 Audio Bridge share the I2S2 bus. They cannot run simultaneously — software switches between mic and USB audio input.*

**This is an advanced/experimental feature.** Build and test everything else first. The ESP-IDF `usb_stream` component is required (not Arduino-compatible for USB Audio hosting).

### Step 10: USB-C Panel Mount Adapters

For each USB-C port on the enclosure:

1. **HOST (to computer):** USB-C female panel mount → short cable → micro-USB male (into Teensy's programming port)
2. **LAUNCHPAD:** USB-C female panel mount → short cable → USB-A female → into USB hub → into Teensy USB Host
3. **AUDIO INTERFACE:** USB-C female panel mount → directly into ESP32-S3 Audio Bridge's USB-C port

---

## Pin Allocation Summary

### Teensy 4.1 — Complete Pin Map

| Pin | Function | Used By |
|-----|----------|---------|
| 0 | Serial1 RX | CrowPanel UART |
| 1 | Serial1 TX | CrowPanel UART |
| 2 | Digital Input | Button 1 (Play) |
| 3 | I2S2 LRCLK | INMP441 / ESP32-S3 Audio Bridge |
| 4 | I2S2 BCLK | INMP441 / ESP32-S3 Audio Bridge |
| 5 | I2S2 DATA | INMP441 / ESP32-S3 Audio Bridge |
| 6 | Digital Input | Button 2 (Record) |
| 7 | I2S BCLK | Audio Shield |
| 8 | I2S LRCLK | Audio Shield |
| 9 | Digital Input | Button 3 (Mode) |
| 10 | SPI CS | Audio Shield SD |
| 11 | SPI MOSI | Audio Shield SD |
| 12 | SPI MISO | Audio Shield SD |
| 13 | SPI SCK | Audio Shield SD |
| 14 | Serial3 TX | MIDI OUT (ubld.it) |
| 15 | Serial3 RX | MIDI IN (ubld.it) |
| 16 (A2) | Analog Input | Pot 1 (Cutoff) |
| 17 (A3) | Analog Input | Pot 2 (Resonance) |
| 18 | I2C SCL | Audio Shield |
| 19 | I2C SDA | Audio Shield |
| 20 | I2S TX | Audio Shield |
| 21 | I2S RX | Audio Shield |
| 22 | Digital Input | Button 4 (Shift) |
| 23 | I2S MCLK | Audio Shield |
| 24 (A4) | Analog Input | Pot 3 (Attack/Decay) |
| 25 (A5) | Analog Input | Pot 4 (Volume) |
| 34 | Serial8 RX | ESP32-S3 Audio Bridge control |
| 35 | Serial8 TX | ESP32-S3 Audio Bridge control |
| USB Host | 5-pin header (bottom) | USB Hub → Launchpad |

**Free pins for future expansion:** 26–33, 36–39 (12+ pins)

---

## Prototyping Order

### Phase 1: Audio Core
Stack Audio Shield on Teensy. Play a tone through headphones.

### Phase 2: Controls
Wire 4 pots + 4 buttons. Test with serial monitor.

### Phase 3: Audio Input
Wire TRS jacks to Audio Shield. Test pass-through.

### Phase 4: INMP441 Microphone
Wire mic to I2S2. Test recording.

### Phase 5: MIDI I/O
Wire ubld.it breakout. Send/receive MIDI notes.

### Phase 6: USB Host (Launchpad)
Solder USB host header. Connect hub + Launchpad. Test USB MIDI.

### Phase 7: CrowPanel UI
Wire UART to Teensy. Build touch UI. Test two-way comms.

### Phase 8: Integration
All subsystems working together on breadboard.

### Phase 9: ESP32-S3 Audio Bridge (Experimental)
Set up ESP-IDF. Implement USB Audio host. Bridge audio to Teensy via I2S2.

### Phase 10: Enclosure & Panel
Transfer to perfboard. Mount USB-C, TRS, pots, buttons. Final testing.

---

## Tools Needed

- Soldering iron (temperature-controlled, ~$30)
- Solder (60/40 or 63/37 leaded for beginners)
- Wire strippers + flush cutters
- Multimeter (any cheap one)
- Helping hands / PCB holder
- Heat shrink tubing
