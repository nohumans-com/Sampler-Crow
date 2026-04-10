#!/bin/bash
# Sampler-Crow: Build + Flash + Deploy
# Usage: ./deploy.sh [firmware|app|all]
# Default: all

set -e
export PATH="$PATH:/Users/lev/Library/Python/3.9/bin"
cd "$(dirname "$0")"

TARGET="${1:-all}"

build_firmware() {
    echo "=== Building Teensy firmware ==="
    pio run 2>&1 | tail -5
}

flash_firmware() {
    echo "=== Flashing Teensy ==="
    pio run -t upload 2>&1 | tail -5
}

build_app() {
    echo "=== Building macOS app ==="
    cd SamplerCrowApp
    swift build -c release 2>&1 | tail -3
    cd ..
}

deploy_app() {
    echo "=== Deploying to /Applications ==="
    cp SamplerCrowApp/.build/release/SamplerCrowApp "/Applications/Sampler Crow.app/Contents/MacOS/Sampler Crow"
    codesign --force --sign - "/Applications/Sampler Crow.app/Contents/MacOS/Sampler Crow" 2>&1
}

case "$TARGET" in
    firmware)
        build_firmware
        flash_firmware
        ;;
    app)
        build_app
        deploy_app
        ;;
    all)
        build_firmware
        flash_firmware
        build_app
        deploy_app
        ;;
    *)
        echo "Usage: $0 [firmware|app|all]"
        exit 1
        ;;
esac

echo "=== Done ==="
