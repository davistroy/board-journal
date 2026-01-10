#!/bin/bash
# Setup script for Ralph Wiggum loop
# Creates the state file that the stop hook monitors

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_FILE="${PROJECT_DIR}/.claude/ralph-loop.local.md"

# Default values
MAX_ITERATIONS=50
COMPLETION_PROMISE="COMPLETE"
PROMPT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --max-iterations)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --completion-promise)
            COMPLETION_PROMISE="$2"
            shift 2
            ;;
        *)
            # Anything else is the prompt
            if [[ -z "$PROMPT" ]]; then
                PROMPT="$1"
            else
                PROMPT="$PROMPT $1"
            fi
            shift
            ;;
    esac
done

# Validate prompt
if [[ -z "$PROMPT" ]]; then
    echo "Error: No prompt provided"
    echo "Usage: setup-ralph-loop.sh \"<prompt>\" [--max-iterations N] [--completion-promise TEXT]"
    exit 1
fi

# Validate max-iterations is a number
if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
    echo "Error: --max-iterations must be a number"
    exit 1
fi

# Create the state file
cat > "$STATE_FILE" << EOF
---
iteration: 1
max_iterations: ${MAX_ITERATIONS}
completion_promise: "${COMPLETION_PROMISE}"
active: true
---

${PROMPT}
EOF

echo "Ralph loop initialized:"
echo "  - Max iterations: ${MAX_ITERATIONS}"
echo "  - Completion promise: ${COMPLETION_PROMISE}"
echo "  - State file: ${STATE_FILE}"
echo ""
echo "The loop will run until the completion promise is detected or max iterations reached."
