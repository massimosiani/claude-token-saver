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
| `04-two-sections-and-fence.md` | The hard one. Both live sections replaced by one, at the first section's position; the fenced example left intact; `## Team notes` and `# Deployment` preserved; no `8-10 word` or `Think before acting` rule left anywhere. |
| `05-section-at-eof.md` | The section runs to the last line, with no heading after it. This is the shape most upgraders have, since pre-1.1.0 appended. Exercises the end-of-file bound. |

`04` is the regression test that matters: it hits all three traps at once - find every
section rather than the first, ignore headings inside fences, and bound each section
without truncating on its own `###` subheadings or running past the `# ` heading below it.
