# /ralph-loop

Start a Ralph Wiggum loop in the current session. Ralph loops enable iterative, self-referential AI development where Claude autonomously works on tasks through repeated iterations until completion.

## Usage

```
/ralph-loop "<prompt>" [--max-iterations <n>] [--completion-promise "<text>"]
```

## Arguments

- `<prompt>` - The task description for Claude to work on iteratively
- `--max-iterations <n>` - Maximum number of iterations before stopping (default: 50)
- `--completion-promise "<text>"` - Text that signals task completion (default: "COMPLETE")

## How It Works

1. Your prompt is saved to `.claude/ralph-loop.local.md`
2. A Stop hook intercepts Claude's exit attempts
3. If completion promise not found and max iterations not reached, the prompt is re-fed
4. Each iteration sees the modified files and git history from previous work
5. Claude autonomously improves by reading its own past work

## Examples

### Basic usage
```
/ralph-loop "Build a REST API for todos with CRUD operations and tests. Output <promise>COMPLETE</promise> when done."
```

### With iteration limit
```
/ralph-loop "Refactor the database layer to use repository pattern" --max-iterations 20
```

### With custom completion promise
```
/ralph-loop "Fix all failing tests in the project" --completion-promise "ALL_TESTS_PASSING"
```

## Best Practices

1. **Clear completion criteria** - Define exactly what "done" means
2. **Incremental goals** - Break complex tasks into phases
3. **Self-correction** - Include instructions for handling failures
4. **Safety limits** - Always use --max-iterations as a safety net

## Instructions

When this command is invoked:

1. Parse the arguments to extract prompt, max-iterations, and completion-promise
2. Create or update `.claude/ralph-loop.local.md` with YAML frontmatter:
   ```yaml
   ---
   iteration: 1
   max_iterations: <max-iterations value or 50>
   completion_promise: "<completion-promise value or COMPLETE>"
   active: true
   ---

   <The user's prompt>
   ```
3. Confirm the loop is active and display the configuration
4. Begin working on the task described in the prompt
5. The Stop hook will handle re-feeding the prompt on subsequent iterations

## Allowed Tools

All tools are allowed for this command.
