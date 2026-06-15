"""Project initialization."""

from __future__ import annotations

from pathlib import Path

from .defaults import BOOTSTRAP_TASK, DEFAULT_CONFIG, DEFAULT_GITIGNORE


class InitError(Exception):
    """Raised when init cannot complete."""


def write_if_missing(path: Path, content: str, force: bool) -> bool:
    if path.exists() and not force:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def ensure_gitignore(path: Path, content: str, force: bool) -> bool:
    if not path.exists():
        return write_if_missing(path, content, force=True)

    existing = path.read_text(encoding="utf-8")
    missing_lines = [line for line in content.splitlines() if line and line not in existing.splitlines()]
    if not missing_lines:
        return False

    separator = "" if existing.endswith("\n") else "\n"
    path.write_text(existing + separator + "\n".join(missing_lines) + "\n", encoding="utf-8")
    return True


def init_repo(repo: Path, force: bool = False) -> list[Path]:
    if not repo.exists():
        raise InitError(f"repo does not exist: {repo}")
    repo.mkdir(parents=True, exist_ok=True)

    written: list[Path] = []
    targets = [
        (repo / ".ai-loop.yml", DEFAULT_CONFIG),
        (repo / "tasks" / "bootstrap-ai-loop.md", BOOTSTRAP_TASK),
        (repo / "runs" / ".gitkeep", "\n"),
        (repo / "runs" / ".locks" / ".gitkeep", "\n"),
    ]
    for path, content in targets:
        if write_if_missing(path, content, force):
            written.append(path)
    gitignore_path = repo / ".gitignore"
    if ensure_gitignore(gitignore_path, DEFAULT_GITIGNORE, force):
        written.append(gitignore_path)
    return written
