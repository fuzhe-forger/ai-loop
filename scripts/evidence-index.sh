#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/evidence-index.sh --pattern <glob> [--output <file>]

Generate a local Markdown index for multiple run evidence directories.

Options:
  --pattern  Glob pattern under runs/, for example 'FUZ-554*', required
  --output   Optional file path to write the index
  -h, --help Show this help

This script is local-only. It reads runs/ and never performs remote writes.
HELP
}

pattern=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern)
      pattern="${2:-}"; shift 2 ;;
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

if [[ -z "$pattern" ]]; then
  echo "--pattern is required" >&2
  show_help
  exit 2
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

timing_field() {
  local run_dir="$1"
  local field="$2"
  python3 - <<'PY' "$run_dir" "$field"
import json
import sys
from pathlib import Path
run_dir = Path(sys.argv[1])
field = sys.argv[2]
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
    print("n/a")
else:
    value = latest.get(field)
    print("n/a" if value is None else value)
PY
}

registry_group_summary() {
  local run_dir="$1"
  python3 - <<'PY' "$run_dir"
import json
import sys
from pathlib import Path
run_dir = Path(sys.argv[1])
registry_path = Path("config/evidence-artifacts.json")
if not registry_path.is_file():
    print("registry_missing")
    raise SystemExit
registry = json.loads(registry_path.read_text(encoding="utf-8"))
groups = {}
for item in registry.get("artifacts") or []:
    group = item.get("group") or "ungrouped"
    path = run_dir / item.get("path", "")
    stats = groups.setdefault(group, [0, 0])
    stats[0] += 1
    if path.is_file() and path.stat().st_size > 0:
        stats[1] += 1
print(", ".join(f"{group}:{present}/{total}" for group, (total, present) in sorted(groups.items())))
PY
}

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

index="# Evidence Index: runs/${pattern}

## Metadata

- Generated at: ${generated_at}
- Pattern: runs/${pattern}
- Ordering: shell glob expansion order under runs/ with nullglob enabled

## Runs

| Run | Summary | Stage Report | Comment Draft | Execution Preflight | Closeout | Continuation Gate | Time Contract | within_one_minute | Absolute Error | Elapsed Minutes | Next Estimate | Registry Groups | Time Calibration | Phase I Queue | North Star Board | North Star Report | Phase C/D Board | Phase C/D Report | Memory Quality | Org Policy | Experience Draft | Memory State | Clarification | Clarification Gate | Writeback | Writeback JSON | Share Preflight JSON | Approval Comment | Approval Metadata |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
"

for run_dir in "${run_dirs[@]}"; do
  if [[ ! -d "$run_dir" ]]; then
    continue
  fi
  run_id="$(basename "$run_dir")"
  index+="| ${run_id} | $(has_file "$run_dir/summary.md") | $(has_file "$run_dir/stage-report.md") | $(has_file "$run_dir/multica-comment.md") | $(has_file "$run_dir/execution-preflight.json") | $(has_file "$run_dir/closeout/closeout-summary.md") | $(has_file "$run_dir/continuation-gate.json") | $(has_file "$run_dir/execution-time-contract.json") | $(timing_field "$run_dir" within_one_minute) | $(timing_field "$run_dir" absolute_error_minutes) | $(timing_field "$run_dir" elapsed_minutes) | $(timing_field "$run_dir" recommended_next_estimate_minutes) | $(registry_group_summary "$run_dir") | $(has_file "$run_dir/time-estimation-calibration.json") | $(has_file "$run_dir/phase-i-task-queue.json") | $(has_file "$run_dir/north-star-task-board.json") | $(has_file "$run_dir/north-star-execution-report.md") | $(has_file "$run_dir/phase-cd-task-board.json") | $(has_file "$run_dir/phase-cd-execution-report.md") | $(has_file "$run_dir/memory-quality-report.json") | $(has_file "$run_dir/organization-policy-report.json") | $(has_file "$run_dir/experience-draft.json") | $(has_file "$run_dir/memory-review-state.json") | $(has_file "$run_dir/clarification.md") | $(has_file "$run_dir/clarification-gate.md") | $(has_file "$run_dir/writeback-summary.md") | $(has_file "$run_dir/writeback-summary.json") | $(has_file "$run_dir/share-preflight-summary.json") | $(has_file "$run_dir/approval-boundary-comment.md") | $(has_file "$run_dir/approval-boundary-metadata.md") |
"
done

index+="
## Review Notes

- Prefer runs with summary and stage report for formal review.
- A missing writeback summary is acceptable when no remote write was requested.
- Missing clarification draft/gate is acceptable unless the run state is needs_clarification.
- Remote side effects must be confirmed from stage report or writeback summary.
- Completed remote writes should have matching approval-boundary artifacts.
- Sharing candidates should persist share-preflight-summary.md/json into the run directory.
- Formal runs should include execution-preflight.json, closeout/closeout-summary.md, continuation-gate.json, execution-time-contract.json, time-estimation-calibration.json, phase-i-task-queue.json, north-star-task-board.json, north-star-execution-report.md, phase-cd-task-board.json, phase-cd-execution-report.md, memory-quality-report.json, organization-policy-report.json, and experience-draft.json after local closeout.
- Time Contract columns expose the latest execution-time-contract*.json fields: within_one_minute, absolute_error_minutes, elapsed minutes, and next estimate.
- Memory review-state transitions should persist memory-review-state.md/json when a case lifecycle state changes.
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s' "$index" > "$output"
  echo "index: $output"
else
  printf '%s' "$index"
fi
