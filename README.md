# claude-token-saver

A Claude Code plugin for choosing communication and workflow preferences in CLAUDE.md.
Its rules aim to reduce unnecessary output and agent work. **Net token savings and
quality preservation have not been measured for these profiles.**

Rules are adapted from [claude-token-efficient](https://github.com/drona23/claude-token-efficient)
and informed by Anthropic's prompting guidance. Setup defaults to three general
communication rules; additional categories and model-specific behavior are opt-in.

## Install

Requires Claude Code, Bash for the reminder hook, and **Python 3.9+** for setup.
The Python helper uses only the standard library: no package installation or network
access is needed to generate or update rules.

```text
/plugin marketplace add massimosiani/claude-token-saver
/plugin install claude-token-saver@claude-token-saver
```

## Usage

```text
/claude-token-saver
```

If that short name conflicts with another command, use the canonical name:

```text
/claude-token-saver:claude-token-saver
```

The skill asks for missing preferences and honors choices you already supplied:

1. **Location:** `./CLAUDE.md` in the current directory (default), or global
   `~/.claude/CLAUDE.md`. It shows the absolute target before writing.
2. **Target model:** general/mixed models (default), or Claude Opus 5. Shared and global
   files default to general rules. Opus 5 additions require an explicit selection.
3. **Categories:** Communication Style only (default). Optionally add Agent Workflow
   (scope, relevant checks, targeted edits) and Formatting and Error Handling (language
   preservation, useful diagnostics, review clarity).
4. **Conciseness**, when communication is selected: Light (default), Medium, or Full.
   Levels are cumulative. Full gives the conclusion with additional explanation when
   requested or necessary to act correctly.

A bundled helper generates the rules verbatim, prints a diff and stores the proposed
file in a private temporary plan. **Every write requires confirmation of that preview.**
Decline and the target remains untouched. Accept and the helper applies exactly that
plan, refusing if the file or plan changed in the meantime. Temporary plans contain
project instructions and are deleted when the workflow finishes.

## Updating existing rules

New sections are bounded by stable comments:

```markdown
<!-- claude-token-saver:begin -->
## Token Efficiency

...selected rules...

<!-- claude-token-saver:end -->
```

You can edit the heading and rules inside them. Keep the markers intact. Rerunning setup
replaces the marked content only after showing your edits in the confirmation diff.
Multiple owned blocks are consolidated at the first block's position. Text outside the
replaced blocks is preserved byte-for-byte, including existing line endings; appending
may add a separator after the original content.

Legacy exact `## Token Efficiency` sections migrate automatically when their boundaries
are unambiguous. The helper understands ATX and Setext headings, backtick and tilde
fences, and standalone HTML comments. It is a conservative scanner, not a complete
CommonMark parser: raw HTML, ambiguous nested Markdown, unfinished blocks, malformed
markers and recognizable renamed legacy headings cause it to stop without writing.
Symlink and hard-link targets are also refused, to preserve their link semantics.

For a renamed legacy section, place the begin/end markers around **only the rules you
want managed**, then preview again. An arbitrary old title without “Token Efficiency”
cannot be identified automatically: identify that block before rerunning setup. For
unsupported Markdown, update the rules manually or simplify the ambiguous construct
before retrying; markers alone do not make unsupported syntax parseable.

Changes are written through an atomic file replacement. Existing file permissions are
preserved; new files and temporary plans are private (`0600`). Content checks catch
changes since preview and during write preparation; they do not lock out another editor
in the final interval before replacement. Avoid simultaneous edits while applying.

## Savings and tradeoffs

Less narration, tighter scope and fewer unnecessary tool or subagent calls may reduce
cost. Extra instructions also consume context, can conflict with project conventions,
and may increase follow-up work. Keep only rules that improve your actual tasks.

The default profile deliberately starts small. Workflow checks stay proportional to the
change; files can be reread when context is missing; already-authorized configuration
edits do not require another approval. Formatting rules preserve the user's language,
and diagnostics surface useful errors without demanding every traceback or sensitive value.

Opus 5 additions address that model's documented verification, delegation and narration
behavior. They are emitted separately from general rules, only when both Opus 5 and Agent
Workflow are selected. Rerun with the general model when switching to other or mixed models.

Upstream's [benchmark summary](https://github.com/drona23/claude-token-efficient/blob/0d30a6db75af983b8ababf585f28faefdfc87895/benchmark/SUMMARY.md)
tests different rule sets and primarily one-shot prompts. Output-token reduction is not
the same as total-token or monetary savings, and its results do not establish this
plugin's effectiveness. We do not claim the upstream percentages for these profiles.

Prompt caching changes the cost of repeated input, so context size alone does not predict
billed cost. Evaluate **total cost per successfully completed task**, recording correctness,
completeness, input/cache/output usage, tool calls and elapsed time. Compare repeated runs
of unchanged baseline, communication-only, workflow-only and combined profiles on the
same tasks, model and effort setting; include regressions as well as savings.

Claude Code recommends targeting under 200 lines per CLAUDE.md. Its memory loader strips
block-level HTML comments, so the generated ownership and provenance comments do not
consume model context there. Other agents may load them.

## Session reminder

At startup only, a synchronous hook checks exactly `./CLAUDE.md` and
`~/.claude/CLAUDE.md` for the phrase `Token Efficiency` or a begin marker. When neither
matches, it emits a user-facing `systemMessage`, not additional instructions to Claude.
It does not repeat on clear, compact or resume.

Set `CLAUDE_TOKEN_SAVER_QUIET` to any non-empty value to silence it. The lookup is deliberately
limited: rules in parent directories, `.claude/CLAUDE.md`, `.claude/rules/`, imports or a
custom config directory may produce a false reminder. A mention inside prose, a comment
or a fenced example can silence it. The reminder is an onboarding hint, not a memory audit.

## Upgrade and removal

Update the plugin with `/plugin update claude-token-saver@claude-token-saver`, then rerun
setup to review changes to generated rules. Updating or uninstalling the plugin does
**not** modify existing CLAUDE.md files.

To remove generated rules, ask `/claude-token-saver` to remove them from the project or
global file. It previews removal and requires confirmation. Alternatively, manually delete
the inclusive begin/end block. Legacy sections use the same conservative migration checks.
Uninstall the plugin separately with `/plugin uninstall claude-token-saver@claude-token-saver`.

## Tests

```bash
bash tests/run.sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The shell suite covers the reminder and its deliberately limited lookup. Python tests
cover literal rule selection, model gating, historical merge fixtures, Markdown boundaries,
byte preservation, idempotence, removal, stale approvals, private plans and failed writes.
CI runs both suites on Linux and macOS and checks the minimum Python version on Linux.
These deterministic checks do not establish end-to-end Claude behavior or cost savings.

## Sources

- [Upstream rules and license](https://github.com/drona23/claude-token-efficient) and
  the pinned benchmark above; see [third-party notices](THIRD_PARTY_NOTICES.md).
- [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)
  for the optional model-specific additions.
- [Claude Code memory](https://code.claude.com/docs/en/memory),
  [prompt caching](https://code.claude.com/docs/en/prompt-caching),
  [hook output](https://code.claude.com/docs/en/hooks#json-output), and
  [skill naming](https://code.claude.com/docs/en/skills#how-a-skill-gets-its-command-name).
- [Evaluating AGENTS.md](https://www.sri.inf.ethz.ch/publications/gloaguen2026agentsmd),
  research on repository context files generally, not an evaluation of this plugin.

## License

[MIT](LICENSE). Adapted upstream material retains its notice in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
