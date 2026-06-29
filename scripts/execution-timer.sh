#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/execution-timer.sh <start|close> --run-id <run-id> --name <slice-name> [options]

Create and close paired execution timer markers inside a run directory.
Use this wrapper instead of ad-hoc /tmp start markers so stale timestamps cannot be reused silently.

Commands:
  start                 Write runs/<run-id>/timers/<name>.start.json and optional start contract
  close                 Read the paired marker and generate execution-time-contract artifacts

Options:
  --run-id <run-id>     Run directory under runs/, required
  --name <name>         Timer name, required; use kebab-case
  --estimate-minutes <n|a-b>
                         Estimate minutes or range, required for start; close reads the start marker by default
  --basis <text>        Estimate basis, optional
  --task-type <type>    Task type for calibration buckets, optional
  --stop-condition <text>
                         Stop/continue condition, optional
  --max-age-minutes <n> Maximum marker age accepted on close, default 180
  --output <file>       Optional Markdown output path for close/start contract
  --json-output <file>  Optional JSON output path for close/start contract
  -h, --help            Show this help

This script is local-only. It writes run-local timing artifacts and never performs remote writes.
HELP
}

command="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi
run_id=""
name=""
estimate_minutes=""
basis=""
task_type=""
stop_condition=""
max_age_minutes="180"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --name)
      name="${2:-}"; shift 2 ;;
    --estimate-minutes)
      estimate_minutes="${2:-}"; shift 2 ;;
    --basis)
      basis="${2:-}"; shift 2 ;;
    --task-type)
      task_type="${2:-}"; shift 2 ;;
    --stop-condition)
      stop_condition="${2:-}"; shift 2 ;;
    --max-age-minutes)
      max_age_minutes="${2:-}"; shift 2 ;;
    --output)
      output_file="${2:-}"; shift 2 ;;
    --json-output)
      json_output_file="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

case "$command" in
  start|close) ;;
  *)
    echo "Command must be start or close" >&2
    show_help
    exit 2 ;;
esac
if [[ -z "$run_id" || -z "$name" ]]; then
  echo "--run-id and --name are required" >&2
  show_help
  exit 2
fi
if [[ "$command" == "start" && -z "$estimate_minutes" ]]; then
  echo "--estimate-minutes is required for start" >&2
  show_help
  exit 2
fi
if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "--name must contain only letters, numbers, dot, underscore, or hyphen" >&2
  exit 2
fi
if [[ ! "$max_age_minutes" =~ ^[0-9]+$ || "$max_age_minutes" -le 0 ]]; then
  echo "--max-age-minutes must be a positive integer" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
run_dir="runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi
mkdir -p "$run_dir/timers"
marker_path="$run_dir/timers/${name}.start.json"
now_iso="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [[ "$command" == "start" ]]; then
  if [[ -s "$marker_path" ]]; then
    echo "Timer marker already exists: $marker_path" >&2
    echo "Close it first or choose another --name." >&2
    exit 1
  fi
  python3 - <<'PY' "$marker_path" "$run_id" "$name" "$estimate_minutes" "$basis" "$task_type" "$stop_condition" "$now_iso"
import json
import sys
from pathlib import Path
marker, run_id, name, estimate, basis, task_type, stop_condition, now = sys.argv[1:]
data = {
    "schema_version": 1,
    "run_id": run_id,
    "name": name,
    "estimate_minutes": estimate,
    "basis": basis,
    "task_type": task_type or None,
    "stop_condition": stop_condition,
    "started_at": now,
    "state": "started",
}
Path(marker).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
  if [[ -n "$output_file" || -n "$json_output_file" ]]; then
    ./scripts/execution-time-contract.sh \
      --estimate-minutes "$estimate_minutes" \
      --basis "$basis" \
      --task-type "$task_type" \
      --started-at "$now_iso" \
      --stop-condition "$stop_condition" \
      ${output_file:+--output "$output_file"} \
      ${json_output_file:+--json-output "$json_output_file"}
  fi
  echo "timer_marker: $marker_path"
  exit 0
fi

if [[ ! -s "$marker_path" ]]; then
  echo "Timer marker not found: $marker_path" >&2
  exit 1
fi

marker_values="$(python3 - <<'PY' "$marker_path"
import json
import sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if data.get("state") != "started":
    raise SystemExit(f"Timer marker is not open: state={data.get('state')}")
print(data["started_at"])
print(data["estimate_minutes"])
print(data.get("basis") or "")
print(data.get("task_type") or "")
print(data.get("stop_condition") or "")
PY
)"
started_at="$(printf '%s\n' "$marker_values" | sed -n '1p')"
marker_estimate_minutes="$(printf '%s\n' "$marker_values" | sed -n '2p')"
marker_basis="$(printf '%s\n' "$marker_values" | sed -n '3p')"
marker_task_type="$(printf '%s\n' "$marker_values" | sed -n '4p')"
marker_stop_condition="$(printf '%s\n' "$marker_values" | sed -n '5p')"
if [[ -z "$estimate_minutes" ]]; then
  estimate_minutes="$marker_estimate_minutes"
elif [[ "$estimate_minutes" != "$marker_estimate_minutes" ]]; then
  echo "Close estimate does not match marker: close=$estimate_minutes marker=$marker_estimate_minutes" >&2
  exit 1
fi
if [[ -z "$basis" ]]; then
  basis="$marker_basis"
fi
if [[ -z "$task_type" ]]; then
  task_type="$marker_task_type"
fi
if [[ -z "$stop_condition" ]]; then
  stop_condition="$marker_stop_condition"
fi
python3 - <<'PY' "$started_at" "$now_iso" "$max_age_minutes"
import datetime as dt
import sys
started_text, now_text, max_age_text = sys.argv[1:]
started = dt.datetime.fromisoformat(started_text.replace("Z", "+00:00"))
now = dt.datetime.fromisoformat(now_text.replace("Z", "+00:00"))
age_seconds = int((now - started).total_seconds())
if age_seconds < 0:
    raise SystemExit("Timer marker starts in the future")
max_age_seconds = int(max_age_text) * 60
if age_seconds > max_age_seconds:
    raise SystemExit(f"Timer marker is stale: age_seconds={age_seconds}, max_age_seconds={max_age_seconds}")
PY

if [[ -z "$output_file" ]]; then
  output_file="$run_dir/execution-time-contract-${name}.md"
fi
if [[ -z "$json_output_file" ]]; then
  json_output_file="$run_dir/execution-time-contract-${name}.json"
fi
./scripts/execution-time-contract.sh \
  --estimate-minutes "$estimate_minutes" \
  --basis "$basis" \
  --task-type "$task_type" \
  --started-at "$started_at" \
  --completed-at "$now_iso" \
  --stop-condition "$stop_condition" \
  --output "$output_file" \
  --json-output "$json_output_file"
python3 - <<'PY' "$marker_path" "$now_iso" "$json_output_file"
import json
import sys
from pathlib import Path
marker_path, completed_at, contract_path = sys.argv[1:]
path = Path(marker_path)
data = json.loads(path.read_text(encoding="utf-8"))
data["state"] = "closed"
data["completed_at"] = completed_at
data["contract_json"] = contract_path
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
echo "timer_marker_closed: $marker_path"
