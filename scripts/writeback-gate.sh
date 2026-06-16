#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/writeback-gate.sh --issue <issue> --run-id <run-id> --type <type> [options]

Check writeback preconditions before writing to Multica.

Options:
  --issue <issue>     Issue identifier, required
  --run-id <run-id>   Run identifier, required
  --type <type>       Writeback type: comment | status | metadata, required
  --policy <policy>   Status policy: conservative | validation | no-status (default: conservative)
  --approved-by <who> Human approver name (required for metadata)
  --output <file>     Write gate report to file
  -h, --help          Show this help
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

issue_id=""
run_id=""
writeback_type=""
status_policy="conservative"
approved_by=""
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --type)
      writeback_type="${2:-}"; shift 2 ;;
    --policy)
      status_policy="${2:-}"; shift 2 ;;
    --approved-by)
      approved_by="${2:-}"; shift 2 ;;
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

if [[ -z "$issue_id" || -z "$run_id" || -z "$writeback_type" ]]; then
  echo "--issue, --run-id, and --type are required" >&2
  show_help
  exit 2
fi

case "$writeback_type" in
  comment|status|metadata) ;;
  *)
    echo "Invalid --type: $writeback_type (must be comment, status, or metadata)" >&2
    exit 2 ;;
esac

case "$status_policy" in
  conservative|validation|no-status) ;;
  *)
    echo "Invalid --policy: $status_policy" >&2
    exit 2 ;;
esac

run_dir="$ROOT_DIR/runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi

cd "$ROOT_DIR"

gate_result="PASSED"
gate_reason="all checks passed"
checks=()

check_core_evidence() {
  local summary="$run_dir/summary.md"
  local stage_report="$run_dir/stage-report.md"
  local comment_draft="$run_dir/multica-comment.md"
  
  if [[ -f "$summary" && -f "$stage_report" && -f "$comment_draft" ]]; then
    checks+=("core_evidence=PASSED")
  else
    checks+=("core_evidence=FAILED")
    gate_result="FAILED"
    gate_reason="core evidence incomplete"
  fi
}

check_strict_gate() {
  local verification_report="$run_dir/verification-report.md"
  if [[ -f "$verification_report" ]]; then
    if rg "Strict Evidence Gate" -A 10 | rg -q "PASSED" "$verification_report"; then
      checks+=("strict_gate=PASSED")
    else
      checks+=("strict_gate=FAILED")
      gate_result="FAILED"
      gate_reason="strict gate did not pass"
    fi
  else
    checks+=("strict_gate=MISSING")
    gate_result="FAILED"
    gate_reason="verification report missing"
  fi
}

check_state_gate() {
  local verification_report="$run_dir/verification-report.md"
  if [[ -f "$verification_report" ]]; then
    if rg "State Metadata Gate" -A 10 | rg -q "PASSED" "$verification_report"; then
      checks+=("state_gate=PASSED")
    else
      checks+=("state_gate=FAILED")
      gate_result="FAILED"
      gate_reason="state gate did not pass"
    fi
  else
    checks+=("state_gate=MISSING")
    gate_result="FAILED"
    gate_reason="verification report missing"
  fi
}

check_draft_exists() {
  local draft_file=""
  case "$writeback_type" in
    comment)
      draft_file="$run_dir/multica-comment.md" ;;
    status)
      draft_file="$run_dir/state-evaluation.json" ;;
    metadata)
      draft_file="$run_dir/metadata-draft.json" ;;
  esac
  
  if [[ -f "$draft_file" && -s "$draft_file" ]]; then
    checks+=("draft_exists=PASSED")
  else
    checks+=("draft_exists=FAILED")
    gate_result="FAILED"
    gate_reason="draft file missing or empty: $draft_file"
  fi
}

check_no_secrets() {
  local draft_file=""
  case "$writeback_type" in
    comment)
      draft_file="$run_dir/multica-comment.md" ;;
    metadata)
      draft_file="$run_dir/metadata-draft.json" ;;
    *)
      checks+=("no_secrets=SKIPPED")
      return ;;
  esac
  
  if [[ ! -f "$draft_file" ]]; then
    checks+=("no_secrets=SKIPPED")
    return
  fi
  
  if rg -i "token|password|secret|key|credential|cookie" "$draft_file" >/dev/null 2>&1; then
    checks+=("no_secrets=FAILED")
    gate_result="FAILED"
    gate_reason="draft contains potential secrets"
  else
    checks+=("no_secrets=PASSED")
  fi
}

check_metadata_format() {
  if [[ "$writeback_type" != "metadata" ]]; then
    checks+=("metadata_format=SKIPPED")
    return
  fi
  
  local metadata_draft="$run_dir/metadata-draft.json"
  if [[ ! -f "$metadata_draft" ]]; then
    checks+=("metadata_format=FAILED")
    gate_result="FAILED"
    gate_reason="metadata draft missing"
    return
  fi
  
  if python3 -c "import json; json.load(open('$metadata_draft'))" >/dev/null 2>&1; then
    checks+=("metadata_format=PASSED")
  else
    checks+=("metadata_format=FAILED")
    gate_result="FAILED"
    gate_reason="metadata draft invalid JSON"
  fi
}

check_human_approval() {
  if [[ "$writeback_type" != "metadata" ]]; then
    checks+=("human_approval=SKIPPED")
    return
  fi
  
  if [[ -n "$approved_by" ]]; then
    checks+=("human_approval=PASSED:$approved_by")
  else
    checks+=("human_approval=FAILED")
    gate_result="FAILED"
    gate_reason="metadata writeback requires --approved-by"
  fi
}

case "$writeback_type" in
  comment)
    check_core_evidence
    check_draft_exists
    check_no_secrets
    ;;
  status)
    check_core_evidence
    check_strict_gate
    check_state_gate
    check_draft_exists
    ;;
  metadata)
    check_core_evidence
    check_strict_gate
    check_state_gate
    check_draft_exists
    check_no_secrets
    check_metadata_format
    check_human_approval
    ;;
esac

allowed="true"
if [[ "$gate_result" == "FAILED" ]]; then
  allowed="false"
fi

report_json=$(cat <<JSON
{
  "gate": "writeback",
  "type": "$writeback_type",
  "issue": "$issue_id",
  "run_id": "$run_id",
  "policy": "$status_policy",
  "result": "$gate_result",
  "checks": {
$(printf '    "%s"\n' "${checks[@]}" | sed 's/=/:"/; s/$/"/' | paste -sd ',' -)
  },
  "allowed": $allowed,
  "reason": "$gate_reason",
  "approved_by": "${approved_by:-null}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
)

if [[ -n "$output_file" ]]; then
  echo "$report_json" > "$output_file"
  echo "writeback_gate_report: $output_file"
fi

echo "$report_json"

if [[ "$gate_result" == "FAILED" ]]; then
  exit 1
fi

exit 0
