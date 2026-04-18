# claude-token-saver

A Claude Code plugin that generates token-efficient rules for your CLAUDE.md. It interactively asks about your preferences and writes optimized rules that reduce token usage in Claude's responses.

Rules adapted from [claude-token-efficient](https://github.com/drona23/claude-token-efficient).

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
   - Communication style - eliminates filler, preamble, sycophancy
   - Technical formatting - ASCII only, no em-dashes or smart quotes
   - Workflow discipline - read before acting, targeted edits, test first
   - Error handling - full tracebacks, no silent swallowing
   - File handling - skip large files, prefer edits over rewrites
3. **Conciseness level** (if Communication Style is selected):
   - Light - removes filler and sycophancy
   - Medium - short sentences, no preamble/closing
   - Full - maximum compression, 8-10 word sentences

The rules are appended under a `## Token Efficiency` section. Existing CLAUDE.md content is preserved.

## Session reminder

A session-start hook checks whether your CLAUDE.md contains token-efficient rules. If not, it reminds you to run `/claude-token-saver`.

## License

MIT
