#!/usr/bin/env bash
# Fixture tests for hooks/session-start.
#
# The hook is the only executable code in this plugin, and every defect found in it so far
# came from code review rather than from running it. Run: tests/run.sh

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/session-start"
RULES='## Token Efficiency

### Agent Workflow

- a rule
'
pass=0
fail=0

# Each sandbox is a fresh temp dir with its own fake HOME, so the developer's real
# ~/.claude never decides a test result.
sandbox() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/home/.claude" "$dir/work"
  printf '%s' "$dir"
}

# run <workdir> <home|-> <quiet|-> -> stdout of the hook, exit code in $rc
run_hook() {
  local workdir="$1" home="$2" quiet="$3" out rc
  if [ "$home" = "-" ]; then
    out="$(cd "$workdir" && env -u HOME CLAUDE_TOKEN_SAVER_QUIET="$quiet" bash "$HOOK" 2>&1)"
  else
    out="$(cd "$workdir" && env HOME="$home" CLAUDE_TOKEN_SAVER_QUIET="$quiet" bash "$HOOK" 2>&1)"
  fi
  rc=$?
  printf '%s' "$out"
  return "$rc"
}

check() { # <label> <expected: silent|reminds> <workdir> <home> <quiet>
  local label="$1" expect="$2" out actual rc
  out="$(run_hook "$3" "$4" "$5")"; rc=$?
  if [ -z "$out" ]; then actual="silent"; else actual="reminds"; fi
  if [ "$actual" = "$expect" ] && [ "$rc" -eq 0 ]; then
    pass=$((pass + 1)); printf '  ok   %s\n' "$label"
  else
    fail=$((fail + 1))
    printf '  FAIL %s (expected %s exit 0, got %s exit %s)\n' "$label" "$expect" "$actual" "$rc"
    [ -n "$out" ] && printf '       output: %s\n' "$(printf '%s' "$out" | head -1)"
  fi
}

echo "session-start hook"

d="$(sandbox)"
check "no rules anywhere -> reminds" reminds "$d/work" "$d/home" ""

d="$(sandbox)"; printf '%s' "$RULES" > "$d/work/CLAUDE.md"
check "project CLAUDE.md" silent "$d/work" "$d/home" ""

d="$(sandbox)"; printf '%s' "$RULES" > "$d/work/CLAUDE.local.md"
check "project CLAUDE.local.md" silent "$d/work" "$d/home" ""

d="$(sandbox)"; mkdir -p "$d/work/.claude"; printf '%s' "$RULES" > "$d/work/.claude/CLAUDE.md"
check ".claude/CLAUDE.md" silent "$d/work" "$d/home" ""

d="$(sandbox)"; mkdir -p "$d/work/.claude/rules/team"
printf '%s' "$RULES" > "$d/work/.claude/rules/team/tokens.md"
check "nested .claude/rules/team/tokens.md" silent "$d/work" "$d/home" ""

d="$(sandbox)"; printf '%s' "$RULES" > "$d/home/.claude/CLAUDE.md"
check "user-level ~/.claude/CLAUDE.md" silent "$d/work" "$d/home" ""

# The subdirectory case: rules at the repo root, session started two levels down.
d="$(sandbox)"; git -C "$d/work" init -q 2>/dev/null
printf '%s' "$RULES" > "$d/work/CLAUDE.md"; mkdir -p "$d/work/src/api"
check "git repo, session started in src/api" silent "$d/work/src/api" "$d/home" ""

# A non-git subdirectory genuinely cannot see the parent, and reminding is the safe
# failure. Pinned so a future change to root resolution is a deliberate one.
d="$(sandbox)"; printf '%s' "$RULES" > "$d/work/CLAUDE.md"; mkdir -p "$d/work/src"
check "non-git subdirectory -> reminds" reminds "$d/work/src" "$d/home" ""

# The loose match is the escape hatch: a hand-edited heading must not nag forever.
d="$(sandbox)"; printf '## Token Efficiency Rules\n\n- mine\n' > "$d/work/CLAUDE.md"
check "hand-edited heading still counts" silent "$d/work" "$d/home" ""

d="$(sandbox)"
check "CLAUDE_TOKEN_SAVER_QUIET=1" silent "$d/work" "$d/home" "1"

# HOME unset must not abort the hook under set -u.
d="$(sandbox)"
check "HOME unset -> reminds, no crash" reminds "$d/work" "-" ""

# The reminder has to be parseable, since Claude Code reads it as JSON.
d="$(sandbox)"; out="$(run_hook "$d/work" "$d/home" "")" || true
if printf '%s' "$out" | python3 -c '
import json,sys
d = json.load(sys.stdin)
assert d["hookSpecificOutput"]["hookEventName"] == "SessionStart"
assert d["hookSpecificOutput"]["additionalContext"]
' 2>/dev/null; then
  pass=$((pass + 1)); echo "  ok   reminder is valid SessionStart JSON"
else
  fail=$((fail + 1)); echo "  FAIL reminder is valid SessionStart JSON"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
