# Sampler-Crow: Hardware Design Document (v3)

**Updated:** 2026-04-11
**Major changes from v2:**
- **ESP32-S3 audio bridge removed**. Honest technical reality: neither ESP32-S3 nor Teensy 4.1 can reliably host a class-compliant USB audio interface in firmware. This was a dead-end.
- **Power strategy** fully specified with a current budget.
- **USB hub moved to a powered hub** because bus power alone is insufficient once a Launchpad and any second USB device are connected.
- Audio I/O simplified: Audio Shield SGTL5000 handles all analog I/O. Multi-channel USB interface support deferred to a later "companion mode" where the Sampler-Crow becomes a USB device plugged into a computer that already has the interface.
- MIDI TRS I/O retained via ubld.it breakout board.

---

## 1. The honest USB audio host question (read this first)

You asked:
> "Can the Teensy 4.1 itself be the class-compliant USB audio host for a Universal Audio Volt (up to 8 channels in)?"

**Short answer: No, not practically.** Here is why, in detail, so you can decide what trade-off you want.

### 1.1 What the Teensy 4.1 hardware can do

The i.MX RT1062 on the Teensy 4.1 has **two independent USB 2.0 Hi-Speed (480 Mbps) controllers**:
- **USB1** = the micro-USB port on top — used as a **device** (appears to a host computer as USB Audio + MIDI + Serial, which is what our macOS host app talks to today).
- **USB2** = the five pads on the bottom labeled `5V / GND / D- / D+ / ID` — used as a **host**, with the Paul Stoffregen `USBHost_t36` library.

Both controllers run at the same time with no conflict. We already use USB1 as a device and USB2 as a host (for the Launchpad — in the future build) with no issue on the RT1062 silicon.

So the *silicon* is capable. The problem is entirely software.

### 1.2 What the firmware actually supports

I checked the installed `USBHost_t36` library and the Teensyduino core:

- `USBHost_t36` ships drivers for: USB hub, HID (keyboard/mouse/joystick), **USB MIDI**, USB mass storage, FTDI/CH34x serial, Bluetooth HCI, and Android Accessory (ADK). **There is no USB Audio Class host driver.** I grepped the entire library and checked the class headers — zero hits for `AudioStream`, `UAC`, `kAudioFormat`, or any audio class descriptor handling.
- `AudioInputUSB` / `AudioOutputUSB` in the Teensy Audio Library are **device-mode only**. They make the Teensy *appear as* a USB audio interface to a connected host computer (what we use now). They cannot consume audio from a USB audio device connected to the Teensy's host port.
- PJRC forum threads have experimented with USB Audio Class host, but nothing is in the mainline, nothing is stable, nothing does multi-channel, and it would be a several-month firmware project of its own even to get stereo in.

### 1.3 Why this is harder than USB MIDI (which does work)

USB MIDI uses bulk transfers: small, infrequent, loss-tolerant, easy. USB Audio Class 2.0 uses **isochronous transfers** with Start-of-Frame synchronization, asynchronous clock feedback, and a continuous 1.4 MB/s data stream for 8 channels at 44.1 kHz stereo float. Handling that in the `USBHost_t36` EHCI driver — simultaneously with running the sampler/sequencer/effects engine — is a completely different class of problem. The RT1062 has the MIPS headroom in theory. In practice, nobody has shipped a working implementation.

### 1.4 What about the ESP32-S3 bridge approach from v2?

No better. The ESP32-S3 has a single USB OTG controller at only Full-Speed (12 Mbps), which is technically below the USB 2.0 Hi-Speed rates the Volt expects. The ESP-IDF `usb_stream` / `usb_host_uac` components exist but are limited to 2-channel and still unstable. And you would have to write an I2S bridge between the ESP32-S3 and the Teensy and worry about clock drift between the two domains. **Remove the ESP32-S3 bridge entirely.**

### 1.5 What we should do instead

Three workable options, in order of practicality:

**Option A — Audio Shield is the "interface" (recommended).** The Teensy Audio Shield Rev D has an SGTL5000 codec with stereo line in, stereo line out, headphone out, and a mic in. That's our panel I/O. No USB audio host needed at all. This is what the software already works with.

**Option B — Add a higher-quality on-board codec.** If you want better than the SGTL5000's ~96 dB SNR, swap the Audio Shield for a direct I2S codec like the PCM1808 (ADC) + PCM5102A (DAC), or a WM8731, or use the Teensy's second I2S bus for an additional codec. Still no USB audio host involved.

**Option C — "Companion mode" for the Volt.** Treat the Sampler-Crow as a standalone instrument that *outputs* to the Volt via analog cables (TRS from Sampler-Crow into Volt 1/2 line inputs). If the user wants the Volt's multi-channel recording, the Volt plugs into their *computer*, not into the Sampler-Crow. The Sampler-Crow's USB1 device port can simultaneously appear to that computer as a second audio device + MIDI controller, so everything still shows up in the DAW. This is actually how Dirtywave M8, Teenage Engineering OP-1, Polyend Tracker, and Elektron Syntakt all do it — they don't host USB audio interfaces, they either have their own codec or use their USB port as a device.

**Verdict: do Option A + Option C combined.** The Audio Shield handles on-device monitoring and the analog TRS ports you listed. When the user wants to use their Volt or any other interface, they plug the Sampler-Crow's micro-USB into their computer alongside the Volt, and the Volt is their audio interface, not the Sampler-Crow's.

---

## 2. Revised architecture (v3)

```
                    ┌──────────────────────────────────┐
                    │  Elecrow CrowPanel 5.0" HMI      │
                    │  (ESP32-S3-WROOM-1 N4R8)         │
USB-C (power + ── ─ │  800x480 capacitive touch         │
programming)        │  LVGL UI                          │
                    │                                    │
                    │  TX (GPIO 10) ──┐                 │
                    │  RX (GPIO  9) ─┐│                 │
                    │  GND ─────────┐││                 │
                    └───────────────┼┼┼─────────────────┘
                                    │││ UART @ 921600
                                    │││
┌───────────────────────────────────┼┼┼──────────────────────┐
│  Teensy 4.1  +  Audio Shield Rev D│││                      │
│  ARM Cortex-M7 @ 600 MHz          │││                      │
│                                    │││                      │
│  Serial1 RX (Pin 0) ───────────────┘│                      │
│  Serial1 TX (Pin 1) ────────────────┘                      │
│  GND ───────────────────────────────                       │
│                                                             │
│  ┌────────────────────────┐                                │
│  │ Audio Shield (SGTL5000)│                                │
│  │  LINE OUT L/R → ────── │──→ TRS Line Out  (rear panel) │
│  │  LINE IN  L/R ← ────── │←── TRS Line In   (rear panel) │
│  │  HP OUT   L/R → ────── │──→ TRS Headphone (rear panel) │
│  │  µSD slot (samples)    │                                │
│  └────────────────────────┘                                │
│                                                             │
│  Serial3 TX (Pin 14) ──→ ubld.it ──→ TRS MIDI Out          │
│  Serial3 RX (Pin 15) ←── ubld.it ←── TRS MIDI In           │
│                                                             │
│  A2-A5 ← 4 Potentiometers                                  │
│  D2,D6,D9,D22 ← 4 Tactile Buttons                          │
│                                                             │
│  USB Device port (micro-USB on top):                       │
│    ──→ Internal micro-USB-to-USB-C panel cable             │
│    ──→ USB-C "COMPUTER" on rear panel                      │
│    (exposes Sampler-Crow as Serial+MIDI+Audio to a Mac/PC) │
│                                                             │
│  USB Host pads (bottom 5 pads):                            │
│    ──→ Powered USB hub inside enclosure                    │
│    ────→ USB-C "CONTROLLER" on rear panel (Launchpad)      │
│    ────→ (expansion port for 2nd MIDI device)              │
│                                                             │
│  External 5V / 3A input ──→ VIN pin (powers Teensy + hub)  │
└─────────────────────────────────────────────────────────────┘
```

**What is different from v2:**
- Removed: ESP32-S3 audio bridge, dev board BOM line, INMP441 mic, the I2S2 bus wiring, Serial8 control link, the USB-C "AUDIO INTERFACE" panel port.
- Added: explicit powered USB hub, explicit 5V 3A power input, upgraded CrowPanel to 5" 800×480, powering strategy section below.
- Kept: Audio Shield, ubld.it MIDI breakout, pots, buttons, USB host for Launchpad.

---

## 3. Panel layout (v3)

```
┌────────────────────────────────────────────────────────────┐
│                         FRONT PANEL                        │
│                                                            │
│   ┌─────────────────────┐   [POT1] [POT2] [POT3] [POT4]  │
│   │  CrowPanel 5.0"    │                                  │
│   │  800 x 480 touch   │    [BTN1] [BTN2] [BTN3] [BTN4]  │
│   └─────────────────────┘                                  │
├────────────────────────────────────────────────────────────┤
│                          REAR PANEL                        │
│                                                            │
│   5V DC    USB-C      USB-C     LINE  LINE  HEAD  MIDI MIDI │
│   3A IN    COMPUTER   CTRLR     IN    OUT   PHONE OUT  IN  │
│   ⊙         ◯          ◯         ◯     ◯     ◯     ◯    ◯  │
└────────────────────────────────────────────────────────────┘
```

**Port definitions:**
1. **5V DC IN** — barrel jack (2.5 × 5.5 mm center positive) OR USB-C PD input. Supplies power to the whole system and downstream USB devices. Spec: 5 V ±5 %, minimum 2 A continuous, 3 A recommended.
2. **USB-C COMPUTER** — Teensy's device-side USB1 port, routed out via a micro-USB-to-USB-C panel adapter. The Sampler-Crow shows up on a computer as a composite Serial + MIDI + Audio device (this is what the macOS host app already uses).
3. **USB-C CONTROLLER** — Teensy's host-side USB2 port via the internal powered hub. Plug a Novation Launchpad Mini MK3 (or any USB MIDI controller) here. The hub inside has a second unused port for expansion.
4. **LINE IN** — 3.5 mm TRS stereo, Audio Shield LINE IN.
5. **LINE OUT** — 3.5 mm TRS stereo, Audio Shield LINE OUT.
6. **HEADPHONE** — 3.5 mm TRS stereo, Audio Shield HP OUT.
7. **MIDI OUT** — 3.5 mm TRS Type A, ubld.it breakout.
8. **MIDI IN** — 3.5 mm TRS Type A, ubld.it breakout.

---

## 4. Power strategy

This is the section that was missing from v2. Do not skip it.

### 4.1 Power budget (worst case, all loads active)

| Rail | Consumer | Typical | Peak | Notes |
|---|---|---|---|---|
| 5 V | Teensy 4.1 (MCU + 3.3 V LDO) | 100 mA | 150 mA | at 600 MHz |
| 5 V | Audio Shield (SGTL5000 + codec) | 20 mA | 30 mA | |
| 5 V | CrowPanel 5" display (backlight + ESP32-S3) | 250 mA | 400 mA | backlight dominates |
| 5 V | Novation Launchpad Mini MK3 (via hub) | 200 mA | 500 mA | rated max per USB spec |
| 5 V | Internal USB hub (controller) | 30 mA | 50 mA | 4-port hub IC |
| 5 V | Second USB port headroom (future expansion) | 0 mA | 500 mA | reserved |
| 5 V | 4 pots + 4 buttons + MIDI opto | ~10 mA | ~10 mA | negligible |
| **Total** | | **~610 mA** | **~1.64 A** | |

- **Minimum supply**: 5 V / 1.5 A → works without the expansion USB port being used.
- **Recommended supply**: 5 V / 3 A → comfortable margin, allows the second USB port to bus-power a device.
- **Not practical on bus power from a computer**: a standard USB 2.0 port provides only 500 mA. We will exceed that the moment the Launchpad lights up. The Sampler-Crow needs its own power input.

### 4.2 Power source options

**Recommended: 5 V barrel jack with an external 5 V / 3 A wall wart.**
- Simple, cheap, rock-solid, plenty of headroom.
- BOM: panel-mount 2.1 × 5.5 mm barrel jack (~$2), Mean Well GS18A05-P1J or similar 18 W USB wall adapter (~$12), DC pigtail cable with 2.1 mm plug.
- The wall wart goes in the box with the instrument.

**Alternative: USB-C PD at 5 V / 3 A.**
- More modern-looking, only one power brick needed (reuse phone charger).
- Requires a USB-C PD sink controller IC (e.g., CH224K, ~$1) that negotiates 5 V at 3 A from a PD charger. Without the IC, most PD chargers default to 5 V / 500 mA. The CH224K is a tiny SOT23-6 chip, one resistor configures the requested voltage, dead simple.
- BOM add: CH224K breakout board (~$3) + USB-C panel mount (~$4).

**Not recommended: bus-powered from the computer USB-C COMPUTER port.**
- A standard laptop USB-C port can sometimes deliver 1.5 A at 5 V, but that is *far* below our peak budget and the computer might not negotiate high current. Also: the user wants to use the Sampler-Crow standalone, disconnected from a computer, and be able to play back via line out or headphones.

**Battery option (deferred to a later hardware revision):**
- 3.7 V Li-Po battery + TP4056 charger IC + 5 V boost converter (e.g., MT3608). Realistic runtime: ~2 hours with a 2000 mAh cell given the 600 mA typical draw. Viable but adds complexity and BMS concerns. Punt on this for v1.

**Chosen approach for this build: barrel jack + external 5 V / 3 A brick.**

### 4.3 Power distribution inside the enclosure

```
         5 V / 3 A external supply
                   │
                   ▼
        [2.1 mm barrel jack]
                   │
        ┌──────────┼──────────────┐
        │          │               │
        │          │               │
    [Schottky  [Bulk cap    [Polyfuse 1.5 A
     diode]    1000 uF]      (VBUS path)]
        │          │               │
        ▼          ▼               ▼
        5V rail common    ────────────┐
        │                              │
        ├──→ Teensy 4.1 VIN pin       │
        │    (onboard reg → 3.3 V for Teensy + Audio Shield + pots)
        │                              │
        ├──→ CrowPanel 5" 5V input    │
        │                              │
        └──→ Powered USB hub VBUS IN ──┘
                   │
                   ├──→ Hub USB-A port 1 → USB-C "CONTROLLER" panel (Launchpad)
                   └──→ Hub USB-A port 2 → (expansion)
```

**Important wiring notes:**
- **Do NOT** feed power from the "USB-C COMPUTER" port into the system. That port is a *device* port — the computer on the other side expects *us* to draw power from it, not the reverse. Leave its VBUS line pulled up via a 47 kΩ resistor (for enumeration detection) and otherwise do not connect it to the system's 5 V rail. The Teensy handles this correctly by default when VIN is used.
- Cut the VUSB-to-VIN pad on the underside of the Teensy 4.1. This is a standard Teensy step when you want to power the Teensy from VIN without back-feeding the USB device port. PJRC documents it. One scalpel cut.
- The Schottky diode on the barrel jack input protects against reverse polarity (plug the wrong supply in and nothing fries).
- The 1000 µF bulk cap absorbs the current spike when the Launchpad's LEDs all turn on at once.
- The polyfuse on the VBUS path to the hub limits downstream current in case a faulty USB device shorts.

### 4.4 USB host port current

The Teensy's USB2 controller does **not** source meaningful current from the `5V` pad on its own. We have to provide 5 V to the hub from our system rail. Specifically, the 5 V pad on the USB host pads of the Teensy is simply the Teensy's VUSB line brought out; it can sink/source a few hundred mA if VUSB is connected, but it is *not* a switched, fused, current-limited USB host port. We bypass it entirely and wire the hub's VBUS IN directly to our system 5 V rail, through a polyfuse, and we only use the D+ / D- / GND lines from the Teensy's USB2 pads.

```
  Teensy 4.1 bottom USB host pads:

  ┌──────────────┐
  │  5V GND D- D+ ID
  │   │   │  │  │  │
  │   x   │  │  │  x     ← leave 5V and ID pads UNCONNECTED
  │       │  │  │
  └───────┼──┼──┼─
          │  │  │
          ▼  ▼  ▼
         GND D- D+   → wire these three to the hub IC's upstream port
                       (or to the SparkFun Teensy USB Host Cable's GND/D-/D+)

  System 5 V rail ──→ [polyfuse 1A] ──→ Hub VBUS IN  (separate from Teensy)
```

This is the single most important change from v2: in v2 we relied on the Teensy's VUSB to power the Launchpad, and it would have browned out. In v3, the hub has its own 5 V rail directly from the supply.

---

## 5. Updated BOM

### Core

| # | Component | Est. Price |
|---|---|---|
| 1 | Teensy 4.1 with pins pre-soldered | ~$49 |
| 2 | Teensy Audio Shield Rev D (SGTL5000) | ~$14 |
| 3 | **CrowPanel 5.0" HMI** (ESP32-S3-WROOM-1-N4R8, 800×480 cap touch, Amazon B0G1RXXM94) | ~$60 |

### Audio / MIDI I/O

| # | Component | Est. Price |
|---|---|---|
| 4 | ubld.it MIDI Breakout MV (opto-isolated, 3.3/5 V) | ~$25 |
| 5 | 3.5 mm TRS panel jacks ×5 (line in, line out, hp out, midi in, midi out) | ~$7 |

### USB

| # | Component | Est. Price |
|---|---|---|
| 6 | SparkFun USB Host Cable for Teensy 4.1 (5-pin to USB-A female) — **only used for the D+/D-/GND, not 5 V** | ~$4 |
| 7 | **Powered** USB 2.0 hub (4-port, small form factor, e.g., Anker A7516 or similar compact hub with external power input) | ~$15 |
| 8 | USB-C panel mount male-to-female pigtails ×2 (for COMPUTER and CONTROLLER ports) | ~$8 |
| 9 | micro-USB-to-USB-C adapter for the COMPUTER port | ~$4 |

### Power

| # | Component | Est. Price |
|---|---|---|
| 10 | 5 V / 3 A DC wall adapter with 2.1 mm barrel plug (Mean Well GS18A05-P1J or equivalent) | ~$12 |
| 11 | Panel-mount 2.1 × 5.5 mm barrel jack | ~$2 |
| 12 | Schottky diode 1N5819 or SS34 (reverse polarity protection) | ~$1 |
| 13 | 1000 µF / 16 V electrolytic cap + 0.1 µF ceramic | ~$2 |
| 14 | 1.5 A polyfuse (resettable) ×2 (one for main, one for USB hub VBUS) | ~$3 |

### Controls / Mechanical

| # | Component | Est. Price |
|---|---|---|
| 15 | B10K potentiometers ×4 with knobs | ~$9 |
| 16 | 12 mm tactile buttons ×4 with caps | ~$5 |
| 17 | MicroSD card 32 GB (sample storage) | ~$8 |
| 18 | 22 AWG hookup wire 6 colors | ~$10 |
| 19 | Perfboard / prototype PCB | ~$8 |

### Removed from v2
- ESP32-S3 dev board (audio bridge) — technically dead end, see §1
- INMP441 mic + its wiring — not needed with the Audio Shield line input
- I2S2 bus wiring (pins 3, 4, 5) — freed for other uses
- Serial8 UART bridge — no longer needed

### Revised total: ~$245
Up ~$30 from v2, mostly because of the 5" display upgrade and the powered hub. In return you drop the complexity of the broken ESP32 bridge and you get a known-working powered USB host.

---

## 6. Pin allocation (v3)

Freed pins from dropping ESP32 bridge: I2S2 bus (pins 3, 4, 5) and Serial8 (pins 34, 35).

| Teensy Pin | Function | Used by |
|---|---|---|
| 0 | Serial1 RX | CrowPanel UART |
| 1 | Serial1 TX | CrowPanel UART |
| 2 | Digital in | Button 1 (Play) |
| 3 | *free* | (was INMP441 WS) |
| 4 | *free* | (was INMP441 SCK) |
| 5 | *free* | (was INMP441 SD) |
| 6 | Digital in | Button 2 (Record) |
| 7 | I2S BCLK | Audio Shield |
| 8 | I2S LRCLK | Audio Shield |
| 9 | Digital in | Button 3 (Mode) |
| 10 | SPI CS | Audio Shield SD |
| 11 | SPI MOSI | Audio Shield SD |
| 12 | SPI MISO | Audio Shield SD |
| 13 | SPI SCK | Audio Shield SD |
| 14 | Serial3 TX | MIDI OUT (ubld.it) |
| 15 | Serial3 RX | MIDI IN (ubld.it) |
| 16 (A2) | Analog in | Pot 1 |
| 17 (A3) | Analog in | Pot 2 |
| 18 | I2C SCL | Audio Shield |
| 19 | I2C SDA | Audio Shield |
| 20 | I2S TX | Audio Shield |
| 21 | I2S RX | Audio Shield |
| 22 | Digital in | Button 4 (Shift) |
| 23 | I2S MCLK | Audio Shield |
| 24 (A4) | Analog in | Pot 3 |
| 25 (A5) | Analog in | Pot 4 |
| USB Host pads | D-, D+, GND only | Powered hub → Launchpad |
| VIN | 5 V input from main rail | (after cutting VUSB→VIN pad) |
| 26–39 | free | Future expansion |

---

## 7. Build order (revised)

1. **Power supply bench test.** Barrel jack → Schottky → bulk cap → multimeter reading 5 V steady. No load yet.
2. **Teensy power.** Cut the VUSB-to-VIN pad under the Teensy (scalpel, one bridge). Wire 5 V rail to VIN and GND to GND. Confirm Teensy boots (LED blink sketch) with *nothing* connected to its micro-USB.
3. **Audio Shield.** Stack onto Teensy. Upload tone test. Hear 440 Hz through headphones into TRS jack.
4. **Controls.** 4 pots, 4 buttons. Verify in serial monitor.
5. **MIDI TRS I/O.** Wire ubld.it. Send notes from a MIDI keyboard into IN; verify in serial monitor. Echo notes to OUT; verify on another MIDI device.
6. **CrowPanel UART.** Wire RX/TX/GND. Confirm bidirectional text echo.
7. **USB host — hub first.** Plug hub into Teensy USB host pads (D+/D-/GND only, *not* 5V). Wire hub VBUS from system 5 V rail through polyfuse. Power on. Plug a known-working USB MIDI device (KeyStep, Launchpad) into the hub. Verify `USBHost_t36` MIDI example detects it.
8. **Full integration.** Run the current Sampler-Crow firmware end-to-end with all peripherals. Measure total current draw at 5 V input with a USB meter. Compare against the budget in §4.1. If actual exceeds 1.5 A continuous, investigate before closing up the enclosure.
9. **Perfboard transfer.** Once everything works on breadboard.
10. **Enclosure / panel.** Drill, mount, label. Final product.

---

## 8. Future: if we really need the Volt

You might still want the Volt eventually. Here are the two realistic paths:

**Path 1: Sampler-Crow as a USB device alongside the Volt on a computer.** No hardware change. When the user wants 8-channel recording, they plug the Sampler-Crow's USB-C COMPUTER port into their laptop alongside the Volt, open their DAW, and record everything together. Sampler-Crow shows up as `Sampler-Crow (2 in / 2 out)` + `Sampler-Crow MIDI`, the Volt shows up as `Volt 476 (4 in / 4 out)`. This is what most portable instruments actually do.

**Path 2: Co-processor for USB audio host.** Add a Raspberry Pi Zero 2 W (or similar Linux SBC with a working USB Audio Class 2 host stack) inside the enclosure, connected to the Teensy via I2S slave mode. The Pi runs ALSA, hosts the Volt, and pipes audio over I2S into the Teensy's second I2S bus. This is a real engineering project — boot time, shared power, clock sync, audio latency — but it would actually work. Defer this until the rest of v1 is shipping and we know we need it.

Do not add either of these to v1. v1 ships with Audio Shield analog I/O only.

---

## 9. What to tell yourself when you are tempted to add USB audio host back in

- Dirtywave M8 uses a CS4272 codec. No USB audio host.
- Teenage Engineering OP-1 uses a CS4272 codec. No USB audio host.
- Polyend Tracker uses a TLV320 codec. No USB audio host.
- Elektron Syntakt uses an on-board codec. No USB audio host.
- Elektron Digitakt II uses an on-board codec. Its USB is a *device* port for the Overbridge plugin, not a host for external interfaces.

None of these professional products hosts an external USB audio interface in firmware. They all use a built-in codec and expose themselves *as* a USB audio device to a computer if integration is needed. That is the pattern to follow.

---

## 10. Summary of decisions

| Question | Decision |
|---|---|
| Can Teensy be USB audio host for Volt? | No, not in any practical firmware that exists today. |
| Should we keep the ESP32-S3 audio bridge? | No. It does not work either. Delete it from the BOM. |
| Where does main audio I/O come from? | Audio Shield SGTL5000 — TRS line in, line out, headphone out. |
| How do we connect the Launchpad? | Teensy USB host pads → powered USB hub → USB-C panel port. |
| How does the system get power? | External 5 V / 3 A brick via barrel jack. Cut VUSB→VIN pad on Teensy. |
| Does the USB-C COMPUTER port source or sink power? | Sinks only. Do not back-feed it. It's a device port. |
| What if we need 8-channel recording? | Plug Sampler-Crow into a computer via USB-C COMPUTER port alongside the Volt. Record both in a DAW. No in-device USB audio hosting. |
| Total current budget | 0.6 A typical, 1.6 A peak at 5 V. 3 A supply gives comfortable headroom. |
