# Ralph Wiggum Stop Hook (PowerShell version)
# Intercepts Claude's exit attempts during active ralph-loop sessions
# and re-feeds the prompt for the next iteration.

$ErrorActionPreference = "Stop"

$ProjectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { Get-Location }
$StateFile = Join-Path $ProjectDir ".claude\ralph-loop.local.md"

# If no state file exists, allow exit
if (-not (Test-Path $StateFile)) {
    Write-Output '{"decision": "allow"}'
    exit 0
}

# Read the state file
$StateContent = Get-Content $StateFile -Raw

# Extract YAML frontmatter values
function Extract-YamlValue {
    param([string]$Key)
    if ($StateContent -match "(?m)^${Key}:\s*`"?([^`"\r\n]+)`"?") {
        return $matches[1]
    }
    return $null
}

$Iteration = Extract-YamlValue "iteration"
$MaxIterations = Extract-YamlValue "max_iterations"
$CompletionPromise = Extract-YamlValue "completion_promise"
$Active = Extract-YamlValue "active"

# Validate we have required values
if (-not $Iteration -or -not $MaxIterations -or -not $Active) {
    # Malformed state file, clean up and allow exit
    Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
    Write-Output '{"decision": "allow"}'
    exit 0
}

# If not active, allow exit
if ($Active -ne "true") {
    Write-Output '{"decision": "allow"}'
    exit 0
}

# Check if max iterations reached
if ([int]$Iteration -ge [int]$MaxIterations) {
    Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
    Write-Output '{"decision": "allow", "message": "Ralph loop completed: max iterations reached"}'
    exit 0
}

# Extract the prompt (everything after the second ---)
$Parts = $StateContent -split "---", 3
$Prompt = if ($Parts.Count -ge 3) { $Parts[2].Trim() } else { "" }

# Check for completion promise in the transcript if available
if ($CompletionPromise -and $env:CLAUDE_TRANSCRIPT_FILE -and (Test-Path $env:CLAUDE_TRANSCRIPT_FILE)) {
    $LastLines = Get-Content $env:CLAUDE_TRANSCRIPT_FILE -Tail 100 -ErrorAction SilentlyContinue
    if ($LastLines -match [regex]::Escape($CompletionPromise)) {
        Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
        Write-Output '{"decision": "allow", "message": "Ralph loop completed: completion promise found"}'
        exit 0
    }
}

# Increment iteration counter
$NewIteration = [int]$Iteration + 1

# Update the state file with new iteration count
$NewContent = @"
---
iteration: $NewIteration
max_iterations: $MaxIterations
completion_promise: "$CompletionPromise"
active: true
---

$Prompt
"@
Set-Content -Path $StateFile -Value $NewContent -NoNewline

# Build the continuation message
$ContinueMsg = @"
[Ralph Loop - Iteration $NewIteration/$MaxIterations]

Continue working on the task. Your previous work is preserved in files and git history.

Review your progress and continue until you can output the completion promise: $CompletionPromise

Original task:
$Prompt
"@

# Escape the message for JSON
$EscapedMsg = $ContinueMsg | ConvertTo-Json

# Block exit and re-feed the prompt
Write-Output "{`"decision`": `"block`", `"message`": $EscapedMsg}"
