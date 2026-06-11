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


def planning_prompt(task_content: str, repo: str) -> str:
    return f"""# AI Loop Planning Task

You are running in the planning stage of the AI Loop system.

## Raw Request

{task_content.strip()}

## Rules

- Do not modify files.
- Do not commit.
- Do not push.
- Do not deploy.
- Treat this as planning, not implementation.
- If information is missing, list concrete questions instead of guessing.

## Repository Context

Repository: {repo}

## Output Format

Produce an implementation-ready task plan with these sections:

1. Problem Statement
2. Assumptions
3. Open Questions
4. Scope
5. Non-goals
6. Proposed Implementation Steps
7. Files Or Modules To Inspect
8. Expected Artifacts
9. Verification Commands
10. Safety Boundaries
11. Ready-To-Run Task Markdown

The final section must be a task markdown draft that can be saved under `tasks/` and later passed to `ai-loop run`.
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
