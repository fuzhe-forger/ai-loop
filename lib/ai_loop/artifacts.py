"""Artifact helpers for AI Loop runs."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def update_run(run_dir: Path, **updates: Any) -> dict[str, Any]:
    run_path = run_dir / "run.json"
    data = read_json(run_path) if run_path.exists() else {}
    data.update(updates)
    data["updated_at"] = now_iso()
    write_json(run_path, data)
    return data

