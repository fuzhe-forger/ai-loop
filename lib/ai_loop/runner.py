"""AI Loop run orchestration."""

from __future__ import annotations

import fcntl
import hashlib
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterator, TextIO

from .agent import AgentError, AgentRequest, run_agent
from .artifacts import now_iso, update_run, write_json, write_text
from .config import ConfigError, config_text, load_config
from .diff import collect_diff
from .ids import validate_id
from .memory import record_run_memory
from .prompt import first_prompt, retry_prompt
from .safety import SafetyError, SafetyRequest, run_safety
from .verifier import VerifyError, VerifyRequest, run_verifier
from .workspace import WorkspaceError, WorkspaceRequest, create_git_worktree, loop_artifact_prefixes


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


@contextmanager
def run_lock(lock_path: Path) -> Iterator[TextIO]:
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("w", encoding="utf-8") as lock_file:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise RunError(f"run lock is held: {lock_path}") from exc
        try:
            yield lock_file
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


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
    try:
        run_id = validate_id(request.run_id or make_run_id(task), field="run_id")
    except ValueError as exc:
        raise RunError(str(exc)) from exc
    workspace_root = Path(config.get("workspace", {}).get("root", "/tmp/ai-loop/workspaces"))
    workspace_path = workspace_root / run_id
    base_ref = request.base_ref or config.get("repo", {}).get("default_ref") or "HEAD"
    lock_path = artifacts_root / ".locks" / f"{repo_hash(repo)}-{base_ref.replace('/', '_')}.lock"

    with run_lock(lock_path):
        return run_locked(request, repo, task, config, config_snapshot, artifacts_root, run_id, workspace_root, workspace_path, base_ref, lock_path)


def run_locked(
    request: RunRequest,
    repo: Path,
    task: Path,
    config: dict,
    config_snapshot: str,
    artifacts_root: Path,
    run_id: str,
    workspace_root: Path,
    workspace_path: Path,
    base_ref: str,
    lock_path: Path,
) -> Path:
    run_dir = artifacts_root / run_id
    if run_dir.exists():
        raise RunError(f"run already exists: {run_dir}")
    run_dir.mkdir(parents=True)

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
                    ignored_dirty_prefixes=loop_artifact_prefixes(repo, artifacts_root),
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
                patch_paths=[],
            )
            write_text(run_dir / "summary.md", summary)
            update_run(run_dir, status="FAILED", error_code="FAILED_WORKSPACE", exit_code=4, finished_at=now_iso())
            record_run_memory(run_dir)
            return run_dir
        workspace_path = workspace.path
        write_text(
            run_dir / "workspace.txt",
            f"mode=git-worktree\npath={workspace.path}\nbranch={workspace.branch}\nbase_ref={workspace.base_ref}\n",
        )
        update_run(run_dir, status="WORKSPACE_READY", workspace=str(workspace.path))

    write_text(run_dir / "prompt.1.md", first_prompt(task_content, str(workspace_path), config))
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
            patch_paths=[],
        )
        write_text(run_dir / "summary.md", summary)
        update_run(run_dir, status="PASSED", error_code=None, exit_code=0, finished_at=now_iso())
        record_run_memory(run_dir)
        return run_dir

    last_verify_error: VerifyError | None = None
    max_iterations = int(config.get("agent", {}).get("max_iterations", 1))
    patch_paths: list[str] = []
    for iteration in range(1, max_iterations + 1):
        prompt_path = run_dir / f"prompt.{iteration}.md"
        update_run(run_dir, status="AGENT_RUNNING", iteration=iteration)
        try:
            run_agent(
                AgentRequest(
                    workspace=workspace_path,
                    prompt_path=prompt_path,
                    run_dir=run_dir,
                    iteration=iteration,
                    config=config,
                )
            )
        except AgentError as exc:
            fail_run(
                run_dir=run_dir,
                run_id=run_id,
                error_code=exc.error_code,
                exit_code=exc.exit_code,
                repo=repo,
                workspace=str(workspace_path),
                dry_run=False,
                result=str(exc),
                patch_paths=patch_paths,
            )
            return run_dir

        update_run(run_dir, status="AGENT_DONE")
        diff_result = collect_diff(workspace_path, run_dir, iteration)
        patch_paths.append(diff_result.patch_path)
        update_run(run_dir, status="DIFF_COLLECTED", patch_paths=patch_paths)

        try:
            run_safety(SafetyRequest(run_dir=run_dir, iteration=iteration, diff=diff_result, config=config))
        except SafetyError as exc:
            fail_run(
                run_dir=run_dir,
                run_id=run_id,
                error_code=exc.error_code,
                exit_code=exc.exit_code,
                repo=repo,
                workspace=str(workspace_path),
                dry_run=False,
                result=f"safety failed: {exc}",
                patch_paths=patch_paths,
            )
            return run_dir

        update_run(run_dir, status="SAFETY_PASSED")
        try:
            run_verifier(VerifyRequest(workspace=workspace_path, run_dir=run_dir, iteration=iteration, config=config))
        except VerifyError as exc:
            last_verify_error = exc
            if iteration >= max_iterations:
                break
            next_iteration = iteration + 1
            write_text(
                run_dir / f"prompt.{next_iteration}.md",
                retry_prompt(
                    task_content=task_content,
                    workspace=str(workspace_path),
                    iteration=next_iteration,
                    diff_text=(run_dir / diff_result.patch_path).read_text(encoding="utf-8"),
                    verify_json=(run_dir / f"verify.{iteration}.json").read_text(encoding="utf-8"),
                    failure_log_tail=verify_failure_tail(run_dir, iteration, config),
                ),
            )
            update_run(run_dir, status="RETRY_READY", iteration=next_iteration)
            continue

        summary = build_summary(
            run_id=run_id,
            status="PASSED",
            error_code=None,
            exit_code=0,
            repo=repo,
            workspace=str(workspace_path),
            dry_run=False,
            result="agent changes passed safety checks and verification commands.",
            patch_paths=patch_paths,
        )
        write_text(run_dir / "summary.md", summary)
        update_run(run_dir, status="PASSED", error_code=None, exit_code=0, finished_at=now_iso(), patch_paths=patch_paths)
        record_run_memory(run_dir)
        return run_dir

    fail_run(
        run_dir=run_dir,
        run_id=run_id,
        error_code="FAILED_MAX_ITERATIONS",
        exit_code=7,
        repo=repo,
        workspace=str(workspace_path),
        dry_run=False,
        result=f"verification did not pass within {max_iterations} iterations: {last_verify_error}",
        patch_paths=patch_paths,
    )
    return run_dir


def fail_run(
    *,
    run_dir: Path,
    run_id: str,
    error_code: str,
    exit_code: int,
    repo: Path,
    workspace: str,
    dry_run: bool,
    result: str,
    patch_paths: list[str],
) -> None:
    summary = build_summary(
        run_id=run_id,
        status="FAILED",
        error_code=error_code,
        exit_code=exit_code,
        repo=repo,
        workspace=workspace,
        dry_run=dry_run,
        result=result,
        patch_paths=patch_paths,
    )
    write_text(run_dir / "summary.md", summary)
    update_run(
        run_dir,
        status="FAILED",
        error_code=error_code,
        exit_code=exit_code,
        finished_at=now_iso(),
        patch_paths=patch_paths,
    )
    record_run_memory(run_dir)


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
    patch_paths: list[str],
) -> str:
    artifacts = [
        "run.json",
        "task.md",
        "config.snapshot.yml",
        "workspace.txt",
        "prompt.1.md",
        "summary.md",
    ]
    artifacts.extend(patch_paths)
    artifact_lines = "\n".join(f"- `{artifact}`" for artifact in artifacts)
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

{artifact_lines}
"""


def verify_failure_tail(run_dir: Path, iteration: int, config: dict) -> str:
    tail_lines = int(config.get("artifacts", {}).get("log_tail_lines_for_retry", 200))
    verify_path = run_dir / f"verify.{iteration}.json"
    if not verify_path.exists():
        return ""

    import json

    data = json.loads(verify_path.read_text(encoding="utf-8"))
    chunks: list[str] = []
    for command in data.get("commands", []):
        if command.get("passed"):
            continue
        chunks.append(f"$ {command.get('command', '')}")
        for key in ("stdout_path", "stderr_path"):
            path_name = command.get(key)
            if not path_name:
                continue
            log_path = run_dir / str(path_name)
            if log_path.exists():
                lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
                chunks.extend(lines[-tail_lines:])
    return "\n".join(chunks)
