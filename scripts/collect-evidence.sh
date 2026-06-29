#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/collect-evidence.sh --issue <issue-id> --run-id <run-id> [--output <file>] [--markdown <file>]

Collect a structured local evidence summary for one ai-loop run.

Options:
  --issue     Issue identifier, for example FUZ-554, required
  --run-id    Run directory name under runs/, required
  --output    Optional JSON output path
  --markdown  Optional Markdown output path
  -h, --help  Show this help

This script is local-only. It reads runs/ and never performs remote writes.
HELP
}

issue=""
run_id=""
output=""
markdown=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --output)
      output="${2:-}"; shift 2 ;;
    --markdown)
      markdown="${2:-}"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      show_help
      exit 2 ;;
  esac
done

if [[ -z "$issue" || -z "$run_id" ]]; then
  echo "--issue and --run-id are required" >&2
  show_help
  exit 2
fi

run_dir="runs/${run_id}"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

file_status() {
  local path="$1"
  if [[ -s "$path" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

json_bool() {
  local path="$1"
  if [[ -s "$path" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

gate_field() {
  local path="$1"
  local field="$2"
  if [[ ! -s "$path" ]]; then
    printf 'MISSING'
    return
  fi
  case "$field" in
    result)
      awk -F': ' '/^- Result: / {print $2; found=1; exit} END {if (!found) print "UNKNOWN"}' "$path" ;;
    score)
      awk -F': ' '/^- Score: / {print $2; found=1; exit} END {if (!found) print "UNKNOWN"}' "$path" ;;
    failures)
      awk -F': ' '/^- Required failures: / {print $2; found=1; exit} END {if (!found) print "UNKNOWN"}' "$path" ;;
    *)
      printf 'UNKNOWN' ;;
  esac
}

summary_path="$run_dir/summary.md"
stage_report_path="$run_dir/stage-report.md"
comment_path="$run_dir/multica-comment.md"
patch_summary_path="$run_dir/patch-summary.md"
review_packet_path="$run_dir/review-packet.md"
verification_report_path="$run_dir/verification-report.md"
execution_preflight_path="$run_dir/execution-preflight.md"
execution_preflight_json_path="$run_dir/execution-preflight.json"
closeout_summary_path="$run_dir/closeout/closeout-summary.md"
continuation_gate_path="$run_dir/continuation-gate.md"
continuation_gate_json_path="$run_dir/continuation-gate.json"
execution_time_contract_path="$run_dir/execution-time-contract.md"
execution_time_contract_json_path="$run_dir/execution-time-contract.json"
time_calibration_path="$run_dir/time-estimation-calibration.md"
time_calibration_json_path="$run_dir/time-estimation-calibration.json"
phase_i_task_queue_path="$run_dir/phase-i-task-queue.md"
phase_i_task_queue_json_path="$run_dir/phase-i-task-queue.json"
north_star_task_board_path="$run_dir/north-star-task-board.md"
north_star_task_board_json_path="$run_dir/north-star-task-board.json"
north_star_execution_report_path="$run_dir/north-star-execution-report.md"
phase_cd_task_board_path="$run_dir/phase-cd-task-board.md"
phase_cd_task_board_json_path="$run_dir/phase-cd-task-board.json"
phase_cd_execution_report_path="$run_dir/phase-cd-execution-report.md"
memory_quality_report_path="$run_dir/memory-quality-report.md"
memory_quality_report_json_path="$run_dir/memory-quality-report.json"
organization_policy_report_path="$run_dir/organization-policy-report.md"
organization_policy_report_json_path="$run_dir/organization-policy-report.json"
experience_draft_path="$run_dir/experience-draft.md"
experience_draft_json_path="$run_dir/experience-draft.json"
memory_review_state_path="$run_dir/memory-review-state.md"
memory_review_state_json_path="$run_dir/memory-review-state.json"
phase_cd_next_task_board_path="$run_dir/phase-cd-next-task-board.md"
phase_cd_next_task_board_json_path="$run_dir/phase-cd-next-task-board.json"
phase_cd_next_execution_report_path="$run_dir/phase-cd-next-execution-report.md"
phase_cd_preflight_memory_state_task_board_path="$run_dir/phase-cd-preflight-memory-state-task-board.md"
phase_cd_preflight_memory_state_task_board_json_path="$run_dir/phase-cd-preflight-memory-state-task-board.json"
phase_cd_preflight_memory_state_execution_report_path="$run_dir/phase-cd-preflight-memory-state-execution-report.md"
execution_time_contract_preflight_memory_state_path="$run_dir/execution-time-contract-preflight-memory-state.md"
execution_time_contract_preflight_memory_state_json_path="$run_dir/execution-time-contract-preflight-memory-state.json"
execution_time_contract_timer_guard_path="$run_dir/execution-time-contract-timer-guard.md"
execution_time_contract_timer_guard_json_path="$run_dir/execution-time-contract-timer-guard.json"
timer_guard_marker_path="$run_dir/timers/timer-guard.start.json"
sinan_fitness_check_path="$run_dir/sinan-fitness-check.md"
sinan_fitness_check_json_path="$run_dir/sinan-fitness-check.json"
intent_ambiguity_gate_path="$run_dir/intent-ambiguity-gate.md"
intent_ambiguity_gate_json_path="$run_dir/intent-ambiguity-gate.json"
share_preflight_summary_path="$run_dir/share-preflight-summary.md"
share_preflight_summary_json_path="$run_dir/share-preflight-summary.json"
writeback_path="$run_dir/writeback-summary.md"
writeback_json_path="$run_dir/writeback-summary.json"
approval_comment_path="$run_dir/approval-boundary-comment.md"
approval_status_path="$run_dir/approval-boundary-status.md"
approval_metadata_path="$run_dir/approval-boundary-metadata.md"
requirement_gate_path="$run_dir/requirement-gate.md"
design_gate_path="$run_dir/design-gate.md"
clarification_path="$run_dir/clarification.md"
clarification_gate_path="$run_dir/clarification-gate.md"
deliverable_gate_path="$run_dir/deliverable-gate.md"
gate_policy_path="$run_dir/gate-policy-check.md"
gate_policy_json_path="$run_dir/gate-policy-check.json"
gate_policy_exception_path="$run_dir/gate-policy-exception.md"
gate_policy_exception_json_path="$run_dir/gate-policy-exception.json"
run_json_path="$run_dir/run.json"

core_status="PASSED"
for required in "$summary_path" "$stage_report_path" "$comment_path"; do
  if [[ ! -s "$required" ]]; then
    core_status="FAILED"
  fi
done

run_status="unknown"
run_mode="unknown"
if [[ -s "$run_json_path" ]]; then
  run_status="$(python3 - <<'PY' "$run_json_path"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('status') or 'unknown')
PY
)"
  run_mode="$(python3 - <<'PY' "$run_json_path"
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get('mode') or 'run')
PY
)"
fi

strict_status="UNKNOWN"
if [[ -s "$verification_report_path" ]]; then
  if grep -qi "strict evidence gate passed" "$verification_report_path" || rg "Strict Evidence Gate" -A 10 "$verification_report_path" | rg -q "\| .* \| PASSED \|"; then
    strict_status="PASSED"
  elif grep -qi "strict evidence gate failed" "$verification_report_path" || rg "Strict Evidence Gate" -A 10 "$verification_report_path" | rg -q "\| .* \| FAILED \|"; then
    strict_status="FAILED"
  fi
fi

json_content="$(python3 - <<'PY' \
  "$issue" "$run_id" "$run_dir" "$run_status" "$run_mode" "$core_status" "$strict_status" \
  "$summary_path" "$stage_report_path" "$comment_path" "$patch_summary_path" "$review_packet_path" "$verification_report_path" "$execution_preflight_path" "$execution_preflight_json_path" "$closeout_summary_path" "$continuation_gate_path" "$continuation_gate_json_path" "$execution_time_contract_path" "$execution_time_contract_json_path" "$time_calibration_path" "$time_calibration_json_path" "$phase_i_task_queue_path" "$phase_i_task_queue_json_path" "$north_star_task_board_path" "$north_star_task_board_json_path" "$north_star_execution_report_path" "$phase_cd_task_board_path" "$phase_cd_task_board_json_path" "$phase_cd_execution_report_path" "$memory_quality_report_path" "$memory_quality_report_json_path" "$organization_policy_report_path" "$organization_policy_report_json_path" "$experience_draft_path" "$experience_draft_json_path" "$memory_review_state_path" "$memory_review_state_json_path" "$phase_cd_next_task_board_path" "$phase_cd_next_task_board_json_path" "$phase_cd_next_execution_report_path" "$phase_cd_preflight_memory_state_task_board_path" "$phase_cd_preflight_memory_state_task_board_json_path" "$phase_cd_preflight_memory_state_execution_report_path" "$execution_time_contract_preflight_memory_state_path" "$execution_time_contract_preflight_memory_state_json_path" "$execution_time_contract_timer_guard_path" "$execution_time_contract_timer_guard_json_path" "$timer_guard_marker_path" "$sinan_fitness_check_path" "$sinan_fitness_check_json_path" "$intent_ambiguity_gate_path" "$intent_ambiguity_gate_json_path" "$share_preflight_summary_path" "$share_preflight_summary_json_path" "$writeback_path" "$writeback_json_path" "$approval_comment_path" "$approval_status_path" "$approval_metadata_path" "$requirement_gate_path" "$design_gate_path" "$clarification_path" "$clarification_gate_path" "$deliverable_gate_path" "$gate_policy_path" "$gate_policy_json_path" "$gate_policy_exception_path" "$gate_policy_exception_json_path" "$run_json_path"
import json, sys
(
    issue, run_id, run_dir, run_status, run_mode, core_status, strict_status,
    summary_path, stage_report_path, comment_path, patch_summary_path,
    review_packet_path, verification_report_path, execution_preflight_path, execution_preflight_json_path, closeout_summary_path, continuation_gate_path, continuation_gate_json_path, execution_time_contract_path, execution_time_contract_json_path, time_calibration_path, time_calibration_json_path, phase_i_task_queue_path, phase_i_task_queue_json_path, north_star_task_board_path, north_star_task_board_json_path, north_star_execution_report_path, phase_cd_task_board_path, phase_cd_task_board_json_path, phase_cd_execution_report_path, memory_quality_report_path, memory_quality_report_json_path, organization_policy_report_path, organization_policy_report_json_path, experience_draft_path, experience_draft_json_path, memory_review_state_path, memory_review_state_json_path, phase_cd_next_task_board_path, phase_cd_next_task_board_json_path, phase_cd_next_execution_report_path, phase_cd_preflight_memory_state_task_board_path, phase_cd_preflight_memory_state_task_board_json_path, phase_cd_preflight_memory_state_execution_report_path, execution_time_contract_preflight_memory_state_path, execution_time_contract_preflight_memory_state_json_path, execution_time_contract_timer_guard_path, execution_time_contract_timer_guard_json_path, timer_guard_marker_path, sinan_fitness_check_path, sinan_fitness_check_json_path, intent_ambiguity_gate_path, intent_ambiguity_gate_json_path, share_preflight_summary_path, share_preflight_summary_json_path, writeback_path, writeback_json_path, approval_comment_path, approval_status_path, approval_metadata_path, requirement_gate_path, design_gate_path,
    clarification_path, clarification_gate_path, deliverable_gate_path, gate_policy_path, gate_policy_json_path, gate_policy_exception_path, gate_policy_exception_json_path, run_json_path,
) = sys.argv[1:]
from pathlib import Path

registry_path = Path("config/evidence-artifacts.json")

def present(path: str) -> bool:
    return Path(path).is_file() and Path(path).stat().st_size > 0


def registry_view(run_dir: str) -> dict:
    if not registry_path.is_file():
        return {"schema_version": None, "source": str(registry_path), "present": False, "groups": {}, "artifacts": {}}
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    artifacts = {}
    groups = {}
    for item in registry.get("artifacts") or []:
        key = item.get("key")
        rel_path = item.get("path")
        group = item.get("group") or "ungrouped"
        path = str(Path(run_dir) / rel_path) if rel_path else run_dir
        entry = {
            "path": path,
            "relative_path": rel_path,
            "group": group,
            "required_for": item.get("required_for") or [],
            "present": present(path),
        }
        artifacts[key] = entry
        groups.setdefault(group, {"total": 0, "present": 0, "missing": 0, "keys": []})
        groups[group]["total"] += 1
        groups[group]["present" if entry["present"] else "missing"] += 1
        groups[group]["keys"].append(key)
    return {
        "schema_version": registry.get("schema_version"),
        "source": str(registry_path),
        "present": True,
        "groups": groups,
        "artifacts": artifacts,
    }


def timing_accuracy(path: str) -> dict:
    artifact = {
        "path": path,
        "present": present(path),
        "trusted_timing": False,
        "estimated_minutes": None,
        "elapsed_seconds": None,
        "elapsed_minutes": None,
        "absolute_error_minutes": None,
        "within_one_minute": None,
        "variance_note": None,
        "recommended_next_estimate_minutes": None,
        "task_type": None,
    }
    if not artifact["present"]:
        return artifact
    try:
        raw = json.loads(Path(path).read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        artifact["variance_note"] = "invalid_json"
        return artifact
    for key in [
        "trusted_timing",
        "estimated_minutes",
        "elapsed_seconds",
        "elapsed_minutes",
        "absolute_error_minutes",
        "within_one_minute",
        "variance_note",
        "recommended_next_estimate_minutes",
        "task_type",
    ]:
        artifact[key] = raw.get(key)
    artifact["trusted_timing"] = raw.get("trusted_timing") is True or raw.get("timing_source") == "timestamp" or bool(raw.get("started_at") and raw.get("completed_at"))
    return artifact


def timing_accuracy_summary(run_dir: str, primary_path: str) -> dict:
    candidates = []
    primary = Path(primary_path)
    if primary.is_file():
        candidates.append(primary)
    for path in sorted(Path(run_dir).glob("execution-time-contract-*.json")):
        if path not in candidates:
            candidates.append(path)
    artifacts = [timing_accuracy(str(path)) for path in candidates]
    present_artifacts = [item for item in artifacts if item.get("present")]
    measured = [item for item in present_artifacts if item.get("trusted_timing")]
    within = [item for item in measured if item.get("within_one_minute") is True]
    misses = [item for item in measured if item.get("within_one_minute") is False]
    return {
        "artifacts": artifacts,
        "artifact_count": len(present_artifacts),
        "trusted_measured_count": len(measured),
        "within_one_minute_count": len(within),
        "one_minute_miss_count": len(misses),
        "latest": present_artifacts[-1] if present_artifacts else None,
    }


def gate_result(path: str) -> dict:
    data = {
        "path": path,
        "present": present(path),
        "result": "MISSING",
        "score": None,
        "required_failures": None,
    }
    if not data["present"]:
        return data
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- Result:"):
            data["result"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("- Score:"):
            raw = stripped.split(":", 1)[1].strip().split("/", 1)[0]
            try:
                data["score"] = int(raw)
            except ValueError:
                data["score"] = None
        elif stripped.startswith("- Required failures:"):
            raw = stripped.split(":", 1)[1].strip()
            try:
                data["required_failures"] = int(raw)
            except ValueError:
                data["required_failures"] = None
    return data


gate_results = {
    "requirement": gate_result(requirement_gate_path),
    "design": gate_result(design_gate_path),
    "clarification": gate_result(clarification_gate_path),
    "deliverable": gate_result(deliverable_gate_path),
}
timing_accuracy_data = timing_accuracy_summary(run_dir, execution_time_contract_json_path)
registry_data = registry_view(run_dir)

data = {
    "schema_version": 1,
    "issue": issue,
    "run_id": run_id,
    "run_dir": run_dir,
    "run": {
        "status": run_status,
        "mode": run_mode,
        "run_json": run_json_path,
        "run_json_present": present(run_json_path),
    },
    "checks": {
        "core_evidence": core_status,
        "strict_gate": strict_status,
        "gate_results": gate_results,
        "gate_policy_check": "PRESENT" if present(gate_policy_path) else "MISSING",
        "gate_policy_exception": "PRESENT" if present(gate_policy_exception_path) else "MISSING",
        "timing_accuracy": timing_accuracy_data,
    },
    "artifacts": {
        "summary": {"path": summary_path, "present": present(summary_path)},
        "stage_report": {"path": stage_report_path, "present": present(stage_report_path)},
        "comment_draft": {"path": comment_path, "present": present(comment_path)},
        "patch_summary": {"path": patch_summary_path, "present": present(patch_summary_path)},
        "review_packet": {"path": review_packet_path, "present": present(review_packet_path)},
        "verification_report": {"path": verification_report_path, "present": present(verification_report_path)},
        "execution_preflight": {"path": execution_preflight_path, "present": present(execution_preflight_path)},
        "execution_preflight_json": {"path": execution_preflight_json_path, "present": present(execution_preflight_json_path)},
        "closeout_summary": {"path": closeout_summary_path, "present": present(closeout_summary_path)},
        "continuation_gate": {"path": continuation_gate_path, "present": present(continuation_gate_path)},
        "continuation_gate_json": {"path": continuation_gate_json_path, "present": present(continuation_gate_json_path)},
        "execution_time_contract": {"path": execution_time_contract_path, "present": present(execution_time_contract_path)},
        "execution_time_contract_json": {"path": execution_time_contract_json_path, "present": present(execution_time_contract_json_path)},
        "time_estimation_calibration": {"path": time_calibration_path, "present": present(time_calibration_path)},
        "time_estimation_calibration_json": {"path": time_calibration_json_path, "present": present(time_calibration_json_path)},
        "phase_i_task_queue": {"path": phase_i_task_queue_path, "present": present(phase_i_task_queue_path)},
        "phase_i_task_queue_json": {"path": phase_i_task_queue_json_path, "present": present(phase_i_task_queue_json_path)},
        "north_star_task_board": {"path": north_star_task_board_path, "present": present(north_star_task_board_path)},
        "north_star_task_board_json": {"path": north_star_task_board_json_path, "present": present(north_star_task_board_json_path)},
        "north_star_execution_report": {"path": north_star_execution_report_path, "present": present(north_star_execution_report_path)},
        "phase_cd_task_board": {"path": phase_cd_task_board_path, "present": present(phase_cd_task_board_path)},
        "phase_cd_task_board_json": {"path": phase_cd_task_board_json_path, "present": present(phase_cd_task_board_json_path)},
        "phase_cd_execution_report": {"path": phase_cd_execution_report_path, "present": present(phase_cd_execution_report_path)},
        "memory_quality_report": {"path": memory_quality_report_path, "present": present(memory_quality_report_path)},
        "memory_quality_report_json": {"path": memory_quality_report_json_path, "present": present(memory_quality_report_json_path)},
        "organization_policy_report": {"path": organization_policy_report_path, "present": present(organization_policy_report_path)},
        "organization_policy_report_json": {"path": organization_policy_report_json_path, "present": present(organization_policy_report_json_path)},
        "experience_draft": {"path": experience_draft_path, "present": present(experience_draft_path)},
        "experience_draft_json": {"path": experience_draft_json_path, "present": present(experience_draft_json_path)},
        "memory_review_state": {"path": memory_review_state_path, "present": present(memory_review_state_path)},
        "memory_review_state_json": {"path": memory_review_state_json_path, "present": present(memory_review_state_json_path)},
        "phase_cd_next_task_board": {"path": phase_cd_next_task_board_path, "present": present(phase_cd_next_task_board_path)},
        "phase_cd_next_task_board_json": {"path": phase_cd_next_task_board_json_path, "present": present(phase_cd_next_task_board_json_path)},
        "phase_cd_next_execution_report": {"path": phase_cd_next_execution_report_path, "present": present(phase_cd_next_execution_report_path)},
        "phase_cd_preflight_memory_state_task_board": {"path": phase_cd_preflight_memory_state_task_board_path, "present": present(phase_cd_preflight_memory_state_task_board_path)},
        "phase_cd_preflight_memory_state_task_board_json": {"path": phase_cd_preflight_memory_state_task_board_json_path, "present": present(phase_cd_preflight_memory_state_task_board_json_path)},
        "phase_cd_preflight_memory_state_execution_report": {"path": phase_cd_preflight_memory_state_execution_report_path, "present": present(phase_cd_preflight_memory_state_execution_report_path)},
        "execution_time_contract_preflight_memory_state": {"path": execution_time_contract_preflight_memory_state_path, "present": present(execution_time_contract_preflight_memory_state_path)},
        "execution_time_contract_preflight_memory_state_json": {"path": execution_time_contract_preflight_memory_state_json_path, "present": present(execution_time_contract_preflight_memory_state_json_path)},
        "execution_time_contract_timer_guard": {"path": execution_time_contract_timer_guard_path, "present": present(execution_time_contract_timer_guard_path)},
        "execution_time_contract_timer_guard_json": {"path": execution_time_contract_timer_guard_json_path, "present": present(execution_time_contract_timer_guard_json_path)},
        "timer_guard_marker": {"path": timer_guard_marker_path, "present": present(timer_guard_marker_path)},
        "sinan_fitness_check": {"path": sinan_fitness_check_path, "present": present(sinan_fitness_check_path)},
        "sinan_fitness_check_json": {"path": sinan_fitness_check_json_path, "present": present(sinan_fitness_check_json_path)},
        "intent_ambiguity_gate": {"path": intent_ambiguity_gate_path, "present": present(intent_ambiguity_gate_path)},
        "intent_ambiguity_gate_json": {"path": intent_ambiguity_gate_json_path, "present": present(intent_ambiguity_gate_json_path)},
        "share_preflight_summary": {"path": share_preflight_summary_path, "present": present(share_preflight_summary_path)},
        "share_preflight_summary_json": {"path": share_preflight_summary_json_path, "present": present(share_preflight_summary_json_path)},
        "writeback_summary": {"path": writeback_path, "present": present(writeback_path)},
        "writeback_summary_json": {"path": writeback_json_path, "present": present(writeback_json_path)},
        "approval_boundary_comment": {"path": approval_comment_path, "present": present(approval_comment_path)},
        "approval_boundary_status": {"path": approval_status_path, "present": present(approval_status_path)},
        "approval_boundary_metadata": {"path": approval_metadata_path, "present": present(approval_metadata_path)},
        "requirement_gate": {"path": requirement_gate_path, "present": present(requirement_gate_path)},
        "design_gate": {"path": design_gate_path, "present": present(design_gate_path)},
        "clarification": {"path": clarification_path, "present": present(clarification_path)},
        "clarification_gate": {"path": clarification_gate_path, "present": present(clarification_gate_path)},
        "deliverable_gate": {"path": deliverable_gate_path, "present": present(deliverable_gate_path)},
        "gate_policy_check": {"path": gate_policy_path, "present": present(gate_policy_path)},
        "gate_policy_check_json": {"path": gate_policy_json_path, "present": present(gate_policy_json_path)},
        "gate_policy_exception": {"path": gate_policy_exception_path, "present": present(gate_policy_exception_path)},
        "gate_policy_exception_json": {"path": gate_policy_exception_json_path, "present": present(gate_policy_exception_json_path)},
    },
    "artifact_registry": registry_data,
    "remote_writes": False,
}
print(json.dumps(data, ensure_ascii=False, indent=2))
PY
)"

markdown_content="# Evidence Summary: ${issue} / ${run_id}

## Run

- Issue: ${issue}
- Run ID: ${run_id}
- Run status: ${run_status}
- Run mode: ${run_mode}
- Run directory: ${run_dir}
- Remote writes: false

## Checks

- Core evidence: ${core_status}
- Strict gate: ${strict_status}
- Gate policy check: $(file_status "$gate_policy_path")
- Gate policy exception: $(file_status "$gate_policy_exception_path")

## Timing Accuracy

$(python3 - <<'PY' "$json_content"
import json
import sys
data = json.loads(sys.argv[1])
timing = data.get("checks", {}).get("timing_accuracy", {})
print(f"- Timing artifact count: {timing.get('artifact_count', 0)}")
print(f"- Trusted measured count: {timing.get('trusted_measured_count', 0)}")
print(f"- Within one minute count: {timing.get('within_one_minute_count', 0)}")
print(f"- One minute miss count: {timing.get('one_minute_miss_count', 0)}")
latest = timing.get("latest") or {}
print(f"- Latest path: {latest.get('path') or 'not-measured'}")
print(f"- Latest estimated minutes: {latest.get('estimated_minutes') if latest.get('estimated_minutes') is not None else 'not-measured'}")
print(f"- Latest elapsed seconds: {latest.get('elapsed_seconds') if latest.get('elapsed_seconds') is not None else 'not-measured'}")
print(f"- Latest elapsed minutes: {latest.get('elapsed_minutes') if latest.get('elapsed_minutes') is not None else 'not-measured'}")
print(f"- Latest absolute error minutes: {latest.get('absolute_error_minutes') if latest.get('absolute_error_minutes') is not None else 'not-measured'}")
print(f"- Latest within_one_minute: {latest.get('within_one_minute') if latest.get('within_one_minute') is not None else 'not-measured'}")
print(f"- Latest variance note: {latest.get('variance_note') or 'not-measured'}")
print(f"- Latest recommended next estimate minutes: {latest.get('recommended_next_estimate_minutes') if latest.get('recommended_next_estimate_minutes') is not None else 'not-measured'}")
PY
)

## Artifact Registry

$(python3 - <<'PY' "$json_content"
import json
import sys
data = json.loads(sys.argv[1])
registry = data.get("artifact_registry") or {}
print(f"- Registry source: {registry.get('source') or 'not-used'}")
print(f"- Registry present: {str(bool(registry.get('present'))).lower()}")
for group, stats in sorted((registry.get("groups") or {}).items()):
    print(f"- {group}: present={stats.get('present', 0)} missing={stats.get('missing', 0)} total={stats.get('total', 0)}")
PY
)

## Gate Results

| Gate | Result | Score | Required Failures | Path |
|---|---|---|---|---|
| Requirement | $(gate_field "$requirement_gate_path" result) | $(gate_field "$requirement_gate_path" score) | $(gate_field "$requirement_gate_path" failures) | ${requirement_gate_path} |
| Design | $(gate_field "$design_gate_path" result) | $(gate_field "$design_gate_path" score) | $(gate_field "$design_gate_path" failures) | ${design_gate_path} |
| Clarification | $(gate_field "$clarification_gate_path" result) | $(gate_field "$clarification_gate_path" score) | $(gate_field "$clarification_gate_path" failures) | ${clarification_gate_path} |
| Deliverable | $(gate_field "$deliverable_gate_path" result) | $(gate_field "$deliverable_gate_path" score) | $(gate_field "$deliverable_gate_path" failures) | ${deliverable_gate_path} |

## Artifacts

| Artifact | Status | Path |
|---|---|---|
| Summary | $(file_status "$summary_path") | ${summary_path} |
| Stage report | $(file_status "$stage_report_path") | ${stage_report_path} |
| Comment draft | $(file_status "$comment_path") | ${comment_path} |
| Patch summary | $(file_status "$patch_summary_path") | ${patch_summary_path} |
| Review packet | $(file_status "$review_packet_path") | ${review_packet_path} |
| Verification report | $(file_status "$verification_report_path") | ${verification_report_path} |
| Execution preflight | $(file_status "$execution_preflight_path") | ${execution_preflight_path} |
| Execution preflight JSON | $(file_status "$execution_preflight_json_path") | ${execution_preflight_json_path} |
| Closeout summary | $(file_status "$closeout_summary_path") | ${closeout_summary_path} |
| Continuation gate | $(file_status "$continuation_gate_path") | ${continuation_gate_path} |
| Continuation gate JSON | $(file_status "$continuation_gate_json_path") | ${continuation_gate_json_path} |
| Execution time contract | $(file_status "$execution_time_contract_path") | ${execution_time_contract_path} |
| Execution time contract JSON | $(file_status "$execution_time_contract_json_path") | ${execution_time_contract_json_path} |
| Time estimation calibration | $(file_status "$time_calibration_path") | ${time_calibration_path} |
| Time estimation calibration JSON | $(file_status "$time_calibration_json_path") | ${time_calibration_json_path} |
| Phase I task queue | $(file_status "$phase_i_task_queue_path") | ${phase_i_task_queue_path} |
| Phase I task queue JSON | $(file_status "$phase_i_task_queue_json_path") | ${phase_i_task_queue_json_path} |
| North Star task board | $(file_status "$north_star_task_board_path") | ${north_star_task_board_path} |
| North Star task board JSON | $(file_status "$north_star_task_board_json_path") | ${north_star_task_board_json_path} |
| North Star execution report | $(file_status "$north_star_execution_report_path") | ${north_star_execution_report_path} |
| Phase C/D task board | $(file_status "$phase_cd_task_board_path") | ${phase_cd_task_board_path} |
| Phase C/D task board JSON | $(file_status "$phase_cd_task_board_json_path") | ${phase_cd_task_board_json_path} |
| Phase C/D execution report | $(file_status "$phase_cd_execution_report_path") | ${phase_cd_execution_report_path} |
| Memory quality report | $(file_status "$memory_quality_report_path") | ${memory_quality_report_path} |
| Memory quality report JSON | $(file_status "$memory_quality_report_json_path") | ${memory_quality_report_json_path} |
| Organization policy report | $(file_status "$organization_policy_report_path") | ${organization_policy_report_path} |
| Organization policy report JSON | $(file_status "$organization_policy_report_json_path") | ${organization_policy_report_json_path} |
| Experience draft | $(file_status "$experience_draft_path") | ${experience_draft_path} |
| Experience draft JSON | $(file_status "$experience_draft_json_path") | ${experience_draft_json_path} |
| Memory review state | $(file_status "$memory_review_state_path") | ${memory_review_state_path} |
| Memory review state JSON | $(file_status "$memory_review_state_json_path") | ${memory_review_state_json_path} |
| Phase C/D next task board | $(file_status "$phase_cd_next_task_board_path") | ${phase_cd_next_task_board_path} |
| Phase C/D next task board JSON | $(file_status "$phase_cd_next_task_board_json_path") | ${phase_cd_next_task_board_json_path} |
| Phase C/D next execution report | $(file_status "$phase_cd_next_execution_report_path") | ${phase_cd_next_execution_report_path} |
| Phase C/D preflight memory-state task board | $(file_status "$phase_cd_preflight_memory_state_task_board_path") | ${phase_cd_preflight_memory_state_task_board_path} |
| Phase C/D preflight memory-state task board JSON | $(file_status "$phase_cd_preflight_memory_state_task_board_json_path") | ${phase_cd_preflight_memory_state_task_board_json_path} |
| Phase C/D preflight memory-state execution report | $(file_status "$phase_cd_preflight_memory_state_execution_report_path") | ${phase_cd_preflight_memory_state_execution_report_path} |
| Execution time contract preflight memory-state | $(file_status "$execution_time_contract_preflight_memory_state_path") | ${execution_time_contract_preflight_memory_state_path} |
| Execution time contract preflight memory-state JSON | $(file_status "$execution_time_contract_preflight_memory_state_json_path") | ${execution_time_contract_preflight_memory_state_json_path} |
| Execution time contract timer guard | $(file_status "$execution_time_contract_timer_guard_path") | ${execution_time_contract_timer_guard_path} |
| Execution time contract timer guard JSON | $(file_status "$execution_time_contract_timer_guard_json_path") | ${execution_time_contract_timer_guard_json_path} |
| Timer guard marker | $(file_status "$timer_guard_marker_path") | ${timer_guard_marker_path} |
| Sinan fitness check | $(file_status "$sinan_fitness_check_path") | ${sinan_fitness_check_path} |
| Sinan fitness check JSON | $(file_status "$sinan_fitness_check_json_path") | ${sinan_fitness_check_json_path} |
| Intent ambiguity gate | $(file_status "$intent_ambiguity_gate_path") | ${intent_ambiguity_gate_path} |
| Intent ambiguity gate JSON | $(file_status "$intent_ambiguity_gate_json_path") | ${intent_ambiguity_gate_json_path} |
| Share preflight summary | $(file_status "$share_preflight_summary_path") | ${share_preflight_summary_path} |
| Share preflight summary JSON | $(file_status "$share_preflight_summary_json_path") | ${share_preflight_summary_json_path} |
| Writeback summary | $(file_status "$writeback_path") | ${writeback_path} |
| Writeback summary JSON | $(file_status "$writeback_json_path") | ${writeback_json_path} |
| Approval boundary comment | $(file_status "$approval_comment_path") | ${approval_comment_path} |
| Approval boundary status | $(file_status "$approval_status_path") | ${approval_status_path} |
| Approval boundary metadata | $(file_status "$approval_metadata_path") | ${approval_metadata_path} |
| Requirement gate | $(file_status "$requirement_gate_path") | ${requirement_gate_path} |
| Design gate | $(file_status "$design_gate_path") | ${design_gate_path} |
| Clarification draft | $(file_status "$clarification_path") | ${clarification_path} |
| Clarification gate | $(file_status "$clarification_gate_path") | ${clarification_gate_path} |
| Deliverable gate | $(file_status "$deliverable_gate_path") | ${deliverable_gate_path} |
| Gate policy check | $(file_status "$gate_policy_path") | ${gate_policy_path} |
| Gate policy JSON | $(file_status "$gate_policy_json_path") | ${gate_policy_json_path} |
| Gate policy exception | $(file_status "$gate_policy_exception_path") | ${gate_policy_exception_path} |
| Gate policy exception JSON | $(file_status "$gate_policy_exception_json_path") | ${gate_policy_exception_json_path} |
| Run JSON | $(file_status "$run_json_path") | ${run_json_path} |

## Review Notes

- Core evidence requires summary, stage report, and comment draft.
- Strict gate is detected from the local verification report when available.
- Gate Results summarize requirement/design/clarification/deliverable gate reports when present.
- Gate policy check records task-type-specific required gates and score thresholds when present.
- Gate policy exception records explicit human override evidence when present.
- Approval boundary artifacts record side-effect approval decisions before writeback gates and remote writes.
- Share preflight summary artifacts record final sharing readiness and approval-boundary snapshots when persisted to the run.
- Phase I task queue artifacts keep long-loop work stocked with evidence-backed local tasks.
- North Star task board artifacts connect current work slices back to the north-star metrics and task-quantity-first estimates.
- North Star execution report records final task completion, timing adjustment, verification, and remaining risks.
- Phase C/D artifacts record organization-layer and project-memory buildout progress.
- Memory quality artifacts validate L2 project memory structure, references, tags, and sensitive-pattern scans.
- Organization policy artifacts summarize Phase C routing, policy, side-effect, and review orchestration readiness.
- Experience draft artifacts provide structured memory metadata with review_state lifecycle.
- Memory review state artifacts record local review_state transitions for project-memory cases.
- Phase C/D preflight memory-state artifacts record this slice's task board, execution report, and timing contract.
- Timer guard artifacts record paired run-local start/close markers to prevent stale /tmp timing reuse.
- Sinan fitness artifacts summarize system health across capability, evidence, memory, organization, timing, and verification.
- Intent ambiguity artifacts record typo/metaphor checks before execution to prevent silent branch selection.
- Execution preflight and closeout summary record the task package boundary and local completion path.
- Clarification draft and clarification gate are required for needs_clarification runs and optional otherwise.
- This collector is local-only and does not write Multica.
"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$json_content" > "$output"
  echo "evidence_json: $output"
else
  printf '%s\n' "$json_content"
fi

if [[ -n "$markdown" ]]; then
  mkdir -p "$(dirname "$markdown")"
  printf '%s' "$markdown_content" > "$markdown"
  echo "evidence_markdown: $markdown"
fi

if [[ "$core_status" == "FAILED" ]]; then
  exit 1
fi
