# Merge fixtures

These historical CLAUDE.md examples now run automatically in `tests/test_configure.py`.
The helper must migrate each to one managed block and preserve unrelated content.

| Fixture | Expected outcome |
|---|---|
| `02-no-section.md` | Append without changing existing build notes. |
| `03-user-edited-section.md` | Include `MY EDIT` in the proposed removal; preserve Deployment. Preview alone never writes. |
| `04-two-sections-and-fence.md` | Consolidate both live sections at the first position; preserve the Team notes fenced example and Deployment. |
| `05-section-at-eof.md` | Replace through EOF. |
| `06-fence-inside-section.md` | Replace the whole section, including its fenced example, without truncating at a quoted heading. |

The Python suite additionally exercises Setext and indented headings, tilde and longer
backtick fences, HTML comments, malformed blocks, renamed headings, missing final
newlines, CRLF/BOM preservation, model selection and preview/apply behavior.
