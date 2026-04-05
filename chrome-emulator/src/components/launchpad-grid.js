// LaunchpadGrid: renders an 8x8 pad grid + function buttons on canvas
// Communicates via MIDI channel 16

const GRID_CH = 16; // MIDI channel for grid (1-indexed)
const PAD_SIZE = 44;
const PAD_GAP = 4;
const PAD_RADIUS = 6;
const ROWS = 8;
const COLS = 8;

// Launchpad Mini MK3 color palette (subset - the full palette has 128 colors)
const PALETTE = [
  '#000000', '#1c1c1c', '#7c7c7c', '#fcfcfc', // 0-3
  '#ff4c4c', '#fe0d00', '#590000', '#190000', // 4-7
  '#ffbd6c', '#ff5400', '#591d00', '#271b00', // 8-11
  '#ffff4c', '#ffff00', '#595900', '#191900', // 12-15
  '#88ff4c', '#54ff00', '#1d5900', '#142b00', // 16-19
  '#4cff4c', '#00ff00', '#005900', '#001900', // 20-23
  '#4cff5e', '#00ff19', '#00590d', '#001904', // 24-27
  '#4cff88', '#00ff55', '#00591d', '#001914', // 28-31
  '#4cffb7', '#00ff99', '#005935', '#00190f', // 32-35
  '#4cfcff', '#00e5ff', '#005153', '#001819', // 36-39
  '#4c88ff', '#0055ff', '#001d59', '#000819', // 40-43
  '#4c4cff', '#0000ff', '#000059', '#000019', // 44-47
  '#874cff', '#5400ff', '#190064', '#0f0030', // 48-51
  '#ff4cff', '#ff00ff', '#590059', '#190019', // 52-55
  '#ff4c87', '#ff0054', '#59001d', '#220013', // 56-59
  '#ff1500', '#993500', '#795100', '#436400', // 60-63
  '#033900', '#005735', '#00547f', '#0000ff', // 64-67
  '#00454f', '#2500cc', '#7f00ff', '#b21a7d', // 68-71
  '#402100', '#ff4a00', '#88e106', '#72ff15', // 72-75
  '#00ff87', '#00a9ff', '#002aff', '#6600a1', // 76-79
];

export class LaunchpadGrid {
  constructor(canvas, connectionManager) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.conn = connectionManager;

    // Pad colors (8x8 grid)
    this.padColors = Array.from({ length: ROWS }, () =>
      Array.from({ length: COLS }, () => '#2a2a4a')
    );

    // Top function row colors
    this.topRowColors = Array(COLS).fill('#2a2a4a');
    // Right column colors
    this.rightColColors = Array(ROWS).fill('#2a2a4a');

    this.pressedPads = new Set();

    this._setupEvents();
    this._resize();
    this.draw();
  }

  _resize() {
    const totalSize = (COLS + 1) * (PAD_SIZE + PAD_GAP) + PAD_GAP;
    this.canvas.width = totalSize;
    this.canvas.height = totalSize;
  }

  _padRect(row, col) {
    // Row 0 = top function row, rows 1-8 = pads, col 8 = right function col
    const x = PAD_GAP + col * (PAD_SIZE + PAD_GAP);
    const y = PAD_GAP + row * (PAD_SIZE + PAD_GAP);
    return { x, y, w: PAD_SIZE, h: PAD_SIZE };
  }

  _hitTest(clientX, clientY) {
    const rect = this.canvas.getBoundingClientRect();
    const scaleX = this.canvas.width / rect.width;
    const scaleY = this.canvas.height / rect.height;
    const x = (clientX - rect.left) * scaleX;
    const y = (clientY - rect.top) * scaleY;

    for (let row = 0; row <= ROWS; row++) {
      for (let col = 0; col <= COLS; col++) {
        const r = this._padRect(row, col);
        if (x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h) {
          return { row, col };
        }
      }
    }
    return null;
  }

  _setupEvents() {
    const handlePress = (e) => {
      e.preventDefault();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      const hit = this._hitTest(clientX, clientY);
      if (!hit) return;

      const key = `${hit.row},${hit.col}`;
      this.pressedPads.add(key);

      // Map to Launchpad programmer mode note: (row+1)*10 + (col+1)
      // Row 0 = top row (notes 91-99), Rows 1-8 = pads (notes 11-89)
      const note = (hit.row === 0 ? 9 : (ROWS - hit.row + 1)) * 10 + (hit.col + 1);

      this.conn.sendNoteOn(GRID_CH, note, 127);
      this.draw();
    };

    const handleRelease = (e) => {
      e.preventDefault();
      // Release all pressed pads
      for (const key of this.pressedPads) {
        const [row, col] = key.split(',').map(Number);
        const note = (row === 0 ? 9 : (ROWS - row + 1)) * 10 + (col + 1);
        this.conn.sendNoteOff(GRID_CH, note);
      }
      this.pressedPads.clear();
      this.draw();
    };

    this.canvas.addEventListener('mousedown', handlePress);
    this.canvas.addEventListener('mouseup', handleRelease);
    this.canvas.addEventListener('mouseleave', handleRelease);
    this.canvas.addEventListener('touchstart', handlePress);
    this.canvas.addEventListener('touchend', handleRelease);
  }

  // Called when receiving MIDI from Teensy (LED updates)
  handleMidiIn(data) {
    const status = data[0] & 0xF0;
    const channel = (data[0] & 0x0F) + 1;

    if (channel !== GRID_CH) return;

    if (status === 0x90) { // Note On = set pad color (velocity = palette index)
      const note = data[1];
      const colorIdx = data[2];
      const row = Math.floor(note / 10);
      const col = (note % 10) - 1;

      if (col < 0 || col > 8) return;

      const color = colorIdx < PALETTE.length ? PALETTE[colorIdx] : `hsl(${colorIdx * 2.8}, 80%, 50%)`;

      if (row === 9) {
        // Top function row
        if (col < 8) this.topRowColors[col] = color;
      } else if (col === 8) {
        // Right function column
        const padRow = ROWS - row;
        if (padRow >= 0 && padRow < ROWS) this.rightColColors[padRow] = color;
      } else {
        // Main pad grid
        const padRow = ROWS - row;
        if (padRow >= 0 && padRow < ROWS && col < COLS) {
          this.padColors[padRow][col] = color;
        }
      }
      this.draw();
    }
  }

  setPadColor(row, col, color) {
    if (row >= 0 && row < ROWS && col >= 0 && col < COLS) {
      this.padColors[row][col] = color;
      this.draw();
    }
  }

  clearAll() {
    for (let r = 0; r < ROWS; r++)
      for (let c = 0; c < COLS; c++)
        this.padColors[r][c] = '#2a2a4a';
    this.topRowColors.fill('#2a2a4a');
    this.rightColColors.fill('#2a2a4a');
    this.draw();
  }

  draw() {
    const ctx = this.ctx;
    ctx.fillStyle = '#111122';
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    // Draw all pads
    for (let row = 0; row <= ROWS; row++) {
      for (let col = 0; col <= COLS; col++) {
        const r = this._padRect(row, col);
        const key = `${row},${col}`;
        const pressed = this.pressedPads.has(key);

        let color;
        if (row === 0 && col < COLS) {
          // Top function row
          color = this.topRowColors[col];
        } else if (row === 0 && col === COLS) {
          // Top-right corner (usually not used)
          color = '#1a1a2e';
        } else if (col === COLS) {
          // Right function column
          color = this.rightColColors[row - 1];
        } else {
          // Main pad
          color = this.padColors[row - 1]?.[col] || '#2a2a4a';
        }

        // Draw pad
        ctx.fillStyle = pressed ? '#ffffff' : color;
        ctx.beginPath();
        ctx.roundRect(r.x, r.y, r.w, r.h, PAD_RADIUS);
        ctx.fill();

        // Subtle border
        ctx.strokeStyle = pressed ? '#00d4ff' : '#444';
        ctx.lineWidth = 1;
        ctx.stroke();
      }
    }
  }
}
