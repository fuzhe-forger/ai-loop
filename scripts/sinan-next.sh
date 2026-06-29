#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/sinan-next.sh [options]

Suggest the next local-only Sinan slice from configured task queues. No network,
no external writes, and no task execution.

Options:
  --run-id <run-id>       Optional run id; defaults outputs under runs/<run-id>/
  --tasks <file>          Task queue JSON; can be passed multiple times
  --target-minutes <n>    Max preferred raw estimate minutes, default 30
  --output <file>         Optional Markdown output path
  --json-output <file>    Optional JSON output path
  -h, --help              Show this help

Default task queues are config/phase-cd-next-tasks.json,
config/phase-cd-preflight-memory-state-tasks.json, and config/north-star-tasks.json.
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_id=""
target_minutes="30"
output_file=""
json_output_file=""
task_files=()
explicit_task_files=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --tasks)
      task_files+=("${2:-}"); explicit_task_files=1; shift 2 ;;
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

if [[ ! "$target_minutes" =~ ^[0-9]+$ || "$target_minutes" -le 0 ]]; then
  echo "--target-minutes must be a positive integer" >&2
  exit 2
fi

cd "$ROOT_DIR"

if [[ ${#task_files[@]} -eq 0 ]]; then
  task_files=(
    "config/phase-cd-next-tasks.json"
    "config/phase-cd-preflight-memory-state-tasks.json"
    "config/north-star-tasks.json"
  )
fi

if [[ -n "$run_id" ]]; then
  [[ -n "$output_file" ]] || output_file="runs/$run_id/sinan-next.md"
  [[ -n "$json_output_file" ]] || json_output_file="runs/$run_id/sinan-next.json"
fi

json_report="$(python3 - <<'PY' "$target_minutes" "$run_id" "$explicit_task_files" "${task_files[@]}"
import datetime as dt
import json
import sys
from pathlib import Path

target_minutes = int(sys.argv[1])
run_id = sys.argv[2] or None
explicit_task_files = sys.argv[3] == "1"
task_files = [Path(value) for value in sys.argv[4:]]
external_terms = [
    "feishu", "飞书", "multica", "obsidian", "push", "deploy", "部署", "生产",
    "delete", "删除", "权限", "remote", "写回", "notification", "通知",
]
safe_external_phrases = [
    "local", "local-only", "本地", "preapproved obsidian generated", "本地 run", "local run",
]
priority_rank = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
status_done = {"done", "completed", "closed", "cancelled", "canceled", "blocked"}
status_overrides = {}
queue = []
warnings = []

for board_path in sorted(Path("runs").glob("**/*task-board*.json")):
    try:
        board = json.loads(board_path.read_text(encoding="utf-8"))
    except Exception:
        continue
    generated_at = str(board.get("generated_at") or "")
    for task in board.get("tasks") or []:
        task_id = task.get("id")
        status = task.get("status")
        if not task_id or not status:
            continue
        previous = status_overrides.get(task_id)
        if previous is None or generated_at >= previous.get("generated_at", ""):
            status_overrides[task_id] = {
                "status": str(status).lower(),
                "source": str(board_path),
                "generated_at": generated_at,
            }

def is_local_side_effect(value):
    text = str(value or "").lower()
    if not text:
        return True
    if any(term in text for term in external_terms):
        return any(phrase in text for phrase in safe_external_phrases)
    return True

def estimate(task):
    value = task.get("raw_estimate_minutes", task.get("estimate_minutes", 999))
    try:
        return int(value)
    except Exception:
        return 999

for task_file in task_files:
    if not task_file.is_file():
        warnings.append(f"missing task file: {task_file}")
        continue
    try:
        data = json.loads(task_file.read_text(encoding="utf-8"))
    except Exception as exc:
        warnings.append(f"invalid task file: {task_file}: {exc}")
        continue
    for task in data.get("tasks") or []:
        status_override = status_overrides.get(task.get("id"))
        status = str((status_override or {}).get("status") or task.get("status") or "todo").lower()
        side_effects = task.get("side_effects") or task.get("side_effect_policy") or ""
        local_only = is_local_side_effect(side_effects)
        raw_estimate = estimate(task)
        row = {
            "source": str(task_file),
            "scope": data.get("scope"),
            "id": task.get("id"),
            "title": task.get("title"),
            "phase": task.get("phase"),
            "status": status,
            "status_source": (status_override or {}).get("source"),
            "priority": task.get("priority") or "P9",
            "task_type": task.get("task_type"),
            "raw_estimate_minutes": raw_estimate,
            "acceptance": task.get("acceptance"),
            "verification": task.get("verification"),
            "output_paths": task.get("output_paths") or [],
            "side_effects": side_effects,
            "local_only": local_only,
            "eligible": status not in status_done and local_only and raw_estimate <= target_minutes,
        }
        queue.append(row)

eligible = [item for item in queue if item["eligible"]]
eligible.sort(key=lambda item: (
    priority_rank.get(str(item.get("priority")), 9),
    item.get("raw_estimate_minutes") or 999,
    str(item.get("source")),
    str(item.get("id")),
))
blocked_local = [item for item in queue if not item["local_only"] and str(item.get("status")) not in status_done]
over_target = [item for item in queue if item["local_only"] and str(item.get("status")) not in status_done and item["raw_estimate_minutes"] > target_minutes]
recommendation = eligible[0] if eligible else None
summary_recommendation = None
if recommendation is None and not explicit_task_files:
    for summary_path in sorted(Path("runs").glob("*/summary.md"), key=lambda path: path.stat().st_mtime, reverse=True):
        if run_id and summary_path.parent.name == run_id:
            continue
        try:
            text = summary_path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        marker = "## Next Suggested Slice"
        if marker not in text:
            continue
        lines = []
        for line in text.split(marker, 1)[1].splitlines():
            stripped = line.strip()
            if stripped.startswith("## "):
                break
            if stripped:
                lines.append(stripped.lstrip("- "))
        if not lines:
            continue
        summary_recommendation = {
            "source": str(summary_path),
            "id": "summary-next-slice",
            "title": " ".join(lines[:3]),
            "phase": "derived-from-summary",
            "status": "todo",
            "priority": "P1",
            "task_type": "followup_planning",
            "raw_estimate_minutes": min(target_minutes, 10),
            "acceptance": "Convert this summary recommendation into a concrete local task or stop if it needs approval.",
            "verification": "scripts/sinan-next.sh --run-id <run-id> records the source summary and recommendation.",
            "output_paths": [],
            "side_effects": "local planning artifact only",
            "local_only": True,
            "eligible": True,
        }
        recommendation = summary_recommendation
        break
report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "run_id": run_id,
    "target_minutes": target_minutes,
    "result": "PASSED" if recommendation else "NO_ELIGIBLE_LOCAL_TASK",
    "side_effects": "local-only recommendation; does not execute tasks or touch external systems",
    "task_files": [str(path) for path in task_files],
    "explicit_task_files": bool(explicit_task_files),
    "warnings": warnings,
    "summary": {
        "total_tasks": len(queue),
        "eligible_tasks": len(eligible),
        "blocked_by_side_effects": len(blocked_local),
        "over_target_minutes": len(over_target),
        "status_overrides": len(status_overrides),
        "used_summary_fallback": summary_recommendation is not None,
    },
    "recommendation": recommendation,
    "eligible_preview": eligible[:5],
    "blocked_by_side_effects_preview": blocked_local[:5],
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys

report = json.loads(sys.argv[1])
rec = report.get("recommendation")

def md_cell(value):
    if isinstance(value, list):
        value = "<br>".join(str(item) for item in value)
    return str(value or "").replace("|", "-").replace("<", "&lt;").replace(">", "&gt;")

print("# Sinan Next Slice")
print()
print(f"- Run ID: `{report.get('run_id') or 'n/a'}`")
print(f"- Result: {report['result']}")
print(f"- Target minutes: {report['target_minutes']}")
print(f"- Side effects: {report['side_effects']}")
print(f"- Total / eligible: {report['summary']['total_tasks']} / {report['summary']['eligible_tasks']}")
print(f"- Blocked by side effects: {report['summary']['blocked_by_side_effects']}")
print(f"- Status overrides from run boards: {report['summary']['status_overrides']}")
print(f"- Used summary fallback: {report['summary']['used_summary_fallback']}")
print()
if rec:
    print("## Recommendation")
    print()
    print(f"- Task: `{rec.get('id')}` {rec.get('title')}")
    print(f"- Source: `{rec.get('source')}`")
    if rec.get("status_source"):
        print(f"- Status source: `{rec.get('status_source')}`")
    print(f"- Priority: {rec.get('priority')}")
    print(f"- Estimate: {rec.get('raw_estimate_minutes')} minutes")
    print(f"- Side effects: {rec.get('side_effects')}")
    print(f"- Acceptance: {rec.get('acceptance')}")
    print(f"- Verification: `{rec.get('verification')}`")
    print()
else:
    print("## Recommendation")
    print()
    print("- No eligible local-only task found under the current target minutes.")
    print()
print("## Eligible Preview")
print()
print("| Task | Priority | Minutes | Source | Verification |")
print("|---|---|---:|---|---|")
for item in report.get("eligible_preview") or []:
    print(
        f"| `{md_cell(item.get('id'))}` {md_cell(item.get('title'))} | "
        f"{md_cell(item.get('priority'))} | {md_cell(item.get('raw_estimate_minutes'))} | "
        f"`{md_cell(item.get('source'))}` | `{md_cell(item.get('verification'))}` |"
    )
if report.get("warnings"):
    print()
    print("## Warnings")
    print()
    for warning in report["warnings"]:
        print(f"- {warning}")
PY
)"

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "sinan_next: $output_file"
else
  printf '%s\n' "$markdown_report"
fi

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "sinan_next_json: $json_output_file"
fi

result="$(python3 - <<'PY' "$json_report"
import json
import sys
print(json.loads(sys.argv[1])["result"])
PY
)"
[[ "$result" == "PASSED" ]]
