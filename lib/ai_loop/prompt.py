"""Prompt generation for AI Loop."""

from __future__ import annotations

from pathlib import Path
from typing import Any


def first_prompt(task_content: str, workspace: str, config: dict[str, Any]) -> str:
    commands = config.get("verify", {}).get("commands", [])
    command_lines = []
    for index, command in enumerate(commands, start=1):
        command_lines.append(f"{index}. {command.get('command', '')}")
    rendered_commands = "\n".join(command_lines) if command_lines else "(no verify commands configured)"

    return f"""# AI Loop Task

You are running inside an isolated workspace.

## Goal

{task_content.strip()}

## Rules

- Modify only this workspace.
- Do not commit.
- Do not push.
- Keep changes focused.
- Do not edit verification commands to bypass checks.
- Final answer must summarize changed files.

## Repository Context

Workspace: {workspace}

## Verification Commands

The loop controller will run:

{rendered_commands}

Your job is to make these pass.
"""


def retry_prompt(
    *,
    task_content: str,
    workspace: str,
    iteration: int,
    diff_text: str,
    verify_json: str,
    failure_log_tail: str,
) -> str:
    return f"""# AI Loop Retry Task

You are still running inside the same isolated workspace.

## Original Goal

{task_content.strip()}

## Retry Context

- Current iteration: {iteration}
- Previous verification failed.
- Keep useful existing edits; only change what is needed to pass verification.
- Do not commit.
- Do not push.
- Do not edit verification commands to bypass checks.

## Current Diff

```diff
{diff_text.strip()}
```

## Verification Result

```json
{verify_json.strip()}
```

## Failure Log Tail

```text
{failure_log_tail.strip()}
```

Workspace: {workspace}
"""
