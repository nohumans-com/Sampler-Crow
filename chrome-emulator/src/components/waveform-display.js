// WaveformDisplay: renders real-time audio waveform from Teensy USB Audio

export class WaveformDisplay {
  constructor(canvas, connectionManager) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.conn = connectionManager;
    this._animating = false;
  }

  start() {
    if (this._animating) return;
    this._animating = true;
    this._draw();
  }

  stop() {
    this._animating = false;
  }

  _draw() {
    if (!this._animating) return;
    requestAnimationFrame(() => this._draw());

    const ctx = this.ctx;
    const w = this.canvas.width;
    const h = this.canvas.height;

    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, w, h);

    const data = this.conn.getWaveformData();
    if (!data) {
      // Draw center line when no audio
      ctx.strokeStyle = '#333';
      ctx.beginPath();
      ctx.moveTo(0, h / 2);
      ctx.lineTo(w, h / 2);
      ctx.stroke();
      return;
    }

    // Draw waveform
    ctx.strokeStyle = '#00d4ff';
    ctx.lineWidth = 1.5;
    ctx.beginPath();

    const sliceWidth = w / data.length;
    let x = 0;

    for (let i = 0; i < data.length; i++) {
      const v = data[i] / 128.0; // 0..2
      const y = (v * h) / 2;

      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
      x += sliceWidth;
    }

    ctx.stroke();

    // Center line (subtle)
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 0.5;
    ctx.beginPath();
    ctx.moveTo(0, h / 2);
    ctx.lineTo(w, h / 2);
    ctx.stroke();
  }
}
