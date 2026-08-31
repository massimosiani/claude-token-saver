#!/usr/bin/env bash
# Fixture tests for hooks/session-start.
#
# The hook is the only executable code in this plugin. Run: tests/run.sh
#
# Note the sandbox: a real ~/.claude always contains this plugin's own installed copy
# under plugins/cache, and that copy contains the string the hook greps for. A pristine
# empty fake HOME hides that, which is how a version shipped where the reminder never
# fired for anyone. Tests that care seed the plugin cache explicitly.

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/session-start"
RULES='## Token Efficiency

### Agent Workflow

- a rule
'
pass=0
fail=0
sandboxes=()
trap 'for s in "${sandboxes[@]:-}"; do [ -n "$s" ] && rm -rf "$s"; done' EXIT

sandbox() {
  local dir
  dir="$(mktemp -d)"
  sandboxes+=("$dir")
  mkdir -p "$dir/home/.claude" "$dir/work"
  printf '%s' "$dir"
}

# Seed the plugin's own installed copy, the way every real machine has it.
install_plugin() {
  local p="$1/.claude/plugins/cache/mp/claude-token-saver/1.2.0/skills/claude-token-saver"
  mkdir -p "$p"
  printf 'Keep the section heading exactly `## Token Efficiency`.\n' > "$p/SKILL.md"
}

# run <workdir> <home|-> <quiet|-> ; "-" means unset that variable
run_hook() {
  local workdir="$1" home="$2" quiet="$3" out rc
  # env requires its -u options before any NAME=VALUE assignments.
  local -a opts=() assigns=()
  if [ "$home" = "-" ]; then opts+=(-u HOME); else assigns+=("HOME=$home"); fi
  if [ "$quiet" = "-" ]; then
    opts+=(-u CLAUDE_TOKEN_SAVER_QUIET)
  else
    assigns+=("CLAUDE_TOKEN_SAVER_QUIET=$quiet")
  fi
  out="$(cd "$workdir" && env ${opts[@]+"${opts[@]}"} ${assigns[@]+"${assigns[@]}"} \
          bash "$HOOK" 2>&1)"
  rc=$?
  printf '%s' "$out"
  return "$rc"
}

check() { # <label> <silent|reminds> <workdir> <home> <quiet>
  local label="$1" expect="$2" out actual rc
  out="$(run_hook "$3" "$4" "$5")"; rc=$?
  if [ -z "$out" ]; then actual="silent"; else actual="reminds"; fi
  if [ "$actual" = "$expect" ] && [ "$rc" -eq 0 ]; then
    pass=$((pass + 1)); printf '  ok   %s\n' "$label"
  else
    fail=$((fail + 1))
    printf '  FAIL %s (expected %s exit 0, got %s exit %s)\n' "$label" "$expect" "$actual" "$rc"
  fi
}

echo "session-start hook"

d="$(sandbox)"; install_plugin "$d/home"
check "no rules, plugin installed -> reminds" reminds "$d/work" "$d/home" "-"

d="$(sandbox)"; printf '%s' "$RULES" > "$d/work/CLAUDE.md"
check "project CLAUDE.md" silent "$d/work" "$d/home" "-"

d="$(sandbox)"; printf '%s' "$RULES" > "$d/work/CLAUDE.local.md"
check "project CLAUDE.local.md" silent "$d/work" "$d/home" "-"

d="$(sandbox)"; mkdir -p "$d/work/.claude"; printf '%s' "$RULES" > "$d/work/.claude/CLAUDE.md"
check ".claude/CLAUDE.md" silent "$d/work" "$d/home" "-"

d="$(sandbox)"; mkdir -p "$d/work/.claude/rules/team"
printf '%s' "$RULES" > "$d/work/.claude/rules/team/tokens.md"
check "nested .claude/rules/team/tokens.md" silent "$d/work" "$d/home" "-"

d="$(sandbox)"; printf '%s' "$RULES" > "$d/home/.claude/CLAUDE.md"
check "user ~/.claude/CLAUDE.md" silent "$d/work" "$d/home" "-"

d="$(sandbox)"; mkdir -p "$d/home/.claude/rules"; printf '%s' "$RULES" > "$d/home/.claude/rules/te.md"
check "user ~/.claude/rules/te.md" silent "$d/work" "$d/home" "-"

d="$(sandbox)"; printf '%s' "$RULES" > "$d/work/CLAUDE.md"; mkdir -p "$d/work/src/api"
check "session started in src/api" silent "$d/work/src/api" "$d/home" "-"

# Regression: anchoring on the git root missed a CLAUDE.md below it.
d="$(sandbox)"; git -C "$d/work" init -q 2>/dev/null
mkdir -p "$d/work/packages/app"; printf '%s' "$RULES" > "$d/work/packages/app/CLAUDE.md"
check "CLAUDE.md below the git root" silent "$d/work/packages/app" "$d/home" "-"

# Regression: recursing ~/.claude matched the plugin's own installed copy, so the
# reminder never fired for any user who had the plugin.
d="$(sandbox)"; install_plugin "$d/home"
check "plugin cache must not count as rules" reminds "$d/work" "$d/home" "-"

d="$(sandbox)"; printf '## Token Efficiency Rules\n\n- mine\n' > "$d/work/CLAUDE.md"
check "hand-edited heading still counts" silent "$d/work" "$d/home" "-"

d="$(sandbox)"
check "CLAUDE_TOKEN_SAVER_QUIET=1" silent "$d/work" "$d/home" "1"
d="$(sandbox)"
check "CLAUDE_TOKEN_SAVER_QUIET=0 does not silence" reminds "$d/work" "$d/home" "0"
d="$(sandbox)"
check "CLAUDE_TOKEN_SAVER_QUIET=false does not silence" reminds "$d/work" "$d/home" "false"
d="$(sandbox)"
check "CLAUDE_TOKEN_SAVER_QUIET unset" reminds "$d/work" "$d/home" "-"

d="$(sandbox)"
check "HOME unset -> reminds, no crash" reminds "$d/work" "-" "-"

d="$(sandbox)"; out="$(run_hook "$d/work" "$d/home" "-")" || true
if ! command -v python3 >/dev/null 2>&1; then
  echo "  skip reminder JSON check (python3 not present)"
elif printf '%s' "$out" | python3 -c '
import json,sys
d = json.load(sys.stdin)
assert d["hookSpecificOutput"]["hookEventName"] == "SessionStart"
assert d["hookSpecificOutput"]["additionalContext"]
'; then
  pass=$((pass + 1)); echo "  ok   reminder is valid SessionStart JSON"
else
  fail=$((fail + 1)); echo "  FAIL reminder is valid SessionStart JSON"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
