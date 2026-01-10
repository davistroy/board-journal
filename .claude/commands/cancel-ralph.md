# /cancel-ralph

Cancel the active Ralph Wiggum loop.

## Usage

```
/cancel-ralph
```

## Description

This command stops any active Ralph loop by removing the state file. Use this when:
- You want to stop the iterative process early
- The loop is stuck or not making progress
- You need to start a different task

## Instructions

When this command is invoked:

1. Check if `.claude/ralph-loop.local.md` exists using Bash:
   ```bash
   test -f .claude/ralph-loop.local.md && echo "exists" || echo "not found"
   ```

2. If the file does NOT exist:
   - Report: "No active Ralph loop found."

3. If the file EXISTS:
   - Read the file to extract the current iteration count from the YAML frontmatter
   - Delete the file:
     ```bash
     rm .claude/ralph-loop.local.md
     ```
   - Report: "Ralph loop cancelled at iteration N."

## Allowed Tools

- Bash (for file existence check and deletion)
- Read (for reading the state file)

$HIDDEN
