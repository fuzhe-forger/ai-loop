#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/north-star-task-board.sh --run-id <run-id> [options]

Generate a North Star task board from config/north-star-tasks.json.
The board estimates from task quantity first, then applies a small historical calibration correction.

Options:
  --run-id <run-id>       Existing run id, required
  --tasks <file>          Task registry, default config/north-star-tasks.json
  --target-minutes <n>    Planning window minutes, default 30
  --output <file>         Optional Markdown output path
  --json-output <file>    Optional JSON output path
  -h, --help              Show this help

This script is local-only. It reads local evidence and never performs remote writes.
HELP
}

run_id=""
tasks_file="config/north-star-tasks.json"
target_minutes="30"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --tasks)
      tasks_file="${2:-}"; shift 2 ;;
    --target-minutes)
      target_minutes="${2:-}"; shift 2 ;;
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

if [[ -z "$run_id" ]]; then
  echo "--run-id is required" >&2
  show_help
  exit 2
fi
if [[ ! "$target_minutes" =~ ^[0-9]+$ || "$target_minutes" -le 0 ]]; then
  echo "--target-minutes must be a positive integer" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run_dir="runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run not found: $run_dir" >&2
  exit 1
fi
if [[ ! -s "$tasks_file" ]]; then
  echo "Task registry not found: $tasks_file" >&2
  exit 1
fi

json_report="$(python3 - <<'PY' "$run_id" "$tasks_file" "$target_minutes" "$run_dir"
import datetime as dt
import json
import sys
from pathlib import Path

run_id, tasks_file, target_minutes_text, run_dir_text = sys.argv[1:]
target_minutes = int(target_minutes_text)
run_dir = Path(run_dir_text)
tasks_path = Path(tasks_file)
calibration_path = run_dir / "time-estimation-calibration.json"
registry = json.loads(tasks_path.read_text(encoding="utf-8"))
calibration = json.loads(calibration_path.read_text(encoding="utf-8")) if calibration_path.is_file() else {}
buckets = ((calibration.get("summary") or {}).get("task_type_buckets") or {})


def replace_run_id(path):
    return str(path).replace("<run-id>", run_id)


def output_present(path_text):
    path_text = replace_run_id(path_text)
    if path_text.startswith("/mnt/") or path_text.startswith("/"):
        path = Path(path_text)
    else:
        path = Path(path_text)
    return path.is_file() and path.stat().st_size > 0


def doc_contains(path_text, needle):
    path = Path(path_text)
    return path.is_file() and needle in path.read_text(encoding="utf-8", errors="replace")


def bucket_confidence(bucket):
    runs = int((bucket or {}).get("runs") or 0)
    if runs >= 10:
        return "high"
    if runs >= 3:
        return "medium"
    if runs > 0:
        return "low"
    return "none"


def calibrated_estimate(raw, bucket):
    runs = int((bucket or {}).get("runs") or 0)
    recommended = (bucket or {}).get("recommended_next_estimate_minutes")
    if runs >= 3 and isinstance(recommended, (int, float)):
        return max(1, int(round(raw * 0.8 + float(recommended) * 0.2)))
    return int(raw)


def task_status(task):
    task_id = task.get("id")
    outputs = [replace_run_id(path) for path in task.get("output_paths") or []]
    present_outputs = [path for path in outputs if output_present(path)]
    if task_id == "NST-005":
        side_effects = str(task.get("side_effects") or "")
        disallowed = any(word in side_effects.lower() for word in ["feishu write", "multica write", "remote git", "deploy"])
        return ("done", "side effects are local or preapproved Obsidian generated only") if not disallowed else ("blocked", "remote side effect needs approval")
    if task_id == "NST-007":
        done = doc_contains("docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md", "短句 + 证据优先") and doc_contains("docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md", "审批")
        return ("done", "long-loop compression guidance present") if done else ("todo", "compression guidance missing")
    if outputs and len(present_outputs) == len(outputs):
        return "done", "all declared outputs are present"
    if present_outputs:
        return "partial", f"{len(present_outputs)}/{len(outputs)} declared outputs are present"
    return "todo", "declared outputs not present yet"

rows = []
for task in registry.get("tasks") or []:
    raw = int(task.get("raw_estimate_minutes") or 0)
    task_type = task.get("task_type") or "unknown"
    bucket = buckets.get(task_type) or {}
    calibrated = calibrated_estimate(raw, bucket)
    status, status_reason = task_status(task)
    rows.append({
        "id": task.get("id"),
        "metric": task.get("metric"),
        "phase": task.get("phase"),
        "title": task.get("title"),
        "priority": task.get("priority") or "P2",
        "task_type": task_type,
        "status": status,
        "status_reason": status_reason,
        "raw_estimate_minutes": raw,
        "calibrated_estimate_minutes": calibrated,
        "calibration_bucket": task_type,
        "calibration_bucket_runs": int(bucket.get("runs") or 0),
        "calibration_bucket_recommended_minutes": bucket.get("recommended_next_estimate_minutes"),
        "calibration_confidence": bucket_confidence(bucket),
        "acceptance": task.get("acceptance"),
        "verification": task.get("verification"),
        "output_paths": [replace_run_id(path) for path in task.get("output_paths") or []],
        "side_effects": task.get("side_effects"),
    })

status_rank = {"todo": 0, "partial": 1, "blocked": 2, "done": 3}
selected = []
used = 0
for row in sorted(rows, key=lambda item: (status_rank.get(item["status"], 0), item["priority"], item["id"])):
    if row["status"] == "done":
        continue
    if used + row["calibrated_estimate_minutes"] <= target_minutes or not selected:
        selected.append(row)
        used += row["calibrated_estimate_minutes"]

summary = {
    "total_tasks": len(rows),
    "done_tasks": sum(1 for row in rows if row["status"] == "done"),
    "partial_tasks": sum(1 for row in rows if row["status"] == "partial"),
    "todo_tasks": sum(1 for row in rows if row["status"] == "todo"),
    "blocked_tasks": sum(1 for row in rows if row["status"] == "blocked"),
    "raw_open_minutes": sum(row["raw_estimate_minutes"] for row in rows if row["status"] != "done"),
    "calibrated_open_minutes": sum(row["calibrated_estimate_minutes"] for row in rows if row["status"] != "done"),
    "selected_minutes": used,
}
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "run_id": run_id,
    "tasks_file": str(tasks_path),
    "target_minutes": target_minutes,
    "estimation_model": registry.get("estimation_model") or {},
    "summary": summary,
    "tasks": rows,
    "selected_slice": selected,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
summary = report["summary"]
print(f"""# North Star Task Board

## Summary

- Generated at: {report['generated_at']}
- Run ID: {report['run_id']}
- Target minutes: {report['target_minutes']}
- Total tasks: {summary['total_tasks']}
- Done / Partial / Todo / Blocked: {summary['done_tasks']} / {summary['partial_tasks']} / {summary['todo_tasks']} / {summary['blocked_tasks']}
- Raw open minutes: {summary['raw_open_minutes']}
- Calibrated open minutes: {summary['calibrated_open_minutes']}
- Selected slice minutes: {summary['selected_minutes']}
- Estimation rule: {report['estimation_model'].get('rule')}

## Selected Slice

| ID | Status | Priority | Metric | Type | Raw | Calibrated | Confidence | Task | Verification |
|---|---|---|---|---|---:|---:|---|---|---|""")
for row in report["selected_slice"]:
    print(f"| {row['id']} | {row['status']} | {row['priority']} | {row['metric']} | {row['task_type']} | {row['raw_estimate_minutes']} | {row['calibrated_estimate_minutes']} | {row['calibration_confidence']} | {row['title']} | {row['verification']} |")
print("\n## All Tasks\n")
print("| ID | Status | Metric | Phase | Type | Raw | Calibrated | Bucket Runs | Bucket Rec | Confidence | Acceptance | Outputs |")
print("|---|---|---|---|---|---:|---:|---:|---:|---|---|---|")
for row in report["tasks"]:
    outputs = "<br>".join(row.get("output_paths") or [])
    bucket_rec = row['calibration_bucket_recommended_minutes'] if row['calibration_bucket_recommended_minutes'] is not None else ""
    print(f"| {row['id']} | {row['status']} | {row['metric']} | {row['phase']} | {row['task_type']} | {row['raw_estimate_minutes']} | {row['calibrated_estimate_minutes']} | {row['calibration_bucket_runs']} | {bucket_rec} | {row['calibration_confidence']} | {row['acceptance']} | {outputs} |")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "north_star_task_board_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "north_star_task_board_report: $output_file"
fi
if [[ -z "$json_output_file" && -z "$output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi
