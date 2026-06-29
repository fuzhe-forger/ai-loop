"""Planning-stage orchestration for ambiguous Loop tasks."""

from __future__ import annotations

import copy
import hashlib
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from .agent import AgentError, AgentRequest, run_agent
from .artifacts import now_iso, update_run, write_json, write_text
from .config import ConfigError, config_text, load_config
from .ids import validate_id
from .memory import record_run_memory
from .prompt import planning_prompt


class PlanError(Exception):
    """Raised when a planning run cannot start."""


@dataclass(frozen=True)
class PlanRequest:
    repo: Path
    task: Path
    dry_run: bool = False
    run_id: str | None = None


def plan(request: PlanRequest) -> Path:
    repo = request.repo.resolve()
    if not repo.exists():
        raise PlanError(f"repo does not exist: {repo}")
    if not (repo / ".git").exists():
        raise PlanError(f"repo is not a git repository: {repo}")

    task = request.task
    if not task.is_absolute():
        task = repo / task
    if not task.exists():
        raise PlanError(f"task file does not exist: {task}")

    try:
        config = load_config(repo)
    except ConfigError as exc:
        raise PlanError(str(exc)) from exc

    config_snapshot = config_text(repo)
    artifacts_root = repo / config.get("artifacts", {}).get("root", "runs")
    try:
        run_id = validate_id(request.run_id or make_plan_run_id(task), field="run_id")
    except ValueError as exc:
        raise PlanError(str(exc)) from exc
    run_dir = artifacts_root / run_id
    if run_dir.exists():
        raise PlanError(f"run already exists: {run_dir}")
    run_dir.mkdir(parents=True)

    task_content = task.read_text(encoding="utf-8")
    write_text(run_dir / "task.md", task_content)
    write_text(run_dir / "config.snapshot.yml", config_snapshot)
    write_text(run_dir / "workspace.txt", f"mode=repo-read-only\npath={repo}\n")
    write_text(run_dir / "prompt.1.md", planning_prompt(task_content, str(repo)))

    write_json(
        run_dir / "run.json",
        {
            "schema_version": 1,
            "run_id": run_id,
            "mode": "plan",
            "status": "PLAN_READY",
            "error_code": None,
            "dry_run": request.dry_run,
            "created_at": now_iso(),
            "updated_at": now_iso(),
            "finished_at": None,
            "iteration": 1,
            "max_iterations": 1,
            "repo": str(repo),
            "workspace": str(repo),
            "workspace_mode": "repo-read-only",
            "task_file": str(task.relative_to(repo) if task.is_relative_to(repo) else task),
            "config_hash": sha256_text(config_snapshot),
            "summary_path": "summary.md",
            "plan_path": None,
            "patch_paths": [],
            "exit_code": None,
        },
    )

    if request.dry_run:
        write_text(
            run_dir / "summary.md",
            build_plan_summary(
                run_id,
                "PASSED",
                None,
                0,
                repo,
                "planning dry-run completed; prompt artifact generated.",
                include_agent_artifacts=False,
                include_plan_artifact=False,
            ),
        )
        update_run(run_dir, status="PASSED", error_code=None, exit_code=0, finished_at=now_iso())
        record_run_memory(run_dir)
        return run_dir

    update_run(run_dir, status="PLANNING_AGENT_RUNNING")
    try:
        result = run_agent(
            AgentRequest(
                workspace=repo,
                prompt_path=run_dir / "prompt.1.md",
                run_dir=run_dir,
                iteration=1,
                config=read_only_agent_config(config),
            )
        )
    except AgentError as exc:
        write_text(
            run_dir / "summary.md",
            build_plan_summary(
                run_id,
                "FAILED",
                exc.error_code,
                exc.exit_code,
                repo,
                str(exc),
                include_agent_artifacts=True,
                include_plan_artifact=False,
            ),
        )
        update_run(run_dir, status="FAILED", error_code=exc.error_code, exit_code=exc.exit_code, finished_at=now_iso())
        record_run_memory(run_dir)
        return run_dir

    final_message = run_dir / result.final_message_path
    if not final_message.exists() or not final_message.read_text(encoding="utf-8").strip():
        error = "planning agent completed but produced no final plan"
        write_text(
            run_dir / "summary.md",
            build_plan_summary(
                run_id,
                "FAILED",
                "FAILED_AGENT_EXIT",
                5,
                repo,
                error,
                include_agent_artifacts=True,
                include_plan_artifact=False,
            ),
        )
        update_run(run_dir, status="FAILED", error_code="FAILED_AGENT_EXIT", exit_code=5, finished_at=now_iso())
        record_run_memory(run_dir)
        return run_dir

    plan_text = final_message.read_text(encoding="utf-8")
    write_text(run_dir / "plan.md", plan_text)
    write_text(
        run_dir / "summary.md",
        build_plan_summary(
            run_id,
            "PASSED",
            None,
            0,
            repo,
            "planning completed; see plan.md.",
            include_agent_artifacts=True,
            include_plan_artifact=True,
        ),
    )
    update_run(run_dir, status="PASSED", error_code=None, exit_code=0, finished_at=now_iso(), plan_path="plan.md")
    record_run_memory(run_dir)
    return run_dir


def make_plan_run_id(task: Path) -> str:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    return f"{stamp}-plan-{slug_from_task(task)}"


def slug_from_task(task: Path) -> str:
    stem = task.stem.lower()
    allowed = []
    for char in stem:
        allowed.append(char if char.isalnum() else "-")
    slug = "".join(allowed).strip("-")
    return slug or "task"


def sha256_text(value: str) -> str:
    return "sha256:" + hashlib.sha256(value.encode("utf-8")).hexdigest()


def read_only_agent_config(config: dict[str, Any]) -> dict[str, Any]:
    plan_config = copy.deepcopy(config)
    agent = plan_config.setdefault("agent", {})
    args = [str(arg) for arg in agent.get("args", ["exec"])]
    agent["args"] = force_read_only_sandbox(args)
    agent["max_iterations"] = 1
    return plan_config


def force_read_only_sandbox(args: list[str]) -> list[str]:
    output = list(args)
    for index, arg in enumerate(output):
        if arg in ("-s", "--sandbox") and index + 1 < len(output):
            output[index + 1] = "read-only"
            return output
    output.extend(["-s", "read-only"])
    return output


def build_plan_summary(
    run_id: str,
    status: str,
    error_code: str | None,
    exit_code: int,
    repo: Path,
    result: str,
    *,
    include_agent_artifacts: bool,
    include_plan_artifact: bool,
) -> str:
    artifacts = [
        "run.json",
        "task.md",
        "config.snapshot.yml",
        "workspace.txt",
        "prompt.1.md",
    ]
    if include_agent_artifacts:
        artifacts.extend(["agent.1.log", "agent.1.json", "agent.1.final.md"])
    if include_plan_artifact:
        artifacts.append("plan.md")
    artifacts.append("summary.md")
    artifact_lines = "\n".join(f"- `{artifact}`" for artifact in artifacts)
    return f"""# AI Loop Plan Summary

- Run ID: `{run_id}`
- Mode: `plan`
- Status: `{status}`
- Error Code: `{error_code or ''}`
- Exit Code: `{exit_code}`
- Repo: `{repo}`

## Result

{result}

## Artifacts

{artifact_lines}
"""
