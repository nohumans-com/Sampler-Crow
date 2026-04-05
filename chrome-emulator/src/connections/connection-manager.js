// ConnectionManager: handles Web MIDI, WebSerial, and Web Audio connections to Teensy

export class ConnectionManager {
  constructor() {
    this.midiAccess = null;
    this.midiIn = null;
    this.midiOut = null;
    this.serialPort = null;
    this.serialReader = null;
    this.serialWriter = null;
    this.audioContext = null;
    this.audioSource = null;
    this.analyserNode = null;

    this.onMidiMessage = null;    // callback(data)
    this.onSerialMessage = null;  // callback(line)
    this.onStatusChange = null;   // callback({midi, serial, audio})
  }

  get status() {
    return {
      midi: !!this.midiIn && !!this.midiOut,
      serial: !!this.serialWriter,
      audio: !!this.analyserNode
    };
  }

  async connectAll() {
    const results = { midi: false, serial: false, audio: false };

    // MIDI - no user gesture needed
    try {
      await this.connectMidi();
      results.midi = true;
    } catch (e) {
      console.warn('MIDI connect failed:', e.message);
    }

    // Serial - requires user gesture (this is called from button click)
    try {
      await this.connectSerial();
      results.serial = true;
    } catch (e) {
      console.warn('Serial connect failed:', e.message);
    }

    // Audio - requires permission
    try {
      await this.connectAudio();
      results.audio = true;
    } catch (e) {
      console.warn('Audio connect failed:', e.message);
    }

    this.onStatusChange?.(this.status);
    return results;
  }

  // --- MIDI ---
  async connectMidi() {
    if (!navigator.requestMIDIAccess) {
      throw new Error('Web MIDI API not supported. Use Chrome.');
    }

    this.midiAccess = await navigator.requestMIDIAccess({ sysex: true });

    // Find Teensy MIDI device
    for (const input of this.midiAccess.inputs.values()) {
      if (input.name?.toLowerCase().includes('teensy')) {
        this.midiIn = input;
        break;
      }
    }
    for (const output of this.midiAccess.outputs.values()) {
      if (output.name?.toLowerCase().includes('teensy')) {
        this.midiOut = output;
        break;
      }
    }

    // If no Teensy found, use first available
    if (!this.midiIn && this.midiAccess.inputs.size > 0) {
      this.midiIn = this.midiAccess.inputs.values().next().value;
    }
    if (!this.midiOut && this.midiAccess.outputs.size > 0) {
      this.midiOut = this.midiAccess.outputs.values().next().value;
    }

    if (this.midiIn) {
      this.midiIn.onmidimessage = (event) => {
        this.onMidiMessage?.(event.data);
      };
      console.log('MIDI connected:', this.midiIn.name, '/', this.midiOut?.name);
    } else {
      throw new Error('No MIDI devices found');
    }
  }

  sendMidi(data) {
    if (this.midiOut) {
      this.midiOut.send(data);
    }
  }

  // Send Note On (channel is 1-indexed)
  sendNoteOn(channel, note, velocity) {
    this.sendMidi([0x90 | (channel - 1), note, velocity]);
  }

  // Send Note Off
  sendNoteOff(channel, note) {
    this.sendMidi([0x80 | (channel - 1), note, 0]);
  }

  // --- Serial ---
  async connectSerial() {
    if (!navigator.serial) {
      throw new Error('WebSerial API not supported. Use Chrome.');
    }

    this.serialPort = await navigator.serial.requestPort();
    await this.serialPort.open({ baudRate: 115200 });

    // Writer
    const textEncoder = new TextEncoderStream();
    textEncoder.readable.pipeTo(this.serialPort.writable);
    this.serialWriter = textEncoder.writable.getWriter();

    // Reader
    this._startSerialReader();
    console.log('Serial connected');
  }

  async _startSerialReader() {
    const textDecoder = new TextDecoderStream();
    this.serialPort.readable.pipeTo(textDecoder.writable);
    const reader = textDecoder.readable.getReader();
    let buffer = '';

    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += value;
        const lines = buffer.split('\n');
        buffer = lines.pop(); // keep incomplete line
        for (const line of lines) {
          if (line.trim()) {
            this.onSerialMessage?.(line.trim());
          }
        }
      }
    } catch (e) {
      console.warn('Serial read error:', e.message);
    }
  }

  async sendSerial(text) {
    if (this.serialWriter) {
      await this.serialWriter.write(text + '\n');
    }
  }

  // --- Audio ---
  async connectAudio() {
    this.audioContext = new AudioContext({ sampleRate: 44100 });

    // Find Teensy audio device
    const devices = await navigator.mediaDevices.enumerateDevices();
    const teensyAudio = devices.find(d =>
      d.kind === 'audioinput' && d.label.toLowerCase().includes('teensy')
    );

    const constraints = {
      audio: teensyAudio
        ? { deviceId: { exact: teensyAudio.deviceId } }
        : true // fallback to default
    };

    const stream = await navigator.mediaDevices.getUserMedia(constraints);
    this.audioSource = this.audioContext.createMediaStreamSource(stream);

    // Analyser for waveform display
    this.analyserNode = this.audioContext.createAnalyser();
    this.analyserNode.fftSize = 2048;
    this.audioSource.connect(this.analyserNode);

    // Also play through speakers
    this.audioSource.connect(this.audioContext.destination);

    console.log('Audio connected:', teensyAudio?.label || 'default device');
  }

  getWaveformData() {
    if (!this.analyserNode) return null;
    const data = new Uint8Array(this.analyserNode.frequencyBinCount);
    this.analyserNode.getByteTimeDomainData(data);
    return data;
  }

  disconnect() {
    if (this.midiIn) {
      this.midiIn.onmidimessage = null;
      this.midiIn = null;
    }
    this.midiOut = null;
    if (this.serialPort) {
      this.serialPort.close().catch(() => {});
      this.serialPort = null;
      this.serialWriter = null;
    }
    if (this.audioContext) {
      this.audioContext.close().catch(() => {});
      this.audioContext = null;
      this.analyserNode = null;
    }
    this.onStatusChange?.(this.status);
  }
}
