# claude-token-saver

A Claude Code plugin that generates token-efficient rules for your CLAUDE.md. It asks
what you want, then writes rules that cut token spend without cutting output quality.

Rules adapted from [claude-token-efficient](https://github.com/drona23/claude-token-efficient),
then audited against Anthropic's current prompting guidance. See [Sources](#sources).

## Install

```
/plugin marketplace add massimosiani/claude-token-saver
```

Then install the plugin:

```
/plugin install claude-token-saver@claude-token-saver
```

## Usage

Run the slash command:

```
/claude-token-saver
```

The plugin walks you through:

1. **Location** - project CLAUDE.md or global `~/.claude/CLAUDE.md`
2. **Categories** - pick which rule sets to include:
   - Communication style - what the agent says: cuts filler, preamble and sycophancy, sets response length
   - Agent workflow - what the agent does: scope discipline, no redundant verification passes, sparing subagent use, targeted edits
   - Formatting and error handling - ASCII and straight quotes, full tracebacks, no silent failures, large-file limits
3. **Conciseness level** (if Communication style is selected):
   - Light - drops filler and sycophancy, keeps normal sentence length
   - Medium - brief answers, no preamble or closing, results over narration
   - Full - adds selectivity: include less, but still write it in full sentences

The rules are appended under a `## Token Efficiency` section. Existing CLAUDE.md content
is preserved. If your CLAUDE.md already contains similar rules, the plugin detects the
overlap and skips adding duplicates.

## Where the savings come from

The intuition is that verbose prose is the problem, so the fix is shorter sentences. It
mostly isn't. The expensive behaviors are structural:

- **Scope expansion** - work you did not ask for, at full token price.
- **Redundant verification** - a self-check pass on top of work the model already checked.
- **Subagent fan-out** - each subagent re-establishes context, re-explores, reports back,
  and then the coordinator re-reads the report.
- **Self-correction narration** - re-litigating earlier statements that changed nothing.

Those live in the **Agent workflow** category, which is why it is worth keeping even if
you skip the rest. Prose compression, by contrast, has a floor: past a point it produces
fragments and abbreviations that cost the reader a reread, and the saving goes with it.
The rules aim for *include less*, not *write it shorter*.

Rules tuned to a specific model generation are marked `(Claude 4.6+)` and carry their
reason inline, so you can tell at a glance which lines to drop if you point the file at a
different agent.

## When this helps, and when it does not

**Worth it for:** high output volume, repeated automation, long agentic sessions, teams
wanting consistent output.

**Not worth it for:** one-off short queries, or exploratory work where you want the model
to think out loud. The file is re-sent as input on every message, so on low output volume
the overhead exceeds the saving.

Two numbers worth knowing before you install this:

- Upstream measures roughly **4-12%** real token savings via API benchmarks. The headline
  63% figure is word reduction on a small directional test, not a controlled study.
- Reported research on agent context files finds machine-generated ones can *reduce* task
  success while raising inference cost, and that hand-written ones help only when they
  stay minimal and precise.

So keep the file small, and delete any rule you do not actually want followed. Claude Code
documentation suggests targeting **under 200 lines** per CLAUDE.md; longer files consume
more context and reduce adherence. A rule nobody follows costs tokens every session and
buys nothing.

Claude Code strips block-level HTML comments before loading the file, so the generated
provenance comments cost nothing there. Other agents may load them.

## Session reminder

A session-start hook checks `./CLAUDE.md`, `./.claude/CLAUDE.md` and
`~/.claude/CLAUDE.md` for a Token Efficiency section. If none has one, it reminds you to
run `/claude-token-saver`.

## Sources

- [claude-token-efficient](https://github.com/drona23/claude-token-efficient) - the
  original rule set and the benchmark numbers quoted above.
- Anthropic's prompt-audit and model-migration guidance bundled with Claude Code, reachable
  as `/claude-api prompt-audit` - the source for the anti-patterns this rule set drops
  (numeric output ceilings, banned-phrase lists, plan-before-acting, verification
  scaffolding) and the model-tuned rules it adds.
- [How Claude remembers your project](https://code.claude.com/docs/en/memory) - CLAUDE.md
  locations, the 200-line guidance, HTML comment stripping.
- AGENTS.md guidance for the cross-tool view of context files:
  [morphllm](https://www.morphllm.com/agents-md-guide),
  [buildbetter](https://blog.buildbetter.ai/agents-md-complete-guide-for-engineering-teams-in-2026/).

## License

MIT
