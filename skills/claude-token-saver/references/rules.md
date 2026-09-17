# Token-Efficient Rules Reference

Rules intended to reduce unnecessary output and agent work. Net savings and quality
preservation have not been measured for these profiles.

Adapted from drona23/claude-token-efficient (MIT); see THIRD_PARTY_NOTICES.md at the
plugin root. The helper copies bullet text verbatim from the categories below.
Communication levels are cumulative. General rules apply to every target model;
Claude Opus 5 additions are included only when that model and Agent Workflow are selected.

The Opus 5 additions follow Anthropic's guidance on redundant verification, delegation,
and narration: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5
Those additions are not a substitute for the general testing rule. Keep model rationale
here so generated instructions do not repeatedly pay for it.

## Category: Communication Style

### Light

- Lead with the answer. Include supporting detail when it helps the reader act.
- Start on the answer and stop when it is answered; omit pleasantries, restatements and closing offers of further help.
- Offer suggestions beyond the request only when they change what the reader would do next.

### Medium

All of the above, plus:

- Keep responses focused and brief. Keep disclaimers and caveats short, with most of the response on the main answer.
- When asked to explain something, give a high-level summary unless an in-depth one is requested.
- Let the result speak: show the diff, the output or the file rather than narrating what it contains.
- Match the response to the question. A simple question gets a direct answer in prose, not headers and sections.
- Calibrate to the reader: tighter for an expert, more explanatory for someone new.

### Full

All of the above, plus:

- Give the conclusion and stop. Add reasoning, alternatives and caveats only when asked, or when acting on the answer without them would be a mistake.
- Keep output short by cutting what you include, never by compressing how you write it. Fragments, invented abbreviations and arrow chains cost the reader a reread, which erases the saving.
- Use tables only for short enumerable facts, and keep the explanation in the surrounding prose.
- Match reasoning effort to the task; concise visible output alone does not guarantee lower total cost.

---

## Category: Agent Workflow

- Deliver the complete task at the intended scope. Make routine decisions yourself; clarify only when different readings would lead to materially different work.
- Before reporting completion, run checks appropriate to the change and required by the project. Report any remaining failures or unverified work.
- Read the relevant code before editing. Reuse context already available; retrieve missing sections or lost context when needed.
- Prefer targeted edits and direct fixes over unrelated rewrites or abstractions.
- Ask before changes outside the user's authorization, including protected files. Existing authorization to edit configuration does not need repeating.
- When delegating, provide sufficient context and assess the result against the task; avoid duplicating completed work without a concrete reason.

---

## Category: Formatting and Error Handling

- Preserve the user's language and necessary technical notation. Use ASCII only when the destination format requires it; preserve code and data exactly unless changing them is the task.
- Surface errors with the diagnostic detail needed to act, omitting sensitive values. Include a traceback when needed for diagnosis; avoid repeatedly dumping the same failure.
- In code reviews, explain the bug, its trigger and impact, and a concrete fix. Check relevant boundary conditions.
- Read large files selectively, expanding to their full contents when the task requires it.

---

## Model: Claude Opus 5

These optional instructions target Opus 5's documented tendency to add verification,
spawn subagents and narrate routine work. Omit them for other or mixed model use.

- Avoid a redundant verification pass or a verifier subagent after the necessary checks have passed. New failures, changes or unresolved concerns justify further checking.
- Delegate only when independent, substantial work justifies the extra context and coordination; finish small tasks directly.
- Keep progress updates and written deliverables proportional to the task. Explain material findings, corrections and changes of direction without narrating routine steps.
