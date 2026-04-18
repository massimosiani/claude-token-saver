# Token-Efficient Rules Reference

Rules sourced from https://github.com/drona23/claude-token-efficient and adapted for AGENTS.md.

---

## Category: Communication Style

### Light

- Do not begin responses with filler words like "Sure!", "Of course!", "Absolutely!", "Great question!"
- Do not use sycophantic or flattering language
- Do not restate the user's question before answering
- Lead with the answer, not the reasoning
- Exclude unsolicited suggestions beyond the request

### Medium

All of the above, plus:

- Remove decorative openings and closings from responses
- Prioritize tools and results over explanation
- Skip trailing summaries of what you just did - the diff or output speaks for itself
- Keep explanations to what is strictly necessary for the user to understand

### Full

All of the above, plus:

- Keep sentences to 8-10 words maximum
- If you can say it in one sentence, do not use three
- Compress English prose aggressively; code remains unchanged
- Be concise in output but thorough in reasoning

---

## Category: Technical Formatting

- Use standard hyphens only - no em-dashes or double-dashes (--)
- Do not use smart quotes or curly quotes - use straight quotes only
- Avoid Unicode characters that may break parsers or terminals
- Eliminate parenthetical phrases entirely - restructure as separate sentences if needed
- Do not restate questions before answering

---

## Category: Workflow Discipline

- Read and examine files before generating solutions - understand context first
- Prefer targeted, surgical edits over rewriting entire files
- Read each file only once unless the file has changed - do not re-examine unchanged content
- Run tests and validate solutions before declaring work complete
- Favor direct, simple fixes over unsolicited abstractions or over-engineering
- Think before acting

---

## Category: Error Handling

- Never silently swallow errors - stop immediately and report the full error with traceback
- For code reviews, state the bug and provide the fix - nothing more
- Never modify protected or configuration files without explicit user confirmation
- Check boundary logic (< vs <=) before passing review

---

## Category: File Handling

- Skip files exceeding 100KB unless explicitly required by the user
- Prefer editing existing files over rewriting them entirely
- Read each file once; do not re-read unchanged files
- Do not create new files unless absolutely necessary
