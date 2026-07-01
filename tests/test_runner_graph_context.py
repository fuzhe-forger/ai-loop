from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from lib.ai_loop import graph_context
from lib.ai_loop.runner import RunRequest, run
from lib.ai_loop.shell import CommandResult


class RunnerGraphContextTests(unittest.TestCase):
    def test_dry_run_records_context_pack_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "repo"
            repo.mkdir()
            (repo / ".git").mkdir()
            (repo / ".ai-loop.yml").write_text(
                """version: 1
workspace:
  provider: git-worktree
  root: /tmp/ai-loop-tests
agent:
  max_iterations: 1
verify:
  commands:
    - name: noop
      command: python -V
artifacts:
  root: runs
""",
                encoding="utf-8",
            )
            task = repo / "task.md"
            task.write_text("# Task\n\nUse graph context.\n", encoding="utf-8")

            def fake_run_command(command: list[str], cwd: Path, timeout_sec: int = 120, check: bool = True) -> CommandResult:
                if command[:2] == ["codegraph", "status"]:
                    return CommandResult(command, cwd, 0, "Index Statistics:\n  Files: 1\n", "")
                if command[:3] == ["git", "diff", "--name-only"]:
                    return CommandResult(command, cwd, 0, "lib/ai_loop/runner.py\n", "")
                if command[:2] == ["codegraph", "affected"]:
                    return CommandResult(command, cwd, 0, "affected: lib/ai_loop/prompt.py\n", "")
                self.fail(f"unexpected command: {command}")

            with (
                patch.object(graph_context.shutil, "which", return_value="/usr/bin/codegraph"),
                patch.object(graph_context, "run_command", side_effect=fake_run_command),
            ):
                run_dir = run(
                    RunRequest(
                        repo=repo,
                        task=task,
                        dry_run=True,
                        run_id="test-graph-context",
                        use_graph_context=True,
                    )
                )

            run_data = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
            self.assertEqual(run_data["graph_context_path"], "graph-context.md")
            self.assertEqual(run_data["context_pack_path"], "context-pack.md")
            self.assertEqual(run_data["context_artifact_paths"], ["graph-context.md", "context-pack.md"])
            summary = (run_dir / "summary.md").read_text(encoding="utf-8")
            self.assertIn("`graph-context.md`", summary)
            self.assertIn("`context-pack.md`", summary)


if __name__ == "__main__":
    unittest.main()
