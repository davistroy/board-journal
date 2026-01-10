#!/bin/bash
# Ralph Wiggum Stop Hook
# Intercepts Claude's exit attempts during active ralph-loop sessions
# and re-feeds the prompt for the next iteration.

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_FILE="${PROJECT_DIR}/.claude/ralph-loop.local.md"

# If no state file exists, allow exit
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Read the state file
STATE_CONTENT=$(cat "$STATE_FILE")

# Extract YAML frontmatter values
extract_yaml_value() {
    local key="$1"
    echo "$STATE_CONTENT" | sed -n "/^---$/,/^---$/p" | grep "^${key}:" | sed "s/^${key}:[[:space:]]*//" | tr -d '"'
}

ITERATION=$(extract_yaml_value "iteration")
MAX_ITERATIONS=$(extract_yaml_value "max_iterations")
COMPLETION_PROMISE=$(extract_yaml_value "completion_promise")
ACTIVE=$(extract_yaml_value "active")

# Validate we have required values
if [[ -z "$ITERATION" ]] || [[ -z "$MAX_ITERATIONS" ]] || [[ -z "$ACTIVE" ]]; then
    # Malformed state file, clean up and allow exit
    rm -f "$STATE_FILE"
    echo '{"decision": "allow"}'
    exit 0
fi

# If not active, allow exit
if [[ "$ACTIVE" != "true" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Check if max iterations reached
if [[ "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
    rm -f "$STATE_FILE"
    echo '{"decision": "allow", "message": "Ralph loop completed: max iterations reached"}'
    exit 0
fi

# Extract the prompt (everything after the second ---)
PROMPT=$(echo "$STATE_CONTENT" | sed -n '/^---$/,/^---$/!p' | tail -n +1)

# Check for completion promise in the transcript if available
if [[ -n "$COMPLETION_PROMISE" ]] && [[ -n "$CLAUDE_TRANSCRIPT_FILE" ]] && [[ -f "$CLAUDE_TRANSCRIPT_FILE" ]]; then
    # Get the last assistant message from the transcript
    LAST_RESPONSE=$(tail -100 "$CLAUDE_TRANSCRIPT_FILE" 2>/dev/null | grep -o "$COMPLETION_PROMISE" || true)

    if [[ -n "$LAST_RESPONSE" ]]; then
        rm -f "$STATE_FILE"
        echo '{"decision": "allow", "message": "Ralph loop completed: completion promise found"}'
        exit 0
    fi
fi

# Increment iteration counter
NEW_ITERATION=$((ITERATION + 1))

# Update the state file with new iteration count
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" << EOF
---
iteration: ${NEW_ITERATION}
max_iterations: ${MAX_ITERATIONS}
completion_promise: "${COMPLETION_PROMISE}"
active: true
---

${PROMPT}
EOF
mv "$TEMP_FILE" "$STATE_FILE"

# Build the continuation message
CONTINUE_MSG="[Ralph Loop - Iteration ${NEW_ITERATION}/${MAX_ITERATIONS}]

Continue working on the task. Your previous work is preserved in files and git history.

Review your progress and continue until you can output the completion promise: ${COMPLETION_PROMISE}

Original task:
${PROMPT}"

# Escape the message for JSON
ESCAPED_MSG=$(echo "$CONTINUE_MSG" | jq -Rs .)

# Block exit and re-feed the prompt
cat << EOF
{"decision": "block", "message": ${ESCAPED_MSG}}
EOF
