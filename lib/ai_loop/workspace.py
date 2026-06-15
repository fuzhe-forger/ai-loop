"""Workspace providers."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .shell import CommandError, run_command


class WorkspaceError(Exception):
    """Raised when workspace creation fails."""


@dataclass(frozen=True)
class WorkspaceRequest:
    repo: Path
    run_id: str
    workspace_root: Path
    base_ref: str
    branch_prefix: str = "ai-loop/"
    force: bool = False
    ignored_dirty_prefixes: tuple[str, ...] = ()


@dataclass(frozen=True)
class WorkspaceResult:
    provider: str
    path: Path
    branch: str
    base_ref: str
    created: bool


def loop_artifact_prefixes(repo: Path, artifacts_root: Path) -> tuple[str, ...]:
    prefixes: list[str] = []
    if artifacts_root.is_relative_to(repo):
        prefixes.append(str(artifacts_root.relative_to(repo)))
    return tuple(prefix for prefix in prefixes if prefix)


def create_git_worktree(request: WorkspaceRequest) -> WorkspaceResult:
    repo = request.repo.resolve()
    workspace_path = request.workspace_root / request.run_id
    branch = f"{request.branch_prefix}{request.run_id}"

    _ensure_git_repo(repo)
    _ensure_clean_repo(repo, request.ignored_dirty_prefixes)
    _ensure_ref_exists(repo, request.base_ref)

    if workspace_path.exists():
        if not request.force:
            raise WorkspaceError(f"workspace already exists: {workspace_path}")
        run_command(["git", "worktree", "remove", "--force", str(workspace_path)], cwd=repo, check=False)

    if _branch_exists(repo, branch):
        if not request.force:
            raise WorkspaceError(f"branch already exists: {branch}")
        run_command(["git", "branch", "-D", branch], cwd=repo)

    workspace_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        run_command(
            ["git", "worktree", "add", "-b", branch, str(workspace_path), request.base_ref],
            cwd=repo,
            timeout_sec=120,
        )
    except CommandError as exc:
        raise WorkspaceError(str(exc)) from exc

    return WorkspaceResult(
        provider="git-worktree",
        path=workspace_path,
        branch=branch,
        base_ref=request.base_ref,
        created=True,
    )


def _ensure_git_repo(repo: Path) -> None:
    try:
        result = run_command(["git", "rev-parse", "--is-inside-work-tree"], cwd=repo)
    except CommandError as exc:
        raise WorkspaceError(f"not a git repository: {repo}") from exc
    if result.stdout.strip() != "true":
        raise WorkspaceError(f"not a git repository: {repo}")


def _ensure_clean_repo(repo: Path, ignored_prefixes: tuple[str, ...] = ()) -> None:
    result = run_command(["git", "status", "--porcelain"], cwd=repo)
    dirty = []
    for line in result.stdout.splitlines():
        path = line[3:] if len(line) > 3 else line
        if any(path == prefix.rstrip("/") or path.startswith(prefix.rstrip("/") + "/") for prefix in ignored_prefixes):
            continue
        dirty.append(line)
    if dirty:
        raise WorkspaceError("source repo is dirty; commit or stash changes before creating a worktree")


def _ensure_ref_exists(repo: Path, ref: str) -> None:
    try:
        run_command(["git", "rev-parse", "--verify", f"{ref}^{{commit}}"], cwd=repo)
    except CommandError as exc:
        raise WorkspaceError(f"base ref does not exist locally: {ref}") from exc


def _branch_exists(repo: Path, branch: str) -> bool:
    result = run_command(["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"], cwd=repo, check=False)
    return result.exit_code == 0
