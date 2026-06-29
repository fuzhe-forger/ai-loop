#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/phase-i-task-queue.sh --run-id <run-id> [options]

Generate a local Phase I follow-up task queue from timing calibration and preflight evidence.

Options:
  --run-id <run-id>       Existing run id, required
  --target-minutes <n>    Planning window minutes, default 30
  --output <file>         Optional Markdown output path
  --json-output <file>    Optional JSON output path
  -h, --help              Show this help

This script is local-only. It reads run evidence and never performs remote writes.
HELP
}

run_id=""
target_minutes="30"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
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

json_report="$(python3 - <<'PY' "$run_id" "$target_minutes" "$run_dir"
import datetime as dt
import json
import re
import sys
from pathlib import Path

run_id, target_minutes_text, run_dir_text = sys.argv[1:]
target_minutes = int(target_minutes_text)
run_dir = Path(run_dir_text)
calibration_path = run_dir / "time-estimation-calibration.json"
preflight_path = run_dir / "execution-preflight.json"
capabilities_path = Path("config/sinan-capabilities.json")

calibration = json.loads(calibration_path.read_text(encoding="utf-8")) if calibration_path.is_file() else {}
preflight = json.loads(preflight_path.read_text(encoding="utf-8")) if preflight_path.is_file() else {}
capabilities = json.loads(capabilities_path.read_text(encoding="utf-8")) if capabilities_path.is_file() else {"capabilities": []}
summary = calibration.get("summary") or {}
buckets = summary.get("task_type_buckets") or {}
preflight_calibration = ((preflight.get("timebox") or {}).get("calibration") or {})
selected_type = preflight_calibration.get("task_type") or "unknown"
selected_bucket = buckets.get(selected_type) or {}
capability_ids = {item.get("id") for item in capabilities.get("capabilities") or []}

queue = []

def add(item_id, title, task_type, estimate, reason, verification, priority="P1"):
    queue.append({
        "id": item_id,
        "title": title,
        "task_type": task_type,
        "estimate_minutes": int(estimate),
        "priority": priority,
        "reason": reason,
        "verification": verification,
    })

def safe_id(value):
    return re.sub(r"[^A-Za-z0-9]+", "-", str(value).strip()).strip("-").lower() or "unknown"

def queued(item_id):
    return any(item["id"] == item_id for item in queue)

sample_quality = preflight_calibration.get("sample_quality")
if sample_quality in (None, "not_calibrated", "low_sample"):
    add(
        "increase-selected-bucket-samples",
        f"Add one more trusted timing sample for {selected_type}",
        selected_type if selected_type != "unknown" else "documentation",
        max(1, int(preflight_calibration.get("recommended_next_estimate_minutes") or selected_bucket.get("recommended_next_estimate_minutes") or 4)),
        f"selected bucket sample_quality={sample_quality or 'missing'}",
        "execution-time-contract JSON contains within_one_minute and bucket sample count increases",
    )

hit_rate = selected_bucket.get("one_minute_hit_rate")
if isinstance(hit_rate, (int, float)) and hit_rate < 0.5:
    add(
        "tighten-selected-bucket-estimate",
        f"Run a smaller {selected_type} slice to improve <1 minute hit rate",
        selected_type,
        max(1, min(4, int(selected_bucket.get("recommended_next_estimate_minutes") or 4))),
        f"selected bucket one_minute_hit_rate={hit_rate}",
        "time-estimation-calibration shows one_minute_hit_rate and latest absolute_error_minutes",
    )

for bucket_name, bucket in sorted(buckets.items()):
    bucket_id = safe_id(bucket_name)
    bucket_runs = int(bucket.get("runs") or 0)
    bucket_hit_rate = bucket.get("one_minute_hit_rate")
    if bucket_runs < 3 and not queued(f"increase-{bucket_id}-bucket-samples") and bucket_name != selected_type:
        add(
            f"increase-{bucket_id}-bucket-samples",
            f"Add trusted timing samples for {bucket_name}",
            bucket_name,
            max(1, int(bucket.get("recommended_next_estimate_minutes") or 4)),
            f"bucket has only {bucket_runs} trusted timing samples",
            f"time-estimation-calibration shows {bucket_name} sample count increases",
        )
    if isinstance(bucket_hit_rate, (int, float)) and bucket_hit_rate < 0.5 and not queued(f"tighten-{bucket_id}-estimate") and bucket_name != selected_type:
        add(
            f"tighten-{bucket_id}-estimate",
            f"Run a smaller {bucket_name} slice to improve <1 minute hit rate",
            bucket_name,
            max(1, min(4, int(bucket.get("recommended_next_estimate_minutes") or 4))),
            f"bucket one_minute_hit_rate={bucket_hit_rate}",
            f"time-estimation-calibration shows {bucket_name} one_minute_hit_rate and latest absolute_error_minutes",
        )

if "trusted_timing_calibration" in capability_ids:
    add(
        "surface-phase-i-share",
        "Surface Phase I timing quality in share/review docs",
        "documentation",
        4,
        "trusted timing capability is ready; share docs should expose quality fields",
        "verify-toolchain phase i timing docs check passes",
    )

if "evidence_closeout" in capability_ids:
    add(
        "evidence-queue-readback",
        "Wire Phase I queue artifacts into evidence summary and index readback",
        "local_script_patch",
        4,
        "long loops need a visible queue artifact in the same evidence surface reviewers already read",
        "collect-evidence JSON, evidence-checklist, and evidence-index expose phase-i-task-queue artifacts",
    )
    add(
        "capability-registry-queue-output",
        "Register Phase I queue outputs in Sinan capability evidence",
        "documentation",
        3,
        "capability registry should list the queue as part of evidence closeout outputs",
        "sinan-capability-check passes and evidence_closeout outputs include phase-i-task-queue paths",
        priority="P2",
    )

if "token_output_compression" in capability_ids:
    add(
        "reduce-progress-token-noise",
        "Add guidance for compressed progress updates during long loops",
        "documentation",
        3,
        "token_output_compression capability exists; long loops need short progress updates",
        "sinan continuous execution guide mentions compressed progress boundaries",
        priority="P2",
    )

if "obsidian_knowledge_sync" in capability_ids:
    add(
        "obsidian-generated-readback",
        "Sync and read back Obsidian generated outputs without operation logs",
        "local_script_patch",
        4,
        "standing approval covers Obsidian generated sync; each long block still needs readback evidence",
        "obsidian-sync reports generated outputs and operation log count stays unchanged",
    )

add(
    "strict-regression-recheck",
    "Run strict state-gated regression after queue changes",
    "local_script_patch",
    4,
    "queue orchestration changes must keep the full toolchain green before closeout",
    "verify-toolchain --strict --state-gate passes and verification-report.md is refreshed",
)

add(
    "generated-index-readback",
    "Read back generated Obsidian indexes after sync",
    "documentation",
    3,
    "Obsidian sync is only useful if generated run and docs indexes expose the latest evidence",
    "generated loop run page and ai-loop docs index contain the refreshed queue evidence",
    priority="P2",
)

add(
    "next-slice-backlog-refresh",
    "Refresh the next local-only slice backlog after evidence closeout",
    "documentation",
    3,
    "when the 30-minute window still has capacity, keep another verifiable local slice ready",
    "phase-i-task-queue JSON has candidates_seen greater than selected queue length or planned_minutes near target",
    priority="P2",
)

add(
    "final-evidence-sync",
    "Refresh evidence, verify-toolchain, and Obsidian generated",
    "local_script_patch",
    4,
    "every work block must end with evidence/readback",
    "verification report passes and Obsidian generated readback succeeds",
    priority="P0",
)

def file_present(relative_path):
    path = run_dir / relative_path
    return path.is_file() and path.stat().st_size > 0

def repo_text_contains(relative_path, needle):
    path = Path(relative_path)
    return path.is_file() and needle in path.read_text(encoding="utf-8", errors="replace")

def evidence_summary_has_queue():
    path = run_dir / "evidence-summary.json"
    if not path.is_file():
        return False
    try:
        artifacts = (json.loads(path.read_text(encoding="utf-8")).get("artifacts") or {})
    except json.JSONDecodeError:
        return False
    return all((artifacts.get(key) or {}).get("present") for key in ("phase_i_task_queue", "phase_i_task_queue_json"))

def capability_registry_has_queue():
    for capability in capabilities.get("capabilities") or []:
        if capability.get("id") != "evidence_closeout":
            continue
        return (
            "scripts/phase-i-task-queue.sh" in (capability.get("entrypoints") or [])
            and "runs/<run-id>/phase-i-task-queue.md" in (capability.get("evidence_outputs") or [])
            and "runs/<run-id>/phase-i-task-queue.json" in (capability.get("evidence_outputs") or [])
            and "scripts/phase-i-task-queue.sh --run-id <run-id> --target-minutes 30" in (capability.get("verification") or [])
        )
    return False

def obsidian_run_has_queue():
    path = Path("/mnt/d/JAVA/knowledge/tiandao/99-generated/loop/runs") / f"{run_id}.md"
    return path.is_file() and "phase-i-task-queue.sh" in path.read_text(encoding="utf-8", errors="replace")

def status_for(item):
    item_id = item["id"]
    if item_id in {"final-evidence-sync", "generated-index-readback", "obsidian-generated-readback", "strict-regression-recheck", "next-slice-backlog-refresh"}:
        return "todo", "recurring end-of-block work"
    if item_id == "evidence-queue-readback":
        done = evidence_summary_has_queue() and file_present("evidence-checklist.md") and file_present("evidence-index.md")
        return ("done", "queue artifacts visible in evidence surfaces") if done else ("todo", "queue artifacts not yet visible in all evidence surfaces")
    if item_id == "surface-phase-i-share":
        done = repo_text_contains("docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md", "Phase I") and repo_text_contains("docs/ai-work-orchestration/share/time-estimation-calibration-guide.md", "within_one_minute")
        return ("done", "Phase I timing fields visible in share docs") if done else ("todo", "share docs do not expose Phase I timing fields")
    if item_id == "reduce-progress-token-noise":
        done = repo_text_contains("docs/ai-work-orchestration/share/sinan-continuous-execution-guide.md", "长循环进展压缩")
        return ("done", "long-loop compression guidance is documented") if done else ("todo", "compression guidance missing")
    if item_id == "capability-registry-queue-output":
        done = capability_registry_has_queue()
        return ("done", "capability registry exposes queue entrypoint and outputs") if done else ("todo", "capability registry does not expose queue entrypoint and outputs")
    if item_id.startswith("increase-"):
        bucket = buckets.get(item["task_type"]) or {}
        sample_count = int(bucket.get("runs") or 0)
        done = sample_count >= 3
        return ("done", f"bucket has {sample_count} samples") if done else ("todo", f"bucket has only {sample_count} samples")
    if item_id.startswith("tighten-"):
        bucket = buckets.get(item["task_type"]) or {}
        bucket_hit_rate = bucket.get("one_minute_hit_rate")
        done = isinstance(bucket_hit_rate, (int, float)) and bucket_hit_rate >= 0.5
        return ("done", f"one_minute_hit_rate={bucket_hit_rate}") if done else ("todo", f"one_minute_hit_rate={bucket_hit_rate}")
    return "todo", "no completion rule registered"

for item in queue:
    item["status"], item["status_reason"] = status_for(item)

selected = []
used = 0
status_rank = {"todo": 0, "done": 1}
for item in sorted(queue, key=lambda row: (status_rank.get(row.get("status"), 0), row["priority"], row["id"])):
    if used + item["estimate_minutes"] <= target_minutes or not selected:
        selected.append(item)
        used += item["estimate_minutes"]
open_minutes = sum(item["estimate_minutes"] for item in selected if item.get("status") != "done")
done_minutes = sum(item["estimate_minutes"] for item in selected if item.get("status") == "done")
open_candidates = sum(1 for item in queue if item.get("status") != "done")

report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "run_id": run_id,
    "target_minutes": target_minutes,
    "selected_task_type": selected_type,
    "selected_bucket": selected_bucket,
    "preflight_sample_quality": sample_quality,
    "planned_minutes": used,
    "open_minutes": open_minutes,
    "done_minutes": done_minutes,
    "queue": selected,
    "candidates_seen": len(queue),
    "candidate_ids": [item["id"] for item in queue],
    "open_candidates": open_candidates,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# Phase I Task Queue

## Summary

- Generated at: {report['generated_at']}
- Run ID: {report['run_id']}
- Target minutes: {report['target_minutes']}
- Planned minutes: {report['planned_minutes']}
- Open minutes: {report['open_minutes']}
- Done minutes: {report['done_minutes']}
- Selected task type: {report['selected_task_type']}
- Preflight sample quality: {report.get('preflight_sample_quality') or 'not-measured'}
- Candidates seen: {report['candidates_seen']}
- Open candidates: {report['open_candidates']}

## Queue

| Status | Priority | ID | Task Type | Estimate | Task | Status Reason | Verification |
|---|---|---|---|---:|---|---|---|
""")
for item in report["queue"]:
    print(f"| {item['status']} | {item['priority']} | {item['id']} | {item['task_type']} | {item['estimate_minutes']} | {item['title']} | {item['status_reason']} | {item['verification']} |")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "phase_i_task_queue_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "phase_i_task_queue_report: $output_file"
fi
if [[ -z "$json_output_file" && -z "$output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi
