"""Artifact helpers for AI Loop runs."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def write_json(path: Path, data: dict[str, Any]) -> None:
    write_text(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_name(f".{path.name}.tmp-{os.getpid()}")
    with tmp_path.open("w", encoding="utf-8") as tmp_file:
        tmp_file.write(content)
        tmp_file.flush()
        os.fsync(tmp_file.fileno())
    tmp_path.replace(path)


def update_run(run_dir: Path, **updates: Any) -> dict[str, Any]:
    run_path = run_dir / "run.json"
    data = read_json(run_path) if run_path.exists() else {}
    data.update(updates)
    data["updated_at"] = now_iso()
    write_json(run_path, data)
    return data
