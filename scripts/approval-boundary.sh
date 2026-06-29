#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/approval-boundary.sh --action <action> [options]

Classify whether an action can continue locally or must stop for explicit human approval.

Options:
  --action <name>          Action name, required. Known examples:
                           local-edit, verify, collect-evidence, share-preflight,
                           obsidian-sync, multica-comment, multica-status,
                           multica-metadata, feishu-write, git-remote, deploy,
                           tool-install, codex-config
  --issue <issue>          Optional issue identifier
  --run-id <run-id>        Optional run identifier
  --approved-by <who>      Human approver name when approval already exists
  --approval-window <file> Optional batch approval JSON file
  --now <iso8601>          Optional current time override for tests
  --output <file>          Optional Markdown report path
  --json-output <file>     Optional JSON report path
  -h, --help               Show this help

Exit codes:
  0  Action may proceed without new approval
  1  Action must stop for approval
  2  Invalid arguments

This script is local-only. It never writes Multica, Feishu, Obsidian, Git remote, or deploy targets.
HELP
}

action=""
issue_id=""
run_id=""
approved_by=""
approval_window=""
now_override=""
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      action="${2:-}"; shift 2 ;;
    --issue)
      issue_id="${2:-}"; shift 2 ;;
    --run-id)
      run_id="${2:-}"; shift 2 ;;
    --approved-by)
      approved_by="${2:-}"; shift 2 ;;
    --approval-window)
      approval_window="${2:-}"; shift 2 ;;
    --now)
      now_override="${2:-}"; shift 2 ;;
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

if [[ -z "$action" ]]; then
  echo "--action is required" >&2
  show_help
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
policy_path="$ROOT_DIR/config/approval-boundary.json"
if [[ ! -s "$policy_path" ]]; then
  echo "Approval boundary policy not found: $policy_path" >&2
  exit 1
fi

json_report="$(python3 - "$policy_path" "$action" "$issue_id" "$run_id" "$approved_by" "$approval_window" "$now_override" <<'PY'
import datetime as dt
import json
import sys
from pathlib import Path

policy_path, action, issue, run_id, approved_by, approval_window, now_override = sys.argv[1:]
policy = json.loads(Path(policy_path).read_text(encoding="utf-8"))
entry = (policy.get("actions") or {}).get(action) or policy.get("default_action") or {}
category = entry.get("category") or "unknown"
side_effect = entry.get("side_effect") or "unknown"
requires_approval = entry.get("requires_approval") is True
default_decision = entry.get("decision_without_approval") or ("stop_for_approval" if requires_approval else "proceed")
reason = entry.get("reason") or "no reason configured"

def parse_time(value):
    if not value:
        return None
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)

now = parse_time(now_override) if now_override else dt.datetime.now(dt.timezone.utc)
window_checks = []
window_approval = False
window_approved_by = None
window_reason = "not-provided"
if approval_window:
    path = Path(approval_window)
    if not path.is_file():
        window_checks.append({"name": "approval_window_exists", "status": "FAILED", "detail": approval_window})
        window_reason = "approval window missing"
    else:
        window_checks.append({"name": "approval_window_exists", "status": "PASSED", "detail": approval_window})
        window_data = json.loads(path.read_text(encoding="utf-8"))
        expires_at = parse_time(window_data.get("expires_at"))
        actions = window_data.get("actions") or []
        issues = window_data.get("issues") or []
        run_ids = window_data.get("run_ids") or []
        side_effects = window_data.get("side_effects") or []
        approved_by_window = window_data.get("approved_by")
        checks = [
            ("approved_by", bool(approved_by_window), approved_by_window or "missing"),
            ("expires_at", bool(expires_at and now <= expires_at), window_data.get("expires_at") or "missing"),
            ("action_scope", action in actions, action),
            ("side_effect_scope", (not side_effects or side_effect in side_effects), side_effect),
            ("issue_scope", (not issues or issue in issues), issue or "not-provided"),
            ("run_scope", (not run_ids or run_id in run_ids), run_id or "not-provided"),
        ]
        for name, passed, detail in checks:
            window_checks.append({"name": name, "status": "PASSED" if passed else "FAILED", "detail": detail})
        window_approval = all(check["status"] == "PASSED" for check in window_checks)
        window_approved_by = approved_by_window if window_approval else None
        window_reason = "batch approval matched" if window_approval else "batch approval does not cover this action"

approval_present = bool(approved_by) or window_approval
resolved_approved_by = approved_by or window_approved_by
if requires_approval and approval_present:
    decision = "approved_to_proceed"
elif requires_approval:
    decision = "stop_for_approval"
else:
    decision = default_decision
result = "PASSED" if decision != "stop_for_approval" else "APPROVAL_REQUIRED"
report = {
    "schema_version": 1,
    "contract": "side-effect-manifest.v1",
    "generated_at": now.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "action": action,
    "issue": issue or None,
    "run_id": run_id or None,
    "category": category,
    "side_effect": side_effect,
    "requires_approval": requires_approval,
    "approved_by": resolved_approved_by or None,
    "direct_approval_by": approved_by or None,
    "approval_window": {
        "path": approval_window or None,
        "matched": window_approval,
        "approved_by": window_approved_by,
        "reason": window_reason,
        "checks": window_checks,
    },
    "decision": decision,
    "side_effect_manifest": {
        "action": action,
        "category": category,
        "side_effect": side_effect,
        "requires_approval": requires_approval,
        "approval_present": approval_present,
        "decision": decision,
        "approval_window_matched": window_approval,
    },
    "result": result,
    "reason": reason if not approval_window else f"{reason}; {window_reason}",
    "remote_writes_performed": False,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - "$json_report" <<'PY'
import json
import sys
report = json.loads(sys.argv[1])
checks = report.get("approval_window", {}).get("checks") or []
check_rows = "\n".join(f"| {item['name']} | {item['status']} | {item.get('detail') or ''} |" for item in checks) or "| none | SKIPPED | no approval window |"
print(f"""# Approval Boundary: {report['action']}

## Result

- Result: {report['result']}
- Decision: {report['decision']}
- Requires approval: {str(report['requires_approval']).lower()}
- Approved by: {report.get('approved_by') or 'not-provided'}
- Direct approved by: {report.get('direct_approval_by') or 'not-provided'}
- Approval window matched: {str(report.get('approval_window', {}).get('matched')).lower()}
- Approval window: {report.get('approval_window', {}).get('path') or 'not-provided'}
- Reason: {report['reason']}
- Remote writes performed: false

## Context

- Issue: {report.get('issue') or 'not-provided'}
- Run ID: {report.get('run_id') or 'not-provided'}
- Category: {report['category']}
- Side effect: {report['side_effect']}

## Approval Window Checks

| Check | Status | Detail |
|---|---|---|
{check_rows}

## Policy

- Local-only actions may proceed.
- Obsidian generated sync has standing approval for `99-generated/` writes only.
- Tool installation, Codex config, Multica, Feishu, Git remote, deployment, destructive filesystem operations, and unknown side effects stop for explicit human approval.
""")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
fi

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "approval_boundary: $output_file"
  if [[ -n "$json_output_file" ]]; then
    echo "approval_boundary_json: $json_output_file"
  fi
else
  printf '%s\n' "$markdown_report"
fi

result="$(python3 - "$json_report" <<'PY'
import json
import sys
print(json.loads(sys.argv[1]).get("result"))
PY
)"
if [[ "$result" == "APPROVAL_REQUIRED" ]]; then
  exit 1
fi
