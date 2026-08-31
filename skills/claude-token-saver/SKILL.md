---
name: claude-token-saver
description: Set up a CLAUDE.md file with token-efficient rules. Asks questions about preferred categories and conciseness level, then generates or merges into CLAUDE.md.
disable-model-invocation: true
---

# Token-Efficient CLAUDE.md Setup

Generate a CLAUDE.md file with token-efficient rules, adapted from
https://github.com/drona23/claude-token-efficient and audited against Anthropic's
current prompting guidance.

Read the rules reference at [references/rules.md](references/rules.md) before proceeding.

## Workflow

### Step 1: Ask where to write

Ask the user:

> Where should I write the CLAUDE.md?
>
> 1. **Project** (default) - `./CLAUDE.md` in the current working directory
> 2. **Global** - `~/.claude/CLAUDE.md`, applies to all projects

Default to project if the user just presses enter or says "default".

### Step 2: Ask which categories to include

Present all categories with descriptions. All are selected by default.

> Which rule categories do you want? Enter numbers to include (e.g. 1,3), or press enter for all.
>
> 1. **Communication style** - what the agent says. Cuts filler, preamble and sycophancy, and sets response length.
> 2. **Agent workflow** - what the agent does. Scope discipline, verification without a redundant second pass, sparing subagent use, targeted edits, confirmation before touching protected files. This is where the largest savings are.
> 3. **Formatting and error handling** - straight quotes and ASCII in prose, full tracebacks instead of silent failures, tight code-review comments, boundary-condition checks, large-file limits.

### Step 3: Ask conciseness level (only if Communication Style is included)

> What conciseness level?
>
> 1. **Light** - drops filler and sycophancy, keeps normal sentence length
> 2. **Medium** - brief answers, no preamble or closing, results over narration
> 3. **Full** - conclusion only, with reasoning, alternatives and caveats supplied on request

### Step 4: Generate

1. Collect the selected rules from `references/rules.md` based on the user's choices.
2. For Communication Style, take the rules up to and including the selected conciseness
   level. The levels are cumulative: Medium includes Light, Full includes both.
3. For the other categories, include every rule in that category.
4. Copy each rule's text verbatim. Do not re-summarize or compress it; the wording is
   the product.
   The `### Light` / `### Medium` / `### Full` headings and the `All of the above, plus:`
   lines between them are structure for the reference file, not rules. Drop them and emit
   one flat bullet list under `### Communication Style`; copied through, those connectives
   would point at headings the output format does not have.
5. Rules marked `(Claude Opus 5)` carry their reason inline. Keep the marker and the
   reason - the reason is what makes the rule checkable later. Do not widen the marker to
   a range: the reference file explains which neighbouring models behave the opposite way.

### Step 5: Merge

The merge must leave exactly one `## Token Efficiency` section. Running the command
twice, or re-running after upgrading the plugin, must not stack a second copy.

1. **No file at the target path**: create one with a top-level heading and the new
   section.
2. **File exists without a `## Token Efficiency` heading**: append the new section and
   leave everything above it untouched.

   Append at the end of the file, with one exception. If the file uses `# ` headings as
   section separators, a `##` section appended after one of them reads as part of it, and
   the rules become a subsection of whatever happens to come last. In that case place the
   new section immediately before the first separator instead.

   A `# ` heading on the first line is the document title, not a separator. Skip it when
   looking for the first one, or the rules land above the title.
3. **File exists with a `## Token Efficiency` heading**: replace it, on these terms.

   **Find every one of them, not the first.** Versions before 1.1.0 appended without
   checking, so a file can hold two or more. The end state is exactly one section, so all
   of them have to go.

   **Ignore headings inside fenced code blocks.** A CLAUDE.md that documents this plugin
   quotes the heading in an example; that is not a live section, and replacing from inside
   the fence would shred the user's example.

   **Bound each section correctly**: from its heading to the next heading at `##` level or
   higher - a line beginning `## ` or `# `, note the trailing space - or to end of file,
   ignoring any heading inside a fence. Two traps: the `###` subsection headings inside
   the section are part of it, so a naive "next line starting with `##`" scan stops
   immediately and orphans the rest; and a `# ` heading below the section is *not* part of
   it, so a scan looking only for `##` runs past it and deletes the user's other sections.

   **Ask before replacing.** Show a diff of what is there against what you would write,
   and get confirmation. Step 6 invites people to edit these rules, so an existing section
   may hold deliberate changes; regenerating over them silently destroys the work this
   skill asked for.

   **If the user declines, change nothing** and say the file was left as it is. Do not
   fall through to appending: a second section is the outcome this whole step exists to
   prevent.

   On confirmation replace wholesale rather than merging rule by rule. Earlier versions
   emitted different subsection names (`Formatting and Workflow`, `Error and File
   Handling`) and rules the current set contradicts, such as an 8-10 word sentence cap;
   only a whole-section replacement clears those.

### Output format

```markdown
# CLAUDE.md

## Token Efficiency

<!-- Rules generated by /claude-token-saver -->
<!-- https://github.com/massimosiani/claude-token-saver -->
<!-- Adapted from https://github.com/drona23/claude-token-efficient (MIT) -->

### Communication Style

- rule 1
- rule 2

### Agent Workflow

- rule 1

### Formatting and Error Handling

- rule 1
...
```

Keep the section heading exactly `## Token Efficiency`, at that heading level and at the
start of the line. Both the replacement rule above and the session-start hook look for
it.

### Step 6: Confirm

Show the user the file path and what was written.

If any `(Claude Opus 5)` rules were included, name them and say they are tuned to that
model's documented behavior - offer to drop them if the user works with a different model
or agent. Then invite edits: a rule nobody follows costs tokens on every session and buys
nothing.
