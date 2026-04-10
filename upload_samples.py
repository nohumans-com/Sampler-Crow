#!/usr/bin/env python3
"""Upload WAV files to Teensy SD card over serial."""
import serial
import serial.tools.list_ports
import sys
import os
import time
import glob

def find_teensy():
    """Find Teensy serial port."""
    for port in serial.tools.list_ports.comports():
        if port.vid == 0x16C0:  # PJRC vendor ID
            return port.device
    # Fallback: look for usbmodem
    ports = glob.glob('/dev/cu.usbmodem*')
    return ports[0] if ports else None

def upload_file(ser, filepath):
    """Upload a single file to Teensy SD card."""
    filename = os.path.basename(filepath)
    filesize = os.path.getsize(filepath)
    print(f"  Uploading {filename} ({filesize} bytes)...", end=" ", flush=True)

    # Send UPLOAD command
    cmd = f"UPLOAD:{filename}:{filesize}\n"
    ser.write(cmd.encode())

    # Wait for READY response
    deadline = time.time() + 5
    while time.time() < deadline:
        line = ser.readline().decode(errors='ignore').strip()
        if line == "READY":
            break
        if line.startswith("ERR:"):
            print(f"FAILED: {line}")
            return False
    else:
        print("FAILED: timeout waiting for READY")
        return False

    # Send raw file bytes
    with open(filepath, 'rb') as f:
        data = f.read()
    ser.write(data)

    # Wait for ACK
    deadline = time.time() + 15
    while time.time() < deadline:
        line = ser.readline().decode(errors='ignore').strip()
        if line.startswith("ACK:UPLOAD:"):
            print("OK")
            return True
        if line.startswith("ERR:"):
            print(f"FAILED: {line}")
            return False
    print("FAILED: timeout waiting for ACK")
    return False

def main():
    sample_dir = os.path.join(os.path.dirname(__file__), "samples")
    if len(sys.argv) > 1:
        files = sys.argv[1:]
    else:
        files = sorted(glob.glob(os.path.join(sample_dir, "*.wav")))

    if not files:
        print("No WAV files found. Put them in ./samples/ or pass paths as arguments.")
        sys.exit(1)

    port = find_teensy()
    if not port:
        print("Teensy not found!")
        sys.exit(1)

    print(f"Connecting to {port}...")
    ser = serial.Serial(port, 115200, timeout=2)
    time.sleep(0.5)  # let Teensy settle
    ser.reset_input_buffer()

    print(f"Uploading {len(files)} files:")
    ok = 0
    for f in files:
        if upload_file(ser, f):
            ok += 1

    # Verify
    ser.write(b"SAMPLELIST\n")
    time.sleep(0.5)
    while ser.in_waiting:
        line = ser.readline().decode(errors='ignore').strip()
        if line.startswith("SAMPLES:"):
            print(f"\nFiles on SD: {line}")

    ser.close()
    print(f"\nDone: {ok}/{len(files)} uploaded successfully.")

if __name__ == "__main__":
    main()
