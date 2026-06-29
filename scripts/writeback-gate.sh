#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/writeback-gate.sh --issue <issue> --run-id <run-id> --type <type> [options]

Check writeback preconditions before writing to Multica or Feishu.

Options:
  --issue <issue>          Issue identifier, required
  --run-id <run-id>        Run identifier, required
  --type <type>            Writeback type: comment | status | metadata | feishu, required
  --policy <policy>        Status policy: conservative | validation | no-status (default: conservative)
  --approved-by <who>      Human approver name
  --approval-window <file> Optional batch approval JSON file
  --output <file>          Write JSON gate report to file
  -h, --help               Show this help
HELP
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

issue_id=""
run_id=""
writeback_type=""
status_policy="conservative"
approved_by=""
approval_window=""
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
    --approval-window)
      approval_window="${2:-}"; shift 2 ;;
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
  comment|status|metadata|feishu) ;;
  *) echo "Invalid --type: $writeback_type (must be comment, status, metadata, or feishu)" >&2; exit 2 ;;
esac
case "$status_policy" in
  conservative|validation|no-status) ;;
  *) echo "Invalid --policy: $status_policy" >&2; exit 2 ;;
esac

run_dir="$ROOT_DIR/runs/$run_id"
if [[ ! -d "$run_dir" ]]; then
  echo "Run directory not found: $run_dir" >&2
  exit 1
fi
cd "$ROOT_DIR"

case "$writeback_type" in
  comment) action="multica-comment"; draft_file="$run_dir/multica-comment.md" ;;
  status) action="multica-status"; draft_file="$run_dir/state-evaluation.json" ;;
  metadata) action="multica-metadata"; draft_file="$run_dir/metadata-draft.json" ;;
  feishu) action="feishu-write"; draft_file="$run_dir/feishu-write-draft.md" ;;
esac

approval_output="$run_dir/approval-boundary-${writeback_type}.md"
approval_json_output="$run_dir/approval-boundary-${writeback_type}.json"
if ! ./scripts/approval-boundary.sh --action "$action" --issue "$issue_id" --run-id "$run_id" ${approved_by:+--approved-by "$approved_by"} ${approval_window:+--approval-window "$approval_window"} --output "$approval_output" --json-output "$approval_json_output" >/tmp/writeback-gate-approval.out 2>/tmp/writeback-gate-approval.err; then
  approval_allowed="false"
else
  approval_allowed="true"
fi

json_report="$(python3 - "$ROOT_DIR" "$issue_id" "$run_id" "$writeback_type" "$status_policy" "$approved_by" "$draft_file" "$approval_output" "$approval_json_output" "$approval_allowed" <<'PY'
import datetime as dt
import json
import re
import sys
from pathlib import Path

root, issue, run_id, writeback_type, status_policy, approved_by, draft_file, approval_output, approval_json_output, approval_allowed = sys.argv[1:]
root = Path(root)
run_dir = root / "runs" / run_id
checks = []
result = "PASSED"
reason = "all checks passed"

def add(name, status, detail=""):
    global result, reason
    checks.append({"name": name, "status": status, "detail": detail})
    if status == "FAILED" and result == "PASSED":
        result = "FAILED"
        reason = detail or name

def rel(path):
    item = Path(path)
    try:
        return str(item.relative_to(root))
    except ValueError:
        return str(item)

for name in ["summary.md", "stage-report.md", "multica-comment.md"]:
    path = run_dir / name
    add(f"core:{name}", "PASSED" if path.is_file() and path.stat().st_size > 0 else "FAILED", rel(path))

if writeback_type in {"metadata", "status"}:
    verification = run_dir / "verification-report.md"
    text = verification.read_text(encoding="utf-8", errors="replace") if verification.is_file() else ""
    add("strict_gate", "PASSED" if "Strict Evidence Gate" in text and "PASSED" in text else "FAILED", rel(verification))
    add("state_gate", "PASSED" if "State Metadata Gate" in text and "PASSED" in text else "FAILED", rel(verification))
else:
    add("strict_gate", "SKIPPED", writeback_type)
    add("state_gate", "SKIPPED", writeback_type)

draft_path = Path(draft_file)
if writeback_type == "feishu" and not draft_path.is_file():
    add("draft_exists", "SKIPPED", "feishu write draft supplied by caller")
elif draft_path.is_file() and draft_path.stat().st_size > 0:
    add("draft_exists", "PASSED", rel(draft_path))
else:
    add("draft_exists", "FAILED", rel(draft_path))

if draft_path.is_file() and writeback_type in {"comment", "metadata", "feishu"}:
    text = draft_path.read_text(encoding="utf-8", errors="replace")
    secret_hit = re.search(r"(?i)(api[_-]?key|password|secret|token|credential|cookie)\s*[:=]", text)
    add("no_secrets", "FAILED" if secret_hit else "PASSED", secret_hit.group(0) if secret_hit else rel(draft_path))
else:
    add("no_secrets", "SKIPPED", writeback_type)

if writeback_type == "metadata" and draft_path.is_file():
    try:
        data = json.loads(draft_path.read_text(encoding="utf-8"))
        ok = bool(data.get("metadata") or data.get("key"))
    except json.JSONDecodeError:
        ok = False
    add("metadata_format", "PASSED" if ok else "FAILED", rel(draft_path))
else:
    add("metadata_format", "SKIPPED", writeback_type)

approval = {}
approval_path = Path(approval_json_output)
if approval_path.is_file():
    approval = json.loads(approval_path.read_text(encoding="utf-8"))
approval_status = "PASSED" if approval_allowed == "true" and approval.get("decision") == "approved_to_proceed" else "FAILED"
add("human_approval", approval_status, approval.get("approved_by") or "approval required")

readback_targets = {
    "comment": run_dir / "multica-comment-readback.json",
    "status": run_dir / "multica-status-readback.json",
    "metadata": run_dir / "multica-metadata-after.json",
    "feishu": run_dir / "feishu-readback.json",
}
readback_path = readback_targets[writeback_type]
readback_required_after_write = True
readback_status = "READY" if approval_status == "PASSED" else "BLOCKED_UNTIL_APPROVAL"
if readback_path.is_file() and readback_path.stat().st_size > 0:
    readback_status = "PRESENT"

allowed = result == "PASSED"
report = {
    "schema_version": 1,
    "contract": "writeback-gate.v1",
    "gate": "writeback",
    "type": writeback_type,
    "issue": issue,
    "run_id": run_id,
    "policy": status_policy,
    "result": result,
    "checks": {item["name"]: item["status"] for item in checks},
    "check_details": checks,
    "allowed": allowed,
    "reason": reason,
    "approved_by": approval.get("approved_by") or approved_by or None,
    "approval_boundary": {
        "path": rel(approval_output),
        "json_path": rel(approval_json_output),
        "decision": approval.get("decision"),
        "approval_window_matched": (approval.get("approval_window") or {}).get("matched"),
    },
    "readback": {
        "required_after_write": readback_required_after_write,
        "status": readback_status,
        "path": rel(readback_path),
    },
    "timestamp": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$json_report" > "$output_file"
  echo "writeback_gate_report: $output_file"
fi
printf '%s\n' "$json_report"

allowed="$(python3 - "$json_report" <<'PY'
import json
import sys
print("true" if json.loads(sys.argv[1]).get("allowed") else "false")
PY
)"
if [[ "$allowed" != "true" ]]; then
  exit 1
fi
