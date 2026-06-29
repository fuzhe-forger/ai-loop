#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/evidence-checklist.sh --run-id <run-id> [--output <file>]

Generate a local evidence checklist for an ai-loop run directory.

Options:
  --run-id   Run directory name under runs/, required
  --output   Optional file path to write the checklist
  -h, --help Show this help

This script is local-only. It does not read Multica and never performs remote writes.
HELP
}

run_id=""
output=""
task_type="unknown"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --output)
      output="${2:-}"; shift 2 ;;
    --task-type)
      task_type="${2:-}"; shift 2 ;;
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

run_dir="runs/${run_id}"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

has_file() {
  local path="$1"
  if [[ -s "$path" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

required_evidence="$(python3 - <<'PY' "$run_dir" "$task_type"
import json
import sys
from pathlib import Path
run_dir = Path(sys.argv[1])
task_type = sys.argv[2] or "unknown"
registry_path = Path("config/evidence-artifacts.json")
print("| Artifact | Group | Required For | Status | Path |")
print("|---|---|---|---|---|")
if not registry_path.is_file():
    print("| registry_missing | registry | n/a | missing | config/evidence-artifacts.json |")
    raise SystemExit
registry = json.loads(registry_path.read_text(encoding="utf-8"))
selected = []
for item in registry.get("artifacts") or []:
    required_for = item.get("required_for") or []
    if "all" in required_for or task_type in required_for:
        selected.append(item)
for item in selected:
    path = run_dir / item["path"]
    status = "present" if path.is_file() and path.stat().st_size > 0 else "missing"
    print(f"| {item['key']} | {item.get('group', 'ungrouped')} | {','.join(item.get('required_for') or [])} | {status} | {path} |")
PY
)"

timing_summary="$(python3 - <<'PY' "$run_dir"
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
print("| Contract | Trusted | Estimated | Elapsed | Absolute Error | within_one_minute |")
print("|---|---|---|---|---|---|")
if not paths:
    print("| MISSING | false | n/a | n/a | n/a | n/a |")
for path in paths:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        print(f"| {path.name} | invalid_json | n/a | n/a | n/a | n/a |")
        continue
    print(
        f"| {path.name} | {str(data.get('trusted_timing', False)).lower()} | "
        f"{data.get('estimated_minutes', 'n/a')} | {data.get('elapsed_minutes', 'n/a')} | "
        f"{data.get('absolute_error_minutes', 'n/a')} | {data.get('within_one_minute', 'n/a')} |"
    )
PY
)"

checklist="$(cat <<REPORT
# Evidence Checklist: ${run_id}

- Task type: ${task_type}

## Core Artifacts

- summary.md: $(has_file "$run_dir/summary.md")
- stage-report.md: $(has_file "$run_dir/stage-report.md")
- multica-comment.md: $(has_file "$run_dir/multica-comment.md")
- writeback-summary.md: $(has_file "$run_dir/writeback-summary.md")
- writeback-summary.json: $(has_file "$run_dir/writeback-summary.json")
- execution-preflight.md: $(has_file "$run_dir/execution-preflight.md")
- execution-preflight.json: $(has_file "$run_dir/execution-preflight.json")
- closeout/closeout-summary.md: $(has_file "$run_dir/closeout/closeout-summary.md")
- continuation-gate.md: $(has_file "$run_dir/continuation-gate.md")
- continuation-gate.json: $(has_file "$run_dir/continuation-gate.json")
- execution-time-contract.md: $(has_file "$run_dir/execution-time-contract.md")
- execution-time-contract.json: $(has_file "$run_dir/execution-time-contract.json")
- time-estimation-calibration.md: $(has_file "$run_dir/time-estimation-calibration.md")
- time-estimation-calibration.json: $(has_file "$run_dir/time-estimation-calibration.json")
- phase-i-task-queue.md: $(has_file "$run_dir/phase-i-task-queue.md")
- phase-i-task-queue.json: $(has_file "$run_dir/phase-i-task-queue.json")
- north-star-task-board.md: $(has_file "$run_dir/north-star-task-board.md")
- north-star-task-board.json: $(has_file "$run_dir/north-star-task-board.json")
- north-star-execution-report.md: $(has_file "$run_dir/north-star-execution-report.md")
- phase-cd-task-board.md: $(has_file "$run_dir/phase-cd-task-board.md")
- phase-cd-task-board.json: $(has_file "$run_dir/phase-cd-task-board.json")
- phase-cd-execution-report.md: $(has_file "$run_dir/phase-cd-execution-report.md")
- memory-quality-report.md: $(has_file "$run_dir/memory-quality-report.md")
- memory-quality-report.json: $(has_file "$run_dir/memory-quality-report.json")
- organization-policy-report.md: $(has_file "$run_dir/organization-policy-report.md")
- organization-policy-report.json: $(has_file "$run_dir/organization-policy-report.json")
- experience-draft.md: $(has_file "$run_dir/experience-draft.md")
- experience-draft.json: $(has_file "$run_dir/experience-draft.json")
- memory-review-state.md: $(has_file "$run_dir/memory-review-state.md")
- memory-review-state.json: $(has_file "$run_dir/memory-review-state.json")
- phase-cd-next-task-board.md: $(has_file "$run_dir/phase-cd-next-task-board.md")
- phase-cd-next-task-board.json: $(has_file "$run_dir/phase-cd-next-task-board.json")
- phase-cd-next-execution-report.md: $(has_file "$run_dir/phase-cd-next-execution-report.md")
- phase-cd-preflight-memory-state-task-board.md: $(has_file "$run_dir/phase-cd-preflight-memory-state-task-board.md")
- phase-cd-preflight-memory-state-task-board.json: $(has_file "$run_dir/phase-cd-preflight-memory-state-task-board.json")
- phase-cd-preflight-memory-state-execution-report.md: $(has_file "$run_dir/phase-cd-preflight-memory-state-execution-report.md")
- execution-time-contract-preflight-memory-state.md: $(has_file "$run_dir/execution-time-contract-preflight-memory-state.md")
- execution-time-contract-preflight-memory-state.json: $(has_file "$run_dir/execution-time-contract-preflight-memory-state.json")
- share-preflight-summary.md: $(has_file "$run_dir/share-preflight-summary.md")
- share-preflight-summary.json: $(has_file "$run_dir/share-preflight-summary.json")
- approval-boundary-comment.md: $(has_file "$run_dir/approval-boundary-comment.md")
- approval-boundary-status.md: $(has_file "$run_dir/approval-boundary-status.md")
- approval-boundary-metadata.md: $(has_file "$run_dir/approval-boundary-metadata.md")
- clarification.md: $(has_file "$run_dir/clarification.md")
- clarification-gate.md: $(has_file "$run_dir/clarification-gate.md")

## Timing Accuracy

${timing_summary}

## Required Evidence By Task Type

${required_evidence}

## Review Questions

- Is the task goal clear?
- Are local deliverables listed?
- Was verification executed or explicitly skipped with a reason?
- Are remote side effects recorded as none, pending approval, or completed?
- For completed remote writes, is the matching approval-boundary artifact present?
- If this run is a sharing candidate, are share-preflight-summary.md/json persisted?
- Was execution-preflight.md generated before implementation or writeback?
- Was closeout/closeout-summary.md generated after local verification?
- Was continuation-gate.md generated before stopping or summarizing?
- Was execution-time-contract.md generated with estimate, actual elapsed time, and variance?
- Does timing evidence expose absolute_error_minutes and within_one_minute for each execution-time-contract*.json?
- Was time-estimation-calibration.md generated when estimated/actual timing is available?
- Was phase-i-task-queue.md generated when the run should continue beyond a small milestone?
- Was north-star-task-board.md generated when the run maps work back to north-star metrics?
- Was north-star-execution-report.md generated after all north-star tasks were done?
- Was phase-cd-task-board.md generated when Phase C/D work is active?
- Was memory-quality-report.md generated for Phase D memory governance?
- Was organization-policy-report.md generated for Phase C organization readiness?
- Was experience-draft.json generated with review_state for Phase D memory lifecycle?
- Was memory-review-state.json generated when a project-memory case changes review_state?
- Was phase-cd-preflight-memory-state-task-board.json generated for this Phase C/D slice?
- Was execution-time-contract-preflight-memory-state.json generated with estimate and actual elapsed time?
- Is the next action clear?
- If the run is needs_clarification, are clarification.md and clarification-gate.md present and actionable?

## Local Paths

- Run directory: ${run_dir}
- Summary: ${run_dir}/summary.md
- Stage report: ${run_dir}/stage-report.md
- Comment draft: ${run_dir}/multica-comment.md
- Writeback summary JSON: ${run_dir}/writeback-summary.json
- Execution preflight: ${run_dir}/execution-preflight.md
- Execution preflight JSON: ${run_dir}/execution-preflight.json
- Closeout summary: ${run_dir}/closeout/closeout-summary.md
- Continuation gate: ${run_dir}/continuation-gate.md
- Continuation gate JSON: ${run_dir}/continuation-gate.json
- Execution time contract: ${run_dir}/execution-time-contract.md
- Execution time contract JSON: ${run_dir}/execution-time-contract.json
- Time estimation calibration: ${run_dir}/time-estimation-calibration.md
- Time estimation calibration JSON: ${run_dir}/time-estimation-calibration.json
- Phase I task queue: ${run_dir}/phase-i-task-queue.md
- Phase I task queue JSON: ${run_dir}/phase-i-task-queue.json
- North Star task board: ${run_dir}/north-star-task-board.md
- North Star task board JSON: ${run_dir}/north-star-task-board.json
- North Star execution report: ${run_dir}/north-star-execution-report.md
- Phase C/D task board: ${run_dir}/phase-cd-task-board.md
- Phase C/D task board JSON: ${run_dir}/phase-cd-task-board.json
- Phase C/D execution report: ${run_dir}/phase-cd-execution-report.md
- Memory quality report: ${run_dir}/memory-quality-report.md
- Memory quality report JSON: ${run_dir}/memory-quality-report.json
- Organization policy report: ${run_dir}/organization-policy-report.md
- Organization policy report JSON: ${run_dir}/organization-policy-report.json
- Experience draft: ${run_dir}/experience-draft.md
- Experience draft JSON: ${run_dir}/experience-draft.json
- Memory review state: ${run_dir}/memory-review-state.md
- Memory review state JSON: ${run_dir}/memory-review-state.json
- Phase C/D next task board: ${run_dir}/phase-cd-next-task-board.md
- Phase C/D next task board JSON: ${run_dir}/phase-cd-next-task-board.json
- Phase C/D next execution report: ${run_dir}/phase-cd-next-execution-report.md
- Phase C/D preflight memory-state task board: ${run_dir}/phase-cd-preflight-memory-state-task-board.md
- Phase C/D preflight memory-state task board JSON: ${run_dir}/phase-cd-preflight-memory-state-task-board.json
- Phase C/D preflight memory-state execution report: ${run_dir}/phase-cd-preflight-memory-state-execution-report.md
- Execution time contract preflight memory-state: ${run_dir}/execution-time-contract-preflight-memory-state.md
- Execution time contract preflight memory-state JSON: ${run_dir}/execution-time-contract-preflight-memory-state.json
- Share preflight summary: ${run_dir}/share-preflight-summary.md
- Share preflight summary JSON: ${run_dir}/share-preflight-summary.json
- Approval boundary comment: ${run_dir}/approval-boundary-comment.md
- Approval boundary status: ${run_dir}/approval-boundary-status.md
- Approval boundary metadata: ${run_dir}/approval-boundary-metadata.md
- Clarification draft: ${run_dir}/clarification.md
- Clarification gate: ${run_dir}/clarification-gate.md
REPORT
)"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$checklist" > "$output"
  echo "checklist: $output"
else
  printf '%s\n' "$checklist"
fi
