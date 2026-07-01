"""Optional CodeGraph context pack generation for AI Loop runs."""

from __future__ import annotations

import shutil
import re
from dataclasses import dataclass
from pathlib import Path

from .shell import CommandResult, run_command


@dataclass(frozen=True)
class GraphContextRequest:
    repo: Path
    task: Path
    output: Path
    base_ref: str = "HEAD"
    build: bool = False


@dataclass(frozen=True)
class GraphContextResult:
    status: str
    report_path: Path
    status_result: CommandResult | None = None
    affected_result: CommandResult | None = None


def generate_graph_context(request: GraphContextRequest) -> GraphContextResult:
    repo = request.repo.resolve()
    output = request.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    if not shutil.which("codegraph"):
        write_unavailable_report(output, repo, request.task, "codegraph command not found")
        return GraphContextResult(status="UNAVAILABLE", report_path=output)

    if request.build and not (repo / ".codegraph").exists():
        run_command(["codegraph", "init", str(repo)], cwd=repo, timeout_sec=300, check=False)

    status_result = run_command(["codegraph", "status", str(repo)], cwd=repo, timeout_sec=60, check=False)
    if status_result.exit_code != 0:
        write_unavailable_report(output, repo, request.task, status_result.stderr.strip() or status_result.stdout.strip())
        return GraphContextResult(status="UNAVAILABLE", report_path=output, status_result=status_result)

    changed_files = git_changed_files(repo, request.base_ref)
    affected_result = None
    if changed_files:
        affected_result = run_command(
            ["codegraph", "affected", *changed_files],
            cwd=repo,
            timeout_sec=120,
            check=False,
        )

    write_report(output, repo, request.task, request.base_ref, status_result, changed_files, affected_result)
    return GraphContextResult(
        status="READY",
        report_path=output,
        status_result=status_result,
        affected_result=affected_result,
    )


def git_changed_files(repo: Path, base_ref: str) -> list[str]:
    result = run_command(
        ["git", "diff", "--name-only", base_ref, "--"],
        cwd=repo,
        timeout_sec=60,
        check=False,
    )
    changed = [line.strip() for line in result.stdout.splitlines() if line.strip()] if result.exit_code == 0 else []
    return sorted(dict.fromkeys(changed))


def task_excerpt(task: Path, max_chars: int = 1200) -> str:
    try:
        content = task.read_text(encoding="utf-8").strip()
    except OSError:
        return "Task file could not be read."
    if len(content) <= max_chars:
        return content or "Task file is empty."
    return content[:max_chars].rstrip() + "\n..."


def context_pack_path(output: Path) -> Path:
    return output.with_name("context-pack.md")


def strip_ansi(value: str) -> str:
    return re.sub(r"\x1b\[[0-9;]*m", "", value)


def write_unavailable_report(output: Path, repo: Path, task: Path, reason: str) -> None:
    content = f"""# Graph Context

- Status: `UNAVAILABLE`
- Repo: `{repo}`
- Task: `{task}`
- Reason: {reason or 'unknown'}
- Remote writes: false

## Sinan Context Pack Contract

This artifact is the local code-understanding input for Sinan Loop stages.

- Plan: use it to identify files or modules to inspect first.
- Execute: keep edits within the listed changed or affected surface unless evidence expands scope.
- Verify: derive validation commands from the affected surface.
- Evidence: attach this report to the run summary when graph context was requested.

## Task Excerpt

```markdown
{task_excerpt(task)}
```

## Fallback

Continue with normal AI Loop execution. Use targeted file inspection and keep the diff surgical.
"""
    output.write_text(
        content,
        encoding="utf-8",
    )
    context_pack_path(output).write_text(
        content,
        encoding="utf-8",
    )


def write_report(
    output: Path,
    repo: Path,
    task: Path,
    base_ref: str,
    status_result: CommandResult,
    changed_files: list[str],
    affected_result: CommandResult | None,
) -> None:
    changed_lines = "\n".join(f"- `{path}`" for path in changed_files) or "- No changed files detected."
    affected_text = "Not run: no changed files detected."
    if affected_result is not None:
        affected_text = strip_ansi(affected_result.stdout or affected_result.stderr or "").strip() or "No affected files reported."
    status_text = strip_ansi(status_result.stdout or status_result.stderr).strip()

    content = f"""# Graph Context

- Status: `READY`
- Repo: `{repo}`
- Task: `{task}`
- Base ref: `{base_ref}`
- Remote writes: false

## Sinan Context Pack Contract

This artifact is the local code-understanding input for Sinan Loop stages.

- Plan: use CodeGraph status, changed files, and affected context to pick the first inspection surface.
- Execute: keep edits within the changed or affected surface unless direct evidence expands scope.
- Verify: use affected modules to choose focused tests before broader checks.
- Evidence: preserve this report under `runs/<run-id>/` so later windows do not reread the whole repo.

## Task Excerpt

```markdown
{task_excerpt(task)}
```

## CodeGraph Status

```text
{status_text}
```

## Changed Files

{changed_lines}

Tracked diff only. Untracked files are omitted to avoid pulling unrelated local scratch space into the prompt.

## Affected Context

```text
{affected_text}
```

## Usage Rule

Start with the changed and affected files above. Expand context only when the evidence shows a missing dependency.
"""
    output.write_text(
        content,
        encoding="utf-8",
    )
    context_pack_path(output).write_text(
        content,
        encoding="utf-8",
    )
