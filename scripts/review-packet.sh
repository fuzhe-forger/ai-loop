#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/review-packet.sh --case <case-id> --pattern <glob> [--include-patch-summary <file>] [--output <file>]

Generate a local human-review packet for a case using run evidence directories.

Options:
  --case     Case identifier, for example FUZ-554, required
  --pattern  Glob pattern under runs/, for example 'FUZ-554*', required
  --include-patch-summary
            Optional local patch-summary.md file to reference in the packet
  --output   Optional file path to write the review packet
  -h, --help Show this help

This script is local-only. It reads runs/ and never performs remote writes.
HELP
}

case_id=""
pattern=""
output=""
patch_summary=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      case_id="${2:-}"; shift 2 ;;
    --pattern)
      pattern="${2:-}"; shift 2 ;;
    --include-patch-summary)
      patch_summary="${2:-}"; shift 2 ;;
    --output)
      output="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$case_id" || -z "$pattern" ]]; then
  echo "--case and --pattern are required" >&2
  show_help
  exit 2
fi

if [[ -n "$patch_summary" && ! -s "$patch_summary" ]]; then
  echo "Patch summary file is missing or empty: $patch_summary" >&2
  exit 1
fi

shopt -s nullglob
run_dirs=(runs/$pattern)
shopt -u nullglob

if [[ ${#run_dirs[@]} -eq 0 ]]; then
  echo "No run directories matched: runs/$pattern" >&2
  exit 1
fi

has_file() {
  local path="$1"
  if [[ -s "$path" ]]; then
    printf 'yes'
  else
    printf 'no'
  fi
}

gate_summary() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    printf 'MISSING'
    return
  fi
  python3 - <<'PY' "$path"
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
result = "UNKNOWN"
score = "UNKNOWN"
for line in text.splitlines():
    stripped = line.strip()
    if stripped.startswith("- Result:"):
        result = stripped.split(":", 1)[1].strip()
    elif stripped.startswith("- Score:"):
        score = stripped.split(":", 1)[1].strip()
print(f"{result} {score}" if score != "UNKNOWN" else result)
PY
}

policy_summary() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    printf 'MISSING'
    return
  fi
  python3 - <<'PY' "$path"
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
result = "UNKNOWN"
task_type = "UNKNOWN"
for line in text.splitlines():
    stripped = line.strip()
    if stripped.startswith("- Result:"):
        result = stripped.split(":", 1)[1].strip()
    elif stripped.startswith("- Task type:"):
        task_type = stripped.split(":", 1)[1].strip()
print(f"{result} {task_type}" if task_type != "UNKNOWN" else result)
PY
}

exception_summary() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    printf 'MISSING'
    return
  fi
  python3 - <<'PY' "$path"
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
status = "UNKNOWN"
approved_by = "UNKNOWN"
for line in text.splitlines():
    stripped = line.strip()
    if stripped.startswith("- Status:"):
        status = stripped.split(":", 1)[1].strip()
    elif stripped.startswith("- Approved by:"):
        approved_by = stripped.split(":", 1)[1].strip()
print(f"{status} {approved_by}" if approved_by != "UNKNOWN" else status)
PY
}

time_contract_summary() {
  local run_dir="$1"
  python3 - <<'PY' "$run_dir"
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
paths = []
primary = run_dir / "execution-time-contract.json"
if primary.is_file():
    paths.append(primary)
for path in sorted(run_dir.glob("execution-time-contract-*.json")):
    if path not in paths:
        paths.append(path)
latest = None
for path in paths:
    try:
        latest = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        continue
if latest is None:
    print("MISSING")
else:
    elapsed = latest.get("elapsed_minutes")
    error = latest.get("absolute_error_minutes")
    within = latest.get("within_one_minute")
    next_estimate = latest.get("recommended_next_estimate_minutes") or latest.get("next_estimate_minutes")
    print(f"elapsed={elapsed if elapsed is not None else 'n/a'}, error={error if error is not None else 'n/a'}, within_one_minute={within if within is not None else 'n/a'}, next={next_estimate if next_estimate is not None else 'n/a'}")
PY
}

state_field() {
  local state_json="$1"
  local field="$2"
  if [[ ! -s "$state_json" ]]; then
    printf 'not evaluated'
    return
  fi
  python3 - <<'PY' "$state_json" "$field"
import json
import sys

path, field = sys.argv[1:]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get(field) or "unknown")
PY
}

state_check() {
  local state_json="$1"
  local writeback_summary="$2"
  local field="$3"
  python3 - <<'PY' "$state_json" "$writeback_summary" "$field"
import json
import sys
from pathlib import Path

state_path, writeback_path, field = sys.argv[1:]

def writeback_completed(path: str) -> str:
    item = Path(path)
    if not item.is_file() or item.stat().st_size == 0:
        return "NO"
    text = item.read_text(encoding="utf-8", errors="replace")
    completed = any(marker in text for marker in [
        "Comment written: true",
        "Status written: true",
        "Metadata written: true",
        "Comment ID:",
    ])
    failed = any(marker in text for marker in [
        "Comment written: failed",
        "Status written: failed",
        "Metadata written: failed",
    ])
    return "YES" if completed and not failed else "NO"

if Path(state_path).is_file() and Path(state_path).stat().st_size > 0:
    with open(state_path, encoding="utf-8") as fh:
        data = json.load(fh)
    print(data.get("checks", {}).get(field) or writeback_completed(writeback_path))
else:
    print(writeback_completed(writeback_path))
PY
}

approval_boundary_summary() {
  local run_dir="$1"
  python3 - <<'PY' "$run_dir"
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_path = run_dir / "writeback-summary.json"
boundaries = {}
if summary_path.is_file() and summary_path.stat().st_size > 0:
    try:
        data = json.loads(summary_path.read_text(encoding="utf-8"))
        raw = data.get("approval_boundaries") or {}
        if isinstance(raw, dict):
            boundaries.update({key: value for key, value in raw.items() if value})
    except json.JSONDecodeError:
        pass

fallbacks = {
    "comment": run_dir / "approval-boundary-comment.md",
    "status": run_dir / "approval-boundary-status.md",
    "metadata": run_dir / "approval-boundary-metadata.md",
}

for key, path in fallbacks.items():
    if key not in boundaries and path.is_file() and path.stat().st_size > 0:
        boundaries[key] = str(path)

labels = []
for key in ["comment", "status", "metadata"]:
    value = boundaries.get(key)
    if value and Path(value).is_file():
        labels.append(f"{key}:yes")
    elif value:
        labels.append(f"{key}:missing")
if labels:
    print(",".join(labels))
else:
    print("none")
PY
}

memory_recommendations_summary() {
  local run_dir="$1"
  python3 - <<'PY' "$run_dir"
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
paths = sorted(run_dir.glob("*memory-recommendations.json"))
if not paths:
    preflight = run_dir / "execution-preflight.json"
    if preflight.is_file():
        try:
            data = json.loads(preflight.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            data = {}
        report = (data.get("memory_recommendations") or {}).get("report")
        if report:
            paths.append(Path(report))
paths = [path for path in paths if path.is_file() and path.stat().st_size > 0]
if not paths:
    print("MISSING")
    raise SystemExit(0)
try:
    data = json.loads(paths[-1].read_text(encoding="utf-8"))
except json.JSONDecodeError:
    print("INVALID_JSON")
    raise SystemExit(0)
items = data.get("recommendations") or []
if not items:
    print("none")
else:
    top = items[0]
    print(f"{len(items)} recs; top={top.get('id')}@{top.get('confidence')}")
PY
}

assigned_actor_for() {
  local next_actor="$1"
  case "$next_actor" in
    execution_agent) printf '顾实' ;;
    reviewer) printf '裴衡' ;;
    human) printf '人类' ;;
    scheduler) printf '黑墙' ;;
    tester) printf '测真' ;;
    scribe) printf '简辞' ;;
    not\ evaluated) printf 'not evaluated' ;;
    *) printf '黑墙' ;;
  esac
}

run_count=0
complete_core_count=0
remote_write_count=0
runs_table="| Run | Summary | Stage Report | Comment Draft | Requirement Gate | Design Gate | Clarification Gate | Deliverable Gate | Gate Policy | Gate Exception | Time Contract | Memory Recommendations | Writeback | Approval Boundary | Remote Write Done | Suggested State | Next Actor | Assigned Actor |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
"

for run_dir in "${run_dirs[@]}"; do
  if [[ ! -d "$run_dir" ]]; then
    continue
  fi
  run_count=$((run_count + 1))
  run_id="$(basename "$run_dir")"
  summary="$(has_file "$run_dir/summary.md")"
  stage_report="$(has_file "$run_dir/stage-report.md")"
  comment="$(has_file "$run_dir/multica-comment.md")"
  requirement_gate="$(gate_summary "$run_dir/requirement-gate.md")"
  design_gate="$(gate_summary "$run_dir/design-gate.md")"
  clarification_gate="$(gate_summary "$run_dir/clarification-gate.md")"
  deliverable_gate="$(gate_summary "$run_dir/deliverable-gate.md")"
  gate_policy="$(policy_summary "$run_dir/gate-policy-check.md")"
  gate_exception="$(exception_summary "$run_dir/gate-policy-exception.md")"
  time_contract="$(time_contract_summary "$run_dir")"
  memory_recommendations="$(memory_recommendations_summary "$run_dir")"
  writeback="$(has_file "$run_dir/writeback-summary.md")"
  approval_boundary="$(approval_boundary_summary "$run_dir")"
  remote_write_done="$(state_check "$run_dir/state-evaluation.json" "$run_dir/writeback-summary.md" remote_write_completed)"
  suggested_state="$(state_field "$run_dir/state-evaluation.json" to)"
  next_actor="$(state_field "$run_dir/state-evaluation.json" required_next_actor)"
  assigned_actor="$(assigned_actor_for "$next_actor")"
  if [[ "$summary" == "yes" && "$stage_report" == "yes" && "$comment" == "yes" ]]; then
    complete_core_count=$((complete_core_count + 1))
  fi
  if [[ "$writeback" == "yes" ]]; then
    remote_write_count=$((remote_write_count + 1))
  fi
  runs_table+="| ${run_id} | ${summary} | ${stage_report} | ${comment} | ${requirement_gate} | ${design_gate} | ${clarification_gate} | ${deliverable_gate} | ${gate_policy} | ${gate_exception} | ${time_contract} | ${memory_recommendations} | ${writeback} | ${approval_boundary} | ${remote_write_done} | ${suggested_state} | ${next_actor} | ${assigned_actor} |
"
done

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

patch_section=""
if [[ -n "$patch_summary" ]]; then
  patch_base="$(awk -F': ' '/^- Base: / {print $2; exit}' "$patch_summary")"
  patch_changed_files="$(awk -F': ' '/^- Changed files: / {print $2; exit}' "$patch_summary")"
  patch_tracked_files="$(awk -F': ' '/^- Tracked changed files: / {print $2; exit}' "$patch_summary")"
  patch_untracked_files="$(awk -F': ' '/^- Untracked files: / {print $2; exit}' "$patch_summary")"
  patch_scope_status="$(awk -F': ' '/^- Status: / {print $2; exit}' "$patch_summary")"

  patch_section="## Patch Summary

- Source: ${patch_summary}
- Base: ${patch_base:-unknown}
- Changed files: ${patch_changed_files:-unknown}
- Tracked changed files: ${patch_tracked_files:-unknown}
- Untracked files: ${patch_untracked_files:-unknown}
- Scope check status: ${patch_scope_status:-unknown}

"
fi

packet="# Review Packet: ${case_id}

## Metadata

- Generated at: ${generated_at}
- Pattern: runs/${pattern}
- Ordering: shell glob expansion order under runs/ with nullglob enabled

## Scope

- Case: ${case_id}
- Run pattern: runs/${pattern}
- Run count: ${run_count}
- Runs with core evidence: ${complete_core_count}
- Runs with writeback summary: ${remote_write_count}

## Evidence Index

${runs_table}
${patch_section}
## Review Checklist

- Are the case goal and boundaries clear?
- Do all formal review runs include summary, stage report, and comment draft?
- Are requirement/design/clarification/deliverable gate scores acceptable for the current state?
- Do evaluated runs have a clear suggested state and next actor?
- Does the Time Contract column expose elapsed time, absolute error, within_one_minute, and next estimate?
- Does the Memory Recommendations column show used/ignored project memory before review?
- Does each evaluated run map to a concrete assigned actor?
- If any run is needs_clarification, did clarification gate pass before human handoff?
- Does the remote-write-done column match the intended writeback evidence?
- For completed remote writes, does the approval-boundary column show comment/status/metadata approval evidence?
- Are remote side effects recorded in writeback summaries when they happened?
- If a patch summary is included, does its scope check pass and match the intended change boundary?
- Is there at least one final report or guide that a teammate can read first?
- Is the next action explicit: continue, review, write back, or stop?

## Suggested Review Decision

- Approve for sharing if core evidence is complete and remote side effects have writeback plus approval-boundary evidence.
- Request follow-up if any formal review run lacks summary or stage report.
- Do not infer business completion from dry-run evidence alone.
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s' "$packet" > "$output"
  echo "review_packet: $output"
else
  printf '%s' "$packet"
fi
