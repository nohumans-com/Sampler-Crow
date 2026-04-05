import { ConnectionManager } from './connections/connection-manager.js';
import { LaunchpadGrid } from './components/launchpad-grid.js';
import { WaveformDisplay } from './components/waveform-display.js';

// --- Initialize ---
const conn = new ConnectionManager();
const grid = new LaunchpadGrid(document.getElementById('launchpad-canvas'), conn);
const waveform = new WaveformDisplay(document.getElementById('waveform-canvas'), conn);

const consoleOutput = document.getElementById('console-output');
const consoleInput = document.getElementById('console-input');
const btnConnect = document.getElementById('btn-connect');
const btnSend = document.getElementById('btn-send');
const cpuDisplay = document.getElementById('cpu-display');
const memDisplay = document.getElementById('mem-display');

// --- Console logging ---
function logToConsole(text, type = 'info') {
  const line = document.createElement('div');
  line.className = `msg-${type}`;
  line.textContent = text;
  consoleOutput.appendChild(line);

  // Auto-scroll, keep max 500 lines
  while (consoleOutput.children.length > 500) {
    consoleOutput.removeChild(consoleOutput.firstChild);
  }
  consoleOutput.scrollTop = consoleOutput.scrollHeight;
}

// --- Status updates ---
function updateStatusDots(status) {
  document.getElementById('midi-status').className =
    `status-dot ${status.midi ? 'connected' : 'disconnected'}`;
  document.getElementById('serial-status').className =
    `status-dot ${status.serial ? 'connected' : 'disconnected'}`;
  document.getElementById('audio-status').className =
    `status-dot ${status.audio ? 'connected' : 'disconnected'}`;
}

// --- Callbacks ---
conn.onStatusChange = updateStatusDots;

conn.onMidiMessage = (data) => {
  // Forward grid LED messages to the LaunchpadGrid
  grid.handleMidiIn(data);

  // Log non-grid MIDI
  const channel = (data[0] & 0x0F) + 1;
  if (channel !== 16) {
    const status = data[0] & 0xF0;
    const names = { 0x90: 'NoteOn', 0x80: 'NoteOff', 0xB0: 'CC' };
    logToConsole(`MIDI In: ${names[status] || '??'} ch${channel} ${data[1]} ${data[2] || 0}`, 'in');
  }
};

conn.onSerialMessage = (line) => {
  // Parse known status messages
  if (line.startsWith('CPU:')) {
    cpuDisplay.textContent = `CPU: ${line.substring(4)}%`;
    return;
  }
  if (line.startsWith('MEM:')) {
    memDisplay.textContent = `MEM: ${line.substring(4)}`;
    return;
  }
  if (line.startsWith('POT:') || line.startsWith('BTN:')) {
    logToConsole(`< ${line}`, 'in');
    return;
  }

  logToConsole(`< ${line}`, 'in');
};

// --- Connect button ---
btnConnect.addEventListener('click', async () => {
  btnConnect.disabled = true;
  btnConnect.textContent = 'Connecting...';

  try {
    const results = await conn.connectAll();
    logToConsole(`Connected: MIDI=${results.midi} Serial=${results.serial} Audio=${results.audio}`, 'info');

    if (results.audio) {
      waveform.start();
    }

    // Send PING to verify Teensy communication
    if (results.serial) {
      await conn.sendSerial('PING');
    }

    btnConnect.textContent = 'Connected';
  } catch (e) {
    logToConsole(`Connection error: ${e.message}`, 'info');
    btnConnect.textContent = 'Retry';
    btnConnect.disabled = false;
  }
});

// --- Serial console input ---
async function sendConsoleCommand() {
  const text = consoleInput.value.trim();
  if (!text) return;
  logToConsole(`> ${text}`, 'out');
  await conn.sendSerial(text);
  consoleInput.value = '';
}

btnSend.addEventListener('click', sendConsoleCommand);
consoleInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') sendConsoleCommand();
});

// --- Keyboard MIDI (for testing without grid) ---
const keyNoteMap = {
  'a': 60, 'w': 61, 's': 62, 'e': 63, 'd': 64,
  'f': 65, 't': 66, 'g': 67, 'y': 68, 'h': 69,
  'u': 70, 'j': 71, 'k': 72
};
const activeKeys = new Set();

document.addEventListener('keydown', (e) => {
  if (e.target === consoleInput) return;
  const note = keyNoteMap[e.key];
  if (note && !activeKeys.has(e.key)) {
    activeKeys.add(e.key);
    conn.sendNoteOn(1, note, 100);
  }
});

document.addEventListener('keyup', (e) => {
  const note = keyNoteMap[e.key];
  if (note) {
    activeKeys.delete(e.key);
    conn.sendNoteOff(1, note);
  }
});

// --- Init message ---
logToConsole('Sampler-Crow Emulator v0.1', 'info');
logToConsole('Click "Connect" to link to Teensy 4.1', 'info');
logToConsole('Keyboard: A-K = piano keys (C4-C5)', 'info');
