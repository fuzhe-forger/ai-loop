from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from lib.ai_loop import graph_context
from lib.ai_loop.shell import CommandResult


class GraphContextTests(unittest.TestCase):
    def test_unavailable_report_writes_context_pack(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            task = repo / "task.md"
            task.write_text("# Task\n\nDo the thing.\n", encoding="utf-8")
            output = repo / "runs" / "run-1" / "graph-context.md"

            with patch.object(graph_context.shutil, "which", return_value=None):
                result = graph_context.generate_graph_context(
                    graph_context.GraphContextRequest(repo=repo, task=task, output=output)
                )

            self.assertEqual(result.status, "UNAVAILABLE")
            self.assertTrue(output.exists())
            context_pack = output.with_name("context-pack.md")
            self.assertTrue(context_pack.exists())
            content = context_pack.read_text(encoding="utf-8")
            self.assertIn("Status: `UNAVAILABLE`", content)
            self.assertIn("Sinan Context Pack Contract", content)
            self.assertIn("Do the thing.", content)

    def test_ready_report_writes_context_pack_with_affected_context(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            repo.mkdir()
            task = repo / "task.md"
            task.write_text("# Task\n\nPatch graph context.\n", encoding="utf-8")
            output = repo / "runs" / "run-2" / "graph-context.md"

            def fake_run_command(command: list[str], cwd: Path, timeout_sec: int = 120, check: bool = True) -> CommandResult:
                if command[:2] == ["codegraph", "status"]:
                    return CommandResult(command, cwd, 0, "Index Statistics:\n  Files: 2\n", "")
                if command[:3] == ["git", "diff", "--name-only"]:
                    return CommandResult(command, cwd, 0, "lib/ai_loop/graph_context.py\n", "")
                if command[:2] == ["codegraph", "affected"]:
                    return CommandResult(command, cwd, 0, "affected: tests/test_graph_context.py\n", "")
                self.fail(f"unexpected command: {command}")

            with (
                patch.object(graph_context.shutil, "which", return_value="/usr/bin/codegraph"),
                patch.object(graph_context, "run_command", side_effect=fake_run_command),
            ):
                result = graph_context.generate_graph_context(
                    graph_context.GraphContextRequest(repo=repo, task=task, output=output, base_ref="HEAD")
                )

            self.assertEqual(result.status, "READY")
            context_pack = output.with_name("context-pack.md")
            self.assertTrue(context_pack.exists())
            content = context_pack.read_text(encoding="utf-8")
            self.assertIn("Status: `READY`", content)
            self.assertIn("lib/ai_loop/graph_context.py", content)
            self.assertIn("affected: tests/test_graph_context.py", content)
            self.assertIn("Evidence: preserve this report", content)


if __name__ == "__main__":
    unittest.main()
