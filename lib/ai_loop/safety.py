"""Safety checks for generated changes."""

from __future__ import annotations

import fnmatch
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .artifacts import write_json
from .diff import DiffResult


class SafetyError(Exception):
    """Raised when generated changes violate safety policy."""

    def __init__(self, message: str, *, error_code: str = "FAILED_SAFETY", exit_code: int = 6) -> None:
        super().__init__(message)
        self.error_code = error_code
        self.exit_code = exit_code


@dataclass(frozen=True)
class SafetyRequest:
    run_dir: Path
    iteration: int
    diff: DiffResult
    config: dict[str, Any]


@dataclass(frozen=True)
class SafetyResult:
    passed: bool
    changed_files: list[str]
    diff_lines: int
    forbidden_paths_hit: list[str]
    errors: list[str]


def run_safety(request: SafetyRequest) -> SafetyResult:
    safety_config = request.config.get("safety", {})
    changed_files = request.diff.changed_files
    diff_lines = request.diff.diff_lines
    max_changed_files = int(safety_config.get("max_changed_files", 0) or 0)
    max_diff_lines = int(safety_config.get("max_diff_lines", 0) or 0)
    forbidden_patterns = [str(pattern) for pattern in safety_config.get("forbid_paths", [])]

    errors: list[str] = []
    forbidden_paths_hit = find_forbidden_paths(changed_files, forbidden_patterns)
    if forbidden_paths_hit:
        errors.append("forbidden paths changed: " + ", ".join(forbidden_paths_hit))
    if max_changed_files and len(changed_files) > max_changed_files:
        errors.append(f"changed file count {len(changed_files)} exceeds max_changed_files {max_changed_files}")
    if max_diff_lines and diff_lines > max_diff_lines:
        errors.append(f"diff line count {diff_lines} exceeds max_diff_lines {max_diff_lines}")

    result = SafetyResult(
        passed=not errors,
        changed_files=changed_files,
        diff_lines=diff_lines,
        forbidden_paths_hit=forbidden_paths_hit,
        errors=errors,
    )
    write_json(
        request.run_dir / f"safety.{request.iteration}.json",
        {
            "schema_version": 1,
            "iteration": request.iteration,
            "passed": result.passed,
            "changed_files": result.changed_files,
            "diff_lines": result.diff_lines,
            "forbidden_paths_hit": result.forbidden_paths_hit,
            "errors": result.errors,
        },
    )
    if not result.passed:
        raise SafetyError("; ".join(errors))
    return result


def find_forbidden_paths(paths: list[str], patterns: list[str]) -> list[str]:
    hits: list[str] = []
    for path in paths:
        normalized = path.strip().lstrip("./")
        for pattern in patterns:
            normalized_pattern = pattern.strip().lstrip("./")
            if not normalized_pattern:
                continue
            if normalized_pattern.endswith("/") and normalized.startswith(normalized_pattern):
                hits.append(path)
                break
            if fnmatch.fnmatch(normalized, normalized_pattern):
                hits.append(path)
                break
            if fnmatch.fnmatch(Path(normalized).name, normalized_pattern):
                hits.append(path)
                break
    return hits
