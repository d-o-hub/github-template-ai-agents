#!/bin/bash
# Capture responsive screenshots at different viewport sizes
# Usage: ./scripts/capture/capture-responsive.sh [url] [output-dir]

set -e

BASE_URL="${1:-https://web-eight-ivory-29.vercel.app}"
OUTPUT_DIR="${2:-assets/screenshots/responsive}"

echo "📸 Capturing responsive screenshots"
echo "   URL: $BASE_URL"
echo "   Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

VIEWPORTS=(
    "1920x1080:desktop"
    "1440x900:laptop"
    "1024x768:tablet-landscape"
    "768x1024:tablet-portrait"
    "375x812:iphone"
    "360x640:android"
)

for vp in "${VIEWPORTS[@]}"; do
    IFS=':' read -r size name <<< "$vp"
    IFS='x' read -r width height <<< "$size"

    echo "  → ${name} (${width}x${height})"
    agent-browser set viewport "$width" "$height" > /dev/null 2>&1
    agent-browser open "$BASE_URL" > /dev/null 2>&1
    agent-browser wait --load networkidle > /dev/null 2>&1
    agent-browser screenshot "$OUTPUT_DIR/${name}.png" > /dev/null 2>&1
    agent-browser close > /dev/null 2>&1
done

echo ""
echo "✅ Responsive screenshots saved to $OUTPUT_DIR"
echo ""
ls -la "$OUTPUT_DIR"
