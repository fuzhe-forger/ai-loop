"""AI Loop run orchestration."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from .artifacts import now_iso, update_run, write_json, write_text
from .config import ConfigError, config_text, load_config
from .prompt import first_prompt
from .workspace import WorkspaceError, WorkspaceRequest, create_git_worktree


class RunError(Exception):
    """Raised when a run cannot start."""


@dataclass(frozen=True)
class RunRequest:
    repo: Path
    task: Path
    dry_run: bool = False
    run_id: str | None = None
    base_ref: str | None = None


def slug_from_task(task: Path) -> str:
    stem = task.stem.lower()
    allowed = []
    for char in stem:
        allowed.append(char if char.isalnum() else "-")
    slug = "".join(allowed).strip("-")
    return slug or "task"


def make_run_id(task: Path) -> str:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    return f"{stamp}-{slug_from_task(task)}"


def sha256_text(value: str) -> str:
    return "sha256:" + hashlib.sha256(value.encode("utf-8")).hexdigest()


def repo_hash(repo: Path) -> str:
    return hashlib.sha256(str(repo.resolve()).encode("utf-8")).hexdigest()[:12]


def run(request: RunRequest) -> Path:
    repo = request.repo.resolve()
    if not repo.exists():
        raise RunError(f"repo does not exist: {repo}")
    if not (repo / ".git").exists():
        raise RunError(f"repo is not a git repository: {repo}")

    task = request.task
    if not task.is_absolute():
        task = repo / task
    if not task.exists():
        raise RunError(f"task file does not exist: {task}")

    try:
        config = load_config(repo)
    except ConfigError as exc:
        raise RunError(str(exc)) from exc

    config_snapshot = config_text(repo)
    artifacts_root = repo / config.get("artifacts", {}).get("root", "runs")
    run_id = request.run_id or make_run_id(task)
    run_dir = artifacts_root / run_id
    if run_dir.exists():
        raise RunError(f"run already exists: {run_dir}")
    run_dir.mkdir(parents=True)

    workspace_root = Path(config.get("workspace", {}).get("root", "/tmp/ai-loop/workspaces"))
    workspace_path = workspace_root / run_id
    base_ref = request.base_ref or config.get("repo", {}).get("default_ref") or "HEAD"
    lock_path = artifacts_root / ".locks" / f"{repo_hash(repo)}-{base_ref.replace('/', '_')}.lock"

    task_content = task.read_text(encoding="utf-8")
    write_text(run_dir / "task.md", task_content)
    write_text(run_dir / "config.snapshot.yml", config_snapshot)
    write_text(run_dir / "workspace.txt", f"mode=dry-run-simulated\npath={workspace_path}\n" if request.dry_run else str(workspace_path) + "\n")

    run_data = {
        "schema_version": 1,
        "run_id": run_id,
        "status": "CREATED",
        "error_code": None,
        "dry_run": request.dry_run,
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "finished_at": None,
        "iteration": 0,
        "max_iterations": int(config.get("agent", {}).get("max_iterations", 1)),
        "repo": str(repo),
        "workspace": str(workspace_path),
        "workspace_mode": "dry-run-simulated" if request.dry_run else "git-worktree",
        "task_file": str(task.relative_to(repo) if task.is_relative_to(repo) else task),
        "config_hash": sha256_text(config_snapshot),
        "lock_path": str(lock_path.relative_to(repo) if lock_path.is_relative_to(repo) else lock_path),
        "summary_path": "summary.md",
        "patch_paths": [],
        "exit_code": None,
    }
    write_json(run_dir / "run.json", run_data)
    update_run(run_dir, status="CONFIG_LOADED")

    if not request.dry_run:
        try:
            workspace = create_git_worktree(
                WorkspaceRequest(
                    repo=repo,
                    run_id=run_id,
                    workspace_root=workspace_root,
                    base_ref=base_ref,
                    branch_prefix=config.get("workspace", {}).get("branch_prefix", "ai-loop/"),
                    ignored_dirty_prefixes=(str(artifacts_root.relative_to(repo)) if artifacts_root.is_relative_to(repo) else "",),
                )
            )
        except WorkspaceError as exc:
            write_text(run_dir / "workspace.error.log", str(exc) + "\n")
            summary = build_summary(
                run_id=run_id,
                status="FAILED",
                error_code="FAILED_WORKSPACE",
                exit_code=4,
                repo=repo,
                workspace=str(workspace_path),
                dry_run=False,
                result=f"workspace creation failed: {exc}",
            )
            write_text(run_dir / "summary.md", summary)
            update_run(run_dir, status="FAILED", error_code="FAILED_WORKSPACE", exit_code=4, finished_at=now_iso())
            return run_dir
        workspace_path = workspace.path
        write_text(
            run_dir / "workspace.txt",
            f"mode=git-worktree\npath={workspace.path}\nbranch={workspace.branch}\nbase_ref={workspace.base_ref}\n",
        )
        update_run(run_dir, status="WORKSPACE_READY", workspace=str(workspace.path))

    prompt = first_prompt(task_content, str(workspace_path), config)
    write_text(run_dir / "prompt.1.md", prompt)
    update_run(run_dir, status="PROMPT_READY", iteration=1)

    if request.dry_run:
        summary = build_summary(
            run_id=run_id,
            status="PASSED",
            error_code=None,
            exit_code=0,
            repo=repo,
            workspace=str(workspace_path),
            dry_run=True,
            result="dry-run completed: config, task, workspace record, prompt, and summary artifacts were generated.",
        )
        write_text(run_dir / "summary.md", summary)
        update_run(run_dir, status="PASSED", error_code=None, exit_code=0, finished_at=now_iso())
        return run_dir

    summary = build_summary(
        run_id=run_id,
        status="FAILED",
        error_code="FAILED_INTERNAL",
        exit_code=9,
        repo=repo,
        workspace=str(workspace_path),
        dry_run=False,
        result="non dry-run execution is not implemented in this bootstrap slice.",
    )
    write_text(run_dir / "summary.md", summary)
    update_run(run_dir, status="FAILED", error_code="FAILED_INTERNAL", exit_code=9, finished_at=now_iso())
    return run_dir


def build_summary(
    *,
    run_id: str,
    status: str,
    error_code: str | None,
    exit_code: int,
    repo: Path,
    workspace: str,
    dry_run: bool,
    result: str,
) -> str:
    return f"""# AI Loop Run Summary

- Run ID: `{run_id}`
- Status: `{status}`
- Error Code: `{error_code or ''}`
- Exit Code: `{exit_code}`
- Repo: `{repo}`
- Workspace: `{workspace}`
- Dry Run: `{str(dry_run).lower()}`

## Result

{result}

## Artifacts

- `run.json`
- `task.md`
- `config.snapshot.yml`
- `workspace.txt`
- `prompt.1.md`
- `summary.md`
"""
