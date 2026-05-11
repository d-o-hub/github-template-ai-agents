#!/bin/bash
# Capture a multi-step flow
# Usage: ./scripts/capture/capture-flow.sh [flow-name] [base-url]

set -e

FLOW_NAME="${1:-resolve}"
BASE_URL="${2:-https://web-eight-ivory-29.vercel.app}"
OUTPUT_DIR="assets/screenshots/flow-${FLOW_NAME}"

echo "📸 Capturing flow: $FLOW_NAME"
echo "   URL: $BASE_URL"
echo "   Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

case "$FLOW_NAME" in
    resolve)
        # Step 1: Open homepage
        echo "  → Step 1: Homepage"
        agent-browser open "$BASE_URL" > /dev/null 2>&1
        agent-browser wait --load networkidle > /dev/null 2>&1
        agent-browser screenshot "$OUTPUT_DIR/01-homepage.png" > /dev/null 2>&1

        # Step 2: Enter query
        echo "  → Step 2: Enter query"
        agent-browser snapshot -i > /dev/null 2>&1
        agent-browser fill @e5 "Rust async runtime" > /dev/null 2>&1
        agent-browser screenshot "$OUTPUT_DIR/02-enter-query.png" > /dev/null 2>&1

        # Step 3: Click resolve
        echo "  → Step 3: Click resolve"
        agent-browser click @e6 > /dev/null 2>&1
        agent-browser wait 3000 > /dev/null 2>&1
        agent-browser screenshot "$OUTPUT_DIR/03-resolving.png" > /dev/null 2>&1

        # Step 4: Result
        echo "  → Step 4: Result"
        agent-browser wait --load networkidle > /dev/null 2>&1
        agent-browser screenshot "$OUTPUT_DIR/04-result.png" > /dev/null 2>&1

        agent-browser close > /dev/null 2>&1
        ;;

    help)
        # Help page flow
        echo "  → Capture help page"
        agent-browser open "$BASE_URL/help" > /dev/null 2>&1
        agent-browser wait --load networkidle > /dev/null 2>&1
        agent-browser screenshot "$OUTPUT_DIR/help-top.png" > /dev/null 2>&1

        agent-browser scroll down 500 > /dev/null 2>&1
        agent-browser screenshot "$OUTPUT_DIR/help-mid.png" > /dev/null 2>&1

        agent-browser scroll down 500 > /dev/null 2>&1
        agent-browser screenshot "$OUTPUT_DIR/help-bottom.png" > /dev/null 2>&1

        agent-browser close > /dev/null 2>&1
        ;;

    *)
        echo "❌ Unknown flow: $FLOW_NAME"
        echo "   Available flows: resolve, help"
        exit 1
        ;;
esac

echo ""
echo "✅ Flow '$FLOW_NAME' captured to $OUTPUT_DIR"
echo ""
ls -la "$OUTPUT_DIR"
