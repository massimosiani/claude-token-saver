# Merge fixtures

Step 5 of the skill is instructions to a model, not code, so these cannot run in
`tests/run.sh`. Point `/claude-token-saver` at a copy of each and check the result by
hand. They exist because reviewing the spec three times missed a defect that running it
against `02` found immediately.

| Fixture | Expected outcome |
|---|---|
| *(no file)* | Creates a CLAUDE.md with a top-level heading and one section. |
| `02-no-section.md` | Appends at the end of the file. The `# Build commands` section above it is left untouched. |
| `03-user-edited-section.md` | Shows a diff surfacing `MY EDIT` as a removal, and changes nothing if declined. `# Deployment` survives. |
| `06-fence-inside-section.md` | A fence *inside* a live section, quoting `## Token Efficiency`. The section must be bounded past the fence, not truncated at the fenced heading - which would leave an unterminated ``` in the file. |
| `04-two-sections-and-fence.md` | The hard one. Both live sections replaced by one, at the first section's position; the fenced example left intact; `## Team notes` and `# Deployment` preserved; no `8-10 word` or `Think before acting` rule left anywhere. |
| `05-section-at-eof.md` | The section runs to the last line, with no heading after it. This is the shape most upgraders have, since pre-1.1.0 appended. Exercises the end-of-file bound. |

`04` and `06` are the two that matter. `04` covers finding every section rather than the
first, and bounding without truncating on `###` subheadings or running past a `# ` heading.
`06` covers the interaction `04` misses: fence-awareness during *bounding*, not just during
finding. An implementation that tracks fences only when locating headings passes `04` and
corrupts `06`.

Neither covers `~~~` fences or indented code blocks, which the spec does not mention.
