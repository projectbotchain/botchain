#!/usr/bin/env bash
# Ralph loop runner - iteratively implement tasks from IMPLEMENTATION_PLAN.md
set -euo pipefail

# Resolve script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"  # Git repo is in same dir as script

# Find claude CLI - check common locations
if command -v claude &>/dev/null; then
    CLAUDE_CMD="claude"
elif [[ -x "$HOME/.local/bin/claude" ]]; then
    CLAUDE_CMD="$HOME/.local/bin/claude"
elif [[ -x "/root/.local/bin/claude" ]]; then
    CLAUDE_CMD="/root/.local/bin/claude"
else
    echo "Error: claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

# Configuration - paths relative to SCRIPT_DIR for prompts, REPO_ROOT for execution
PLAN_FILE="$SCRIPT_DIR/IMPLEMENTATION_PLAN.md"
LOG_DIR="$SCRIPT_DIR/logs"

# Determine prompt file based on mode
MODE="build"
WORK_SCOPE=""
PROMPT_FILE="$SCRIPT_DIR/PROMPT_build.md"
MAX_ITERATIONS=0  # 0 = unlimited

if [[ "${1:-}" == "plan" ]]; then
    MODE="plan"
    PROMPT_FILE="$SCRIPT_DIR/PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
elif [[ "${1:-}" == "plan-work" ]]; then
    MODE="plan-work"
    PROMPT_FILE="$SCRIPT_DIR/PROMPT_plan_work.md"
    WORK_SCOPE="${2:-}"
    MAX_ITERATIONS=${3:-0}
    if [[ -z "$WORK_SCOPE" ]]; then
        echo "Error: plan-work requires a scope description"
        echo "Usage: ./loopclaude.sh plan-work \"description of work scope\""
        exit 1
    fi
elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS=$1
fi

mkdir -p "$LOG_DIR"

count_remaining() {
    grep '^- \[ \]' "$PLAN_FILE" 2>/dev/null | wc -l || true
}

count_completed() {
    grep '^- \[x\]' "$PLAN_FILE" 2>/dev/null | wc -l || true
}

count_blocked() {
    grep 'Blocked:' "$PLAN_FILE" 2>/dev/null | wc -l || true
}

# Verify files exist
if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

# Plan file is only required in build mode (plan mode creates it)
if [[ "$MODE" == "build" ]] && [[ ! -f "$PLAN_FILE" ]]; then
    echo "Error: $PLAN_FILE not found"
    echo "Run './loopclaude.sh plan' first to create the implementation plan."
    exit 1
fi

# In plan mode, create empty plan file if it doesn't exist
if [[ "$MODE" == "plan" ]] && [[ ! -f "$PLAN_FILE" ]]; then
    echo "Creating initial $PLAN_FILE..."
    echo "# Implementation Plan" > "$PLAN_FILE"
    echo "" >> "$PLAN_FILE"
    echo "<!-- This file will be populated by the planning run -->" >> "$PLAN_FILE"
    echo "" >> "$PLAN_FILE"
fi

# Header
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Ralph Loop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Mode:   $MODE"
echo "  Root:   $REPO_ROOT"
echo "  Prompt: $PROMPT_FILE"
echo "  Plan:   $PLAN_FILE"
[[ "$MAX_ITERATIONS" -gt 0 ]] && echo "  Max:    $MAX_ITERATIONS iterations"
[[ "$MAX_ITERATIONS" -eq 0 ]] && echo "  Max:    unlimited"
[[ -n "$WORK_SCOPE" ]] && echo "  Scope:  $WORK_SCOPE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Plan mode: run once to generate the plan
if [[ "$MODE" == "plan" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Planning iteration | Generating implementation plan..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    timestamp=$(date +%Y%m%d-%H%M%S)
    log_file="$LOG_DIR/plan-${timestamp}.log"
    
    prompt_content=$(cat "$PROMPT_FILE")
    
    echo "Running Claude Code from $REPO_ROOT..."
    pushd "$REPO_ROOT" > /dev/null
    if $CLAUDE_CMD --dangerously-skip-permissions -p "$prompt_content" 2>&1 | tee "$log_file"; then
        echo "Planning completed successfully"
    else
        echo "Planning exited with error. Check $log_file"
    fi
    popd > /dev/null
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Planning Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Plan file: $PLAN_FILE"
    echo "  Tasks:     $(count_remaining) remaining, $(count_completed) completed"
    echo "  Log:       $log_file"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

iteration=0
while true; do
    iteration=$((iteration + 1))
    remaining=$(count_remaining)
    completed=$(count_completed)
    timestamp=$(date +%Y%m%d-%H%M%S)
    log_file="$LOG_DIR/run-${iteration}-${timestamp}.log"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Iteration $iteration | Remaining: $remaining | Completed: $completed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ "$remaining" -eq 0 ]]; then
        echo "All tasks complete!"
        break
    fi

    if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$iteration" -gt "$MAX_ITERATIONS" ]]; then
        echo "Max iterations ($MAX_ITERATIONS) reached. $remaining tasks remaining."
        exit 1
    fi

    # Build prompt with scope substitution for plan-work mode
    if [[ "$MODE" == "plan-work" ]]; then
        export WORK_SCOPE
        prompt_content=$(envsubst < "$PROMPT_FILE")
    else
        prompt_content=$(cat "$PROMPT_FILE")
    fi

    # Run Claude Code from repo root
    echo "Running Claude Code from $REPO_ROOT..."
    pushd "$REPO_ROOT" > /dev/null
    if $CLAUDE_CMD --dangerously-skip-permissions -p "$prompt_content" 2>&1 | tee "$log_file"; then
        echo "Claude Code completed successfully"
    else
        if rg -q "Error: No messages returned" "$log_file"; then
            echo "Claude Code returned no messages (likely transient). Retrying after 5s..."
            sleep 5
            continue
        fi
        echo "Claude Code exited with error, checking if progress was made..."
    fi
    popd > /dev/null

    # Check progress
    new_remaining=$(count_remaining)
    if [[ "$new_remaining" -eq "$remaining" ]]; then
        echo "No progress made this iteration. Check $log_file"
        echo "Waiting 10s before retry..."
        sleep 10
    else
        echo "Progress: $remaining -> $new_remaining tasks"
    fi

    # Auto-commit if enabled (from repo root)
    if [[ "${RALPH_AUTOCOMMIT:-0}" == "1" ]] && [[ "$MODE" == "build" ]]; then
        if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
            msg="ralph: iteration $iteration"
            echo "Committing: $msg"
            git -C "$REPO_ROOT" add -A && git -C "$REPO_ROOT" commit -m "$msg" || echo "Commit failed"
        fi
    fi

    sleep 2
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total iterations: $iteration"
echo "  Tasks completed:  $(count_completed)"
echo "  Tasks blocked:    $(count_blocked)"
echo "  Logs:             $LOG_DIR/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
