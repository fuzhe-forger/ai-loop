"""Project initialization."""

from __future__ import annotations

from pathlib import Path

from .defaults import BOOTSTRAP_TASK, DEFAULT_CONFIG


class InitError(Exception):
    """Raised when init cannot complete."""


def write_if_missing(path: Path, content: str, force: bool) -> bool:
    if path.exists() and not force:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
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
    return written

