#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/writeback-summary-json.sh --run-id <run-id> [options]

Generate structured writeback-summary.json from runs/<run-id>/writeback-summary.md.

Options:
  --run-id <run-id>   Run identifier under runs/, required
  --issue <issue>     Optional issue identifier override
  --input <file>      Markdown writeback summary path
  --output <file>     JSON output path (default: runs/<run>/writeback-summary.json)
  -h, --help          Show this help

This script is local-only. It never writes Multica, Feishu, Obsidian, or Git remote.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_id=""
issue_id=""
input_file=""
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --input)
      input_file="${2:-}"; shift 2 ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$run_id" ]]; then
  echo "--run-id is required" >&2
  show_help
  exit 2
fi

run_dir="$ROOT_DIR/runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

if [[ -z "$input_file" ]]; then
  input_file="$run_dir/writeback-summary.md"
fi
if [[ -z "$output_file" ]]; then
  output_file="$run_dir/writeback-summary.json"
fi

if [[ ! -s "$input_file" ]]; then
  echo "Writeback summary is missing or empty: $input_file" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_file")"

python3 - <<'PY' "$input_file" "$output_file" "$issue_id" "$run_id" "$ROOT_DIR"
import datetime as dt
import json
import re
import sys
from pathlib import Path

input_path, output_path, issue_arg, run_id, root_dir = sys.argv[1:]
input_path = Path(input_path)
output_path = Path(output_path)
root = Path(root_dir)
text = input_path.read_text(encoding="utf-8", errors="replace")


def line_value(label: str) -> str:
    pattern = re.compile(rf"^- {re.escape(label)}:[ \t]*(.*)$", re.MULTILINE)
    match = pattern.search(text)
    return match.group(1).strip() if match else ""


def bool_value(label: str):
    raw = line_value(label).lower()
    if raw == "true":
        return True
    if raw == "false":
        return False
    if raw == "failed":
        return "failed"
    return None


def artifact(label: str) -> str:
    return line_value(label)

issue = issue_arg or line_value("Issue") or "unknown"
metadata_write_value = line_value("Metadata write value")
metadata_key = ""
metadata_value = ""
if metadata_write_value and "=" in metadata_write_value:
    metadata_key, metadata_value = metadata_write_value.split("=", 1)

data = {
    "schema_version": 1,
    "issue": issue,
    "run_id": run_id,
    "source": str(input_path.relative_to(root) if input_path.is_absolute() and root in input_path.parents else input_path),
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "requests": {
        "comment": bool_value("Write comment requested"),
        "status": bool_value("Write status requested"),
        "metadata": bool_value("Write metadata requested"),
    },
    "results": {
        "comment": bool_value("Comment written"),
        "status": bool_value("Status written"),
        "metadata": bool_value("Metadata written"),
    },
    "comment": {
        "id": line_value("Comment ID"),
        "created_at": line_value("Comment created at"),
        "write_result": artifact("Comment write result"),
        "readback": artifact("Comment readback"),
        "gate": artifact("Writeback gate"),
        "approval_boundary": artifact("Approval boundary comment"),
    },
    "status": {
        "value": line_value("Status write value"),
        "readback": artifact("Status readback"),
        "gate": artifact("Status writeback gate"),
        "approval_boundary": artifact("Approval boundary status"),
    },
    "metadata": {
        "key": metadata_key,
        "value": metadata_value,
        "raw_value": metadata_write_value,
        "write_result": artifact("Metadata write result"),
        "readback": artifact("Metadata readback"),
        "before": artifact("Metadata before"),
        "after": artifact("Metadata after"),
        "gate": artifact("Metadata writeback gate"),
        "approval_boundary": artifact("Approval boundary metadata"),
        "approved_by": line_value("Metadata approved by"),
    },
    "approval_boundaries": {
        "comment": artifact("Approval boundary comment"),
        "status": artifact("Approval boundary status"),
        "metadata": artifact("Approval boundary metadata"),
    },
    "readback_artifacts": {
        "comment": artifact("Comment readback"),
        "status": artifact("Status readback"),
        "metadata": artifact("Metadata readback"),
        "feishu": artifact("Feishu readback"),
    },
    "error_log": line_value("Write error log"),
    "remote_write_completed": any(
        value is True for value in [bool_value("Comment written"), bool_value("Status written"), bool_value("Metadata written")]
    ),
}

output_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"writeback_summary_json: {output_path}")
PY
