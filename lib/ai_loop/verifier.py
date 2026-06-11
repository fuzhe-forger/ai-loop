"""Deterministic verification command runner."""

from __future__ import annotations

import re
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .artifacts import write_json, write_text


class VerifyError(Exception):
    """Raised when required verification fails."""

    def __init__(self, message: str, *, error_code: str = "FAILED_VERIFY", exit_code: int = 1) -> None:
        super().__init__(message)
        self.error_code = error_code
        self.exit_code = exit_code


@dataclass(frozen=True)
class VerifyRequest:
    workspace: Path
    run_dir: Path
    iteration: int
    config: dict[str, Any]


def run_verifier(request: VerifyRequest) -> list[dict[str, Any]]:
    commands = request.config.get("verify", {}).get("commands", [])
    results: list[dict[str, Any]] = []
    required_failures: list[str] = []

    for index, command_config in enumerate(commands, start=1):
        result = run_verify_command(request, command_config, index)
        results.append(result)
        if result["required"] and not result["passed"]:
            required_failures.append(result["name"])

    write_json(
        request.run_dir / f"verify.{request.iteration}.json",
        {
            "schema_version": 1,
            "iteration": request.iteration,
            "passed": not required_failures,
            "commands": results,
        },
    )
    if required_failures:
        raise VerifyError("required verification failed: " + ", ".join(required_failures))
    return results


def run_verify_command(request: VerifyRequest, command_config: dict[str, Any], index: int) -> dict[str, Any]:
    name = str(command_config.get("name") or f"command-{index}")
    command = str(command_config.get("command") or "")
    if not command:
        raise VerifyError(f"verify command {name} is empty", error_code="FAILED_CONFIG", exit_code=3)

    cwd_value = str(command_config.get("cwd") or ".")
    cwd = (request.workspace / cwd_value).resolve()
    if not cwd.exists() or not cwd.is_dir():
        raise VerifyError(f"verify cwd does not exist for {name}: {cwd_value}", error_code="FAILED_CONFIG", exit_code=3)

    shell = bool(command_config.get("shell", True))
    timeout_sec = int(command_config.get("timeout_sec", 120))
    required = bool(command_config.get("required", True))
    slug = slugify(name)
    stdout_path = request.run_dir / f"verify.{request.iteration}.{index}.{slug}.stdout.log"
    stderr_path = request.run_dir / f"verify.{request.iteration}.{index}.{slug}.stderr.log"
    started = time.monotonic()
    timed_out = False

    try:
        completed = subprocess.run(
            ["/bin/bash", "-lc", command] if shell else command.split(),
            cwd=str(cwd),
            text=True,
            capture_output=True,
            timeout=timeout_sec,
        )
        exit_code = completed.returncode
        stdout = completed.stdout
        stderr = completed.stderr
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        exit_code = 124
        stdout = (exc.stdout or "") if isinstance(exc.stdout, str) else ""
        stderr = (exc.stderr or "") if isinstance(exc.stderr, str) else ""
        stderr += f"\n[ai-loop] verify command timed out after {timeout_sec}s\n"

    duration_ms = int((time.monotonic() - started) * 1000)
    write_text(stdout_path, redact(stdout, request.config))
    write_text(stderr_path, redact(stderr, request.config))
    passed = exit_code == 0 and not timed_out
    return {
        "name": name,
        "command": command,
        "shell": shell,
        "cwd": cwd_value,
        "timeout_sec": timeout_sec,
        "required": required,
        "exit_code": exit_code,
        "duration_ms": duration_ms,
        "timed_out": timed_out,
        "stdout_path": stdout_path.name,
        "stderr_path": stderr_path.name,
        "passed": passed,
    }


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9._-]+", "-", value.lower()).strip("-")
    return slug or "command"


def redact(content: str, config: dict[str, Any]) -> str:
    redact_config = config.get("safety", {}).get("redact", {})
    if not redact_config.get("enabled", True):
        return content
    redacted = content
    for pattern in redact_config.get("patterns", []):
        try:
            redacted = re.sub(str(pattern), "[REDACTED]", redacted)
        except re.error:
            continue
    return redacted
