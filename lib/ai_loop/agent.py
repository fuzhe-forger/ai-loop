"""Agent executors."""

from __future__ import annotations

import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .artifacts import write_json


class AgentError(Exception):
    """Raised when an agent execution fails."""

    def __init__(self, message: str, *, error_code: str, exit_code: int) -> None:
        super().__init__(message)
        self.error_code = error_code
        self.exit_code = exit_code


@dataclass(frozen=True)
class AgentRequest:
    workspace: Path
    prompt_path: Path
    run_dir: Path
    iteration: int
    config: dict[str, Any]


@dataclass(frozen=True)
class AgentResult:
    executor: str
    command: list[str]
    exit_code: int
    duration_ms: int
    timeout: bool
    log_path: str
    final_message_path: str


def run_agent(request: AgentRequest) -> AgentResult:
    agent_config = request.config.get("agent", {})
    executor = agent_config.get("executor", "codex")
    if executor != "codex":
        raise AgentError(f"unsupported agent executor: {executor}", error_code="FAILED_CONFIG", exit_code=3)
    return run_codex(request)


def run_codex(request: AgentRequest) -> AgentResult:
    agent_config = request.config.get("agent", {})
    command = [agent_config.get("command", "codex")]
    command.extend(str(arg) for arg in agent_config.get("args", ["exec", "-s", "workspace-write"]))
    final_message = request.run_dir / f"agent.{request.iteration}.final.md"
    command.extend(["-C", str(request.workspace), "-o", str(final_message), "-"])

    log_path = request.run_dir / f"agent.{request.iteration}.log"
    timeout_sec = int(agent_config.get("timeout_sec", 1800))
    started = time.monotonic()
    timeout = False

    with log_path.open("w", encoding="utf-8") as log_file:
        prompt = request.prompt_path.read_text(encoding="utf-8")
        log_file.write("$ " + " ".join(command) + f" < {request.prompt_path.name}\n\n")
        log_file.flush()
        try:
            completed = subprocess.run(
                command,
                cwd=str(request.workspace),
                text=True,
                input=prompt,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                timeout=timeout_sec,
            )
            exit_code = completed.returncode
        except subprocess.TimeoutExpired:
            timeout = True
            exit_code = 124
            log_file.write(f"\n[ai-loop] agent timed out after {timeout_sec}s\n")

    duration_ms = int((time.monotonic() - started) * 1000)
    result = AgentResult(
        executor="codex",
        command=command,
        exit_code=exit_code,
        duration_ms=duration_ms,
        timeout=timeout,
        log_path=log_path.name,
        final_message_path=final_message.name,
    )
    write_json(
        request.run_dir / f"agent.{request.iteration}.json",
        {
            "schema_version": 1,
            "iteration": request.iteration,
            "executor": result.executor,
            "model": agent_config.get("model"),
            "command": result.command,
            "exit_code": result.exit_code,
            "duration_ms": result.duration_ms,
            "timeout": result.timeout,
            "log_path": result.log_path,
            "final_message_path": result.final_message_path,
        },
    )

    if timeout:
        raise AgentError("agent timed out", error_code="FAILED_AGENT_TIMEOUT", exit_code=8)
    if exit_code != 0:
        raise AgentError(f"agent exited with code {exit_code}", error_code="FAILED_AGENT_EXIT", exit_code=5)
    return result
