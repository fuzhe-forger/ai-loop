#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: scripts/memory-review-state.sh --case-id <id> --to <state> [options]

Change a project-memory case review_state with policy validation.

Options:
  --case-id <id>       Case id in memory/index.json, required
  --to <state>         Target review_state, required
  --from <state>       Optional expected current review_state guard
  --policy <file>      Policy file, default config/project-memory-policy.json
  --index <file>       Memory index file, default from policy
  --reason <text>      Reason recorded in the report
  --execute            Actually update the index; default is dry-run
  --output <file>      Optional Markdown output path
  --json-output <file> Optional JSON output path
  -h, --help           Show this help

This script is local-only. By default it performs a dry-run and never writes.
HELP
}

case_id=""
target_state=""
expected_from=""
policy_file="config/project-memory-policy.json"
index_file=""
reason=""
execute="false"
output_file=""
json_output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case-id)
      case_id="${2:-}"; shift 2 ;;
    --to)
      target_state="${2:-}"; shift 2 ;;
    --from)
      expected_from="${2:-}"; shift 2 ;;
    --policy)
      policy_file="${2:-}"; shift 2 ;;
    --index)
      index_file="${2:-}"; shift 2 ;;
    --reason)
      reason="${2:-}"; shift 2 ;;
    --execute)
      execute="true"; shift ;;
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

if [[ -z "$case_id" || -z "$target_state" ]]; then
  echo "--case-id and --to are required" >&2
  show_help
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

json_report="$(python3 - <<'PY' "$case_id" "$target_state" "$expected_from" "$policy_file" "$index_file" "$reason" "$execute"
import datetime as dt
import json
import sys
from pathlib import Path

case_id, target_state, expected_from, policy_file, index_file, reason, execute_text = sys.argv[1:]
execute = execute_text == "true"
policy_path = Path(policy_file)
policy = json.loads(policy_path.read_text(encoding="utf-8"))
index_path = Path(index_file or policy.get("index_file", "memory/index.json"))
index = json.loads(index_path.read_text(encoding="utf-8"))
allowed_states = policy.get("allowed_review_state") or []
transitions = policy.get("review_state_transitions") or {}

case = None
for item in index.get("cases") or []:
    if item.get("id") == case_id:
        case = item
        break

checks = []
def add(name, status, detail=""):
    checks.append({"name": name, "status": status, "detail": detail})

add("policy_schema", "PASSED" if policy.get("schema_version") == 1 else "FAILED", str(policy.get("schema_version")))
add("index_schema", "PASSED" if index.get("schema_version") == 1 else "FAILED", str(index.get("schema_version")))
add("case_exists", "PASSED" if case else "FAILED", case_id)
add("target_allowed", "PASSED" if target_state in allowed_states else "FAILED", target_state)

current_state = (case or {}).get("review_state") or ""
if expected_from:
    add("from_guard", "PASSED" if current_state == expected_from else "FAILED", f"current={current_state}, expected={expected_from}")
allowed_next = transitions.get(current_state, [])
add("transition_allowed", "PASSED" if target_state in allowed_next else "FAILED", f"{current_state}->{target_state}")

failed = [check for check in checks if check["status"] != "PASSED"]
result = "PASSED" if not failed else "FAILED"
changed = False
if execute and result == "PASSED" and case is not None:
    case["review_state"] = target_state
    index["updated_at"] = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    changed = True

report = {
    "schema_version": 1,
    "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "policy": str(policy_path),
    "index": str(index_path),
    "case_id": case_id,
    "from_state": current_state,
    "to_state": target_state,
    "expected_from": expected_from or None,
    "execute": execute,
    "changed": changed,
    "reason": reason,
    "result": result,
    "failed_checks": len(failed),
    "checks": checks,
    "side_effects": [str(index_path)] if changed else [],
}
print(json.dumps(report, ensure_ascii=False, indent=2))
PY
)"

markdown_report="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(f"""# Memory Review State Transition

## Summary

- Generated at: {report['generated_at']}
- Policy: {report['policy']}
- Index: {report['index']}
- Case: {report['case_id']}
- Transition: {report['from_state']} → {report['to_state']}
- Execute: {str(report['execute']).lower()}
- Changed: {str(report['changed']).lower()}
- Result: {report['result']}
- Reason: {report.get('reason') or 'not-provided'}

## Checks

| Check | Status | Detail |
|---|---|---|""")
for check in report["checks"]:
    detail = str(check.get("detail") or "").replace("|", "-")
    print(f"| {check['name']} | {check['status']} | {detail} |")
PY
)"

if [[ -n "$json_output_file" ]]; then
  mkdir -p "$(dirname "$json_output_file")"
  printf '%s\n' "$json_report" > "$json_output_file"
  echo "memory_review_state_json: $json_output_file"
fi
if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  printf '%s\n' "$markdown_report" > "$output_file"
  echo "memory_review_state_report: $output_file"
fi
if [[ -z "$json_output_file" && -z "$output_file" ]]; then
  printf '%s\n' "$markdown_report"
fi

result_status="$(python3 - <<'PY' "$json_report"
import json
import sys
report = json.loads(sys.argv[1])
print(report.get("result") or "FAILED")
PY
)"
if [[ "$result_status" != "PASSED" ]]; then
  exit 1
fi
