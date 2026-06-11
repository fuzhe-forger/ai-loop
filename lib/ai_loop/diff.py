"""Diff collection helpers."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .artifacts import write_json, write_text
from .shell import run_command


@dataclass(frozen=True)
class DiffResult:
    iteration: int
    patch_path: str
    changed_files: list[str]
    diff_lines: int


def collect_diff(workspace: Path, run_dir: Path, iteration: int) -> DiffResult:
    diff = run_command(["git", "diff", "--binary"], cwd=workspace, check=False)
    names = run_command(["git", "diff", "--name-only"], cwd=workspace, check=False)
    patch_path = run_dir / f"diff.{iteration}.patch"
    write_text(patch_path, diff.stdout)

    changed_files = [line for line in names.stdout.splitlines() if line.strip()]
    diff_lines = count_diff_lines(diff.stdout)
    result = DiffResult(
        iteration=iteration,
        patch_path=patch_path.name,
        changed_files=changed_files,
        diff_lines=diff_lines,
    )
    write_json(
        run_dir / f"diff.{iteration}.json",
        {
            "schema_version": 1,
            "iteration": iteration,
            "patch_path": result.patch_path,
            "changed_files": result.changed_files,
            "diff_lines": result.diff_lines,
        },
    )
    return result


def count_diff_lines(diff_text: str) -> int:
    count = 0
    for line in diff_text.splitlines():
        if line.startswith("+++") or line.startswith("---"):
            continue
        if line.startswith("+") or line.startswith("-"):
            count += 1
    return count
