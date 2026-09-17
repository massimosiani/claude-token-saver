---
name: claude-token-saver
description: Choose communication and workflow preferences, then preview and safely update a managed rules block in CLAUDE.md. Can also remove previously generated rules.
disable-model-invocation: true
---

# CLAUDE.md Rule Setup

Use the bundled Python helper for generation and file edits. It copies literal rules
from [references/rules.md](references/rules.md) and preserves content outside its managed
blocks. Read that reference when explaining the available preferences.

## Choose preferences

Honor choices already supplied by the user; ask only for missing ones. Present the
following defaults as suggestions, not as answers the user has already submitted.

- **Location:** project `./CLAUDE.md` (default) or global `~/.claude/CLAUDE.md`.
  Explain that project means the current directory; show the absolute target path.
- **Target model:** general/mixed models (default) or Claude Opus 5. Select this before
  generation. Global or shared files should use general rules unless the user explicitly
  wants Opus 5 additions. Do not infer the target from the current session's model.
- **Categories:** Communication Style only (default). Agent Workflow and Formatting and
  Error Handling are optional. Describe workflow as scope, relevant checks and targeted
  edits; formatting as language preservation, useful diagnostics and review clarity.
- **Conciseness:** Light (default), Medium or Full, when communication is selected.
  Levels are cumulative. Full omits extra explanation unless requested or necessary.

For a removal request, establish only the target location and use `--remove` below.

## Preview

Requires Python 3.9 or newer, with no third-party packages. If unavailable, explain the
requirement and leave the target untouched; do not improvise the merge in model-written code.
Resolve `scripts/configure.py` relative to this skill's directory (inside the installed
plugin, not the user's project). Use shell quoting for all paths. For example:

```bash
plan_dir="$(mktemp -d)"
python3 "${CLAUDE_PLUGIN_ROOT}/skills/claude-token-saver/scripts/configure.py" preview \
  --target "/absolute/project/CLAUDE.md" --plan "$plan_dir/plan.json" \
  --categories communication --level light --model general
```

Supported category names are `communication`, `workflow`, and `formatting`, comma-separated.
Model values are `general` and `opus-5`. For removal, replace the category, level and model
arguments with `--remove`.

The helper prints a diff and an approval digest and writes a private plan. Show the full
diff and target path to the user. Explain selected model additions before writing. If
there are no changes, report that and stop.

Legacy exact `## Token Efficiency` sections can be migrated, including duplicates.
Renamed legacy headings, malformed markers, unfinished blocks and unsupported Markdown
produce an error rather than a guessed edit. On error, explain it and stop; do not bypass
the helper. Offer a manual migration for the user to review: enclose only their existing
rules with the begin/end markers shown below. Unsupported syntax may also need manual simplification; adding
markers alone does not make it parseable. Arbitrary legacy renames
without a recognizable title require the user to identify the block.

## Confirm and apply

Ask for confirmation of this exact diff before any target write, including first setup
or removal, unless the user has already explicitly approved that exact preview.
On decline, remove only the temporary plan directory and leave the target untouched.
On acceptance, apply with the digest printed by preview:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/claude-token-saver/scripts/configure.py" apply \
  --plan "$plan_dir/plan.json" --approve "<approval digest from preview>"
```

If the target or plan changed, generate a new preview and obtain confirmation of the new
diff. Never silently regenerate a different edit under an earlier approval. The helper
refuses symlink and hard-link targets; explain that limitation rather than unlinking them.
Delete the temporary plan directory when finished, including acceptance, decline,
no-change and error exits: it may contain private project instructions.

Report the updated path, selected categories and model. Explain that users may edit the
rules and heading inside the markers, and that rerunning replaces those edits only after
another reviewed diff. Preserve the markers themselves:

```markdown
<!-- claude-token-saver:begin -->
## Token Efficiency

...selected rules...

<!-- claude-token-saver:end -->
```

Generated rules remain after plugin uninstall and change only when setup is rerun. To
remove them, use the helper's removal preview or delete the inclusive marked block.
Do not promise measured token savings: this project has no cost/quality benchmark yet.
