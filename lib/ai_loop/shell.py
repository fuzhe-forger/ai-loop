"""Small subprocess helpers."""

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CommandResult:
    command: list[str]
    cwd: Path
    exit_code: int
    stdout: str
    stderr: str


class CommandError(Exception):
    """Raised when a command exits non-zero."""

    def __init__(self, result: CommandResult) -> None:
        super().__init__(result.stderr.strip() or result.stdout.strip() or f"command failed: {result.command}")
        self.result = result


def run_command(command: list[str], cwd: Path, timeout_sec: int = 120, check: bool = True) -> CommandResult:
    completed = subprocess.run(
        command,
        cwd=str(cwd),
        text=True,
        capture_output=True,
        timeout=timeout_sec,
    )
    result = CommandResult(
        command=command,
        cwd=cwd,
        exit_code=completed.returncode,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )
    if check and result.exit_code != 0:
        raise CommandError(result)
    return result

