"""Configuration loading and validation."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml


class ConfigError(Exception):
    """Raised when `.ai-loop.yml` is missing or invalid."""


def load_config(repo: Path) -> dict[str, Any]:
    config_path = repo / ".ai-loop.yml"
    if not config_path.exists():
        raise ConfigError(f"missing config: {config_path}")

    data = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise ConfigError("config must be a YAML mapping")

    if data.get("version") != 1:
        raise ConfigError("only config version 1 is supported")

    workspace = data.get("workspace") or {}
    if workspace.get("provider") != "git-worktree":
        raise ConfigError("MVP only supports workspace.provider=git-worktree")

    agent = data.get("agent") or {}
    if int(agent.get("max_iterations", 0) or 0) < 1:
        raise ConfigError("agent.max_iterations must be >= 1")

    verify = data.get("verify") or {}
    commands = verify.get("commands") or []
    if not isinstance(commands, list):
        raise ConfigError("verify.commands must be a list")
    for index, command in enumerate(commands, start=1):
        if not isinstance(command, dict):
            raise ConfigError(f"verify.commands[{index}] must be a mapping")
        if not isinstance(command.get("command"), str) or not command.get("command", "").strip():
            raise ConfigError(f"verify.commands[{index}].command must be a non-empty string")
        if "name" in command and not isinstance(command.get("name"), str):
            raise ConfigError(f"verify.commands[{index}].name must be a string")

    return data


def config_text(repo: Path) -> str:
    return (repo / ".ai-loop.yml").read_text(encoding="utf-8")
