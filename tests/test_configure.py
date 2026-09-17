"""Behavioral regression tests for rendering, preservation and approved writes."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skills/claude-token-saver/scripts/configure.py"
spec = importlib.util.spec_from_file_location("configure", SCRIPT)
configure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(configure)
BEGIN, END = configure.BEGIN, configure.END
SECTION = configure.render(["communication"])


class RenderingTests(unittest.TestCase):
    def test_default_is_small_and_general(self):
        self.assertEqual(SECTION.count("\n- "), 3)
        self.assertNotIn("### Agent Workflow", SECTION)
        self.assertNotIn("### Claude Opus 5", SECTION)
        self.assertLess(len(SECTION.split()), 100)

    def test_levels_are_cumulative_without_duplicate_rules(self):
        previous = set()
        for level in ("light", "medium", "full"):
            output = configure.render(["communication"], level)
            bullets = [line for line in output.splitlines() if line.startswith("- ")]
            self.assertTrue(previous < set(bullets))
            self.assertEqual(len(bullets), len(set(bullets)))
            self.assertNotIn("All of the above", output)
            previous = set(bullets)

    def test_every_selected_rule_is_literal_reference_text(self):
        reference = configure.REFERENCE.read_text()
        for line in configure.render(list(configure.CATEGORIES), "full", "opus-5").splitlines():
            if line.startswith("- "):
                self.assertIn(line + "\n", reference)

    def test_general_model_keeps_testing_without_opus_restrictions(self):
        output = configure.render(["workflow"])
        self.assertIn("run checks appropriate to the change", output)
        self.assertNotIn("verifier subagent", output)
        self.assertNotIn("Claude Opus 5 Workflow", output)

    def test_opus_additions_require_both_model_and_workflow(self):
        self.assertNotIn("verifier subagent", configure.render(["communication"], model="opus-5"))
        output = configure.render(["workflow"], model="opus-5")
        self.assertIn("verifier subagent", output)
        self.assertIn("run checks appropriate to the change", output)

    def test_category_order_does_not_change_output(self):
        self.assertEqual(configure.render(["workflow", "communication"]),
                         configure.render(["communication", "workflow"]))

    def test_bad_selections_fail(self):
        for categories in ([], ["oops"], ["communication", "communication"]):
            with self.subTest(categories=categories), self.assertRaises(ValueError):
                configure.render(categories)


class MergeTests(unittest.TestCase):
    def merge(self, text, section=SECTION):
        return configure.merge(text.encode(), section).decode()

    def test_creation(self):
        self.assertEqual(self.merge(""), "# CLAUDE.md\n\n" + SECTION)

    def test_append_preserves_existing_bytes(self):
        for ending in ("", "\n", "\n\n", "\n\n\n", "  \n"):
            original = "# CLAUDE.md\n\nKeep è and 日本語." + ending
            with self.subTest(ending=ending):
                output = self.merge(original)
                self.assertTrue(output.startswith(original))
                self.assertIn("\n\n" + BEGIN, output)

    def test_existing_fixtures_migrate_and_are_idempotent(self):
        for fixture in sorted((ROOT / "tests/fixtures/merge").glob("[0-9]*.md")):
            with self.subTest(fixture=fixture.name):
                original = fixture.read_bytes()
                output = configure.merge(original, SECTION)
                self.assertEqual(configure.merge(output, SECTION), output)
                self.assertEqual(output.count(BEGIN.encode()), 1)
                self.assertEqual(output.count(END.encode()), 1)
                if b"# Deployment" in original:
                    self.assertTrue(output.endswith(original[original.index(b"# Deployment"):]))
                if fixture.name.startswith("02"):
                    self.assertTrue(output.startswith(original))
                if fixture.name.startswith("03"):
                    self.assertNotIn(b"MY EDIT", output)
                if fixture.name.startswith("04"):
                    example = original[original.index(b"## Team notes"):original.rindex(b"## Token Efficiency")]
                    # The last heading above is live; its preceding fenced example survives.
                    self.assertIn(example, output)

    def test_level_one_and_two_boundaries(self):
        for heading in ("# Deployment", "## Deployment", "   # Deployment", "##\tDeployment",
                        "Deployment\n==========", "Deployment\n----------",
                        "Deployment policy\nfor production\n=========="):
            with self.subTest(heading=heading):
                prefix = "# CLAUDE.md\n\nUse pnpm.\n\n"
                suffix = "\n\n" + heading + "\n\nNever deploy without approval.\n"
                original = prefix + "## Token Efficiency\n\n### Old rules\n\nOld rule.\n" + suffix
                output = self.merge(original)
                self.assertTrue(output.startswith(prefix))
                self.assertTrue(output.endswith(suffix))
                self.assertNotIn("Old rule.", output)

    def test_fenced_and_commented_headings_are_not_sections(self):
        for example in ("```md\n## Token Efficiency\n```", "~~~md\n## Token Efficiency\n~~~",
                        "````md\n```\n## Token Efficiency\n````",
                        "<!--\n## Token Efficiency\n-->", "    ## Token Efficiency",
                        "\t## Token Efficiency"):
            with self.subTest(example=example):
                original = "# Examples\n\n" + example + "\n"
                self.assertTrue(self.merge(original).startswith(original))

    def test_fences_inside_legacy_section_do_not_truncate_replacement(self):
        for marker in ("```", "~~~", "````"):
            original = "## Token Efficiency\n\n" + marker + "md\n# Fake boundary\n" + marker + "\n\n# Keep\nkeep\n"
            output = self.merge(original)
            self.assertNotIn("Fake boundary", output)
            self.assertTrue(output.endswith("\n# Keep\nkeep\n"))

    def test_marker_examples_inside_fences_or_comments_are_preserved(self):
        for example in ("```md\n" + SECTION + "```\n", "<!--\n" + BEGIN + "\n"):
            # A comment ends at the marker's -->; a later end marker would be invalid.
            original = "# Examples\n\n" + example
            self.assertTrue(self.merge(original).startswith(original))

    def test_markers_survive_renaming_and_preserve_adjacent_content(self):
        prefix, suffix = "# Before\nunchanged\n\n", "\n# After\nunchanged\n"
        original = prefix + SECTION.replace("## Token Efficiency", "# My personal preferences") + suffix
        self.assertEqual(self.merge(original), prefix + SECTION + suffix)

    def test_duplicate_managed_blocks_are_consolidated(self):
        middle = "\n## Team notes\nkeep exactly\n\n"
        original = SECTION + middle + SECTION
        self.assertEqual(self.merge(original), SECTION + middle)

    def test_recognizable_renamed_legacy_sections_require_manual_migration(self):
        for heading in ("## Token Efficiency Rules", "## token efficiency", "# Token Efficiency",
                        "Token Efficiency Rules\n----------------------"):
            with self.subTest(heading=heading), self.assertRaises(configure.UnsafeMerge):
                self.merge(heading + "\n\n- My rules.\n")

    def test_unclosed_or_ambiguous_constructs_are_refused(self):
        for original in ("```\nunfinished", "~~~\nunfinished", "<!-- unfinished", BEGIN + "\n",
                         END + "\n", BEGIN + "\n" + BEGIN + "\n" + END + "\n",
                         "<div>\n## Token Efficiency\n</div>\n",
                         "- Example:\n\n  ```md\n## Token Efficiency\n  ```\n",
                         "- ```md\n## Token Efficiency\n  ```\n",
                         "Text <!-- comment\n## Token Efficiency\n-->\n"):
            with self.subTest(original=original), self.assertRaises(configure.UnsafeMerge):
                self.merge(original)

    def test_crlf_and_bom_preserved(self):
        prefix = b"\xef\xbb\xbf# CLAUDE.md\r\n\r\n"
        suffix = b"\r\n# Deployment\r\nPreserve me.\r\n"
        original = prefix + b"## Token Efficiency\r\n\r\n- Old.\r\n" + suffix
        result = configure.merge(original, SECTION)
        self.assertTrue(result.startswith(prefix))
        self.assertTrue(result.endswith(suffix))
        self.assertNotIn(b"\n", result.replace(b"\r\n", b""))
        self.assertEqual(configure.merge(result, SECTION), result)

    def test_removal_changes_only_owned_blocks(self):
        prefix, suffix = "# Before\n\n", "\n# After\nKeep.\n"
        self.assertEqual(self.merge(prefix + SECTION + suffix, None), prefix + suffix)
        self.assertEqual(self.merge(prefix + suffix, None), prefix + suffix)


class ApplyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="token saver è ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.target = self.root / "project" / "CLAUDE.md"
        self.plan = self.root / "plan.json"

    def preview(self, section=SECTION):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            configure.preview(self.target, self.plan, section)
        return configure.digest(self.plan.read_bytes()), output.getvalue()

    def write_existing(self, data=b"# Existing\n\nKeep this.\n"):
        self.target.parent.mkdir()
        self.target.write_bytes(data)
        return data

    def apply(self, approval):
        with contextlib.redirect_stdout(io.StringIO()):
            configure.apply(self.plan, approval)

    def test_preview_does_not_create_target_or_parent(self):
        _, diff = self.preview()
        self.assertFalse(self.target.parent.exists())
        self.assertIn("+## Token Efficiency", diff)
        self.assertEqual(stat.S_IMODE(self.plan.stat().st_mode), 0o600)

    def test_plan_cannot_be_the_target(self):
        self.target = self.root / "CLAUDE.md"
        with self.assertRaises(configure.UnsafeMerge):
            configure.preview(self.target, self.target, SECTION)
        self.assertFalse(self.target.exists())

    def test_existing_plan_is_not_overwritten(self):
        self.plan.write_bytes(b"An existing private plan.")
        with self.assertRaises(FileExistsError):
            self.preview()
        self.assertEqual(self.plan.read_bytes(), b"An existing private plan.")
        self.assertFalse(self.target.exists())

    def test_declining_by_discarding_plan_leaves_existing_file_unchanged(self):
        original = self.write_existing()
        self.preview()
        self.plan.unlink()
        self.assertEqual(self.target.read_bytes(), original)

    def test_apply_writes_exact_reviewed_content_and_preserves_mode(self):
        self.write_existing()
        self.target.chmod(0o640)
        approval, _ = self.preview()
        expected = configure.base64.b64decode(json.loads(self.plan.read_text())["after_base64"])
        self.apply(approval)
        self.assertEqual(self.target.read_bytes(), expected)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o640)

    def test_apply_creates_new_global_parent(self):
        approval, _ = self.preview()
        self.apply(approval)
        self.assertEqual(self.target.read_text(), "# CLAUDE.md\n\n" + SECTION)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)

    def test_changed_existing_target_is_not_overwritten(self):
        self.write_existing()
        approval, _ = self.preview()
        self.target.write_bytes(b"User edited this after preview.")
        with self.assertRaisesRegex(configure.UnsafeMerge, "Target changed"):
            self.apply(approval)
        self.assertEqual(self.target.read_bytes(), b"User edited this after preview.")

    def test_new_target_created_after_preview_is_not_overwritten(self):
        approval, _ = self.preview()
        self.write_existing()
        with self.assertRaises(configure.UnsafeMerge):
            self.apply(approval)

    def test_deleted_target_is_not_recreated(self):
        self.write_existing()
        approval, _ = self.preview()
        self.target.unlink()
        with self.assertRaises(configure.UnsafeMerge):
            self.apply(approval)
        self.assertFalse(self.target.exists())

    def test_tampered_plan_is_rejected(self):
        original = self.write_existing()
        approval, _ = self.preview()
        self.plan.write_bytes(self.plan.read_bytes() + b" ")
        with self.assertRaisesRegex(configure.UnsafeMerge, "Plan changed"):
            self.apply(approval)
        self.assertEqual(self.target.read_bytes(), original)

    def test_replayed_approval_is_rejected(self):
        approval, _ = self.preview()
        self.apply(approval)
        with self.assertRaises(configure.UnsafeMerge):
            self.apply(approval)

    def test_noop_does_not_write_a_plan(self):
        self.write_existing(("# CLAUDE.md\n\n" + SECTION).encode())
        with contextlib.redirect_stdout(io.StringIO()) as output:
            configure.preview(self.target, self.plan, SECTION)
        self.assertIn("No changes", output.getvalue())
        self.assertFalse(self.plan.exists())

    def test_symlink_target_is_rejected(self):
        actual = self.root / "actual.md"
        actual.write_text("Keep.")
        self.target.parent.mkdir()
        self.target.symlink_to(actual)
        with self.assertRaises(configure.UnsafeMerge):
            self.preview()
        self.assertEqual(actual.read_text(), "Keep.")

    def test_hard_link_target_is_rejected(self):
        self.write_existing()
        os.link(self.target, self.root / "other.md")
        with self.assertRaises(configure.UnsafeMerge):
            self.preview()

    def test_failed_replace_preserves_original_and_cleans_temporary_file(self):
        original = self.write_existing()
        approval, _ = self.preview()
        with patch.object(configure.os, "replace", side_effect=OSError("write failed")):
            with self.assertRaises(OSError):
                self.apply(approval)
        self.assertEqual(self.target.read_bytes(), original)
        self.assertEqual(list(self.target.parent.iterdir()), [self.target])

    def test_unsafe_markdown_leaves_target_and_plan_untouched(self):
        original = self.write_existing(b"<!-- unfinished\n")
        with self.assertRaises(configure.UnsafeMerge):
            self.preview()
        self.assertEqual(self.target.read_bytes(), original)
        self.assertFalse(self.plan.exists())

    def test_cli_preview_apply_and_remove(self):
        def run(*args):
            result = subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout
        self.write_existing()
        original = self.target.read_bytes()
        output = run("preview", "--target", str(self.target), "--plan", str(self.plan),
                     "--categories", "workflow", "--model", "general")
        self.assertIn("Approval digest:", output)
        run("apply", "--plan", str(self.plan), "--approve", configure.digest(self.plan.read_bytes()))
        self.assertIn(b"run checks appropriate", self.target.read_bytes())
        self.plan.unlink()
        run("preview", "--target", str(self.target), "--plan", str(self.plan), "--remove")
        run("apply", "--plan", str(self.plan), "--approve", configure.digest(self.plan.read_bytes()))
        self.assertTrue(self.target.read_bytes().startswith(original))
        self.assertNotIn(BEGIN.encode(), self.target.read_bytes())


class HookContractTests(unittest.TestCase):
    def test_hook_is_only_registered_for_startup(self):
        hooks = json.loads((ROOT / "hooks/hooks.json").read_text())["hooks"]["SessionStart"]
        self.assertEqual([hook["matcher"] for hook in hooks], ["startup"])

    def test_reminder_is_user_facing_json(self):
        with tempfile.TemporaryDirectory() as directory:
            env = dict(os.environ, HOME=directory)
            env.pop("CLAUDE_TOKEN_SAVER_QUIET", None)
            result = subprocess.run(["bash", str(ROOT / "hooks/session-start")],
                                    cwd=directory, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertIn("CLAUDE_TOKEN_SAVER_QUIET", payload["systemMessage"])
        self.assertNotIn("hookSpecificOutput", payload)


if __name__ == "__main__":
    unittest.main()
