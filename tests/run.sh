#!/usr/bin/env bash
# Fixture tests for hooks/session-start. Run: tests/run.sh
#
# Two fidelity rules, both learned by shipping a bug the tests could not see:
#
#   1. The fake HOME is an ANCESTOR of the working directory, because on a real machine a
#      project usually sits inside $HOME. A sibling HOME hid half of the plugin-cache bug.
#   2. The fake HOME contains this plugin's own installed copy, because every real machine
#      has one and it contains the string the hook greps for. A pristine ~/.claude is a
#      state no user is ever in.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/hooks/session-start"
RULES='## Token Efficiency

### Agent Workflow

- a rule
'
pass=0
fail=0
declare -a sandboxes=()
trap 'for s in ${sandboxes[@]+"${sandboxes[@]}"}; do rm -rf "$s"; done' EXIT

# Sets $SB and $WORK. Not called via $( ), or the array append lands in a subshell and
# the cleanup trap silently frees nothing - which is what the previous version did.
sandbox() {
  SB="$(mktemp -d)"
  sandboxes+=("$SB")
  WORK="$SB/home/projects/app"
  mkdir -p "$SB/home/.claude" "$WORK"
  # The plugin's own installed copy, at the real layout and the real version.
  local version p
  version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" | head -1)"
  p="$SB/home/.claude/plugins/cache/mp/claude-token-saver/$version/skills/claude-token-saver"
  mkdir -p "$p"
  printf 'Keep the section heading exactly `## Token Efficiency`.\n' > "$p/SKILL.md"
}

# check <label> <silent|reminds> <workdir> <home|-> <quiet|->
check() {
  local label="$1" expect="$2" workdir="$3" home="$4" quiet="$5"
  local out err rc actual errfile
  local -a opts=() assigns=()
  [ "$home" = "-" ] && opts+=(-u HOME) || assigns+=("HOME=$home")
  [ "$quiet" = "-" ] && opts+=(-u CLAUDE_TOKEN_SAVER_QUIET) \
                     || assigns+=("CLAUDE_TOKEN_SAVER_QUIET=$quiet")
  errfile="$(mktemp)"
  # stdout and stderr kept apart: merged, a stderr warning with no JSON scores as a
  # reminder and passes every reminder assertion.
  out="$(cd "$workdir" && env ${opts[@]+"${opts[@]}"} ${assigns[@]+"${assigns[@]}"} \
          bash "$HOOK" 2>"$errfile")"
  rc=$?
  err="$(cat "$errfile")"; rm -f "$errfile"
  [ -z "$out" ] && actual="silent" || actual="reminds"

  local problem=""
  [ "$actual" = "$expect" ] || problem="expected $expect, got $actual"
  [ "$rc" -eq 0 ] || problem="${problem:+$problem; }exit $rc"
  [ -z "$err" ] || problem="${problem:+$problem; }stderr: $(printf '%s' "$err" | head -1)"
  if [ "$actual" = "reminds" ]; then
    case "$out" in
      *'"hookEventName": "SessionStart"'*) ;;
      *) problem="${problem:+$problem; }no SessionStart payload" ;;
    esac
    case "$out" in
      *CLAUDE_TOKEN_SAVER_QUIET*) ;;
      *) problem="${problem:+$problem; }reminder does not name the opt-out" ;;
    esac
  fi

  if [ -z "$problem" ]; then
    pass=$((pass + 1)); printf '  ok   %s\n' "$label"
  else
    fail=$((fail + 1)); printf '  FAIL %s (%s)\n' "$label" "$problem"
  fi
}

echo "session-start hook"

sandbox; check "no rules, plugin installed under HOME" reminds "$WORK" "$SB/home" "-"
sandbox; printf '%s' "$RULES" > "$WORK/CLAUDE.md"
         check "CLAUDE.md in the working directory" silent "$WORK" "$SB/home" "-"
sandbox; printf '%s' "$RULES" > "$SB/home/.claude/CLAUDE.md"
         check "user ~/.claude/CLAUDE.md" silent "$WORK" "$SB/home" "-"
sandbox; printf '## Token Efficiency Rules\n\n- mine\n' > "$WORK/CLAUDE.md"
         check "hand-edited heading still counts" silent "$WORK" "$SB/home" "-"

# Documented limitations, pinned so that changing them is a deliberate act.
# The most common real configuration: a project CLAUDE.md with build notes and no marker,
# plus global rules. Without this, the loop's second iteration is only ever reached
# because the first file is absent, never because its grep failed.
sandbox; printf '# CLAUDE.md\n\nBuild with pnpm.\n' > "$WORK/CLAUDE.md"
         printf '%s' "$RULES" > "$SB/home/.claude/CLAUDE.md"
         check "project file without marker, global with it" silent "$WORK" "$SB/home" "-"

# Documented limitations, pinned so that changing them is a deliberate act.
sandbox; printf '%s' "$RULES" > "$WORK/CLAUDE.md"; mkdir -p "$WORK/src"
         check "subdirectory reminds (known limitation)" reminds "$WORK/src" "$SB/home" "-"
sandbox; mkdir -p "$WORK/.claude/rules"; printf '%s' "$RULES" > "$WORK/.claude/rules/tokens.md"
         check ".claude/rules reminds (known limitation)" reminds "$WORK" "$SB/home" "-"
sandbox; mkdir -p "$WORK/.claude"; printf '%s' "$RULES" > "$WORK/.claude/CLAUDE.md"
         check ".claude/CLAUDE.md reminds (known limitation)" reminds "$WORK" "$SB/home" "-"

sandbox; check "QUIET=1 silences" silent "$WORK" "$SB/home" "1"
sandbox; check "QUIET=off also silences (any value)" silent "$WORK" "$SB/home" "off"
sandbox; check "QUIET unset reminds" reminds "$WORK" "$SB/home" "-"
sandbox; check "QUIET set but empty reminds" reminds "$WORK" "$SB/home" ""
sandbox; check "HOME unset reminds, no crash" reminds "$WORK" "-" "-"

# The payload is asserted whole, not by substring. The JSON escape helper was removed on
# the grounds that the message is a literal; this is what keeps that true, since adding a
# quote or backslash to it would emit unparseable JSON that substring checks still accept.
sandbox
expected='{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "No token-efficient rules found in CLAUDE.md. Run /claude-token-saver to add them, or set CLAUDE_TOKEN_SAVER_QUIET=1 to silence this."
  }
}'
actual="$(cd "$WORK" && env -u CLAUDE_TOKEN_SAVER_QUIET HOME="$SB/home" bash "$HOOK")"
if [ "$actual" = "$expected" ]; then
  pass=$((pass + 1)); echo "  ok   reminder payload matches exactly"
else
  fail=$((fail + 1)); echo "  FAIL reminder payload matches exactly"
  diff <(printf '%s' "$expected") <(printf '%s' "$actual") | head -6
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
