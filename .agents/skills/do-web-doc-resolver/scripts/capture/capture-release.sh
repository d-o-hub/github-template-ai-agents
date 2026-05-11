#!/bin/bash
# Capture screenshots for a release
# Usage: ./scripts/capture/capture-release.sh [version] [base-url]

set -e

VERSION="${1:-$(node -p "require('../web/package.json').version" 2>/dev/null || echo "0.1.0")}"
BASE_URL="${2:-https://web-eight-ivory-29.vercel.app}"
OUTPUT_DIR="assets/screenshots/release-v${VERSION}"

echo "📸 Capturing release v${VERSION}..."
echo "   URL: $BASE_URL"
echo "   Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# Homepage
echo "  → Homepage..."
agent-browser open "$BASE_URL" > /dev/null 2>&1
agent-browser wait --load networkidle > /dev/null 2>&1
agent-browser screenshot "$OUTPUT_DIR/homepage.png" > /dev/null 2>&1
agent-browser close > /dev/null 2>&1

# Help page
echo "  → Help page..."
agent-browser open "$BASE_URL/help" > /dev/null 2>&1
agent-browser wait --load networkidle > /dev/null 2>&1
agent-browser screenshot "$OUTPUT_DIR/help-page.png" > /dev/null 2>&1
agent-browser close > /dev/null 2>&1

# Full page homepage
echo "  → Full page..."
agent-browser open "$BASE_URL" > /dev/null 2>&1
agent-browser wait --load networkidle > /dev/null 2>&1
agent-browser screenshot --full "$OUTPUT_DIR/homepage-full.png" > /dev/null 2>&1
agent-browser close > /dev/null 2>&1

# Annotated
echo "  → Annotated..."
agent-browser open "$BASE_URL" > /dev/null 2>&1
agent-browser wait --load networkidle > /dev/null 2>&1
agent-browser screenshot --annotate "$OUTPUT_DIR/homepage-annotated.png" > /dev/null 2>&1
agent-browser close > /dev/null 2>&1

echo ""
echo "✅ Release v${VERSION} screenshots saved to $OUTPUT_DIR"
echo ""
ls -la "$OUTPUT_DIR"
