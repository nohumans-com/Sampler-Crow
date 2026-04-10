# Comprehensive Music Theory Reference — Keys, Chords, Scales & Progressions

> **Purpose**: This document serves as the authoritative data source for building a chord/key quantization engine. It provides every note spelling, chord formula, scale degree, inversion, and progression pattern needed to snap musical input to any target chord or key.

---

## Table of Contents

1. [Foundational Concepts](#1-foundational-concepts)
2. [The Circle of Fifths](#2-the-circle-of-fifths)
3. [Major Keys & Scales](#3-major-keys--scales)
4. [Minor Keys & Scales](#4-minor-keys--scales)
5. [Church Modes](#5-church-modes)
6. [Exotic & World Scales](#6-exotic--world-scales)
7. [Intervals Reference](#7-intervals-reference)
8. [Chord Construction — All Types](#8-chord-construction--all-types)
9. [Chord Inversions & Voicings](#9-chord-inversions--voicings)
10. [Diatonic Chords per Key](#10-diatonic-chords-per-key)
11. [Chord Progressions by Genre](#11-chord-progressions-by-genre)
12. [Borrowed Chords & Modal Interchange](#12-borrowed-chords--modal-interchange)
13. [Enharmonic Equivalence & Spelling Rules](#13-enharmonic-equivalence--spelling-rules)
14. [Data Structures for Implementation](#14-data-structures-for-implementation)

---

## 1. Foundational Concepts

### 1.1 The Chromatic Scale (12 Pitch Classes)

Using sharps:
```
C  C#  D  D#  E  F  F#  G  G#  A  A#  B
```

Using flats:
```
C  Db  D  Eb  E  F  Gb  G  Ab  A  Bb  B
```

MIDI note numbers (middle C = 60):
```
C=0, C#/Db=1, D=2, D#/Eb=3, E=4, F=5, F#/Gb=6, G=7, G#/Ab=8, A=9, A#/Bb=10, B=11
```
All pitch classes are modulo 12.

### 1.2 Enharmonic Equivalents

| Sharp Name | Flat Name | MIDI Class |
|-----------|-----------|------------|
| C         | C         | 0          |
| C#        | Db        | 1          |
| D         | D         | 2          |
| D#        | Eb        | 3          |
| E         | Fb        | 4          |
| E#        | F         | 5          |
| F#        | Gb        | 6          |
| G         | G         | 7          |
| G#        | Ab        | 8          |
| A         | A         | 9          |
| A#        | Bb        | 10         |
| B         | Cb        | 11         |

Double sharps (##/𝄪) and double flats (𝄫) also exist:
- C## = D, D## = E, F## = G, G## = A, A## = B
- Dbb = C, Ebb = D, Gbb = F, Abb = G, Bbb = A

### 1.3 Semitones and Intervals

| Semitones | Interval Name           | Abbreviation |
|-----------|------------------------|--------------|
| 0         | Perfect Unison (P1)    | P1           |
| 1         | Minor Second (m2)      | m2           |
| 2         | Major Second (M2)      | M2           |
| 3         | Minor Third (m3)       | m3           |
| 4         | Major Third (M3)       | M3           |
| 5         | Perfect Fourth (P4)    | P4           |
| 6         | Tritone / Aug 4th / Dim 5th | TT / A4 / d5 |
| 7         | Perfect Fifth (P5)     | P5           |
| 8         | Minor Sixth (m6)       | m6           |
| 9         | Major Sixth (M6)       | M6           |
| 10        | Minor Seventh (m7)     | m7           |
| 11        | Major Seventh (M7)     | M7           |
| 12        | Perfect Octave (P8)    | P8           |

Extended intervals (compound):

| Semitones | Interval Name          | Abbreviation |
|-----------|----------------------|--------------|
| 13        | Minor Ninth (m9)     | m9           |
| 14        | Major Ninth (M9)     | M9           |
| 15        | Minor Tenth (m10)    | m10          |
| 16        | Major Tenth (M10)    | M10          |
| 17        | Perfect Eleventh (P11)| P11         |
| 18        | Augmented Eleventh (#11) | A11 / #11 |
| 19        | Perfect Twelfth (P12) | P12         |
| 20        | Minor Thirteenth (m13)| m13         |
| 21        | Major Thirteenth (M13)| M13         |

---

## 2. The Circle of Fifths

### 2.1 Circle Layout

```
                    C (0 sharps/flats)
              F (1♭)                G (1#)
         B♭ (2♭)                      D (2#)
       E♭ (3♭)                          A (3#)
      A♭ (4♭)                            E (4#)
       D♭ (5♭)                          B (5#)
         G♭/F# (6♭/6#)
```

### 2.2 Key Signatures — Sharps Order

| Key Major | Key Minor | Sharps | Sharp Notes        |
|-----------|-----------|--------|--------------------|
| C major   | A minor   | 0      | —                  |
| G major   | E minor   | 1      | F#                 |
| D major   | B minor   | 2      | F# C#              |
| A major   | F# minor  | 3      | F# C# G#           |
| E major   | C# minor  | 4      | F# C# G# D#        |
| B major   | G# minor  | 5      | F# C# G# D# A#     |
| F# major  | D# minor  | 6      | F# C# G# D# A# E#  |
| C# major  | A# minor  | 7      | F# C# G# D# A# E# B# |

### 2.3 Key Signatures — Flats Order

| Key Major | Key Minor | Flats | Flat Notes          |
|-----------|-----------|-------|---------------------|
| C major   | A minor   | 0     | —                   |
| F major   | D minor   | 1     | Bb                  |
| Bb major  | G minor   | 2     | Bb Eb               |
| Eb major  | C minor   | 3     | Bb Eb Ab            |
| Ab major  | F minor   | 4     | Bb Eb Ab Db         |
| Db major  | Bb minor  | 5     | Bb Eb Ab Db Gb      |
| Gb major  | Eb minor  | 6     | Bb Eb Ab Db Gb Cb   |
| Cb major  | Ab minor  | 7     | Bb Eb Ab Db Gb Cb Fb|

### 2.4 Relative Major/Minor Pairs

Each major key shares a key signature with its relative minor (3 semitones below):

| Major | Relative Minor |
|-------|---------------|
| C     | Am            |
| G     | Em            |
| D     | Bm            |
| A     | F#m           |
| E     | C#m           |
| B     | G#m           |
| F#    | D#m           |
| Gb    | Ebm           |
| Db    | Bbm           |
| Ab    | Fm            |
| Eb    | Cm            |
| Bb    | Gm            |
| F     | Dm            |

### 2.5 Parallel Major/Minor Pairs

Same root, different mode (C major ↔ C minor). Every root note has both a parallel major and parallel minor.

---

## 3. Major Keys & Scales

Formula (in semitones): **W-W-H-W-W-W-H** → `[0, 2, 4, 5, 7, 9, 11]`

Scale degrees: `1  2  3  4  5  6  7`

| Key    | 1   | 2   | 3   | 4   | 5   | 6   | 7   |
|--------|-----|-----|-----|-----|-----|-----|-----|
| C      | C   | D   | E   | F   | G   | A   | B   |
| G      | G   | A   | B   | C   | D   | E   | F#  |
| D      | D   | E   | F#  | G   | A   | B   | C#  |
| A      | A   | B   | C#  | D   | E   | F#  | G#  |
| E      | E   | F#  | G#  | A   | B   | C#  | D#  |
| B      | B   | C#  | D#  | E   | F#  | G#  | A#  |
| F#     | F#  | G#  | A#  | B   | C#  | D#  | E#  |
| C#     | C#  | D#  | E#  | F#  | G#  | A#  | B#  |
| F      | F   | G   | A   | Bb  | C   | D   | E   |
| Bb     | Bb  | C   | D   | Eb  | F   | G   | A   |
| Eb     | Eb  | F   | G   | Ab  | Bb  | C   | D   |
| Ab     | Ab  | Bb  | C   | Db  | Eb  | F   | G   |
| Db     | Db  | Eb  | F   | Gb  | Ab  | Bb  | C   |
| Gb     | Gb  | Ab  | Bb  | Cb  | Db  | Eb  | F   |
| Cb     | Cb  | Db  | Eb  | Fb  | Gb  | Ab  | Bb  |

---

## 4. Minor Keys & Scales

### 4.1 Natural Minor

Formula: **W-H-W-W-H-W-W** → `[0, 2, 3, 5, 7, 8, 10]`

Scale degrees: `1  2  ♭3  4  5  ♭6  ♭7`

| Key    | 1   | 2   | ♭3  | 4   | 5   | ♭6  | ♭7  |
|--------|-----|-----|-----|-----|-----|-----|-----|
| Am     | A   | B   | C   | D   | E   | F   | G   |
| Em     | E   | F#  | G   | A   | B   | C   | D   |
| Bm     | B   | C#  | D   | E   | F#  | G   | A   |
| F#m    | F#  | G#  | A   | B   | C#  | D   | E   |
| C#m    | C#  | D#  | E   | F#  | G#  | A   | B   |
| G#m    | G#  | A#  | B   | C#  | D#  | E   | F#  |
| D#m    | D#  | E#  | F#  | G#  | A#  | B   | C#  |
| A#m    | A#  | B#  | C#  | D#  | E#  | F#  | G#  |
| Dm     | D   | E   | F   | G   | A   | Bb  | C   |
| Gm     | G   | A   | Bb  | C   | D   | Eb  | F   |
| Cm     | C   | D   | Eb  | F   | G   | Ab  | Bb  |
| Fm     | F   | G   | Ab  | Bb  | C   | Db  | Eb  |
| Bbm    | Bb  | C   | Db  | Eb  | F   | Gb  | Ab  |
| Ebm    | Eb  | F   | Gb  | Ab  | Bb  | Cb  | Db  |
| Abm    | Ab  | Bb  | Cb  | Db  | Eb  | Fb  | Gb  |

### 4.2 Harmonic Minor

Formula: **W-H-W-W-H-W+H-H** → `[0, 2, 3, 5, 7, 8, 11]`

Scale degrees: `1  2  ♭3  4  5  ♭6  7`

Raises the 7th degree of natural minor by one semitone to create a leading tone.

| Key    | 1   | 2   | ♭3  | 4   | 5   | ♭6  | 7   |
|--------|-----|-----|-----|-----|-----|-----|-----|
| Am     | A   | B   | C   | D   | E   | F   | G#  |
| Em     | E   | F#  | G   | A   | B   | C   | D#  |
| Bm     | B   | C#  | D   | E   | F#  | G   | A#  |
| F#m    | F#  | G#  | A   | B   | C#  | D   | E#  |
| C#m    | C#  | D#  | E   | F#  | G#  | A   | B#  |
| Dm     | D   | E   | F   | G   | A   | Bb  | C#  |
| Gm     | G   | A   | Bb  | C   | D   | Eb  | F#  |
| Cm     | C   | D   | Eb  | F   | G   | Ab  | B   |
| Fm     | F   | G   | Ab  | Bb  | C   | Db  | E   |
| Bbm    | Bb  | C   | Db  | Eb  | F   | Gb  | A   |

### 4.3 Melodic Minor (Ascending)

Formula: **W-H-W-W-W-W-H** → `[0, 2, 3, 5, 7, 9, 11]`

Scale degrees: `1  2  ♭3  4  5  6  7`

Raises both the 6th and 7th degrees. (In classical usage, descending = natural minor.)

| Key    | 1   | 2   | ♭3  | 4   | 5   | 6   | 7   |
|--------|-----|-----|-----|-----|-----|-----|-----|
| Am     | A   | B   | C   | D   | E   | F#  | G#  |
| Em     | E   | F#  | G   | A   | B   | C#  | D#  |
| Bm     | B   | C#  | D   | E   | F#  | G#  | A#  |
| Dm     | D   | E   | F   | G   | A   | B   | C#  |
| Gm     | G   | A   | Bb  | C   | D   | E   | F#  |
| Cm     | C   | D   | Eb  | F   | G   | A   | B   |
| Fm     | F   | G   | Ab  | Bb  | C   | D   | E   |
| Bbm    | Bb  | C   | Db  | Eb  | F   | G   | A   |

---

## 5. Church Modes

All modes are rotations of the major scale. Each has a distinct interval pattern and color.

### 5.1 Mode Formulas

| Mode        | Degree | Formula (semitones)        | Character   | Interval Pattern |
|-------------|--------|---------------------------|-------------|-----------------|
| Ionian      | I      | `[0,2,4,5,7,9,11]`       | Major       | W-W-H-W-W-W-H  |
| Dorian      | II     | `[0,2,3,5,7,9,10]`       | Minor       | W-H-W-W-W-H-W  |
| Phrygian    | III    | `[0,1,3,5,7,8,10]`       | Minor/Dark  | H-W-W-W-H-W-W  |
| Lydian      | IV     | `[0,2,4,6,7,9,11]`       | Major/Bright| W-W-W-H-W-W-H  |
| Mixolydian  | V      | `[0,2,4,5,7,9,10]`       | Major/Blues  | W-W-H-W-W-H-W  |
| Aeolian     | VI     | `[0,2,3,5,7,8,10]`       | Natural Min | W-H-W-W-H-W-W  |
| Locrian     | VII    | `[0,1,3,5,6,8,10]`       | Diminished  | H-W-W-H-W-W-W  |

### 5.2 All Modes Spelled Out for Each Root

#### Modes of C

| Mode       | Notes                      |
|------------|---------------------------|
| C Ionian   | C D E F G A B              |
| C Dorian   | C D Eb F G A Bb            |
| C Phrygian | C Db Eb F G Ab Bb          |
| C Lydian   | C D E F# G A B             |
| C Mixolydian| C D E F G A Bb            |
| C Aeolian  | C D Eb F G Ab Bb           |
| C Locrian  | C Db Eb F Gb Ab Bb         |

#### Modes of D

| Mode       | Notes                      |
|------------|---------------------------|
| D Ionian   | D E F# G A B C#            |
| D Dorian   | D E F G A B C              |
| D Phrygian | D Eb F G A Bb C            |
| D Lydian   | D E F# G# A B C#           |
| D Mixolydian| D E F# G A B C            |
| D Aeolian  | D E F G A Bb C             |
| D Locrian  | D Eb F G Ab Bb C           |

#### Modes of E

| Mode       | Notes                      |
|------------|---------------------------|
| E Ionian   | E F# G# A B C# D#          |
| E Dorian   | E F# G A B C# D            |
| E Phrygian | E F G A B C D              |
| E Lydian   | E F# G# A# B C# D#         |
| E Mixolydian| E F# G# A B C# D          |
| E Aeolian  | E F# G A B C D             |
| E Locrian  | E F G A Bb C D             |

#### Modes of F

| Mode       | Notes                      |
|------------|---------------------------|
| F Ionian   | F G A Bb C D E             |
| F Dorian   | F G Ab Bb C D Eb           |
| F Phrygian | F Gb Ab Bb C Db Eb         |
| F Lydian   | F G A B C D E              |
| F Mixolydian| F G A Bb C D Eb           |
| F Aeolian  | F G Ab Bb C Db Eb          |
| F Locrian  | F Gb Ab Bb Cb Db Eb        |

#### Modes of G

| Mode       | Notes                      |
|------------|---------------------------|
| G Ionian   | G A B C D E F#             |
| G Dorian   | G A Bb C D E F             |
| G Phrygian | G Ab Bb C D Eb F           |
| G Lydian   | G A B C# D E F#            |
| G Mixolydian| G A B C D E F             |
| G Aeolian  | G A Bb C D Eb F            |
| G Locrian  | G Ab Bb C Db Eb F          |

#### Modes of A

| Mode       | Notes                      |
|------------|---------------------------|
| A Ionian   | A B C# D E F# G#           |
| A Dorian   | A B C D E F# G             |
| A Phrygian | A Bb C D E F G             |
| A Lydian   | A B C# D# E F# G#          |
| A Mixolydian| A B C# D E F# G           |
| A Aeolian  | A B C D E F G              |
| A Locrian  | A Bb C D Eb F G            |

#### Modes of B

| Mode       | Notes                      |
|------------|---------------------------|
| B Ionian   | B C# D# E F# G# A#         |
| B Dorian   | B C# D E F# G# A           |
| B Phrygian | B C D E F# G A             |
| B Lydian   | B C# D# E# F# G# A#        |
| B Mixolydian| B C# D# E F# G# A         |
| B Aeolian  | B C# D E F# G A            |
| B Locrian  | B C D E F G A              |

### 5.3 Modes of Harmonic Minor

These are generated by rotating the harmonic minor scale:

| Mode Name (common)              | Degree | Formula (semitones)        |
|---------------------------------|--------|---------------------------|
| Harmonic Minor                  | I      | `[0,2,3,5,7,8,11]`       |
| Locrian ♮6                      | II     | `[0,1,3,5,6,9,10]`       |
| Ionian Augmented                | III    | `[0,2,4,5,8,9,11]`       |
| Dorian #4 (Romanian)            | IV     | `[0,2,3,6,7,9,10]`       |
| Phrygian Dominant (Freygish)    | V      | `[0,1,4,5,7,8,10]`       |
| Lydian #2                       | VI     | `[0,3,4,6,7,9,11]`       |
| Super Locrian 𝄫7 (Ultralocrian) | VII    | `[0,1,3,4,6,8,9]`        |

### 5.4 Modes of Melodic Minor

| Mode Name (common)              | Degree | Formula (semitones)        |
|---------------------------------|--------|---------------------------|
| Melodic Minor                   | I      | `[0,2,3,5,7,9,11]`       |
| Dorian ♭2 (Phrygian ♮6)        | II     | `[0,1,3,5,7,9,10]`       |
| Lydian Augmented                | III    | `[0,2,4,6,8,9,11]`       |
| Lydian Dominant (Overtone)      | IV     | `[0,2,4,6,7,9,10]`       |
| Mixolydian ♭6 (Hindu)           | V      | `[0,2,4,5,7,8,10]`       |
| Locrian ♮2 (Aeolian ♭5)        | VI     | `[0,2,3,5,6,8,10]`       |
| Super Locrian (Altered Scale)   | VII    | `[0,1,3,4,6,8,10]`       |

---

## 6. Exotic & World Scales

### 6.1 Pentatonic Scales

| Scale              | Formula (semitones) | Example in C          |
|--------------------|--------------------|-----------------------|
| Major Pentatonic   | `[0,2,4,7,9]`     | C D E G A             |
| Minor Pentatonic   | `[0,3,5,7,10]`    | C Eb F G Bb           |
| Blues (minor + b5)  | `[0,3,5,6,7,10]`  | C Eb F F#/Gb G Bb     |
| Major Blues         | `[0,2,3,4,7,9]`   | C D Eb E G A          |
| Japanese (In)      | `[0,1,5,7,8]`     | C Db F G Ab           |
| Hirajoshi          | `[0,2,3,7,8]`     | C D Eb G Ab           |
| Iwato              | `[0,1,5,6,10]`    | C Db F Gb Bb          |
| Kumoi              | `[0,2,3,7,9]`     | C D Eb G A            |
| Pelog (Balinese)   | `[0,1,3,7,8]`     | C Db Eb G Ab          |
| Chinese            | `[0,4,6,7,11]`    | C E F# G B            |
| Egyptian           | `[0,2,5,7,10]`    | C D F G Bb            |
| Yo                 | `[0,2,5,7,9]`     | C D F G A             |

### 6.2 Hexatonic Scales

| Scale              | Formula (semitones)  | Example in C           |
|--------------------|---------------------|------------------------|
| Whole Tone         | `[0,2,4,6,8,10]`   | C D E F# G# A#         |
| Augmented (Coltrane)| `[0,3,4,7,8,11]`  | C Eb E G Ab B           |
| Prometheus          | `[0,2,4,6,9,10]`   | C D E F# A Bb           |
| Blues Hexatonic     | `[0,3,5,6,7,10]`   | C Eb F Gb G Bb          |
| Tritone             | `[0,1,4,6,7,10]`   | C Db E Gb G Bb          |

### 6.3 Heptatonic (7-note) World Scales

| Scale                  | Formula (semitones)     | Example in C                |
|------------------------|------------------------|-----------------------------|
| Hungarian Minor        | `[0,2,3,6,7,8,11]`    | C D Eb F# G Ab B            |
| Hungarian Major        | `[0,3,4,6,7,9,10]`    | C D# E F# G A Bb            |
| Double Harmonic Major  | `[0,1,4,5,7,8,11]`    | C Db E F G Ab B              |
| (Byzantine / Arabic)   |                        |                              |
| Double Harmonic Minor  | `[0,2,3,6,7,8,11]`    | C D Eb F# G Ab B             |
| (Hungarian Minor)      |                        |                              |
| Neapolitan Major       | `[0,1,3,5,7,9,11]`    | C Db Eb F G A B              |
| Neapolitan Minor       | `[0,1,3,5,7,8,11]`    | C Db Eb F G Ab B             |
| Persian                | `[0,1,4,5,6,8,11]`    | C Db E F Gb Ab B             |
| Enigmatic              | `[0,1,4,6,8,10,11]`   | C Db E F# G# A# B           |
| Spanish (Jewish)       | `[0,1,4,5,7,8,10]`    | C Db E F G Ab Bb             |
| Gypsy                  | `[0,2,3,6,7,8,10]`    | C D Eb F# G Ab Bb            |
| Algerian               | `[0,2,3,6,7,8,11]`    | C D Eb F# G Ab B             |
| Flamenco               | `[0,1,4,5,7,8,11]`    | C Db E F G Ab B              |
| Ukrainian Dorian       | `[0,2,3,6,7,9,10]`    | C D Eb F# G A Bb             |
| Romanian               | `[0,2,3,6,7,9,10]`    | C D Eb F# G A Bb             |
| Hindu (Mixolydian b6)  | `[0,2,4,5,7,8,10]`    | C D E F G Ab Bb              |
| Bebop Dominant         | `[0,2,4,5,7,9,10,11]` | C D E F G A Bb B (8 notes)  |
| Bebop Major            | `[0,2,4,5,7,8,9,11]`  | C D E F G Ab A B (8 notes)  |
| Bebop Minor (Dorian)   | `[0,2,3,4,5,7,9,10]`  | C D Eb E F G A Bb (8 notes) |

### 6.4 Octatonic / Symmetric Scales

| Scale                     | Formula (semitones)          | Example in C                      |
|---------------------------|-----------------------------|------------------------------------|
| Diminished (W-H)          | `[0,2,3,5,6,8,9,11]`       | C D Eb F Gb Ab A B                |
| Diminished (H-W)          | `[0,1,3,4,6,7,9,10]`       | C Db Eb E F# G A Bb               |
| Chromatic                 | `[0,1,2,3,4,5,6,7,8,9,10,11]` | All 12 notes                   |

---

## 7. Intervals Reference

### 7.1 Interval Quality Rules

From any root note, intervals can be:
- **Perfect**: Unison, 4th, 5th, Octave (can be diminished or augmented)
- **Major/Minor**: 2nd, 3rd, 6th, 7th (major can become augmented; minor can become diminished)

Modification chain: `diminished ← minor ← major → augmented` or `diminished ← perfect → augmented`

### 7.2 All Intervals from C

| Interval | Note | Semitones |
|----------|------|-----------|
| P1       | C    | 0         |
| m2       | Db   | 1         |
| M2       | D    | 2         |
| m3       | Eb   | 3         |
| M3       | E    | 4         |
| P4       | F    | 5         |
| A4/d5    | F#/Gb| 6         |
| P5       | G    | 7         |
| m6       | Ab   | 8         |
| M6       | A    | 9         |
| m7       | Bb   | 10        |
| M7       | B    | 11        |
| P8       | C    | 12        |

### 7.3 Interval Inversions

When you invert an interval (flip the notes), the quality inverts and the numbers sum to 9:
- P ↔ P, M ↔ m, A ↔ d
- M3 (4 semitones) inverts to m6 (8 semitones). 4+8=12, 3+6=9.

---

## 8. Chord Construction — All Types

### 8.1 Triads

| Chord Type  | Symbol(s)         | Formula (semitones) | Intervals    | Example (C root) |
|-------------|-------------------|--------------------:|--------------|-----------------|
| Major       | C, CM, Cmaj       | `[0, 4, 7]`        | R M3 P5      | C E G           |
| Minor       | Cm, Cmin, C-       | `[0, 3, 7]`        | R m3 P5      | C Eb G          |
| Diminished  | Cdim, C°          | `[0, 3, 6]`        | R m3 d5      | C Eb Gb         |
| Augmented   | Caug, C+          | `[0, 4, 8]`        | R M3 A5      | C E G#          |
| Suspended 2 | Csus2             | `[0, 2, 7]`        | R M2 P5      | C D G           |
| Suspended 4 | Csus4, Csus       | `[0, 5, 7]`        | R P4 P5      | C F G           |

### 8.2 Seventh Chords

| Chord Type            | Symbol(s)              | Formula (semitones)  | Intervals       | Example (C root)  |
|-----------------------|------------------------|---------------------:|-----------------|-------------------|
| Major 7th             | Cmaj7, CΔ7, CM7       | `[0, 4, 7, 11]`     | R M3 P5 M7      | C E G B           |
| Dominant 7th          | C7                     | `[0, 4, 7, 10]`     | R M3 P5 m7      | C E G Bb          |
| Minor 7th             | Cm7, Cmin7, C-7        | `[0, 3, 7, 10]`     | R m3 P5 m7      | C Eb G Bb         |
| Minor Major 7th       | CmMaj7, Cm(M7), C-Δ7  | `[0, 3, 7, 11]`     | R m3 P5 M7      | C Eb G B          |
| Diminished 7th        | Cdim7, C°7             | `[0, 3, 6, 9]`      | R m3 d5 d7      | C Eb Gb Bbb(A)    |
| Half-Diminished 7th   | Cm7♭5, Cø7             | `[0, 3, 6, 10]`     | R m3 d5 m7      | C Eb Gb Bb        |
| Augmented 7th         | C+7, C7#5, Caug7       | `[0, 4, 8, 10]`     | R M3 A5 m7      | C E G# Bb         |
| Augmented Major 7th   | C+M7, CmajAug7, CΔ7#5 | `[0, 4, 8, 11]`     | R M3 A5 M7      | C E G# B          |
| Dominant 7th sus4     | C7sus4                 | `[0, 5, 7, 10]`     | R P4 P5 m7      | C F G Bb          |
| Dominant 7th sus2     | C7sus2                 | `[0, 2, 7, 10]`     | R M2 P5 m7      | C D G Bb          |
| Diminished Maj 7th    | C°M7                   | `[0, 3, 6, 11]`     | R m3 d5 M7      | C Eb Gb B         |

### 8.3 Sixth Chords

| Chord Type      | Symbol(s)    | Formula (semitones) | Intervals     | Example (C root) |
|-----------------|-------------|--------------------:|---------------|-----------------|
| Major 6th       | C6           | `[0, 4, 7, 9]`     | R M3 P5 M6    | C E G A          |
| Minor 6th       | Cm6          | `[0, 3, 7, 9]`     | R m3 P5 M6    | C Eb G A         |
| 6/9             | C6/9         | `[0, 4, 7, 9, 14]` | R M3 P5 M6 M9 | C E G A D        |
| Minor 6/9       | Cm6/9        | `[0, 3, 7, 9, 14]` | R m3 P5 M6 M9 | C Eb G A D       |

### 8.4 Extended Chords (9th, 11th, 13th)

**Ninth Chords:**

| Chord Type              | Symbol(s)        | Formula (semitones)      | Example (C root)    |
|-------------------------|-----------------|-------------------------:|---------------------|
| Major 9th               | Cmaj9, CΔ9      | `[0, 4, 7, 11, 14]`     | C E G B D           |
| Dominant 9th            | C9               | `[0, 4, 7, 10, 14]`     | C E G Bb D          |
| Minor 9th               | Cm9, C-9         | `[0, 3, 7, 10, 14]`     | C Eb G Bb D         |
| Minor Major 9th         | CmMaj9           | `[0, 3, 7, 11, 14]`     | C Eb G B D          |
| Dominant 7#9 (Hendrix)  | C7#9             | `[0, 4, 7, 10, 15]`     | C E G Bb D#         |
| Dominant 7b9            | C7b9             | `[0, 4, 7, 10, 13]`     | C E G Bb Db         |
| Dominant 7#9#5          | C7#9#5           | `[0, 4, 8, 10, 15]`     | C E G# Bb D#        |
| Dominant 7b9b5          | C7b9b5           | `[0, 4, 6, 10, 13]`     | C E Gb Bb Db        |
| Add 9                   | Cadd9            | `[0, 4, 7, 14]`         | C E G D             |
| Minor add 9             | Cm(add9)         | `[0, 3, 7, 14]`         | C Eb G D            |

**Eleventh Chords:**

| Chord Type              | Symbol(s)        | Formula (semitones)          | Example (C root)      |
|-------------------------|-----------------|-----------------------------:|-----------------------|
| Major 11th              | Cmaj11           | `[0, 4, 7, 11, 14, 17]`     | C E G B D F           |
| Dominant 11th           | C11              | `[0, 4, 7, 10, 14, 17]`     | C E G Bb D F          |
| Minor 11th              | Cm11             | `[0, 3, 7, 10, 14, 17]`     | C Eb G Bb D F         |
| Dominant 7#11           | C7#11            | `[0, 4, 7, 10, 14, 18]`     | C E G Bb D F#         |
| Major 7#11              | Cmaj7#11         | `[0, 4, 7, 11, 14, 18]`     | C E G B D F#          |

**Thirteenth Chords:**

| Chord Type              | Symbol(s)        | Formula (semitones)              | Example (C root)        |
|-------------------------|-----------------|----------------------------------:|-------------------------|
| Major 13th              | Cmaj13           | `[0, 4, 7, 11, 14, 17, 21]`     | C E G B D F A           |
| Dominant 13th           | C13              | `[0, 4, 7, 10, 14, 17, 21]`     | C E G Bb D F A          |
| Minor 13th              | Cm13             | `[0, 3, 7, 10, 14, 17, 21]`     | C Eb G Bb D F A         |
| Dominant 13b9           | C13b9            | `[0, 4, 7, 10, 13, 17, 21]`     | C E G Bb Db F A         |
| Dominant 7b13           | C7b13            | `[0, 4, 7, 10, 14, 20]`         | C E G Bb D Ab           |

### 8.5 Altered Dominant Chords (Jazz)

The "altered scale" (7th mode of melodic minor) produces chords with all possible alterations to 5ths and 9ths:

| Chord Type           | Symbol(s)      | Formula (semitones)      | Example (C root)      |
|----------------------|---------------|-------------------------:|-----------------------|
| 7alt (generic)       | C7alt          | `[0, 4, 10, +any alt]`  | Context-dependent     |
| 7b5                  | C7b5           | `[0, 4, 6, 10]`         | C E Gb Bb             |
| 7#5                  | C7#5           | `[0, 4, 8, 10]`         | C E G# Bb             |
| 7b9                  | C7b9           | `[0, 4, 7, 10, 13]`     | C E G Bb Db           |
| 7#9                  | C7#9           | `[0, 4, 7, 10, 15]`     | C E G Bb D#           |
| 7b5b9                | C7b5b9         | `[0, 4, 6, 10, 13]`     | C E Gb Bb Db          |
| 7b5#9                | C7b5#9         | `[0, 4, 6, 10, 15]`     | C E Gb Bb D#          |
| 7#5b9                | C7#5b9         | `[0, 4, 8, 10, 13]`     | C E G# Bb Db          |
| 7#5#9                | C7#5#9         | `[0, 4, 8, 10, 15]`     | C E G# Bb D#          |

### 8.6 Power Chords & Clusters

| Chord Type     | Symbol(s)   | Formula (semitones) | Example (C root) |
|----------------|------------|--------------------:|-----------------|
| Power Chord    | C5          | `[0, 7]`           | C G              |
| Power + Octave | C5          | `[0, 7, 12]`       | C G C            |
| Add 2 cluster  | Cadd2       | `[0, 2, 4, 7]`     | C D E G          |
| Add 4          | Cadd4       | `[0, 4, 5, 7]`     | C E F G          |
| Quartal (4ths) | —           | `[0, 5, 10]`       | C F Bb           |
| Quintal (5ths) | —           | `[0, 7, 14]`       | C G D            |

### 8.7 Complete Chord Spelling — All 12 Roots

Below is every **triad and seventh chord** spelled out for all 12 root notes.

#### C Chords

| Type     | Notes          |
|----------|---------------|
| C        | C E G          |
| Cm       | C Eb G         |
| Cdim     | C Eb Gb        |
| Caug     | C E G#         |
| Csus2    | C D G          |
| Csus4    | C F G          |
| Cmaj7    | C E G B        |
| C7       | C E G Bb       |
| Cm7      | C Eb G Bb      |
| CmMaj7   | C Eb G B       |
| Cdim7    | C Eb Gb A      |
| Cø7      | C Eb Gb Bb     |
| Caug7    | C E G# Bb      |
| C6       | C E G A        |
| Cm6      | C Eb G A       |
| Cmaj9    | C E G B D      |
| C9       | C E G Bb D     |
| Cm9      | C Eb G Bb D    |
| C7#9     | C E G Bb D#    |
| C7b9     | C E G Bb Db    |

#### C#/Db Chords

| Type     | Notes               |
|----------|---------------------|
| C#       | C# E# G#  (Db F Ab)  |
| C#m      | C# E G#   (Dbm)      |
| C#dim    | C# E G               |
| C#aug    | C# E# G## (Db F A)   |
| C#maj7   | C# E# G# B# (Db F Ab C)|
| C#7      | C# E# G# B  (Db F Ab Cb)|
| C#m7     | C# E G# B   (Dbm7)   |
| C#mMaj7  | C# E G# B#           |
| C#dim7   | C# E G Bb            |
| C#ø7     | C# E G B             |

#### D Chords

| Type     | Notes          |
|----------|---------------|
| D        | D F# A         |
| Dm       | D F A          |
| Ddim     | D F Ab         |
| Daug     | D F# A#        |
| Dsus2    | D E A          |
| Dsus4    | D G A          |
| Dmaj7    | D F# A C#      |
| D7       | D F# A C       |
| Dm7      | D F A C        |
| DmMaj7   | D F A C#       |
| Ddim7    | D F Ab Cb(B)   |
| Dø7      | D F Ab C       |
| Daug7    | D F# A# C      |
| D6       | D F# A B       |
| Dm6      | D F A B        |
| Dmaj9    | D F# A C# E    |
| D9       | D F# A C E     |
| Dm9      | D F A C E      |

#### Eb/D# Chords

| Type     | Notes          |
|----------|---------------|
| Eb       | Eb G Bb        |
| Ebm      | Eb Gb Bb       |
| Ebdim    | Eb Gb Bbb(A)   |
| Ebaug    | Eb G B         |
| Ebsus2   | Eb F Bb        |
| Ebsus4   | Eb Ab Bb       |
| Ebmaj7   | Eb G Bb D      |
| Eb7      | Eb G Bb Db     |
| Ebm7     | Eb Gb Bb Db    |
| EbmMaj7  | Eb Gb Bb D     |
| Ebdim7   | Eb Gb Bbb Dbb  |
| Ebø7     | Eb Gb Bbb Db   |

#### E Chords

| Type     | Notes          |
|----------|---------------|
| E        | E G# B         |
| Em       | E G B          |
| Edim     | E G Bb         |
| Eaug     | E G# B#(C)     |
| Esus2    | E F# B         |
| Esus4    | E A B          |
| Emaj7    | E G# B D#      |
| E7       | E G# B D       |
| Em7      | E G B D        |
| EmMaj7   | E G B D#       |
| Edim7    | E G Bb Db      |
| Eø7      | E G Bb D       |
| Eaug7    | E G# B#(C) D   |
| E6       | E G# B C#      |
| Em6      | E G B C#       |
| Emaj9    | E G# B D# F#   |
| E9       | E G# B D F#    |
| Em9      | E G B D F#     |

#### F Chords

| Type     | Notes          |
|----------|---------------|
| F        | F A C          |
| Fm       | F Ab C         |
| Fdim     | F Ab Cb(B)     |
| Faug     | F A C#         |
| Fsus2    | F G C          |
| Fsus4    | F Bb C         |
| Fmaj7    | F A C E        |
| F7       | F A C Eb       |
| Fm7      | F Ab C Eb      |
| FmMaj7   | F Ab C E       |
| Fdim7    | F Ab Cb Ebb(D) |
| Fø7      | F Ab Cb Eb     |
| Faug7    | F A C# Eb      |
| F6       | F A C D        |
| Fm6      | F Ab C D       |
| Fmaj9    | F A C E G      |
| F9       | F A C Eb G     |
| Fm9      | F Ab C Eb G    |

#### F#/Gb Chords

| Type     | Notes               |
|----------|---------------------|
| F#       | F# A# C#            |
| F#m      | F# A C#             |
| F#dim    | F# A C              |
| F#aug    | F# A# C##(D)        |
| F#maj7   | F# A# C# E#         |
| F#7      | F# A# C# E          |
| F#m7     | F# A C# E           |
| F#mMaj7  | F# A C# E#          |
| F#dim7   | F# A C Eb           |
| F#ø7     | F# A C E            |
| Gb       | Gb Bb Db            |
| Gbm      | Gb Bbb Db           |
| Gbmaj7   | Gb Bb Db F          |
| Gb7      | Gb Bb Db Fb         |

#### G Chords

| Type     | Notes          |
|----------|---------------|
| G        | G B D          |
| Gm       | G Bb D         |
| Gdim     | G Bb Db        |
| Gaug     | G B D#         |
| Gsus2    | G A D          |
| Gsus4    | G C D          |
| Gmaj7    | G B D F#       |
| G7       | G B D F        |
| Gm7      | G Bb D F       |
| GmMaj7   | G Bb D F#      |
| Gdim7    | G Bb Db Fb(E)  |
| Gø7      | G Bb Db F      |
| Gaug7    | G B D# F       |
| G6       | G B D E        |
| Gm6      | G Bb D E       |
| Gmaj9    | G B D F# A     |
| G9       | G B D F A      |
| Gm9      | G Bb D F A     |

#### Ab/G# Chords

| Type     | Notes          |
|----------|---------------|
| Ab       | Ab C Eb        |
| Abm      | Ab Cb Eb       |
| Abdim    | Ab Cb Ebb(D)   |
| Abaug    | Ab C E         |
| Absus2   | Ab Bb Eb       |
| Absus4   | Ab Db Eb       |
| Abmaj7   | Ab C Eb G      |
| Ab7      | Ab C Eb Gb     |
| Abm7     | Ab Cb Eb Gb    |
| AbmMaj7  | Ab Cb Eb G     |
| Abdim7   | Ab Cb Ebb Gbb  |
| Abø7     | Ab Cb Ebb Gb   |
| G#       | G# B# D#      |
| G#m      | G# B D#       |
| G#dim    | G# B D        |

#### A Chords

| Type     | Notes          |
|----------|---------------|
| A        | A C# E         |
| Am       | A C E          |
| Adim     | A C Eb         |
| Aaug     | A C# E#(F)     |
| Asus2    | A B E          |
| Asus4    | A D E          |
| Amaj7    | A C# E G#      |
| A7       | A C# E G       |
| Am7      | A C E G        |
| AmMaj7   | A C E G#       |
| Adim7    | A C Eb Gb      |
| Aø7      | A C Eb G       |
| Aaug7    | A C# E#(F) G   |
| A6       | A C# E F#      |
| Am6      | A C E F#       |
| Amaj9    | A C# E G# B    |
| A9       | A C# E G B     |
| Am9      | A C E G B      |

#### Bb/A# Chords

| Type     | Notes          |
|----------|---------------|
| Bb       | Bb D F         |
| Bbm      | Bb Db F        |
| Bbdim    | Bb Db Fb(E)    |
| Bbaug    | Bb D F#        |
| Bbsus2   | Bb C F         |
| Bbsus4   | Bb Eb F        |
| Bbmaj7   | Bb D F A       |
| Bb7      | Bb D F Ab      |
| Bbm7     | Bb Db F Ab     |
| BbmMaj7  | Bb Db F A      |
| Bbdim7   | Bb Db Fb Abb(G)|
| Bbø7     | Bb Db Fb Ab    |
| Bbaug7   | Bb D F# Ab     |
| Bb6      | Bb D F G       |
| Bbm6     | Bb Db F G      |
| Bbmaj9   | Bb D F A C     |
| Bb9      | Bb D F Ab C    |
| Bbm9     | Bb Db F Ab C   |

#### B Chords

| Type     | Notes          |
|----------|---------------|
| B        | B D# F#        |
| Bm       | B D F#         |
| Bdim     | B D F          |
| Baug     | B D# F##(G)    |
| Bsus2    | B C# F#        |
| Bsus4    | B E F#         |
| Bmaj7    | B D# F# A#     |
| B7       | B D# F# A      |
| Bm7      | B D F# A       |
| BmMaj7   | B D F# A#      |
| Bdim7    | B D F Ab       |
| Bø7      | B D F A        |
| Baug7    | B D# F##(G) A  |
| B6       | B D# F# G#     |
| Bm6      | B D F# G#      |
| Bmaj9    | B D# F# A# C#  |
| B9       | B D# F# A C#   |
| Bm9      | B D F# A C#    |

---

## 9. Chord Inversions & Voicings

### 9.1 Triad Inversions

Any triad has three positions:

| Position       | Description              | Notation     | Example (C major) |
|----------------|--------------------------|-------------|-------------------|
| Root Position   | Root on bottom            | C or C/C    | C E G             |
| 1st Inversion  | 3rd on bottom             | C/E         | E G C             |
| 2nd Inversion  | 5th on bottom             | C/G         | G C E             |

### 9.2 Seventh Chord Inversions

Four-note chords have four positions:

| Position       | Description              | Notation     | Example (Cmaj7)   |
|----------------|--------------------------|-------------|-------------------|
| Root Position   | Root on bottom            | Cmaj7       | C E G B           |
| 1st Inversion  | 3rd on bottom             | Cmaj7/E     | E G B C           |
| 2nd Inversion  | 5th on bottom             | Cmaj7/G     | G B C E           |
| 3rd Inversion  | 7th on bottom             | Cmaj7/B     | B C E G           |

### 9.3 Figured Bass Notation (Classical)

| Inversion      | Figured Bass | Shorthand |
|----------------|-------------|-----------|
| Root Position  | 5/3          | (none)    |
| 1st Inv Triad  | 6/3          | 6         |
| 2nd Inv Triad  | 6/4          | 6/4       |
| Root Pos 7th   | 7            | 7         |
| 1st Inv 7th    | 6/5          | 6/5       |
| 2nd Inv 7th    | 4/3          | 4/3       |
| 3rd Inv 7th    | 4/2 or 2    | 4/2       |

### 9.4 Slash Chords (Bass Note Notation)

A slash chord indicates a specific bass note: `Chord/BassNote`

Common slash chords that are NOT simple inversions:

| Slash Chord | Notes (bottom up) | Function                    |
|-------------|--------------------|-----------------------------|
| C/Bb        | Bb C E G           | Dominant approach            |
| Am/G        | G A C E            | Am7 in 3rd inversion         |
| F/G         | G F A C            | G11 (no 3rd) — dominant sub |
| C/D         | D C E G            | Dsus type / G major feel     |
| Ab/Bb       | Bb Ab C Eb         | Bb7sus feel                  |
| D/F#        | F# D A             | D 1st inversion (very common)|
| G/B         | B G D              | G 1st inversion              |
| C/E         | E C G              | C 1st inversion              |

### 9.5 Voicing Types

| Voicing Type    | Description                                        |
|-----------------|---------------------------------------------------|
| Close voicing   | All notes within one octave                        |
| Open voicing    | Notes spread across multiple octaves               |
| Drop 2          | Take 2nd note from top, drop it an octave          |
| Drop 3          | Take 3rd note from top, drop it an octave          |
| Drop 2+4        | Drop both 2nd and 4th notes from top an octave     |
| Shell voicing   | Root + 3rd + 7th only (jazz piano)                 |
| Rootless voicing| Omit the root (let bass player handle it)          |
| Quartal voicing | Stack notes in 4ths rather than 3rds               |
| Cluster voicing | Notes within a 2nd or 3rd of each other            |
| Spread voicing  | Wide intervals, often used in orchestration         |

---

## 10. Diatonic Chords per Key

### 10.1 Major Key Diatonic Chords

**Triads** built on each scale degree:

| Degree | Roman Numeral | Quality     |
|--------|--------------|-------------|
| I      | I            | Major       |
| II     | ii           | Minor       |
| III    | iii          | Minor       |
| IV     | IV           | Major       |
| V      | V            | Major       |
| VI     | vi           | Minor       |
| VII    | vii°         | Diminished  |

**Seventh chords** built on each scale degree:

| Degree | Roman Numeral | Quality         |
|--------|--------------|-----------------|
| I      | Imaj7        | Major 7th       |
| II     | ii7          | Minor 7th       |
| III    | iii7         | Minor 7th       |
| IV     | IVmaj7       | Major 7th       |
| V      | V7           | Dominant 7th    |
| VI     | vi7          | Minor 7th       |
| VII    | viiø7        | Half-Dim 7th    |

### 10.2 Major Key Diatonic Chords — All 12 Keys (Triads)

| Key  | I    | ii   | iii  | IV   | V    | vi   | vii° |
|------|------|------|------|------|------|------|------|
| C    | C    | Dm   | Em   | F    | G    | Am   | Bdim |
| G    | G    | Am   | Bm   | C    | D    | Em   | F#dim|
| D    | D    | Em   | F#m  | G    | A    | Bm   | C#dim|
| A    | A    | Bm   | C#m  | D    | E    | F#m  | G#dim|
| E    | E    | F#m  | G#m  | A    | B    | C#m  | D#dim|
| B    | B    | C#m  | D#m  | E    | F#   | G#m  | A#dim|
| F#   | F#   | G#m  | A#m  | B    | C#   | D#m  | E#dim|
| F    | F    | Gm   | Am   | Bb   | C    | Dm   | Edim |
| Bb   | Bb   | Cm   | Dm   | Eb   | F    | Gm   | Adim |
| Eb   | Eb   | Fm   | Gm   | Ab   | Bb   | Cm   | Ddim |
| Ab   | Ab   | Bbm  | Cm   | Db   | Eb   | Fm   | Gdim |
| Db   | Db   | Ebm  | Fm   | Gb   | Ab   | Bbm  | Cdim |
| Gb   | Gb   | Abm  | Bbm  | Cb   | Db   | Ebm  | Fdim |

### 10.3 Minor Key Diatonic Chords (Natural Minor)

| Degree | Roman Numeral | Quality     |
|--------|--------------|-------------|
| i      | i            | Minor       |
| II     | ii°          | Diminished  |
| III    | III          | Major       |
| iv     | iv           | Minor       |
| v      | v            | Minor       |
| VI     | VI           | Major       |
| VII    | VII          | Major       |

### 10.4 Minor Key Diatonic Chords — All 12 Keys (Triads)

| Key  | i    | ii°   | III  | iv   | v    | VI   | VII  |
|------|------|-------|------|------|------|------|------|
| Am   | Am   | Bdim  | C    | Dm   | Em   | F    | G    |
| Em   | Em   | F#dim | G    | Am   | Bm   | C    | D    |
| Bm   | Bm   | C#dim | D    | Em   | F#m  | G    | A    |
| F#m  | F#m  | G#dim | A    | Bm   | C#m  | D    | E    |
| C#m  | C#m  | D#dim | E    | F#m  | G#m  | A    | B    |
| G#m  | G#m  | A#dim | B    | C#m  | D#m  | E    | F#   |
| Dm   | Dm   | Edim  | F    | Gm   | Am   | Bb   | C    |
| Gm   | Gm   | Adim  | Bb   | Cm   | Dm   | Eb   | F    |
| Cm   | Cm   | Ddim  | Eb   | Fm   | Gm   | Ab   | Bb   |
| Fm   | Fm   | Gdim  | Ab   | Bbm  | Cm   | Db   | Eb   |
| Bbm  | Bbm  | Cdim  | Db   | Ebm  | Fm   | Gb   | Ab   |
| Ebm  | Ebm  | Fdim  | Gb   | Abm  | Bbm  | Cb   | Db   |

### 10.5 Harmonic Minor Diatonic Chords

| Degree | Roman Numeral | Quality         |
|--------|--------------|-----------------|
| i      | i            | Minor           |
| II     | ii°          | Diminished      |
| III    | III+         | Augmented       |
| iv     | iv           | Minor           |
| V      | V            | Major           |
| VI     | VI           | Major           |
| VII    | vii°         | Diminished      |

Seventh chords of harmonic minor:

| Degree | Quality               |
|--------|-----------------------|
| i      | Minor-Major 7th       |
| ii     | Half-Diminished 7th   |
| III    | Augmented Major 7th   |
| iv     | Minor 7th             |
| V      | Dominant 7th          |
| VI     | Major 7th             |
| vii    | Diminished 7th        |

### 10.6 Melodic Minor Diatonic Chords

| Degree | Roman Numeral | Quality           |
|--------|--------------|-------------------|
| i      | i            | Minor             |
| II     | II           | Minor             |
| III    | III+         | Augmented         |
| IV     | IV           | Major (Dominant)  |
| V      | V            | Major (Dominant)  |
| vi     | vi°          | Diminished        |
| vii    | vii°         | Diminished        |

---

## 11. Chord Progressions by Genre

### 11.1 Universal / Common Progressions

| Name                    | Numerals              | Key of C              | Frequency |
|-------------------------|----------------------|----------------------|-----------|
| "The Most Common"       | I – V – vi – IV      | C G Am F              | Ubiquitous|
| "50s / Doo-Wop"         | I – vi – IV – V      | C Am F G              | Very High |
| "Pachelbel's Canon"     | I – V – vi – iii – IV – I – IV – V | C G Am Em F C F G | High |
| "Three Chord"           | I – IV – V           | C F G                 | Very High |
| "Blues Turnaround"      | I – IV – V – IV      | C F G F               | High      |
| "Plagal"                | IV – I               | F C                   | High      |
| "Authentic"             | V – I                | G C                   | High      |
| "Deceptive Cadence"     | V – vi               | G Am                  | Common    |

### 11.2 Pop & Rock Progressions

| Name                    | Numerals              | Key of C              | Usage / Feel          |
|-------------------------|----------------------|----------------------|-----------------------|
| "Pop Punk"              | I – V – vi – IV      | C G Am F              | Pop-punk, power pop   |
| "Sensitive"             | vi – IV – I – V      | Am F C G              | Emotional ballads     |
| "Optimistic"            | I – IV – vi – V      | C F Am G              | Uplifting pop         |
| "Melancholy Pop"        | vi – V – IV – V      | Am G F G              | Bittersweet           |
| "Rock Anthem"           | I – bVII – IV – I    | C Bb F C              | Classic rock          |
| "Grunge"                | I – bVI – bVII       | C Ab Bb               | Dark alternative      |
| "Aeolian Rock"          | i – bVI – bVII – i   | Cm Ab Bb Cm           | Minor rock            |
| "Creep" Progression     | I – III – IV – iv    | C E F Fm              | Radiohead-style       |
| "Happy Minor"           | i – bVII – bVI – V   | Am G F E              | Andalusian cadence    |
| "Power Pop"             | I – iii – IV – V     | C Em F G              | Bright rock           |
| "Indie"                 | I – IV – I – V       | C F C G               | Simple, catchy        |

### 11.3 Blues Progressions

#### 12-Bar Blues (Basic)
```
| I7  | I7  | I7  | I7  |
| IV7 | IV7 | I7  | I7  |
| V7  | IV7 | I7  | V7  |
```
In C: `C7 C7 C7 C7 | F7 F7 C7 C7 | G7 F7 C7 G7`

#### 12-Bar Blues (Jazz/Quick Change)
```
| I7  | IV7 | I7  | I7  |
| IV7 | IV7 | I7  | I7  |
| V7  | IV7 | I7  | V7  |
```

#### 12-Bar Blues (Bird Changes / Bebop)
```
| Imaj7 | IV7   | Imaj7  | I7     |
| IV7   | #IVdim7| Imaj7 | VI7alt |
| ii7   | V7    | iii7 VI7| ii7 V7|
```

#### Minor Blues
```
| i7  | i7  | i7   | i7  |
| iv7 | iv7 | i7   | i7  |
| bVI7| V7  | i7   | V7  |
```

### 11.4 Jazz Progressions

| Name                      | Numerals                      | Key of C                          |
|---------------------------|-------------------------------|-----------------------------------|
| ii-V-I Major              | ii7 – V7 – Imaj7             | Dm7 G7 Cmaj7                      |
| ii-V-i Minor              | iiø7 – V7 – i                | Dø7 G7 Cm                         |
| I-vi-ii-V (Rhythm Changes)| Imaj7 – vi7 – ii7 – V7       | Cmaj7 Am7 Dm7 G7                  |
| iii-vi-ii-V               | iii7 – vi7 – ii7 – V7        | Em7 Am7 Dm7 G7                    |
| Tritone Substitution      | ii7 – bII7 – Imaj7           | Dm7 Db7 Cmaj7                     |
| Coltrane Changes          | Imaj7 – V7/bVI – bVImaj7 – V7/III – IIImaj7 – V7/I – Imaj7 | Cmaj7 Eb7 Abmaj7 B7 Emaj7 G7 Cmaj7 |
| Backdoor ii-V             | iv7 – bVII7 – Imaj7          | Fm7 Bb7 Cmaj7                     |
| Lady Bird                 | Imaj7 – iii7 – bIIImaj7 – bIImaj7 | Cmaj7 Em7 Ebmaj7 Dbmaj7     |
| Confirmation Changes      | I – VI7 – ii – V – I – #Idim – ii – V | Cmaj7 A7 Dm7 G7 Cmaj7 C#dim Dm7 G7 |
| "All The Things" Bridge   | iv – bVII7 – III – VI7 – ii – V7 – I | Fm Bb7 E A7 Dm G7 C         |
| Modal Jazz (So What)      | i Dorian (16 bars) – i Dorian up ½ step (8 bars) – return | Dm7 Ebm7 Dm7 |
| Autumn Leaves              | ii7 – V7 – Imaj7 – IVmaj7 – viiø7 – III7 – vi | Cm7 F7 Bbmaj7 Ebmaj7 Aø7 D7 Gm |

### 11.5 Classical Progressions

| Name                      | Numerals                  | Key of C              | Period/Style       |
|---------------------------|--------------------------|----------------------|--------------------|
| Authentic Cadence (PAC)   | V – I                    | G C                  | All periods        |
| Plagal Cadence (Amen)     | IV – I                   | F C                  | Hymns, all periods |
| Half Cadence              | (any) – V                | ... G                | All periods        |
| Deceptive Cadence         | V – vi                   | G Am                 | All periods        |
| Phrygian Half Cadence     | iv6 – V                  | Fm/Ab E              | Baroque            |
| Circle of 5ths            | I–IV–vii°–iii–vi–ii–V–I  | C F Bdim Em Am Dm G C| Baroque, Classical  |
| Romanesca                 | III–VII–i–V–III–VII–i–V  | Eb Bb Cm G Eb Bb Cm G| Renaissance        |
| Lament Bass               | i–v6–iv6–V               | Cm Gm/Bb Fm/Ab G     | Baroque (descending)|
| Passamezzo Antico         | i–VII–i–V–III–VII–i–V–i  | Am G Am E C G Am E Am | Renaissance       |
| Passamezzo Moderno        | I–IV–I–V–I–IV–I–V–I     | C F C G C F C G C     | Renaissance       |
| Omnibus Progression       | I–V4/2–vi–V6/5–I6...    | (chromatic voice leading)| Romantic         |
| Neapolitan approach       | bII6 – V – i             | Db/F G Cm             | Classical/Romantic |
| Augmented 6th → V → I    | It6/Fr6/Ger6 – V – I    | Ab-C-F# → G → C      | Classical/Romantic |

### 11.6 R&B / Soul / Gospel Progressions

| Name                      | Numerals                    | Key of C              |
|---------------------------|----------------------------|----------------------|
| "I Will Always Love You"  | I – III7 – IV – iv          | C E7 F Fm            |
| Gospel 2-5-1              | ii9 – V13 – Imaj9          | Dm9 G13 Cmaj9        |
| Sweet Soul                | I – iii – IV – V            | C Em F G             |
| Neo-Soul                  | IVmaj7 – iii7 – vi7 – ii7  | Fmaj7 Em7 Am7 Dm7   |
| Gospel Shout              | IV – V – iii – vi           | F G Em Am            |
| Gospel Turnaround         | I – I7 – IV – #IVdim7 – I/V – vi – ii7 – V7 | C C7 F F#dim7 C/G Am Dm7 G7 |

### 11.7 EDM / Electronic / Modern Progressions

| Name                    | Numerals              | Key of C              | Subgenre          |
|-------------------------|----------------------|----------------------|-------------------|
| "Four Chords (minor)"  | i – bVI – bIII – bVII| Cm Ab Eb Bb          | Pop-EDM           |
| "Anthem Trance"         | vi – IV – I – V      | Am F C G             | Trance             |
| "Dark Minimal"          | i – iv               | Cm Fm                | Techno             |
| "Lo-fi"                | ii7 – V7 – Imaj7 – vi7 | Dm7 G7 Cmaj7 Am7  | Lo-fi hip hop     |
| "Future Bass"           | I – iii – vi – IV    | C Em Am F            | Future Bass        |
| "Vapor/Synth"           | Imaj7 – IVmaj7       | Cmaj7 Fmaj7          | Synthwave          |
| "Film Score Epic"       | i – bVI – bIII – bVII| Cm Ab Eb Bb          | Cinematic          |
| "Trap Soul"             | i – bVI – bVII – iv  | Cm Ab Bb Fm          | Trap/R&B           |

### 11.8 Interesting / Uncommon Progressions

| Name                      | Numerals                        | Key of C                    | Character         |
|---------------------------|--------------------------------|-----------------------------|--------------------|
| "Chromatic Mediant"       | I – bIII – I – #V              | C Eb C G#                  | Cinematic shift    |
| "Coltrane Matrix"         | IMaj7–bIII7–bVIMaj7–VII7–IIIMaj7–V7 | Cmaj7 Eb7 Abmaj7 B7 Emaj7 G7 | Avant-garde |
| "Constant Structure"      | Same chord type, parallel move  | Cmaj7 Dbmaj7 Dmaj7 Ebmaj7  | Modern jazz        |
| "Planing / Parallelism"   | Move entire chord shape chromatically | Dm7 Ebm7 Em7 Fm7    | Debussy, film      |
| "Pedal Point Harmony"     | Changing chords over static bass| C/G Am/G F/G G              | Tension builder    |
| "Tritone Pairs"           | I – #IV – I                     | C F# C                     | Dissonant contrast |

### 11.9 Rare / Exotic Progressions

| Name                        | Numerals / Description              | Character              |
|-----------------------------|-------------------------------------|------------------------|
| "Axis System" (Bartók)      | Substitute chords at tritone, m3, M3 distances | Symmetrical harmony |
| Messiaen Modes              | Chords derived from modes of limited transposition | Symmetric, otherworldly |
| Negative Harmony             | Mirror chord functions around axis between root and 5th | Inversion of function |
| Spectral Harmony            | Chords derived from overtone series  | Microtonal / rich      |
| Polytonal Progressions      | Two keys simultaneously (e.g., C maj + F# maj) | Stravinsky, Milhaud |
| Pandiatonic                 | All notes of a scale used freely without functional progression | Copland, Stravinsky |
| Neo-Riemannian (PRL)        | Progressions via Parallel, Relative, Leading-tone exchanges | Film scores, late romantic |
| Chromatic Mediants           | Moves by M3 or m3 (C→E, C→Ab, C→Eb, C→A) | Marvel, Spielberg scores |

---

## 12. Borrowed Chords & Modal Interchange

### 12.1 What is Modal Interchange?

Using chords from parallel modes (same root, different scale). Most commonly borrowing from the parallel minor into a major key.

### 12.2 Common Borrowed Chords in Major Keys

In the key of C major, borrowing from C minor / C Dorian / C Phrygian / C Lydian etc.:

| Borrowed Chord | Source Mode      | Notes        | Common Usage                        |
|---------------|-----------------|-------------|-------------------------------------|
| iv            | Aeolian (minor) | Fm           | Melancholy feel in major keys        |
| bVII          | Mixolydian      | Bb           | Rock/pop, "backdoor" dominant        |
| bVI           | Aeolian          | Ab           | Dramatic, cinematic                  |
| bIII          | Aeolian          | Eb           | Surprise brightness in minor feel    |
| ii°           | Aeolian          | Ddim         | Darker ii chord                      |
| i             | Aeolian          | Cm           | "Major to minor" surprise            |
| iv7           | Aeolian          | Fm7          | Sophisticated sadness                |
| #IV (Lydian)  | Lydian           | F#           | Dreamy, ethereal                     |
| bII (Neapolitan)| Phrygian      | Db           | Classical drama                      |
| V7 of bVII    | Double Mixolydian| F7          | Secondary dominant to bVII           |

### 12.3 Secondary Dominants

A secondary dominant is a V7 chord that resolves to a diatonic chord other than I:

| Secondary Dominant | Target | In C Major         |
|-------------------|--------|-------------------|
| V7/ii             | ii     | A7 → Dm           |
| V7/iii            | iii    | B7 → Em           |
| V7/IV             | IV     | C7 → F            |
| V7/V              | V      | D7 → G            |
| V7/vi             | vi     | E7 → Am           |

### 12.4 Secondary Leading-Tone Chords

| Chord    | Target | In C Major          |
|----------|--------|---------------------|
| vii°7/ii | ii     | C#dim7 → Dm         |
| vii°7/iii| iii    | D#dim7 → Em         |
| vii°7/IV | IV     | Edim7 → F           |
| vii°7/V  | V      | F#dim7 → G          |
| vii°7/vi | vi     | G#dim7 → Am         |

### 12.5 Tritone Substitutions (Jazz)

Replace any dominant 7th with the dominant 7th a tritone away (they share the same tritone interval):

| Original | Tritone Sub | Shared Tritone | Resolution |
|----------|------------|---------------|------------|
| G7       | Db7        | B & F         | → C        |
| D7       | Ab7        | F# & C        | → G        |
| A7       | Eb7        | C# & G        | → D        |
| E7       | Bb7        | G# & D        | → A        |
| B7       | F7         | D# & A        | → E        |
| F#7      | C7         | A# & E        | → B        |
| C7       | Gb7        | E & Bb         | → F        |

---

## 13. Enharmonic Equivalence & Spelling Rules

### 13.1 When to Use Sharps vs. Flats

**Rules for correct spelling:**
1. Key signatures determine sharps/flats — use the accidentals of the key
2. Each scale degree uses a unique letter name (no repeated letters)
3. Ascending motion prefers sharps; descending prefers flats
4. In sharp keys: use sharps. In flat keys: use flats
5. Diminished intervals use flats; augmented intervals use sharps

### 13.2 Enharmonic Keys

| Sharp Key | Flat Key  | Sound Identical |
|-----------|-----------|-----------------|
| F# major  | Gb major  | Yes             |
| C# major  | Db major  | Yes             |
| B major   | Cb major  | Yes             |
| D# minor  | Eb minor  | Yes             |
| A# minor  | Bb minor  | Yes             |
| G# minor  | Ab minor  | Yes             |

### 13.3 Enharmonic Chords

Some chords are spelled differently but sound the same:

| Chord A    | Chord B     | Same Pitches |
|-----------|-------------|-------------|
| C#        | Db          | Yes         |
| F#m       | Gbm         | Yes         |
| Cdim7     | Ebdim7 = Gbdim7 = Adim7 | Yes (symmetric) |
| Caug      | Eaug = G#aug | Yes (symmetric) |

**Diminished 7th symmetry:** There are only 3 unique diminished 7th chords:
1. Cdim7 = Ebdim7 = Gbdim7 = Adim7 → `[0, 3, 6, 9]`
2. C#dim7 = Edim7 = Gdim7 = Bbdim7 → `[1, 4, 7, 10]`
3. Ddim7 = Fdim7 = Abdim7 = Bdim7 → `[2, 5, 8, 11]`

**Augmented triad symmetry:** There are only 4 unique augmented triads:
1. Caug = Eaug = G#aug → `[0, 4, 8]`
2. Dbaug = Faug = Aaug → `[1, 5, 9]`
3. Daug = F#aug = Bbaug → `[2, 6, 10]`
4. Ebaug = Gaug = Baug → `[3, 7, 11]`

---

## 14. Data Structures for Implementation

### 14.1 Pitch Class Representation

```
PITCH_CLASSES = {
  "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3,
  "E": 4, "Fb": 4, "E#": 5, "F": 5, "F#": 6, "Gb": 6,
  "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10,
  "B": 11, "Cb": 11, "B#": 0
}
```

### 14.2 Chord Type Definitions (Intervals from Root)

```
CHORD_TYPES = {
  // Triads
  "major":        [0, 4, 7],
  "minor":        [0, 3, 7],
  "diminished":   [0, 3, 6],
  "augmented":    [0, 4, 8],
  "sus2":         [0, 2, 7],
  "sus4":         [0, 5, 7],
  
  // Seventh chords
  "maj7":         [0, 4, 7, 11],
  "7":            [0, 4, 7, 10],
  "m7":           [0, 3, 7, 10],
  "mMaj7":        [0, 3, 7, 11],
  "dim7":         [0, 3, 6, 9],
  "m7b5":         [0, 3, 6, 10],
  "aug7":         [0, 4, 8, 10],
  "augMaj7":      [0, 4, 8, 11],
  "7sus4":        [0, 5, 7, 10],
  "7sus2":        [0, 2, 7, 10],
  "dimMaj7":      [0, 3, 6, 11],
  
  // Sixth chords
  "6":            [0, 4, 7, 9],
  "m6":           [0, 3, 7, 9],
  
  // Ninth chords
  "maj9":         [0, 4, 7, 11, 14],
  "9":            [0, 4, 7, 10, 14],
  "m9":           [0, 3, 7, 10, 14],
  "mMaj9":        [0, 3, 7, 11, 14],
  "add9":         [0, 4, 7, 14],
  "madd9":        [0, 3, 7, 14],
  "7b9":          [0, 4, 7, 10, 13],
  "7#9":          [0, 4, 7, 10, 15],
  "6/9":          [0, 4, 7, 9, 14],
  "m6/9":         [0, 3, 7, 9, 14],
  
  // Eleventh chords
  "maj11":        [0, 4, 7, 11, 14, 17],
  "11":           [0, 4, 7, 10, 14, 17],
  "m11":          [0, 3, 7, 10, 14, 17],
  "7#11":         [0, 4, 7, 10, 14, 18],
  "maj7#11":      [0, 4, 7, 11, 14, 18],
  
  // Thirteenth chords
  "maj13":        [0, 4, 7, 11, 14, 17, 21],
  "13":           [0, 4, 7, 10, 14, 17, 21],
  "m13":          [0, 3, 7, 10, 14, 17, 21],
  "13b9":         [0, 4, 7, 10, 13, 17, 21],
  "7b13":         [0, 4, 7, 10, 14, 20],
  
  // Altered dominants
  "7b5":          [0, 4, 6, 10],
  "7#5":          [0, 4, 8, 10],
  "7b5b9":        [0, 4, 6, 10, 13],
  "7b5#9":        [0, 4, 6, 10, 15],
  "7#5b9":        [0, 4, 8, 10, 13],
  "7#5#9":        [0, 4, 8, 10, 15],
  "7alt":         [0, 4, 10],  // 3rd + b7, rest varies
  
  // Power & special
  "5":            [0, 7],
  "add2":         [0, 2, 4, 7],
  "add4":         [0, 4, 5, 7],
}
```

### 14.3 Scale Type Definitions

```
SCALE_TYPES = {
  // Standard Western
  "major":              [0, 2, 4, 5, 7, 9, 11],
  "natural_minor":      [0, 2, 3, 5, 7, 8, 10],
  "harmonic_minor":     [0, 2, 3, 5, 7, 8, 11],
  "melodic_minor_asc":  [0, 2, 3, 5, 7, 9, 11],
  
  // Modes of Major
  "ionian":             [0, 2, 4, 5, 7, 9, 11],
  "dorian":             [0, 2, 3, 5, 7, 9, 10],
  "phrygian":           [0, 1, 3, 5, 7, 8, 10],
  "lydian":             [0, 2, 4, 6, 7, 9, 11],
  "mixolydian":         [0, 2, 4, 5, 7, 9, 10],
  "aeolian":            [0, 2, 3, 5, 7, 8, 10],
  "locrian":            [0, 1, 3, 5, 6, 8, 10],
  
  // Modes of Harmonic Minor
  "harmonic_minor":         [0, 2, 3, 5, 7, 8, 11],
  "locrian_nat6":           [0, 1, 3, 5, 6, 9, 10],
  "ionian_augmented":       [0, 2, 4, 5, 8, 9, 11],
  "dorian_sharp4":          [0, 2, 3, 6, 7, 9, 10],
  "phrygian_dominant":      [0, 1, 4, 5, 7, 8, 10],
  "lydian_sharp2":          [0, 3, 4, 6, 7, 9, 11],
  "ultralocrian":           [0, 1, 3, 4, 6, 8, 9],
  
  // Modes of Melodic Minor
  "melodic_minor":          [0, 2, 3, 5, 7, 9, 11],
  "dorian_b2":              [0, 1, 3, 5, 7, 9, 10],
  "lydian_augmented":       [0, 2, 4, 6, 8, 9, 11],
  "lydian_dominant":        [0, 2, 4, 6, 7, 9, 10],
  "mixolydian_b6":          [0, 2, 4, 5, 7, 8, 10],
  "locrian_nat2":           [0, 2, 3, 5, 6, 8, 10],
  "altered":                [0, 1, 3, 4, 6, 8, 10],
  
  // Pentatonic & Blues
  "major_pentatonic":       [0, 2, 4, 7, 9],
  "minor_pentatonic":       [0, 3, 5, 7, 10],
  "blues":                  [0, 3, 5, 6, 7, 10],
  "major_blues":            [0, 2, 3, 4, 7, 9],
  
  // Symmetric
  "whole_tone":             [0, 2, 4, 6, 8, 10],
  "diminished_wh":          [0, 2, 3, 5, 6, 8, 9, 11],
  "diminished_hw":          [0, 1, 3, 4, 6, 7, 9, 10],
  "chromatic":              [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  
  // Exotic / World
  "hungarian_minor":        [0, 2, 3, 6, 7, 8, 11],
  "hungarian_major":        [0, 3, 4, 6, 7, 9, 10],
  "double_harmonic_major":  [0, 1, 4, 5, 7, 8, 11],
  "neapolitan_major":       [0, 1, 3, 5, 7, 9, 11],
  "neapolitan_minor":       [0, 1, 3, 5, 7, 8, 11],
  "persian":                [0, 1, 4, 5, 6, 8, 11],
  "enigmatic":              [0, 1, 4, 6, 8, 10, 11],
  "spanish":                [0, 1, 4, 5, 7, 8, 10],
  "gypsy":                  [0, 2, 3, 6, 7, 8, 10],
  "algerian":               [0, 2, 3, 6, 7, 8, 11],
  "flamenco":               [0, 1, 4, 5, 7, 8, 11],
  "ukrainian_dorian":       [0, 2, 3, 6, 7, 9, 10],
  "hirajoshi":              [0, 2, 3, 7, 8],
  "japanese_in":            [0, 1, 5, 7, 8],
  "iwato":                  [0, 1, 5, 6, 10],
  "kumoi":                  [0, 2, 3, 7, 9],
  "pelog":                  [0, 1, 3, 7, 8],
  "chinese":                [0, 4, 6, 7, 11],
  "egyptian":               [0, 2, 5, 7, 10],
  "yo":                     [0, 2, 5, 7, 9],
  
  // Bebop (8-note)
  "bebop_dominant":         [0, 2, 4, 5, 7, 9, 10, 11],
  "bebop_major":            [0, 2, 4, 5, 7, 8, 9, 11],
  "bebop_minor":            [0, 2, 3, 4, 5, 7, 9, 10],
  
  // Hexatonic
  "augmented_scale":        [0, 3, 4, 7, 8, 11],
  "prometheus":             [0, 2, 4, 6, 9, 10],
  "tritone_scale":          [0, 1, 4, 6, 7, 10],
}
```

### 14.4 Circle of Fifths as Data

```
CIRCLE_OF_FIFTHS = {
  "major": ["C", "G", "D", "A", "E", "B", "F#/Gb", "Db", "Ab", "Eb", "Bb", "F"],
  "minor": ["Am", "Em", "Bm", "F#m", "C#m", "G#m", "D#m/Ebm", "Bbm", "Fm", "Cm", "Gm", "Dm"],
  "sharps_count": [0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1],  // flats = negative convention
  "accidentals": [
    [],
    ["F#"],
    ["F#", "C#"],
    ["F#", "C#", "G#"],
    ["F#", "C#", "G#", "D#"],
    ["F#", "C#", "G#", "D#", "A#"],
    ["F#", "C#", "G#", "D#", "A#", "E#"],
    ["Bb", "Eb", "Ab", "Db", "Gb"],
    ["Bb", "Eb", "Ab", "Db"],
    ["Bb", "Eb", "Ab"],
    ["Bb", "Eb"],
    ["Bb"]
  ]
}
```

### 14.5 Progression Templates

```
PROGRESSION_TEMPLATES = {
  // Common
  "four_chords":        { numerals: ["I", "V", "vi", "IV"], tags: ["pop", "rock", "common"] },
  "50s":                { numerals: ["I", "vi", "IV", "V"], tags: ["pop", "oldies", "common"] },
  "canon":              { numerals: ["I", "V", "vi", "iii", "IV", "I", "IV", "V"], tags: ["classical", "pop", "common"] },
  "three_chord":        { numerals: ["I", "IV", "V"], tags: ["rock", "folk", "country", "common"] },
  "andalusian":         { numerals: ["i", "bVII", "bVI", "V"], tags: ["flamenco", "rock", "common"] },
  
  // Rock
  "rock_anthem":        { numerals: ["I", "bVII", "IV", "I"], tags: ["rock"] },
  "grunge":             { numerals: ["I", "bVI", "bVII"], tags: ["rock", "alternative"] },
  "aeolian_rock":       { numerals: ["i", "bVI", "bVII", "i"], tags: ["rock", "minor"] },
  "creep":              { numerals: ["I", "III", "IV", "iv"], tags: ["rock", "interesting"] },
  
  // Blues
  "12_bar_blues":       { numerals: ["I7","I7","I7","I7","IV7","IV7","I7","I7","V7","IV7","I7","V7"], tags: ["blues"] },
  "minor_blues":        { numerals: ["i7","i7","i7","i7","iv7","iv7","i7","i7","bVI7","V7","i7","V7"], tags: ["blues", "minor"] },
  
  // Jazz
  "ii_V_I_major":       { numerals: ["ii7", "V7", "Imaj7"], tags: ["jazz", "common"] },
  "ii_V_i_minor":       { numerals: ["iiø7", "V7", "i"], tags: ["jazz", "minor"] },
  "rhythm_changes":     { numerals: ["Imaj7", "vi7", "ii7", "V7"], tags: ["jazz", "common"] },
  "tritone_sub":        { numerals: ["ii7", "bII7", "Imaj7"], tags: ["jazz", "advanced"] },
  "coltrane_changes":   { numerals: ["Imaj7", "V7/bVI", "bVImaj7", "V7/III", "IIImaj7", "V7/I", "Imaj7"], tags: ["jazz", "exotic"] },
  "backdoor":           { numerals: ["iv7", "bVII7", "Imaj7"], tags: ["jazz", "advanced"] },
  
  // Gospel / R&B
  "gospel_251":         { numerals: ["ii9", "V13", "Imaj9"], tags: ["gospel", "rb"] },
  "gospel_turnaround":  { numerals: ["I", "I7", "IV", "#IVdim7", "I/V", "vi", "ii7", "V7"], tags: ["gospel"] },
  
  // Classical
  "circle_of_fifths":   { numerals: ["I", "IV", "vii°", "iii", "vi", "ii", "V", "I"], tags: ["classical", "baroque"] },
  "romantic":           { numerals: ["I", "bVI", "IV", "V"], tags: ["classical", "romantic", "cinematic"] },
  "neapolitan":         { numerals: ["i", "bII6", "V", "i"], tags: ["classical", "dramatic"] },
  
  // Modern / Electronic
  "dark_minor":         { numerals: ["i", "bVI", "bIII", "bVII"], tags: ["edm", "cinematic", "modern"] },
  "lofi":               { numerals: ["ii7", "V7", "Imaj7", "vi7"], tags: ["lofi", "chill", "modern"] },
  "trap_soul":          { numerals: ["i", "bVI", "bVII", "iv"], tags: ["trap", "rb", "modern"] },
}
```

### 14.6 Quantization Algorithm Guidance

To quantize a note to a target chord or key:

1. **Note-to-Chord Quantization**:
   - Given a MIDI note and target chord, find the nearest pitch class that belongs to the chord
   - Calculate distance to each chord tone (mod 12), pick the nearest
   - Preserve the octave of the original note as much as possible
   - For ties (equidistant), prefer chord tones in priority order: root > 5th > 3rd > 7th > extensions

2. **Note-to-Scale Quantization**:
   - Same as above but using scale pitch classes instead of chord tones
   - More pitch classes available = less pitch shifting

3. **Chord-Aware Scale Quantization** (recommended):
   - Primary targets: chord tones of current chord
   - Secondary targets: remaining scale tones
   - Avoid targets: notes a semitone above a chord tone (creates dissonance) unless passing

4. **Voice Leading / Smooth Quantization**:
   - When quantizing a melody across chord changes, minimize total pitch movement
   - Prefer common tones (notes shared between consecutive chords)
   - Move by step (1-2 semitones) rather than leap when forced to change

### 14.7 Common Chord Symbol Aliases

For parsing user input, map these aliases to canonical chord types:

```
CHORD_ALIASES = {
  // Major
  "M": "major", "maj": "major", "": "major",
  
  // Minor
  "m": "minor", "min": "minor", "-": "minor",
  
  // Diminished
  "dim": "diminished", "°": "diminished", "o": "diminished",
  
  // Augmented
  "aug": "augmented", "+": "augmented",
  
  // Seventh variations
  "Δ7": "maj7", "M7": "maj7", "△7": "maj7",
  "dom7": "7", "dom": "7",
  "-7": "m7", "min7": "m7",
  "ø": "m7b5", "ø7": "m7b5", "half-dim": "m7b5", "halfdim": "m7b5",
  "°7": "dim7", "o7": "dim7", "full-dim": "dim7",
  "minmaj7": "mMaj7", "m(M7)": "mMaj7", "mΔ7": "mMaj7", "-Δ7": "mMaj7",
  
  // Extended
  "dom9": "9", "dom11": "11", "dom13": "13",
  
  // Suspended
  "sus": "sus4",
  
  // Power
  "5": "5", "power": "5", "(no3)": "5",
}
```

### 14.8 Note Name Generation

To convert a pitch class + key context to the correct note name:

```
SHARP_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
FLAT_NAMES  = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

SHARP_KEYS = ["C", "G", "D", "A", "E", "B", "F#", "C#"]
FLAT_KEYS  = ["F", "Bb", "Eb", "Ab", "Db", "Gb", "Cb"]

// Minor keys follow their relative major
SHARP_MINOR_KEYS = ["Am", "Em", "Bm", "F#m", "C#m", "G#m", "D#m", "A#m"]
FLAT_MINOR_KEYS  = ["Dm", "Gm", "Cm", "Fm", "Bbm", "Ebm", "Abm"]
```

---

## Appendix A: Quick Reference — Roman Numeral Conversion

For any key, convert roman numerals to actual chords:

**Process:**
1. Determine the scale of the key
2. Map each roman numeral to its scale degree
3. Apply the quality (upper case = major, lower case = minor, ° = dim, + = aug)
4. Apply any accidentals (b = flat the root by 1 semitone, # = sharp it)

**Example in G major:**
- I = G, ii = Am, iii = Bm, IV = C, V = D, vi = Em, vii° = F#dim
- bVII = F (borrowed), bVI = Eb (borrowed), bIII = Bb (borrowed)

---

## Appendix B: Quick Reference — Nashville Number System

Nashville numbers use Arabic numerals instead of Roman numerals and are widely used in studio sessions:

| Number | Quality Default | Example in C |
|--------|----------------|-------------|
| 1      | Major          | C            |
| 2      | Minor          | Dm           |
| 3      | Minor          | Em           |
| 4      | Major          | F            |
| 5      | Major (or dom7)| G            |
| 6      | Minor          | Am           |
| 7      | Diminished     | Bdim         |

Conventions: dash = minor (2-), diamond = major 7, caret = sharp, flat sign = flat.

---

## Appendix C: Frequency & MIDI Reference

| Note  | MIDI | Frequency (Hz) |
|-------|------|----------------|
| C0    | 12   | 16.35           |
| A0    | 21   | 27.50           |
| C1    | 24   | 32.70           |
| A1    | 33   | 55.00           |
| C2    | 36   | 65.41           |
| A2    | 45   | 110.00          |
| C3    | 48   | 130.81          |
| A3    | 57   | 220.00          |
| C4    | 60   | 261.63 (Middle C)|
| A4    | 69   | 440.00 (Concert A)|
| C5    | 72   | 523.25          |
| A5    | 81   | 880.00          |
| C6    | 84   | 1046.50         |
| C7    | 96   | 2093.00         |
| C8    | 108  | 4186.01         |

**Formula:** `frequency = 440 * 2^((midi_note - 69) / 12)`

---

*End of reference document. This data is sufficient to build a complete chord/key quantization engine with support for all Western music theory constructs, genre-specific progressions, and correct enharmonic spelling.*
