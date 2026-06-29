#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/evaluate-state.sh --run-id <run-id> [--issue <issue-id>] [--write-run] [--output <file>] [--markdown <file>]

Evaluate a local ai-loop run directory and suggest the next Multica Loop state.

Options:
  --run-id    Run directory name under runs/, required
  --issue     Optional issue identifier, for example FUZ-554
  --write-run Write state-evaluation.json and state-evaluation.md into the run directory
  --output    Optional JSON output path
  --markdown  Optional Markdown output path
  -h, --help  Show this help

This script is local-only. It reads runs/ and never performs remote writes.
HELP
}

run_id=""
issue=""
output=""
markdown=""
write_run="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --issue)
      issue="${2:-}"; shift 2 ;;
    --write-run)
      write_run="true"; shift ;;
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

if [[ "$write_run" == "true" ]]; then
  output="$run_dir/state-evaluation.json"
  markdown="$run_dir/state-evaluation.md"
fi

if [[ -z "$issue" ]]; then
  issue="$(printf '%s\n' "$run_id" | grep -Eo '^[A-Z]+-[0-9]+' || true)"
  if [[ ! "$issue" =~ ^[A-Z]+-[0-9]+$ ]]; then
    issue="unknown"
  fi
fi

summary_path="$run_dir/summary.md"
stage_report_path="$run_dir/stage-report.md"
comment_path="$run_dir/multica-comment.md"
patch_summary_path="$run_dir/patch-summary.md"
review_packet_path="$run_dir/review-packet.md"
scope_split_path="$run_dir/scope-split-report.md"
verification_report_path="$run_dir/verification-report.md"
writeback_path="$run_dir/writeback-summary.md"
writeback_json_path="$run_dir/writeback-summary.json"
requirement_gate_path="$run_dir/requirement-gate.md"
clarification_path="$run_dir/clarification.md"
clarification_gate_path="$run_dir/clarification-gate.md"
gate_policy_path="$run_dir/gate-policy-check.md"
gate_policy_json_path="$run_dir/gate-policy-check.json"
gate_policy_exception_path="$run_dir/gate-policy-exception.md"
gate_policy_exception_json_path="$run_dir/gate-policy-exception.json"
run_json_path="$run_dir/run.json"

json_content="$(python3 - <<'PY' \
  "$issue" "$run_id" "$run_dir" \
  "$summary_path" "$stage_report_path" "$comment_path" "$patch_summary_path" \
  "$review_packet_path" "$scope_split_path" "$verification_report_path" "$writeback_path" "$writeback_json_path" "$requirement_gate_path" "$clarification_path" "$clarification_gate_path" "$gate_policy_path" "$gate_policy_json_path" "$gate_policy_exception_path" "$gate_policy_exception_json_path" "$run_json_path"
import json
import sys
from pathlib import Path

(
    issue,
    run_id,
    run_dir,
    summary_path,
    stage_report_path,
    comment_path,
    patch_summary_path,
    review_packet_path,
    scope_split_path,
    verification_report_path,
    writeback_path,
    writeback_json_path,
    requirement_gate_path,
    clarification_path,
    clarification_gate_path,
    gate_policy_path,
    gate_policy_json_path,
    gate_policy_exception_path,
    gate_policy_exception_json_path,
    run_json_path,
) = sys.argv[1:]


def present(path: str) -> bool:
    item = Path(path)
    return item.is_file() and item.stat().st_size > 0


def read_text(path: str) -> str:
    item = Path(path)
    if not item.is_file():
        return ""
    return item.read_text(encoding="utf-8", errors="replace")


def writeback_completed(path: str) -> bool:
    text = read_text(path)
    if not text:
        return False
    completed_markers = [
        "Comment written: true",
        "Status written: true",
        "Metadata written: true",
        "Comment ID:",
    ]
    failed_markers = [
        "Comment written: failed",
        "Status written: failed",
        "Metadata written: failed",
    ]
    return any(marker in text for marker in completed_markers) and not any(
        marker in text for marker in failed_markers
    )


def writeback_completed_json(path: str) -> bool:
    item = Path(path)
    if not item.is_file() or item.stat().st_size == 0:
        return False
    try:
        data = json.loads(item.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return False
    return data.get("remote_write_completed") is True


def requirement_gate_failed(path: str) -> bool:
    text = read_text(path)
    if not text:
        return False
    failed_markers = [
        "- Result: FAILED",
        "Result: FAILED",
        "Next state: needs_clarification",
        "needs_clarification",
    ]
    return any(marker in text for marker in failed_markers)


def gate_passed(path: str) -> bool:
    text = read_text(path)
    if not text:
        return False
    return "- Result: PASSED" in text or "Result: PASSED" in text


def gate_policy_result(markdown_path: str, json_path: str) -> str:
    json_item = Path(json_path)
    if json_item.is_file() and json_item.stat().st_size > 0:
        try:
            data = json.loads(json_item.read_text(encoding="utf-8"))
            return data.get("result") or "UNKNOWN"
        except json.JSONDecodeError:
            return "UNKNOWN"
    text = read_text(markdown_path)
    if not text:
        return "MISSING"
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- Result:"):
            return stripped.split(":", 1)[1].strip() or "UNKNOWN"
    return "UNKNOWN"


def active_gate_policy_exception(markdown_path: str, json_path: str) -> bool:
    json_item = Path(json_path)
    if json_item.is_file() and json_item.stat().st_size > 0:
        try:
            data = json.loads(json_item.read_text(encoding="utf-8"))
            return data.get("status") == "ACTIVE" and bool(data.get("approved_by")) and bool(data.get("reason"))
        except json.JSONDecodeError:
            return False
    text = read_text(markdown_path)
    return "- Status: ACTIVE" in text and "- Approved by:" in text and "## Reason" in text


artifacts = {
    "summary": {"path": summary_path, "present": present(summary_path)},
    "stage_report": {"path": stage_report_path, "present": present(stage_report_path)},
    "comment_draft": {"path": comment_path, "present": present(comment_path)},
    "patch_summary": {"path": patch_summary_path, "present": present(patch_summary_path)},
    "review_packet": {"path": review_packet_path, "present": present(review_packet_path)},
    "scope_split_report": {"path": scope_split_path, "present": present(scope_split_path)},
    "verification_report": {"path": verification_report_path, "present": present(verification_report_path)},
    "writeback_summary": {"path": writeback_path, "present": present(writeback_path)},
    "writeback_summary_json": {"path": writeback_json_path, "present": present(writeback_json_path)},
    "requirement_gate": {"path": requirement_gate_path, "present": present(requirement_gate_path)},
    "clarification": {"path": clarification_path, "present": present(clarification_path)},
    "clarification_gate": {"path": clarification_gate_path, "present": present(clarification_gate_path)},
    "gate_policy_check": {"path": gate_policy_path, "present": present(gate_policy_path)},
    "gate_policy_check_json": {"path": gate_policy_json_path, "present": present(gate_policy_json_path)},
    "gate_policy_exception": {"path": gate_policy_exception_path, "present": present(gate_policy_exception_path)},
    "gate_policy_exception_json": {"path": gate_policy_exception_json_path, "present": present(gate_policy_exception_json_path)},
    "run_json": {"path": run_json_path, "present": present(run_json_path)},
}

missing_core = [
    name
    for name in ("summary", "stage_report", "comment_draft")
    if not artifacts[name]["present"]
]
remote_write_completed = writeback_completed_json(writeback_json_path) or writeback_completed(writeback_path)
needs_clarification = requirement_gate_failed(requirement_gate_path)
clarification_present = artifacts["clarification"]["present"]
clarification_gate_present = artifacts["clarification_gate"]["present"]
clarification_gate_passed = gate_passed(clarification_gate_path)
gate_policy_status = gate_policy_result(gate_policy_path, gate_policy_json_path)
gate_policy_failed = gate_policy_status == "FAILED"
gate_policy_exception_active = active_gate_policy_exception(gate_policy_exception_path, gate_policy_exception_json_path)

if missing_core:
    from_state = "running"
    to_state = "blocked"
    reason = "missing_evidence: " + ", ".join(missing_core)
    next_actor = "execution_agent"
    side_effects_allowed = False
elif needs_clarification and not clarification_present:
    from_state = "intake_ready"
    to_state = "blocked"
    reason = "needs_clarification but clarification evidence is missing"
    next_actor = "execution_agent"
    side_effects_allowed = False
elif needs_clarification and not clarification_gate_present:
    from_state = "intake_ready"
    to_state = "blocked"
    reason = "needs_clarification but clarification gate evidence is missing"
    next_actor = "execution_agent"
    side_effects_allowed = False
elif needs_clarification and not clarification_gate_passed:
    from_state = "intake_ready"
    to_state = "blocked"
    reason = "needs_clarification but clarification gate did not pass"
    next_actor = "execution_agent"
    side_effects_allowed = False
elif needs_clarification:
    from_state = "intake_ready"
    to_state = "needs_clarification"
    reason = "requirement gate failed; clarification evidence and quality gate are present"
    next_actor = "human"
    side_effects_allowed = False
elif gate_policy_failed and not gate_policy_exception_active:
    from_state = "evidence_ready"
    to_state = "blocked"
    reason = "gate policy check failed; fix required gates or record an explicit human exception"
    next_actor = "execution_agent"
    side_effects_allowed = False
elif not artifacts["verification_report"]["present"]:
    from_state = "running"
    to_state = "evidence_ready"
    reason = "core evidence complete; verification report is not present"
    next_actor = "execution_agent"
    side_effects_allowed = False
elif remote_write_completed:
    from_state = "writeback_ready"
    to_state = "done"
    reason = "writeback summary shows at least one completed remote write"
    next_actor = "human"
    side_effects_allowed = False
else:
    from_state = "evidence_ready"
    to_state = "review_ready"
    reason = "core evidence complete and verification report present"
    next_actor = "reviewer"
    side_effects_allowed = False

checks = {
    "core_evidence": "FAILED" if missing_core else "PASSED",
    "verification_report": "PRESENT" if artifacts["verification_report"]["present"] else "MISSING",
    "writeback_summary": "PRESENT" if artifacts["writeback_summary"]["present"] else "MISSING",
    "remote_write_completed": "YES" if remote_write_completed else "NO",
    "requirement_gate": "FAILED" if needs_clarification else ("PRESENT" if artifacts["requirement_gate"]["present"] else "MISSING"),
    "clarification": "PRESENT" if clarification_present else "MISSING",
    "clarification_gate": "PASSED" if clarification_gate_passed else ("PRESENT" if clarification_gate_present else "MISSING"),
    "gate_policy_check": gate_policy_status,
    "gate_policy_exception": "ACTIVE" if gate_policy_exception_active else ("PRESENT" if artifacts["gate_policy_exception"]["present"] else "MISSING"),
}

data = {
    "schema_version": 1,
    "contract": "review-orchestration.v1",
    "issue": issue,
    "run_id": run_id,
    "run_dir": run_dir,
    "from": from_state,
    "to": to_state,
    "reason": reason,
    "required_next_actor": next_actor,
    "review_orchestration": {
        "evidence_summary": artifacts.get("summary", {}).get("present"),
        "review_packet": artifacts.get("review_packet", {}).get("present"),
        "verification_report": artifacts.get("verification_report", {}).get("present"),
        "verdict": to_state,
        "next_actor": next_actor,
    },
    "side_effects_allowed": side_effects_allowed,
    "checks": checks,
    "missing_core_evidence": missing_core,
    "artifacts": artifacts,
}

print(json.dumps(data, ensure_ascii=False, indent=2))
PY
)"

markdown_content="$(python3 - <<'PY' "$json_content"
import json
import sys

data = json.loads(sys.argv[1])


def status(present: bool) -> str:
    return "present" if present else "missing"


rows = []
for label, key in [
    ("Summary", "summary"),
    ("Stage report", "stage_report"),
    ("Comment draft", "comment_draft"),
    ("Patch summary", "patch_summary"),
    ("Review packet", "review_packet"),
    ("Scope split report", "scope_split_report"),
    ("Verification report", "verification_report"),
    ("Writeback summary", "writeback_summary"),
    ("Requirement gate", "requirement_gate"),
    ("Clarification", "clarification"),
    ("Clarification gate", "clarification_gate"),
    ("Gate policy check", "gate_policy_check"),
    ("Gate policy JSON", "gate_policy_check_json"),
    ("Gate policy exception", "gate_policy_exception"),
    ("Gate policy exception JSON", "gate_policy_exception_json"),
]:
    artifact = data["artifacts"][key]
    rows.append(f"| {label} | {status(artifact['present'])} | {artifact['path']} |")

print(f"""# Loop State Evaluation: {data['issue']} / {data['run_id']}

## Suggested Transition

- From: {data['from']}
- To: {data['to']}
- Reason: {data['reason']}
- Required next actor: {data['required_next_actor']}
- Side effects allowed: {str(data['side_effects_allowed']).lower()}

## Checks

- Core evidence: {data['checks']['core_evidence']}
- Verification report: {data['checks']['verification_report']}
- Writeback summary: {data['checks']['writeback_summary']}
- Requirement gate: {data['checks']['requirement_gate']}
- Clarification: {data['checks']['clarification']}
- Clarification gate: {data['checks']['clarification_gate']}
- Gate policy check: {data['checks']['gate_policy_check']}
- Gate policy exception: {data['checks']['gate_policy_exception']}

## Artifacts

| Artifact | Status | Path |
|---|---|---|
{chr(10).join(rows)}

## Notes

- This is a local recommendation only.
- It does not write Multica comments or status.
- Remote side effects still require the existing policy and human control.
""")
PY
)"

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  printf '%s\n' "$json_content" > "$output"
  echo "state_json: $output"
else
  printf '%s\n' "$json_content"
fi

if [[ -n "$markdown" ]]; then
  mkdir -p "$(dirname "$markdown")"
  printf '%s' "$markdown_content" > "$markdown"
  echo "state_markdown: $markdown"
fi
